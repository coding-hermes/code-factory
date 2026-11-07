# CORRECTIONS — round 10

Generated 2026-11-06T20:35:57-0500.

## Verdicts

- **deepseek** — FAIL, blocking 2, 5877 bytes, complete=True
- **glm** — FAIL, blocking 3, 10054 bytes, complete=True
- **grok** — FAIL, blocking 9, 14270 bytes, complete=True
- **kimi** — FAIL, blocking 6, 11090 bytes, complete=True
- **sol** — FAIL, blocking 22, 28962 bytes, complete=True

## Verdict text (verbatim, per seat)

### deepseek

```
Verification complete. I read all 13 chapters, the OUTLINE, the SCHEMA, and the spine script; ran the spine gate (clean); then independently re-verified ~25 load-bearing specific claims against the live code at the listed paths. Results below.

VERDICT: FAIL
BLOCKING: 2
NON-BLOCKING: 1

FINDINGS:

1. [FALSE CLAIM / stale measurement] M4-board — §7 verification row and §13 F4-4 both report a live board drift and an events count that re-measurement disproves. Claim quoted: "drift … RESULT: DRIFT (4 failed) … 1 divergent id: CF-270 (workdir=pending, published=complete) … HEAD=47d68b4 vs origin/main=4dc0ef0" and "events count … 518 lines" (also "357 rows / 518 events" in §1). Evidence: re-ran `python3 scripts/board_drift.py check --workdir /home/kara/code-factory --ref origin/main` → RESULT: OK, byte parity identical on both tasks.jsonl and events.jsonl, "357 vs 357 rows; 0 divergent ids", HEAD=8ae4f82=origin/main. `wc -l .coding-hermes/board/events.jsonl` → 519 (not 518). `git rev-parse HEAD` → 8ae4f823334746733f3448d543f7d8a5c4162dec. The divergence the chapter flags as "must be reconciled" was already reconciled (commit 4dc0ef0 closed CF-270; it is in origin/main). Fix: re-run board_drift and rewrite the §7 row to RESULT: OK; correct the events count 518→519 in §1 and §7; mark F4-4 resolved-by-4dc0ef0 rather than live.

2. [FALSE CLAIM / stale locators] M1-provisioning — every certification-ladder locator in §11 points at a verify-node.sh that no longer exists at those lines. Claim quoted: "agent_alive … :50-54 … :53 RESULT: FAIL … gateway_reachable :57-87 … checkout_freshness :118-155 … :150 … seed_drift :157-202 … :194-198 … :205-214 precedence", plus §1 "verify-node.sh (:20-214)". Evidence: current `scripts/verify-node.sh` is 241 lines (was 214 at the stamped revision). Commit f1d5cfb "fix(verify-node): refuse a non-digit --port" (CF-270) inserted +28/−1 near the top of the file. Measured current positions: agent_alive :75-76 (RESULT: FAIL at :76), gateway_reachable :98-113, unauth_refused :119-129, artifact_digest :139-141, checkout_freshness :150-177, seed_drift :188-225, terminal VERIFY forms :233-241. Every §11 leg line number is shifted ~+25. Fix: re-pin the §11 ladder table against the 241-line file, or state explicitly the revision those locators describe.

3. [UNVERIFIED / revision-drift, systemic] all chapters — the Identity "Revision" stamps are not the current HEADs. Evidence: code-factory HEAD = 8ae4f82 (5 commits ahead of the stamped 47d68b4: f1d5cfb, 7281f5a, 24580c1, 4dc0ef0, 8ae4f82); scheduler HEAD = 3496308b (ahead of the stamped 1771d3aa). crier (691f0c78) and crier-fleet (283bca91) stamps MATCH their live HEADs. Every other specific locator I verified — lib.sh all 78 lines, node-bus-worker.py directive_text :977 / reply :1176-1192 / dispatch_wall :1200-1205 / deliver :1208, dispatcher.py EXEC_TIMEOUT :47 (inert, 1 ref) / 25 log( sites (23 calls), scheduler 57 flags / 379 log.Printf / 43 routes / 30 tables / dispatchReplyVerdict reads only payload["ok"], crier 3 slog sites / 91 test files / HandleRegister:598 / HandleDeliver:990 / HandleRetrieve:1690 / HandleAck:1812 / metrics.go:2 "opt-in", proxy sink paths :50/:52 / LISTEN :53 / live 401, M0 source-count 17, and test counts 40/28/12/9 (all run green) — remains exact at HEAD, because only verify-node.sh and the board changed in code-factory and no scheduler source changed. Fix: re-stamp identity fields to current HEAD at merge, or state the derivation revision as an explicit snapshot date.

DEFECT CLASSES: stale-measurement (snapshot lag), stale-locator (line drift after a fix landing mid-round), revision-drift.

CHAPTER SCORECARD:
M0-shared-contract — WRITTEN (every helper location and the 17-source count verified exact)
M1-provisioning — PARTIAL (certification-ladder §11 locators shifted by the CF-270 verify-node fix)
M2-dispatch — WRITTEN (directive_text, reply shape, dispatch_wall, deliver all exact; 40 tests green)
M3-repository — WRITTEN (308-line lander, gate-default and no-invoker claims consistent)
M4-board — PARTIAL (drift row and events count stale; store is now OK/519/0-divergent)
M5-harness — WRITTEN (28 harness_resolve tests green; F5-2/F5-5 call-site analysis holds)
M6-documentation — WRITTEN (gate reads MASTER-DOC: FAIL; spine gate added and clean)
M7-github — WRITTEN (UNVERIFIED status honest; no mint possible on this host)
M8-safety — WRITTEN (9 reclaim tests green; scan-scope surface exact)
M9-scheduler — WRITTEN (57/379/43/30 all measured-correct; CF-355 dispatchReplyVerdict confirmed against dispatch_leg.go:713-726)
M10-crier — WRITTEN (3 slog sites, 91 test files, handler funcs at exact lines, metrics.go:2 "opt-in" contradiction real)
M11-dispatcher — WRITTEN (EXEC_TIMEOUT inert proven, 23/25 log-site census exact)
M12-inference-proxy — WRITTEN (sink paths, LISTEN, live 401 all exact; F12-7 framing-correct)

Overall: the document is genuinely rigorous — the spine gate passes and ~25 independent specific claims I re-derived against live code are exact, including the hardest ones (dispatchReplyVerdict's ok-only read, the inert EXEC_TIMEOUT, the 57/379/43/30 scheduler census, the 3-slog-site handler census). The two blocking findings share one root cause: five commits landed after the writer's 47d68b4 snapshot — the CF-270 verify-node fix and its board close — which moved verify-node.sh's line numbers and resolved the board drift the document still reports as live. Both are small mechanical fixes, but a reader acting on today's §4/M4 would chase a phantom CF-270 divergence and grep verify-node.sh at dead line numbers, so neither chapter can be called written until re-measured.

PANEL REVIEW COMPLETE

session_id: local-0753a4c9d1d3920e5323adb83a7b037567fcc670e96cbbab73047cd7907c5f52

EXIT=0
```

### glm

