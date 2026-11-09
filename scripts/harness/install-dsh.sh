#!/usr/bin/env bash
# install-dsh.sh — pinned installer, adapter probe and per-layer diagnosis for DeepSeek's own
# harness (`dsh`). CF-226.
#
# `dsh` is DeepSeek's open-source harness ("everything is a plugin", built on Cordis):
# npm `@deepseek-ai/dsh` / CLI `dsh` / upstream https://github.com/deepseek-ai/deepseek-harness.
# The previous revision of this repo said no deepseek harness existed; it does, and the state that
# sentence described ("absent from both repos") is what this file replaces with a measurement.
#
#   install-dsh.sh --check       read-only: package identity, pin, profile, composed plugin tree
#   install-dsh.sh --apply       install the PIN under $HOME (npm --prefix), scaffold the profile
#   install-dsh.sh --turn        ONE real turn in CF_WORKDIR that must write CF_TURN_TOKEN
#   install-dsh.sh --layers      the six plugin layers, one row per layer, in order
#   install-dsh.sh --pin-status  live registry re-measurement of an RC pin (this pin is an RC)
#   install-dsh.sh --contract    the §5 set is accepted, or exit 2 with a named refusal
#
# Exit codes: 0 PASS · 1 FAIL · 2 REFUSED (a named refusal; nothing was installed or run)
#             3 UNVERIFIED/SKIP (nothing was certified, e.g. no credential for a turn)
#
# MEASURED PROVENANCE OF THE PIN — registry.npmjs.org, read 2026-11-08
#   package          @deepseek-ai/dsh                     (scoped, maintainers @deepseek.com)
#   version          0.2.1-rc.5                           <- an RC; see "THE PIN IS AN RC" below
#   dist-tags        latest=0.2.2-rc.1, next=0.2.2-rc.1, alpha=0.2.2-alpha.3
#   bin              { "dsh": "lib/bin.js" }
#   engines          ABSENT from the manifest (no declared node floor) — measured working on
#                    node 22.22.3 / npm 10.9.8; a lower major is reported as unmeasured, not refused
#   dist.shasum      8e1bfd31869414f7a5ec10c34403a852ac9c3dc7
#   dist.integrity   sha512-WkyJZv4zl9sCAxSzRctGm58m0rilGqwR6pniBiLOz5CPDfHfDuAUicg0AAazXI7oj/Cph6/cjNTncA/rpLTXpw==
#   dependency tree  618 packages, 858 MB unpacked (measured with `npm install --global --prefix`)
#
# MEASURED INSTALL (this repo's control host, 2026-11-08): 10 s, `$HOME/.local/harness/dsh`,
# 858 MB, `dsh --version` reads back `0.2.1-rc.5`, and a second `--apply` is a no-op that does not
# touch the installed tree.
#
# WHAT THE PIN ACTUALLY OFFERS (measured, not read off a README)
#   dsh <profile> "<task>"            the launcher: boot a profile (an ordered stack of plugin
#                                    -bundle patch layers) and pass app args to it. The PROFILE
#                                    comes first: `dsh headless --json "<task>"`.
#   dsh headless "<task>"            non-interactive: "Answer one task and exit; the answer goes to
#                                    stdout and diagnostics to stderr". Flags: --json (NDJSON run
#                                    events), --session-id (ADOPT an existing session only).
#   dsh <profile> --dump-config      the COMPOSED plugin tree, one `- id:` / `name:` /
#                                    `disabled:` entry per plugin, annotated with the bundle layer
#                                    that contributed it (`# == @deepseek-ai/dsh-base`).
#   dsh <profile> --patch <file>     an extra patch-layer overlay (id-targeted config overrides).
#   dsh plugin --profile <p> <pnpm>  install a plugin into a profile.
#   $DSH_HOME                        the harness state dir (default $HOME/.dsh) holding profiles/,
#                                    sessions/ and storages/. NOT the same as $HOME: `HOME=x` gives
#                                    `x/.dsh`, `DSH_HOME=x` gives `x`.
#
# TWO MEASURED FACTS THAT SHAPE THIS FILE
#   1. `--dump-config` EXITS 0 WHILE A BUNDLE IS MISSING. With a profile naming an unresolvable
#      bundle the pin prints, on stderr,
#        dsh: skipping profile bundle "@deepseek-ai/dsh-missing-bundle": Error: dsh: cannot resolve
#        profile bundle … from the dsh installation or <profile dir>; run 'dsh plugin --profile …
#        install' …
#      and still exits 0 with a partial tree. So this adapter parses the composition's STDERR and
#      never takes exit 0 as evidence — the same rule the codex exec sidecar taught (CF-006).
#   2. A PLUGIN-LAYER FAILURE IS ALREADY PER-LAYER, AND ITS STDOUT SAYS WHICH LAYER. With the `llm`
#      plugin disabled by the profile's patch layer, a boot prints
#        dsh: no agent factory registered (load an agent-loop plugin)
#        dsh: startup failed: 1 required plugin did not activate
#        Plugins waiting for services (8):
#          Plugin                     Missing services
#          agent-loop (required)      llm
#          llm-deepseek               llm
#          …
#      That table is the evidence `--layers` and `--turn` use to name the layer that failed
#      (package -> resolved -> enabled -> service -> tool -> permission) instead of reporting
#      "dsh is broken". Nothing here is inferred when the table is present.
#
# THE PIN IS AN RC, SO HOW THE VERSION IS RE-MEASURED
#   The pin is an exact, prerelease version (`0.2.1-rc.5`) — never a range, never `latest`, because
#   `latest` on this package IS an RC and a range would silently ride the release train. Three
#   constants at the top of this file are the pin (version, dist.shasum, dist.integrity) and they
#   are re-measured, together, by ONE command that needs no install and no credential:
#       install-dsh.sh --pin-status
#   which reads `npm view <pkg> dist-tags --json` and `npm view <pkg>@<pin> version dist.integrity
#   dist.shasum --json`, then reports (a) whether the registry still serves the pinned integrity
#   and shasum — a registry that serves DIFFERENT bytes for the same version is a FAIL, not a
#   warning — and (b) whether a newer RC exists, named, with the exact edit that adopts it. The
#   measured sequence for adopting a new RC is recorded in specs/HARNESS.md §"dsh".
#
# CREDENTIALS (AGENTS.md r8, specs/HARNESS-MATRIX.md §5)
#   A credential is a PATH to a mode-600 file (CF_API_KEY_FILE). A VALUE in argv, or a key exported
#   into the ambient environment, is refused by name. `dsh` reads the key from DEEPSEEK_API_KEY in
#   the LAUNCHING environment (measured: without it a boot prints
#   `dsh: MISSING_CREDENTIAL: llm-deepseek: no API key for provider route "deepseek-official"`),
#   so a turn exports it from the key file inside the child shell: never on a command line, never
#   in a log, never in this adapter's own output.
#
# NON-CLAIMS
#   * no crier adapter ships here. The written decision (and what an adapter would have to parse)
#     is recorded in specs/HARNESS.md §"dsh — the adapter decision" rather than implied by silence.
#   * no DuckBrain write happens here (the matrix's `memory` leg belongs to the foreman); a turn
#     echoes the record fields it must hand over and says that it did not write them.
#   * `model_served` is reported from dsh's own session record, which logs ONE model id for a
#     request; the installer prints it as recorded, side by side with the requested id, and does
#     not claim the two were distinguishable (specs/HARNESS-MEMORY.md §3.6).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib.sh"
# One implementation of the §5 contract (installed by CF-229, extended by CF-231): a credential is a
# path, an ambient key is refused, every declared name is recorded.
. "$HERE/harness-vars.sh"

