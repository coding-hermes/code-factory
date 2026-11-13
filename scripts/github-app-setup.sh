#!/usr/bin/env bash
# github-app-setup.sh — the first-install walkthrough for the fleet's GitHub App credential.
#
#   github-app-setup.sh --check [--env-file F] [--repo ORG/NAME] [--slug SLUG] [--node AGENT]
#   github-app-setup.sh --apply --slug SLUG --repo ORG/NAME \
#                             [--app-id N] [--installation-id N] [--key-file PATH]
#   github-app-setup.sh --manifest [--name code-factory] [--org coding-hermes]
#
# WHY AN APP AND NOT A PAT: a personal access token is one person's credential with that
# person's whole scope, it does not expire unless someone remembers, and every node that
# holds one can do everything that person can. A GitHub App is an identity of its own, the
# installation is scoped to named repositories, and the token a node uses dies in ONE HOUR.
# The fleet commits as the App's bot user, not as whoever created the token.
#
# WHAT THIS SCRIPT CANNOT DO: create the App. Registering a GitHub App is a browser
# authorization click — the manifest flow needs a human to POST a manifest from a page and
# approve it, and the private key download is a one-time browser download. There is no
# headless endpoint for it, and this script will not pretend there is. What it does is verify
# every piece afterwards and REFUSE, naming the piece, until the hand-made parts are right.
#
# WHAT IT DOES AUTOMATE: writing ~/.config/code-factory/github-app.env (mode 600) from
# answers it has verified against the API, printing the exact permission set with a reason
# per permission, and proving with a real API call that a freshly minted installation token
# can READ the target repo. Success is printed only after that proof passes.
#
# Nothing secret is printed: not the token, not the JWT, not the private key. Verification
# lives in scripts/github-app-token.py so there is exactly one implementation of it.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

ENV_FILE="${GITHUB_APP_ENV_FILE:-$HOME/.config/code-factory/github-app.env}"
TOKEN_FILE="${GITHUB_APP_TOKEN_FILE:-$HOME/.config/code-factory/github.token}"
APP_ID=""
INSTALLATION_ID=""
KEY_FILE=""
SLUG=""
REPO=""
ORG=""
NAME="code-factory"
NODE=""
API_BASE="${GITHUB_API_BASE:-https://api.github.com}"
MODE=""
ASSUME_YES=0

# The set the fleet needs. Every entry states why: a permission nobody can justify is a
# permission to remove.
#   contents: write       a node clones AND pushes; a push is a contents write. read: would
#                         let a node clone but never land a commit — a node that cannot push
#                         is not a node.
#   pull_requests: write  main is protected for the release contract (CF-163), so landing is
#                         a PR; opening one needs write, and the review lane reads check runs.
#   metadata: read        granted to every App and not optional; without it the token cannot
#                         resolve the repository or the installation at all.
# Not requested on purpose: administration, secrets, workflows, packages, members, hooks.
# An installation token cannot exceed what the App declares, so a narrow App is the whole
# blast radius of a leaked node credential.
PERMISSIONS=(
  "contents:write|clone and push commits from a node"
  "pull_requests:write|open the PR that a protected main requires"
  "metadata:read|mandatory for every App; resolves the repo and installation"
)

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-2}"; }

expand_tilde() { case "$1" in "~/") printf '%s/' "$HOME" ;; "~/"*) printf '%s/%s' "$HOME" "${1#\~/}" ;; *) printf '%s' "$1" ;; esac; }
norm_repo() { printf '%s' "${1#https://github.com/}" | sed -e 's/\.git$//' -e 's#^git@github.com:##'; }

# The repo this script ships in, when the caller did not name one: an installation that does
# not cover code-factory itself is not useful to code-factory.
default_repo() {
  local url
  url=$(git -C "$HERE" remote get-url origin 2>/dev/null || true)
  [ -n "$url" ] && norm_repo "$url" || true
}

while [ $# -gt 0 ]; do
  case "$1" in
    --check|--apply) MODE="${1#--}"; shift ;;
    --manifest) MODE="manifest"; shift ;;
    --env-file) ENV_FILE="$(expand_tilde "${2:-}")"; shift 2 ;;
    --token-file) TOKEN_FILE="$(expand_tilde "${2:-}")"; shift 2 ;;
    --app-id) APP_ID="${2:-}"; shift 2 ;;
    --installation-id) INSTALLATION_ID="${2:-}"; shift 2 ;;
    --key-file) KEY_FILE="$(expand_tilde "${2:-}")"; shift 2 ;;
    --slug) SLUG="${2:-}"; shift 2 ;;
    --repo) REPO="$(norm_repo "${2:-}")"; shift 2 ;;
    --node) NODE="${2:-}"; shift 2 ;;
    --org) ORG="${2:-}"; shift 2 ;;
    --name) NAME="${2:-}"; shift 2 ;;
    --api-base) API_BASE="${2:-}"; shift 2 ;;
    --yes) ASSUME_YES=1; shift ;;
    -h|--help) usage 0 ;;
    *) say "unknown argument: $1"; usage 2 ;;
  esac
