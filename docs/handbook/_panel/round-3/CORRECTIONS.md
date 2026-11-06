# CORRECTIONS — round 3

Generated 2026-11-06T16:48:09-0500.

## Verdicts

- **deepseek** — FAIL, blocking 3, 10825 bytes, complete=True
- **glm** — FAIL, blocking 4, 9987 bytes, complete=True
- **grok** — FAIL, blocking 12, 10603 bytes, complete=True
- **kimi** — FAIL, blocking 1, 9005 bytes, complete=True
- **sol** — FAIL, blocking 26, 34896 bytes, complete=True

## Verdict text (verbatim, per seat)

### deepseek

```
VERDICT: FAIL

BLOCKING: 3 — findings that must be fixed before the chapter set can be called written

NON-BLOCKING: 3

FINDINGS:

BLOCKING

1. kind: UNVERIFIED — rule 2 (both sides) — M1, M3, M4, M5, M6, M9 — within-repo contracts still one-sided where the other side is nameable in code this round actually read.
   Claim (pattern): producer/consumer cells written as "rumour — one side only" or prose instead of file:function, on contracts whose both sides live inside these five repos.
   Evidence (each side IS findable and is named elsewhere in this very document):
   - M1-C1 consumer is "crier POST /agents/{id} handler" — but M10 §3 names the real function: `internal/registry/handler.go:598` `HandleRegister`.
   - M3-C2 producer is "the node's result envelope (branch, commit)" — but M2 §6 names the real builder: `node-bus-worker.py:1128` (the reply envelope).
   - M9-C1 (owner→scheduler) — "rumour — neither side named" (operator config / config load path); the config-load consumer is nameable (the chapter itself notes `admission_mode.go:112` reads it from the DB).
   - M4-C1 both sides "rumour"; M4-C2 producer "rumour" + consumer "an invocation"; M5-C1 consumer "per-leg verdict" (the producer `tests/harness-conformance.sh` IS named, the consumer side is not); M6-C2 both sides "rumour".
   The honest "rumour" flagging is a real improvement over round-2's overclaim (it stops lying), but flagging a rumour does not satisfy rule 2. For external boundaries (bunker binary M0-C1/M1-C2, GitHub M7-C1, filesystem M8-C1, upstream gateway M12-C2) "rumour — one side only, external system" is the correct completion; for these six within-repo rows it is not.
   Fix: name the producer/consumer file:function where it exists in the already-read code (cross-reference M10's HandleRegister into M1-C1, M2's reply builder into M3-C2, etc.); reserve "rumour" for the genuinely external boundaries only.

2. kind: UNVERIFIED — M9 — the owner→scheduler contract (M9-C1) is the clearest instance and the scheduler's reason to exist, and it has "neither side named" with state UNMEASURED.
   Claim: "M9-C1 | owner | in | rumour — neither side named (operator config, not a function) | rumour (config load path, not a function) | UNMEASURED".
   Evidence: the consumer is nameable — `admission_mode.go:112` `admissionModeForProject` reads from the DB; the config-load path and the lane enabled/cadence/weight/pin fields the OUTLINE §IV lists for this contract all live in this repo. A contract with one in-repo side unread is a rumour under rule 2; one with neither side named is an unwritten row.
   Fix: read the config-load path (and the DB read it lands in) and name producer + consumer file:function, or explicitly downgrade the row to "no owning module — see Part I.9" and stop listing it in §6.

3. kind: OMISSION — document as a whole — Parts I, II, IV–VIII have no chapters.
   Claim: OUTLINE.md commits to 8 parts; only Part III (13 module chapters) exists.
   Evidence: F1–F16 flows (the panel's largest standing finding), the 18-contract register (OUTLINE §IV still says "0 of 18 name both implementations"), the full settings register (~83 env / ~215 CLI, OUTLINE V), risk (VI), work derivation (VII), and delivery mechanisms (VIII) have no home. The outline itself marks F6–F16 "(MISSING)" and Parts IV–VIII as unwritten, so this is an acknowledged gap, not a hidden one — but a handbook that is 1/8 of its own structure cannot be called written.
   Fix: either write those parts or obtain an explicit quorum ruling that this round's deliverable is Part III only and record that ruling in the outline; as it stands the structure map promises 8 parts and delivers 1.

NON-BLOCKING

4. kind: OMISSION (system defect, correctly reported) — M0–M8, M11, M12 — Metrics "RED — none".
   Evidence: I confirmed the honesty is real — only M9 (server_metrics.go) and M10 (metrics.go) actually emit. The observability gap (dispatch/settlement/landing rate, refusal count, latency all answered by grep) is a defect in the systems, which the chapters correctly report. Not a writing defect.

5. kind: UNVERIFIED (aspirational settings) — M9 §5 — config resolution order is FEAT-005 target, not today's reality.
   Claim (F9-3): the daemon loads only the fleet sections + a few [scheduler] fields; [daemon]/[gateway]/[duckbrain] are not loaded until FEAT-005 wires LoadConfig.
   Evidence: `config.example.toml:12-16` (DOGFOOD-012) states exactly this. The 12 settings rows I verified against the file are therefore a register of intent, not of loaded behaviour. Correctly disclosed; worth a board row so the register and the loader cannot keep drifting apart.

6. kind: OMISSION (coverage) — M1, M5, M6, M10 — core submodule bodies still structure-mapped, not read line-by-line.
   Evidence: M1 (9 of 13 unit bodies unread, self-stamped UNVERIFIED), M5 (5 foreign installer bodies unread), M6 (pipeline beyond master_doc_check.py unread), M10 (handler.go's 1895-line body read at function/slog-surface level only). Each chapter discloses this honestly, and the cite-accuracy on what WAS read is excellent, but the outline's S-level submodule inventory is not yet fully evidence-backed.

DEFECT CLASSES:

one-sided-contract-residual (within-repo, nameable) · missing-parts (7 of 8 outline parts unwritten) · unread-submodule-body · honest-red-metrics (system gap, correctly reported) · aspirational-settings-register (config-not-loaded) · external-boundary-rumour (correct, not a defect)

CHAPTER SCORECARD:

- M0 shared-contract — WRITTEN. Both files read in full; F0-5/F0-6 verified true this round (credential predicate `[0-7]00` at harness-vars.sh:201-204, non-emptiness not set-ness at :176/:181 — both re-read and confirmed); source census 11/17 correct; M0-C1 is an external bunker boundary, so the one-sided flag is the correct completion. Metrics RED honest.
- M1 provisioning — PARTIAL. Floor precedence (:115-141) and F1-2 (unknown role raises FloorError, exit 2) verified; Status self-stamped UNVERIFIED (9 unit bodies unread); M1-C1 consumer nameable (HandleRegister) but left as prose.
- M2 dispatch — WRITTEN. The two best contract rows in the set — M2-C1 (`dispatch.go:202` text_b64 vs `node-bus-worker.py:986` text) and M2-C2 (`node-bus-worker.py:1132` status vs `dispatch_leg.go:713-726` ok) both name producer AND consumer file:function, and both CF-354/CF-355 re-verified; F2-3 (dispatch_wall does not clamp — `:1152-1157` int-converts then falls back) re-read and confirmed.
- M3 repository — PARTIAL. Land/freshness/gate cites verified; F3-2 (clone_lane clones a lane row, not a repo) and F3-3 (--gate-cmd empty default, no gate runs) both true; held back by the nameable M3-C2 producer and repo_freshness.py unread.
- M4 board — PARTIAL. Store re-measured (357 rows / 515 events, drift OK, 20 verbs, duplicate-id and evidence-run-id refusals reproduced); F4-2 (census vs validation) is a correct correction; but M4-C1/M4-C2 both remain one-sided within-repo.
- M5 harness — PARTIAL. Resolver + hermes installer verified (python >=3.11,<3.14 refusal, 28 tests); F5-2 (resolver has no production caller) correctly re-classifies S4 as optional; 5 foreign installer bodies unread, M5-C1 consumer vague.
- M6 documentation — PARTIAL. Gate result reproduced (44 modules / 37 VERIFIED / 50 errors, exit 1); F6-2 (structural/citation gate, not truth verifier) and F6-3 (ownership.py classified optional) both real; most of the pipeline unread, M6-C2 both sides vague.
- M7 github — PARTIAL. CLI surface verified (bare invocation → usage, exit 2); settings register now filled (F7-2 fixes the round-2 one-row register); mint UNVERIFIED (no App creds, honest); three script bodies largely unread.
- M8 safety — WRITTEN. Both files read in full; AGED_PARENTS = (.node/jobs, .node/clones) confirmed at :21, check_scan_scope surface (two path patterns, case-sensitive same-line rule, empty-selection OK) confirmed at :31-32/:64-68; F8-3 (dispatcher .cf-jobs not a reap target) real; M8-C1 external filesystem boundary.
- M9 scheduler — PARTIAL. The round-2 empties are now filled and correct: settings register (12 rows, all match config.example.toml exactly), admission authority read (admission_mode.go:98/:112, tick_process.go:40, packer_select.go:19, namespace_alloc.go:131, usage_pool_policy.go:21 — all line-exact), revision re-stamped 1771d3aa, Go version corrected to 1.26.5 (default PATH, verified). go test ./... re-run by this judge and the SCHED-GAP-1726 goroutine-census FAIL reproduced exactly (rc 1, 159.7s, "1 goroutine(s) still parked in evalDrain"). Held back by M9-C1 (both sides unnamed) and S1 grep-level coverage of four packages.
- M10 crier — PARTIAL. Ports (8767 config.go:622, 8770 main.go:39), client methods (deliver:975/retrieve:1009/ack:1038), metrics default (EnableMetrics:true, config.go:673 + CR_ENABLE_METRICS override) all verified; F10-2 corrected (host go 1.26.5, GOTOOLCHAIN=auto fetches 1.26.10, build/test PASS) and F10-3 (metrics default-ON) both real; contracts correctly re-attributed (M10 §4b now says the node worker does NOT import crier_client — the round-2 contradiction is fixed); 1895-line handler body read at function/slog level, not line-by-line.
- M11 dispatcher — WRITTEN. Read in full; M11-C2 corrected to "works" (dispatcher.py:500-508 always sends ok, which is exactly what dispatchReplyVerdict reads — CF-355 belongs to the node worker, not this producer); F11-3 (replay not crash-safe), F11-4 (margin is intended, not guaranteed), F11-5 (serial head-of-line blocking) all real and verified; M11-C1 both-sided.
- M12 inference-proxy — WRITTEN. Read in full; full sha256 `b12a0ac521c4b5a9cd7e2b76883a7edf2c9e0efd87d9bc3be3d2056d3f39e0b5` reproduced (273 lines); F12-3 (credential selector + hardcoded API_SERVER_KEY diagnostic at :269) and F12-4 (mid-stream failure terminates with no 502 — headers already sent at :206-210, flush at :217-218, bare return at :238) both verified; M12-C2 external upstream boundary.

Bottom line: the round-3 rewrite is a step-change in accuracy — I independently reproduced ~40 claims (the full scheduler go test, go version across three toolchains, every contested line citation, the config.example.toml register, both cross-system contract defects CF-354/CF-355) and found not one FALSE CLAIM remaining. The document no longer fabricates or overclaims; what remains is coverage, not truth: seven of the eight outline parts still have no chapter, six within-repo contracts are still one-sided when the other side is nameable in code this round actually read, and several submodule bodies are still structure-mapped rather than read. Fix those and this is a PASS set.

PANEL REVIEW COMPLETE

EXIT=0
```

