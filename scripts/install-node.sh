#!/usr/bin/env bash
# install-node.sh — install and prove one pinned Node runtime without root (CF-003).
#
# Why this exists: `project-node.sh` layer 10 could only GRADE a Node runtime it found on
# PATH, so a fresh node with a `package.json` repo (or a Go repo whose tests shell out to
# `node`) reported `FAIL tool:node` and the node was never provisioned. This is the
# provisioning half, the same shape as install-go.sh: a digest-pinned user-space archive
# under $HOME, a version read back from the binary that will actually run, and --check
# that stays read-only.
#
#   install-node.sh --check      # is the pinned runtime present? name the value or the gap
#   install-node.sh --apply      # install it (idempotent; a second --apply changes nothing)
#
# Pin: v22.22.3 — the version measured on the fleet host. Digests are the published
# SHASUMS256.txt values, and the linux-x64 tarball was downloaded and hashed again before
# this pin was written (31,059,464 bytes, sha256 2e5d1356…). A mismatch is a FAIL: the
# archive is never unpacked.
#
# Fixture seam (tests only): --tarball PATH --sha256 HEX (or NODE_DIST_TARBALL /
# NODE_DIST_SHA256) replace the download URL with a local file. The digest is still
# checked, so the arm proves fetch-verify-extract-readback; only the artifact differs.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

NODE_PIN="v22.22.3"
NODE_SHA256_LINUX_X64="2e5d13569282d016861fae7c8f935e741693c269101a5bebcf761a5376d1f99f"
NODE_SHA256_LINUX_ARM64="1c4a9933a5e45bc88f54f70b5f91232c127ec49f1a5989d23fb85824c7adf9b7"
NODE_DISK_FLOOR_GB=1
MODE=""
ROOT="${NODE_INSTALL_ROOT:-$HOME/node-toolchain}"
ROOT_EXPLICIT=0
TARBALL="${NODE_DIST_TARBALL:-}"
SHA_OVERRIDE="${NODE_DIST_SHA256:-}"
PRINT_PATH=0

usage() {
  echo "usage: $0 --check|--apply [--root DIR] [--tarball FILE --sha256 HEX] [--print-path]" >&2
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --check|--apply) MODE="${1#--}"; shift ;;
    --root) ROOT="$2"; ROOT_EXPLICIT=1; shift 2 ;;
    --tarball) TARBALL="$2"; shift 2 ;;
    --sha256) SHA_OVERRIDE="$2"; shift 2 ;;
    --print-path) PRINT_PATH=1; shift ;;
    *) usage ;;
  esac
done
[ -n "$MODE" ] || usage
if [ -n "$TARBALL" ] && [ -z "$SHA_OVERRIDE" ]; then
  echo "FAIL  dist — --tarball needs --sha256: an unchecked fixture is not evidence" >&2
  exit 1
fi
if [ -n "$SHA_OVERRIDE" ] && [ -z "$TARBALL" ]; then
  echo "FAIL  dist — --sha256 overrides the pin only together with --tarball" >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64|amd64)  ARCH=x64   ; WANT_SHA="$NODE_SHA256_LINUX_X64" ;;
  aarch64|arm64) ARCH=arm64 ; WANT_SHA="$NODE_SHA256_LINUX_ARM64" ;;
  *) echo "FAIL  arch — $(uname -m) has no pinned Node archive in this installer" >&2; exit 1 ;;
esac
[ -n "$SHA_OVERRIDE" ] && WANT_SHA="$SHA_OVERRIDE"
TARGET="$ROOT/$NODE_PIN"
OWNED_NODE="$TARGET/bin/node"
CURRENT="$ROOT/current"
ARCHIVE="node-$NODE_PIN-linux-$ARCH.tar.xz"
URL="https://nodejs.org/dist/$NODE_PIN/$ARCHIVE"

version_of() {
  local binary="$1" output
  [ -x "$binary" ] || return 1
  output=$("$binary" --version 2>&1) || return 1
  output=${output%%$'\n'*}
  [ -n "$output" ] || return 1
  printf '%s\n' "$output"
}

is_pin() {
  case "$1" in
    "$NODE_PIN"|"v$NODE_PIN") return 0 ;;
    *) return 1 ;;
  esac
}

[ "$PRINT_PATH" -eq 1 ] && { printf '%s\n' "$CURRENT/bin"; exit 0; }

# --- 1. what is already here (read-only in both modes) ---------------------------------
found=""
for candidate in "$OWNED_NODE" "$(have node)"; do
  [ -n "$candidate" ] || continue
  output="$(version_of "$candidate")" || continue
  if is_pin "$output"; then found="$candidate"; found_version="$output"; break; fi
done

if [ "$MODE" = check ]; then
  if [ "$ROOT_EXPLICIT" -eq 1 ] && [ -x "$OWNED_NODE" ]; then
    observed="$(version_of "$OWNED_NODE")" || observed=""
    if is_pin "${observed:-}"; then
      ok "node" "$OWNED_NODE ($observed) — pin $NODE_PIN"
      [ -L "$CURRENT" ] && ok "node:current" "$(readlink -f "$CURRENT")" \
        || warn "node:current" "$CURRENT is not a symlink — --apply would create it"
      exit 0
    fi
    bad "node" "$OWNED_NODE reports '${observed:-nothing}' — want $NODE_PIN"
    echo "NODE: FAIL ($FAILED)"
    exit 1
  fi
  # An explicit --root is a SCOPED question ("is THIS installation the pin?"), so a runtime
  # that happens to be on PATH cannot answer it. Without --root the check adopts a matching
  # runtime from PATH the way install-go.sh does, and says where it found it.
  if [ "$ROOT_EXPLICIT" -eq 0 ] && [ -n "$found" ]; then
    ok "node" "$found ($found_version) — pin $NODE_PIN (from PATH)"
    [ -L "$CURRENT" ] && ok "node:current" "$(readlink -f "$CURRENT")" \
      || warn "node:current" "$CURRENT is not a symlink — --apply would create it"
    exit 0
  fi
  if [ "$ROOT_EXPLICIT" -eq 1 ]; then
    if [ -n "$found" ]; then
      bad "node" "$OWNED_NODE absent — want $NODE_PIN at that root (a $found_version runtime on PATH is not this root; run with --apply)"
    else
      bad "node" "$OWNED_NODE absent — want $NODE_PIN at that root (run with --apply)"
    fi
  elif [ -x "$OWNED_NODE" ]; then
    bad "node" "$OWNED_NODE reports $(version_of "$OWNED_NODE" || echo 'nothing') — want $NODE_PIN"
  else
    bad "node" "no Node runtime at $OWNED_NODE or on PATH — kind node cannot install or test here (run with --apply)"
  fi
  echo "NODE: FAIL ($FAILED)"
  exit 1
