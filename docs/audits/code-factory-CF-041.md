# CF-041 audit — README quick start, executed literally

Task: CF-041, "Quick start documented path fails as written: env-ordering, a nonexistent `--agent`
flag, and an adapter list the repo does not ship".

Evaluated tree: `9880018d224fd6a2dc6bbaa092214d0bddae08d0` (published `origin/main` at the time of the
sweep; the same tip the row's own provenance tree `0959258` is an ancestor of).

Tick: `code-factory-readme-2026-11-03-12-46-13`.

## Method

The tree was exported with `git archive origin/main` into a throwaway directory (`$SCRATCH/src`,
99 files) so no working tree or checkout state could contribute to the result. Every command below is
copied verbatim from `README.md` § Quick start, and each was run under an isolated `HOME` with exactly
the two exports the README prints on the lines above them:

    export CRIER_URL=http://crier.example:8767
    export BUNKER_SERVER=your-bunker-server

Exit codes are quoted from the command itself, never from a pipeline.

Outcome: **CF-041's three reported defects do not reproduce at this tree.** The quick start the row
describes is not the quick start the repository ships — the row's own provenance commit `0959258`
already carried the text below (the README quick-start block is byte-identical between `0959258` and
`9880018`).

## Claim 1 — "step 1 aborts on an unset `BUNKER_SERVER`"

Measured, README step 1 as printed (exports present):

    scripts/bunker-server-install.sh --check

    bunker server: your-bunker-server
      PASS  bunker_client — /usr/local/bin/bunker bunker 0.2.0
      FAIL  bunker_config — missing ($HOME/.config/bunker/config.yaml) — the client has no server to talk to
      FAIL  server_reachable — your-bunker-server did not answer: bunker: reading server "your-bunker-server"
      PASS  tool:python3 — /usr/bin/python3
      PASS  tool:git — /usr/bin/git
      PASS  tool:curl — /usr/bin/curl
      PASS  tool:jq — /usr/bin/jq
      PASS  disk — 142.8 GB free (floor 5 GB)

    RESULT: FAIL (2)

Exit code 1. This is a real check line with the measured missing values named, which is what the README
promises ("fail with the missing value named"). Not a defect.

The bare abort the row quotes (*"line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name"*)
is reproducible only when the two exports the README prints three lines earlier are dropped:

    scripts/bunker-server-install.sh --check      # without the README exports
    scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name

Exit code 1. A reader who skips a printed `export` is not following the documented path.

## Claim 2 — "step 2 is printed with a `--agent` flag `project-node.sh` rejects"

README step 2, as shipped at both `0959258` and `9880018`:

    ./scripts/project-node.sh --check --project myproject

    node provisioning — project=myproject harness=hermes host=<host>
    [00] preflight
      PASS  arch — x86_64 (Linux 7.0.0-38-generic)
      PASS  role — worker (floor 5 GiB from role-default)
      PASS  disk — 142.8 GB free (floor 5 GB)
      PASS  mem — 44338 MB
      FAIL  reach:http://crier.example:8767/health — -> 000
      PASS  reach:https://pypi.org/simple/ — 200
    [10] base
      ... (tool checks)
    [20] harness
    harness: hermes (pin 0.19.0, port 10800)
      FAIL  python — hermes-agent 0.19.0 requires python >=3.11,<3.14; found 3.14.4
    [30] bus
      FAIL  crier_identity — absent — stage a bundle and re-run; a node without an identity is invisible
    [40] repo
      FAIL  repo — $HOME/repo absent (pass --repo to clone)
    [90] manifest
      ..    manifest is written only when every layer passes

    NODE: FAIL (3)

Exit code 1 — an honest fresh-host result with every gap named. `--agent` is not printed by the README;
it belongs to `verify-node.sh` and `node-create.sh`. Running it proves the flag is indeed rejected
(the row's observation, but of a command the README never documents):

    ./scripts/project-node.sh --check --agent cf-dogfood-probe
    unknown arg: --agent

Exit code 2.

## Claim 3 — "Layout claims six adapters, the repo ships three"

README § Layout at this tree:

    scripts/harness/ install-<harness>.sh — shipped: hermes, claude-code, opencode.
                     codex, aider, goose and pi-agent are documented in specs/HARNESS.md and ship
                     no installer yet (CF-006)

`git ls-tree scripts/harness/` returns exactly `install-claude-code.sh`, `install-hermes.sh`,
`install-opencode.sh` — three, matching the claim's "shipped:" list. `specs/HARNESS.md` mentions
`codex`, `aider`, `goose` and `pi-agent` once each, which is what the line points at. The six-adapter
list the row describes is the pre-CF-006 wording; it is not in this tree.

## Claim 4 (row acceptance) — step 3 reaches a checker

    scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes

    node-create — project=myrepo harness=hermes server=your-bunker-server
      ..    spawning node-myrepo-074801 (ttl 6h)
      FAIL  spawn — bunker: server "your-bunker-server" not found in config

Exit code 1, missing value named. The README's sentence "all three commands reach their checkers and
fail with the missing value named" holds for all three on a host with no bunker server, no Crier and
no repo — which is the state this sweep ran in.

## Selftest

    bash tests/selftest.sh

    ...
    13. node provisioning names its resolved floor and refuses below it
      PASS  malformed floor refused before install

    SELFTEST: PASS

Exit code 0.

## Defect that is still live (filed separately)

`verify-node.sh`'s usage line cannot be reached without `BUNKER_SERVER`, because the variable is
expanded with the `${VAR:?}` abort form before argument parsing:

    ./scripts/verify-node.sh --help
    ./scripts/verify-node.sh: line 17: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name

Exit code 1. `bunker-server-install.sh` behaves the same way at line 14, but there the README supplies
the export; `verify-node.sh` has no README coverage and no way to print its own usage. Filed as CF-063.

## What this sweep did not exercise

- No real bunker server, Crier instance or node existed, so only the fresh-host failure paths were
  measured. Every `PASS` above is a local host check; no live node, gateway, or bus round trip is
  claimed.
- `--apply` install paths were not run (no network installs on this host).
- The status table's historical clone figure was not re-measured; it is covered by the published
  audit `docs/audits/code-factory-readme-2026-10-30-20-29-25.md`.
