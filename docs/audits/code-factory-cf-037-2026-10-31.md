# CF-037 reach-status regression audit

Frozen at 2026-10-31T19:58:57Z from source commit `cc0a1e473d63065875242ceabcc15b1f218857e3` before the fix.

## Deterministic fixture

The probe prepended a temporary `curl` executable to `PATH`. The executable printed `000` and exited 7, modeling an unreachable URL without making a network request:

```bash
#!/usr/bin/env bash
printf '000'
exit 7
```

The reachable control used the same fixture shape, printing `200` and exiting 0. The temporary `HOME` prevented writes to the operator's node state.

## Regression proof: pre-fix source

Command: run `tests/selftest.sh` after replacing only `scripts/project-node.sh` with `git show cc0a1e4:scripts/project-node.sh`.

Observed output:

```text
3. unreachable Crier reports one HTTP status code
  FAIL  unreachable URL status was duplicated or missing
SELFTEST: FAIL (1)
```

The direct unreachable-URL probe on the same pre-fix source produced:

```text
  FAIL  reach:http://closed.test:8767/health — -> 000000
```

The pre-fix selftest exit was 1. This is the measured duplicate emitted by `curl -w '%{http_code}'` plus the fallback `echo 000`.

## Fixed source verification

The direct unreachable-URL probe after the fix produced:

```text
  FAIL  reach:http://closed.test:8767/health — -> 000
```

The fixed selftest produced:

```text
3. unreachable Crier reports one HTTP status code
  PASS  unreachable URL -> one 000 status
SELFTEST: PASS
```

The reachable control after the fix produced:

```text
  PASS  reach:http://reachable.test:8767/health — 200
```

Additional checks:

```text
bash -n scripts/project-node.sh tests/selftest.sh
bash -n: PASS
```

The change keeps the curl status output when curl fails only long enough to replace it with one fallback `000`; successful HTTP 200 output remains unchanged.

ch:trace row=CF-037 spec=scripts/project-node.sh#preflight-reach wave=none:serial test=tests/selftest.sh::reach-unreachable doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-cf-037-2026-10-31.md witness=none:closed-port-and-local-fixture verdict=none:open-finding commit=none:branch-only memory=none:unresolved-namespace

STATUS: complete
TIER: T1 -- deterministic local fixture, pre-fix RED proof, fixed selftest, reachable control, and shell syntax check
EVIDENCE: docs/audits/code-factory-cf-037-2026-10-31.md