```
All verification batteries are complete. I re-ran every repeatable command the chapters quote: the spine gate (0 findings, twice), master_doc_check (FAIL 44/37/50, exit 1), verify-patch, board census/drift/validate, the live 401 admission probe, the proxy sha256, and the grep/locator counts across all five systems (57 flags, 43 routes, 379 log sites, 10 LoadRootConfig sites, 30 tables, 3 slog sites, 67 metric strings, 91 test files, 25 log() lines, 11/17 lib.sh sourcers — all reproduce exactly). Three chapters' recorded measurements do not survive contact with the current tree: the code-factory repo moved 5 commits past the chapters' stamped revision `47d68b4` while the round-10 edits were in flight, and `verify-node.sh`, the board store, and the patch chain all changed in that window.

VERDICT: FAIL

BLOCKING: 3 — findings that must be fixed before this chapter set can be called written

NON-BLOCKING: 2

FINDINGS:

1. Kind: CONTRADICTION (+OMISSION) — chapter M1
   Claim quoted: "`:50-54` `agent_alive` — `bunker exec … echo ALIVE $(hostname)` must return `ALIVE*`; on failure `:53` prints `RESULT: FAIL` and exits 1" and the ladder locators "`:57-87` gateway_reachable · `:90-103` unauth_refused · `:104-115` artifact_digest · `:118-155` checkout_freshness · `:157-202` seed_drift · `:205-214` precedence".
   Evidence: HEAD is `8ae4f82`, 5 commits past the stamped `47d68b4`; `scripts/verify-node.sh` changed in that window (commit `f1d5cfb`, CF-270, 29 lines inserted before the legs). At HEAD: `agent_alive` is `:73-76`, `RESULT: FAIL` is `:76` (not `:53`), `unauth_refused` at `:119-129`, `artifact_digest` at `:139-141`, the checkout WARN at `:177` (chapter cites `:150`, now a comment line). Every ladder locator in §9/§10/§11 is shifted ~+23 lines and no longer resolves. Additionally the NEW behavior — non-digit `--port` refused with exit 2, port no longer interpolated into the remote shell — is absent from the chapter entirely (OMISSION).
   Fix: re-derive M1 §9/§10/§11 against `8ae4f82` (or whatever commit this issue lands on), add the port-validation leg, re-stamp the revision. Mechanical: the file's leg semantics are unchanged, only locators and the new leg.

2. Kind: CONTRADICTION — chapter M4
   Claim quoted: "`RESULT: DRIFT (4 failed)` with 1 divergent id (CF-270) (workdir=`pending`, published=`complete`); HEAD=`47d68b4` vs `origin/main=4dc0ef0`" and "events count … 518 lines" (§1 Status, §7 rows, F4-4).
   Evidence: re-run this round at HEAD `8ae4f82`: `board_drift` returns `RESULT: OK`, 357 vs 357 rows, 0 divergent ids; CF-270 is `complete` in BOTH the workdir and `origin/main`; HEAD == origin/main == `8ae4f82`; events.jsonl is now 519 lines (the closeout event landed). The recorded measurement — including the chapter's §1 status line "DRIFT (board copies)" — no longer reproduces; the reconciliation F4-4 demanded ("must be reconciled before the merge that carries this chapter") has in fact happened, and the chapter records the pre-reconciliation state as this round's truth.
   Fix: re-take §1 status and all §7 board measurements at the issue revision; rewrite F4-4 to record the reconciliation as satisfied. `boardctl validate` (RESULT: OK, 7 warnings) still reproduces and needs no change.

3. Kind: CONTRADICTION — chapter M6
   Claim quoted: "`bash scripts/verify-patch.sh` … **PASS** — `4 stages, 3 patches, f393a681…`" (§7).
   Evidence: re-run this round: `VERIFY-PATCH: PASS` over **5 stages, 4 patches, tip `57432007…`** — `patches/fleet-ops-deploy-doc.patch` (+test, +chain sha) landed in commit `8ae4f82`, after the chapter's stamp. The command still passes but the quoted output is false at the issue tree.
   Fix: update the row to the measured chain. One line.

4. (Non-blocking) Kind: UNVERIFIED (stale count) — chapter M3
   Claim quoted: "`selftest.sh` is 4,737 lines with *named* arms".
   Evidence: now 4,852 lines (the fleet-ops deploy-doc arm appended at the end). The cited arm locators `:2463-2729` (cf213) and `:3433-3670` (cf244) still resolve exactly — verified by grep this round.
   Fix: refresh the line count when re-stamping; no locator change needed.

5. (Non-blocking) Kind: CONTRADICTION (stamp hygiene) — chapters M0, M2, M3, M5, M7, M8 (stamp `47d68b4`) and M9 (stamp `1771d3aa`)
   Claim quoted: "Revision | `47d68b4…` (at derivation; code-factory HEAD, re-derived round 9)" / "`1771d3aa` (scheduler repo HEAD, re-stamped this round)".
   Evidence: code-factory HEAD is `8ae4f82`; scheduler HEAD is `3496308b`. For these chapters the stamps are cosmetically stale only: `git diff --name-only 47d68b4..8ae4f82` shows no cited file changed outside verify-node.sh/selftest.sh/board/patches, and the scheduler's cited Go files are byte-identical since `1771d3aa` — I re-verified flags=57, routes=43, log sites=379, LoadRootConfig=10, tables=30, admission_mode/spawn/dispatch_leg/migrations locators all exact at current HEAD. The schema's rule is "one revision per document issue"; the issue will land on a commit that is not the stamp.
   Fix: re-stamp at the landing commit during the blocking fixes; no content change required for these chapters.

Spine gate: `python3 scripts/handbook_spine.py` re-run twice this round — `chapters=13 canonical contracts=18 findings=0`, exit 0. No unregistered contract ids, no dual-default settings, no dangling M/F references, no count disagreements between OUTLINE and chapters; nothing to add from the spine. The OUTLINE's "5 of 18 internal contracts name both file:function (CT-02..CT-06)" claim was independently confirmed against the chapters; the 13 boundary rows each name the covered side with the far side honestly marked external/missing per the OUTLINE I.9 convention. Chapter-quoted commands I could NOT repeat (and say so per rule 4): the live-node rows (M2 bus-worker ladder on cf-node, M5 conformance legs, M10 signed-read ladder — no live node from this seat), M7's token mint (no App credentials on this host), M12's valid-token 403 row (node token file not read). All four are disclosed as such inside the chapters themselves.

DEFECT CLASSES: STALE-REVISION-STAMP; SUPERSEDED-MEASUREMENT (repo moved under the document mid-round); LOCATOR-DRIFT; OMISSION (post-derivation behavior landed undocumented)

CHAPTER SCORECARD:
- M0 shared-contract — WRITTEN: every locator verified against the 78-line lib.sh (all 10 helpers, both source-greps 11/17, fails-closed probe reproducible); only RED is the absence-proved metrics field.
- M1 provisioning — PARTIAL: semantics of the ladder and both measured lies (F1-1 mode-600, F1-5 asymmetry) stand, but all verify-node.sh locators are false at HEAD and the new CF-270 port leg is omitted (finding 1); bodies honestly self-declared UNVERIFIED.
- M2 dispatch — WRITTEN: constants, reply shape (`:1176-1192` exact), dispatch_wall non-clamping, settlement ordering, configure_family PID hardcode all verified verbatim; CF-354/CT-03/CT-04 states reproduce.
- M3 repository — WRITTEN: GATE="" default + run_gate guard, explicit-ref push, gitreins pin/exit-0 hook path, clone_lane row-clone semantics, selftest arm ranges all verified; line-count nit (finding 4).
- M4 board — PARTIAL: store structure, verb surface, CT-10 zero-match grep and validate output reproduce, but the drift/census measurements recorded as this round's are superseded by the reconciled tree (finding 2).
- M5 harness — WRITTEN: CFV sets (12/6), the [0-7]00-predicate-vs-"must be 600"-message mismatch (F0-6 verified real), per-adapter registers, computed installer dispatch (`project-node.sh:440,449-452`) all verified.
- M6 documentation — PARTIAL: gate behavior reproduced exactly (MASTER-DOC: FAIL, 44/37/50, exit 1; roots/glob/B13 claims all true), but the patch-chain row's quoted output is superseded (finding 3); own-gate FAIL honestly carried in §1.
- M7 github — WRITTEN: CLI-exit-2 surface, 0600 key gate, MIN_AGE 2400, mode-600-before-rewrite ordering, credential-domain separation (fleet-gh-scope ≠ M7) all verified; mint honestly UNVERIFIED.
- M8 safety — WRITTEN: both files verified against constants (BUILD_CACHES/AGED_PARENTS/PROTECTED), inclusive TTL boundary, scan-scope surface; callers verified (`project-node.sh:212`; no caller for scan scope).
- M9 scheduler — PARTIAL: deep sample exact (admission procedure locators, 57/43/379/10/30 counts, dispatchReplyVerdict CF-355 confirmed in code, all 8 migration locators, F9-3 LoadRootConfig correction true), but five self-declared RED fields remain open (377 of 379 log sites, S1 grep-level, aux-flag consequences, per-route contracts, S3 write authorities) and the stamp is stale.
- M10 crier — WRITTEN-leaning-PARTIAL: every tested claim exact (entrypoints :598/:990/:1690/:1812, slog 3/3 at the cited lines, config defaults block, 67-string census, 91 test files, guard pipeline, client methods, CT-08 producer); REDs are scoped and named (handler body, per-metric table, guard log surface) — grading PARTIAL on its own declared RED field count of 4.
- M11 dispatcher — WRITTEN: 538 lines, all settings verbatim (incl. the inert EXEC_TIMEOUT and string TASK_S), task_seconds floor, kill-group analysis, ledger replay ordering, 23/25 log-site census, CT-06 `ok` field — all verified; decoration-test and metrics REDs honestly declared.
- M12 inference-proxy — WRITTEN: sha256 exact, all settings at `:43-54` verbatim, live 401 reproduced, systemd unit active with the cited drop-in, sink-path correction (F12-8) confirmed against the code; boundary REDs honestly declared.

The failure is narrow and mechanical: three chapters carry measurements that were true at stamp-time and false at issue-time because their own repo advanced five commits underneath them — precisely the defect class the schema's "one revision per document issue" rule exists to prevent. Everything else I could repeat, repeated clean.

PANEL REVIEW COMPLETE

session_id: local-33a3c7ef5abacc9d24ca28ae3f65ac565e47cc6df28a0ae03b94d0129c705cdf

EXIT=0
```

### grok

