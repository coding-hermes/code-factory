#!/usr/bin/env bash
set -u
set -o pipefail
repo=$(pwd)
scratch=$(mktemp -d /var/tmp/code-factory-readme-20261030-110314.XXXXXX)
run() {
  name=$1
  shift
  printf '\n### %s\n$' "$name"
  printf ' %q' "$@"
  printf '\n'
  set +e
  output=$("$@" 2>&1)
  rc=$?
  set -e
  printf '%s\n' "$output"
  printf 'RC=%s\n' "$rc"
}
cd "$repo"
run quickstart-bunker-check env -u BUNKER_SERVER HOME="$scratch" bash scripts/bunker-server-install.sh --check
run quickstart-project-node env -u BUNKER_SERVER -u CRIER_URL HOME="$scratch" bash scripts/project-node.sh --check --project '<project>'
run selftest env HOME="$scratch" bash tests/selftest.sh
run configured-bunker-check env HOME="$scratch" BUNKER_SERVER=your-bunker-server bash scripts/bunker-server-install.sh --check
run node-create-refusal env HOME="$scratch" BUNKER_SERVER=your-bunker-server CRIER_URL=http://crier.example:8767 bash scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes
run hermes-check env HOME="$scratch" bash scripts/harness/install-hermes.sh --check
run opencode-check env HOME="$scratch" bash scripts/harness/install-opencode.sh --check
run claude-check env HOME="$scratch" bash scripts/harness/install-claude-code.sh --check
printf '\n### tracked-harness-files\n'
git ls-tree -r --name-only HEAD scripts/harness
printf '\n### readme-fences\n'
grep -n '^```' README.md
printf '\n### env-read-sites\n'
grep -RhoE '\$\{?[A-Z][A-Z0-9_]{2,}' scripts --include='*.sh' | sort -u
printf '\n### scratch-home\n%s\n' "$scratch"