DSH_PKG="@deepseek-ai/dsh"
DSH_PIN="0.2.1-rc.5"
DSH_SHASUM="8e1bfd31869414f7a5ec10c34403a852ac9c3dc7"
DSH_INTEGRITY="sha512-WkyJZv4zl9sCAxSzRctGm58m0rilGqwR6pniBiLOz5CPDfHfDuAUicg0AAazXI7oj/Cph6/cjNTncA/rpLTXpw=="
DSH_UPSTREAM="https://github.com/deepseek-ai/deepseek-harness"
# The node major this ladder was actually proven on. The pin declares no `engines` field, so this
# is a measurement, not a requirement: a lower major is reported as unmeasured (WARN), not refused.
DSH_MEASURED_NODE_MAJOR=22
DISK_FLOOR_GB=2.0

# Derived from $HOME only. No override: an install outside $HOME is not user-space. A prefix of its
# own (not the shared ~/.local/harness/npm that claude-code uses) because this pin is a 618-package
# tree: a dsh-specific prefix makes `rm -rf` of a bad pin unable to touch a sibling harness.
INSTALL_ROOT="$HOME/.local/harness/dsh"
PREFIX="$INSTALL_ROOT"
BIN="$PREFIX/bin/dsh"
PKG_DIR="$PREFIX/lib/node_modules/@deepseek-ai/dsh"
# The harness state dir. `dsh` itself reads DSH_HOME, so honouring it is passing a run input
# through, not inventing one; unset means the pin's own default.
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
PROFILE_DEFAULT="headless"
# The route id the pin's DeepSeek provider plugin uses. Measured: `deepseek-official`.
DSH_DEEPSEEK_ROUTE="deepseek-official"

TURN_TOKEN="${CF_TURN_TOKEN:-CF-226-TOKEN-4e8b1d}"
TURN_FILE="${CF_TURN_FILE:-dsh-turn.txt}"
TIMEOUT_S="${CF_TIMEOUT_S:-1800}"
# The layer probe is a trivial task, so it gets a short budget of its own.
PROBE_TIMEOUT_S="${CF_DSH_PROBE_TIMEOUT_S:-180}"

MODE=""
PROMPT=""
PROMPT_FILE=""

usage() {
  cat <<'DSH_USAGE'
install-dsh.sh — pinned installer, adapter probe and per-layer diagnosis for DeepSeek's harness.

USAGE
  install-dsh.sh [--check | --apply | --turn | --layers | --pin-status | --contract] [CF_* options]

MODES
  --check       (default) READ-ONLY and offline. Reports the node, the npm prefix, the package
                identity at the pin, the binary and the version read back, the resolved bin target,
                the profile, and the COMPOSED plugin tree (entry count, disabled ids, bundle
                layers). Composes against a throwaway copy of the profile under the cache root
                because the pinned binary SCAFFOLDS $DSH_HOME when it composes in place — so
                composing in the real state dir would not be read-only. Touches no install state,
                no $DSH_HOME, and never the network.
  --apply       Install @deepseek-ai/dsh at the pin under $HOME/.local/harness/dsh with an explicit
                npm --prefix: the registry metadata (version + integrity + shasum) is verified
                before downloading, the package identity and `dsh --version` are read back
                afterwards, and the headless profile is scaffolded. Re-running it changes nothing.
  --turn        ONE real turn in $CF_WORKDIR. Runs `dsh <profile> --json "<directive>"`, requires
                the turn to write $CF_TURN_FILE containing $CF_TURN_TOKEN, and reports the model
                dsh recorded, the turn outcome, the tool count and the permission preset. On a
                failure it prints the per-layer attribution rather than one line saying it broke.
  --layers      The six plugin layers, in order, one row each: package -> resolved -> enabled ->
                service -> tool -> permission. A failure names the layer and the plugin/service
                that failed; layers after it are reported as not measured, never as broken.
  --pin-status  Live registry re-measurement. This pin is an RC, so the version is re-measured from
                the registry: does the registry still serve the recorded integrity/shasum for the
                pin, and is there a newer RC? Network required; installs and runs nothing.
  --contract    Validate the §5 set and exit 0, or exit 2 with a named refusal. Installs nothing,
                runs nothing: the acceptance check the conformance battery calls.
  --help, -h    This text.

OPTIONS
  --prompt TEXT       The task for --turn (a directive is not a secret, so argv is fine). The
                      artifact instruction is APPENDED to it, so the turn is always verifiable by
                      bytes; with no directive, the turn is the artifact instruction alone.
  --prompt-file PATH  Read the task from a file instead.
DSH_USAGE
  cfv_help_block
  cat <<'DSH_TAIL'

WHERE THE RUN PROFILE COMES FROM
  CF_HARNESS_OPTS may carry `profile=<name>`; the default is `headless`, the pin's non-interactive
  profile ("answer one task and exit"). CF_MODEL is applied through a generated patch-layer overlay
  (`- id: agent-default-model` / `config.model`) written 0600 under the cache root and deleted on
  exit, because a profile's model is config and the pin's headless surface has no model flag.
  CF_PROVIDER `deepseek` maps onto the pin's route id `deepseek-official`; any other provider is
  passed through verbatim and only reaches the model through a plugin layer (matrix §3), which a
  service-layer failure will then name.

REFUSALS (each one names the rule, not just "invalid")
  * a credential VALUE in CF_API_KEY_FILE, `--api-key`, or CF_API_KEY set at all;
  * DEEPSEEK_API_KEY / DSH_API_KEY exported into the ambient environment, and an ambient
    OPENAI_API_KEY / ANTHROPIC_API_KEY — the directive is the only source (matrix §5);
  * CF_WORKDIR that does not exist, or that resolves outside $HOME;
  * a CF_API_KEY_FILE that is missing, empty, or not mode 600;
  * CF_BASE_URL that is not http(s), or that carries userinfo;
  * CF_MAX_TURNS / CF_TIMEOUT_S that are not integers, or outside 1..1000 / 1..86400;
  * running as root, or an npm prefix outside $HOME;
  * a registry pin whose metadata no longer matches the recorded integrity/shasum.
DSH_TAIL
}

die_usage() { say "install-dsh: $*" >&2; say "try --help" >&2; exit 2; }

# --- argv: the modes this adapter adds, then the §5 surface (harness-vars.sh owns that) ---------
# harness-vars.sh refuses an unknown argument, so the modes and the two prompt flags are taken out
# of argv here and everything else is handed to it unchanged.
cfv_argv=()
while [ $# -gt 0 ]; do
  case "$1" in
    --check|--apply|--contract) cfv_argv+=("$1"); shift ;;
    --turn|--layers|--pin-status) MODE="$1"; shift ;;
    --prompt) [ $# -ge 2 ] || die_usage "--prompt needs a value"; PROMPT="$2"; shift 2 ;;
    --prompt-file) [ $# -ge 2 ] || die_usage "--prompt-file needs a path"; PROMPT_FILE="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) cfv_argv+=("$1"); shift ;;
  esac
done
cfv_load_env
if [ "${#cfv_argv[@]}" -gt 0 ]; then
  cfv_parse_args "${cfv_argv[@]}"
else
  cfv_parse_args
fi
[ -z "$MODE" ] && MODE="--$CFV_MODE"

# ---------------------------------------------------------------- small helpers

inside_home() {  # inside_home <abs path>
  case "$1" in "$HOME"/*) return 0 ;; *) return 1 ;; esac
}

# The turn cache root, and the only tree this adapter creates or removes under.
turn_cache_root() { printf '%s' "${XDG_CACHE_HOME:-$HOME/.cache}/cf-dsh"; }

# inside_turn_cache <abs path> — true only for one leaf directly under the cache root.
inside_turn_cache() {
  local root leaf
  root="$(turn_cache_root)"
  case "${1:-}" in "$root"/*) ;; *) return 1 ;; esac
  leaf="${1#"$root"/}"
  case "$leaf" in */*) return 1 ;; esac
  return 0
}

