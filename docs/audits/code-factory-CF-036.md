# CF-036 verification audit

Task: make the pinned Hermes installer fail clearly on unsupported Python versions.

The commands below were run from the repository checkout after the source changes and before the containing fix commit was created. The source baseline before this change was `896afada91dea44eee0c5ae7d3a3c49146cbd2ff`; this file is committed with the fix and is the fixed-tip evidence artifact.

## Syntax

Command:

    bash -n scripts/harness/install-hermes.sh tests/selftest.sh

Result: exit 0, no output.

## Selftest

Command:

    bash tests/selftest.sh

Exact output:

    1. every script parses
      PASS  bash -n bunker-server-install.sh
      PASS  bash -n lib.sh
      PASS  bash -n node-create.sh
      PASS  bash -n project-node.sh
      PASS  bash -n verify-node.sh
      PASS  bash -n install-claude-code.sh
      PASS  bash -n install-hermes.sh
      PASS  bash -n install-opencode.sh
      PASS  bash -n selftest.sh
    2. the node checker FAILS on an empty PATH
      PASS  empty PATH -> exit 1
      PASS  report contains FAIL rows
    3. unreachable Crier reports one HTTP status code
      PASS  unreachable URL -> one 000 status
    4. clone errors distinguish missing refs from repository access
      PASS  missing ref names main and --ref without a private-repo hint
      PASS  repository access failure retains deploy-key hint
    5. fetch_verified refuses a wrong digest
      PASS  correct digest accepted
    digest mismatch for file:///var/tmp/hermes-scratch/tmp.RVSp3t6d5Y/src: want 0000000000000000000000000000000000000000000000000000000000000000 got 5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03
      PASS  wrong digest refused
    6. no literal credential assignments
      PASS  none found
    7. the board is valid JSONL
      PASS  24/24 rows parse
    8. project board entrypoint is real and fails closed without dependency
      PASS  bash -n scripts/boardctl
      PASS  local help
      PASS  missing boardctl -> explicit FAIL, exit 127
    9. every prompt file the README relies on exists
      PASS  every prompts/*.md named by README.md exists
      PASS  absent prompt refused (absent: prompts/ghost-lane.md)
    10. Hermes refuses an unsupported Python without pip or network
      PASS  Python 3.14 refusal names the supported range without pip

    SELFTEST: PASS

Exit status: 0.

The CF-036 fixture injects `HERMES_PYTHON_BIN` with a local mock that answers only `Python 3.14.9` to `--version` and fails any other invocation. Therefore the refusal is exercised without creating a venv, invoking pip, or accessing the network.

## Installer check

Command:

    HOME="$(mktemp -d)" scripts/harness/install-hermes.sh --check

Exact output on the host's Python 3.14.9 interpreter:

    harness: hermes (pin 0.19.0, port 10800)
      FAIL  python — hermes-agent 0.19.0 requires python >=3.11,<3.14; found 3.14.9

Exit status: 1.

The installer now performs this fail-closed interpreter check before the binary, gateway, provider-key, venv, or pip paths. The supported range is stated in `README.md` and `specs/HARNESS.md`.

ch:trace row=CF-036 spec=scripts/harness/install-hermes.sh#pin wave=none:serial test=tests/selftest.sh::hermes-unsupported-python doc=README.md evidence=docs/audits/code-factory-CF-036.md witness=none:local-python-3.14.9-and-network-free-fixture verdict=none:open-finding commit=none:open memory=none:unresolved-namespace

STATUS: PASS
TIER: T3 — local syntax, selftest, and Python 3.14 installer check
EVIDENCE: docs/audits/code-factory-CF-036.md