done
[ -n "$MODE" ] || usage 2

PY="$(command -v python3 || true)"
[ -n "$PY" ] || { bad "python3" "python3 is required (it signs the App JWT)"; exit 1; }
MINTER="$HERE/github-app-token.py"
[ -r "$MINTER" ] || { bad "minter" "$MINTER is missing"; exit 1; }

if [ -z "$REPO" ]; then REPO="$(default_repo)"; fi
if [ -z "$REPO" ] && [ -f "$ENV_FILE" ]; then
  REPO="$(sed -n 's/^GITHUB_APP_REPO=//p' "$ENV_FILE" | tail -1)"
fi

print_permissions() {
  local row name why
  say ""
  say "PERMISSIONS the App must declare (Repository permissions):"
  for row in "${PERMISSIONS[@]}"; do
    name="${row%%|*}"; why="${row#*|}"
    say "  $(printf '%-22s' "$name") $why"
  done
  say "  $(printf '%-22s' 'everything else') no access — an installation token cannot exceed this set"
  say ""
  say "  Account permission: none. Event subscriptions: none (no webhooks are needed)."
}

browser_steps() {
  local key="${KEY_FILE:-$HOME/.config/code-factory/github-app.private-key.pem}"
  local slug="${SLUG:-<the-slug-GitHub-assigns>}"
  say ""
  say "BROWSER STEPS — a human must do these; no API can:"
  say ""
  say "  1. Create the App (one authorization click, and the only way to get a private key):"
  if [ -n "$ORG" ]; then
    say "       https://github.com/organizations/$ORG/settings/apps/new"
  else
    say "       https://github.com/settings/apps/new   (or .../organizations/<org>/settings/apps/new)"
  fi
  say "     Name it '$NAME' (the slug appears in its URL). Set the permissions above."
  say "     Or print the manifest with --manifest and paste it into the manifest flow."
  say ""
  say "  2. Generate a private key on the App page (Private keys -> Generate a private key)."
  say "     GitHub downloads it once and never shows it again. Move it to:"
  say "       $key"
  say "     and make it unreadable to anyone else:   chmod 600 $key"
  say ""
  say "  3. Install the App on the organization and choose the repositories:"
  say "       https://github.com/apps/$slug/installations/new"
  say "     After installing, the URL of the installation settings page ends in the"
  say "     installation id: .../installations/<NUMBER>  — that number is needed below."
  say ""
  say "  4. Come back and run:"
  say "       scripts/github-app-setup.sh --apply --slug $slug --repo ${REPO:-ORG/NAME} \\"
  say "         --app-id <NUMBER> --installation-id <NUMBER> --key-file $key"
  say ""
  say "  This script verifies all four pieces afterwards. It does not create the App, and it"
  say "  never reports success it has not measured."
}

# --- manifest ------------------------------------------------------------------------------
if [ "$MODE" = "manifest" ]; then
  exec "$PY" "$MINTER" manifest --name "$NAME" ${ORG:+--org "$ORG"}
fi

# --- check ---------------------------------------------------------------------------------
run_minter_check() {
  local args=(check --env-file "$ENV_FILE" --api-base "$API_BASE")
  [ -n "$REPO" ] && args+=(--repo "$REPO")
  [ -n "$SLUG" ] && args+=(--slug "$SLUG")
  "$PY" "$MINTER" "${args[@]}"
}