```
⚠️  Primary auth failed — switching to fallback: fireworks / accounts/fireworks/models/deepseek-v4p1-flash-1017
VERDICT: FAIL
BLOCKING: 9
NON-BLOCKING: 4

FINDINGS

B1. FALSE CLAIM — document scope (README I.1–I.5, II.1–II.5; OUTLINE F1–F5)
Claim: "I.1 … **RENDERED** (sheet 2)", "II.1 DISPATCH … **RENDERED** (sheet 5)" and OUTLINE "F1 DISPATCH AND SETTLEMENT … *(RENDERED)*" … "F5 LANDING *(RENDERED)*".
Evidence: no rendered artifact exists in the tree — `find /home/kara/code-factory -name '*handbook*.pdf'` → 0 results; `find docs/handbook -maxdepth 2 -name '*.pdf' -o -name '*.png'` → 0 results. The renderer's input root is gone: `ls docs/master` → "No such file or directory", and `scripts/gen_nasa_handbook.py:253-260` globs `docs/master/[0-9][0-9]-*.md` and returns 1 with `no modules found` on an empty selection — M6 §11 says the same thing. So five primary flows and all of Part I are asserted as delivered artifacts that cannot be produced and are not present.
Fix: delete every "RENDERED" status (Part I and II.1–II.5) or commit the actual sheets with a path; F1–F5 must be marked MISSING until a flow chapter exists, because every chapter's "F1 is the primary flow this module owns" (M0 §12, M2 §12, M3 §12, M11 §12) currently points at nothing.

B2. CONTRADICTION — contract register, all parts
Claim: OUTLINE:204-206 "**5 of 18** internal contracts name both `file:function` (CT-02, CT-03, CT-04, CT-05, CT-06); the remaining 14 are boundary contracts".
Evidence: 5 + 14 = 19 of 18. The spine's register is 18 CANON − 13 BOUNDARY = 5 internal (`scripts/handbook_spine.py:34-84`; `grep -c '^    "CT-'` → 31 = 18 + 13). M9:206 states "CT-05 is **internal**". README's prose states the opposite split — "Four contracts (CT-02, CT-03, CT-04, CT-06) are *internal* … Fourteen (CT-01, CT-05, CT-07..CT-18) are *boundary*" — while its own table two paragraphs later says "5 of 18 internal … 14 boundary contracts". M6:98 repeats "the 14 boundary contracts".
Fix: adopt 5 internal / 13 boundary (CT-01, CT-07…CT-18 boundary; CT-05 internal) in OUTLINE Part IV, both README passages, and M6 §5; add a spine assertion that reads the outline's stated split and compares it to `len(CANON) - len(BOUNDARY)`.

B3. CONTRADICTION — submodule count
Claim: OUTLINE:274 "Submodule chapters … 47"; README I.4 "13 modules, 47 submodules".
Evidence: the chapters define 48 submodule rows — M0 1, M1 5, M2 3, M3 3, M4 2, M5 5, M6 **9**, M7 1, M8 2, M9 5, M10 4, M11 4, M12 4. M6's §3 table carries S1–S9 because M6 §5 added "**Spine gate (S9, added this round)**". The spine cannot see this: `handbook_spine.py:308` sets `"submodule": None`, and the count loop skips a None target (line 318).
Fix: state 48 everywhere, add M6.S9 to the OUTLINE's M6 list, and make the spine parse `^| S<n>` rows inside §3 instead of hardcoding.

B4. FALSE CLAIM — M4, §1 Status and §7
Claim: "**DRIFT (board copies)** — `board_drift` `RESULT: DRIFT (4 failed)` with 1 divergent id (CF-270) against `origin/main=4dc0ef0`"; §7 "357 vs 357 rows, **1 divergent id: CF-270**".
Evidence, measured now: `python3 scripts/board_drift.py check --workdir /home/kara/code-factory --ref origin/main` → every row PASS, "board rows — 357 vs 357 rows; 0 divergent ids: none", "HEAD ancestry … origin/main=8ae4f823…", `RESULT: OK`. `wc -l .coding-hermes/board/events.jsonl` → **519**, not the 518 the chapter stamps in §1, §7 and §13. The divergence was reconciled after the stamp (47d68b4), and the chapter's own instruction — "must be re-run after that merge" — was not executed before delivery.
Fix: re-run board_drift and boardctl validate at the delivery revision, re-stamp the Status row, and if the measurement is deliberately as-of 47d68b4, say "as-of" in the Status cell rather than presenting it as current.

B5. FALSE CLAIM — M6, §7
Claim: "patch chain … **PASS** — `4 stages, 3 patches, f393a681…`".
Evidence: `bash scripts/verify-patch.sh` now prints "5 stages, 4 patches, 57432007b324f382…" and `patches/fleet-ops-chain.sha256:13` carries the `deploy-doc` stage. The 4/3 figure was exact at 47d68b4 (chain file had 4 stage lines) — the row is stamp-stale, not invented.
Fix: re-run and re-stamp; add the stage count to the row's date so a reader can date the reading.

B6. FALSE CLAIM — M9, §1
Claim: "`go.mod` declares `go 1.26.0` + `toolchain go1.26.6`; `go env GOVERSION` resolves **go1.26.6**".
Evidence: `go.mod` today declares `toolchain go1.26.10` (commit 9bc9e561, "build: bump go.mod toolchain floor to go1.26.10 (RELEASE-038)", 20:10 today); `go env GOVERSION` → `go1.26.10`. At the stamped 1771d3aa the claim is exact (`git show 1771d3aa:go.mod` → `toolchain go1.26.6`).
Fix: re-stamp §1 and the §4a runtime row; the pinned-version assertion is the one line an operator will copy into a build.

B7. CONTRADICTION — M3.S1 (secondary instance M1.S1)
Claim: "S1 clone and track freshness | `clone_lane.py`, `repo_freshness.py` | **active** | `clone_lane.py:129` `main()` is the entrypoint (**operator-invoked; no in-repo caller**)".
Evidence: the row's own evidence satisfies the OUTLINE's *optional* rule (OUTLINE:109-113) and not its *active* rule. `grep -rn 'clone_lane' scripts/` matches only the file itself and tests. Same defect in M1.S1: the row is classified **active** on the strength of `disk_floor.py` → `project-node.sh:173`, while the other unit in the row, `bunker-server-install.sh`, has no invoker at all (`grep -rn 'bunker-server-install' scripts/ tests/` → its own docstring plus `tests/selftest.sh:1754`; a test arm is not a lane, cron, timer or unit).
Fix: split the rows per unit and label: `clone_lane.py` optional, `repo_freshness.py` unproven until its caller is measured; `disk_floor.py` active, `bunker-server-install.sh` optional.

B8. OMISSION — M9, §3 ordered admission procedure
Claim: "**Ordered admission procedure** … The composed decision sequence, in order of authority:" — five steps, ending at usage-pool reservation.
Evidence: the code applies two further admission gates that the sequence never mentions, both registered in M9's own §5 as admission controls: board-stasis (`internal/scheduler/packer_select.go:456-469` `boardStasisBlocks(m.boardStasisGate, …)` and `:595-602` `boardStasisBlockedQuiet`; `cmd/schedulerd/main.go:150` "exclude a cooldown-mode BUILDER lane … while its board file has NOT changed") and the load gate (`main.go:144` "Defer new spawns while the 1-minute load average is at or above this value"). A reader implementing admission from §3 ships without either gate, and §5 and §3 disagree about what admission is.
Fix: add both gates as numbered steps with their predicates, their position inside `packer_select`, and what each does on unreadable input (stasis fails open; load defers rather than drops).

B9. OMISSION — log inventories presented as verbatim, M1/M2/M3/M5/M7 §9
Claim: each chapter heads §9 "Log lines (verbatim)" and lists a handful of rows; MASTER-DOC-SCHEMA §6 requires "Every operator-visible line, verbatim, with its level and the condition that triggers it".
Evidence (site counts measured now): M1 lists 5 rows against 55 `ok|bad|note|warn|say` sites in `bunker-provision.sh` alone plus 21 in `verify-node.sh`; M2 lists 4 against 70 `ok()/bad()/warn()/note()` calls in `node-bus-worker.py`; M3 lists 5 against 35 in `land-node-branch.sh`; M5 lists 4 against six installers plus `harness-vars.sh`; M7 lists 2 against three scripts. None states a scope, and none counts the gap in its RED total (M1 = 3, M2 = 2, M3 = 2, M5 = 3, M7 = 3). Contrast M9 §9 ("2 of 379 … the named RED"), M11 §9 (23/23 call sites, verified complete), M12 §9 (4/4 print sites) and M0 §9 (7/7), which do this correctly.
Fix: add the measured site count and scope sentence to each §9 (as M9 does), and add §9 to each chapter's RED count until the inventory is complete.

N1. UNVERIFIED — M1, §11 (stamp-scoped locators)
Claim: "the checkout unmeasurable case prints `warn` at `:150` … The seed leg … does call `unverified()` at `:194-198`" and "`:205-214` precedence".
Evidence: at the delivered HEAD `scripts/verify-node.sh` is 241 lines — `:150` and `:194-198` are comments, the `warn` is `:177`, `unverified()` is `:225`, and the FAIL/UNVERIFIED/PASS precedence block is `:232-241`; `agent_alive` is `:75-76`, not `:50-54`/`:53`. At 47d68b4 (214 lines) all four citations are exact, so the claim is true and the locator is stale.
Fix: put the revision on each verification row, or cite `git show 47d68b4:scripts/verify-node.sh:150`.

N2. CONTRADICTION — chapter heading structure
Claim: OUTLINE:99-131 "The corrected thirteen" headings begin "1. Purpose, authority and operational position · 2. Consequences of absence, and of false report".
Evidence: all 13 chapters begin "1. Identity · 2. Purpose, authority and position", folding the absence/false-report content into §2 (e.g. M4:14-27). This follows MASTER-DOC-SCHEMA §1 ("Identity" first), so the two governing documents disagree and neither was amended; no content is lost, which is why this is non-blocking.
Fix: amend OUTLINE Part III to the delivered order (Identity 1, Purpose-and-consequences 2) and say the schema wins.

N3. FALSE CLAIM — M6, §5 (gate coverage)
Claim: the spine "Enforces: … (5) count claims".
Evidence: `handbook_spine.py:308` sets `"submodule": None`, so no submodule count is ever compared; `COUNT_CLAIM` (line 88) requires the noun immediately after the number, so "14 boundary contracts" cannot match; the outline and README are never read. That is precisely how B2 and B3 passed a gate that reports `findings=0`.
Fix: narrow the sentence in M6 §5 to the five checks it actually performs, or extend the checker to submodule counts, adjective-tolerant count phrases, and the outline/README as inputs.

N4. PADDING — revision archaeology, all chapters
Claim: the chapters interleave prior-round corrections with the claims: M9 §5 "Round-4 claimed … **That is FALSE.**", M3 §7 "Note (B04 / grok 9). Round-3 cited …", M2 §3 "Round-4's 'no production caller' was false", M5 §2 "Round-5's … was **false**".
Evidence: these sentences identify a previous seat, not a behaviour of the system; an operator cannot act on them, and they sit inside the fields that must be acted on. The OUTLINE already reserves the home for them: Appendix D "Change log and supersession record" (OUTLINE:263-264).
Fix: move the correction history to Appendix D and leave one line per chapter pointing at it.

DEFECT CLASSES
stale-stamp evidence (claims true at stamped rev, false at delivered HEAD); unregistered count drift; internal/boundary register disagreement across document parts; classification-vs-own-rule drift; scope-claim inflation (RENDERED artifacts, "verbatim" inventories); gate blind spot reported as coverage; omission of live admission gates from the composed sequence; process archaeology as prose.

CHAPTER SCORECARD
M0 — PARTIAL. Every helper locator verified against `lib.sh` (5-9, 13, 19-42, 45, 48-57, 60-64, 67-70, 75-78), both greps reproduce exactly (11 / 17), 7/7 log lines. Held back only by the panel's own rule that a RED metrics field keeps a chapter PARTIAL.
M1 — PARTIAL. Substance is sound (bunker-provision.sh:181/:214/:233, disk_floor.py:36-37, :68-71 all exact), but S1 conflates an active unit with an optional one (B7), §9 is 5 rows of 76 sites (B9), and four §11 locators no longer resolve at HEAD (N1).
M2 — PARTIAL. Best-verified node chapter: `directive_text:977`, `process:1007`, reply `:1176-1192`, `deliver:1208`, `dispatch_wall:1200-1205`, `configure_family.py:24-28,17,149` all exact; 0-match greps reproduce. Held by §9 4-of-70 (B9) and metrics RED.
M3 — PARTIAL. Landing citations are exact (`:38,55-59,74-75,192,206,244,278-300,304,307`) and the shipped arm reproduces (`cf213` :2463-2729). S1 is misclassified against its own evidence (B7) and §9 lists 5 of 35 lander sites (B9).
M4 — PARTIAL. Store, verbs and lock classifier are accurately documented (`board_lock.py:149-158`, ABSENT/HELD/RESIDUE), but its Status asserts DRIFT on a board that is now in byte parity (B4).
M5 — PARTIAL. Adapter registers verified to the line (`install-hermes.sh:23,24,26`, `install-codex.sh:47,49,51,56,57,60`, `install-claude-code.sh:36,39,40,43`, `harness-vars.sh:203-204`, 28 unit tests). Held by §9 4 rows and self-declared unread bodies.
M6 — PARTIAL. Gate readings reproduce exactly (`44 module(s): 37 VERIFIED, 50 error(s)`, exit 1; spine 0). Holds the wrong boundary count (B2), a stale patch-chain row (B5), and a gate-coverage claim the checker cannot support (N3).
M7 — PARTIAL. Lifecycle controls are located correctly (`github-app-refresh.sh:24,28-30,55-61,103-135`; token.py mode check 346-351). Mint unrun (declared), §9 is 2 rows (B9).
M8 — PARTIAL. Both units read in full and both readings reproduce (`9 tests OK`; `15 gitleaks claim(s)`); only the RED metrics field holds it.
M9 — PARTIAL. The strongest control-plane chapter on the wire side (43 routes reproduce exactly, 57 flags, 379 log sites, 30 tables, `dispatchReplyVerdict:713-726`), but its composed admission sequence omits two live gates (B8) and its toolchain stamp is stale (B6).
M10 — PARTIAL. Handler surfaces, 91 test files, 3 slog sites and 67 metric strings all reproduce; the 1895-line body and the guard log surface are declared unread, which is honest and is why it is PARTIAL.
M11 — PARTIAL. Closest to WRITTEN: 23/23 log call sites, every setting locator exact, py_compile and the process-group claim both check out, and it withdraws the descendant-kill guarantee on its own evidence. Held by metrics RED and the asserting-free live tests it names.
M12 — PARTIAL. Content sha256 reproduces byte-for-byte, 401 admission reproduced live (401, unit `active`), both sinks corrected to the real paths. Held by the unframed SSE stream (F12-7) and the config-wired, unproven node client.
No chapter is SKELETON; no chapter reaches WRITTEN on its own RED ledger, and none may be called written while B1–B9 stand.

PANEL REVIEW COMPLETE

session_id: local-0f5106db9870121343a8a61da831bc1d20b91a6a76c8289876ac5ad7a099e09c

EXIT=0
```