# The pin answers `0.2.1-rc.5` and nothing else; anything before the first space is the version.
bin_version() {
  local raw
  raw=$("$1" --version 2>/dev/null) || return 1
  raw="${raw%%$'\n'*}"
  case "$raw" in
    ''|*[!0-9A-Za-z.+-]*) return 1 ;;
  esac
  printf '%s' "${raw%% *}"
}

node_major() {
  local v
  v=$("$1" --version 2>/dev/null) || return 1
  v="${v#v}"
  printf '%s' "${v%%.*}"
}

dsh_profile() {  # the run profile: CF_HARNESS_OPTS profile=<name>, else the pin's headless profile
  local opts="${CFV_VALUE[CF_HARNESS_OPTS]:-}" p
  case ",$opts," in
    *,profile=*)
      p="$(printf '%s' "$opts" | tr ',' '\n' | sed -n 's/^profile=//p' | head -1)"
      [ -n "$p" ] && { printf '%s' "$p"; return 0; }
      ;;
  esac
  printf '%s' "$PROFILE_DEFAULT"
}

# deepseek -> the pin's own route id; anything else is passed through and named as plugin-dependent.
dsh_route() {
  case "${1:-}" in
    deepseek|deepseek-api|deepseek-official|'') printf '%s' "$DSH_DEEPSEEK_ROUTE" ;;
    *) printf '%s' "${1}" ;;
  esac
}

# A credential value, never a path (the §5 rule, applied again where a bare env var is read).
secret_shaped() {
  local v="$1"
  case "$v" in sk-*|sk_*|xox[abp]-*|ghp_*|gho_*|AIza*) return 0 ;; esac
  case "$v" in */*|*' '*) return 1 ;; esac
  [ ${#v} -ge 20 ] && printf '%s' "$v" | grep -Eq '^[A-Za-z0-9_+=.-]+$'
}

# ---------------------------------------------------------------- install-state probes

probe_node() {
  local n major
  n="$(have node)"
  if [ -z "$n" ]; then
    bad "node" "absent — $DSH_PKG is a node package and its bin is lib/bin.js"
    return 1
  fi
  major="$(node_major "$n")" || major=""
  if [ -n "$major" ] && [ "$major" -ge "$DSH_MEASURED_NODE_MAJOR" ] 2>/dev/null; then
    ok "node" "$n ($("$n" --version 2>/dev/null)); the pin declares no engines field, and this ladder was measured on major $DSH_MEASURED_NODE_MAJOR"
  else
    warn "node" "$n reports $("$n" --version 2>/dev/null) — the pin declares no engines field and this ladder was measured on major $DSH_MEASURED_NODE_MAJOR only, so this major is unmeasured (not refused)"
  fi
  return 0
}

probe_npm() {
  local p
  p="$(have npm)"
  if [ -z "$p" ]; then
    note "npm — absent (only --apply needs it; --check and --turn do not)"
  else
    note "npm — $p ($("$p" --version 2>/dev/null)) (used by --apply)"
  fi
}

probe_prefix() {
  case "$HOME" in ''|/) bad "prefix" "refused — \$HOME is '$HOME'"; return 1 ;; esac
  case "$PREFIX" in
    "$HOME"/*) ok "prefix" "$PREFIX (user-space, under \$HOME)" ;;
    *) bad "prefix" "refused — $PREFIX is not under \$HOME"; return 1 ;;
  esac
}

pkg_identity() {  # prints "name@version" from the installed package.json, or fails
  local pj="$PKG_DIR/package.json" node_bin
  [ -f "$pj" ] || return 1
  node_bin="$(have node)" || return 1
  "$node_bin" -e '
try{const p=require(process.argv[1]);const n=String(p.name||"");const v=String(p.version||"");
if(!n||!v)process.exit(1);process.stdout.write(n+"@"+v);}catch(e){process.exit(1)}' "$pj" 2>/dev/null
}

probe_package() {
  local id
  if ! id="$(pkg_identity)"; then
    bad "package" "absent — no $PKG_DIR/package.json (run --apply, pin $DSH_PIN)"
    return 1
  fi
  if [ "$id" = "$DSH_PKG@$DSH_PIN" ]; then
    ok "package" "$id at $PKG_DIR (pin $DSH_PIN)"
  else
    bad "package" "$id at $PKG_DIR != $DSH_PKG@$DSH_PIN — run --apply"
    return 1
  fi
  return 0
}

probe_binary() {
  local p v
  if [ -x "$BIN" ]; then
    ok "binary" "$BIN (installed by this adapter)"
  else
    p="$(have dsh)"
    case "$p" in
      '') bad "binary" "absent — no $BIN and no dsh on PATH (run --apply, pin $DSH_PIN)"; return 1 ;;
      # A PATH binary this adapter did not place is host-provided, even when its version matches:
      # the pin is then unowned, and specs/HARNESS.md requires the row to say so.
      *)  bad "binary" "host-provided $p (not installed by this adapter — run --apply)"; return 1 ;;
    esac
  fi
  return 0
}

probe_version() {  # probe_version <binary>
  local v
  v="$(bin_version "$1")" || v=""
  if [ "$v" = "$DSH_PIN" ]; then
    ok "version" "$v (pin $DSH_PIN)"
  else
    bad "version" "${v:-unreadable} != pin $DSH_PIN"
    return 1
  fi
}

# The bin is a symlink into the package (measured: bin/dsh -> ../lib/node_modules/@deepseek-ai/dsh/lib/bin.js).
# A dangling or foreign target is the `resolved` layer failing, and the row names the target.
probe_resolved() {
  local target
  if [ ! -e "$BIN" ]; then
    bad "resolved" "absent — nothing at $BIN"
    return 1
  fi
  target="$(readlink -f "$BIN" 2>/dev/null)" || target=""
  if [ -z "$target" ] || [ ! -e "$target" ]; then
    bad "resolved" "$BIN resolves to '${target:-nothing}' — the launcher's target does not exist"
    return 1
  fi
  case "$target" in
    "$PKG_DIR"/*) ok "resolved" "$BIN -> $target" ;;
    *) bad "resolved" "$BIN resolves to $target, outside $PKG_DIR — not the pinned package"; return 1 ;;
  esac
  return 0
}

profile_dir() { printf '%s' "$DSH_HOME/profiles/$(dsh_profile)"; }

probe_profile() {
  local dir
  dir="$(profile_dir)"
  if [ -d "$dir" ]; then
    ok "profile" "$dir (profile $(dsh_profile))"
  else
    bad "profile" "not scaffolded at $dir — the pin cannot boot profile '$(dsh_profile)' without it; --apply scaffolds it"
    return 1
  fi
}

# ---------------------------------------------------------------- composition (never in place)

# compose_readonly <profile> <out-tree> <out-stderr>
# Runs `--dump-config` against a THROWAWAY copy of the profile under the cache root. Measured: the
# pinned binary scaffolds $DSH_HOME/profiles/<name> when it composes, so composing in the real state
# dir would write four files into a --check. The copy is removed before returning.
compose_readonly() {
  local prof="$1" out="$2" err="$3" root tmp rc
  root="$(turn_cache_root)"
  mkdir -p "$root" 2>/dev/null || return 1
  tmp="$(umask 077; mktemp -d "$root/compose.XXXXXXXX")" || return 1
  if [ ! -d "$DSH_HOME/profiles/$prof" ]; then
    rm -rf -- "$tmp" 2>/dev/null
    return 1
  fi
  mkdir -p "$tmp/profiles" || { rm -rf -- "$tmp"; return 1; }
  cp -a "$DSH_HOME/profiles/$prof" "$tmp/profiles/$prof" || { rm -rf -- "$tmp"; return 1; }
  DSH_HOME="$tmp" "$BIN" --profile "$prof" --dump-config >"$out" 2>"$err"
  rc=$?
  inside_turn_cache "$tmp" && rm -rf -- "$tmp"
  return "$rc"
}

composed_entries() {  # count of `- id:` entries in a composed tree
  grep -c '^- id: ' "$1" 2>/dev/null || true
}

composed_disabled_ids() {  # one disabled plugin id per line
  awk '
    /^- id: / { cur=$3; next }
    cur!="" && /^  disabled: true[[:space:]]*$/ { print cur; cur=""; next }
    /^# == / { cur="" }
  ' "$1" 2>/dev/null || true
}

# A bundle the pin could not resolve, from the composition's stderr (it exits 0 anyway — measured).
unresolved_bundles() {  # unresolved_bundles <stderr file>
  sed -n 's/.*cannot resolve profile bundle "\([^"]*\)".*/\1/p' "$1" 2>/dev/null | awk '!seen[$0]++'
}