### glm

```
│ cache/scratch/ffc_probe.sh
│ @@ -0,0 +1,7 @@
│ +#!/usr/bin/env bash
│ +set -u
│ +HERE=/home/kara/code-factory/scripts
│ +. "$HERE/lib.sh"
│ +fetch_verified "http://127.0.0.1:1/nothing" "/home/kara/.hermes/cache/scratch/ffc_artifact.bin" "deadbeef"
│ +echo "rc=$?"
│ +[ -e "/home/kara/.hermes/cache/scratch/ffc_artifact.bin" ] && echo "ARTIFACT LEFT" || echo "no artifact left"
All checks complete. ~130 line-level citations re-verified against the five codebases, every chapter's test battery re-run, both Go repos built and tested, one probe script executed. Verdict follows.

```
VERDICT: FAIL

BLOCKING: 4 — findings that must be fixed before the named chapter can be called written

NON-BLOCKING: 8

FINDINGS:

BLOCKING

1. kind UNVERIFIED — chapter M12 (§12 cross-reference; §6 contract M12-C1)
   Claim quoted: "M2 DISPATCH (node) is the client that reaches the proxy over the tailnet";
   M12-C1 producer cell: "node `POST /v1/chat/completions` with `Authorization: Bearer ***"
   with state "works".
   Evidence: `grep -rn '8775|proxy|PROXY|CF_PROXY'` over code-factory scripts/, config/,
   specs/ returns nothing (run this round) — no node file references the proxy at all; the
   producer side names no file:function; the row is also malformed (a pipe inside backticks
   splits the cell; `***` is an unexplained redaction). The proxy-side half (401 at :128-130,
   allowlist 403 at :155-160) is verified; the client half is asserted, not shown.
   Fix: name the node-side producer file:function (or restate the producer as the
   operator-configured CF_BASE_URL boundary and quote the empty grep as proof), and repair
   the table row. "Works" may not stand on one measured side.

2. kind UNVERIFIED (one-sided internal contract) — chapter M3 (§6, M3-C2)
   Claim quoted: producer = "rumour — one side only (the node's result envelope
   `branch`/`commit`; no producer file:function named)".
   Evidence: the producer exists and is already cited by M2 §6 — node-bus-worker.py:1128-1144
   builds the result envelope; `branch`/`commit` are its `git_field(...rev-parse...)` entries
   (re-read this round). Both sides of this contract live inside the five systems; leaving
   one unnamed is a rumour by the panel's own rule.
   Fix: one cell — cite node-bus-worker.py:1141-1142 as the producer.

3. kind UNVERIFIED (classification evidence is not an invoking line) — chapter M1 (§3)
   Claim quoted: S1 "disk_floor.py:144 `main()` is the CLI entrypoint; invoked by
   bunker-provision.sh"; S4 "node_seed.py runs inside bunker-provision --apply
   (docs/UNIT-MAP.yaml:64)".
   Evidence: OUTLINE §III.3 requires the invoking `file:line` or an absence proof by quoted
   grep. `main()` at disk_floor.py:144 is a definition, not an invocation; UNIT-MAP.yaml:64
   is a document, not code. No line of bunker-provision.sh calling disk_floor.py or
   node_seed.py is cited anywhere in the chapter.
   Fix: cite the actual call lines inside bunker-provision.sh, or quote the grep proving
   absence. The chapter's own note ("S1–S4 unit bodies are UNVERIFIED this round") confirms.

4. kind CONTRADICTION (field-contract violation) — chapters M5, M9, M10 (§1 Status)
   Claim quoted: M5 "Status: VERIFIED — … the remaining installer bodies not read
   line-by-line"; M9 and M10 "Status: PARTIAL".
   Evidence: MASTER-DOC-SCHEMA §1 enumerates Status as `VERIFIED` / `UNVERIFIED` / `FAILING`
   — never blank, never anything else. "PARTIAL" is not in the vocabulary, and M5's VERIFIED
   covers the same epistemic state (units admitted unread) that M1 stamps UNVERIFIED. Three
   chapters, one situation, three different words.
   Fix: one convention — unread bodies ⇒ UNVERIFIED for the module, with a scoped note
   naming what IS verified; reserve FAILING for measured breaks.

NON-BLOCKING

5. kind OMISSION — chapter M2 (§9): two log rows for a 1498-line active worker. No
   grep-derived inventory offered. Fix: derive §9 from a quoted grep of the logging calls.

6. kind OMISSION — chapter M6 (§6, M6-C2): producer "the render pipeline, no function" —
   gen_nasa_handbook.py is in M6's own unit list and can fill the producer side; only the
   consumer (owner approval) is genuinely external. Fix: name the render entry function.

7. kind UNVERIFIED (rule 4 — I could not repeat these either; each is honestly marked):
   M1 §7 certification ladder and M2 §7 / M10 §7 cf-node bus ladder (verified: no
   ~/node-bus-worker.py on this host), M5 §7 conformance legs, M7 §7 token mint (no App
   credentials on this host), M12 §7 live admission (proxy not started). These must run
   before their modules may carry VERIFIED.

8. kind OMISSION-adjacent, chapter correct — M11 §7/F11-2: confirmed by grep —
   tests/test_durable_job.py contains no assert/raise/exit, so the "live job tests" cannot
   fail; the chapter's UNVERIFIED row is right and the tests themselves are decoration until
   they assert (board-row material, not a chapter defect).

9. Documented system defects, reproduced this round (chapters already carry them with
   evidence — board rows, not doc gaps): CF-354 (node reads `text` at node-bus-worker.py:986
   vs scheduler emits `text_b64` at bus/dispatch.go:202 — both read verbatim); CF-355
   (dispatchReplyVerdict :713-726 returns success when `ok` is absent — read verbatim);
   SCHED-GAP-1726 (go test ./internal/scheduler reproduced: rc 1, goroutine parked in
   evalDrain, 157.6s); lint-gate pass-through (ruff confirms F841 at panel_loop.py:114);
   gitleaks hook exit-0 hole (install-gitreins.sh:130-132); landing gate empty by default
   (land-node-branch.sh:36, :171-193).

10. kind UNBUILDABLE-adjacent, systemic — M6 (§7/F6-1): the doc gate's `[0-9][0-9]-*.md`
    glob (master_doc_check.py:188) cannot select these `M*.md` chapters, so the handbook's
    own gate cannot certify the part of the handbook this loop is writing. Already filed;
    the fix is a gate change, not a chapter change — but WRITTEN status for chapters/ is
    currently un-gateable by machine.

11. PADDING hunt: none found. Every §5 settings row tested carries default + range +
    consequence; NAME ONLY count: 0. Log lines are classified descriptive/evidentiary with
    the distinction load-bearing (F0-4).

12. Rumour states that are honest boundaries (verified, not defects): M4-C1 — grep shows no
    in-repo producer invoking `boardctl create` (only board_lock.py:100 and
    gen_unit_map.py:45 reference the name), so the foreman→board producer genuinely lives
    outside this repo; M0-C1/M1-C2 (bunker CLI), M7-C1 (GitHub), M12-C2 (upstream gateway)
    are external peers with no file:function to name. Correctly measured.

DEFECT CLASSES:
- one-sided-internal-contract (nameable side left as rumour)
- unproven-cross-reference (client asserted without a cite)
- classification-evidence-not-invoking-line (definitions/docs standing in for call sites)
- status-vocabulary-drift (field contract violated: PARTIAL, scoped-VERIFIED)
- credential/live-node-gated-unrepeatable checks
- admitted-incomplete-inventory (grep-level reads of large bodies)
- gate-cannot-select-its-own-chapters
- decorative-tests (print without assert)