### kimi

```
All verification complete. The scheduler suite re-ran green (25/25) at current HEAD. I have everything needed for the verdict.

VERDICT: FAIL

BLOCKING: 6 — findings that must be fixed before this chapter set can be called written
NON-BLOCKING: 3

FINDINGS:

1. kind: FALSE CLAIM — chapter M4 (BOARD), §7 verification table + §1 status
   claim quoted: "drift | python3 scripts/board_drift.py check --workdir /home/kara/code-factory --ref origin/main | byte parity, RESULT OK | 2026-11-06 | FAIL — RESULT: DRIFT (4 failed); ... 1 divergent id: CF-270 (workdir=pending, published=complete); HEAD=47d68b4 vs origin/main=4dc0ef0"
   evidence: I re-ran the exact documented command this round. Measured output: "PASS byte parity tasks.jsonl — identical", "PASS byte parity events.jsonl — identical", "board rows — 357 vs 357 rows; 0 divergent ids: none", "RESULT: OK". HEAD == origin/main == 8ae4f823334746733f3448d543f7d8a5c4162dec. The CF-270 merge the chapter itself said "must be reconciled ... and board_drift must be re-run after that merge" landed (commit 4dc0ef0) and the chapter was not updated. Related: §1/§13 claim "518 events"; measured `wc -l .coding-hermes/board/events.jsonl` = 519, and `boardctl validate` itself prints "357 tasks, 519 events".
   fix: re-measure the drift row and the events count at the current revision; record that the CF-270 reconciliation the chapter demanded is done.

2. kind: FALSE CLAIM — chapter M9 (SCHEDULER), §1 identity
   claim quoted: "go.mod declares go 1.26.0 + toolchain go1.26.6; go env GOVERSION resolves go1.26.6. Host go version = go1.26.5 (default PATH /home/kara/.local/bin/go); /usr/bin/go = go1.26.8"
   evidence: `go.mod` at HEAD 0203e982 reads "toolchain go1.26.10" (bumped by commit 9bc9e561, RELEASE-038 — one of 10 commits past the stamped 1771d3aa). `go version` = go1.26.10; `/usr/bin/go version` = go1.26.10. All three measured values are wrong against the current tree.
   fix: re-stamp the revision and re-measure the toolchain/host lines.

3. kind: FALSE CLAIM — chapter M10 (CRIER), §7 verification table (rule 4: not repeatable)
   claim quoted: "go test ./... | green | 2026-11-06, rev 691f0c78 | PASS (rc 0)"
   evidence: at the current HEAD (86c4c469, one commit past the stamp), `go test ./...` FAILS: "--- FAIL: TestMetricsState_SeriesRenderOnIdleBoot (0.04s) ... crier_detect_alerts_total{signal=\"odd_hour_volume\",severity=\"warning\"} = 1, want 0", "FAIL github.com/crier-dev/crier/cmd/server". Reproduced twice in full-package runs (58.0s and 47.4s); the single test passes under -run (0.070s) — a within-package contamination or clock-sensitive failure. Either way the documented command does not reproduce. Same false host-go sentence as M9 ("host go version = go1.26.5 ... /usr/bin/go = go1.26.8" — both are 1.26.10).
   fix: re-run at HEAD, record the cmd/server failure (and whether it is contamination or a real regression), correct the host-go values, re-stamp.

4. kind: FALSE CLAIM — chapter M6 (DOCUMENTATION), §7 verification table
   claim quoted: "patch chain | bash scripts/verify-patch.sh | VERIFY-PATCH: PASS | 2026-11-06 | PASS — 4 stages, 3 patches, f393a681…"
   evidence: re-run this round prints "PASS live: ... matches the shipped chain (5 stages, 4 patches, 57432007b324f382a90bf7405a8bb50735a87a145ed95f5e0e5b782b964e7687)" — 5 stages, 4 patches, a different digest. The PASS verdict holds; the quoted measured values are wrong.
   fix: re-quote the current chain output.

5. kind: FALSE CLAIM — chapter M3 (REPOSITORY), §7 note (count claim)
   claim quoted: "selftest.sh is 4,737 lines with named arms"
   evidence: `wc -l tests/selftest.sh` = 4852. The substantive claim (named arms, zero numbered-arm matches) verified true; the count is wrong.
   fix: correct the count.

6. kind: CONTRADICTION (structure) — all 12 code-factory chapters, §1 identity
   claim quoted: "Revision | 47d68b4da7e3dae49e2294ab3a77c7a75eba2657 (at derivation; code-factory HEAD, re-derived round 9)"
   evidence: `git rev-parse HEAD` = 8ae4f823334746733f3448d543f7d8a5c4162dec — five commits past the stamp (including f1d5cfb, the CF-270 verify-node.sh change). This is the root cause of findings 1, 4 and the locator drift below: the chapters describe a tree five commits old while calling it HEAD. The schema's own rule ("a check that passed three revisions ago is UNVERIFIED") makes the stamped verification tables UNVERIFIED until re-run. Most locators still verify (I checked ~75; the M0/M2/M5/M7/M8 line maps are exact), so this is not wholesale rot — but the stamp is false as written.
   fix: re-stamp all code-factory chapters at 8ae4f82 and re-run the verification tables that touch moved files.

NON-BLOCKING:

7. kind: UNVERIFIED (locator drift) — M1 §9/§11
   claim quoted: "RESULT: FAIL (verify-node.sh:53)", "unverified \"seed_drift: …\" at :194-198", ":205-214 precedence"
   evidence: current file has RESULT: FAIL at :76, the seed unverified call at :225, terminal precedence at :233-241 (the CF-270 port-validation block shifted every line). The F1-5 substance — checkout-unmeasurable warns without calling unverified() while the seed leg calls it — I verified is still true at :177 vs :225.
   fix: re-pin the locators.

8. kind: UNVERIFIED (locator) — M4 §2/§5/§11
   claim quoted: "--status complete REQUIRES --evidence-run-id (boardctl --help:25)"
   evidence: `scripts/boardctl --help` is a 4-line wrapper usage; the string appears under `boardctl update --help`. The substantive rule is real — I probed it live against a scratch board: "completion REFUSED for \"CF-999\": --evidence-run-id is REQUIRED when setting status \"complete\" (TR-251)".
   fix: point the locator at the update verb's help.

9. kind: OMISSION (gate blind spot, live) — M6 S9 / handbook_spine.py
   claim: `python3 scripts/handbook_spine.py` → "chapters=13 canonical contracts=18 findings=0" (reproduced by me, rc 0).
   evidence: findings 1, 4, 5, 7 above are stale measured values and drifted locators the spine did not catch — exactly the blind spot M6 names as OPEN ("it does not verify cited line numbers exist ... trusts the chapters' self-reported status word"). Not a new defect, but this round proves the blind spot is load-bearing.
   fix: acceptable as a named OPEN; would be blocking if the spine were cited as proof of correctness.

WHAT VERIFIED TRUE (sampled, all re-run by me this round): M0's entire lib.sh line map (:5-:78), 11/17 sourcer greps, and fails-closed fetch semantics; M1's F1-1 (bunker-provision.sh:214 tests [ -s ] while :233 prints "mode 600"), F2-2 PID-1755676 hardcode, disk_floor precedence; every M2 locator checked (:81-85, :113-114, :977-1007, :1176-1208, :1389-1422, :1479-1511) including the no-run_id reply shape; M3's GATE=\"\"/run_gate guard, gitreins pin 0.17.1, hook exit-0-when-no-config, cf213/cf244 arm locators (:2463-2729/:3433-3670), clone_lane F3-1/F3-2; M4's 357 rows, validate "RESULT: OK (7 warning(s))", board_lock adjudicate (:149-158); M5's [0-7]00-vs-"must be 600" predicate (F0-6), all adapter pins and --apply refusals, hermes python >=3.11,<3.14 gate; M6's gate output reproduced byte-exact ("44 module(s): 37 VERIFIED, 50 error(s)", MASTER-DOC: FAIL); M7's rc=2 bare CLI, 0600 key refusal, MIN_AGE=2400; M8's test_reclaim OK, 15-claim scan, BUILD_CACHES/AGED_PARENTS/PROTECTED constants, inclusive TTL boundary; M9's 30 tables / no verdicts, 43 routes, 57 flags, 379 log.Printf sites, dispatchReplyVerdict reads payload["ok"] only (:713-726), every admission_mode/main.go/server_metrics locator, go build PASS, and the full `env -u SCHEDULER_OPERATOR_RESTART_APPROVED go test ./...` re-run by me: 25/25 packages ok (internal/scheduler 185.1s); M10's 91 test files, 3 slog sites, 67 crier_ strings, Port :622=8767, EnableMetrics :673=true, metrics.go:2 "opt-in" comment, all handler/guard/policy locators, go build PASS; M11's 538 lines, 25 log( lines, single-match inert EXEC_TIMEOUT, and the code-level confirmation of F11-3/F11-4/F11-6/F11-8; M12's sha256 (b12a0ac5…), 273 lines, every constant at :43-54, live 401 on :8775, systemd active, unauthenticated /health, F12-3 hardcoded credential name, the :164 union annotation, timeout=300 at :204/:241. CT-02..CT-06 all name both sides correctly (dispatch.go:202/184 → handler.go:990; handler.go:1690 → node-bus-worker.py:1007; node-bus-worker.py:1176/1208 → handler.go:990; load_lane_config.py:31-37 → spawn.go:1244; dispatcher.py:500-508 → dispatch_leg.go:713).

DEFECT CLASSES: STALE-REVISION-STAMP, STALE-MEASURED-VALUE, FALSE-COUNT, FALSE-TOOLCHAIN-CLAIM, UNREPRODUCIBLE-TEST-STATUS, LOCATOR-DRIFT, GATE-BLIND-SPOT-ACTIVE

CHAPTER SCORECARD:
M0  — WRITTEN. Every cited line re-verified; probe reproducible; honest RED on metrics.
M1  — PARTIAL. Substance verified (F1-1, F1-5, F2-2), but the verify-node.sh locators drifted after the CF-270 fix and the revision stamp is five commits behind HEAD.
M2  — WRITTEN. Every checked locator and the reply-shape claim verified; the non-repeatable live check is honestly named.
M3  — PARTIAL. Landing/hook/clone claims all verified; the "4,737 lines" selftest count is false (4,852).
M4  — PARTIAL. Census, validate and lock classifier verified, but the headline drift row no longer reproduces (RESULT: OK today) and the events count is stale — against the chapter's own mandated re-run rule.
M5  — WRITTEN. Adapter matrix, pins, and the credential-predicate correction all verified in code.
M6  — PARTIAL. Gate FAIL reproduced byte-exact; the verify-patch quoted output (stages/patches/digest) is stale.
M7  — WRITTEN. CLI surface, 0600 refusal and lifecycle defaults verified; mint honestly UNVERIFIED.
M8  — WRITTEN. All three verification commands reproduce; constants and TTL boundary exact.
M9  — PARTIAL. Counts, routes, flags, settlement and admission locators all verified, and the full suite re-ran green at HEAD — but the toolchain claim (1.26.6 vs actual 1.26.10), both host-go values, and the revision stamp (10 commits behind) are false.
M10 — PARTIAL. Handler/guard/metrics inventory verified, but the documented `go test ./...` FAILS at HEAD (cmd/server), and the stamp/host-go values are stale.
M11 — WRITTEN. Full-file read confirmed; all eight findings verified in code; stamp is current HEAD.
M12 — WRITTEN. Hash, line count, live 401, systemd state and every locator reproduced; failure-mode analysis (F12-3/4/5/6/7) matches the code.

Bottom line: the document's evidentiary core is real — the overwhelming majority of its file:line claims survive re-derivation, which is more than the rejected version managed. But six measured claims, including a chapter's headline verification row and a test-suite PASS that currently runs red, do not reproduce against the code today, and every code-factory chapter calls a five-commit-old tree "HEAD". Re-stamp, re-measure the six rows, and this passes.

PANEL REVIEW COMPLETE

session_id: local-1e7b7a081a4982ae3c4ea92c042a0b33775136fda287d71062a1b795c74f4ebd

EXIT=0
```