# The plugin ids a profile declares, read from its package.json (the pin's `dsh.profile.bundles`).
profile_bundles() {
  local pj; pj="$(profile_dir)/package.json"
  [ -f "$pj" ] || return 1
  local node_bin; node_bin="$(have node)" || return 1
  "$node_bin" -e '
try{const p=require(process.argv[1]);const b=(p.dsh&&p.dsh.profile&&p.dsh.profile.bundles)||[];
process.stdout.write(b.join("\n"))}catch(e){process.exit(1)}' "$pj" 2>/dev/null
}

report_enabled() {  # report_enabled <tree> <stderr>
  local tree="$1" err="$2" entries disabled missing bundles b
  bundles="$(profile_bundles 2>/dev/null | paste -sd, -)"
  missing="$(unresolved_bundles "$err" | paste -sd, -)"
  if [ -n "$missing" ]; then
    bad "enabled" "bundle(s) did not resolve: $missing — the pin SKIPPED them and still exited 0, so the composed tree is missing their plugins; remedy: dsh plugin --profile $(dsh_profile) install"
    return 1
  fi
  if [ ! -s "$tree" ]; then
    bad "enabled" "the composed tree is EMPTY — profile $(dsh_profile) declares bundles: ${bundles:-none}"
    return 1
  fi
  entries="$(composed_entries "$tree")"
  disabled="$(composed_disabled_ids "$tree" | paste -sd, -)"
  ok "enabled" "$entries plugin entries composed from ${bundles:-no bundle}; disabled: ${disabled:-none}"
  return 0
}

# ---------------------------------------------------------------- per-layer attribution

# attribute_boot <tree> <stderr> — turns one failed boot into layer rows.
# Measured inputs: (1) "startup failed: N required plugin(s) did not activate" + a
# "Plugins waiting for services (k)" table; (2) "MISSING_CREDENTIAL: … no API key for provider
# route …"; (3) "cannot resolve profile bundle …". Anything else is reported as unattributed with
# the first diagnostic line quoted, never as "dsh is broken".
attribute_boot() {
  local tree="$1" err="$2" required line svc disabled cause rc=1
  required="$(sed -n 's/.*startup failed: \([0-9][0-9]*\) required plugin.*/\1/p' "$err" | head -1)"

  if [ -n "$required" ]; then
    # The waiting table is the per-plugin evidence: plugin -> the services it is missing. The
    # header row ("Plugin … Missing services") is skipped by name, so it can never be read as a
    # plugin that waits on a service called "Missing".
    local pairs="" svc_list="" plugin svc named=""
    while IFS= read -r line; do
      case "$line" in Plugin*|'Missing services'*) continue ;; esac
      plugin="${line%% *}"
      svc="$(printf '%s' "$line" | sed -e 's/.*[[:space:]]\{2,\}//')"
      pairs="$pairs${pairs:+; }${plugin}→${svc}"
      svc_list="$svc_list $svc"
    done < <(awk '
      /^Plugins waiting for services/ { f=1; next }
      f && /^[[:space:]]*$/ { f=0 }
      f && /^  [A-Za-z0-9@._-]/ { line=$0; sub(/^[[:space:]]+/,"",line); print line }
    ' "$err")
    disabled="$(composed_disabled_ids "$tree" | paste -sd, -)"
    cause="service"
    for svc in $(printf '%s' "$svc_list" | tr ' ' '\n' | awk 'NF && !seen[$0]++'); do
      printf '%s\n' "$disabled" | tr ',' '\n' | grep -qx -- "$svc" && { cause="enabled"; named="$named $svc"; }
    done
    case "$cause" in
      enabled)
        bad "layer:enabled" "plugin(s)$named DISABLED in the profile's patch layer ($(profile_dir)/cordis.patch.yml), and $required required plugin(s) did not activate; the pin names what waits on them: $(printf '%s' "$pairs" | cut -c1-220) — re-enable in the patch layer (the pinned tree itself is intact)"
        ;;
      *)
        bad "layer:service" "startup failed: $required required plugin(s) did not activate; the pin names the missing service(s) and the plugins waiting on them: $(printf '%s' "$pairs" | cut -c1-220) — the plugin tree composed ($(composed_entries "$tree") entries), so the gap is a service no composed bundle provides"
        ;;
    esac
    return 1
  fi

  if grep -q 'MISSING_CREDENTIAL' "$err" 2>/dev/null; then
    # The plugin tree mounted and the only refusal is the credential seam: that is a run input,
    # not a broken harness — and it is reported as such.
    ok "layer:service" "plugins mounted; the boot's only refusal is the credential seam — $(sed -n 's/.*MISSING_CREDENTIAL: *//p' "$err" | head -1 | cut -c1-180)"
    return 0
  fi

  if [ -n "$(unresolved_bundles "$err")" ]; then
    bad "layer:resolved" "bundle(s) did not resolve: $(unresolved_bundles "$err" | paste -sd, -) — the launcher loaded a partial plugin tree"
    return 1
  fi

  line="$(grep -v '^[[:space:]]*$' "$err" 2>/dev/null | head -1)"
  bad "layer:unattributed" "the boot failed and this adapter could not place the failure in a layer; first diagnostic line: ${line:-<none>} (diagnostics: $DSH_HOME/logs)"
  return 1
}

# ---------------------------------------------------------------- layer rows for --layers/--turn

# The session record dsh writes for one run: <DSH_HOME>/sessions/--<cwd slug>--/<id>/session.v4.jsonl.zstd
# MEASURED at the pin: v4, one JSON event per line, zstd-compressed. `model_served` lives in
# `assistant/message` -> data.message.source{kind:"model", provider, model}; the turn's outcome in
# `turn/end` -> data.reason.kind; the tool registry in `request/header` -> data.header.tools[];
# the permission surface in `permission/preset` / `approval/policy` / `sandbox/mode`.
session_log_for() {  # session_log_for <session id> -> path, or fails
  local sid="$1" d
  [ -n "$sid" ] || return 1
  d="$(find "$DSH_HOME/sessions" -maxdepth 2 -type d -name "$sid" -print 2>/dev/null | head -1)"
  [ -n "$d" ] || return 1
  find "$d" -maxdepth 1 -name 'session.v*.jsonl.zstd' -print 2>/dev/null | head -1
}

