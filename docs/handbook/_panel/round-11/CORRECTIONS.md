# CORRECTIONS — round 11

Generated 2026-11-06T21:15:37-0500.

## Verdicts

- **deepseek** — FAIL, blocking 4, 4890 bytes, complete=True
- **glm** — FAIL, blocking 2, 8749 bytes, complete=True
- **grok** — FAIL, blocking 8, 15434 bytes, complete=True
- **kimi** — FAIL, blocking 12, 13470 bytes, complete=True
- **sol** — FAIL, blocking 23, 31812 bytes, complete=True

## Verdict text (verbatim, per seat)

### deepseek

```
VERDICT: FAIL

BLOCKING: 4 — findings that must be fixed before these chapters can be called written
NON-BLOCKING: 1

FINDINGS:

1. CONTRADICTION — M4 — claim: "the store is measured (357/518)" (CT-14 row, §6). Evidence: `wc -l .coding-hermes/board/events.jsonl` = 519; the chapter's own §7 records "519 lines" and §13 F4-4 states "The events count is 519, not 518." A stale pre-reconciliation count survives in exactly one cell. Fix: change 518 → 519 in the CT-14 producer/consumer cell.

2. CONTRADICTION — M10 — claim: §13 evidence-of-record "go test ./... (PASS)" contradicts §7 "**FLAKY** — not a clean PASS" and §1 RED "go test ./... flaky — not a clean PASS at HEAD". Evidence: all three lines quoted from the same chapter, opposite outcomes for the same command at the same revision. Fix: record §13 as FLAKY to match §7 and §1.

3. FALSE CLAIM (stale defect diagnosis) — M10 — claim: §7 documents `TestMetricsState_SeriesRenderOnIdleBoot` (`crier_detect_alerts_total ... = 1, want 0`) as a live flake "not a clean PASS at HEAD `86c4c469`". Evidence: live crier HEAD is `dc15b2d6`; commit `eb21ca03` ("make the idle-boot detect-alert assertion order-insensitive") landed after the stamp and directly fixes the order-sensitivity the chapter still reports as live. The flakiness RED is stale at the tree the chapter's own "HEAD" now resolves to. Fix: re-stamp to the true HEAD and re-run `go test ./...` before asserting flakiness.

4. UNBUILDABLE — M6 — claim: the delivery pipeline renders/checks this handbook (F6-1 is disclosed but unresolved). Evidence: `master_doc_check.py:188`, `gen_nasa_handbook.py:18` + `:253-260` (hardcodes `docs/master`), and `master_doc_fill.py:422` all select `[0-9][0-9]-*.md`, which matches none of the `M0-…-*.md` chapters. Only `handbook_spine.py` selects `M*.md`. Fix: wire a chapter-aware selection path in fill/check/render (or retire them as the delivery path and name the spine the real gate).

NON-BLOCKING:

5. M9 §1 — revision note says "carries board-only commits past this stamp"; the single post-stamp commit `972f11c8` is a `.qa/chaos-probes/errorpath.sh` chmod, not a board commit. Substance is sound — every cited Go file is byte-identical to the stamp — but the wording is imprecise.

DEFECT CLASSES: stale-count-residual · evidence-table-contradiction · stale-defect-diagnosis · unbuildable-delivery-pipeline

CHAPTER SCORECARD:
- M0 — WRITTEN. Every helper line-cited; 11/17 sourcing and the fetch_verified fail-closed probe reproduced; sole RED is metrics-absent (correct per schema).
- M1 — WRITTEN. Settings registers filled with consequences; two measured lies (F1-1, F1-5) named; four file bodies honestly disclosed UNVERIFIED.
- M2 — WRITTEN. CF-354 fixed and CF-355 carried; reply shape (`status`, no `run_id`/`outcome`) verified against node-bus-worker.py.
- M3 — WRITTEN. Shipped landing arm run (`SHIPPED_LANDING_ARM_RC=0`); F3-2/F3-3/F3-5 verified.
- M4 — PARTIAL. One stale count residual (518 vs 519) in CT-14.
- M5 — WRITTEN. Settings registers expanded; F5-5 (computed installer caller) corrected.
- M6 — PARTIAL. Delivery pipeline cannot select these chapters (UNBUILDABLE, F6-1); the gate is structural, not semantic (self-declared).
- M7 — WRITTEN. Credential lifecycle registered; credential-domain correction (scoped token is fleet-gh-scope.py, not M7).
- M8 — WRITTEN. Both units read in full; exact reap targets and boundaries documented.
- M9 — PARTIAL. Per-route contract and store write-authorities/recovery queries unwritten (self-declared); §9 inventory 2 of 379 sites.
- M10 — PARTIAL. Evidence-line contradiction plus a stale flakiness diagnosis.
- M11 — WRITTEN. Full read; all 23 log lines; the kill-process-group guarantee honestly withdrawn (F11-8).
- M12 — WRITTEN. Full read; admission/routing/capture verified (401 reproduced, sha256 reproduced); streaming FAILING demonstrated (F12-7), not merely unverified.

Spine: `python3 scripts/handbook_spine.py` → `chapters=13 canonical contracts=18 findings=0`, exit 0. No spine findings to carry as blocking.

The four rules are otherwise met: claims carry file:line or quoted command output (rule 1); internal contracts CT-02/03/04/05/06/08 name both sides (rule 2); settings carry default/range/consequence, including M9's 32 auxiliary flags (rule 3); and every key command I repeated reproduced exactly — 30 tables, 43 routes, 57 flags, 379 log.Printf, `dispatch.go:202` `text_b64`+`board`, `dispatch_leg.go:713-726` reading only `payload["ok"]` (CF-355 confirmed live), proxy sha256 `b12a0ac5…`, live 401, crier handler slog=3, dispatcher 538 lines, `go build ./...` rc 0. Live-node ladders are honestly marked UNVERIFIED rather than asserted (rule 4).

PANEL REVIEW COMPLETE

session_id: local-7ee07bffa59959724bfcf24fa3e4c683384ebad8847a2e37b09c2114965c68e7

EXIT=0
```

### glm

