# code-factory docs lane — tick `code-factory-docs-2026-11-04-10-01-07`

Deliverable: one corrected document plus the command that proves the new sentence.

Claim corrected: `docs/DESIGN.md` §3 ("The path of one unit of work") and §5 ("Failure model")
stated three legs of the factory loop in the present tense — a node-side bus worker, a result
envelope with an ack, and a control-host digest recomputation that decides a run — while no script
in this tree implements any of them. `README.md:13` names `docs/DESIGN.md` "the authority", so an
operator reading it takes a design intention for shipped behaviour; that is the class the lane
contract forbids.

Transport: a throwaway clone of the published remote at `127e996`
(`git clone https://github.com/coding-hermes/code-factory.git`), clean porcelain. The registered
checkout `~/code-factory` was left untouched: it was 21 commits behind `gh/main` and a sibling lane
(`code-factory-releng-2026-11-04-10-22-25`) was `running` on it at selection time.

## Before / after

| Where | Before (false statement) | After |
|---|---|---|
| `docs/DESIGN.md:36` (was `:34-45`) | "3. The node's bus worker pulls the message (signed), verifies the brief digest, hands the directive to the harness" | §3 is a table with a **State in this tree** column; step 3 reads **Not shipped**, citing `scripts/project-node.sh:245-249` and `specs/NODE.md` § Layers, owner CF-068 |
| `docs/DESIGN.md:38-45` (step 5) | "The node returns a result envelope … It **acks** the message only after the result is delivered" | Step 5 reads **Not shipped**: `specs/ENVELOPE.md` defines the shape, nothing produces, consumes or acks one, owner CF-004 |
| `docs/DESIGN.md:38-45` (step 6) | "The control host pulls the artifacts, recomputes the digests, and only then records the run" | Step 6 reads **Not shipped as a gate**: `scripts/verify-node.sh:60-70` is optional, records nothing, consumed by no automation, owner CF-107 |
| `docs/DESIGN.md:59` (was `:57-65`) | "Node unreachable → message stays in the inbox; the lane is degraded after N misses" | §5 marks it design intent, no inbox ships here (§3 step 2), the degradation is the scheduler's, not measured |
| `docs/DESIGN.md:72-76` | "Node dies mid-job → the lease expires and the message is redelivered" | §5: no lease or redelivery consumer exists under `scripts/`; idempotence is required of the harness (`AGENTS.md` rule 5), unenforced here |
| `docs/DESIGN.md:78-81` | "Result digest mismatch → run FAILS; the node is quarantined until `--check` passes" | §5: the optional probe prints a named row and a non-zero exit; no run recorder, no quarantine path — **not measured** |
| `docs/DESIGN.md:85-86` | "Disk exhaustion → the node refuses new work at the floor" | §5 marks it **shipped** with the code path: `scripts/project-node.sh:144-176`, `specs/NODE.md` § Disk floor |

## Code path that proves the new statements

Run from the repository root at this commit.

```
$ grep -rniE 'envelope|\back\b|inbox|lease|redeliver' scripts/ --include=*.sh --include=*.py
scripts/board_lock.py:77:    holds the lock), ``free`` (we acquired and released it) or ``error`` (the
scripts/add_family_lanes.py:59:        "releases",
scripts/configure_family.py:84:    "releng": """Your job: releases and the state of the tree.
scripts/configure_family.py:89:3. If a release is due, tag it from a green commit and write the notes from board rows, not
```

Four hits, none of them a consumer of an inbox, an envelope or an ack. For contrast, the bus layer
is a file stat and nothing else:

```
$ sed -n '245,249p' scripts/project-node.sh
  if [ -f "$STATE/crier.json" ]; then
    ok "crier_identity" "$STATE/crier.json"
    m=$(stat -c '%a' "$STATE/crier.json"); [ "$m" = 600 ] && ok "crier_mode" "600" || bad "crier_mode" "$m (must be 600)"
  else
    bad "crier_identity" "absent — stage a bundle and re-run; a node without an identity is invisible"
```

`specs/NODE.md` § Layers already carried the contract (`A node-side bus worker. Layer 30 starts and
checks no process and opens no socket`), and the only digest check on the control host is optional:

```
$ sed -n '60,70p' scripts/verify-node.sh
# 4. optional artifact integrity
if [ -n "$ARTIFACT" ]; then
  remote=$(bunker exec --server "$SERVER" "$AGENT" -- bash -lc "sha256sum $(shq "$ARTIFACT") 2>/dev/null | cut -d' ' -f1")
  tmp=$(mktemp)
  bunker exec --server "$SERVER" "$AGENT" --raw -- cat "$ARTIFACT" > "$tmp" 2>/dev/null
  local_h=$(sha256sum "$tmp" | cut -d' ' -f1); rm -f "$tmp"
  if [ -n "$remote" ] && [ "$remote" = "$local_h" ]; then
    ok "artifact_digest" "$(basename "$ARTIFACT") ${local_h:0:12} on both sides"
  else
    bad "artifact_digest" "node ${remote:0:12} vs host ${local_h:0:12} — bytes differ or file missing"
```

## Claims that came back TRUE (recorded so the next tick does not re-run them)

| Claim | Command | Literal result |
|---|---|---|
| `docs/BOARD.md` write rule 3: a `complete` status requires a bound run/evidence artifact accepted by the CLI | `bash scripts/boardctl update CF-001 --status complete` against a one-row fixture board | `rc=1`, `boardctl: evidence run required: completion REFUSED for "CF-001": --evidence-run-id is REQUIRED when setting status "complete" (TR-251)`, row status still `in_progress` — the rule is enforced, not decorative |
| `specs/NODE.md`: `node-create.sh` stages exactly five files and no `config.yaml` | `bash scripts/node-create.sh --staged-files` | `rc=0`; `project-node.sh`, `lib.sh`, `disk_floor.py`, `reclaim_disk.py`, `harness/install-hermes.sh` |
| `README.md`: adapter `--check` prints five gate rows when a binary is found | `HERMES_PYTHON_BIN=python3.12 bash scripts/harness/install-hermes.sh --check` | `PASS python`, `FAIL binary — host-provided … (not installed by this adapter)`, `FAIL version — 0.22.5+3030.g770a952 != pin 0.19.0`, `FAIL port — nothing on :10800`, `PASS inference_key`, `HERMES: FAIL (3)`, rc 1 |
| `README.md`: the 13 satellites are nested under the root lane | live census `curl -s "http://127.0.0.1:9090/api/v1/projects?limit=500"` | 19 `code-factory*` rows; every satellite carries `parent=code-factory`; only `code-factory-qa` is `enabled=false` |

## Claims found false but NOT fixed here (owned elsewhere)

- `docs/OPERATIONS.md:90` cites `scripts/bunker-server-install.sh:56` for the `residue` warn row —
  line 56 is `fi`; the warn is at `:63`. `:91` cites `:61` for `tool:$t` (real site `:67-68`);
  `:92` cites `scripts/project-node.sh:176` for the optional-tool warn (real site `:208-209`);
  `:11` cites `scripts/harness/install-hermes.sh:100` for the `gateway_start` refusal (real site
  `:258`). This is CF-195's subject, whose acceptance criteria require a committed citation checker
  plus a selftest arm — code, outside this lane's write scope. Not filed again.
- `README.md` inference-credential row quotes `HERMES: FAIL (1)` from the pre-CF-183 adapter; the
  command it names now prints `HERMES: FAIL (3)` (table above). README is the readme lane's surface.
- `docs/BOARD.md` "Current measured state" still prints `RESULT: OK (3 warning(s))` without naming
  the `boardctl` binary that produced it — CF-154's subject.

## Not verified

- Whether a bus worker runs inside a live node — **not measured** by this repository; no agent host
  was reachable for this tick.
- Whether any control-host automation consumes `verify-node.sh`'s exit status — **not measured**;
  no scheduler or crier configuration was inspected.
- The end-to-end round trip (CF-004) — **not measured**, unchanged by a documentation edit.

## Gate

```
$ bash tests/selftest.sh
SELFTEST: PASS
rc=0   (195 PASS rows; baseline at 127e996 was the same before the edit)
```

ch:trace row=CF-202 spec=docs/DESIGN.md#3 test=tests/selftest.sh doc=docs/DESIGN.md evidence=docs/audits/code-factory-docs-2026-11-04-10-01-07.md witness=cmd:grep-envelope-ack-inbox-4-hits-none-consumer verdict=gitreins:CF-202-DOC1 commit=none:self-referential-hash memory=/code-factory/tick/docs/2026-11-04-1001

STATUS: done
TIER: T3 (invoked and observed: the greps, the adapter check, the census and the gate were run in this tick)
EVIDENCE: docs/audits/code-factory-docs-2026-11-04-10-01-07.md; docs/DESIGN.md §3/§5; verdict CF-202-DOC1