### sol

```
│ cache/scratch/round10_judge_probes.py
│ @@ -0,0 +1,95 @@
│ +#!/usr/bin/env python3
│ +"""Read-only source review and isolated local fixtures; no real credentials."""
│ +import ast
│ +import contextlib
│ +import http.client
│ +import importlib.util
│ +import io
│ +import json
│ +import os
│ +from pathlib import Path
│ +import subprocess
│ +import tempfile
│ +import threading
│ +from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
│ +from unittest.mock import patch
│ +
│ +ROOT = Path('/home/kara/code-factory')
│ +def load(path, name):
│ +    spec = importlib.util.spec_from_file_location(name, str(path))
│ +    mod = importlib.util.module_from_spec(spec)
│ +    spec.loader.exec_module(mod)
│ +    return mod
│ +spine = load(ROOT/'scripts/handbook_spine.py', 'review_spine')
│ +chapters = spine.chapters()
│ +print('CHAPTER_COUNT', len(chapters), 'CANON', len(spine.CANON), 'BOUNDARY', len(spine.BOUNDARY), 'INTERNAL', len(set(spine.CANON)-spine.BOUNDARY))
│ +print('RED_DECLARATIONS', {name: text.split('## RED field count: ')[-1].splitlines()[0] for name,text in chapters.items()})
│ +print('SPINE_NORMALIZED_STRING_DEFAULTS', repr(spine.norm_default('`alpha`')), repr(spine.norm_default('`beta`')))
│ +# Challenge the actual checker in memory, leaving the files untouched.
│ +mutated = dict(chapters)
│ +mutated['M0-shared-contract'] = mutated['M0-shared-contract'].replace('## 6. Contracts in and out', '## 6. Contracts in and out\n\n| CT-99 | invented | out | `fake.py:missing` | `fake.go:missing` | works |')
│ +buf=io.StringIO()
│ +with patch.object(spine, 'chapters', return_value=mutated), contextlib.redirect_stdout(buf), patch('sys.argv', ['handbook_spine.py']):
│ +    rc=spine.main()
│ +print('UNKNOWN_CONTRACT_MUTATION', 'rc='+str(rc), repr(buf.getvalue()))
│ +mutated=dict(chapters)
│ +mutated['M0-shared-contract']=mutated['M0-shared-contract'].replace('## 5. Settings register', '## 5. Settings register\n\n| TEST_DEFAULT | `alpha` | any | test | test |')
│ +mutated['M1-provisioning']=mutated['M1-provisioning'].replace('## 5. Settings register', '## 5. Settings register\n\n| TEST_DEFAULT | `beta` | any | test | test |')
│ +buf=io.StringIO()
│ +with patch.object(spine, 'chapters', return_value=mutated), contextlib.redirect_stdout(buf), patch('sys.argv', ['handbook_spine.py']):
│ +    rc=spine.main()
│ +print('CONFLICTING_STRING_DEFAULTS_MUTATION', 'rc='+str(rc), repr(buf.getvalue()))
│ +# Execute only the real pure directive decoder, avoiding worker side effects.
│ +node_ast=ast.parse((ROOT/'scripts/node-bus-worker.py').read_text())
│ +node_ns={'base64': __import__('base64'), 'DIRECTIVE_MEMBERS':('task','text','prompt','message','body')}
│ +exec(compile(ast.Module(body=[n for n in node_ast.body if isinstance(n,ast.FunctionDef) and n.name=='directive_text'],type_ignores=[]),'<actual node decoder>','exec'),node_ns)
│ +dispatch_ast=ast.parse(Path('/home/kara/crier-fleet/dispatcher.py').read_text())
│ +dispatch_ns={'base64':__import__('base64'), 'json':json, 'log':lambda s:None}
│ +exec(compile(ast.Module(body=[n for n in dispatch_ast.body if isinstance(n,ast.FunctionDef) and n.name=='payload_task'],type_ignores=[]),'<actual dispatcher decoder>','exec'),dispatch_ns)
│ +from types import SimpleNamespace
│ +payload={'text_b64':'!!!invalid!!!','text':'legacy replacement directive'}
│ +print('NODE_BAD_B64',node_ns['directive_text'](payload))
│ +print('DISPATCHER_BAD_B64',repr(dispatch_ns['payload_task'](SimpleNamespace(payload=payload))))
│ +# A synthetic token local to this isolated fixture; never inspect token files or call live upstreams.
│ +proxy=load(Path('/home/kara/.hermes/scripts/cf-inference-proxy.py'),'review_proxy')
│ +class Upstream(BaseHTTPRequestHandler):
│ +    def do_POST(self):
│ +        self.rfile.read(int(self.headers.get('Content-Length','0')))
│ +        body=b'data: [DONE]\n\n'
│ +        self.send_response(200)
│ +        self.send_header('Content-Type','text/event-stream')
│ +        self.send_header('Content-Length',str(len(body)))
│ +        self.end_headers()
│ +        self.wfile.write(body)
│ +    def log_message(self,*args):pass
│ +up=ThreadingHTTPServer(('127.0.0.1',0),Upstream)
│ +px=ThreadingHTTPServer(('127.0.0.1',0),proxy.Handler)
│ +proxy.UPSTREAM='http://127.0.0.1:'+str(up.server_port)
│ +proxy.UPSTREAM_MODEL=''
│ +proxy.upstream_key=lambda:'synthetic-fixture-key'
│ +proxy.load_tokens=lambda:{'fixture-node':'synthetic-fixture-token'}
│ +proxy.log_usage=lambda rec:None
│ +proxy.capture_request=lambda *args:None
│ +threads=[threading.Thread(target=s.serve_forever,daemon=True) for s in (up,px)]
│ +for t in threads:t.start()
│ +try:
│ +    conn=http.client.HTTPConnection('127.0.0.1',px.server_port,timeout=0.7)
│ +    conn.request('POST','/v1/chat/completions',json.dumps({'model':'hermes','stream':True}),{'Authorization':'Bearer synthetic-fixture-token','Content-Type':'application/json'})
│ +    r=conn.getresponse()
│ … omitted 17 diff line(s) across 1 additional file(s)/section(s)
VERDICT: FAIL
BLOCKING: 22 — findings that must be fixed before the affected chapters can be called written
NON-BLOCKING: 1

FINDINGS:

Review basis:
  Read all thirteen chapters, OUTLINE.md, MASTER-DOC-SCHEMA.md, the spine checker, and implementation regions across all five covered systems. Judged the working-tree chapters, not previous seats’ verdicts.

  Required spine command reproduced:
    python3 scripts/handbook_spine.py
    chapters=13  canonical contracts=18
    findings=0
    exit 0

  Therefore there are no findings emitted by the required spine run to promote to blocking CONTRADICTION findings. Its zero does not establish semantic correctness: independent fault-injection checks below demonstrate missed defects.

  Other verification reproduced:
    tests/test_disk_floor.py: 12 tests, OK
    tests/test_lane_target.py: 40 tests, OK
    tests/test_harness_resolve.py: 28 tests, OK
    tests/test_reclaim.py: 9 tests, OK
    check_scan_scope.py: 15 claims, RESULT: OK
    master_doc_check.py: 44 modules, 37 declared VERIFIED, 50 errors, MASTER-DOC: FAIL
    board_drift.py: RESULT: DRIFT (4 failed), CF-270 pending locally versus complete in origin/main
    boardctl validate: 357 tasks, 518 events, RESULT: OK (7 warning(s))
    Live inference proxy, unauthenticated POST: HTTP 401
    Proxy content hash: b12a0ac521c4b5a9cd7e2b76883a7edf2c9e0efd87d9bc3be3d2056d3f39e0b5

  Isolated probes used synthetic credentials, loopback fixture servers and in-memory mutations, not real provider calls. Reproduction script:
    /home/kara/.hermes/cache/scratch/round10_judge_probes.py

  I did not repeat the full Go build/test suites, live-node certification, harness installation/conformance or GitHub App minting. Their historical PASS claims are not fresh execution evidence from this judge. A final compound aggregate command was approval-blocked; no results from that command are claimed here.

B01 — FALSE CLAIM — M6
  Claim:
    The spine “Enforces … canonical contract ids … setting-default conflicts” (M6:50).

  Evidence:
    scripts/handbook_spine.py:200-213 checks whether expected canonical IDs appear; it never rejects an additional unknown CT ID.
    scripts/handbook_spine.py:126-137 strips every backticked span from a default, including the value itself.

    Independently executed in-memory mutations:
      Add CT-99: rc=0, findings=0.
      Document TEST_DEFAULT as `alpha` in one chapter and `beta` in another: rc=0, findings=0.
      norm_default('`alpha`') and norm_default('`beta`') both returned ''.

  Fix:
    State the actual enforcement boundary. Reject unknown CT IDs and preserve literal default values during normalization. Add negative tests for both mutations before claiming these guarantees.

B02 — CONTRADICTION — M6; OUTLINE Part IV
  Claim:
    M6:98 calls BOUNDARY “the 14 boundary contracts.”
    OUTLINE:204-206 says five internal contracts leave fourteen boundary contracts.

  Evidence:
    Executing the checker’s actual data structures produced:
      CANON=18
      BOUNDARY=13
      INTERNAL=5

    scripts/handbook_spine.py:64-84 contains the boundary set. CT-05 is explicitly excluded from it.

  Fix:
    Derive these counts from CANON and BOUNDARY instead of maintaining prose copies. Correct the boundary count to thirteen. Extend the count gate to cover the outline and this policy census.

B03 — UNVERIFIED — M0, M2, M3, M4, M5, M6, M7, M8, M9, M10, M12
  Claim:
    “One side named + the other marked missing/external” is an “honest terminal state, not a chapter defect” (for example M2:94-96 and M10:133-134).

  Evidence:
    The brief supplies no exemption from the both-sides rule. MASTER-DOC-SCHEMA.md:56-57 explicitly requires both implementation sides.

    Several rows additionally declare works without verifying the wire:
      M2:89, CT-11: both sides external, state works.
      M9:202, CT-15: both sides external, justification “OUTLINE Part IV.”
      M12:95, CT-07: both sides external, justification “OUTLINE Part IV.”

    An outline assertion is not implementation evidence or measured output.

  Fix:
    Keep unavailable sides explicitly UNVERIFIED and blocking; do not grant a completion exemption or inherit works from the outline. Supply accessible implementation references and repeatable observations where available. Obtain an explicit scope/contract waiver from the owner if a boundary is intentionally not verifiable.

B04 — OMISSION — all chapters, §6
  Claim:
    The contract tables constitute “Contracts in and out.”

  Evidence:
    Their common columns are ID, peer, direction, producer, consumer and state. OUTLINE:200-203 also requires payload, timing, failure semantics and breaking-change policy.

    For example M11:93-94 identifies retrieve and completion endpoints but supplies no complete lease/deadline compatibility contract. The code’s actual receive and completion operations are dispatcher.py:435 and :500-519. M10’s Python client has explicit required-ID and lease behavior at clients/python/crier_client.py:1038-1078 that is not captured in a complete canonical contract record.

  Fix:
    Give every interface one authoritative detailed contract containing all required fields. Chapters may link to it rather than duplicate it. A producer/consumer name table is not the full wire contract.

B05 — OMISSION — M0–M8, M11, M12
  Claim:
    Each affected §8 declares “RED — none,” while several §1 status cells still declare VERIFIED.

  Evidence:
    These chapters explicitly leave the required metrics field RED. MASTER-DOC-SCHEMA.md:72-79 and OUTLINE:123 make absence a RED field, not an optional omission. Independently inspected lib.sh, dispatcher.py and cf-inference-proxy.py contain the documented print/log paths but no metric registry.

  Fix:
    Preserve the honest RED declarations and mark the chapters PARTIAL. Resolve the observability requirement with actual type/label/question/scrape contracts, or obtain an explicit schema waiver. Do not silently treat an absence-proved RED as a completed required field.

B06 — UNVERIFIED — M1, M2, M5, M7, M10
  Claim:
    Verification rows include live-node certification, a node-local signed-read ladder, harness conformance and token minting.

  Evidence:
    M1:150 and M5:141 explicitly say not run.
    M2:104 and M10:144 give `python3 ~/node-bus-worker.py --check` on another machine, without a complete control-host-to-node invocation.
    M7:91 gives `python3 scripts/github-app-token.py token …`, which is not an executable verification command.

    The small unit suites reproduced successfully, but they do not certify these integration wires.

  Fix:
    Supply exact commands, required credential-file names without credential values, execution location, prerequisites, expected refusal/success observations and revision-stamped results. Until repeated, retain these checks as blocking UNVERIFIED. I could not repeat them from the instructions supplied.

B07 — OMISSION — M1
  Claim:
    §5 is the provisioning settings register.

  Evidence:
    It has no operational register for node_env.py and omits node_freshness.py controls.
    scripts/node_env.py:473-486 accepts --env-file and repeatable --config-set, and requires check/apply mode.
    :495-503 targets HOME/.hermes/.env and config.yaml.
    :548-556 carries unmanaged variables forward.
    scripts/node_freshness.py:677-702 defines --path=repo, --timeout=180 and refusal below one second.

    These controls alter configuration preservation, measurement location and failure behavior.

  Fix:
    Register these controls individually with defaults, accepted values, precedence, consumers and consequences. Explain unmanaged-variable preservation and the freshness timeout refusal. “Settings surface read” is not a written settings contract.

B08 — OMISSION — M2
  Claim:
    §5 documents dispatch controls; --harness-wall/--timeout defaults are given as DEFAULT_HARNESS_WALL/DEFAULT_TIMEOUT (M2:77).

  Evidence:
    scripts/node-bus-worker.py:83-84 defines the actual defaults as 10 and 1800 seconds.
    :1437-1476 exposes --dry-run and identity, token, workdir, harness and gateway overrides absent from the register.
    :1381-1385 explicitly says a dry run has already leased messages and leaves them to expire.

  Fix:
    Expand symbolic defaults into values and register the omitted operational controls. State prominently that --dry-run avoids execution/post/ack but does not avoid inbox custody mutation: it leases messages.

B09 — CONTRADICTION — M3
  Claim:
    S1 is “active,” supported by clone_lane.py’s main entrypoint, while the same cell says “operator-invoked; no in-repo caller” (M3:37).

  Evidence:
    OUTLINE:108-113 requires an invoking scheduler lane, cron, timer or unit for active classification. A main entrypoint proves direct executability, not activation. The chapter also correctly establishes at :41-45 that clone_lane.py copies scheduler lane rows, not repository checkouts.

  Fix:
    Classify clone_lane.py according to an actual invoker, or mark it operator-invoked. Classify repo_freshness.py separately rather than assigning both files one unsupported activation status. Keep lane-row cloning distinct from checkout creation.

B10 — UNVERIFIED — M3
  Claim:
    The chapter is “VERIFIED (source + shipped behavioral arm)” (M3:12), including ownership of commit hooks and gates.

  Evidence:
    scripts/install-gitreins.sh:59-63 checks an executable file containing the word gitreins.
    :120-122 preserves an existing matching hook.
    M3:159-164 correctly acknowledges that effective core.hooksPath is not resolved and a rejecting-commit fixture is missing.

    The documented landing behavior test does not prove that Git invokes the installed commit gate.

  Fix:
    Separate landing verification from hook verification. Supply a disposable repository test that resolves the effective hook path and proves a deliberately rejected commit cannot advance HEAD. Keep S3 UNVERIFIED until that test is exercised.

B11 — UNBUILDABLE — M4
  Claim:
    A clean RESIDUE permits proceeding; degraded RESIDUE means “do NOT proceed” and requires establishing observation quality (M4:153-154).

  Evidence:
    scripts/board_lock.py:73-94 distinguishes free from error internally.
    :149-158 discards the error detail and emits the same RESIDUE form for both.

    A fault-injected execution of the actual adjudicate function with flock_probe=('error','open-failed') returned:
      RESIDUE consumers=0 commits_after_mtime=unknown

  Fix:
    Provide an exact independent probe that distinguishes the cases, or expose UNKNOWN/error detail from the classifier. Until then, the safe documented action for an indistinguishable RESIDUE must be to stop and investigate. The current branching procedure asks the operator to observe information its command suppresses.

B12 — OMISSION — M5
  Claim:
    §5 supplies the harness and toolchain settings register; the Go dependency is merely “pinned” (M5:66).

  Evidence:
    scripts/install-go.sh:7-15 defines go1.26.5, architecture-specific digests, a 1 GiB floor, rsc.io/quote v1.5.2, check mode and GO_INSTALL_ROOT defaulting to HOME/go-toolchain.
    :53-85 performs a cold-cache module proof with a 30-second timeout and explicit GOPROXY handling.

    These values and their operational consequences are absent from M5’s register.

  Fix:
    Document the installer pin, artifact checks, root override, disk floor, network proof, timeout and cache-cleanup behavior. “Pinned” is NAME ONLY when the pin and its consequences are not registered.

B13 — UNBUILDABLE — M6
  Claim:
    M6 owns fill, gate, render and delivery of this handbook.

  Evidence:
    The chapter itself acknowledges an incompatible selection path at :165-170.
    scripts/gen_nasa_handbook.py:253-260 selects NN-*.md and refuses an empty selection.
    scripts/master_doc_check.py:186-209 also selects NN-*.md.
    Actual renderer execution printed:
      no modules found
    Actual fill dry run printed:
      todo=0 provider=deepseek workers=2

    The delivered sources are M*.md chapters.

  Fix:
    Establish one working chapter-aware fill/check/render path and document an invocation that consumes the real chapter set and produces an inspectable artifact. Until that exists, this module is accurately described as broken, but cannot be called written as an operational delivery procedure.

B14 — OMISSION — M6
  Claim:
    panel_loop.py is the loop producing the handbook, but its settings and termination behavior are not registered.

  Evidence:
    scripts/panel_loop.py:278-294 defines rounds, max-seconds, start-round, writer/judge timeouts and uncapped interpretations.
    :332-354 can exit successfully after two rounds with no new defect class, even without unanimous PASS.
    :33-37 also defines external scratch dependencies and writer model/provider overrides.

  Fix:
    Register these controls individually. Distinguish successful process termination from document acceptance, including the no-new-defect-class exit while blockers remain. Give the operator a readback procedure for the actual stop reason and outstanding findings.

B15 — OMISSION — M9
  Claim:
    “Remaining 32 of the 57” settings are listed with consequences “not expanded per row” (M9:160-180).

  Evidence:
    cmd/schedulerd/main.go:174-208 contains concrete verification, session-reaping, routing, simulation, failure-rate disable and output controls.
    Examples include --reap-sessions-apply, --auto-disable-failure-rate, --auto-disable-min-ticks and --config.

    The chapter explicitly acknowledges that the required consequence column is missing.

  Fix:
    Expand each setting into default, valid range, reader, precedence and a specific consequence. Mutation switches and auto-disable thresholds cannot be discharged by a group label. These entries remain NAME ONLY under the brief.

B16 — OMISSION — M9
  Claim:
    §3 presents an “Ordered admission procedure” (M9:58-86).

  Evidence:
    The actual MultiPoolPacker.Pack path includes:
      packer_select.go:36-42 — flat fallback versus namespace allocation.
      :47-80 — namespace concurrency accounting.
      :136-164 — disabled namespace, allocation and budget filtering.
      :216-251 — starvation, pending-work and bump urgency adjustments.
      :264-287 — held-lane rotation preceding ordinary urgency.

    These mechanisms affect which run is admitted but are not composed into the chapter’s procedure.

  Fix:
    Trace actual call order through evaluation, allocation, candidate filtering, scoring, rotation, concurrency and spawn reservation. State the refusal/deferral and observable reason for each gate. The existing five-item list is a partial account, not an operational admission algorithm.

B17 — OMISSION — M9
  Claim:
    S3 durable state and S4 operator surfaces are documented.

  Evidence:
    M9:105-106 explicitly leaves write authorities and recovery queries unwritten.
    :52-55 explicitly leaves per-route request/response shapes and write-authority readbacks unwritten.

    Table keys and route names do not tell an operator how to recover a run, mutate a lane safely or verify the resulting authority state.

  Fix:
    For run-critical stores, name the writer, legal transitions, recovery selector and idempotency boundary. For operator mutations, document auth, input, failure response and exact readback. Retain S3/S4 as PARTIAL until these procedures exist.

B18 — OMISSION — M9, M10
  Claim:
    Required log and metric inventories are present.

  Evidence:
    M9:240-244 explicitly inventories only two of its measured 379 scheduler logging sites.
    M10:177-180 explicitly leaves the per-metric type/labels/question/scrape contract incomplete.
    M10:198-203 explicitly leaves guard logs untabulated.
    crier/internal/guard/guard.go:430-457 contains the omitted guard audit surface.

  Fix:
    Finish the operator-relevant inventory at the declared module scope. Provide verbatim templates, triggering conditions and evidentiary limitations, and complete per-metric contracts. Naming uncovered sites is honest RED reporting, not completion of the field.

B19 — OMISSION — M10
  Claim:
    Storage custody is described principally as PostgreSQL versus SQLite (M10:114-119).

  Evidence:
    config/config.go:113-123 can resolve to memory.
    :732-767 implements database URL precedence, explicit backend selection and refusal rules.
    :770-808 implements pool settings and constraints.

    The memory mode is run-correctness relevant because custody can be process-local rather than durable. The chapter does not provide a complete default/range/consequence register or a running-backend proof.

  Fix:
    Document memory, SQLite and PostgreSQL; all selection inputs and precedence; durability consequences; startup refusal conditions; and an exact means of proving the serving backend. Do not leave custody choice as a named-but-unwritten RED.

B20 — FALSE CLAIM — M10
  Claim:
    Guard.Timeout: “too short fails checks open.”
    Guard.MaxConcurrent: “0 or overflow saturates the guard” (M10:96-97).

  Evidence:
    internal/guard/guard.go:332-357 makes an error outcome depend on FailClosed, policy action and high-confidence deterministic evidence. A short timeout does not universally produce an allow.
    config/config.go:1154-1158 refuses CR_GUARD_MAX_CONCURRENT<=0 at startup; that configuration does not simply run a saturated guard.

  Fix:
    Make consequences conditional on the actual error policy and deterministic evidence. Distinguish rejected configuration from runtime saturation, and distinguish supported values from invalid inputs.

B21 — UNVERIFIED — M11
  Claim:
    Status is VERIFIED, although live-job tests are “decoration” and an execution mode remains unmeasured (M11:12).

  Evidence:
    tests/test_durable_job.py:7-11 invokes a real dispatch and prints its result without a result-dependent failure exit.
    tests/test_job_kill.py:23-35 computes and prints PASS/FAIL but likewise does not fail the process on a bad result.
    dispatcher.py:336-358 contains the separate synchronous execution path.
    :326-331 performs deadline termination, whose descendant behavior the chapter itself leaves unresolved.

  Fix:
    Label source inspection, syntax validity and behavioral certification separately. Add result-dependent failing oracles for both modes, timeout termination, descendant survival, reply delivery and replay. I did not run these live-node scripts; a source read and py_compile do not establish their operational guarantees.

B22 — CONTRADICTION — M12
  Claim:
    §1 declares VERIFIED for “routing, streaming, capture,” while §11 says streaming correctness is UNVERIFIED until completion/framing passes.

  Evidence:
    cf-inference-proxy.py:105 selects HTTP/1.1.
    :206-224 sends streaming headers without Content-Length, Transfer-Encoding or Connection: close, then returns without closing the response.

    I exercised the actual Handler against a finite loopback SSE upstream using synthetic credentials:
      ISOLATED_STREAM 200
      Content-Length absent
      Transfer-Encoding absent
      Connection absent
      ISOLATED_STREAM_EOF False TimeoutError

    This reproduces the documented healthy-stream completion defect, independently of earlier seats.

  Fix:
    Grade streaming FAILING, admission separately verified, and the node/upstream integration separately UNVERIFIED. Ship a repeatable framing/completion oracle. Keep the chapter PARTIAL until it supplies a working streaming contract or a clearly bounded failure procedure rather than a blanket VERIFIED status.

N01 — NON-BLOCKING — CONTRADICTION — M4
  Claim:
    “All four rows” in the contract discussion (M4:96).

  Evidence:
    M4:92-94 contains three rows: CT-14, CT-13 and CT-10.

  Fix:
    Change “four” to “three,” or avoid the maintained count. This is editorial and does not change the underlying contract findings.

DEFECT CLASSES:
  checker false negatives;
  conflicting census claims;
  unsupported boundary exemptions;
  incomplete wire contracts;
  unresolved required fields;
  unreproducible integration checks;
  missing setting consequences;
  activation misclassification;
  unproven gate enforcement;
  unobservable recovery branches;
  disconnected document delivery;
  undocumented stop semantics;
  incomplete admission authority;
  missing custody guarantees;
  incorrect degradation consequences;
  non-failing verification oracles;
  inconsistent verification status

CHAPTER SCORECARD:
  M0 — PARTIAL
    The shell helper account is substantive and source-backed. Mandatory metrics remain RED, and the one-sided external-contract completion exemption is unsupported.

  M1 — PARTIAL
    Provisioning and seed behavior have useful evidence. Environment/freshness controls are missing from the register, live certification is unverified, and metrics remain RED.

  M2 — PARTIAL
    Directive decoding and settlement ordering are materially documented. Operational switches, dry-run lease effects, complete defaults and repeatable live verification remain incomplete.

  M3 — PARTIAL
    Landing mechanics and optional gating are described with code references. Activation classification is inconsistent, effective hook enforcement lacks a negative proof, and metrics remain RED.

  M4 — PARTIAL
    The store census and drift observations reproduced. The clean/degraded RESIDUE recovery branch cannot be followed using the documented classifier output; external write wires and metrics remain unresolved.

  M5 — PARTIAL
    The shared variable contract and adapter differences are useful. Toolchain controls are incompletely registered, live conformance remains unverified, and metrics remain RED.

  M6 — PARTIAL
    The chapter honestly identifies substantial pipeline breakage. Delivery still does not consume the chapter set, spine guarantees exceed enforcement, and panel termination controls are unwritten.

  M7 — PARTIAL
    Credential domains and several lifecycle controls are distinguished. Minting lacks a complete repeatable invocation and current behavioral evidence; the external wire and metrics remain RED.

  M8 — PARTIAL
    Target roots, TTL behavior and scan scope are concrete; the reclaim and scope checks reproduced. Required metrics remain RED, and the external-contract completion rule is not satisfied.

  M9 — PARTIAL
    Settlement, selected defaults and store keys are substantive. Admission composition, auxiliary-setting consequences, mutation/readback contracts, recovery authorities and log coverage remain incomplete.

  M10 — PARTIAL
    Transport, signed reads and several guard branches are source-backed. Storage custody, metric contracts, guard logs and integration verification remain incomplete; two setting consequences contradict code.

  M11 — PARTIAL
    The source-level job, ledger and completion descriptions are substantial. VERIFIED overstates behavioral assurance: the shipped result scripts lack failing oracles, execution modes are not fully certified, and metrics remain RED.

  M12 — PARTIAL
    Hash, live unauthenticated refusal and the streaming failure reproduced. Blanket VERIFIED conflicts with the demonstrated framing defect; client/upstream contracts and metrics remain unresolved.

PANEL REVIEW COMPLETE

session_id: local-6b779dc6b314ff03ff1fd9aee6c47734c13c96e4a0c920b3b733c86e06df318a

EXIT=0
```