```
│ /tmp/ffc2.sh
│ @@ -0,0 +1,6 @@
│ +#!/bin/bash
│ +. /home/kara/code-factory/scripts/lib.sh
│ +fetch_verified http://127.0.0.1:1/nothing /tmp/ffc-artifact2 deliberately-wrong-digest
│ +rc=$?
│ +echo "FETCH_RC=$rc"
│ +[ -e /tmp/ffc-artifact2 ] && echo "ARTIFACT=yes" || echo "ARTIFACT=no"
All verification complete. I checked every chapter against the code with live commands — locators, defaults, counts, contract rows, and repeatable verification commands across all five systems. Composing the verdict.

VERDICT: FAIL

BLOCKING: 2 — findings that must be fixed before this chapter set can be called written
NON-BLOCKING: 3

FINDINGS:

1. kind CONTRADICTION — chapter M4, §6 CT-14 state cell: "the store is measured (357/518) but the foreman→board write wire is not exercised in this repo".
   Evidence: measured this round, `wc -l .coding-hermes/board/events.jsonl` = 519; M4's own §1 ("357 rows / **519** events"), §7 ("PASS (519)") and F4-4 ("The events count is 519, not 518") all state 519. The CT-14 cell carries the pre-reconciliation 518 that F4-4 explicitly supersedes — a stale count inside a contract-state cell of the same chapter.
   Fix: change "(357/518)" to "(357/519)" in the CT-14 cell.

2. kind UNVERIFIED — chapter M10, §7 "`go test ./...` … **FLAKY** — not a clean PASS at HEAD" and §1 "Revision `86c4c469…` (crier repo HEAD at round-11 derivation…)".
   Evidence: crier HEAD is now `dc15b2d6`, two commits past the stamp; `eb21ca03` ("test(cmd/server): make the idle-boot detect-alert assertion order-insensitive") fixes exactly the test M10 names as flaky — it removes the `crier_detect_alerts_total{signal="odd_hour_volume"} = 1, want 0` assertion M10 quotes and documents the root cause (QA-CRIER-56: CR_DETECT_QUIET_HOURS 01:00–05:00 UTC window contamination, matching M10's own "clock-sensitive" diagnosis). Re-run by this judge at live HEAD: `go build ./...` rc 0; `go test ./cmd/server/ -run TestMetricsState_SeriesRenderOnIdleBoot -count=1` ok (0.326s); `go test ./cmd/server/ -count=1` ok (40.2s). The FLAKY RED and the RED-count-5 are therefore stale: the fix landed after the stamp, and unlike M9 ("the repo is live and carries board-only commits past this stamp"), M10 does not disclose stamp drift while its "crier repo HEAD" claim is no longer true.
   Fix: re-stamp M10 to current crier HEAD, re-run `go test ./...` there, and either drop the FLAKY row (RED count 5→4) or record the re-measured state; disclose the post-stamp commits as M9 does.

3. (non-blocking) kind CONTRADICTION — OUTLINE VIII.1: "the `foreman → scheduler` contract is **broken** because 3 of 11 disagree" vs OUTLINE Part IV CT-05 and M9 §6, which both state the 3-of-11 breakage is **unmeasured** ("no command establishes which three files disagree or on what") and the state UNVERIFIED. The outline line lacks the supersession annotation its Part IV neighbours carry.
   Fix: annotate VIII.1 as superseded by M9 §6 CT-05, or strike the "broken because" clause.

4. (non-blocking) kind CONTRADICTION — OUTLINE Part IV CT-02 payload shape "envelope: run_id, corr_id, lane, board_row, text_b64" vs measured `payload()` at `internal/bus/dispatch.go:175-208`: the envelope carries `kind, lane, corr_id, scheduler_id, issued_at, board, workdir, reply_to, limits{text_b64…}` — the field is `board`, not `board_row`, and there is no `run_id` member. M9 CT-02 documents the real shape ("field **`board`** (not `board_row`)"), verified by this judge.
   Fix: correct the outline's CT-02 payload list or mark it superseded by M9 §6.

5. (non-blocking) kind UNVERIFIED — M2 §7 "bus worker ladder … 2026-11-05, cf-node only — PASS (FACT-04) — **not repeatable from this control host**". Rule 4 statement: this judge could not repeat it either (`~/node-bus-worker.py` absent here). The chapter discloses the limit honestly and carries it as a named RED; recorded so the next round knows the row's evidence remains single-host.

Spine: `python3 scripts/handbook_spine.py` run by this judge — `chapters=13 canonical contracts=18 findings=0`, rc 0. Zero spine findings; the two CONTRADICTION-class findings above are in cells the spine's regexes cannot see (a parenthetical stale count in a contract cell; outline-side structure text), which is consistent with M6 §3's own description of the gate's blind spots.

Everything else sampled reproduced exactly against the code, including: M0 all helper locators + the fail-closed probe (FETCH_RC=1, ARTIFACT=no) + 11/17 sourcing counts; M1 the B05 checkout/seed UNVERIFIED asymmetry (`:177` warn without `unverified()` vs `:225` with), port-validation leg, disk-floor precedence, the "five/six" re-apply comment; M2 constants `:81-85/:113-114`, `dispatch_wall` no-clamp, PID hardcode `:24-28`, crier max≤100 cap `handler.go:1718-1731`; M3 `GATE="" :38`, run_gate guard, explicit-object push `:278`, hook exit-0 path `:130-131`; M4 board census 357/519, `board_drift` RESULT: OK byte-parity HEAD==origin/main, validate OK(7); M5 `[0-7]00` predicate vs "must be 600" message, codex 300 re-default, project-node computed installer path `:440/:449-452`; M6 master_doc_check FAIL 44/37/50 exit 1, all three `[0-9][0-9]-*.md` globs; M7 0600 refusals, MIN_AGE 2400; M8 all four unit tests PASS + 15-claim scan live; M9 dispatchReplyVerdict reads only `payload["ok"]` `:709-726`, ~20 flag defaults all exact, 57 flags/43 routes/10 LoadRootConfig/379 log sites/30 tables/0 verdicts, build PASS; M10 handler locators 598/990/1690/1812, 3 slog sites, 1895 lines, 91 test files, 67 metric strings, full guard defaults block; M11 every env default `:38-:68`, `task_seconds` formula, EXEC_TIMEOUT inert (1 match), F11-8 process-group structure code-true; M12 sha256 exact, live 401 reproduced, systemd active with `10-upstream.conf`, unframed-stream code path `:206-224`.

DEFECT CLASSES: STALE-COUNT-IN-STATE-CELL · STAMP-DRIFT-UNDISCLOSED · FIXED-DEFECT-STILL-CARRIED-AS-RED · OUTLINE-SUPERSESSION-NOT-ANNOTATED · SINGLE-HOST-EVIDENCE (disclosed)

CHAPTER SCORECARD:
- M0 — WRITTEN: every claim re-verified this round incl. the fail-closed probe; one honest RED (metrics-none, absence-proved).
- M1 — PARTIAL: four large-file bodies read at settings-surface only (node_env 589, node_seed_drift 558, node_freshness 732, bunker_config_gen 724); certification ladder never run on a live node; log inventory 5/141 sites. Named, not hidden.
- M2 — WRITTEN: contracts section fully verified both-sides with canonical ids; residuals (live ladder single-host, S1 trio structure-mapped, 4/70 log sites) are named REDs, and the S2 re-grade (lane_target has a caller) is code-true.
- M3 — PARTIAL: `repo_freshness.py` body unread; S3 hook *enforcement* unproven (no rejecting-commit fixture resolves `core.hooksPath`); landing arm itself verified green this round.
- M4 — PARTIAL: store, drift, validation all reproduced by this judge; blocked only by the stale 518 in the CT-14 cell (finding 1) — a one-token fix.
- M5 — PARTIAL: claude/codex full bodies not line-by-line; conformance battery (the FACT-08 certification) not run this round; M5-C2 honestly downgraded from "works" to UNVERIFIED.
- M6 — PARTIAL: its own gate reads MASTER-DOC: FAIL (44/37/50) and the fill/render pipeline is UNBUILDABLE against M*.md chapters (F6-1, open, correctly owned); the chapter documents its own pipeline's defects truthfully but they are not yet closed.
- M7 — PARTIAL: mint never executed (no App creds on this host) — the module's core operation remains UNVERIFIED by design of the environment; settings register now complete.
- M8 — WRITTEN: both files read in full; every verification command re-run by this judge (9 reclaim tests, 15-claim scope scan, compiles); one honest RED.
- M9 — PARTIAL (deep): S1 internals grep-level, S4 per-route contracts unwritten, S3 write authorities unwritten, 2/379 log sites — but every sampled claim (≈40 locators, 7 measured counts, build, 30-table store) reproduced exactly, and the CF-355 finding is code-true at `:713-726`.
- M10 — PARTIAL: blocked by the stale FLAKY row/stamp (finding 2); 1895-line handler body not line-by-line (its slog surface is complete at 3/3); per-metric contract unfilled; guard log surface untallied.
- M11 — WRITTEN: read in full, every locator verified, decoration rows removed rather than counted as PASS, honest decoration-test and metrics REDs.
- M12 — WRITTEN: read in full, sha256/live-401/systemd reproduced by this judge, streaming honestly graded FAILING with a reproduced oracle (unframed `:206-224` verified code-true).

PANEL REVIEW COMPLETE

session_id: local-1357a12d4ae878f02717aecd4359381d9af5c69aeaf209b0fe1feba5a799e13c

EXIT=0
```

### grok

