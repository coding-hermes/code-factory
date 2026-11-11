# LOOP CODEX — what the operating loop reads

The machine-readable half of the handbook sheet `2.4` (`~/code-factory-reports/handbook/cf-master.pdf`).
Both say the same thing; this one is what an agent parses. If they disagree, this file is wrong and the
sheet wins — fix it in the same tick.

Authority: `specs/HARNESS-MATRIX.md` (harness selection), `specs/NODE.md` (node contract),
`docs/MVP-PLAN.md` (workstream order). Measured state below is at revision `3b1e826` and must be
re-measured, not quoted, before a row is closed; §3's register was re-measured against the board at
`3d1b642` on 2026-11-08 and every cited row that has since closed is marked **closed** with what it
shipped (`bash scripts/boardctl validate` → `RESULT: OK (17 warning(s))` at that tip; the board
carries 366 rows / 549 events, 109 `complete`).

---

## 1. The stages, and the command that closes each

| Stage | Exit test (re-runnable) | State |
|---|---|---|
| **S0** control host | `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:9090/health` = 200; `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8767/health` = 200; a DuckBrain POST of a key then GET of the same key returns the bytes | **CLOSED** |
| **S1** node provisioned | `./scripts/bunker-provision.sh --config <conf> --check` → `BUNKER: PASS` | **CLOSED** (one WARN: no env file declared) |
| **S2** node on the bus | `python3 ~/node-bus-worker.py --check` on the node → `BUS WORKER: READY` | **READY** — signed read 200; no production dispatch consumed yet |
| **S3** foreman on the node | with the control host unreachable, on the node: `boardctl create` a row, do it, close it with the acceptance command's output quoted in the row | **OPEN** — `CF-249` (the seeded node consumes a real directive and returns a usable result; the prompts/skills seed itself, `CF-220`, is closed) |
| **S4** result lands | `./scripts/land-node-branch.sh …` proves the commit is an ancestor of `origin/main` **and** the file is in that tree | **CLOSED** |
| **S5** harness matrix | `tests/harness-conformance.sh` prints five legs per harness, `PASS` or `SKIP` naming the missing credential | **Hermes measured; foreign-harness implementations have landed for claude-code, codex and pi, but live-node conformance remains unverified** — see `CF-225`, `CF-227`, `CF-228` (complete; fixture or installer evidence, live-node residuals retained) |
| **S6** scale out | two project lanes on two bunkers: each `/agents/<id>/inbox` answers 200 to a signed read, and each closes a row from inside its own node | **OPEN** — `CF-210` (17 lanes, one node) |

**Do not start S6 before S3.** A foreman on a different machine from the work is grading a claim.

---

## 2. The five flows and what proves each

| Flow | Carrier | Proof |
|---|---|---|
| 1 directive | scheduler → `POST /agents/{id}/inbox` → node signs (ed25519, ±30 s) and reads | `200` on a signed read; lease 30 s |
| 2 result | node → reply with `corr_id` → scheduler correlates, acks, completes the tick | tick reaches `completed`; poll 10 s, lease 45 s — measured in the scheduler's code, not in this repo |
| 3 memory | node → DuckBrain, namespace = project, one record per run | read back byte-identical: `run_id, lane, harness, model_requested, model_served, provider_binding, commit` |
| 4 credential | one bundle, mode 600, deleted both sides; paths only, never values | file present at 600 on the node; no value in any log |
| 5 artifact | node → control host, with sha256 | **partial**: `verify-node.sh --artifact` returns ONE file and recomputes its digest; a run cannot yet declare its own artifact set — re-measured 2026-11-08, `CF-211` was the result leg and is closed, so the gap now sits with `CF-392` |

---

## 3. The deficiency register (pick from here)

Ordered as the loop should take them: S3 blockers first, then S5, then scale.

