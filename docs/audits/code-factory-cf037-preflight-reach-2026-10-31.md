# Audit — CF-037 preflight reach status-code duplication

Measured 2026-10-31 in the code-factory checkout on branch `readme-audit-2026-10-30-232800`.
Pre-fix tree: HEAD `8e1638c69f2ab8c632bb5e3de2494caddce53109`. No external services were
relied on: the unreachable arm is a closed `127.0.0.1` port (allocated by binding port 0 and
releasing it), the reachable arm is a local `python3 -m http.server` fixture serving an empty
`health` file. Every probe ran with an isolated `HOME` and `NO_PROXY=127.0.0.1,localhost`.

## Defect

`scripts/project-node.sh` captured the preflight reach status with

```
c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$u" 2>/dev/null || echo 000)
```

`curl -w '%{http_code}'` already prints `000` when a connection gets no HTTP response (and
exits nonzero), so the `|| echo 000` fallback appended a second `000` and every FAIL line
carried six digits — a stranger cannot tell an unreachable bus from a formatting defect.

## Evidence — pre-fix, unreachable (measured at 8e1638c)

Command:

```
CRIER_URL=http://127.0.0.1:33089 ./scripts/project-node.sh --check --project demo
```

Output (reach rows, verbatim):

```
  FAIL  reach:http://127.0.0.1:33089/health — -> 000000
  PASS  reach:https://pypi.org/simple/ — 200
```

Six digits on the FAIL row: the defect.

## Evidence — selftest red on the pre-fix tree

`bash tests/selftest.sh` with the new fixture and the unfixed script printed
`SELFTEST: FAIL (1)`; the only red row was the CF-037 fixture:

```
8. cf037-reach-code — preflight reach prints one three-digit status code (CF-037)
  FAIL  closed port reach line is not exactly one three-digit code:   FAIL  reach:http://127.0.0.1:33207/health — -> 000000
  PASS  local fixture prints 'PASS reach:<url> — 200'

SELFTEST: FAIL (1)
```

## Evidence — post-fix, unreachable

Command:

```
CRIER_URL=http://127.0.0.1:55455 ./scripts/project-node.sh --check --project demo
```

Output (reach rows, verbatim):

```
  FAIL  reach:http://127.0.0.1:55455/health — -> 000
  PASS  reach:https://pypi.org/simple/ — 200
```

Exactly one three-digit code on the FAIL row.

## Evidence — post-fix, reachable local fixture

Command:

```
CRIER_URL=http://127.0.0.1:35917 ./scripts/project-node.sh --check --project demo
```

Output (reach row for the fixture URL, verbatim):

```
  PASS  reach:http://127.0.0.1:35917/health — 200
```

## Evidence — selftest green on the fixed tree

```
8. cf037-reach-code — preflight reach prints one three-digit status code (CF-037)
  PASS  closed port prints one three-digit code (000)
  PASS  local fixture prints 'PASS reach:<url> — 200'

SELFTEST: PASS
```

## Fix

The capture keeps curl's own status and defaults to `000` only when the capture is empty
(no curl on PATH or killed curl), so a failed connection can never duplicate the code:

```
c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$u" 2>/dev/null)
[ -n "$c" ] || c=000
```

The `ok`/`bad` call sites and the `PASS reach:<url> — 200` convention are unchanged.

## Marker

```
ch:trace row=CF-037 spec=scripts/project-node.sh#preflight-reach wave=none:serial test=tests/selftest.sh::cf037-reach-code doc=docs/audits/code-factory-cf037-preflight-reach-2026-10-31.md prompt=prompts/dogfood.md evidence=docs/audits/code-factory-cf037-preflight-reach-2026-10-31.md witness=none:closed-port-and-local-fixture verdict=none:open-finding commit=none:self-referential-hash memory=none:unverified
```