check() {
  local rc=0 mode
  say "github-app-setup --check — env file $ENV_FILE"
  say ""
  if [ ! -f "$ENV_FILE" ]; then
    say "  FAIL  env_file — $ENV_FILE does not exist yet"
    say ""
    say "  Nothing is configured, so nothing can be verified. The pieces a person creates"
    say "  by hand are: the App (its id), the installation (its id), the private key file at"
    say "  mode 600, and the installation's coverage of the target repo."
    browser_steps
    print_permissions
    say ""
    say "GITHUB APP SETUP: FAIL (1) — no env file, nothing measured"
    return 1
  fi
  mode=$(stat -c %a "$ENV_FILE" 2>/dev/null || echo '?')
  if [ "$mode" = "600" ]; then
    ok "env_file" "$ENV_FILE present, mode 600"
  else
    bad "env_file" "$ENV_FILE is mode $mode, expected 600 (chmod 600 $ENV_FILE)"; rc=1
  fi

  # Every hand-made piece is measured by the minter, which names each one it cannot verify:
  # app id, installation id, private key (mode + parse), token mint, declared permissions,
  # installation coverage of --repo, and a real read of the repo with a fresh token.
  if run_minter_check; then
    ok "verification" "every hand-made piece measured green by github-app-token.py"
  else
    bad "verification" "one or more pieces above are missing or wrong — see the named rows"; rc=1
  fi

  # A token that expires in an hour needs something to re-mint it. Not a FAIL here (a
  # control-host-only setup never installs one), but never silent either. Existence alone is
  # insufficient: the timer must target this node and run at least every 30 minutes.
  local refresh_dir="$HOME/.config/systemd/user" timer="" service="" cadence="" refresh_ok=0 cron_minutes="" candidate unit command_line value seconds
  if [ -n "$NODE" ]; then
    for candidate in "$refresh_dir"/cf-github-app-refresh.timer "$refresh_dir"/cf-github-app-refresh-*.timer; do
      [ -f "$candidate" ] || continue
      unit=$(sed -n 's/^Unit=//p' "$candidate" | tail -1)
      [ -n "$unit" ] || unit="$(basename "${candidate%.timer}.service")"
      case "$unit" in */*|*..*) continue ;; esac
      service="$refresh_dir/$unit"
      command_line=$(sed -n 's/^ExecStart=//p' "$service" 2>/dev/null | tail -1)
      if [[ " $command_line " == *" --node $NODE "* ]]; then
        cadence=$(sed -n 's/^OnUnitActiveSec=//p' "$candidate" | head -1)
        if [[ "$cadence" =~ ^([0-9]+)(s|sec|min)$ ]] && [ "${#BASH_REMATCH[1]}" -le 6 ]; then
          value=$((10#${BASH_REMATCH[1]})); seconds=$value
          [ "${BASH_REMATCH[2]}" != min ] || seconds=$((value * 60))
          if [ "$seconds" -gt 0 ] && [ "$seconds" -le 1800 ]; then refresh_ok=1; timer="$candidate"; break; fi
        fi
        if [ -z "$cadence" ]; then warn "refresh" "$candidate has no OnUnitActiveSec cadence (expected 30 minutes or less)"; else warn "refresh" "$candidate has invalid or too slow cadence $cadence (maximum 30 minutes)"; fi
      else
        warn "refresh" "$candidate/$service targets a different node or has no service (expected --node $NODE)"
      fi
    done
    if [ "$refresh_ok" -eq 0 ]; then
      while IFS= read -r command_line; do
        [[ " $command_line " == *" --node $NODE "* && "$command_line" == *github-app-refresh.sh* ]] || continue
        if [[ "$command_line" =~ ^\*/([0-9]+)[[:space:]]+\*[[:space:]]+\*[[:space:]]+\*[[:space:]]+\*[[:space:]] ]]; then
          cron_minutes="${BASH_REMATCH[1]}"
          if [ "${#cron_minutes}" -le 2 ] && [ "$((10#$cron_minutes))" -gt 0 ] && [ "$((10#$cron_minutes))" -le 30 ]; then refresh_ok=1; cadence="${cron_minutes}min (cron)"; break; fi
        fi
      done < <(crontab -l 2>/dev/null)
    fi
  fi
  if [ "$refresh_ok" -eq 1 ]; then
    ok "refresh" "refresh timer/cron targets --node $NODE and runs every ${cadence:-$cron_minutes}"
  elif [ -z "$NODE" ]; then
    warn "refresh" "no node supplied for refresh cadence check — a node will lose push rights 3600s after provisioning (scripts/github-app-refresh.sh --node <agent> --server <host>; see skills/code-factory-bunker/SKILL.md)"
  elif [ -n "$timer" ]; then
    warn "refresh" "$timer has cadence $cadence, but it must run every 30 minutes or less — a node will lose push rights 3600s after provisioning (scripts/github-app-refresh.sh --node <agent> --server <host>; see skills/code-factory-bunker/SKILL.md)"
  else
    warn "refresh" "no refresh timer for --node $NODE — a node will lose push rights 3600s after provisioning (scripts/github-app-refresh.sh --node <agent> --server <host>; see skills/code-factory-bunker/SKILL.md)"
  fi

  say ""
  if [ "$rc" -eq 0 ]; then
    if [ -n "$REPO" ]; then
      say "GITHUB APP SETUP: PASS — the App credential is real, scoped, and reads $REPO -> 200"
    else
      say "GITHUB APP SETUP: PASS — every configured App piece was measured; no repository read was requested"
    fi
  else
    say "GITHUB APP SETUP: FAIL"
  fi
  [ "$rc" -eq 0 ]
}

