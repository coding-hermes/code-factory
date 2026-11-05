#!/usr/bin/env bash
# install-go.sh — install and prove one pinned Go toolchain without root.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

GO_PIN="go1.26.5"
GO_SHA256_LINUX_AMD64="5c2c3b16caefa1d968a94c1daca04a7ca301a496d9b086e17ad77bb81393f053"
GO_SHA256_LINUX_ARM64="fe4789e92b1f33358680864bbe8704289e7bb5fc207d80623c308935bd696d49"
GO_DISK_FLOOR_GB=1
GO_PROBE_MODULE="rsc.io/quote"
GO_PROBE_VERSION="v1.5.2"
MODE="${1:---check}"
ROOT="${GO_INSTALL_ROOT:-$HOME/go-toolchain}"
TARGET="$ROOT/$GO_PIN"
OWNED_GO="$TARGET/bin/go"

case "$MODE" in
  --check|--apply) ;;
  *) echo "usage: $0 [--check|--apply]" >&2; exit 2 ;;
esac
[ "$#" -le 1 ] || { echo "usage: $0 [--check|--apply]" >&2; exit 2; }

version_of() {
  local binary="$1" output
  output=$("$binary" version 2>&1) || return 1
  output=${output%%$'\n'*}
  [ -n "$output" ] || return 1
  printf '%s\n' "$output"
}

is_pin() {
  case "$1" in
    "go version $GO_PIN "*) return 0 ;;
    *) return 1 ;;
  esac
}

find_pinned_go() {
  local candidate output
  for candidate in "$OWNED_GO" "$(have go)"; do
    [ -n "$candidate" ] && [ -x "$candidate" ] || continue
    output=$(version_of "$candidate") || continue
    if is_pin "$output"; then
      PINNED_GO="$candidate"
      PINNED_VERSION="$output"
      return 0
    fi
  done
  return 1
}

module_proof() {
  local binary="$1" proxy probe rc first
  if [ -n "${GOPROXY:-}" ]; then
    proxy="$GOPROXY"
  else
    proxy=$("$binary" env GOPROXY 2>/dev/null | head -1)
  fi
  [ -n "$proxy" ] || proxy=unset
  if ! command -v timeout >/dev/null 2>&1; then
    bad "go:module" "$GO_PROBE_MODULE@$GO_PROBE_VERSION via $proxy: timeout command missing"
    return 1
  fi
  probe=$(mktemp -d) || {
    bad "go:module" "$GO_PROBE_MODULE@$GO_PROBE_VERSION via $proxy: cannot create cold module cache"
    return 1
  }
  (
    cd "$probe" || exit 1
    "$binary" mod init cf219.invalid/probe >/dev/null 2>&1 || exit 1
    GOPROXY="$proxy" GOMODCACHE="$probe/gomodcache" GOTOOLCHAIN=local GOSUMDB=off GOFLAGS= \
      timeout 30 "$binary" mod download "$GO_PROBE_MODULE@$GO_PROBE_VERSION"
  ) >"$probe/probe.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "go:module" "$GO_PROBE_MODULE@$GO_PROBE_VERSION resolved via $proxy"
  else
    first=$(awk 'NF { print; exit }' "$probe/probe.log" 2>/dev/null | cut -c1-240)
    bad "go:module" "$GO_PROBE_MODULE@$GO_PROBE_VERSION via $proxy: ${first:-exit $rc with no output}"
  fi
  # Module cache entries are read-only by design; make this private temp tree
  # removable before deleting it so a successful proof leaves no residue.
  chmod -R u+w "$probe" 2>/dev/null || true
  rm -rf "$probe"
  [ "$rc" -eq 0 ]
}

if [ "$MODE" = "--check" ]; then
  if find_pinned_go; then
    ok "go" "$PINNED_VERSION"
  else
    bad "go" "missing: pinned $GO_PIN not found under $ROOT"
  fi
  [ "$FAILED" -eq 0 ] && exit 0 || exit 1
fi

# An owned, measured pin is the idempotence sentinel. A healthy second run does
# no disk check, download, extraction, or symlink update; a damaged current link
# is repaired before repeating the cold module proof.
if [ -x "$OWNED_GO" ]; then
  owned_version=$(version_of "$OWNED_GO") || owned_version=""
  if is_pin "$owned_version"; then
    if [ ! "$ROOT/current" -ef "$TARGET" ]; then
      ln -sfn "$GO_PIN" "$ROOT/current" || {
        bad "go" "cannot update $ROOT/current"
        exit 1
      }
    fi
    ok "go" "already at $GO_PIN — $owned_version"
    module_proof "$OWNED_GO" || true
    [ "$FAILED" -eq 0 ] && exit 0 || exit 1
  fi
fi

require_disk "$HOME" "$GO_DISK_FLOOR_GB" || exit 1
case "$(uname -m)" in
  x86_64|amd64)
    archive="$GO_PIN.linux-amd64.tar.gz"
    digest="$GO_SHA256_LINUX_AMD64"
    ;;
  aarch64|arm64)
    archive="$GO_PIN.linux-arm64.tar.gz"
    digest="$GO_SHA256_LINUX_ARM64"
    ;;
  *)
    bad "go" "unsupported Linux architecture: $(uname -m)"
    exit 1
    ;;
esac

mkdir -p "$ROOT" || { bad "go" "cannot create install root $ROOT"; exit 1; }
stage=$(mktemp -d "$ROOT/.install-$GO_PIN.XXXXXXXX") || {
  bad "go" "cannot create staging directory under $ROOT"
  exit 1
}
trap 'rm -rf "$stage"' EXIT
url="${GO_DL_BASE:-https://go.dev/dl}/$archive"
if ! fetch_verified "$url" "$stage/$archive" "$digest"; then
  bad "go:download" "$url failed verification for sha256 $digest"
  exit 1
fi
mkdir -p "$stage/extract"
if ! tar -xzf "$stage/$archive" -C "$stage/extract"; then
  bad "go:extract" "$archive could not be extracted"
  exit 1
fi
candidate="$stage/extract/go/bin/go"
installed_version=$(version_of "$candidate") || installed_version=""
if ! is_pin "$installed_version"; then
  bad "go" "archive read-back was ${installed_version:-empty}; expected go version $GO_PIN ..."
  exit 1
fi
if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
  rm -rf "$TARGET"
fi
mv "$stage/extract/go" "$TARGET" || { bad "go" "cannot publish $TARGET"; exit 1; }
ln -sfn "$GO_PIN" "$ROOT/current" || { bad "go" "cannot update $ROOT/current"; exit 1; }
ok "go" "$installed_version"
module_proof "$OWNED_GO" || true
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