parse_session_log() {  # parse_session_log <zstd path> -> one KEY=VALUE line per measured field
  local z="$1" js dec
  command -v zstd >/dev/null 2>&1 || { note "session_log — zstd is absent, so the record cannot be read"; return 1; }
  js="$(turn_cache_root)/parse-session.js"
  if [ ! -f "$js" ]; then
    mkdir -p "$(turn_cache_root)" 2>/dev/null || return 1
    cat > "$js" <<'JS'
// Reads dsh's session record (one JSON event per line) and prints the fields the adapter records.
// Every field is optional: an absent one prints as an empty value, never as a guess.
const fs = require('fs');
const text = fs.readFileSync(0, 'utf8');
let served = '', provider = '', tools = '', names = '', preset = '', policy = '', sandbox = '', outcome = '', error = '';
for (const line of text.split('\n')) {
  if (!line.trim()) continue;
  let e; try { e = JSON.parse(line); } catch (_) { continue; }
  const d = e && e.data ? e.data : null;
  if (!d) continue;
  if (e.type === 'assistant/message' && d.message && d.message.source && d.message.source.kind === 'model') {
    served = String(d.message.source.model || served);
    provider = String(d.message.source.provider || provider);
  }
  if (e.type === 'request/header' && d.header && Array.isArray(d.header.tools)) {
    tools = String(d.header.tools.length);
    names = d.header.tools.map(t => t && t.name).filter(Boolean).join(',');
    if (d.header.config && !served) served = String(d.header.config.model || '');
    if (d.header.config && !provider) provider = String(d.header.config.provider || '');
  }
  if (e.type === 'permission/preset' && d.preset) preset = String(d.preset);
  if (e.type === 'approval/policy' && d.policy) policy = String(d.policy);
  if (e.type === 'sandbox/mode' && d.mode) sandbox = String(d.mode);
  if (e.type === 'turn/end' && d.reason) {
    outcome = String(d.reason.kind || '');
    if (d.reason.error && d.reason.error.message) error = String(d.reason.error.message).replace(/\s+/g, ' ').slice(0, 240);
  }
}
process.stdout.write(['served=' + served, 'provider=' + provider, 'tools=' + tools, 'toolnames=' + names,
  'preset=' + preset, 'policy=' + policy, 'sandbox=' + sandbox, 'outcome=' + outcome,
  'error=' + error].join('\n') + '\n');
JS
  fi
  dec="$(umask 077; mktemp "$(turn_cache_root)/session.XXXXXXXX")" || return 1
  zstd -dc "$z" > "$dec" 2>/dev/null || { rm -f "$dec"; return 1; }
  "$(have node)" "$js" < "$dec"
  local rc=$?
  rm -f "$dec"
  return $rc
}

session_field() {  # session_field <parsed file> <key>
  sed -n "s/^$2=//p" "$1" 2>/dev/null | head -1
}

# ---------------------------------------------------------------- boot probe (service layer)

# boot_probe <prompt> <out> <err> — one dsh boot with a scrubbed environment. The key, when one is
# supplied, is read from CF_API_KEY_FILE inside the child shell and exported: never argv, never
# logged. Returns the boot's exit code.
boot_probe() {
  local prompt="$1" out="$2" err="$3" prof patch="" keyfile="${CFV_VALUE[CF_API_KEY_FILE]:-}"
  prof="$(dsh_profile)"
  [ -x "$BIN" ] || return 127
  printf -- '- id: agent-default-model\n  config:\n    provider: %s\n    model: %s\n' \
    "$(dsh_route "${CFV_VALUE[CF_PROVIDER]:-}")" "${CFV_VALUE[CF_MODEL]:-deepseek-flash}" > "$BOOT_PATCH" 2>/dev/null
  chmod 600 "$BOOT_PATCH" 2>/dev/null
  patch="$BOOT_PATCH"
  (
    cd "${CFV_VALUE[CF_WORKDIR]:-$HOME}" || exit 1
    unset DEEPSEEK_API_KEY DSH_API_KEY DEEPSEEK_BASE_URL DSH_BASE_URL 2>/dev/null
    if [ -n "$keyfile" ] && [ -s "$keyfile" ]; then
      DEEPSEEK_API_KEY="$(cat "$keyfile")"; export DEEPSEEK_API_KEY
      [ -n "${CFV_VALUE[CF_BASE_URL]:-}" ] && { DEEPSEEK_BASE_URL="${CFV_VALUE[CF_BASE_URL]}"; export DEEPSEEK_BASE_URL; }
    fi
    if [ -n "$patch" ] && [ -s "$patch" ]; then
      DSH_HOME="$DSH_HOME" timeout "$PROBE_TIMEOUT_S" "$BIN" "$prof" --patch "$patch" --json "$prompt" >"$out" 2>"$err" </dev/null
    else
      DSH_HOME="$DSH_HOME" timeout "$PROBE_TIMEOUT_S" "$BIN" "$prof" --json "$prompt" >"$out" 2>"$err" </dev/null
    fi
  )
}

# ---------------------------------------------------------------- the contract (matrix §5)

# The §5 set is validated by harness-vars.sh; this adds the one ambient name THIS harness reads.
# harness-vars.sh's cfv_env_value only reads the twelve declared names plus the two provider keys
# the matrix names (CF_API_KEY / OPENAI_API_KEY / ANTHROPIC_API_KEY), so the DeepSeek names are read
# explicitly here rather than widening that shared implementation.
contract_extras() {
  local v val
  for v in DEEPSEEK_API_KEY DSH_API_KEY; do
    case "$v" in
      DEEPSEEK_API_KEY) val="${DEEPSEEK_API_KEY:-}" ;;
      DSH_API_KEY) val="${DSH_API_KEY:-}" ;;
    esac
    if [ -n "$val" ]; then
      cfv_fail "contract:ambient" \
        "refused — $v is set in the ambient environment; dsh reads it from the launching environment, so a lane that exported it would silently become the credential source. unset $v and pass CF_API_KEY_FILE=<path> (matrix §5)"
    fi
  done
  # CF_HARNESS_OPTS profile=<name>: the run profile is an option, so it is recorded, not inferred.
  v="${CFV_VALUE[CF_HARNESS_OPTS]:-}"
  case ",$v," in
    *,profile=*)
      local p; p="$(printf '%s' "$v" | tr ',' '\n' | sed -n 's/^profile=//p' | head -1)"
      if [ -n "$p" ]; then
        printf '%s' "$p" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$' \
          || cfv_fail "contract:CF_HARNESS_OPTS" "refused — profile='$p' is not a profile name ([A-Za-z0-9._-])"
      fi
      ;;
  esac
}

# The §5 run set, required by --turn (a turn is a run) and validated when present everywhere else.
require_run_set() {
  local k missing=""
  for k in "${CFV_REQUIRED[@]}"; do
    [ -n "${CFV_VALUE[$k]:-}" ] || missing="$missing $k"
  done
  if [ -n "$missing" ]; then
    cfv_fail "contract:required" "refused — --turn needs the §5 run set; missing:$missing"
    return 1
  fi
  return 0
}