CHAPTER SCORECARD:
- M0  WRITTEN — 13/13 headings; every predicate and grep re-verified true ([0-7]00 vs
  "must be 600", non-emptiness vs set-ness, 11/17 sourcers, codex divergence); fail-closed
  fetch repeated (rc 1, no artifact).
- M1  PARTIAL — S1–S4 bodies unread (own admission); classification evidence not invoking
  lines (finding 3); cert ladder unrepeatable here.
- M2  WRITTEN — contract spine verified exactly (constants :80-84/:111-114, text refusal
  :986-991, reply fields :1128-1144 verbatim, dispatch_wall no-clamp, PID 1755676 hardcode);
  §9 thin (finding 5).
- M3  PARTIAL — every claim verified (GATE="" default, gate-only-when-set, explicit-object
  push + ancestry proof, lane-ROW clone with enabled=0/local repo_url, arm-51 F841
  reproduced); blocked only by the M3-C2 producer cell (finding 2).
- M4  WRITTEN — 357 rows / 515 events re-counted, drift RESULT: OK, duplicate-id refusal
  reproduced verbatim, evidence-run-id rule confirmed at --help:25.
- M5  PARTIAL — resolver-not-wired and opencode check-only verified true; three installer
  bodies unread; status word over-claims (finding 4).
- M6  PARTIAL — gate FAIL reproduced (44 modules, 37 VERIFIED, 50 errors, exit 1); panel
  path staleness verified; its own gate cannot grade chapters/ (finding 10).
- M7  PARTIAL — settings register fully verified (60/540/20, min-age 2400, if-older 0,
  exit-2 bare invoke); mint unrepeatable without App credentials.
- M8  WRITTEN — both files read in full, all cites exact; .cf-jobs reaper gap real
  (AGED_PARENTS = .node/{jobs,clones} only).
- M9  PARTIAL — settlement/envelope/config/metrics cites all verified (30 tables, board not
  board_row, absence-is-success premise verbatim); S1/S5 grep-level; go-test FAIL
  reproduced, not a doc defect.
- M10 PARTIAL — config defaults block verified (metrics default-ON, sig conditional,
  8767/8770); 1895-line handler §6 admitted non-exhaustive; status word off-vocabulary.
- M11 WRITTEN — read in full; every spot-check exact (task_seconds floor, serial loop,
  ledger-after-run ordering, reply body with error_b64, all 16 log lines).
- M12 PARTIAL — proxy side fully verified against the sha256-stamped file (admission,
  rewrite, mid-stream no-502, lying FATAL message); node-client side unproven (finding 1).

Score: 5 WRITTEN, 8 PARTIAL, 0 SKELETON. Zero FALSE CLAIMs in ~130 re-verified citations —
the round-3 chapters describe the code as it is. The FAIL is narrow: four fixable defects
(one contract cell, one cross-reference, one set of call-site cites, one status
convention), not a rewrite.
```

PANEL REVIEW COMPLETE

session_id: local-f2b05d177ed315d3a12eb87e79a7bd603cdf926a017f2503c07254b5503f1546

EXIT=0
```

### grok