```
⚠️  Primary auth failed — switching to fallback: fireworks / accounts/fireworks/models/deepseek-v4p1-flash-1017
VERDICT: FAIL
BLOCKING: 8
NON-BLOCKING: 4

WHAT I RAN (rule 4, stated up front)
```
python3 scripts/handbook_spine.py                -> chapters=13 canonical contracts=18 findings=0 exit 0
grep -rl '\. "$HERE/lib.sh"' scripts/            -> 11      full-regex variant -> 17
wc -l scripts/lib.sh                             -> 78 (helpers at :5-9 :13 :19 :45 :48 :60 :67 :75)
python3 tests/test_disk_floor.py                 -> Ran 12, OK
python3 tests/test_harness_resolve.py            -> Ran 28, OK
python3 tests/test_reclaim.py                    -> Ran 9, OK
python3 tests/test_lane_target.py                -> rc 0
python3 scripts/check_scan_scope.py              -> OK, 15 claims, rc 0
bash scripts/verify-patch.sh                     -> VERIFY-PATCH: PASS (5 stages, 4 patches, 57432007…)
scripts/boardctl validate                        -> RESULT: OK (7 warning(s))
wc -l .coding-hermes/board/events.jsonl          -> 519          jq ids -> 357
grep -cE 'flag\.(String|Int|...)' cmd/schedulerd/main.go -> 57    routes -> 43
grep -rn log.Printf internal/scheduler/*.go|wc -l -> 379          sqlite3 .tables -> 30
crier handler.go -> 1895 lines, 3 slog sites (:1332 :1795 :1885)  registry tests -> 91
crier_ metric strings -> 67        go build ./... -> rc 0 (scheduler AND crier)
sha256sum cf-inference-proxy.py -> b12a0ac5…e0b5 (matches M12), 273 lines
```
I did NOT repeat: the live-node legs (M1 certification ladder, M2/M10 `node-bus-worker.py --check`, M5 conformance battery), M7's mint (no App creds), M12's disallowed-model 403 (did not read the node token file), and the Go test suites (builds only — so M9's "25/25 green" and M10's flakiness claim are unconfirmed by me in either direction).

The spine reports zero findings. That is not evidence of consistency; it is evidence about the gate. `has_fq()` (handbook_spine.py:121-123) only proves a `file:line` *pattern* exists — it never opens the file. Submodule counts are never compared (`"submodule": None`, :308). OUTLINE Part IV is never read. Every finding below sits in exactly those blind spots.

FINDINGS

1. kind UNBUILDABLE — chapters: all 13 — claim: OUTLINE.md:253 `VII.3 Acceptance gate per chapter — what makes a chapter WRITTEN rather than merely present`, and it is the whole content of Part VII (one line, no criterion).
   evidence: MASTER-DOC-SCHEMA.md:7-8 `A module section that cannot fill a required field is not "incomplete" — it is RED, and the empty field is the finding`; schema §5 `If the module emits none, write "none" — and that is a RED field`. Measured from the chapters' own footers: 40 RED fields across 13 chapters (M0 1, M1 4, M2 3, M3 3, M4 2, M5 4, M6 2, M7 4, M8 1, M9 5, M10 5, M11 2, M12 4), and Metrics is `RED — none` in 11 of 13 chapters (only M9 and M10 emit metrics). So under the document's own field contract no chapter can be WRITTEN — not this round, not any round — and there is no written gate to say otherwise.
   fix: write VII.3 with a decision rule that distinguishes "absence proved" from "not measured", and state whether metrics absence is a terminal accepted state; until then "WRITTEN" is a word without a referent and every round ends PARTIAL by construction.

2. kind OMISSION — chapters: all 13 (§12 of each) — claim: M1 §12 `F2 PROVISIONING AND CERTIFICATION is the primary flow this module owns.`; M3 §12 `F5 LANDING is the primary flow M3 owns.`; M9 §12 `F11 SCHEDULING ADMISSION is the primary flow`; M11 §12 `F1 DISPATCH AND SETTLEMENT is the flow this module executes on the control box.`
   evidence: no flow artifact exists anywhere — `docs/handbook/` contains chapters/ (13 files), OUTLINE.md, README.md, PANEL-LOOP.md and nothing else; README Part II marks all 16 rows `**MISSING**`, and README:47 admits `Parts I (beyond the rendered sheets), II.6–II.10, IV (as a re-derived register), V, VI, VII and VIII have no chapters`. The spine passes every F-reference because REF only range-checks F1–F16 (handbook_spine.py:87, :295-300). A reader who turns to the page each chapter names finds nothing; a chapter cannot be called written while its own cross-reference is a promise.
   fix: either write the owning flow for each chapter (F1, F2, F5, F11 first — they are called "primary" and "owned"), or change §12 to cite a written artifact.

3. kind UNBUILDABLE — chapter: M6 — claim: `So no chapter-aware path exists from source selection to delivered artifact` (M6 §1 status), and CT-18 state `**UNVERIFIED** — the renderer hardcodes docs/master and selects [0-9][0-9]-*.md, so it does not render these M*.md chapters`.
   evidence (measured by this seat): master_doc_check.py:188 `sorted(root.glob("[0-9][0-9]-*.md"))`, master_doc_fill.py:422 same glob, gen_nasa_handbook.py:253-259 same glob + `no modules found` refusal; `python3 scripts/master_doc_check.py` returns `44 module(s): 37 VERIFIED, 50 error(s)` / `MASTER-DOC: FAIL` — 44 appendix unit files, zero of the 13 chapters. Consequence: the delivered handbook is un-gated and un-rendered by its own pipeline, so the only gate that reads it is the one in finding 1's blind spot.
   fix: add the chapter-aware selection to check/fill/render (the glob is three lines) and re-stamp CT-18 with a producer that actually emits these files.

4. kind CONTRADICTION — chapter: M4 — claim: `the store is measured (357/518) but the foreman→board write wire is not exercised in this repo` (M4 §6, CT-14 row).
   evidence: `wc -l .coding-hermes/board/events.jsonl` = 519, measured this seat; M4's own §1 (`357 rows / **519** events`), §7 (519) and §13 (519) all say 519.
   fix: 518 -> 519.

5. kind CONTRADICTION — chapter: M10 — claim: §7 row `| go test | go test ./... | green | 2026-11-06, rev 86c4c469 | **FLAKY** — see the note below; not a clean PASS |` versus §13 `Commands run: go build ./... (PASS); go test ./... (PASS)`.
   evidence: the two sentences are in the same chapter; the §7 row and its own flakiness note (`go test ./... does not reliably reproduce green at HEAD`, two named failures reproduced by two different seats) say the run is not a pass, and §13 records it as PASS. A verification record that disagrees with itself cannot be cited as evidence by anyone.
   fix: delete `(PASS)` in §13; record `go test ./... — FLAKY at 86c4c469, failing test varies; see §7`.

6. kind CONTRADICTION — chapters: M3, M5, README — claim: M3 §3 `| S1 clone a lane row | clone_lane.py | ...` and `| S1 track freshness | repo_freshness.py | ...`; M5 §3 F5-4 `OUTLINE v2 lists M5 as 5 submodules (S1–S5); docs/UNIT-MAP.yaml lists 3 (S1–S3). The two structure maps still disagree`.
   evidence: M3's table has two distinct units under one id, so `M3.S1` is ambiguous; row count 49 vs distinct ids 48, which is the only way README I.4's `13 modules, 48 submodules` and OUTLINE's `48 submodules` hold. The spine cannot see it (submodule count is `None`, handbook_spine.py:308), and the M5 map disagreement is still open. A structure count with two source maps and a duplicate id has no authority.
   fix: give the two units unique ids (S1/S1b) and resolve UNIT-MAP vs OUTLINE to one map, then re-count.

7. kind CONTRADICTION — chapters: M2/M4/M6/M9/M10/M11 vs M0/M1/M3/M5/M7/M8/M12 — claim (six chapters, verbatim): `Local ids are retired; each row carries the CT id its peer chapter cites, so two ends can be matched.`
   evidence: ten local ids are live — M0-C1, M1-C1, M1-C2, M3-C1, M3-C2, M5-C2, M7-C1, M8-C1, M12-C1, M12-C2. Worse, M7 and M8 cite no canonical CT id at all (their whole §6 is M7-C1 / M8-C1), so two real interfaces — GitHub App installation-token mint, and the filesystem reap boundary — sit outside OUTLINE Part IV's 18. Part IV's "18 interfaces" is therefore not the complete register, and the one mechanism built to match two ends (the CT id) does not apply to the chapters that most need it.
   fix: either register the two interfaces canonically and say which local ids remain as sub-edges of a CT, or delete the "retired" sentence and state the two-register convention once, in Part IV.

8. kind CONTRADICTION — document register: OUTLINE Part IV vs seven chapter §6 rows — claim: OUTLINE.md:209-214 re-derives only the both-sides count (`Current (round 11, re-derived from the chapters): 5 of 18 internal contracts name both file:function`), while the per-contract state column below it still reads:
   evidence (outline -> chapter): CT-01 `works` -> M9 `UNVERIFIED (boundary)`; CT-07 `works` -> M12 `UNVERIFIED (boundary)`; CT-11 `works` -> M2 `UNVERIFIED (boundary)`; CT-13 `broken` -> M4 `UNVERIFIED`; CT-14 `works` -> M4 `UNVERIFIED`; CT-17 `broken` -> M5 `UNVERIFIED`; CT-18 `works` -> M6 `UNVERIFIED`. Only CT-02/03/04 carry `(superseded — see …)` notes. Seven of eighteen rows of the register a reader will actually use are contradicted by the chapter that measures them. The spine passes because it never reads OUTLINE Part IV.
   fix: re-derive the state column from the chapters this round, or annotate every superseded row with the chapter that supersedes it; an outline that says "works" over a chapter that says "UNVERIFIED" is the exact rumour-with-a-verdict the chapters were written to kill.

NON-BLOCKING

9. kind PADDING — chapters: 12 of 13 (70 passages match `Round-[0-9]|round-[0-9]`) — example claims: M6 §5 `Round-4's "0 serialises" was false (sol B14)`; M2 §11 `Round-4's "crash-before-persistence" discussion missed this same-batch case.`; M3 §7 `Round-6 said "none is shipped" — false.`
   evidence: these sentences are about the panel's history, not about the machine; OUTLINE already allocates the home for them (Appendix D, `Change log and supersession record`). They are readable, they are not actionable, and they grow every round — M9 carries ten, M12 eight.
   fix: keep one clause where the correction changes what an operator does (M0's `have()` empty-success, M11's withdrawn kill guarantee), move the rest to Appendix D.

10. kind OMISSION — chapter: M0 — claim: `**Exported helper inventory (B09, completed this round — every helper in lib.sh)**`, with `fetch_verified()` described as `url/dest/digest -> 0 on digest-verified install, 1 on any failure`.
    evidence: lib.sh:40 `chmod +x "$dest" 2>/dev/null || true` — every verified download is made executable and a failed chmod is swallowed; the function's own comment at :18 calls the exit code "the INSTALL, not the best-effort chmod". An operator reading the inventory will not know the primitive silently chmods the artifact.
    fix: add one row/one clause: successful install chmods +x, failure ignored.

11. kind locator drift — chapter: M1 — claim: `:44-53 port validation (NEW leg, CF-270) ... a digit test (:44-46), a 5-digit length cap (:47), then two ... refusals (:48-49 and :51-54)`.
    evidence (measured): digit test is :40-43, the length cap is :46, the refusals are :47-50 and :52-55 (printf :48 and :53, `exit 2` :49 and :54). The strings and the two refusals are exactly as described; the block bounds are off by ~4 lines, in a chapter that states `all re-pinned this round`.
    fix: correct the five ranges; substance needs no change.

12. kind UNVERIFIED (record) — chapter: M3 — claim: `| freshness gate | tests/selftest.sh arm cf244-node-freshness | freshness sub-cases PASS | 2026-11-06 | arm present (:3433-3670); not re-run this round (see note) |`.
    evidence: the Result column carries neither PASS nor UNVERIFIED, so the row cannot be counted or contradicted — in a table whose contract (schema §4) is `Expected/Result` with a stamp. The honest word is UNVERIFIED.
    fix: `UNVERIFIED — arm present, not run this round`.

DEFECT CLASSES
```
gate-cannot-see-the-artifact      (spine blind to locators/submodules/Part IV; doc gate blind to M*.md)
unreachable-definition-of-done    (RED-field rule vs "WRITTEN"; VII.3 unwritten)
declared-but-absent artifact      (16 flows, Parts I/V-VIII referenced by chapters)
stale-annotation contradiction    (OUTLINE Part IV state column, 7 of 18 rows)
count drift after re-measurement  (518 vs 519)
verification-record self-contradiction (M10 FLAKY vs PASS)
duplicate register id / two-authority structure map (M3 S1 x2, UNIT-MAP vs OUTLINE)
register convention fork          (10 live local ids in 7 chapters that say ids are retired)
panel-changelog padding           (70 round-N passages)
bounded locator drift             (M1 port-leg ranges)
```

CHAPTER SCORECARD — 0 WRITTEN, 13 PARTIAL, 0 SKELETON
```
M0  PARTIAL  Body and every cited line verified by me (78 lines, helpers :5-:75, 11/17 sourcing greps).
             Not WRITTEN: 1 RED field (metrics); helper table omits lib.sh:40 chmod.
M1  PARTIAL  Locators exact where I checked (bunker-provision :214/:233/:601/:604-609, disk_floor :36/:123,
             verify-node 241 lines, TTL :355-356); 4 RED fields (4 unread bodies, live ladder unrun).
M2  PARTIAL  Constants exact (:81-85, :113-114, :1479-1489); CT-09 absence reproduced (0 matches); 3 RED.
M3  PARTIAL  Sizes exact (308/180/130/4852); F3-5 (no in-repo lander caller) and duplicate-S1 defect.
M4  PARTIAL  All quoted output reproduced (357 rows, 519 events, validate OK 7 warnings); 518/519 contradiction.
M5  PARTIAL  Every pin locator exact (install-hermes :23/:24/:26, codex :47/:49/:51/:56-60, claude :36/:39/:40/:43,
             harness-vars :28/:31/:203-204/:276-281); 4 RED (conformance unrun, UNIT-MAP fork).
M6  PARTIAL  verify-patch output reproduced verbatim (5 stages, 4 patches, 57432007…); chapters invisible to its
             own gate and renderer; CT-18 unproduced.
M7  PARTIAL  CLI/exit-2 reproduced; mint never run; only a local contract id (finding 7); 4 RED.
M8  PARTIAL  Both files read in full by me too; 9 tests and 15-claim scan reproduced; 1 RED (metrics).
M9  PARTIAL  Strongest evidence in the set: 57 flags, 43 routes (enumeration exact), 30 tables, 379 sites,
             migration locators, build rc 0; 5 RED (2/379 logs, three packages grep-level, S3/S4 contracts unrun).
M10 PARTIAL  1895 lines, 3 slog sites, 91 test files, 67 metrics, config defaults :622-673 all exact; build rc 0;
             5 RED plus the FLAKY/PASS contradiction.
M11 PARTIAL  538 lines, 23 log sites, inert DISPATCH_EXEC_TIMEOUT reproduced (:47 only); kill guarantee withdrawn
             (F11-8) and tests cannot fail (F11-2).
M12 PARTIAL/F text hash, 273 lines, sink paths :50/:52 and the unframed SSE path :206-224 all confirmed; streaming
             is FAILING with a demonstrated defect and no shipped oracle.
```

The chapters are, on the evidence I could reproduce, unusually accurate: every line number I sampled resolved, every quoted count matched, both Go builds pass, and the weaknesses the chapters admit are real weaknesses, not cover. That does not make this round a pass. The document still cannot be delivered (finding 3), cannot be graded complete under its own rules (finding 1), points at 16 flows that do not exist (finding 2), and its register — the one table a reader trusts to know what is connected — is wrong on seven of eighteen rows (finding 8). Fixing those is work; softening them would cost another loop.

PANEL REVIEW COMPLETE

session_id: local-febff1cabde19f0e1101e4a61758a4755d198b804ce844af6217f7d6581c3ee7

EXIT=0
```

### kimi

```
VERDICT: FAIL
BLOCKING: 12
NON-BLOCKING: 6

REPEATED BY THIS SEAT (rule 4): spine `python3 scripts/handbook_spine.py` → `chapters=13 canonical contracts=18 findings=0` (rc 0), and its source read at `:178-336` — it checks canonical-id citation, function-token and state agreement for the five internal contracts, setting conflicts, dangling M/F refs and module/flow/contract/chapter counts. It does not read the OUTLINE, does not reject an unknown CT id, and sets `submodule: None` (`:308`). Independently re-run: scheduler `go build ./...` PASS and `env -u SCHEDULER_OPERATOR_RESTART_APPROVED go test ./...` 25/25 ok (internal/scheduler 227.5s) plus the three env-sensitive tests; crier `go build` was not re-run but every cited handler/config/guard line was read at the stamped rev; `boardctl validate` `RESULT: OK (7 warning(s))`, `board_drift` `RESULT: OK` 357/357, 0 divergent ids, HEAD=origin/main=`08a2c8a`; `test_disk_floor` 12, `test_lane_target` 40, `test_harness_resolve` 28, `test_reclaim` 9; `check_scan_scope` RESULT OK (15 claims); `verify-patch.sh` PASS; proxy `sha256sum` `b12a0ac5…` and live 401 on `:8775`; systemd MainPID 2603939; `master_doc_check.py` prints `44 module(s): 37 VERIFIED, 50 error(s)` / `MASTER-DOC: FAIL`. Not repeated: the live-node legs (M1 ladder, M2 bus-worker `--check`, M5 conformance battery, M7 mint), the M3 shipped landing arm, and crier `go test ./...`.

FINDINGS — BLOCKING (12)

B1 CONTRADICTION — M4 §6 (CT-14 row). Claim: "the store is measured (357/518)". Evidence: `wc -l .coding-hermes/board/events.jsonl` = 519; the same chapter says 519 in §1, §7 ("PASS (519)") and §13; `boardctl validate` prints "357 tasks, 519 events, 0 fixtures". The 518 is residue of the pre-reconciliation snapshot the chapter declares superseded. Fix: 518 → 519.

B2 OMISSION — M9 §3 (S2 row). Claim: "S2 execution and settlement | `spawn`, `slot_pool`, `lifecycle`, `dispatch_leg` | **active** | `dispatch_leg.go:260` `awaitDispatchReply`; `:262-336` constructs completed/failed/timeout outcomes". Evidence: `OUTLINE.md:186-187` defines S2 as "local vs remote, queue→running→terminal, deadlines, circuit behaviour, accounting, recovery"; the row names one of its four files and has no field for circuit behaviour, cost/usage accounting, or the recovery path (`execution_runs.recovery_idx` appears only as a table key at §3). Fix: add the submodule's mechanics with locators, or scope each omitted aspect out with measured evidence.

B3 OMISSION — M9 §9. Claim: "The two rows below are the settlement/batch-dispatch lines; the remaining 377 sites are uncovered and are the named RED on this field". Evidence: `grep -rn "log.Printf" internal/scheduler/*.go | wc -l` = 379 (reproduced); MASTER-DOC-SCHEMA §6 requires every operator-visible line. Fix: complete the inventory (or move it to a referenced appendix and cite it here); a 2/379 field cannot pass.

B4 OMISSION — M10 §8. Claim: "the series names are inventoried, but the full per-metric `type/labels/question/scrape` table is a named RED on this field (B21), not a completed register". Evidence: schema §5 makes that table the field; the 67-string census (`grep -rhoE 'crier_[a-z_]+' … | sort -u | wc -l` = 67, reproduced) is an inventory, not the contract. Fix: fill the table for the runtime series already named (guard, inbox/delivery, capability, webhook/store/detect/HTTP).

B5 OMISSION — M10 §9. Claim: "the three handler sites are [complete], the guard's are not yet tabulated (a named RED on this field)". Evidence: the same section quotes `internal/guard/guard.go:430-457` emitting `guard` and `guard blocked` with request_id/provider/model/decision/risk — operator-critical lines the field omits. Fix: tabulate them; the handler census being 3/3 is not the module's surface.

B6 OMISSION — M10 §5. Claim: "how an operator proves *which* backend is actually serving custody (readback of the resolved backend at boot) is not yet written (a named RED on §5)". Evidence: `config/config.go:113-123` resolves `CR_REGISTRY_BACKEND` → `sqlite:` URL → any URL → `memory`, and the chapter itself cites `config.go:550-551` that memory custody is lost on restart. Without the readback an operator cannot tell durable from demo custody. Fix: write the boot readback command, its expected output and the failure indication.

B7 UNVERIFIED — M10 §7. Claim: "`go test ./...` does **not** reliably reproduce green at HEAD `86c4c469` … The documented command is therefore flaky, and the row is not a clean PASS." Evidence: the chapter's own runs — `TestSessionFanoutWebhookBodyVerdict` (78.5s/34.3s) and `TestMetricsState_SeriesRenderOnIdleBoot` (58.0s/47.4s) failing on different runs. Note: commit `eb21ca03` (after this stamp) makes the idle-boot assertion order-insensitive, so the row is already stale. Fix: re-measure at current HEAD and either record a repeatable green command or keep UNVERIFIED with the flake isolated to a named test and a filed row.

B8 UNVERIFIED — M1 §1/§7. Claim: "**UNVERIFIED (bodies)** … `node_env.py` (589), `node_seed_drift.py` (558), `node_freshness.py` (732), `bunker_config_gen.py` (724) read at their **settings surface** … bodies not line-by-line; … the certification ladder not run this round". Evidence: reproduced the runnable rows (`bash -n`, `py_compile`, `test_disk_floor` 12 tests PASS); the four bodies and the live ladder remain unproven, so §5's consequences for those units are argued from argparse, not from control flow. Fix: read the bodies, or mark each affected settings row "surface-only" and state which consequence is therefore unproven.

B9 UNVERIFIED — M3 §1/§11. Claim: "`repo_freshness.py` body not read line-by-line … S3 hook *enforcement* is UNVERIFIED". Evidence: the chapter's own missing evidence — "`install-gitreins.sh:59-63` checks only that `.git/hooks/pre-commit` is executable and contains the string `gitreins` … It does not resolve the effective `core.hooksPath`, and a generated hook file does not prove git invokes it." The hook also exits 0 when `.gitreins/config.yaml` is absent (`:130-131`, verified). Fix: read the freshness body; ship the disposable rejecting-commit fixture and quote its rc.

B10 UNBUILDABLE — M6 §1/§11 (delivery path). Claim: "**The fill/render/panel pipeline is UNBUILDABLE against these M-numbered chapters**". Evidence, measured: `master_doc_check.py:188`, `master_doc_fill.py:422` and `gen_nasa_handbook.py:253` all select `[0-9][0-9]-*.md`; no `M*.md` chapter can be selected, and the gate returns `44 module(s): 37 VERIFIED, 50 error(s)` / `MASTER-DOC: FAIL` (reproduced). CT-18 therefore cannot leave UNVERIFIED. Fix: a chapter-aware selection path (glob or a separate root), then a gate run that reports the 13 chapters by name; until then the handbook has no route to the owner through the pipeline it documents.

B11 CONTRADICTION — OUTLINE Part IV vs the chapters. Claim: "Current (round 11, re-derived from the chapters): **5 of 18** internal contracts name both `file:function` …" followed by rows still carrying old states. Evidence: nine rows disagree with the chapter that owns them — CT-01 "works" vs M9 UNVERIFIED; CT-07 "works" vs M12 UNVERIFIED; CT-11 "works" vs M2 UNVERIFIED; CT-12 "works" vs M3 UNVERIFIED; CT-13 "broken" vs M4 UNVERIFIED; CT-14 "works" vs M4 UNVERIFIED; CT-15 "works" vs M9 UNVERIFIED; CT-17 "broken" vs M5 UNVERIFIED; CT-18 "works" vs M6 UNVERIFIED (and README I.1–I.3 re-graded MISSING). Only CT-02/03/04/06 carry "superseded" notes. The spine cannot catch this — it never reads OUTLINE. Fix: annotate each re-graded row or delete the state words from Part IV and point at §6.

B12 UNVERIFIED — M2 §7, M5 §7, M7 §7 (grouped: green-shaped rows with no runnable command here). Claims: "PASS (FACT-04) — **not repeatable from this control host**"; "conformance legs … not run this round | **UNVERIFIED** (needs a live node)"; "token mint … not run this round | **UNVERIFIED** (no App creds on this host)". Evidence: schema §4 — "A check that cannot be run by someone who did not write the module is not a check"; a carried PASS is not a measured PASS. Fix: run each on a node/with credentials, or move the carried PASS to a provenance note and put UNVERIFIED in the Result cell.

FINDINGS — NON-BLOCKING (6)

N1 COUNT — M9 §5: "The remaining 32 of the 57" but the auxiliary table carries 33 flag names (25 rows; `tls-key`, `duckbrain-url`, `duckbrain-interval`, `sim-idle`, `sim-count`, `gateway-key`, `sim-ticks`, `templates-file` are second names in shared cells). 24 + 33 = 57, verified — every one of the 57 names exists in `cmd/schedulerd/main.go`; only the split is off by one. Fix the word.

N2 PADDING — all chapters: round archaeology ("Round-4's … was false", "round-6 conflated …", "Round-8 called … that is wrong") is interleaved through §2/§10/§11/§13, addressed to the panel rather than the operator. The writer's manifest admits grok N4 is the one correction not applied. Fix: move it to Appendix D / §13 evidence and leave the operator prose declarative.

N3 STALE STAMP — M10 §1: "crier repo HEAD at round-11 derivation `86c4c469`…" while HEAD is now `dc15b2d6` (two commits later: `eb21ca03` test fix, `dc15b2d6` board). Cited files are byte-identical across the range (`git diff --name-only` on every cited path is empty), so content is sound; unlike M9, there is no post-stamp note. Fix: add the M9-style sentence.

N4 STRUCTURE — M3 §3: two rows are both labelled "S1" (`clone_lane.py`, `repo_freshness.py`) against OUTLINE M3's single S1, and `handbook_spine.py:308` sets `"submodule": None`, so no submodule count is ever checked. Fix: label them S1a/S1b or fold them into one row; note the spine blind spot where the count is claimed.

N5 EVIDENCE ORIGIN — M12 §7: the disallowed-model row's Result reads "reproduced by round-3 judge kimi … **not re-run by this writer** — the node token file was not read". A past seat's reproduction is not this round's evidence. Fix: Result = UNVERIFIED, with the round-3 reproduction moved to provenance.

N6 DANGLING XREF — M8 §12: "M3 REPOSITORY cites job/clone dirs as landing evidence, which M8's reaper must not delete". M3 contains no job-dir or clone-dir evidence citation (`clone_lane.py` clones a *lane row*, which M3 itself states at F3-2). Fix: re-point at the module that actually cites job dirs (M11 `.cf-jobs`, M1 node jobs) or drop the sentence.

DEFECT CLASSES: self-declared RED left open (log inventories, per-metric contract, per-route contract, custody readback); carried verification presented in a pass-shaped cell; stale count surviving a reconciliation; register not re-stamped after a state re-grade; delivery pipeline cannot select the delivered chapters; panel archaeology in operator prose; submodule scope thinner than the outline's own definition; spine blind spots (positional locators, submodule counts, OUTLINE never read).

CHAPTER SCORECARD (0 WRITTEN, 13 PARTIAL, 0 SKELETON)
M0 PARTIAL — every helper, setting and contract evidenced; §7 commands re-run and reproduced (11/17 sourcing, fetch_verified fails closed). Held back only by the RED §8 (no metrics); no writing gap found.
M1 PARTIAL — blocking B8: four bodies settings-surface-only and the certification ladder never run live; all runnable §7 rows reproduced (12/12 disk-floor tests).
M2 PARTIAL — blocking B12: the live inbox ladder is a carried PASS, "not repeatable from this control host". Content audited exact (reply fields, dry-run lease custody, 70 helper sites, `text_b64` first).
M3 PARTIAL — blocking B9: `repo_freshness.py` body unread and hook enforcement unproven by construction; landing arm not re-run by this seat.
M4 PARTIAL — blocking B1 (518 vs 519). Store, drift, validate and duplicate-id refusal all reproduced; the classification/limits prose is the strongest in the set.
M5 PARTIAL — blocking B12 (conformance battery unrun); adapter capability matrix and `install-go.sh` register are complete and the refusal lines verified at source.
M6 PARTIAL — blocking B10: the only pipeline that could deliver the document cannot select it, and the gate it documents reads FAIL; the chapter states both plainly.
M7 PARTIAL — blocking B12 (mint unrun, no App creds); settings/lifecycle register is complete and the mode-0600 refusal verified.
M8 PARTIAL — both files read in full, three §7 rows reproduced; held back only by the RED §8 and the N6 cross-reference.
M9 PARTIAL — blocking B2, B3: S2's outline scope is not written and 377 of 379 log sites are uncovered; admission sequence, flag surface, 30-table store and 43 routes all verified, and the full suite reproduces green.
M10 PARTIAL — blocking B4, B5, B6, B7: the metrics table, guard logs, custody readback and a stable test command are all missing; handler locators, guard/config defaults and the 3-site slog census are exact.
M11 PARTIAL — read in full, 23-of-23 log inventory, settings and failure modes exact, `CF_DURABLE_JOB` and `DISPATCH_EXEC_TIMEOUT` corrections verified; held back only by the RED §8 and the non-asserting job tests (a repository defect, named).
M12 PARTIAL — admission/routing/capture verified live (401, sha256, PID); streaming correctly graded FAILING (F12-7); N5 on the disallowed-model row.

PANEL REVIEW COMPLETE

session_id: local-9ca83af4d2667671bf8182a1d9f258ede26644e20b6bbf8f23923aed9121d096

EXIT=0
```

### sol

```
│ cache/scratch/quorum-round11-sol-yxGVQWlq/probes.py
│ @@ -0,0 +1,140 @@
│ +#!/usr/bin/env python3
│ +"""Read-only round-11 judge probes; all fixtures stay in this scratch dir."""
│ +import ast
│ +import contextlib
│ +import http.client
│ +import importlib.util
│ +import io
│ +import json
│ +import os
│ +from pathlib import Path
│ +import signal
│ +import subprocess
│ +import sys
│ +import threading
│ +import time
│ +from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
│ +
│ +ROOT = Path('/home/kara/code-factory')
│ +OUT = Path(__file__).resolve().parent
│ +
│ +def load(name, path):
│ +    spec = importlib.util.spec_from_file_location(name, path)
│ +    mod = importlib.util.module_from_spec(spec)
│ +    sys.modules[name] = mod
│ +    spec.loader.exec_module(mod)
│ +    return mod
│ +
│ +sp = load('round11_spine', ROOT / 'scripts/handbook_spine.py')
│ +original = sp.chapters()
│ +for label, change in (
│ +    ('baseline', lambda d: None),
│ +    ('unknown_CT99', lambda d: d.__setitem__('M0-shared-contract', d['M0-shared-contract'].replace('## 7. Verification', '| CT-99 | fabricated | out | `a.py:1` `send()` | `b.py:1` `read()` | works |\n\n## 7. Verification'))),
│ +    ('quoted_default_conflict', lambda d: (d.__setitem__('M0-shared-contract', d['M0-shared-contract'].replace('## 6. Contracts', '| `ROUND11_TEST_SETTING` | `alpha` | path | routing | wrong target |\n\n## 6. Contracts')), d.__setitem__('M1-provisioning', d['M1-provisioning'].replace('## 6. Contracts', '| `ROUND11_TEST_SETTING` | `beta` | path | routing | wrong target |\n\n## 6. Contracts')))),
│ +):
│ +    fixture = dict(original)
│ +    change(fixture)
│ +    sp.chapters = lambda: fixture
│ +    saved = sys.argv
│ +    sys.argv = ['handbook_spine.py', '--json']
│ +    stream = io.StringIO()
│ +    with contextlib.redirect_stdout(stream):
│ +        rc = sp.main()
│ +    sys.argv = saved
│ +    result = json.loads(stream.getvalue())
│ +    print('SPINE', label, 'rc=', rc, 'findings=', len(result['findings']))
│ +sp.chapters = lambda: original
│ +
│ +# Execute the real proxy handler against a finite loopback upstream. No live
│ +# credentials, provider calls, or production logs are used by this fixture.
│ +proxy = load('round11_proxy', '/home/kara/.hermes/scripts/cf-inference-proxy.py')
│ +class Upstream(BaseHTTPRequestHandler):
│ +    def do_POST(self):
│ +        self.rfile.read(int(self.headers.get('Content-Length', '0')))
│ +        data = b'data: [DONE]\n\n'
│ +        self.send_response(200)
│ +        self.send_header('Content-Type', 'text/event-stream')
│ +        self.send_header('Content-Length', str(len(data)))
│ +        self.end_headers()
│ +        self.wfile.write(data)
│ +    def log_message(self, *_):
│ +        pass
│ +
│ +up = ThreadingHTTPServer(('127.0.0.1', 0), Upstream)
│ +threading.Thread(target=up.serve_forever, daemon=True).start()
│ +proxy.UPSTREAM = 'http://127.0.0.1:%s' % up.server_port
│ +proxy.upstream_key = lambda: 'disposable-fixture-key'
│ +proxy.Handler._node = lambda self: 'fixture-node'
│ +proxy.USAGE_LOG = OUT / 'usage.jsonl'
│ +proxy.CAPTURE_LOG = OUT / 'capture.jsonl'
│ +relay = ThreadingHTTPServer(('127.0.0.1', 0), proxy.Handler)
│ +threading.Thread(target=relay.serve_forever, daemon=True).start()
│ +connection = http.client.HTTPConnection('127.0.0.1', relay.server_port, timeout=0.8)
│ +connection.request('POST', '/v1/chat/completions', json.dumps({'model': 'hermes', 'stream': True}), {'Content-Type': 'application/json'})
│ +response = connection.getresponse()
│ +print('PROXY_STREAM_STATUS=', response.status, 'framing=', {k: response.getheader(k) for k in ('Content-Length', 'Transfer-Encoding', 'Connection')})
│ +try:
│ +    body = response.read()
│ +    print('PROXY_STREAM_EOF_COMPLETED=True', repr(body))
│ … omitted 62 diff line(s) across 1 additional file(s)/section(s)
│ .hermes/cache/scratch/quorum-round11-sol-yxGVQWlq/probes.py
│ @@ -137,4 +137,37 @@
│  # order without running its production writer/panel subprocesses.
│  panel = (ROOT / 'scripts/panel_loop.py').read_text().splitlines()
│  print('PANEL_START_ASSIGNMENTS=', [(i, line.strip()) for i, line in enumerate(panel, 1) if re.search(r'\brnd\s*=', line)])
│ +# Exercise the real panel main with state/writer boundaries replaced; no
│ +# production state or subprocess can be reached.
│ +loop = load('round11_panel', ROOT / 'scripts/panel_loop.py')
│ +loop.PANEL = OUT / 'panel-fixture'
│ +loop.load_state = lambda: {'round': 10, 'status': 'idle', 'history': [], 'classes_seen': [], 'clean_streak': 0}
│ +loop.save_state = lambda st: None
│ +class FixtureStop(Exception):
│ +    pass
│ +def stop_writer(rnd, chapters, timeout):
│ +    print('PANEL_ACTUAL_FIRST_ROUND=', rnd, 'requested_start=99')
│ +    raise FixtureStop()
│ +loop.run_writer = stop_writer
│ +saved = sys.argv
│ +sys.argv = ['panel_loop.py', '--start-round', '99', '--rounds', '12', '--max-seconds', '0']
│ +try:
│ +    loop.main()
│ +except FixtureStop:
│ +    pass
│ +finally:
│ +    sys.argv = saved
│ +
│ +# The real seed budget compares raw source bytes, NOT tarball bytes.
│ +seed = load('round11_seed', ROOT / 'scripts/node_seed.py')
│ +seedroot = OUT / 'seed-fixture'
│ +seedroot.mkdir(exist_ok=True)
│ +(seedroot / 'one-byte.txt').write_bytes(b'x')
│ +manifest = seedroot / 'manifest.txt'
│ +manifest.write_text('one-byte.txt\n')
│ +archive = seedroot / 'out.tar.gz'
│ +args = SimpleNamespace(repo_root=str(seedroot), manifest=str(manifest), exclude_backups=False, budget=1, out=str(archive))
│ +with contextlib.redirect_stdout(io.StringIO()):
│ +    seedrc = seed.build(args)
│ +print('SEED_BUDGET_BYTES=1', 'source_bytes=1', 'archive_bytes=', archive.stat().st_size, 'rc=', seedrc)
│  print('PROBE_COMPLETE')
│ .hermes/cache/scratch/quorum-round11-sol-yxGVQWlq/probes.py
│ @@ -87,6 +87,8 @@
│
│  # Minimal process-geometry fixture reproducing dispatcher.py:233,260,291,329.
│  run = OUT / 'runner.sh'
│ +for path in (OUT / 'runner.pid', OUT / 'harness.pid'):
│ +    path.unlink(missing_ok=True)
│  run.write_text('echo $$ > "'+str(OUT / 'runner.pid')+'"\ntimeout 60 sh -c "sleep 60 & wait" &\necho $! > "'+str(OUT / 'harness.pid')+'"\nwait $!\n')
│  runner = subprocess.Popen(['sh', str(run)], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
│  hpid = None
│ cache/scratch/quorum-round11-sol-yxGVQWlq/census.py
│ @@ -0,0 +1,15 @@
│ +from pathlib import Path
│ +import re
│ +rows = {}
│ +red = {}
│ +for p in sorted(Path('/home/kara/code-factory/docs/handbook/chapters').glob('M*.md')):
│ +    text = p.read_text()
│ +    sec = re.search(r'^## 3\..*?\n(.*?)(?=^## 4\.)', text, re.S | re.M).group(1)
│ +    rows[p.stem] = sorted(set(re.findall(r'^\| S(\d+)\b', sec, re.M)), key=int)
│ +    red[p.stem] = int(re.search(r'RED field count: (\d+)', text).group(1))
│ +print('SUBMODULE_IDS', rows)
│ +print('SUBMODULE_TOTAL', sum(map(len, rows.values())))
│ +print('DECLARED_RED_COUNTS', red)
│ +print('DECLARED_RED_TOTAL', sum(red.values()))
│ +print('UNIT_TEST_TOTAL', sum([12, 40, 28, 9]))
│ +print('BLOCKING_IDS_B01_TO_B22', len(range(1, 23)))
│ .hermes/cache/scratch/quorum-round11-sol-yxGVQWlq/census.py
│ @@ -12,4 +12,4 @@
│  print('DECLARED_RED_COUNTS', red)
│  print('DECLARED_RED_TOTAL', sum(red.values()))
│  print('UNIT_TEST_TOTAL', sum([12, 40, 28, 9]))
│ -print('BLOCKING_IDS_B01_TO_B22', len(range(1, 23)))
│ +print('BLOCKING_IDS_B01_TO_B23', len(range(1, 24)))
VERDICT: FAIL
BLOCKING: 23 — findings that must be fixed before the affected chapters can be called written
NON-BLOCKING: 1

FINDINGS:

Review basis and verification

I read the outline, field schema, all 13 chapters, the spine checker, and the relevant implementation paths across the five systems. Findings below distinguish inaccurate documentation from accurately documented software defects. A software defect already described correctly is not counted again as a new FALSE CLAIM.

The documentation and spine checker are modified working-tree files, not merely the committed tree at code-factory revision 08a2c8a2ea3a44445da2f1013c545b568c7bf352.

The required command, run from /home/kara/code-factory, returned:

    python3 scripts/handbook_spine.py
    chapters=13  canonical contracts=18
    findings=0

There are therefore no automatic spine findings to promote into CONTRADICTION findings. That result does not establish semantic correctness; B13 demonstrates false-negative cases.

Independent execution also returned:

    tests/test_disk_floor.py: 12 tests, OK
    tests/test_lane_target.py: 40 tests, OK
    tests/test_harness_resolve.py: 28 tests, OK
    tests/test_reclaim.py: 9 tests, OK
    Total: 89 tests, all passed

    check_scan_scope.py:
      15 gitleaks claims name their --log-opts
      RESULT: OK

    verify-patch.sh:
      5 stages, 4 patches
      VERIFY-PATCH: PASS

    master_doc_check.py:
      44 module(s): 37 VERIFIED, 50 error(s), 0 warning(s)
      MASTER-DOC: FAIL

    boardctl validate:
      357 tasks, 519 events, 0 fixtures
      RESULT: OK (7 warning(s))

    board_drift.py check:
      byte parity identical for tasks.jsonl and events.jsonl
      357 versus 357 rows; 0 divergent ids
      RESULT: OK

    proxy no-token POST:
      HTTP 401

    proxy content hash:
      b12a0ac521c4b5a9cd7e2b76883a7edf2c9e0efd87d9bc3be3d2056d3f39e0b5

I did not repeat live provisioning, credentialed GitHub minting, the live-node conformance battery, or either complete Go test suite. Their historical results are not presented here as independently reproduced results.

Disposable probes are available at:

    /home/kara/.hermes/cache/scratch/quorum-round11-sol-yxGVQWlq/probes.py

They use scratch files and local fixtures, not production credentials or paid inference.

Blocking findings

B01 — OMISSION
Chapter ids: M0, M1, M2, M3, M4, M5, M6, M7, M8, M11, M12
Claim quoted: “RED — none (absence-proved this round)” in each chapter’s metrics section.
Evidence: These chapters explicitly declare no emitted metrics. MASTER-DOC-SCHEMA.md:72-79 makes “none” a RED required field. Examples independently inspected include scripts/lib.sh:5-11, scripts/reclaim_disk.py:119-125, dispatcher.py:112-120, and cf-inference-proxy.py:98-101.
Fix: Retain the honest RED status and grade these chapters PARTIAL. Close the required observability field with real, measured instrumentation and its type/labels/question/scrape contract. Do not manufacture metric names to fill the table.

B02 — OMISSION
Chapter ids: M9, M10
Claims quoted: M9:245, “Measured — real, not RED”; M10:182-185, “the full per-metric type/labels/question/scrape table is a named RED.”
Evidence: M9:245-253 describes endpoint blocks and selected semantics, but does not supply the required per-metric contract. M10 explicitly acknowledges the missing table. MASTER-DOC-SCHEMA.md:72-79 requires that contract, not merely endpoint existence or a grep census.
Fix: Enumerate the actual observations with type, labels or JSON dimensions, question answered, source, reset/persistence semantics, and scrape/read location. M9’s blanket “not RED” is premature.

B03 — OMISSION
Chapter ids: M1, M2, M3, M5, M6, M7, M9, M10
Claim quoted: “the uncovered count is a named RED on this field,” repeated in the partial log inventories.
Evidence: MASTER-DOC-SCHEMA.md:81-91 requires every operator-visible line. The chapters themselves acknowledge missing inventories. Additional concrete emitters include node-bus-worker.py:1223-1229, install-go.sh:61-67, panel_loop.py:299-355, and crier/cmd/server/harnesswiring.go:109,153. M6’s two gate rows do not document its panel loop’s operational output.
Fix: Complete the inventory by owned submodule, including condition, level, placeholders, and descriptive/evidentiary classification. A measured denominator makes incompleteness honest; it does not satisfy the field.

B04 — OMISSION
Chapter id: M1
Claim quoted: “config keys … PROJECT AGENT SERVER REPO REF HARNESS NAMESPACE NAMESPACES TTL …” at M1:103.
Evidence: This is an aggregate list, not a settings register with a default, range, reader and consequence for each input. Examples omitted or insufficiently registered include bunker_config_gen.py:105-115 defaults for agent prefix, database, output directory and credential directory; node_seed_drift.py:488-506 exposes additional mode and timeout controls.
Fix: Expand the aggregate row into individually evidenced settings. Complete the provisioning and drift-probe surfaces, including target paths, strictness switches, required inputs and precedence. The existing list is NAME ONLY for its unexpanded members.

B05 — FALSE CLAIM
Chapter id: M1
Claim quoted: “--budget … seed tarball size ceiling” at M1:112.
Evidence: scripts/node_seed.py:130-138 sums source-file sizes and compares that total with args.budget before creating the archive at :147-150. It does not compare compressed archive size. An execution of the actual build() with a one-byte source and a one-byte budget returned rc=0 while creating a 197-byte archive.
Fix: Describe the budget as the aggregate uncompressed source-file byte ceiling. Explain that compression, archive headers and filesystem overhead are not bounded by that check.

B06 — OMISSION
Chapter id: M2
Claim quoted: “Unregistered operational overrides: --home, --identity, --bus-identity, --key, --token-file, --agent, --project, --crier, --workdir, --harness-cmd, --gateway-port” at M2:79.
Evidence: These are real controls at node-bus-worker.py:1443-1476. They select identity, credentials, destination, execution directory and executable template. Listing their names without individual defaults, validation, readers and consequences fails the stated settings rule.
Fix: Register each override separately. Include the five-second lease selected by dry-run at node-bus-worker.py:1312, not just the general warning that dry-run leases messages.

B07 — UNVERIFIED
Chapter id: M3
Claim quoted: “S3 hook enforcement is UNVERIFIED” at M3:12.
Evidence: install-gitreins.sh:59-63 checks a specific executable hook file and its text; :124-135 generates a hook that may exit successfully without running the guard. Neither proves that Git’s effective hook configuration invokes it. The landing fixture is not a rejecting-commit fixture.
Fix: Provide a disposable repository test that resolves effective core.hooksPath, installs the intended gate, attempts a known-rejected commit, and proves HEAD did not advance. Record the complete command and revision. Keep S3 RED until that evidence exists.

B08 — FALSE CLAIM
Chapter id: M3
Claim quoted: CT-12’s producer is “external — the node’s commit hook stages the diff” at M3:96.
Evidence: The hook is generated by covered code at scripts/install-gitreins.sh:124-135. Its body changes directory and executes gitreins guard --quality-async. It does not stage a diff. The chapter also says, in the same cell, that the hook is in-repo.
Fix: Name the covered producer as the generated pre-commit hook, identify its generator and invocation, and describe it as invoking the guard against already-staged changes. Mark only the unavailable external implementation as external.

B09 — CONTRADICTION
Chapter id: M4
Claim quoted: CT-14 says “the store is measured (357/518)” at M4:92.
Evidence: M4:12,107,109,180 and 193 say 519 events. Independent boardctl validate returned “357 tasks, 519 events, 0 fixtures”; board drift returned byte parity. The old count remains in a current contract-state cell despite the chapter’s explicit supersession paragraph.
Fix: Replace 357/518 with the current measured value, or label the old count historical at that exact occurrence. One corrected paragraph does not supersede an unqualified contradictory table cell elsewhere.

B10 — OMISSION
Chapter id: M5
Claim quoted: “harness-vars.sh … is the register for the CF_* set it enforces” at M5:81.
Evidence: The expanded installer tables still do not cover the complete module settings surface. harness_resolve.py:327-370 exposes --lane-class, --directive-harness, --lane-harness, --node-harnesses, --shims and --matrix-file. These determine selection and refusals, but lack individual register entries. install-go.sh:138 also reads GO_DL_BASE, absent from the Go installer register.
Fix: Complete the resolver and installer settings registers. Give each override’s precedence, validation and consequence. Optional execution does not make its controls optional documentation.

B11 — UNBUILDABLE
Chapter id: M6
Claim quoted: “no chapter-aware path exists from source selection to delivered artifact” at M6:12.
Evidence: gen_nasa_handbook.py:253-260 selects NN-*.md and refuses an empty selection. master_doc_fill.py:422 uses the same incompatible selection convention. I ran the renderer with scratch output paths; it printed “no modules found” and returned rc=1. The structural checker separately returned 50 errors against the legacy unit set.
Fix: Supply one executable, chapter-aware delivery path from these M*.md files through validation to the owner’s artifact, with a reproduced command and expected output. Correctly documenting that the path is broken does not fulfill the delivery requirement.

B12 — FALSE CLAIM
Chapter id: M6
Claims quoted: “--start-round … resume at a specific round” and “--rounds … the iteration budget” at M6:112-114.
Evidence: panel_loop.py:295 assigns the requested start, but :305 overwrites it from stored state before running the writer. The loop condition at :304 compares the stored absolute round with --rounds; it does not count additional iterations. A fixture using stored round 10, --start-round 99 and --rounds 12 printed “start round 99” but invoked the writer for round 11.
Fix: Describe the current inert start override and absolute-round ceiling accurately, or repair the controls and verify them. Do not present intended resume semantics as implemented behavior.

B13 — OMISSION
Chapter id: M6
Claim quoted: “mechanical cross-chapter consistency” — the spine gate’s advertised role.
Evidence: handbook_spine.py:200-213 iterates only known canonical ids, leaving unexpected ids unchecked. norm_default() at :133 deletes every backticked span, including actual string values. In-memory tests of the real checker returned:
    baseline: rc=0, findings=0
    injected CT-99: rc=0, findings=0
    conflicting backticked alpha/beta defaults: rc=0, findings=0
M6:50 honestly describes these defects, but the required enforcement remains absent.
Fix: Reject unknown CT ids, preserve default values while stripping citation annotations, and add negative fixtures that require nonzero exits. Treat today’s spine PASS as a limited consistency result, not acceptance evidence.

B14 — UNVERIFIED
Chapter id: M7
Claim quoted: “token mint … python3 scripts/github-app-token.py token …” at M7:91.
Evidence: The verification command contains an ellipsis and supplies neither a complete invocation nor a reproducible fixture. github-app-token.py:598-606 is the actual mint-and-write path. The chapter explicitly says it was not run. I did not perform a credentialed mint either.
Fix: Provide a complete credential-safe invocation with explicit prerequisites and outputs, plus a local API fixture covering failure and private-file creation. Keep live minting UNVERIFIED until actually exercised; compilation and usage output do not prove credential lifecycle behavior.

B15 — OMISSION
Chapter id: M9
Claim quoted: “the remaining 32 of the 57” with “default + consequence” at M9:162.
Evidence: The auxiliary table at M9:164-190 has no range column. Some defaults remain symbolic names rather than usable values: PeerFreshnessWindowDefault is 180 seconds at internal/database/peers.go:28; DefaultHermesReapStaleAfter is 24 hours at internal/database/hermesstate.go:52. “int” or “Go duration” also does not explain validation, zero, negative or fallback behavior.
Fix: Supply resolved defaults, accepted domains, rejected/special values, actual readers and precedence. Consequences alone do not complete the default/range/consequence contract.

B16 — OMISSION
Chapter id: M9
Claims quoted: “Per-route request/response shapes and write-authority readbacks are not written” at M9:53-55; “write authorities and recovery queries per table are not yet written” at :107.
Evidence: internal/api/server.go:289-370 mounts the real operator routes. The chapter provides route names and selected database keys, but not the procedures needed to safely configure, inspect and recover the scheduler.
Fix: Document route methods, payloads, authorization, refusal behavior and exact readbacks for mutating controls. For execution stores, name the writer, state transitions, recovery query and operator procedure. A route census and key census are not operational contracts.

B17 — FALSE CLAIM
Chapter id: M9
Claim quoted: “empty gateway-url → exec.Command fallback” at M9:177.
Evidence: The binary also defaults no-exec-fallback to true at cmd/schedulerd/main.go:190. internal/scheduler/spawn.go:1717-1754 explicitly defers when the gateway client is nil and fallback is disabled. An empty gateway URL alone therefore does not authorize execution fallback.
Fix: State the interaction: a usable exec fallback requires fallback to be enabled; with the default prohibition, the nil-gateway path defers. Include both controls and the resulting indication in the same register entry.

B18 — OMISSION
Chapter id: M10
Claim quoted: The chapter’s submodule inventory covers “custody and transport,” “the guard,” “binaries, ports, services,” and “client libraries.”
Evidence: Covered production code also wires push ingress to harness execution: cmd/server/ingressroutes.go:148-154 installs harnessDispatch; harnesswiring.go:60-130 loads session bindings, dispatches and persists the first harness session id. internal/harness/config.go:91-105 defaults delivery off, while :244-269 exposes enablement, default harness, timeout and concurrency controls. registry.go:12-15 sets 900 seconds and four concurrent deliveries.
Fix: Add this behavior to an existing M10 submodule rather than inventing a package-level chapter. Document activation, bindings, receipt semantics, persistence, failures and settings. The outline includes mechanisms that can change run behavior, even when default-off.

B19 — UNVERIFIED
Chapter id: M11
Claim quoted: “live-job tests … failure oracle” at M11:101.
Evidence: tests/test_durable_job.py:8-11 prints the returned result without checking it. tests/test_job_kill.py:35 prints PASS or FAIL but does not make that verdict determine process exit. These scripts can fail through incidental exceptions, but lack a dependable semantic failure oracle for the properties claimed. I independently reproduced the process-group problem: the timeout group differed from the runner group and remained a live, non-zombie process after terminating the runner group.
Fix: Make assertions and exit status enforce the expected reply, deadline and descendant cleanup. Check process identity and non-zombie state, and distinguish the inner timeout path from the outer dispatcher deadline. Record the exact commands and results.

B20 — OMISSION
Chapter id: M12
Claim quoted: “a repeatable framing/completion oracle is the missing evidence” at M12:182-184.
Evidence: The verification table contains no executable streaming-completion test. I exercised the real Handler against a finite local SSE upstream and obtained:
    status=200
    Content-Length=None
    Transfer-Encoding=None
    Connection=None
    EOF completion=False: TimeoutError
This confirms the documented defect; it is not a new allegation that streaming might be broken.
Fix: Ship or fully print the finite-upstream fixture and its expected failing result, then use it as the regression oracle for the eventual repair. Admission 401 and a content hash do not verify the streaming contract.

B21 — OMISSION
Chapter id: M0
Claim quoted: The runtime dependency table lists “bash,” “curl,” and “sha256sum” at M0:65-69.
Evidence: lib.sh:21-40 also invokes mktemp, rm, cut, dirname, mkdir, mv and chmod. lib.sh:45-51 relies on df and awk for disk admission. These are operational dependencies with distinct failure consequences, not imported shell functions.
Fix: Register the required utility set and how missing or failing utilities affect each helper. In particular, document that the executable-bit operation is best-effort at lib.sh:40 and that disk measurement depends on df/awk.

B22 — OMISSION
Chapter id: M10
Claim quoted: “S4 client libraries | clients/python/crier_client.py, clients/typescript” at M10:35.
Evidence: The chapter’s substantive client contract is Python-only. The TypeScript client has its own constructor and environment behavior at clients/typescript/crier.ts:546-598: mandatory signing-key provision, token fallback from CR_AUTH_TOKEN, a 30000 ms timeout, and fromEnv resolution. Its signing implementation is at :603-625. None receives a corresponding implementation-level treatment in the chapter.
Fix: Document the TypeScript consumer surface, configuration/defaults, signing contract, errors and compatibility expectations. Naming its directory is not documentation of the versioned library.

B23 — UNVERIFIED
Chapter ids: M0, M1, M2, M3, M4, M5, M6, M7, M8, M9, M10, M12
Claim quoted: “The one-sided flag here is the correct completion” at M0:92; “the honest terminal state, not a chapter defect” at M6:137-138; equivalent boundary exemptions recur elsewhere.
Evidence: The round-11 brief requires producer AND consumer as file:function and says UNVERIFIED blocks. The spine explicitly exempts boundary contracts at handbook_spine.py:209-213. Chapters retain missing or unmeasured endpoints, including M1-C1 registration, CT-11 session storage, CT-13/CT-14 board writes, M5-C2 gateway startup and M12-C1/C2.
Fix: Do not turn an honest scope limitation into a completion waiver. Name every covered implementation endpoint, document the boundary payload and failure semantics, and provide a repeatable boundary observation. Where the far side cannot be established, retain UNVERIFIED and PARTIAL. Any relaxation of the both-sides acceptance rule requires an explicit change to the governing contract, not a local prose exemption.

Non-blocking finding

N01 — PADDING
Chapter ids: M0–M12
Claim quoted: Examples include “Round-5 wrote … neither exists” at M12:75-76 and repeated accounts of which previous round invented or corrected a statement.
Evidence: Current operational instructions are interleaved with extensive editorial repair history. The outline already provides an appendix for verdicts and a supersession record.
Fix: Keep current behavior, evidence and active limitations in the chapter. Move round-by-round correction narratives into the supersession appendix, retaining concise links. This does not block correctness, but it obscures the procedures readers need.

DEFECT CLASSES:

    REQUIRED_FIELD_RED
    METRIC_CONTRACT_INCOMPLETE
    LOG_INVENTORY_INCOMPLETE
    SETTINGS_NAME_ONLY
    BUDGET_DOMAIN_MISDESCRIBED
    HOOK_ENFORCEMENT_UNPROVEN
    PRODUCER_MISIDENTIFIED
    STALE_COUNT_CONTRADICTION
    DELIVERY_PATH_UNBUILDABLE
    PANEL_FLAG_SEMANTICS_FALSE
    SPINE_FALSE_NEGATIVE
    VERIFICATION_COMMAND_INCOMPLETE
    CONFIGURATION_INTERACTION_FALSE
    OPERATOR_AND_RECOVERY_CONTRACT_MISSING
    REACHABLE_EXECUTION_MECHANISM_OMITTED
    TEST_ORACLE_NON_ENFORCING
    STREAM_PROBE_NOT_DELIVERED
    RUNTIME_DEPENDENCY_INCOMPLETE
    CLIENT_LIBRARY_NAME_ONLY
    BOUNDARY_COMPLETION_WAIVER
    EDITORIAL_HISTORY_PADDING

CHAPTER SCORECARD:

M0 — PARTIAL
    The shared helpers and source counts are substantially described; I reproduced 11 direct and 17 total sourcing scripts. Required metrics remain RED, utility dependencies are incomplete, and the one-sided contract is not completed under this brief.

M1 — PARTIAL
    The certification ladder and seed state machine have useful source evidence. The budget’s measured domain is described incorrectly; configuration controls remain incompletely registered; logs, registration and live certification remain open.

M2 — PARTIAL
    The corrected text_b64 consumption and reply/ack ordering are grounded in code. Identity/execution overrides remain NAME ONLY, logging is incomplete, metrics are absent, and the live ladder was not repeated here.

M3 — PARTIAL
    Landing behavior, optional gates and remote-proof limitations are documented. Effective commit-hook enforcement is not demonstrated, CT-12 misdescribes its producer, and required logs and metrics remain incomplete.

M4 — PARTIAL
    Store validation and byte parity reproduced successfully. The CT-14 cell still contradicts the corrected event count; write-boundary contracts remain unverified and metrics remain RED.

M5 — PARTIAL
    Adapter differences and the resolver’s lack of runtime wiring are described. Resolver and installer controls remain incomplete, hook enforcement and live conformance remain unverified, and logs and metrics are unfinished.

M6 — PARTIAL
    The chapter correctly exposes major pipeline failures, but the delivery path is still unusable for these chapters. Resume/cap semantics are misstated, spine enforcement has demonstrated blind spots, and its own required fields remain open.

M7 — PARTIAL
    Credential domains and refresh behavior are substantially mapped. The mint command is not a complete reproducible verification procedure; the external exchange, log inventory and metrics remain incomplete.

M8 — PARTIAL
    The target sets, TTL boundary and dry-run semantics agree with the implementation; all nine reclaim tests passed. The mandatory metrics field is explicitly RED, preventing WRITTEN under the supplied schema.

M9 — PARTIAL
    Admission and selected settlement/store behavior are documented. Settings are not fully admissible, the empty-gateway consequence is wrong under default fallback policy, operator/recovery contracts are unfinished, and observability inventories remain incomplete.

M10 — PARTIAL
    Inbox lease semantics and guard degradation are grounded in source. Harness dispatch is a reachable omitted mechanism; TypeScript is only named; metric/log contracts and storage readback remain unfinished. I did not independently rerun its full suite.

M11 — PARTIAL
    Job execution, ledger gaps and serial head-of-line blocking are described accurately. The process-group defect reproduced, but the shipped verification scripts do not enforce the required behavioral outcomes. Metrics remain RED.

M12 — PARTIAL
    Hash, live no-token refusal and the streaming failure reproduced. The chapter honestly marks streaming FAILING, but does not deliver its completion oracle; client/upstream boundaries and metrics remain open.

All chapters contain substantive work, so none is graded SKELETON. None satisfies WRITTEN. The chapters’ own RED summaries total 40 fields; these 23 blocking findings group related defects and are not a claim that only 23 individual fields remain unfinished.

PANEL REVIEW COMPLETE

session_id: local-fc33037f1bd4fb90480526706fd19a3b4e8d618a5dbe5e9389cbf0f6090f7f00

EXIT=0
```