check_workdir() {
  local dir="${CFV_VALUE[CF_WORKDIR]:-}" real work
  [ -n "$dir" ] || return 0
  real="$(cd "$dir" 2>/dev/null && pwd -P)" || real=""
  [ -n "$real" ] || { cfv_fail "workdir" "refused — CF_WORKDIR does not exist: $dir"; return 1; }
  work="$(cd "$HOME" 2>/dev/null && pwd -P)"
  case "$real" in
    "$work"/*) return 0 ;;
    *) cfv_fail "workdir" "refused — $real is outside \$HOME ($work)"; return 1 ;;
  esac
}

# ---------------------------------------------------------------- provenance

# The registry is the only authority for "the pin is the pin": a version string alone does not say
# which bytes it serves. Both digests recorded at the top are compared.
provenance_check() {
  local meta version integrity shasum node_bin
  node_bin="$(have node)" || { bad "provenance" "refused — node is absent, so the registry metadata cannot be parsed"; return 1; }
  if ! meta="$(npm view "$DSH_PKG@$DSH_PIN" version dist.integrity dist.shasum --json 2>/dev/null)" || [ -z "$meta" ]; then
    bad "provenance" "refused — registry metadata for $DSH_PKG@$DSH_PIN is unreachable, so the pin cannot be confirmed"
    return 1
  fi
  # `npm view` answers with literal dotted keys ("dist.integrity"), not a nested object; accept both.
  version="$(printf '%s' "$meta" | "$node_bin" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{process.stdout.write(String(JSON.parse(s).version||""))}catch(e){}})')"
  integrity="$(printf '%s' "$meta" | "$node_bin" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(String(j["dist.integrity"]||(j.dist&&j.dist.integrity)||""))}catch(e){}})')"
  shasum="$(printf '%s' "$meta" | "$node_bin" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(String(j["dist.shasum"]||(j.dist&&j.dist.shasum)||""))}catch(e){}})')"
  if [ "$version" != "$DSH_PIN" ]; then
    bad "provenance" "refused — the registry serves version '$version' for the pin $DSH_PIN"
    return 1
  fi
  if [ "$integrity" != "$DSH_INTEGRITY" ]; then
    bad "provenance" "refused — dist.integrity for $DSH_PKG@$DSH_PIN is not the recorded one (recorded ${DSH_INTEGRITY:0:24}…, registry ${integrity:0:24}…) — the pin's bytes changed"
    return 1
  fi
  if [ "$shasum" != "$DSH_SHASUM" ]; then
    bad "provenance" "refused — dist.shasum mismatch (recorded $DSH_SHASUM, registry $shasum)"
    return 1
  fi
  ok "provenance" "$DSH_PKG@$DSH_PIN — registry integrity + shasum match the recorded pin; upstream $DSH_UPSTREAM"
}

# ---------------------------------------------------------------- --apply

scaffold_profile() {
  local prof dir
  prof="$(dsh_profile)"; dir="$(profile_dir)"
  if [ -d "$dir" ]; then
    note "profile $prof already scaffolded at $dir — left untouched (a patch layer is user state)"
    return 0
  fi
  DSH_HOME="$DSH_HOME" "$BIN" --profile "$prof" --dump-config >/dev/null 2>&1
  if [ -d "$dir" ]; then
    ok "profile" "$dir scaffolded by the pinned launcher (profile $prof)"
  else
    bad "profile" "the pinned launcher did not scaffold $dir"
    return 1
  fi
}

do_apply() {
  local v out err log rc target
  if [ "$(id -u)" -eq 0 ]; then
    bad "root" "refused — this installer is user-space; run it as the owning user, never as root"
    return 1
  fi
  probe_prefix || return 1

  v="$(bin_version "$BIN" 2>/dev/null)" || v=""
  if [ -x "$BIN" ] && [ "$v" = "$DSH_PIN" ]; then
    note "already installed at pin $DSH_PIN — nothing to do (idempotent)"
    probe_package || true
    ok "binary" "$BIN"
    probe_version "$BIN" || true
    probe_resolved || true
    scaffold_profile || true
    return 0
  fi
  [ -x "$BIN" ] && note "installed launcher reports ${v:-unreadable} != pin $DSH_PIN — installing the pin over it"

  probe_node || return 1
  local npm_bin; npm_bin="$(have npm)" || { bad "npm" "absent — the pin is an npm package"; return 1; }
  require_disk "$HOME" "$DISK_FLOOR_GB" || return 1
  provenance_check || return 1

  log="$(umask 077; mktemp "$(turn_cache_root)/npm.XXXXXXXX.log" 2>/dev/null)" \
    || { mkdir -p "$(turn_cache_root)"; log="$(umask 077; mktemp "$(turn_cache_root)/npm.XXXXXXXX.log")"; } \
    || { bad "install" "cannot create a private npm log under $(turn_cache_root)"; return 1; }
  say "  ..    npm install --global --prefix $PREFIX $DSH_PKG@$DSH_PIN"
  # An explicit --prefix on every call: the global prefix is ambient state (a ~/.npmrc can point it
  # anywhere), and honouring it would install outside $HOME. npm verifies the registry's integrity
  # for the tarball itself; provenance_check above proves the recorded pin is what it will fetch.
  "$npm_bin" install --global --prefix "$PREFIX" --no-fund --no-audit --loglevel=error \
    "$DSH_PKG@$DSH_PIN" >"$log" 2>&1
  rc=$?
  if [ "$rc" -ne 0 ]; then
    bad "install" "npm exited $rc — log: $log"
    sed -n '1,12p' "$log" | sed 's/^/        /'
    return 1
  fi
  ok "install" "npm exited 0 ($(sed -n 's/^added \([0-9]*\) packages.*/\1/p' "$log" | head -1) packages)"
  rm -f "$log"

  probe_package || return 1
  v="$(bin_version "$BIN")" || v=""
  if [ "$v" = "$DSH_PIN" ]; then
    ok "version_readback" "$("$BIN" --version 2>/dev/null | head -1) — matches pin $DSH_PIN"
  else
    bad "version_readback" "${v:-unreadable} != pin $DSH_PIN after install"
    return 1
  fi
  probe_resolved || return 1
  scaffold_profile || return 1

  # The composed tree is part of the install claim: a pin that installs but composes nothing is an
  # installed package, not a usable harness.
  out="$(umask 077; mktemp "$(turn_cache_root)/compose.XXXXXXXX")"
  err="$(umask 077; mktemp "$(turn_cache_root)/compose-err.XXXXXXXX")"
  if compose_readonly "$(dsh_profile)" "$out" "$err"; then
    report_enabled "$out" "$err" || true
  else
    bad "enabled" "the pinned launcher could not compose profile '$(dsh_profile)'"
  fi
  rm -f "$out" "$err"

  ok "footprint" "$PREFIX — $(du -sh "$PREFIX" 2>/dev/null | cut -f1) under \$HOME (618 packages measured)"
  case ":$PATH:" in
    *":$PREFIX/bin:"*) ok "path_env" "$PREFIX/bin is on PATH" ;;
    *) note "path_env — $PREFIX/bin is not on PATH; add it, or call $BIN by path (the conformance battery resolves the adapter's own binary row)" ;;
  esac
  return 0
}

# ---------------------------------------------------------------- --turn