fi

# --- 2. apply: idempotent install of the pinned archive --------------------------------
if [ -n "$found" ] && [ "$found" = "$OWNED_NODE" ] && is_pin "$found_version"; then
  ok "node" "$OWNED_NODE already $found_version (unchanged)"
  ln -sfn "$TARGET" "$CURRENT"
  [ "$PRINT_PATH" -eq 1 ] && printf '%s\n' "$CURRENT/bin"
  exit 0
fi

free=$(free_gb "$HOME")
if awk -v f="$free" -v m="$NODE_DISK_FLOOR_GB" 'BEGIN{exit !(f>=m)}'; then
  note "disk ${free} GB free (installer floor ${NODE_DISK_FLOOR_GB} GB)"
else
  bad "disk" "${free} GB free < installer floor ${NODE_DISK_FLOOR_GB} GB at $HOME"
  echo "NODE: FAIL ($FAILED)"
  exit 1
fi

mkdir -p "$ROOT" || { bad "node_root" "cannot create $ROOT"; echo "NODE: FAIL ($FAILED)"; exit 1; }
work="$(mktemp -d "$ROOT/.install-XXXXXX")" || { bad "node_staging" "cannot create a staging dir under $ROOT"; echo "NODE: FAIL ($FAILED)"; exit 1; }
cleanup() { rm -rf "$work"; }
trap cleanup EXIT

if [ -n "$TARBALL" ]; then
  [ -f "$TARBALL" ] || { bad "node_dist" "$TARBALL does not exist"; echo "NODE: FAIL ($FAILED)"; exit 1; }
  cp "$TARBALL" "$work/$ARCHIVE" || { bad "node_dist" "cannot stage $TARBALL"; echo "NODE: FAIL ($FAILED)"; exit 1; }
  source_desc="local $TARBALL"
else
  # fetch_verified downloads, compares sha256 and only then puts the file in place (M0 rule 7).
  if ! fetch_verified "$URL" "$work/$ARCHIVE" "$WANT_SHA"; then
    bad "node_dist" "$URL — download or digest verification failed (want $WANT_SHA)"
    echo "NODE: FAIL ($FAILED)"
    exit 1
  fi
  source_desc="$URL"
fi
got=$(sha256sum "$work/$ARCHIVE" | cut -d' ' -f1)
[ "$got" = "$WANT_SHA" ] && ok "node_dist" "$source_desc sha256 ${got:0:12}…" \
  || { bad "node_dist" "sha256 $got != $WANT_SHA"; echo "NODE: FAIL ($FAILED)"; exit 1; }

if ! tar -xJf "$work/$ARCHIVE" -C "$work"; then
  bad "node_extract" "tar -xJf $ARCHIVE failed"
  echo "NODE: FAIL ($FAILED)"
  exit 1
fi
extracted="$work/node-$NODE_PIN-linux-$ARCH"
[ -d "$extracted" ] || { bad "node_extract" "archive did not contain node-$NODE_PIN-linux-$ARCH"; echo "NODE: FAIL ($FAILED)"; exit 1; }

# Replace the pin directory atomically enough that a concurrent reader never sees a
# half-extracted tree: build at a sibling path, then swap.
staged="$ROOT/.$NODE_PIN.new.$$"
rm -rf "$staged"
mv "$extracted" "$staged" || { bad "node_install" "cannot move the extracted tree into $ROOT"; echo "NODE: FAIL ($FAILED)"; exit 1; }
rm -rf "$TARGET"
mv "$staged" "$TARGET" || { bad "node_install" "cannot place $TARGET"; echo "NODE: FAIL ($FAILED)"; exit 1; }
ln -sfn "$TARGET" "$CURRENT"
ok "node_install" "$TARGET ($ARCH, sha256 ${WANT_SHA:0:12}…)"

observed="$(version_of "$OWNED_NODE")" || observed=""
if is_pin "${observed:-}"; then
  ok "node" "$OWNED_NODE ($observed) — pin $NODE_PIN"
  ok "node:current" "$(readlink -f "$CURRENT")"
  npm="$TARGET/bin/npm"
  if [ -x "$npm" ]; then
    nv="$(PATH="$TARGET/bin:$PATH" "$npm" --version 2>&1 | head -1)"
    ok "npm" "$nv"
  else
    warn "npm" "absent from the $NODE_PIN archive (node-only runtime)"
  fi
else
  bad "node" "$OWNED_NODE reports '${observed:-nothing}' — want $NODE_PIN"
fi

echo ""
if [ "$FAILED" -eq 0 ]; then echo "NODE: PASS ($NODE_PIN at $TARGET)"; exit 0; fi
echo "NODE: FAIL ($FAILED)"
exit 1
