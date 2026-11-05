#!/usr/bin/env bash
# install-gitreins.sh — put the commit gate ON THE NODE: the binary, the hooks, the identity.
#
#   install-gitreins.sh --check
#   install-gitreins.sh --apply --author-name "Name" --author-email "mail@example" \
#                       [--co-author "Name <mail>"] [--repo "$HOME/repo"]
#
# A remote foreman commits on the bunker, so the gate has to live there: without it the node
# writes commits nothing graded, and the control host only finds out when it pulls. This is the
# node-side half of the same gate the control host runs for board commits.
#
# Pinned, never `curl | sh`: the version is installed from the index at an exact pin and the
# installed version is read back (a version string is not evidence until it is measured).
# Everything lands under $HOME; no root, no system package manager.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

PIN="${GITREINS_PIN:-0.17.1}"
# Debian and friends mark the system interpreter externally managed (PEP 668), so --user is
# refused outright and --break-system-packages is not an option on a machine we do not own.
# A dedicated venv under $HOME is the same shape the harness installer uses, and needs no root.
VENV="${GITREINS_VENV:-$HOME/gitreins-venv}"
BINDIR="$HOME/.local/bin"
REPO="${NODE_REPO:-$HOME/repo}"
MODE="--check"
AUTHOR_NAME="${GIT_AUTHOR_NAME:-}"
AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-}"
CO_AUTHOR="${GIT_CO_AUTHOR:-}"

usage() { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-2}"; }

installed() { [ -x "$VENV/bin/gitreins" ] && "$VENV/bin/gitreins" --version 2>/dev/null | awk '{print $2}' \
  || { command -v gitreins >/dev/null 2>&1 && gitreins --version 2>/dev/null | awk '{print $2}'; }; }

check() {
  local py pip ver hook cfg name email
  say "gitreins on the node — repo=$REPO pin=$PIN"

  py=$(command -v python3) && ok "python3" "$("$py" --version 2>&1)" \
    || { bad "python3" "absent — gitreins is a python package"; return 1; }

  pip=$("$py" -m pip --version 2>/dev/null | head -1) \
    && ok "pip" "${pip:-present}" \
    || bad "pip" "python3 -m pip is unavailable — run 'python3 -m ensurepip --user'"

  ver=$(installed)
  if [ -z "$ver" ]; then
    bad "gitreins" "absent (no $VENV/bin/gitreins and none on PATH) — run --apply"
  elif [ "$ver" = "$PIN" ]; then
    ok "gitreins" "version $ver at pin $PIN"
  else
    bad "gitreins" "version $ver != pin $PIN"
  fi

  if [ -d "$REPO" ]; then
    cfg="$REPO/.gitreins/config.yaml"
    [ -f "$cfg" ] && ok "config" "$cfg" || bad "config" "$cfg absent — the gate has no policy"
    hook="$REPO/.git/hooks/pre-commit"
    if [ -x "$hook" ] && grep -q gitreins "$hook" 2>/dev/null; then
      ok "hook" "pre-commit runs gitreins"
    else
      bad "hook" "no gitreins pre-commit in $REPO/.git/hooks — run 'gitreins install' there"
    fi
  else
    bad "repo" "$REPO is not a directory — the gate has nothing to protect"
  fi

  name=$(git config --global user.name 2>/dev/null || true)
  email=$(git config --global user.email 2>/dev/null || true)
  if [ -n "$name" ] && [ -n "$email" ]; then
    ok "identity" "$name <$email>"
  else
    bad "identity" "git user.name/user.email unset — a commit from this node is unattributed"
  fi

  say ""
  if [ "$FAILED" -eq 0 ]; then say "GITREINS: PASS — the gate is present on this node"; else say "GITREINS: FAIL ($FAILED)"; fi
  [ "$FAILED" -eq 0 ]
}