# --- apply ---------------------------------------------------------------------------------
ask() {  # ask <prompt> <varname>  — only ever on a terminal; never guesses a value
  local prompt="$1" __var="$2" value=""
  if [ ! -t 0 ]; then
    bad "$__var" "not a terminal and --$__var was not given — refusing to guess it"; return 1
  fi
  printf '  %s: ' "$prompt" >&2
  IFS= read -r value || return 1
  printf -v "$__var" '%s' "$value"
  return 0
}

apply() {
  local rc=0 tmp mode
  say "github-app-setup --apply — writing $ENV_FILE"
  say ""
  say "App creation itself is a browser step: the manifest flow needs a human authorization"
  say "click and the private key is a one-time browser download. This script verifies what"
  say "exists after that; it does not fabricate an App or a key."
  print_permissions

  [ -n "$APP_ID" ] || ask "App ID (App settings -> About -> App ID)" APP_ID || rc=1
  [ -n "$INSTALLATION_ID" ] || ask "Installation ID (organization Settings -> GitHub Apps -> Configure, the number in the URL)" INSTALLATION_ID || rc=1
  [ -n "$KEY_FILE" ] || ask "Private key path" KEY_FILE || rc=1
  [ -n "$SLUG" ] || ask "App slug (the name in https://github.com/apps/<slug>)" SLUG || rc=1
  [ -n "$REPO" ] || ask "Target repo ORG/NAME" REPO || rc=1
  [ "$rc" -eq 0 ] || { say ""; say "GITHUB APP SETUP: FAIL — missing answers, nothing written"; return 1; }

  case "$APP_ID" in ''|*[!0-9]*) bad "app_id" "--app-id '$APP_ID' is not the numeric App ID"; rc=1 ;; esac
  case "$INSTALLATION_ID" in ''|*[!0-9]*) bad "installation_id" "--installation-id '$INSTALLATION_ID' is not numeric"; rc=1 ;; esac
  case "$REPO" in */*) ;; *) bad "repo" "--repo '$REPO' is not ORG/NAME"; rc=1 ;; esac
  [ "$rc" -eq 0 ] || { say ""; say "GITHUB APP SETUP: FAIL — refused the answers, nothing written"; return 1; }

  if [ ! -f "$KEY_FILE" ]; then
    bad "private_key_file" "$KEY_FILE does not exist — download it from the App page"
    say ""; say "GITHUB APP SETUP: FAIL — nothing written"; return 1
  fi
  mode=$(stat -c %a "$KEY_FILE" 2>/dev/null || echo '?')
  if [ "$mode" != "600" ]; then
    bad "private_key_file" "$KEY_FILE is mode $mode; refusing to chmod a key you may have placed for another purpose — run: chmod 600 $KEY_FILE"
    say ""; say "GITHUB APP SETUP: FAIL — nothing written"; return 1
  fi

  # Write the env file at 600 before verifying, because the verifier reads the env file.
  # A failed verification leaves it in place to be fixed and re-checked, never a claim of
  # success: nothing prints READY except the check below.
  mkdir -p "$(dirname "$ENV_FILE")"
  tmp="$(mktemp)"; chmod 600 "$tmp"
  {
    printf '# code-factory GitHub App credential — pointers, never secrets (mode 600)\n'
    printf '# written by scripts/github-app-setup.sh --apply; verified by github-app-token.py --check\n'
    printf 'GITHUB_APP_ID=%s\n' "$APP_ID"
    printf 'GITHUB_APP_INSTALLATION_ID=%s\n' "$INSTALLATION_ID"
    printf 'GITHUB_APP_PRIVATE_KEY_FILE=%s\n' "$KEY_FILE"
    printf 'GITHUB_APP_SLUG=%s\n' "$SLUG"
    printf 'GITHUB_APP_REPO=%s\n' "$REPO"
    printf '# where a minted 1h installation token is written (never committed, mode 600)\n'
    printf 'GITHUB_APP_TOKEN_FILE=%s\n' "$TOKEN_FILE"
  } > "$tmp"
  mv "$tmp" "$ENV_FILE"; chmod 600 "$ENV_FILE"
  ok "env_file" "$ENV_FILE written, mode 600 (no secret in it: it names the key path)"

  say ""
  say "verifying the pieces against the GitHub API (a real call; the token is never printed)"
  say ""
  if run_minter_check; then
    say ""
    say "GITHUB APP SETUP: READY — every piece verified, and a fresh installation token reads $REPO"
    say ""
    say "the token expires in 3600s, so armed the refresh next:"
    say "  scripts/github-app-token.py token            # mint one now, mode 600"
    say "  scripts/github-app-refresh.sh --local        # and keep this host fresh"
    return 0
  fi
  say ""
  say "GITHUB APP SETUP: INCOMPLETE — the env file was written but verification FAILED;"
  say "the named rows above are the pieces still wrong. Nothing here claims success."
  browser_steps
  return 1
}

case "$MODE" in
  check) check ;;
  apply) apply ;;
esac
