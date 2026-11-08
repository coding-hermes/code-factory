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

# CF-266: a version read from PATH is NOT the binary this installer's hook will call. The hook is
# pinned to $VENV/bin/gitreins (DF-011), so the two sources are reported apart and never folded
# together — the old `installed()` fell back to PATH silently, so `--check` certified a hook that
# died with "No such file or directory" on the first commit.
venv_bin() { [ -x "$VENV/bin/gitreins" ] && printf '%s' "$VENV/bin/gitreins"; }
path_bin() { command -v gitreins 2>/dev/null; }

# installed — "<version> <venv|path>", or nothing when no gitreins answers --version. The
# provenance is part of the answer: callers must not treat a PATH hit as the pinned interpreter.
installed() {
  local bin ver src
  for src in venv path; do
    bin=""
    if [ "$src" = venv ]; then bin=$(venv_bin); else bin=$(path_bin); fi
    [ -n "$bin" ] || continue
    ver=$("$bin" --version 2>/dev/null | awk '{print $2}')
    if [ -n "$ver" ]; then printf '%s %s\n' "$ver" "$src"; return 0; fi
  done
  return 1
}

# The interpreter a hook actually invokes: the first uncommented word whose basename is exactly
# `gitreins` (an absolute pinned path, or a bare name resolved through PATH here). A hook that
# merely CONTAINS the string is not proof the gate can run — `.gitreins/config.yaml` in a hook
# carries the word too and would match a naive grep.
hook_gitreins_bin() {
  local hook="$1" tok base
  [ -r "$hook" ] || return 1
  while IFS= read -r tok; do
    tok="${tok//[;()|&]/}"
    tok="${tok%\"}"; tok="${tok#\"}"
    tok="${tok%\'}"; tok="${tok#\'}"
    base="${tok##*/}"
    [ "$base" = gitreins ] || continue
    case "$tok" in
      */*) printf '%s' "$tok" ;;
      *) command -v gitreins 2>/dev/null || printf '%s' gitreins ;;
    esac
    return 0
  done < <(grep -vE '^[[:space:]]*#' "$hook" 2>/dev/null | tr ' 	' '\n\n' | grep -F gitreins)
  return 1
}

check() {
  local py pip inst ver src hook cfg name email hookbin
  say "gitreins on the node — repo=$REPO pin=$PIN"

  py=$(command -v python3) && ok "python3" "$("$py" --version 2>&1)" \
    || { bad "python3" "absent — gitreins is a python package"; return 1; }

  pip=$("$py" -m pip --version 2>/dev/null | head -1) \
    && ok "pip" "${pip:-present}" \
    || bad "pip" "python3 -m pip is unavailable — run 'python3 -m ensurepip --user'"

  if inst=$(installed); then ver="${inst% *}"; src="${inst##* }"; else ver=""; src=""; fi
  if [ -z "$ver" ]; then
    bad "gitreins" "absent (no $VENV/bin/gitreins and none on PATH) — run --apply"
  elif [ "$src" = venv ]; then
    if [ "$ver" = "$PIN" ]; then
      ok "gitreins" "version $ver at pin $PIN from $VENV/bin/gitreins"
    else
      bad "gitreins" "version $ver from $VENV/bin/gitreins != pin $PIN — run --apply"
    fi
  elif [ "$ver" = "$PIN" ]; then
    # The pin matches, but this is not the interpreter the hook calls. Calling that "installed"
    # is the CF-266 lie: the row passed while $VENV — the path written into the hook — was absent.
    bad "gitreins" "version $ver at pin $PIN but only on PATH ($(path_bin)) — $VENV/bin/gitreins is absent, so the pinned hook cannot run; run --apply"
  else
    bad "gitreins" "version $ver on PATH ($(path_bin)) != pin $PIN — run --apply"
  fi

  if [ -d "$REPO" ]; then
    cfg="$REPO/.gitreins/config.yaml"
    [ -f "$cfg" ] && ok "config" "$cfg" || bad "config" "$cfg absent — the gate has no policy"
    hook="$REPO/.git/hooks/pre-commit"
    hookbin=$(hook_gitreins_bin "$hook") || hookbin=""
    if [ ! -e "$hook" ]; then
      bad "hook" "no pre-commit at $hook — the gate is not installed there; run --apply"
    elif [ ! -x "$hook" ]; then
      bad "hook" "$hook is not executable — git skips it, so the gate never runs"
    elif [ -z "$hookbin" ]; then
      bad "hook" "$hook names no gitreins interpreter — it is not a GitReins gate"
    elif [ ! -x "$hookbin" ]; then
      # A hook whose interpreter is not there fails closed at the worst moment. Name the path.
      bad "hook" "$hook calls $hookbin which does not exist or is not executable — every commit there fails closed until --apply"
    else
      ok "hook" "pre-commit calls $hookbin (executable)"
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
  local py log inst ver src
  py=$(command -v python3) || { bad "python3" "absent — cannot install gitreins"; return 1; }

  [ -n "$AUTHOR_NAME" ] && [ -n "$AUTHOR_EMAIL" ] \
    || { bad "identity" "--author-name and --author-email are required on --apply (a node that commits anonymously is worse than one that refuses)"; return 1; }

  if inst=$(installed); then ver="${inst% *}"; src="${inst##* }"; else ver=""; src=""; fi
  if [ "$src" = venv ] && [ "$ver" = "$PIN" ]; then
    ok "gitreins" "already at pin $PIN in $VENV (no install)"
  else
    # CF-266: a pin-matching binary on PATH is NOT a reason to skip the venv. The hook is written
    # with the absolute $VENV path, so skipping left it pinned to an interpreter that never existed.
    if [ "$src" = path ]; then
      note "gitreins $ver on PATH ($(path_bin)) is not the binary the hook pins to — installing the pin into $VENV"
    elif [ "$src" = venv ]; then
      note "$VENV carries gitreins $ver, pin is $PIN — installing the pin into $VENV"
    fi
    if [ ! -x "$VENV/bin/python" ]; then
      say "  ..    creating $VENV"
      "$py" -m venv "$VENV" || { bad "venv" "python3 -m venv failed (python3-venv missing?)"; return 1; }
      ok "venv" "$VENV"
    fi
    log="$HOME/.gitreins-install-$PIN.log"
    say "  ..    installing gitreins==$PIN into the venv"
    if "$VENV/bin/python" -m pip install --upgrade --no-input "gitreins==$PIN" >"$log" 2>&1; then
      if inst=$(installed); then ver="${inst% *}"; src="${inst##* }"; else ver=""; src=""; fi
      if [ "$src" = venv ] && [ "$ver" = "$PIN" ]; then
        ok "install" "gitreins $ver in $VENV (log $log)"
      else
        bad "install" "installed ${ver:-nothing} (${src:-nowhere}) but the pin is $PIN (log $log)"; return 1
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
    local hook="$REPO/.git/hooks/pre-commit" hookbin
    hookbin=$(hook_gitreins_bin "$hook") || hookbin=""
    if [ -x "$hook" ] && [ -n "$hookbin" ]; then
      if [ -x "$hookbin" ]; then
        ok "hook" "already present in $REPO, calls $hookbin (left untouched)"
      else
        bad "hook" "existing $hook calls $hookbin which does not exist or is not executable — every commit there fails closed; remove that hook and re-run --apply"
      fi
    elif [ ! -x "$VENV/bin/gitreins" ]; then
      # CF-266: never write a hook pinned to an interpreter that is not there. Refusing is
      # diagnosable; a dead hook fails closed at commit time with no clue where it came from.
      bad "hook" "refusing to write $hook — $VENV/bin/gitreins does not exist or is not executable, so a hook pinned to it would fail every commit"
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