apply() {
  local py log ver
  py=$(command -v python3) || { bad "python3" "absent — cannot install gitreins"; return 1; }

  [ -n "$AUTHOR_NAME" ] && [ -n "$AUTHOR_EMAIL" ] \
    || { bad "identity" "--author-name and --author-email are required on --apply (a node that commits anonymously is worse than one that refuses)"; return 1; }

  local cur; cur=$(installed)
  if [ "$cur" = "$PIN" ]; then
    ok "gitreins" "already at pin $PIN (no install)"
  else
    if [ ! -x "$VENV/bin/python" ]; then
      say "  ..    creating $VENV"
      "$py" -m venv "$VENV" || { bad "venv" "python3 -m venv failed (python3-venv missing?)"; return 1; }
      ok "venv" "$VENV"
    fi
    log="$HOME/.gitreins-install-$PIN.log"
    say "  ..    installing gitreins==$PIN into the venv"
    if "$VENV/bin/python" -m pip install --upgrade --no-input "gitreins==$PIN" >"$log" 2>&1; then
      ver=$(installed)
      if [ "$ver" = "$PIN" ]; then
        ok "install" "gitreins $ver (log $log)"
      else
        bad "install" "installed ${ver:-nothing} but the pin is $PIN (log $log)"; return 1
      fi
    else
      bad "install" "pip exited $? — log $log"; return 1
    fi
    mkdir -p "$BINDIR"
    ln -sf "$VENV/bin/gitreins" "$BINDIR/gitreins" \
      && ok "path" "$BINDIR/gitreins -> $VENV/bin/gitreins" \
      || bad "path" "could not link $BINDIR/gitreins"
  fi

  if [ -d "$REPO" ]; then
    # `gitreins install` skips a repo that already has .gitreins/config.yaml and writes no hook,
    # so the hook is written here with the ABSOLUTE venv path — the reason DF-011 pins it: a bare
    # `gitreins` on PATH may be a different version that skips guards.
    local hook="$REPO/.git/hooks/pre-commit"
    if [ -x "$hook" ] && grep -q 'gitreins' "$hook" 2>/dev/null; then
      ok "hook" "already present in $REPO (left untouched)"
    else
      cat > "$hook" <<HOOK
#!/usr/bin/env bash
# GitReins pre-commit hook — runs Tier 1 guards on staged changes.
# Written by code-factory install-gitreins.sh. The gitreins path is ABSOLUTE on purpose
# (DF-011): a bare \`gitreins\` resolves via PATH and can silently run a different version.
REPO_ROOT="\$(git rev-parse --show-toplevel)"
if [ ! -f "\$REPO_ROOT/.gitreins/config.yaml" ]; then
    exit 0
fi
cd "\$REPO_ROOT"
$VENV/bin/gitreins guard --quality-async
exit \$?
HOOK
      chmod +x "$hook" && ok "hook" "written, pinned to $VENV/bin/gitreins" \
        || bad "hook" "could not write $hook"
    fi
  else
    bad "repo" "$REPO is not a directory"
  fi

  git config --global user.name "$AUTHOR_NAME"  && ok "identity" "user.name set to $AUTHOR_NAME" \
    || bad "identity" "could not set user.name"
  git config --global user.email "$AUTHOR_EMAIL" && ok "identity" "user.email set to $AUTHOR_EMAIL" \
    || bad "identity" "could not set user.email"

  if [ -n "$CO_AUTHOR" ]; then
    local envfile="$HOME/.hermes/.env"
    mkdir -p "$(dirname "$envfile")"
    touch "$envfile"; chmod 600 "$envfile"
    if grep -q '^CODING_HERMES_CO_AUTHOR=' "$envfile" 2>/dev/null; then
      ok "co_author" "CODING_HERMES_CO_AUTHOR already present (not printed)"
    else
      printf 'CODING_HERMES_CO_AUTHOR=%s\n' "$CO_AUTHOR" >> "$envfile"
      ok "co_author" "CODING_HERMES_CO_AUTHOR appended to $envfile (not printed)"
    fi
  fi

  say ""
  check
}

while [ $# -gt 0 ]; do
  case "$1" in
    --check|--apply) MODE="$1"; shift ;;
    --repo) REPO="$2"; shift 2 ;;
    --author-name) AUTHOR_NAME="$2"; shift 2 ;;
    --author-email) AUTHOR_EMAIL="$2"; shift 2 ;;
    --co-author) CO_AUTHOR="$2"; shift 2 ;;
    -h|--help) usage 0 ;;
    *) say "unknown argument: $1"; usage 2 ;;
  esac
done

case "$MODE" in
  --check) check ;;
  --apply) apply ;;
esac