| Ref | Now | Target | Row |
|---|---|---|---|
| D-1 | node has no prompts, no skills; the foreman there improvises | provisioning seeds `prompts/` + declared skills, digest-recorded, ~16 MB budget, drift check | `CF-220` **closed** — the seeder ships; the residual (a seeded node consuming a real directive) stays with `CF-249` |
| D-6 | only some lanes return a result; 5 replies sit unacked | every lane replies with `corr_id`; uncorrelated replies are acked with a reason | `CF-211` **closed** — `scripts/node-bus-worker.py` posts the result envelope (`ok`, `error`, `reply_b64`, `in_reply_to`) under an idempotency key and acks after delivery; the other lanes stay unmeasured |
| D-2 | no Go toolchain graded or installed (Go = 27 of 61 repo origins) | layer 10 grades go per project kind; `install-go.sh` pins it and proves a module resolves | `CF-218` **closed** (layer 10 derives the kind set and resolves a pinned module), `CF-219` **closed** (`install-go.sh` installs at a digest pin) |
| D-3 | 6 of 7 harnesses unproven; adapters/installers missing or stubs | five conformance legs per harness on a real node | `CF-225` **closed** (claude-code), `CF-227` **closed** (codex); `CF-228` **closed** (pi/pi-agent) — five legs on a real node are still unproven for every harness but hermes |
| D-4 | harness decided by whichever binary the node got | directive > lane > model-family default > hermes, with the reason recorded | `CF-230` **closed** — selection is data-driven and records its reason |
| D-5 | installers take no declared inputs; a key could arrive in argv | `CF_*` contract everywhere; a value credential is a `FAIL` | `CF-229` **closed** — the `CF_*` contract ships across the harness installers |
| D-7 | control host cannot reach a node's gateway | defined transport; `UNVERIFIED` is its own verdict | `CF-224` |
| D-8 | nothing defines what comes back from a node | artifact return: path, sha256, size, recomputed on return | `CF-211` **closed** — `specs/ENVELOPE.md` §Result defines the verdict field, the path home, the correlation rule, the delivery budget/key and ack-after-delivery; the artifact SET (path + sha256 + size per file) is still undefined and now sits with `CF-392` |
| D-9 | one DuckBrain token reads any namespace | per-key namespace scoping | `CF-208` |
| D-10 | the node's inference path points at a deferred proxy | a live endpoint per node, seat measured after dispatch | `CF-012`, `CF-171` |
| D-11 | one node, 17 lanes with no path to it | one bunker per project, every lane routed by crier | `CF-210` |
| D-12 | the guard's tests lane caps below the suite's runtime | a `BUDGET` outcome naming budget, elapsed, last section | `CF-217` |
| B-1 | cross-provider harness matrix unmeasured | capability per harness + `provider_binding` on every run | `CF-233` |
| B-2 | harness swap needs a reprovision | one config file, `--explain`, effective next tick | `CF-234` |
| B-3 | oh-my-hermes unused, five forks | adopt or reject, provenance-pinned | `CF-235` |
| B-4 | no evidence a swap is safe | conformance across two harnesses before a default moves | `CF-236` |
| B-5 | capability table hand-written | generate it from probes | `CF-237` |

---

## 4. The tick protocol

1. **Read** the board (`.coding-hermes/board/tasks.jsonl`) and this file. Take the lowest open stage's
   highest-priority row. A `BACKLOG` row never displaces a P0/P1, and is never dropped.
2. **Verify the premise** before dispatching: `git fetch`, then grep `origin/main`'s log and board for
   the row id. A row may already be landed.
3. **Spawn at most three workers**, each in its own worktree off `origin/main`, and tell each one what
   it may not touch (`tests/selftest.sh`, `docs/ACCEPTANCE-PLAN.md`, the board, sibling-owned files) so
   parallel branches cannot collide.
4. **Verify the return yourself**: read the diff, run the row's acceptance command, confirm the commit
   is on the branch it claims. A worker's summary is not evidence.
5. **Land through the gate.** If the gate cannot run because the host is loaded, say so and cite the
   budget — never a silent `--no-verify`.
6. **Close** the row only with a re-runnable command in the evidence, and update the spec in the same
   change when spec and reality disagree.
7. **Write one DuckBrain record**: stage moved, rows touched, proven / not proven, and the next tick's
   first action.

## 5. What the loop may not decide alone

Publishing the repo; changing its public surface; moving a model-family harness default; deleting a
node; spending on a new provider. Those return to the owner with the measurement that motivated them.

## 6. The loop's unit of progress

A closed row with a re-runnable command — not a tick that ran. A tick that closed nothing must still
produce a filed defect or a named blocker, or it is indistinguishable from an idle machine.