do_turn() {
  local keyfile prompt_file="" prof prompt out err rc sid log parsed file served requested got
  if [ ! -x "$BIN" ] || [ "$(bin_version "$BIN" 2>/dev/null || echo '')" != "$DSH_PIN" ]; then
    bad "turn" "refused — the pin is not installed at $BIN; run --apply first"
    return 1
  fi
  keyfile="${CFV_VALUE[CF_API_KEY_FILE]:-}"
  if [ -z "$keyfile" ] || [ ! -s "$keyfile" ]; then
    say "  SKIP  turn — no credential to run with. Missing: CF_API_KEY_FILE (a mode-600 path; dsh reads DEEPSEEK_API_KEY from its launching environment, and an exported one is refused as ambient)"
    SKIPPED=1
    return 0
  fi
  require_run_set || return 1
  prof="$(dsh_profile)"

  # The caller's directive (argv, a file, or stdin) is the TASK. The artifact instruction is then
  # APPENDED, so a turn is always measurable by bytes even when the caller's task says nothing about
  # a file: an adapter that trusted the caller's prompt for its own evidence could report a turn as
  # served without ever seeing an artifact. No caller directive at all is legitimate — the turn is
  # then the artifact instruction alone.
  if [ -n "$PROMPT_FILE" ]; then
    [ -r "$PROMPT_FILE" ] || { bad "turn" "cannot read --prompt-file $PROMPT_FILE"; return 1; }
    prompt_file="$PROMPT_FILE"
  elif [ -z "$PROMPT" ] && [ ! -t 0 ]; then
    prompt_file="$(umask 077; mktemp "$(turn_cache_root)/prompt.XXXXXXXX")" \
      || { mkdir -p "$(turn_cache_root)"; prompt_file="$(umask 077; mktemp "$(turn_cache_root)/prompt.XXXXXXXX")"; } \
      || { bad "turn" "cannot stage stdin"; return 1; }
    cat > "$prompt_file" || { bad "turn" "cannot read stdin"; return 1; }
  fi

  file="${CFV_VALUE[CF_WORKDIR]}/$TURN_FILE"
  rm -f "$file"
  if [ -n "$prompt_file" ]; then
    prompt="$(cat "$prompt_file")"
  else
    prompt="$PROMPT"
  fi
  {
    [ -n "$prompt" ] && printf '%s\n\n' "$prompt"
    printf 'Create a file named %s in the current working directory whose entire content is exactly this one line and nothing else: %s\n' \
      "$TURN_FILE" "$TURN_TOKEN"
  } > "$(turn_cache_root)/directive.txt"
  prompt="$(cat "$(turn_cache_root)/directive.txt")"
  [ -n "$prompt" ] || { bad "turn" "cannot stage the directive"; return 1; }

  out="$(umask 077; mktemp "$(turn_cache_root)/turn-out.XXXXXXXX")" || { bad "turn" "cannot stage stdout"; return 1; }
  err="$(umask 077; mktemp "$(turn_cache_root)/turn-err.XXXXXXXX")" || { bad "turn" "cannot stage stderr"; return 1; }
  requested="${CFV_VALUE[CF_MODEL]}"
  say "  ..    turn: $DSH_PKG@$DSH_PIN profile $prof in ${CFV_VALUE[CF_WORKDIR]} (model $requested, provider $(dsh_route "${CFV_VALUE[CF_PROVIDER]}"), timeout ${TIMEOUT_S}s)"
  BOOT_PATCH="$(turn_cache_root)/model-overlay.$RANDOM.yml"
  PROBE_TIMEOUT_S="$TIMEOUT_S"
  boot_probe "$prompt" "$out" "$err"
  rc=$?
  rm -f "$BOOT_PATCH"

  sid="$(sed -n 's/.*"type":"session","sessionId":"\([^"]*\)".*/\1/p' "$out" 2>/dev/null | head -1)"
  if [ "$rc" -ne 0 ]; then
    bad "turn" "exit $rc — $(grep -v '^[[:space:]]*$' "$err" 2>/dev/null | head -1 | cut -c1-240)"
    # A failed run is diagnosed per layer, and the tree it composed is quoted in the row.
    local tree; tree="$(umask 077; mktemp "$(turn_cache_root)/tree.XXXXXXXX")"
    compose_readonly "$prof" "$tree" "$err.compose" 2>/dev/null || true
    attribute_boot "$tree" "$err" || true
    rm -f "$tree" "$err.compose"
    rm -f "$out" "$err"
    return 1
  fi
  ok "turn_exit" "exit 0"

  # model_served comes from dsh's own session record, located by the session id in its --json stream.
  log="$(session_log_for "$sid")" || log=""
  if [ -z "$log" ]; then
    warn "model_served" "requested $requested → recorded unknown: no session record under $DSH_HOME/sessions for ${sid:-<no session id in the --json stream>}"
  else
    parsed="$(umask 077; mktemp "$(turn_cache_root)/parsed.XXXXXXXX")"
    if parse_session_log "$log" > "$parsed" 2>/dev/null; then
      served="$(session_field "$parsed" served)"
      if [ -n "$served" ]; then
        ok "model_served" "requested $requested → recorded $served (provider $(session_field "$parsed" provider); dsh logs ONE model id per request, so 'recorded' is the honest word — specs/HARNESS-MEMORY.md §3.6)"
      else
        warn "model_served" "requested $requested → recorded model absent from $log"
      fi
      ok "turn_outcome" "dsh's own record: turn/end reason.kind=$(session_field "$parsed" outcome)"
      local ntools names
      ntools="$(session_field "$parsed" tools)"; names="$(session_field "$parsed" toolnames)"
      if [ -n "$ntools" ] && [ "$ntools" != "0" ]; then
        ok "tool" "$ntools tool(s) registered for the run: $(printf '%s' "$names" | cut -c1-160)"
      else
        warn "tool" "the session record carries no tool registry for this run (the run stopped before a model request)"
      fi
      ok "permission" "session record: permission/preset=$(session_field "$parsed" preset), approval/policy=$(session_field "$parsed" policy), sandbox/mode=$(session_field "$parsed" sandbox)"
    else
      warn "model_served" "requested $requested → the session record at $log could not be read"
    fi
    rm -f "$parsed"
  fi

  if [ -f "$file" ]; then
    got="$(tr -d '\r' <"$file" | sed -e 's/[[:space:]]*$//')"
    if [ "$got" = "$TURN_TOKEN" ]; then
      ok "artifact" "${CFV_VALUE[CF_WORKDIR]}/$TURN_FILE contains the fixed token (sha256 $(sha256sum "$file" | cut -d' ' -f1))"
    else
      bad "artifact" "$file does not contain the fixed token"
    fi
  else
    bad "artifact" "$file was not written (exit 0 is not evidence — the artifact is)"
  fi

  say "record harness=dsh harness_version=$DSH_PIN model_requested=$requested model_recorded=${served:-unknown} run_id=${CFV_VALUE[CF_RUN_ID]} lane=${CFV_VALUE[CF_LANE]} namespace=${CFV_VALUE[CF_NAMESPACE]} workdir=${CFV_VALUE[CF_WORKDIR]}"
  say "record memory=not-written (leg 'memory' belongs to the foreman; this adapter echoes the fields it must hand over)"
  rm -f "$out" "$err"
  return 0
}

# ---------------------------------------------------------------- --layers

do_layers() {
  local prof tree err err2 out rc sid log parsed
  prof="$(dsh_profile)"
  say "layers: package -> resolved -> enabled -> service -> tool -> permission (profile $prof)"
  mkdir -p "$(turn_cache_root)"

  # 1. package
  if probe_package; then
    local missing_bundles="" b
    for b in $(profile_bundles 2>/dev/null); do
      [ -d "$PKG_DIR/node_modules/$b" ] || [ -d "$PREFIX/lib/node_modules/$b" ] || missing_bundles="$missing_bundles $b"
    done
    if [ -n "$missing_bundles" ]; then
      bad "layer:package" "bundle package(s) absent from the installed tree:$missing_bundles — the launcher will SKIP them and still exit 0"
      say "  ..    layer:resolved, layer:enabled, layer:service, layer:tool, layer:permission — not measured: the package layer failed (a bundle that is not installed cannot be composed, so a boot would measure a partial tree, not this harness)"
      return 1
    else
      ok "layer:package" "$(pkg_identity) present; the profile's bundle package(s) resolve in the installed tree ($(profile_bundles 2>/dev/null | paste -sd, -))"
    fi
  else
    say "  ..    layer:resolved, layer:enabled, layer:service, layer:tool, layer:permission — not measured: the package layer failed (nothing to boot)"
    return 1
  fi

  # 2. resolved
  if probe_resolved && probe_version "$BIN"; then
    :
  else
    say "  ..    layer:enabled, layer:service, layer:tool, layer:permission — not measured: the resolved layer failed"
    return 1
  fi

  # 3. enabled
  tree="$(umask 077; mktemp "$(turn_cache_root)/tree.XXXXXXXX")"
  err="$(umask 077; mktemp "$(turn_cache_root)/tree-err.XXXXXXXX")"
  if ! compose_readonly "$prof" "$tree" "$err"; then
    bad "layer:enabled" "the launcher could not compose profile '$prof' ($(profile_dir)) — a layer that cannot compose cannot boot"
    say "  ..    layer:service, layer:tool, layer:permission — not measured: the enabled layer failed"
    rm -f "$tree" "$err"
    return 1
  fi
  if ! report_enabled "$tree" "$err"; then
    say "  ..    layer:service, layer:tool, layer:permission — not measured: the enabled layer failed"
    rm -f "$tree" "$err"
    return 1
  fi

  # 4. service — one boot. With a credential the boot answers; without one the boot's own refusal is
  # the measurement, because a credential seam refusal proves the plugin tree mounted.
  out="$(umask 077; mktemp "$(turn_cache_root)/probe-out.XXXXXXXX")"
  err2="$(umask 077; mktemp "$(turn_cache_root)/probe-err.XXXXXXXX")"
  BOOT_PATCH="$(turn_cache_root)/model-overlay.$RANDOM.yml"
  boot_probe "Reply with exactly: DSH-LAYER-PROBE. Do not use tools." "$out" "$err2"
  rc=$?
  rm -f "$BOOT_PATCH"
  if [ "$rc" -eq 0 ]; then
    ok "layer:service" "one boot answered (exit 0); the plugin tree mounted and the LLM route $(dsh_route "${CFV_VALUE[CF_PROVIDER]:-}") served a request"
  else
    attribute_boot "$tree" "$err2" || {
      say "  ..    layer:tool, layer:permission — not measured: the service layer failed"
      rm -f "$tree" "$err" "$out" "$err2"
      return 1
    }
  fi

  # 5+6. tool and permission — from the run's own session record. A credential-free probe that
  # failed at the credential seam has no request header, so the newest record is used when one
  # exists and the absence is named when none does.
  sid="$(sed -n 's/.*"type":"session","sessionId":"\([^"]*\)".*/\1/p' "$out" 2>/dev/null | head -1)"
  log="$(session_log_for "$sid" 2>/dev/null)" || log=""
  if [ -z "$log" ]; then
    log="$(find "$DSH_HOME/sessions" -name 'session.v*.jsonl.zstd' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"
  fi
  if [ -z "$log" ]; then
    say "  ..    layer:tool, layer:permission — not measured: no session record under $DSH_HOME/sessions (a credential is needed for one)"
  else
    parsed="$(umask 077; mktemp "$(turn_cache_root)/parsed.XXXXXXXX")"
    if parse_session_log "$log" > "$parsed" 2>/dev/null; then
      local ntools preset policy sandbox
      ntools="$(session_field "$parsed" tools)"; preset="$(session_field "$parsed" preset)"
      policy="$(session_field "$parsed" policy)"; sandbox="$(session_field "$parsed" sandbox)"
      if [ -n "$ntools" ] && [ "$ntools" != "0" ]; then
        ok "layer:tool" "$ntools tool(s) in the run's request header (record: ${log#"$DSH_HOME"/})"
      else
        say "  ..    layer:tool — no request header in the newest record (${log#"$DSH_HOME"/}): the run stopped before a model request, so the tool registry was never measured"
      fi
      if [ -n "$preset" ] && [ "$preset" != "0" ]; then
        ok "layer:permission" "permission/preset=$preset, approval/policy=$policy, sandbox/mode=$sandbox — measured, not inherited: dsh recorded them on the session"
      else
        say "  ..    layer:permission — no permission events in the newest record"
      fi
    else
      say "  ..    layer:tool, layer:permission — the record at ${log#"$DSH_HOME"/} could not be read (zstd/node)"
    fi
    rm -f "$parsed"
  fi
  rm -f "$tree" "$err" "$out" "$err2"
  return 0
}

# ---------------------------------------------------------------- --pin-status

do_pin_status() {
  local node_bin tags latest meta version integrity shasum
  node_bin="$(have node)" || { bad "pin_status" "node is absent, so registry metadata cannot be parsed"; return 1; }
  if ! tags="$(npm view "$DSH_PKG" dist-tags --json 2>/dev/null)" || [ -z "$tags" ]; then
    bad "pin_status" "the registry is unreachable — the RC pin cannot be re-measured from here ($DSH_PKG)"
    return 1
  fi
  latest="$(printf '%s' "$tags" | "$node_bin" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{process.stdout.write(String(JSON.parse(s).latest||""))}catch(e){}})')"
  ok "dist_tags" "latest=$latest pin=$DSH_PIN$([ "$latest" = "$DSH_PIN" ] && printf ' (the pin is the newest RC)' || printf ' (a NEWER RC exists)')"
  if provenance_check; then
    ok "pin_status" "the registry still serves the recorded bytes for $DSH_PIN, so the pin is unchanged; re-measure again before promoting it"
  else
    return 1
  fi
  if [ "$latest" != "$DSH_PIN" ]; then
    say "  ..    adopting $latest = edit DSH_PIN, DSH_SHASUM and DSH_INTEGRITY together in scripts/harness/install-dsh.sh, then re-run --apply, --layers and --turn and record the measurement in specs/HARNESS.md"
  fi
  return 0
}

# ---------------------------------------------------------------- main

say "harness: dsh ($DSH_PKG pin $DSH_PIN, profile $(dsh_profile), state $DSH_HOME)"
say "  note: the pin is an RC — re-measure it with --pin-status (registry integrity + a newer-RC check)"

mkdir -p "$(turn_cache_root)" 2>/dev/null || true

# Every mode validates the §5 set; --turn additionally requires the run set, because a turn is a run.
cfv_validate "$([ "$MODE" = "--turn" ] && printf 'contract' || printf '%s' "$CFV_MODE")"
contract_extras
check_workdir
if [ "$MODE" = "--turn" ]; then require_run_set; fi
if cfv_refused; then
  say ""
  say "DSH: FAIL ($CFV_FAILED) — contract refused; nothing was installed or run"
  exit 2
fi
if [ "$MODE" = "--contract" ]; then
  say ""
  say "DSH: CONTRACT PASS — the §5 set is accepted (specs/HARNESS-MATRIX.md §5); nothing installed, nothing run"
  exit 0
fi

case "$MODE" in
  --check)
    probe_node || true
    probe_npm
    probe_prefix || true
    probe_package || true
    probe_binary || true
    if [ -x "$BIN" ]; then probe_version "$BIN" || true; fi
    probe_resolved || true
    probe_profile || true
    # The composed plugin tree: this is what a "plugin-layer failure" would be failing in, so
    # --check measures it instead of asserting the harness works.
    if [ -x "$BIN" ] && [ -d "$(profile_dir)" ]; then
      tree="$(umask 077; mktemp "$(turn_cache_root)/check-tree.XXXXXXXX")"
      terr="$(umask 077; mktemp "$(turn_cache_root)/check-tree-err.XXXXXXXX")"
      if compose_readonly "$(dsh_profile)" "$tree" "$terr"; then
        report_enabled "$tree" "$terr" || true
      else
        bad "enabled" "the launcher could not compose profile '$(dsh_profile)'"
      fi
      rm -f "$tree" "$terr"
    else
      say "  ..    enabled — not measured: the package/profile layers above are absent (run --apply)"
    fi
    if [ -n "${CFV_VALUE[CF_API_KEY_FILE]:-}" ]; then
      say "  ..    auth — CF_API_KEY_FILE is a path (content not read); --turn exports it to the child as DEEPSEEK_API_KEY and never puts it on a command line"
    else
      say "  ..    auth — no credential (a credential is a RUN input, not an install condition; --turn will SKIP and name it)"
    fi
    say ""
    verdict DSH
    exit $?
    ;;

  --apply)
    do_apply || true
    say ""
    verdict DSH action
    exit $?
    ;;

  --turn)
    do_turn || true
    say ""
    if [ "${SKIPPED:-0}" -eq 1 ]; then
      say "DSH: SKIP (no credential — nothing measured, nothing claimed)"
      exit 3
    fi
    verdict DSH action
    exit $?
    ;;

  --layers)
    do_layers || true
    say ""
    verdict DSH action
    exit $?
    ;;

  --pin-status)
    do_pin_status || true
    say ""
    verdict DSH action
    exit $?
    ;;

  *)
    bad "mode" "unknown mode '$MODE'"
    say ""
    verdict DSH action
    exit $?
    ;;
esac