```
⚠️  Primary auth failed — switching to fallback: fireworks / accounts/fireworks/models/deepseek-v4p1-flash-1017
VERDICT: FAIL

BLOCKING: 12 — findings that must be fixed before this chapter can be called written
NON-BLOCKING: 9

Basis: I judged the chapters against the code at the stamped revisions (code-factory 943ef98, scheduler 1771d3aa, crier 691f0c78, crier-fleet 283bca9, proxy sha256 b12a0ac5…) and re-ran the commands myself. The code-fact accuracy is genuinely high — every line citation I sampled landed (lib.sh 5-9/13/19-42/48-57/75-78, harness-vars.sh 176/201-204/276-277, install-codex.sh 47/67-72/190/276-280, node-bus-worker.py 986/1128-1144/1152-1157, configure_family.py 24-28, land-node-branch.sh 36/171-193/265-283, dispatch_leg.go 713-726, bus/dispatch.go 202, admission_mode.go 98/112, config.go 622-673, dispatcher.py 43-60/185-197/428-442/479/500-508, cf-inference-proxy.py 47/53/60/155-160/238/269). Reproduced live: scheduler go test FAIL (rc=1, SCHED-GAP-1726, 159.2s), crier go test PASS, both go build PASS, board 357 rows/515 events, board_drift RESULT OK, master_doc_check 44 modules/37 VERIFIED/50 errors/FAIL, scan-scope 15 claims OK, unit tests 40/28/9/12 PASS, scheduler /api/v1/metrics HTTP 200 with all named blocks. The failures are evidentiary and structural, not factual.

FINDINGS

1. OMISSION — M9 §9. Claim: "Log lines (verbatim)" table = 2 lines. Evidence: `grep -rn "log.Printf" internal/scheduler/*.go | wc -l` → 379. The chapter gives no partial-inventory qualifier (M10 does). Fix: inventory the control plane's operator surface, or state the table is a sample and name what generates the full set.

2. OMISSION — M11 §9. Claim: the verbatim operator-visible set (16 rows). Evidence: dispatcher.py logs at :147, :316, :413, :422, :450, :467, :537 are absent; :422 `client for %s failed` is cited in §10 as the distinguishing symptom of "node unreachable" while missing from §9. Fix: complete the table or mark it a subset.

3. NAME ONLY — M11 §5. Claim: `DISPATCH_TASK_S` default 240 (`:48`), range "positive int", "What breaks if changed: —". Per rule 3 this row is unwritten. Evidence: dispatcher.py:48, :185-197 (TASK_S is the fallback when wall_s<=0). Fix: state the consequence.

4. UNVERIFIED — M12 §6 M12-C1. Claim: producer "node `POST /v1/chat/completions` with `Authorization: Bearer ***", state "works". Evidence: the raw line (line 76) is a broken table cell — unclosed code span, redaction artifact, pipe inside the cell lost; and no node-side file:function is named. Fix: name the node producer call site and repair the row.

5. FALSE CLAIM — M1 §3 S1. Claim: "`disk_floor.py:144` `main()` is the CLI entrypoint; invoked by `bunker-provision.sh` before admission". Evidence: `grep -n "floor|FLOOR" scripts/bunker-provision.sh` → no matches; the only caller is `scripts/project-node.sh:173`. Fix: cite the real invoking line.

6. UNVERIFIED — M6 §3 S5–S8. Claim: gen_nasa_handbook.py, gen_system_views.py, extract_owner_decisions.py, gen_unit_map.py, verify-patch.sh are "active", evidence column = "render the handbook" / "extracts owner decisions" / "measures who references a unit" / "chain-break detection". Rule: evidence must be the invoking line or a quoted absence grep. Evidence: repo-wide grep finds no invoker for any of them (self-references only); no cron, systemd unit or lane references them. Fix: cite invoking lines or reclassify optional/legacy with the absence grep.

7. UNVERIFIED — M4 §9. Claim: three verbatim lines `boardctl: task id "%s" already exists…`, `…not found…`, `RESULT: OK / FAIL`. Evidence: no file:line anywhere; boardctl is an external binary, so the strings are untraceable from this repo. Fix: quote the source or a captured run with its command.

8. UNVERIFIED marked PASS — M0 §7. Claim: "fetch_verified fails closed … Last run: round-2, exercised by a judge … **PASS**" and "credential mode predicate … 2026-11-06 … PASS — reproduced (offline probe, round-2 sol)". Schema: a check that passed earlier is UNVERIFIED; a row dated today cannot be sourced to round 2. Fix: re-run both, record date, rev and output.

9. UNVERIFIED pointers (not repeatable) — M3 §7 "tests/selftest.sh arm 41… 12/12", M3 §10 "selftest arm 51 — F841 at scripts/panel_loop.py:114", M4 §7 "selftest arm 33". Evidence: tests/selftest.sh is 4,591 lines with no arm numbering (`grep -nE "\barm (33|41|51)\b"` → 0); arms are named loops. (The F841 itself is real: panel_loop.py:114 assigns `rc` and never reads it.)

10. CONTRADICTION — M0 §3 vs M5 §3, M3 §3 vs M5 §3. Claim: M0.S1 "variable contract (harness-vars.sh)" and M5.S5 "variable contract (harness-vars.sh)"; M3.S3 lists install-gitreins.sh and M5.S3 also lists install-gitreins.sh. OUTLINE gives M0.S1 = lib.sh shell contract and M5.S5/S3 = the rest. Two chapters own each unit with no arbitration; M8 shows the team knows how to resolve this (verify-patch.sh → M6.S8). Fix: one owner, the other cross-references.

11. UNVERIFIED (rule 2) — 12 of 13 chapters. Only M11-C1/C2 name both sides (`crier_client.py:1009`→`dispatcher.py:435`; `dispatcher.py:500-508`→`dispatch_leg.go:713`). Worst rows: M4-C1 both sides "rumour" (an invocation + a file), M4-C2 producer "the judge's verdict", M6-C2 both rumour, M5-C1/C2 consumer rumour, M9-C1 "neither side named" — yet several are scored "works". A row scored "works" with one side is a rumour with a verdict attached. Fix: name both implementations or set the state UNVERIFIED and drop "works".

12. Status vocabulary — M9 §1 "PARTIAL", M10 §1 "PARTIAL" (schema §1 allows only VERIFIED/UNVERIFIED/FAILING); M5 "VERIFIED" with 2 of 5 submodules unread and the conformance battery unrun, M6 "VERIFIED" while its own §7 gate reads `MASTER-DOC: FAIL`, M11 "VERIFIED" with an UNVERIFIED §7 row, M0 "VERIFIED" resting partly on a round-2 check. Fix: use the closed vocabulary and let the scope live in the body.

NON-BLOCKING

13. M12 §5 registers `LISTEN = ("0.0.0.0", 8775)` as a setting; it is a hardcoded constant (cf-inference-proxy.py:53) with no override, "range: a bind address", and the consequence is a rationale, not a break. Host-exposure boundary is unmeasured in §11.
14. M2 §3 S1 evidence is `main()` existence (`add_family_lanes.py`), not an invoking line — "active" asserted, not shown.
15. M1 §3 S4 evidence cites `docs/UNIT-MAP.yaml:64` (a generated document) where the code line exists (`bunker-provision.sh:454`).
16. Decoration checks: M11 §7 "source read … PASS", M12 §7 "file reachable `wc -l` … PASS" — cannot fail, so they prove nothing.
17. M6 §9 row 3 (`WRITER ROUND COMPLETE` / `PANEL REVIEW COMPLETE`) is this round's own marker and has no locator in the module.
18. M0 §3 labels two different submodules "S1" (shell contract, variable contract).
19. M10 §8 proves metrics default-ON but does not name the contradicting artifact: `internal/metrics/metrics.go:5` still calls `/metrics` "the opt-in GET /metrics surface".
20. M9 §8 block list is incomplete: the live payload also carries `uptime_s` and `generated_at`.
21. M3 §2 "the only path a finished node task has into `origin/main`" rests on a comment (`:8-9`); no enumeration of the alternatives is offered.

DEFECT CLASSES
- log-inventory omission (control-plane blindness; §9 presented as complete when it is 2 of 379)
- NAME ONLY setting (no consequence)
- one-sided contract (rule 2) with a "works" verdict attached
- evidence-of-classification replaced by prose; circular citation to a generated doc
- stale PASS rows (round-2 provenance stamped as current)
- non-repeatable pointers ("arm N" that does not exist)
- unit double-ownership across chapters
- status inflation / out-of-vocabulary status word
- corrupt table cell from a redaction artifact
- decoration checks that cannot fail
- hardcoded constant registered as a configurable setting

CHAPTER SCORECARD
- M0 PARTIAL — strong line evidence, but a round-2 PASS row, double-labelled S1, and a second submodule the module map assigns to M5; status over-claims.
- M1 PARTIAL — F1-1/F1-2/F1-3 verified in code; S1 evidence names the wrong invoker (bunker-provision.sh has no floor reference; caller is project-node.sh:173); S4 cites a doc.
- M2 PARTIAL — contracts, settings and F2-2/F2-3 verified exactly; S1 classification lacks an invoking line; the only node-side bus check is not repeatable here (admitted).
- M3 PARTIAL — F3-2/F3-3 verified; "arm 41/51" pointers unrepeatable; install-gitreins.sh double-owned with M5.
- M4 PARTIAL — census and drift reproduced (357/515, RESULT OK); §9 log lines have no locator; both contract rows name neither side; "arm 33".
- M5 PARTIAL — F5-2 verified (resolver has no production caller); VERIFIED status over 2 unread submodules + unrun conformance; shares harness-vars.sh with M0.
- M6 PARTIAL — the module's own gate fails (44/37/50, MASTER-DOC: FAIL) and S5–S8 are classified "active" on prose; §9 row 3 has no locator; status over-claims.
- M7 PARTIAL — settings, CLI surface (rc=2 usage), JWT window, mode gate all verified; mint unrun (admitted); single contract one-sided; most of the file body unread.
- M8 WRITTEN — both units read full; AGED_PARENTS (:21) and PROTECTED (:22) match; 9 reclaim tests and the 15-claim scan-scope check reproduced; failure modes name real OPEN items; the one one-sided row is the filesystem itself, which is defensible.
- M9 PARTIAL — the most measured chapter (build PASS, test FAIL reproduced by me at 159.2s, 30 tables, metrics HTTP 200, F9-3 corroborated: LoadConfig has no non-test caller) but §9 is 2 lines for a 379-site package.
- M10 PARTIAL — config, ports, handler funcs, slog lines and PASS test run all verified; honest non-exhaustive note; M10-C2 consumer is a file, not a function; status word outside the schema.
- M11 PARTIAL — the only chapter with both contract sides named, and every line citation I checked was exact; blocked by §9's 7 omissions (one cited in §10), the NAME ONLY row, and decoration/unrun checks.
- M12 PARTIAL — admission/routing/stream/capture and F12-3/F12-4 verified against code; blocked by the corrupt M12-C1 cell and its unnamed producer; LISTEN is a constant registered as a setting.

Not repeatable by me, and stated as such by the chapters: the live-node `--check` ladders (M1 §7, M2 §7, M10 §7), M11's live job tests, M7's mint (no App creds), M12's live 403 admission probe.

PANEL REVIEW COMPLETE

session_id: local-3a0d746112cd2bec396e4f862ae1988fe8a90f9f84d773acbdec64c43f223b4b

EXIT=0
```

### kimi

```
Both batteries done. Composing the verdict from ~60 spot-checked locator claims and 17 repeated verification commands.

VERDICT: FAIL — narrowly. No factual claim tested against the code failed; the round fails on one field-contract breach and carries seven non-blocking findings.

BLOCKING: 1
NON-BLOCKING: 7

FINDINGS:

1. kind: BLOCKING / field-contract breach (off-vocabulary status stamp)
   chapter: M9-scheduler, M10-crier
   claim quoted: "Status | **PARTIAL** — settlement … read this round" (M9 §1); "Status | **PARTIAL** — `internal/registry/handler.go` … read this round" (M10 §1)
   evidence: docs/MASTER-DOC-SCHEMA.md:21 — "Status | `VERIFIED` / `UNVERIFIED` / `FAILING` — never blank, never 'done'". PARTIAL is outside the closed set. The chapters' own scope detail is honest and thorough, but the identity field is malformed against the contract this document is judged by.
   fix: either restamp both chapters UNVERIFIED-with-scope (the scope prose already exists), or amend MASTER-DOC-SCHEMA.md §1 to admit PARTIAL and define it. Mechanical; minutes.

2. kind: UNVERIFIED (inherited, unmeasured state)
   chapter: M4-board
   claim quoted: "M4-C2 … **UNMEASURED** — round-2 carried 'broken (OUTLINE §IV)'; the state was inherited, not measured this round"
   evidence: chapter §6; no fixture run. Rule 1: a carried verdict with no fresh evidence stays UNVERIFIED.
   fix: run a gitreins verdict → board close fixture (or prove no such path exists) and stamp the measured state.

3. kind: CONTRADICTION (document-internal staleness)
   chapter: OUTLINE.md vs chapters M2/M9/M10/M11/M12
   claim quoted: OUTLINE PART IV — "Current: **0 of 18** name both implementations."
   evidence: chapters now name producer AND consumer file:function for at least 8 contracts: M2-C1 (`dispatch.go:202` → `node-bus-worker.py:986`), M2-C2 (`node-bus-worker.py:1128` → `dispatch_leg.go:713`), M9-C2/C3, M10-C1, M11-C1 (`crier_client.py:1009` → `dispatcher.py:435`), M11-C2, M12-C1. Verified this round against the code.
   fix: recount and rewrite the OUTLINE PART IV preamble.

4. kind: FALSE CLAIM (locator drift, minor)
   chapter: M9-scheduler
   claim quoted: F9-4 — "implemented in `metricsSpawns` (`:192`)"
   evidence: internal/api/server_metrics.go:195 is the `func` keyword; :192 is the doc comment. The sibling cite "described at server_metrics.go:20" is exact (verified).
   fix: cite :195 (or ":192-195").

5. kind: UNVERIFIED (verification debt — the check was repeatable and was not run)
   chapter: M12-inference-proxy
   claim quoted: "admission (live) … not run this round | **UNVERIFIED** — admission is a curl away … but the proxy was not started this round"
   evidence: the proxy is LIVE — `ss -tlnp` shows 0.0.0.0:8775 (pid 2603939). Repeated by this judge: POST with no token → 401; POST with a valid node token and model "definitely-not-allowed-model" → 403 {"error": "model not permitted", "allowed": ["hermes"]}. Both match cf-inference-proxy.py:128-130 and :155-160.
   fix: stamp the row PASS with today's output; the chapter's claim is true but its evidence cell is empty where it need not be.

6. kind: OMISSION (assurance gap behind a true claim)
   chapter: M10-crier
   claim quoted: "go test | `go test ./...` | green | 2026-11-06, rev `691f0c78` | **PASS** (rc 0, all packages ok)"
   evidence: reproduced — rc 0, but the run reports "ok crier/internal/registry 0.063s [no tests to run]". The 1895-line handler (S1, the module's core) is covered by zero executable tests; the green cannot fail for that package.
   fix: the chapter should state the shallowness, as M6 §7 does for its own FAIL; a PASS over a package with no tests is a weaker fact than the row implies.

7. kind: UNVERIFIED (one-sided internal contracts — rumour class)
   chapter: M4-board, M6-documentation, M9-scheduler
   claim quoted: M4-C1 "rumour — one side only" (both sides); M6-C2 "rumour — one side only" (both sides, UNMEASURED); M9-C1 "rumour — neither side named"
   evidence: chapter §6 rows. Honestly flagged per rule 2 (external peers like github.com, the upstream gateway, the bunker binary, a git remote and the filesystem legitimately have no in-repo function to name); but these three are internal wires with no file:function on either side.
   fix: name both implementations or file the board rows and cite them.

8. kind: FALSE CLAIM (settings-register imprecision, minor)
   chapter: M11-dispatcher
   claim quoted: "`DISPATCH_TASK_S` | 240 (`:48`) | positive int | … | —"
   evidence: dispatcher.py:48 — `TASK_S = os.environ.get("DISPATCH_TASK_S", "240")` keeps the value a string; `int(TASK_S)` happens only inside task_seconds (:193). A non-numeric env value raises ValueError at use, not at admission; the "what breaks" cell is "—".
   fix: note string-until-use and the ValueError-at-use failure mode; fill the consequence cell.

DEFECT CLASSES: off-vocabulary status stamp · inherited-unmeasured state · stale superseded count (OUTLINE vs chapters) · locator drift · verification debt (repeatable check left unrun) · green-over-no-tests assurance gap · one-sided internal contract (rumour) · consequence-cell imprecision

CHAPTER SCORECARD:
- M0-shared-contract: WRITTEN — 13/13 headings; every locator re-verified by this judge (grep counts 11/17, predicates [0-7]00 vs 600|400, defaults 40/1800, fetch_verified --max-time 120). Metrics RED declared, as the schema mandates.
- M1-provisioning: PARTIAL — S1–S4 unit bodies self-declared not read line-by-line; M1-C1 both sides unread. What was read (resolve(), probe, verify-node ladder) verified exact.
- M2-dispatch: WRITTEN — node worker contracts verified line-level (:986 text read, :1128-1144 reply shape, :1152-1157 dispatch_wall, configure_family.py:24-28 PID hardcode). Non-repeatable check honestly flagged.
- M3-repository: WRITTEN — gate-by-default correction verified (GATE="" at :36, set only at :76); clone_lane.py lane-row finding verified; dry-run row reproducible.
- M4-board: PARTIAL — store census and drift reproduced (357/515, RESULT OK), but both contracts are rumours and M4-C2 is inherited-not-measured (finding 2).
- M5-harness: WRITTEN — F5-2 (resolver has no production caller) verified against node-bus-worker.py:407-409/459-469 and dispatcher.py:260; adapter capability matrix verified (pins 0.19.0/0.17.1/0.166.0, python >=3.11,<3.14, opencode --apply refusal).
- M6-documentation: WRITTEN — gate FAIL reproduced byte-for-byte (44 modules, 37 VERIFIED, 50 errors, MASTER-DOC: FAIL, rc 1); F6-2 (structural, not semantic, gate) is the harsh call this panel exists to make; ownership.py status reproduced (held-by-live-worker, panel_loop).
- M7-github: PARTIAL — mint UNVERIFIED (no App creds on host, declared); settings/control regions verified exact (:45-52, JWT 60/540, TIMEOUT 20, --min-age 2400).
- M8-safety: WRITTEN — both units read in full; settings and scan-scope surface verified (:42/:46-47/:135, AGED_PARENTS .node/jobs+.node/clones, two path patterns, same-line rule, empty-selection OK).
- M9-scheduler: PARTIAL — settlement, admission, settings and metrics verified exact (dispatchReplyVerdict :713-726 reads only payload["ok"], absence=success; 30 tables, no verdicts; config.example.toml defaults all match; DOGFOOD-012 caveat true). go build PASS and go test FAIL (SCHED-GAP-1726 goroutine census, rc 1) both reproduced this round. Blocking stamp defect (finding 1); locator drift (finding 4).
- M10-crier: PARTIAL — handler entry points, guard pipeline, config defaults and agentsig conditional all verified (:598/:990/:1690/:1812, port 8767, EnableMetrics true :673, go build + go test PASS reproduced). 1895-line body not read line-by-line (declared); test green is shallow for registry (finding 6). Blocking stamp defect (finding 1).
- M11-dispatcher: WRITTEN — full-body read; F11-3 (dispatch :479 before ledger_put :481), F11-4 (task_seconds :185-197 floor 30), F11-5 (serial loop :428-442), reply always carries ok (:500-508) all verified. Settings imprecision is finding 8.
- M12-inference-proxy: WRITTEN — full-body read + content sha256 verified; fail-closed startup (:265-270), mid-stream no-502 (:236-238), hardcoded credential name (:269) all verified; live admission independently reproduced by this judge (401/403 PASS), upgrading the chapter's UNVERIFIED row (finding 5).

Basis for the verdict: I re-verified over 60 file:line claims across all 13 chapters and repeated 17 of the chapters' verification commands; every substantive claim held. The document's remaining REDs are self-declared, which the schema makes admissible. The single blocking finding is the out-of-vocabulary Status stamp in M9 and M10 against MASTER-DOC-SCHEMA.md:21 — cheap to fix, but the field contract is explicit, and a lenient round costs a loop iteration.

PANEL REVIEW COMPLETE

session_id: local-f6007e764b96e0c5e4f3efae4eb2a2d5b73d6f8dda42ac47b2d157c7ff46241c

EXIT=0
```

### sol

```
│ cache/scratch/handbook-r3-sol-probes.py
│ @@ -0,0 +1,76 @@
│ +import ast
│ +import importlib.util
│ +import io
│ +import json
│ +import pathlib
│ +import re
│ +import subprocess
│ +import types
│ +
│ +root = pathlib.Path('/home/kara/code-factory')
│ +chapter = (root / 'docs/handbook/chapters/M0-shared-contract.md').read_text()
│ +for line in chapter.splitlines():
│ +    if line.startswith('| who sources it'):
│ +        command = re.search(r'`([^`]+)`', line).group(1)
│ +        r = subprocess.run(command, shell=True, cwd=root, capture_output=True, text=True)
│ +        print('M0 literal command:', command)
│ +        print('result:', json.dumps({'rc': r.returncode, 'file_count': len(r.stdout.splitlines()), 'stderr': r.stderr.strip()}))
│ +
│ +path = '/home/kara/.hermes/scripts/cf-inference-proxy.py'
│ +spec = importlib.util.spec_from_file_location('proxy_audit', path)
│ +m = importlib.util.module_from_spec(spec)
│ +spec.loader.exec_module(m)
│ +m.upstream_key = lambda: 'fixture-only-not-a-credential'
│ +usage = []
│ +m.log_usage = usage.append
│ +
│ +class Response:
│ +    status = 200
│ +    headers = {'Content-Type': 'text/event-stream'}
│ +    def __init__(self, fail_after_chunk):
│ +        self.fail_after_chunk = fail_after_chunk
│ +        self.calls = 0
│ +    def read1(self, n):
│ +        self.calls += 1
│ +        if self.fail_after_chunk and self.calls == 1:
│ +            return b'data: fixture\n\n'
│ +        raise OSError('fixture upstream read failure')
│ +
│ +class Harness:
│ +    path = '/v1/chat/completions'
│ +    def __init__(self):
│ +        self.statuses = []
│ +        self.headers_out = []
│ +        self.wfile = io.BytesIO()
│ +    def send_response(self, code): self.statuses.append(code)
│ +    def send_header(self, *header): self.headers_out.append(header)
│ +    def end_headers(self): pass
│ +    _json = m.Handler._json
│ +
│ +for fail_after_chunk in (False, True):
│ +    m.urllib.request.urlopen = lambda *a, **kw: Response(fail_after_chunk)
│ +    h = Harness()
│ +    m.Handler._forward(h, 'POST', 'fixture-node', b'{"model":"hermes","stream":true}')
│ +    print('M12 streaming fault:', json.dumps({'after_chunk': fail_after_chunk, 'response_status_sequence': h.statuses, 'output': h.wfile.getvalue().decode()}))
│ +
│ +class Admission(Harness):
│ +    def _node(self): return 'fixture-node'
│ +    def _forward(self, *args): raise AssertionError('disallowed request forwarded')
│ +h = Admission()
│ +body = b'{"model":"definitely-not-allowed"}'
│ +h.headers = {'Content-Length': str(len(body))}
│ +h.rfile = io.BytesIO(body)
│ +m.Handler.do_POST(h)
│ +print('M12 isolated admission:', json.dumps({'statuses': h.statuses, 'body': h.wfile.getvalue().decode()}))
│ +
│ +source = pathlib.Path('/home/kara/crier-fleet/dispatcher.py').read_text()
│ +tree = ast.parse(source)
│ +fn = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'task_seconds')
│ +ns = {'TASK_S': '240', 'CAP_S': 7200, 'MARGIN_S': 60}
│ +exec(compile(ast.Module(body=[fn], type_ignores=[]), '<dispatcher task_seconds>', 'exec'), ns)
│ +print('M11 actual task_seconds:', json.dumps({str(w): ns['task_seconds'](w) for w in (0, 10, 60, 90, 10000)}))
│ +
│ +for name in ('M0-shared-contract.md', 'M5-harness.md', 'M12-inference-proxy.md'):
│ +    text = (root / 'docs/handbook/chapters' / name).read_text()
│ +    print('chapter:', name, 'lines:', len(text.splitlines()))
│ +print('PROBES COMPLETE: no upstream network or real credentials used')
VERDICT: FAIL
BLOCKING: 26 — grouped findings that prevent the affected chapters from being called WRITTEN
NON-BLOCKING: 0

FINDINGS:

Review basis:
  All thirteen M0–M12 chapters were read against the outline, field schema and actual implementation sources. Previous seats’ verdict files were not used as evidence.

  Source revisions matched the chapter stamps:
    code-factory: 943ef984dc093e5780605ac6e54cd043122126ef
    scheduler: 1771d3aad61e6c1ce2845e3f1450f88aa73340b3
    crier: 691f0c78fc75717295abf3bd85aaa9192616aac0
    crier-fleet: 283bca91091933177ec521e52f37f1bc987cf7da

  The proxy’s measured SHA-256 matched its chapter:
    b12a0ac521c4b5a9cd7e2b76883a7edf2c9e0efd87d9bc3be3d2056d3f39e0b5

Evidence path prefixes:
  CF = /home/kara/code-factory
  SC = /home/kara/coding-hermes-scheduler/coding-herms-scheduler
  CR = /home/kara/crier
  DF = /home/kara/crier-fleet
  PROXY = /home/kara/.hermes/scripts/cf-inference-proxy.py

Accurately documented implementation defects, including the text_b64/text mismatch and status/ok mismatch, are not counted below as new false documentation claims. Explicit RED fields nevertheless remain blockers under the supplied schema.

B01 — UNVERIFIED — M0–M12 — Both-sided implementation contracts remain incomplete.

  Claim quoted:
    M0:94: “rumour — one side only”
    M4:66: producer is “boardctl create/update”; consumer is the JSONL store.
    M9:88: consumer is “node/dispatcher decode”.
    M12:77: upstream consumer is not a function.

  Evidence:
    These are admissions of missing contract fields, not completed contracts. Even apparently concrete rows sometimes name an expression rather than its implementing function: M2:78 names a read at node-bus-worker.py:986, whose enclosing consumer is process() at CF/scripts/node-bus-worker.py:972. M11:69 presents the client’s retrieve() as the producer instead of identifying the server’s HandleRetrieve at CR/internal/registry/handler.go:1690.

    CF/docs/MASTER-DOC-SCHEMA.md:51–57 requires both implementing files and functions.

  Fix:
    Complete each contract at its actual boundary. Name producer and consumer functions, payload, timing, failure semantics and compatibility rule. External implementation unavailable must remain explicitly UNVERIFIED; “works” does not waive the missing side.

B02 — UNVERIFIED — M1, M2, M3, M5, M6, M8, M9, M10, M11, M12 — “Active” is repeatedly supported by existence, not invocation.

  Claim quoted:
    M1:35: “main() is the CLI entrypoint”
    M2:34: “tests/test_lane_target.py exercises it”
    M8:33–34: main() and __main__ guards
    M12:32–35: “read”

  Evidence:
    CF/scripts/disk_floor.py:144 defines an entry point. CF/scripts/check_scan_scope.py:117 invokes its own main only when executed. Neither establishes that a scheduler lane, timer, cron or another production unit invokes it.

    The classification rule at CF/docs/handbook/OUTLINE.md:107–113 specifically requires the invoking line. An operator-invoked facility can be optional, not automatically active.

  Fix:
    Replace entry-point and “read” evidence with the actual caller or installed service/timer invocation. Where that cannot be established, mark activation UNVERIFIED. Apply the rule consistently rather than only to harness_resolve.py and ownership.py.

B03 — OMISSION — M0–M8, M11, M12 — Required metrics fields remain RED.

  Claim quoted:
    These eleven chapters explicitly report “RED — none.”

  Evidence:
    CF/docs/MASTER-DOC-SCHEMA.md:72–79 makes an absent metrics surface a RED field. Examples inspected directly include CF/scripts/lib.sh:5–11, DF/dispatcher.py:112–120 and PROXY:83–101: their output is reporting or capture, not the required counter/gauge/histogram inventory.

  Fix:
    Do not call these chapters WRITTEN while this requirement remains unsatisfied. Either supply an evidenced metrics surface or obtain an explicit schema exception defining an acceptable alternative. Accurately describing “none” is honest, but it does not turn the required field green.

B04 — UNBUILDABLE — M0, M1, M2, M3, M5, M7, M10, M11, M12 — Several verification rows are descriptions of tests, not executable procedures.

  Claim quoted:
    M0:105: “source both contracts, probe modes 400/600/700/644”
    M3:96: “--workdir <scratch> … --commit <sha>”
    M7:75: “token …”
    M11:77: “read_file dispatcher.py”
    M12:90: “run the proxy, POST with a disallowed model”

  Evidence:
    These omit fixture creation, complete arguments, execution location or a concrete oracle. M2:92 and M10:91 explicitly acknowledge that their node command is not repeatable from this control host. Several dated verification rows also lack their own revision or artifact binding.

    I did not repeat live provisioning, credential minting, remote harness execution or the full Go suites. Those results are not independently confirmed by this review.

  Fix:
    Supply complete fixture/setup/run/assert/cleanup procedures, execution locations and credential prerequisites. Bind historical results to revisions and artifacts. Keep unavailable live checks UNVERIFIED rather than treating syntax checks or source reads as substitutes.

B05 — FALSE CLAIM — M0 — Both published source-count commands fail literally.

  Claim quoted:
    M0:102–103 reports PASS with 11 direct sourcers and 17 total sourcers.

  Evidence:
    I extracted each command verbatim from the chapter and executed it in CF. Both returned:
      rc=1
      file_count=0
      stderr=""

    The displayed grep expressions are over-escaped. This is a reproducibility failure even if a corrected expression would recover the intended counts.

  Fix:
    Replace the commands with expressions that actually match the source. Re-run them and publish the command, matching file list and count together.

B06 — FALSE CLAIM — M0, M5 — The shared variable contract is not sourced by every installer.

  Claim quoted:
    M0:38: “sourced by every harness installer”
    M0:46: “install-opencode.sh uses the shared contract; install-codex.sh does not.”

  Evidence:
    The account of divergent implementations is incomplete. CF/scripts/harness/install-claude-code.sh:34–36 sources lib.sh, not harness-vars.sh. It implements its own CLI and variable behavior, including --turn, at :60–115 and :127 onward.

    This is another independent adapter contract, not merely the codex divergence already described.

  Fix:
    Replace the universal sourcing claim with a per-adapter implementation map. Document which adapters share the validator, which duplicate it and where their accepted inputs and enforcement differ.

B07 — OMISSION — M0, M5 — The CF_* settings register omits substantial enforced behavior.

  Claim quoted:
    M0:69: “harness-vars.sh is the register for the CF_* set it enforces”
    M5:66 describes CF_* validation as a library contract.

  Evidence:
    CF/scripts/harness/harness-vars.sh:28–31 declares the input and required sets. Its enforced rules include:
      CF_BASE_URL scheme and userinfo refusal: :211–220
      CF_MODEL shape: :223–225
      provider/namespace/lane shape: :226–231
      CF_RUN_ID shape: :233–236
      CF_WORKDIR realpath containment: :239–250
      CF_SKILLS_DIR warning behavior: :254–261
      CF_HARNESS_OPTS syntax and secret detection: :264–272
      required fields specifically in contract mode: :307–316

    The chapter registers do not give these settings their complete defaults, valid shapes, mode-dependent requirements and consequences.

  Fix:
    Register every declared input and validation mode. Distinguish unset, required, recorded-only, warning-only and enforced behavior. A reference to “the CF_* contract” is not a replacement for its operational specification.

B08 — OMISSION — M1 — The provisioning control surface and destructive branch are unwritten.

  Claim quoted:
    M1:16: “Turns a bare host into a node”
    M1 §5 registers only ROLE_DEFAULTS and DEFAULT_ROLE.

  Evidence:
    CF/scripts/bunker-provision.sh:95–123 parses configuration as data and rejects unknown keys. Its CLI at :561–609 controls credentials, profile application, namespaces, repository/ref, harness selection and overrides.

    It also implements --destroy with a mandatory --yes and a bunker destroy call at :550–558. These controls are absent from the settings register and recovery procedure.

  Fix:
    Document the actual configuration keys, precedence, defaults, valid values and consequences. Include teardown authorization, exact target selection and what the destroy operation does and does not remove. Mark unread provisioning units as separate unresolved coverage, not one generic status sentence.

B09 — OMISSION — M1 — The “certification ladder” covers only part of the implemented ladder.

  Claim quoted:
    M1:124–129 lists agent_alive, gateway_reachable, unauth_refused and the two strictness switches.

  Evidence:
    CF/scripts/verify-node.sh also implements:
      artifact digest comparison: :105–115
      checkout freshness and its exit mapping: :118–155
      seed drift and its exit mapping: :157–202
      final FAIL/UNVERIFIED/PASS precedence: :205–214

    In particular, the default freshness-unmeasurable branch at :145–151 and seed-unmeasurable branch at :188–198 do not have identical effects.

  Fix:
    Give every leg its trigger, measurement, exit mapping, strict-mode behavior and expected indication. An operator must be able to distinguish a usable gateway, a fresh checkout and an intact seed instead of treating them as one certification claim.

B10 — OMISSION — M2 — Inbox settlement, durable replay limits and operator controls are insufficiently specified.

  Claim quoted:
    M2:72 describes SEEN_LIMIT as the “idempotency window”.
    M2 §10 names protocol mismatches but not the full execute/deliver/cache/ack failure sequence.

  Evidence:
    CF/scripts/node-bus-worker.py:1304–1367 executes messages, delivers results, updates and saves the seen cache, then acknowledges. Results enter the cache after delivery succeeds; save failure only warns. A crash before persistence is therefore not covered by durable replay.

    The CLI also exposes reply target, long-poll budget, interval, harness wall and HTTP timeout at :1430–1450, with validation at :1454–1478. These are missing from the settings register.

  Fix:
    Write the settlement state machine, persistence boundary, crash windows and per-branch retry consequences. Register the actual worker controls, including --reply-to’s default and the 0..120 long-poll bound.

B11 — OMISSION — M3 — Hook installation is described, but hook effectiveness is not operationally specified.

  Claim quoted:
    M3:37 identifies generated hooks, .gitleaks.toml and core.hooksPath as S3.
    M3:81 acknowledges that a generated hook does not prove Git invokes it.

  Evidence:
    CF/scripts/install-gitreins.sh:59–63 checks only an executable .git/hooks/pre-commit containing “gitreins”. At :120–138 it preserves an existing such hook or writes one. It does not establish the effective core.hooksPath or exercise a rejecting commit.

    The inspected boardctl help separately exposes boardctl install and enforce/warn lint modes. The chapter supplies no complete board-lint installation or effective-hook verification procedure.

  Fix:
    Document effective hook-path resolution, coexistence of board-lint and GitReins, enforcement versus warning mode and a disposable rejecting-commit fixture. Give the bypass disclosure procedure concrete fields and evidence rather than merely saying it must be disclosed.

B12 — OMISSION — M4 — The chapter names semantic validation but does not record or operationalize it.

  Claim quoted:
    M4:83: “The real validation is boardctl’s validate verb”
    M4 §7 records census, parity, lock behavior and duplicate-id refusal, but no validate result.

  Evidence:
    I ran scripts/boardctl validate in CF. It reported:
      rows: 357 tasks, 515 events, 0 fixtures
      key uniformity: 357/357 rows carry only canon keys (0 drift)
      RESULT: OK (7 warning(s))

    The warnings included free-form guard/CI values, priority/title disagreements, a duplicate event id and skipped header checks on a headerless board.

    The measured CLI also distinguishes ordinary validate from --strict-keys and --fail-on dangling-dep. Those acceptance differences are absent from the chapter.

  Fix:
    Add the real semantic-validation command and result, distinguish warnings from failures and specify the stricter gate policy. Document row/event vocabulary and evidence-binding semantics sufficiently for a writer to construct valid updates, not merely discover twenty verb names.

B13 — OMISSION — M5 — The adapter capability matrix still leaves immediately discoverable behavior unread.

  Claim quoted:
    M5:131: Claude Code “body unread this round”
    M5:133: DeepSeek and pi-agent “bodies unread this round”

  Evidence:
    CF/scripts/harness/install-deepseek.sh:95–97 refuses --apply.
    CF/scripts/harness/install-pi-agent.sh:107–109 refuses --apply.
    CF/scripts/harness/install-claude-code.sh:60–115 exposes --turn, a pinned package, Node >=22, isolated settings, credential requirements and a turn limit that is not always enforced.

    These are substantive support and operation differences, not obscure internals.

  Fix:
    Complete the per-adapter matrix: install/check/contract/turn support, pins, prerequisites, credential path, invocation, actual budget enforcement and refusal behavior. Do not leave installed/check-only/unsupported distinctions implicit.

B14 — CONTRADICTION — M6 — The chapter both claims and disproves VERIFIED recomputation.

  Claim quoted:
    M6:17–18: “master_doc_check.py recomputes VERIFIED from headings, locators and facts; without it a VERIFIED stamp is prose.”

  Evidence:
    CF/scripts/master_doc_check.py:128–138 reads the supplied status and applies additional checks. At :214–216 it retains and counts that supplied status.

    M6:26–32 correctly explains this later in the same chapter. I repeated the checker and obtained:
      44 module(s): 37 VERIFIED, 50 error(s), 0 warning(s), 10 fact(s) in the ledger
      MASTER-DOC: FAIL

  Fix:
    Remove the recomputation claim. State consistently that the checker validates structure/citations and reports the document’s declared status; it does not derive semantic truth.

B15 — UNBUILDABLE — M6 — The fill/render pipeline does not operate on the delivered chapter set, and this is incompletely documented.

  Claim quoted:
    M6:42: S5 is active and will “render the handbook”.
    M6 §10 describes stale checker and panel selection, but not the renderer’s equivalent failure.

  Evidence:
    CF/scripts/gen_nasa_handbook.py:17–18 hardcodes docs/master. At :253–260 it selects NN-*.md and refuses an empty selection.

    I executed it with output paths under the scratch directory. Its output was:
      no modules found

    CF/scripts/master_doc_fill.py:26 also defaults to docs/master and selects NN-*.md at :422. Its engine, worker count and write controls are implemented at :393–418 but absent from the chapter settings.

  Fix:
    Document each stage’s actual input selection and output artifact. Mark the delivered M-chapter pipeline unsupported where appropriate. Provide a concrete route from these chapter files to the approval artifact and register the stage-specific settings. Do not describe a legacy renderer as the working delivery path.

B16 — FALSE CLAIM — M7, M11, M12 — Credential producer ownership is conflated across unrelated token systems.

  Claim quoted:
    M7:107: M11 consumes the scoped per-dispatch credential “minted on this box”.
    M11:135: “M7 GITHUB mints the per-dispatch scoped token”.
    M12:137: “M7 GITHUB and M1 PROVISIONING produce the node tokens this proxy admits.”

  Evidence:
    DF/dispatcher.py:68–95 loads /home/kara/.hermes/scripts/fleet-gh-scope.py and calls its dispatch_env/env_prefix interface.

    That tool’s mint_scoped at /home/kara/.hermes/scripts/fleet-gh-scope.py:81–94 invokes a different minter, ~/.hermes/scripts/gh-app-token.py, configured at :52.

    CF/scripts/github-app-token.py:362–372 implements the chapter’s installation-token mint. PROXY:48 and :65–72 instead load a node-token JSON mapping; :115–123 compare incoming bearer tokens against it. The chapters do not identify the actual producer of that mapping.

  Fix:
    Separate GitHub installation tokens, per-repository dispatch credentials, crier credentials and inference node tokens. Name their actual producers, consumers, stores, scopes and rotation paths. Mark the proxy-token producer unknown until established.

B17 — OMISSION — M7 — Essential mint inputs and lifecycle controls are absent or NAME ONLY.

  Claim quoted:
    M7 §4 lists the App private key as “an App key file (env file)”.
    M7 §5 gives several ranges only as “seconds” or “a path”.

  Evidence:
    CF/scripts/github-app-token.py requires distinct numeric App and installation identifiers at :300–322 and a separate RSA key file with exactly mode 0600 at :326–358.

    Output destination resolution is at :579. Environment overrides for input/API defaults are at :107–117. Refresh controls include --token-file, --git-credentials, --dry-run and --quiet at CF/scripts/github-app-refresh.sh:37–53. The empty-node default selects local behavior at :104.

  Fix:
    Document the credential input schema separately from the key file, required identifiers, mode requirements, destination precedence, refresh scheduling and all write/no-write controls. Replace unit names masquerading as ranges with actual accepted and enforced bounds.

B18 — FALSE CLAIM — M9 — Example configuration values are presented as defaults instead of actual daemon defaults.

  Claim quoted:
    M9:64: min_interval default 20m
    M9:68: max_concurrent default 12
    M9:72: namespace_mode default true

  Evidence:
    Actual daemon flag defaults in SC/cmd/schedulerd/main.go are:
      :108 — min-interval = 30 seconds
      :112 — max-concurrent = 10
      :113 — namespace-mode = false

    The later chapter caveat that only selected TOML fields are loaded makes it especially unsafe to use the example file as the runtime default register. The max_concurrent consequence also incorrectly discusses an independent load gate.

  Fix:
    Separate binary defaults, example values, accepted TOML fields and deployed overrides. Cite each setting’s actual reader. Register load-gate-threshold independently; its binary default is 0, disabled, at main.go:144.

B19 — OMISSION — M9 — Admission and operator authority are inventoried, not explained.

  Claim quoted:
    M9:33 names admissionModeFor, evaluate, Pack, Allocate and reserveUsagePools.
    M9:36 describes operator surfaces as seven command names.

  Evidence:
    SC/internal/scheduler/admission_mode.go implements board ownership at :143–184 and tasks admission at :208 onward. It distinguishes workable rows, unreadable boards, owned/shared boards and cooldown fallback.

    SC/cmd/schedulerd/main.go:142–170 exposes pacing, load admission, board-stasis, memory and liveness controls. Operator authentication is implemented in SC/internal/api/auth.go, including credential extraction at :187–197. These affect a run but are not operationally specified in M9.

  Fix:
    Write the actual admission decision sequence, including ownership, workability, pacing and refusal reasons. Document mutation authentication, command/API entry points, durable transitions and recovery. Package/function lists do not satisfy the S1–S5 chapter obligations.

B20 — CONTRADICTION — M9, M10 — Identity status violates the supplied field vocabulary.

  Claim quoted:
    M9:12: Status “PARTIAL”
    M10:12: Status “PARTIAL”

  Evidence:
    CF/docs/MASTER-DOC-SCHEMA.md:21 permits VERIFIED, UNVERIFIED or FAILING. The handbook README itself separates identity status from chapter completeness at :54–60.

  Fix:
    Keep PARTIAL in the chapter-completeness scorecard. Use the schema’s identity vocabulary and specify which claims are verified, unverified or failing.

B21 — OMISSION — M10 — Guard failure policy and oversized-payload behavior are missing from the safety account.

  Claim quoted:
    M10:23–25 describes the guard’s normal pipeline and a false pass.
    M10:66 compresses Guard.* controls into one row with range “—”.

  Evidence:
    CR/internal/guard/guard.go:198–234 skips the LLM for oversized payloads and branches on deterministic evidence.
    Its errorResult at :318–361 defaults to fail-open, preserves high-confidence deterministic blocks and applies fail-closed policy when configured.
    Policy precedence is implemented at CR/internal/guard/policy.go:172–202.

    Actual setting validation is at CR/config/config.go:1139–1187, including positive bounds for timeout, concurrency and payload caps.

  Fix:
    Document disabled, oversized, saturated, provider-outage, malformed-verdict, fail-open and fail-closed paths. Register each control with its environment name, units, bound and consequence. The security boundary cannot be conveyed by the happy-path pipeline alone.

B22 — OMISSION — M9, M10 — “Real metrics” is not the required metrics inventory.

  Claim quoted:
    M9:106–113 lists JSON blocks.
    M10:97 says there is “at least one counter crier_detect_alerts_total”.

  Evidence:
    SC/internal/api/server_metrics.go:125 onward distinguishes sources and reset/window behavior; for example, deferrals are per-process counters reset on restart at :132–136.

    CR/internal/guard/metrics.go:19–49 exposes saturation/provider-failure counters and a duration histogram with decision/errored labels. CR/cmd/server/observability.go:168 onward registers gauges. These are operationally important surfaces absent from the inventory.

    The schema requires metric, type, labels, question answered and scrape location—not merely existence of an endpoint.

  Fix:
    Derive the full inventory from registrations and increments. Include units, bounded labels, reset semantics, windows, availability reasons, scrape authentication and the scraper or explicitly unknown scrape deployment.

B23 — OMISSION — M11 — The dispatcher can disable its durable job model, but the chapter never names the switch.

  Claim quoted:
    M11:17: “start detached, poll with short calls, kill the process group on deadline”
    M11 §5 omits CF_DURABLE_JOB.
    M11:60 leaves DISPATCH_TASK_S’s consequence as “—”.

  Evidence:
    DF/dispatcher.py:334–358 selects a separate synchronous path when CF_DURABLE_JOB=0. This bypasses the detached start/poll job model that the chapter presents as the dispatcher’s behavior.

    Additional operational controls include progress cadence at :45, agent selection at :104–109, log/PID paths at :41–42 and the scope tool at :68.

  Fix:
    Register the execution-mode switch and explain both paths, their deadline/failure differences and the legacy stream-boundary risk. Complete fallback-duration consequences and the remaining service configuration.

B24 — FALSE CLAIM — M12 — Failure before the first body chunk does not guarantee a clean 502 response.

  Claim quoted:
    M12:117: “Upstream unreachable before first byte | 502”
    M12:129–130: “A 502 is returned only when the failure happens before the first byte.”

  Evidence:
    PROXY:206–210 sends the upstream status and ends headers before reading the first chunk at :212. The exception branch tests first is None at :236, which means no body chunk was received—not that headers remain unsent.

    An isolated execution of the actual _forward method with a failing first upstream read produced:
      response_status_sequence: [200, 502]

    With one chunk followed by failure it produced:
      response_status_sequence: [200]

    No upstream network or real credentials were used.

  Fix:
    Distinguish connection failure before upstream acceptance, read failure after downstream headers but before the first chunk, and failure after a chunk. Document the attempted second response in the middle case; do not promise a valid standalone 502.

B25 — FALSE CLAIM — M12 — “Python 3.x” is not a sufficient interpreter constraint.

  Claim quoted:
    M12:43: python3, “stdlib only”, constraint “3.x”

  Evidence:
    PROXY:164 defines _forward with bytes | None and has no postponed-annotation import. That evaluated union annotation requires Python 3.10 or later; older Python 3 interpreters do not satisfy the source as written.

  Fix:
    State and test the minimum interpreter version. Separate “no third-party packages” from “compatible with every Python 3 release”.

B26 — OMISSION — M12 — Capture content and capture/usage failure semantics are not specified.

  Claim quoted:
    M12:94–97 describes “structured capture/usage JSONL” and lists attribution fields.
    M12 §10 contains no capture-write or usage-write failure mode.

  Evidence:
    PROXY:83–95 records the raw request body, truncated to 120000 characters, plus message/tool counts and request keys. Capture exceptions are silently swallowed.

    PROXY:98–101 writes usage without equivalent exception suppression. These writes occur on admission-refusal and forwarding paths, including :152–157, :220–238 and :252–253. Failure of the usage sink can therefore affect request handling rather than merely omit telemetry.

    The capture function also appends without implementing the “last 200 requests” retention claimed by the source comment at :51.

  Fix:
    Document exact paths, content sensitivity, truncation, permissions, retention and rotation ownership. Distinguish capture loss from usage-write failure and state how either is detected. Do not infer implemented retention from a comment.

Verification repeated by this judge:
  python3 tests/test_disk_floor.py — 12 tests, OK
  python3 tests/test_lane_target.py — 40 tests, OK
  python3 tests/test_harness_resolve.py — 28 tests, OK
  python3 tests/test_reclaim.py — 9 tests, OK
  python3 scripts/master_doc_check.py — MASTER-DOC: FAIL; 50 errors
  python3 scripts/check_scan_scope.py — 15 claims; RESULT: OK
  python3 scripts/board_drift.py check --workdir /home/kara/code-factory --ref origin/main — RESULT: OK
  scripts/boardctl validate — RESULT: OK (7 warning(s))
  bash scripts/verify-patch.sh — VERIFY-PATCH: PASS
  M0 literal grep procedures — both failed, zero matches
  Isolated proxy admission — 403 “model not permitted”; forwarding was not reached
  Isolated proxy streaming failures — reproduced the header/first-chunk distinction above
  Dispatcher task_seconds — confirmed 10s and 60s caller budgets both produce a 30s task budget

  The full scheduler/crier Go suites and live node, mint and remote-job checks were not repeated. This verdict does not claim otherwise.

DEFECT CLASSES:
  One-sided contracts
  Activation inferred from existence
  Unresolved mandatory RED fields
  Non-executable verification procedures
  Broken literal commands
  Divergent validator implementations
  NAME ONLY and omitted settings
  Missing lifecycle and recovery branches
  Hook presence mistaken for enforcement evidence
  Self-reported status mistaken for recomputation
  Legacy pipeline selection
  Credential-domain conflation
  Example values mistaken for runtime defaults
  Invalid identity-status vocabulary
  Incomplete guard policy
  Incomplete metrics inventory
  Undocumented execution-mode switch
  Headers/body failure-boundary confusion
  Incorrect interpreter constraint
  Unspecified capture and telemetry failure semantics

CHAPTER SCORECARD:

  M0 — PARTIAL
    Concrete helper and predicate evidence exists. Literal verification commands fail; universal adapter sourcing is false; variable settings, contracts and metrics remain incomplete.

  M1 — PARTIAL
    Disk-floor behavior is substantiated, including passing unit tests. Provisioning controls, teardown and the complete certification state mapping are not written.

  M2 — PARTIAL
    The two principal dialect mismatches are accurately described. Settlement durability, replay boundaries, activation evidence and worker controls remain incomplete.

  M3 — PARTIAL
    Landing and optional-gate behavior are substantially grounded. Effective hook enforcement, board-lint operation and a complete reproducible verification procedure are missing.

  M4 — PARTIAL
    Census and published-reference parity were reproduced. Semantic validation has unresolved warnings, while row/event policy and contract implementations remain insufficiently specified.

  M5 — PARTIAL
    Resolver tests pass and its unwired status is acknowledged. The adapter matrix still omits available operational behavior, and the shared-variable account is incomplete.

  M6 — PARTIAL
    The checker’s real failure is reproducible. The chapter contradicts itself about status recomputation and does not provide a working fill/render path for these chapters.

  M7 — PARTIAL
    CLI behavior and portions of the refresh path are grounded. Mint inputs and lifecycle settings are incomplete; credential production is incorrectly mapped to other systems; live mint remains unverified.

  M8 — PARTIAL
    Reclaim tests and scan-scope behavior were reproduced. The active classification lacks invoking evidence, the service contract is incomplete and the mandatory metrics field remains RED.

  M9 — PARTIAL
    Settlement defect descriptions are grounded in source. Runtime defaults are wrong, admission/operator behavior is mostly inventoried rather than specified, metrics are incomplete and identity status violates the schema.

  M10 — PARTIAL
    Default-on metrics and signed-read ordering are grounded. Guard degradation policy, settings bounds, complete metrics and client/transport contracts remain unwritten.

  M11 — PARTIAL
    Ledger ordering, serial execution and budget-floor behavior are accurately described. The nondurable execution switch is omitted, credential ownership is wrong and live verification lacks a reliable executable oracle.

  M12 — PARTIAL
    Hash, admission logic and mid-stream truncation behavior are grounded. The pre-first-chunk guarantee is false, Python requirements are wrong and token provenance/capture failure contracts are incomplete.

No chapter qualifies as WRITTEN. None is merely a SKELETON: all contain substantive source-backed material, but every chapter still has blocking field or behavioral gaps.

PANEL REVIEW COMPLETE

session_id: local-70787b3b8fdee698b884a209105a2e0c8ceffd95c85d231fd2801f6c7b83c802

EXIT=0
```

