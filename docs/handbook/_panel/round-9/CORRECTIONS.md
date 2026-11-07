# CORRECTIONS — round 9

Generated 2026-11-06T19:58:48-0500.

## Verdicts

- **deepseek** — FAIL, blocking 3, 6317 bytes, complete=True
- **glm** — FAIL, blocking 4, 24459 bytes, complete=True
- **grok** — FAIL, blocking 8, 18074 bytes, complete=True
- **kimi** — FAIL, blocking 5, 10065 bytes, complete=True
- **sol** — FAIL, blocking 25, 29854 bytes, complete=True

## Verdict text (verbatim, per seat)

### deepseek

```
I've read the brief, OUTLINE, MASTER-DOC-SCHEMA, all 13 chapters, the README, and the spine script; run the spine; and spot-verified the load-bearing claims against the actual code. Verdict follows.

VERDICT: FAIL

BLOCKING: 3
NON-BLOCKING: 6

FINDINGS:

1. kind UNBUILDABLE — M6 — claim: "The fill/render/panel pipeline is UNBUILDABLE against these M-numbered chapters" (M6 §1 Status, B13). Evidence: `master_doc_fill.py:422`, `gen_nasa_handbook.py:253-260` and `master_doc_check.py:188` all select `[0-9][0-9]-*.md`, which does not match `M0-shared-contract.md` … `M12-inference-proxy.md`. Verified against the sources. Fix: make the selection glob chapter-aware (accept `M[0-9]+-*.md` alongside `[0-9][0-9]-*.md`), or add a separate chapter-aware fill/render/panel path. Until then the handbook cannot be produced by its own toolchain, and this is the single most load-bearing blocker.

2. kind UNVERIFIED (NAME ONLY) — M9 — claim: "Auxiliary / routing / lifecycle flags … consequence is scoped, not expanded per row" (M9 §5, 32 of 57 flags). Evidence: `cmd/schedulerd/main.go` measured `grep -cE 'flag\.(String|Int|Int64|Bool|Duration|Float64)'` = 57 (verified); 25 flags carry default+range+consequence, 32 carry name+default only. Per rule 3 a name with no consequence counts as unwritten. Fix: fill default/range/consequence for the remaining 32 flags (the chapter itself names this a RED on the register, deepseek #2 / sol B19).

3. kind UNVERIFIED — M9 — claim: "the remaining 377 sites are uncovered and are the named RED on this field" (M9 §9). Evidence: `grep -rn "log.Printf" internal/scheduler/*.go | wc -l` = 379 (verified); only 2 sites are tabulated in §9. The schema §6 requires every operator-visible line, verbatim. Fix: complete the log-line inventory (or file a scoped board row and cite it as the standing exception).

NON-BLOCKING (honestly self-reported, not writing defects):

4. OMISSION (scope) — F-ROOT-1 — Parts I (beyond rendered sheets), II.6–II.16 (11 of 16 flows), and Parts V/VI/VII/VIII have no chapters. Stated explicitly in README ("This round's deliverable is Part III only") and filed. Non-blocking for the Part III deliverable, but it is the largest structural gap and is what makes "Can a task list be derived?" answer "Not yet" (Part VII unwritten).

5. RED Metrics × 11 modules — M0, M1, M2, M3, M4, M5, M6, M7, M8, M11, M12 all report Metrics "none" (absence-proved by repo-wide grep, quoted with command and 0-match output). This is a system observability defect (board rows filed), not a writing defect; per the round-2 B03 ruling it keeps those chapters PARTIAL, correctly.

6. Environmental UNVERIFIED — M1/M5/M7: certification ladder, conformance battery and token mint unrun because they require a live node or GitHub App creds absent on this host. Correctly labelled, not fabricated.

7. Boundary-contract UNVERIFIED — CT-01/05/07-18 (14 of 18) name the covered side and mark the far side rumour/missing/external. Correct per OUTLINE I.9; the spine treats these as complete.

8. Stale outline text — OUTLINE M9.S3 "26 tables" vs measured 30 (F9-2); OUTLINE Part IV "10 works / 6 broken / 2 missing" vs re-derived per-contract state. Both superseded in-chapter; outline-side, not chapter-side.

9. Minor README RED-column drift — README lists M2 RED "Metrics" but M2's own RED count is 2 (Metrics §8 + §7 ladder not repeatable); M3 README "S2 operator-invoked" vs M3's §1 repo_freshness body unread. Cosmetic; not a count claim the spine weighs.

DEFECT CLASSES: UNBUILDABLE (pipeline glob mismatch) · NAME-ONLY settings (M9 auxiliary flags) · RED fields (metrics-absent, unread bodies, unrun verification) · UNVERIFIED boundary contracts (external peers) · OMISSION (out-of-scope parts/flows). FALSE CLAIM: none found. CONTRADICTION: none (spine 0 findings; cross-chapter producer/consumer agreement holds). PADDING: none.

CHAPTER SCORECARD (all against code; every spot-checked claim verified true):
M0 PARTIAL — Metrics RED; otherwise complete and source-verified.
M1 PARTIAL — Metrics RED; four unit bodies unread line-by-line; certification ladder unrun.
M2 PARTIAL — Metrics RED; live bus-worker ladder not repeatable from this host.
M3 PARTIAL — Metrics RED; repo_freshness.py body unread.
M4 PARTIAL — Metrics RED; CT-13/CT-14 UNVERIFIED (external peers).
M5 PARTIAL — Metrics RED; foreign installer bodies unread; conformance unrun.
M6 PARTIAL — Metrics RED; own gate reads MASTER-DOC FAIL; pipeline UNBUILDABLE (blocking #1).
M7 PARTIAL — Metrics RED; mint UNVERIFIED; M7-C1 UNVERIFIED.
M8 PARTIAL — Metrics RED (sole RED; bodies read in full).
M9 PARTIAL — 5 RED fields; settings register and log inventory incomplete (blocking #2, #3).
M10 PARTIAL — 4 RED fields (handler body, per-metric contract, guard log surface, custody-proof).
M11 PARTIAL — Metrics RED; live-job tests are decoration (0 assert, verified).
M12 PARTIAL — Metrics RED; node-client half and stream completion UNVERIFIED.

Verification performed this round, all reproduced independently: spine (`chapters=13 canonical contracts=18 findings=0`, rc 0); CF-355 `dispatchReplyVerdict` reads only `payload["ok"]`, absence-of-verdict = success (dispatch_leg.go); node reply fields are `status/dispatch_id/corr_id/…` with no `run_id`/`outcome` (node-bus-worker.py:1176-1192); `dispatch_wall` accepts-then-`int()`-converts, no clamp (node-bus-worker.py:1200-1205); cf-inference-proxy.py = 273 lines, sinks `cf-inference-usage.jsonl`/`cf-inference-requests.jsonl`, `bytes | None` at :164, stream path emits headers with no framing; scheduler 30 tables / 43 routes / 57 flags / 379 log.Printf; crier 3 slog sites / 91 test files / 67 metric strings; dispatcher 25 `log(` lines / 0 assert in test_durable_job.py.

Net: this is the strongest round yet — zero false claims, zero contradictions, spine-clean, and every precise count I re-ran matched the chapter text. It fails on buildability and completeness, not on accuracy: no chapter is WRITTEN, M6's own toolchain cannot select these M-numbered chapters, and M9's settings/log registers are materially unfilled. Those three are the blocking remainder.

PANEL REVIEW COMPLETE

session_id: local-3a9bc7973d7a09ff269e02350e05006e3a4cbdeb2a18f2c8582b0e164921359e

EXIT=0
```

### glm

```
│ cache/scratch/judge_battery.py
│ @@ -0,0 +1,328 @@
│ +#!/usr/bin/env python3
│ +"""Quorum judge battery: verify chapter file:line claims against the code."""
│ +import re, subprocess, sys
│ +from pathlib import Path
│ +
│ +CF = Path("/home/kara/code-factory")
│ +SCH = Path("/home/kara/coding-hermes-scheduler/coding-hermes-scheduler")
│ +CR = Path("/home/kara/crier")
│ +FL = Path("/home/kara/crier-fleet")
│ +PRX = Path("/home/kara/.hermes/scripts/cf-inference-proxy.py")
│ +
│ +ROOTS = {"cf": CF, "sch": SCH, "cr": CR, "fl": FL}
│ +
│ +# (label, root, relpath, line, regex)  -> regex must match AT that line (1-indexed)
│ +CHECKS = [
│ +    # ---- M0 lib.sh ----
│ +    ("M0 lib.sh:5 say", "cf", "scripts/lib.sh", 5, r"say\(\)"),
│ +    ("M0 lib.sh:6 ok()", "cf", "scripts/lib.sh", 6, r"ok\(\)"),
│ +    ("M0 lib.sh:7 bad()", "cf", "scripts/lib.sh", 7, r"bad\(\)"),
│ +    ("M0 lib.sh:8 warn()", "cf", "scripts/lib.sh", 8, r"warn\(\)"),
│ +    ("M0 lib.sh:9 note()", "cf", "scripts/lib.sh", 9, r"note\(\)"),
│ +    ("M0 lib.sh:11 FAILED", "cf", "scripts/lib.sh", 11, r"FAILED"),
│ +    ("M0 lib.sh:13 have()", "cf", "scripts/lib.sh", 13, r"have\(\)"),
│ +    ("M0 lib.sh:19 fetch_verified", "cf", "scripts/lib.sh", 19, r"fetch_verified\(\)"),
│ +    ("M0 lib.sh:22 max-time 120", "cf", "scripts/lib.sh", 22, r"max-time\s+120"),
│ +    ("M0 lib.sh:26 digest mismatch", "cf", "scripts/lib.sh", 26, r"digest mismatch"),
│ +    ("M0 lib.sh:32 cannot create", "cf", "scripts/lib.sh", 32, r"cannot create destination"),
│ +    ("M0 lib.sh:37 cannot move", "cf", "scripts/lib.sh", 37, r"cannot move verified"),
│ +    ("M0 lib.sh:45 free_gb", "cf", "scripts/lib.sh", 45, r"free_gb\(\)"),
│ +    ("M0 lib.sh:48 require_disk", "cf", "scripts/lib.sh", 48, r"require_disk\(\)"),
│ +    ("M0 lib.sh:54 disk row", "cf", "scripts/lib.sh", 54, r"disk"),
│ +    ("M0 lib.sh:60 once()", "cf", "scripts/lib.sh", 60, r"once\(\)"),
│ +    ("M0 lib.sh:62 sentinel check", "cf", "scripts/lib.sh", 62, r"sentinel|if\s"),
│ +    ("M0 lib.sh:67 shq()", "cf", "scripts/lib.sh", 67, r"shq\(\)"),
│ +    ("M0 lib.sh:75 bunker_exec", "cf", "scripts/lib.sh", 75, r"bunker_exec\(\)"),
│ +    # ---- M1 ----
│ +    ("M1 prov:103 non-KV refused", "cf", "scripts/bunker-provision.sh", 103, r"."),
│ +    ("M1 prov:119 unknown key", "cf", "scripts/bunker-provision.sh", 119, r"unknown|KEY=VALUE|refus"),
│ +    ("M1 prov:147 node_env check", "cf", "scripts/bunker-provision.sh", 147, r"node_env"),
│ +    ("M1 prov:181 have bunker", "cf", "scripts/bunker-provision.sh", 181, r"have bunker"),
│ +    ("M1 prov:182 bunker_cli", "cf", "scripts/bunker-provision.sh", 182, r"bunker_cli"),
│ +    ("M1 prov:214 -s token", "cf", "scripts/bunker-provision.sh", 214, r"\-s .*github\.token"),
│ +    ("M1 prov:233 mode 600", "cf", "scripts/bunker-provision.sh", 233, r"mode 600"),
│ +    ("M1 prov:356 TTL 6h", "cf", "scripts/bunker-provision.sh", 356, r"TTL.*6h"),
│ +    ("M1 prov:426 node_env apply", "cf", "scripts/bunker-provision.sh", 426, r"node_env.*--apply|--apply.*node_env"),
│ +    ("M1 prov:454 node_seed build", "cf", "scripts/bunker-provision.sh", 454, r"node_seed.*build"),
│ +    ("M1 prov:483 gateway_auth", "cf", "scripts/bunker-provision.sh", 483, r"node_gateway_auth"),
│ +    ("M1 prov:518 node_identity", "cf", "scripts/bunker-provision.sh", 518, r"node_identity"),
│ +    ("M1 prov:550 destroy()", "cf", "scripts/bunker-provision.sh", 550, r"destroy\(\)"),
│ +    ("M1 prov:552 --yes refusal", "cf", "scripts/bunker-provision.sh", 552, r"destroy.*--yes|refusing"),
│ +    ("M1 prov:589 cli wins", "cf", "scripts/bunker-provision.sh", 589, r"command line always wins"),
│ +    ("M1 prov:601 comment five", "cf", "scripts/bunker-provision.sh", 601, r"five"),
│ +    ("M1 prov:604 six reapply", "cf", "scripts/bunker-provision.sh", 604, r"DUCKBRAIN_URL|GITHUB_TOKEN_FILE"),
│ +    ("M1 disk:36 ROLE_DEFAULTS", "cf", "scripts/disk_floor.py", 36, r"worker.*5|ROLE_DEFAULTS"),
│ +    ("M1 disk:37 DEFAULT_ROLE", "cf", "scripts/disk_floor.py", 37, r"DEFAULT_ROLE"),
│ +    ("M1 disk:123 raise", "cf", "scripts/disk_floor.py", 123, r"raise|unknown role|FloorError"),
│ +    ("M1 disk:141 role default", "cf", "scripts/disk_floor.py", 141, r"ROLE_DEFAULTS"),
│ +    ("M1 disk:169 exit 2", "cf", "scripts/disk_floor.py", 169, r"2"),
│ +    ("M1 seed:43 manifest", "cf", "scripts/node_seed.py", 43, r"DEFAULT_MANIFEST"),
│ +    ("M1 seed:44 budget 16MiB", "cf", "scripts/node_seed.py", 44, r"DEFAULT_BUDGET|16"),
│ +    ("M1 seed:164 seed_record", "cf", "scripts/node_seed.py", 164, r"seed_record"),
│ +    ("M1 seed:290 rmtree", "cf", "scripts/node_seed.py", 290, r"rmtree"),
│ +    ("M1 seed:377 budget default", "cf", "scripts/node_seed.py", 377, r"budget"),
│ +    ("M1 verify:53 RESULT: FAIL", "cf", "scripts/verify-node.sh", 53, r"RESULT: FAIL"),
│ +    ("M1 verify:150 checkout warn", "cf", "scripts/verify-node.sh", 150, r"warn"),
│ +    ("M1 verify:194 seed unverified", "cf", "scripts/verify-node.sh", 194, r"unverified"),
│ +    ("M1 verify:205 terminal forms", "cf", "scripts/verify-node.sh", 205, r"VERIFY"),
│ +    ("M1 pn:173 disk_floor", "cf", "scripts/project-node.sh", 173, r"disk_floor"),
│ +    ("M1 pn:212 reclaim", "cf", "scripts/project-node.sh", 212, r"reclaim_disk"),
│ +    ("M1 pn:440 computed installer", "cf", "scripts/project-node.sh", 440, r"install-\$HARNESS"),
│ +    ("M1 pn:449 invoke", "cf", "scripts/project-node.sh", 449, r"--apply|--check"),
│ +    ("M1 crier:598 HandleRegister", "cr", "internal/registry/handler.go", 598, r"HandleRegister\b|func.*HandleRegister"),
│ +    ("M1 crier:613 HandleRegisterByID", "cr", "internal/registry/handler.go", 613, r"HandleRegisterByID"),
│ +    # ---- M2 ----
│ +    ("M2 nbw:81 inbox 10", "cf", "scripts/node-bus-worker.py", 81, r"DEFAULT_INBOX_LIMIT\s*=\s*10"),
│ +    ("M2 nbw:82 lease 30", "cf", "scripts/node-bus-worker.py", 82, r"DEFAULT_LEASE_SECONDS\s*=\s*30"),
│ +    ("M2 nbw:85 seen 200", "cf", "scripts/node-bus-worker.py", 85, r"SEEN_LIMIT\s*=\s*200"),
│ +    ("M2 nbw:113 turns 40", "cf", "scripts/node-bus-worker.py", 113, r"CF_MAX_TURNS|40|1000"),
│ … omitted 250 diff line(s) across 1 additional file(s)/section(s)
│ cache/scratch/probe_sch.py
│ @@ -0,0 +1,13 @@
│ +from pathlib import Path
│ +SCH = Path("/home/kara/coding-hermes-scheduler/coding-herms-scheduler")
│ +print("exists:", SCH.exists())
│ +p = SCH / "internal/scheduler/dispatch_leg.go"
│ +print("file exists:", p.exists())
│ +try:
│ +    t = p.read_text(errors="replace")
│ +    lines = t.splitlines()
│ +    print("lines:", len(lines))
│ +    print("252:", lines[251][:90])
│ +    print("713:", lines[712][:90])
│ +except Exception as e:
│ +    print("EXC:", type(e).__name__, e)
│ .hermes/cache/scratch/judge_battery.py
│ @@ -4,7 +4,7 @@
│  from pathlib import Path
│
│  CF = Path("/home/kara/code-factory")
│ -SCH = Path("/home/kara/coding-hermes-scheduler/coding-hermes-scheduler")
│ +SCH = Path("/home/kara/coding-hermes-scheduler/coding-herms-scheduler")
│  CR = Path("/home/kara/crier")
│  FL = Path("/home/kara/crier-fleet")
│  PRX = Path("/home/kara/.hermes/scripts/cf-inference-proxy.py")
│ cache/scratch/judge_battery2.py
│ @@ -0,0 +1,110 @@
│ +#!/usr/bin/env python3
│ +"""Round 2: scheduler line checks (fixed path) + range claims for other chapters."""
│ +import re
│ +from pathlib import Path
│ +
│ +CF = Path("/home/kara/code-factory")
│ +SCH = Path("/home/kara/coding-hermes-scheduler/coding-herms-scheduler")
│ +CR = Path("/home/kara/crier")
│ +FL = Path("/home/kara/crier-fleet")
│ +ROOTS = {"cf": CF, "sch": SCH, "cr": CR, "fl": FL}
│ +
│ +# (label, root, relpath, line, regex)
│ +LINE = [
│ +    ("M9 dl:252 DISPATCH log", "sch", "internal/scheduler/dispatch_leg.go", 252, r"DISPATCH:"),
│ +    ("M9 dl:260 awaitDispatchReply", "sch", "internal/scheduler/dispatch_leg.go", 260, r"awaitDispatchReply"),
│ +    ("M9 dl:456 batch log", "sch", "internal/scheduler/dispatch_leg.go", 456, r"DISPATCH:"),
│ +    ("M9 dl:709 absence-success", "sch", "internal/scheduler/dispatch_leg.go", 709, r"absence|SUCCESS|success"),
│ +    ("M9 dl:713 dispatchReplyVerdict", "sch", "internal/scheduler/dispatch_leg.go", 713, r"func dispatchReplyVerdict"),
│ +    ("M9 dl:716 ok read", "sch", "internal/scheduler/dispatch_leg.go", 716, r"payload\[.ok.\]|ok"),
│ +    ("M9 bus:202 payload", "sch", "internal/bus/dispatch.go", 202, r"payload|text_b64"),
│ +    ("M9 am:98 admissionModeFor", "sch", "internal/scheduler/admission_mode.go", 98, r"func admissionModeFor\b|func admissionModeFor\("),
│ +    ("M9 am:112 forProject", "sch", "internal/scheduler/admission_mode.go", 112, r"admissionModeForProject"),
│ +    ("M9 am:143 laneOwnsBoard", "sch", "internal/scheduler/admission_mode.go", 143, r"laneOwnsBoard"),
│ +    ("M9 am:177 boardOwnedByLane", "sch", "internal/scheduler/admission_mode.go", 177, r"func boardOwnedByLane"),
│ +    ("M9 am:230 tasksAdmissionDue", "sch", "internal/scheduler/admission_mode.go", 230, r"func tasksAdmissionDue"),
│ +    ("M9 am:234 calls boardOwnedByLane", "sch", "internal/scheduler/admission_mode.go", 234, r"boardOwnedByLane"),
│ +    ("M9 am:266 lastTickFailed", "sch", "internal/scheduler/admission_mode.go", 266, r"lastTickStatusFailed"),
│ +    ("M9 up:21 reserveUsagePools", "sch", "internal/scheduler/usage_pool_policy.go", 21, r"reserveUsagePools"),
│ +    ("M9 tp:40 evaluate", "sch", "internal/scheduler/tick_process.go", 40, r"evaluate"),
│ +    ("M9 ps:19 Pack", "sch", "internal/scheduler/packer_select.go", 19, r"Pack"),
│ +    ("M9 na:131 Allocate", "sch", "internal/scheduler/namespace_alloc.go", 131, r"Allocate"),
│ +    ("M9 main:95 db flag", "sch", "cmd/schedulerd/main.go", 95, r"flag\.String\(\"db\""),
│ +    ("M9 main:96 listen", "sch", "cmd/schedulerd/main.go", 96, r"127\.0\.0\.1:9090"),
│ +    ("M9 main:108 min-interval", "sch", "cmd/schedulerd/main.go", 108, r"min-interval"),
│ +    ("M9 main:112 max-concurrent", "sch", "cmd/schedulerd/main.go", 112, r"max-concurrent"),
│ +    ("M9 main:113 namespace-mode", "sch", "cmd/schedulerd/main.go", 113, r"namespace-mode"),
│ +    ("M9 main:114 tick-timeout", "sch", "cmd/schedulerd/main.go", 114, r"tick-timeout"),
│ +    ("M9 main:122 api-read-timeout", "sch", "cmd/schedulerd/main.go", 122, r"api-read-timeout"),
│ +    ("M9 main:128 gw-response-timeout", "sch", "cmd/schedulerd/main.go", 128, r"gateway-response-timeout"),
│ +    ("M9 main:142 slot-patience", "sch", "cmd/schedulerd/main.go", 142, r"slot-patience"),
│ +    ("M9 main:144 load-gate", "sch", "cmd/schedulerd/main.go", 144, r"load-gate"),
│ +    ("M9 main:150 stasis", "sch", "cmd/schedulerd/main.go", 150, r"board-stasis"),
│ +    ("M9 main:190 no-exec-fallback", "sch", "cmd/schedulerd/main.go", 190, r"no-exec-fallback"),
│ +    ("M9 auth:187 extract", "sch", "internal/api/auth.go", 187, r"extractBearerOrHeaderToken"),
│ +    ("M9 met:42 window 24h", "sch", "internal/api/server_metrics.go", 42, r"24"),
│ +    ("M9 met:125 sources", "sch", "internal/api/server_metrics.go", 125, r"metricsSources"),
│ +    ("M9 met:195 metricsSpawns", "sch", "internal/api/server_metrics.go", 195, r"func metricsSpawns"),
│ +    ("M9 mig:1217 tick_dispatch", "sch", "internal/database/migrations.go", 1217, r"tick_dispatch"),
│ +    ("M9 mig:1391 execution_runs", "sch", "internal/database/migrations.go", 1391, r"execution_runs"),
│ +    ("M9 mig:1412 workspace_leases", "sch", "internal/database/migrations.go", 1412, r"workspace_leases"),
│ +    ("M9 mig:1427 execution_attempts", "sch", "internal/database/migrations.go", 1427, r"execution_attempts"),
│ +    ("M9 mig:1449 execution_events", "sch", "internal/database/migrations.go", 1449, r"execution_events"),
│ +    ("M9 mig:1460 verification_receipts", "sch", "internal/database/migrations.go", 1460, r"verification_receipts"),
│ +    ("M9 mig:1470 projections", "sch", "internal/database/migrations.go", 1470, r"execution_projections"),
│ +    ("M9 mig:1479 outbox", "sch", "internal/database/migrations.go", 1479, r"execution_outbox"),
│ +    ("M9 spawn:1244 buildForemanPrompt", "sch", "internal/scheduler/spawn.go", 1244, r"buildForemanPrompt"),
│ +    ("M9 alert:462 escalation", "sch", "internal/scheduler/alert_escalation.go", 462, r"."),
│ +    ("M1 crier:598 HandleRegister", "cr", "internal/registry/handler.go", 598, r"func.*HandleRegister\b|HandleRegister\("),
│ +]
│ +
│ +# (label, root, relpath, lo, hi, regex) — regex must appear SOMEWHERE in [lo,hi]
│ +RANGE = [
│ +    ("M1 disk exit2", "cf", "scripts/disk_floor.py", 168, 172, r"2\b|exit"),
│ +    ("M1 seed budget default", "cf", "scripts/node_seed.py", 374, 380, r"budget"),
│ +    ("M1 verify seed unverified", "cf", "scripts/verify-node.sh", 193, 199, r"unverified"),
│ +    ("M1 verify terminal forms", "cf", "scripts/verify-node.sh", 205, 214, r"VERIFY: (PASS|FAIL|UNVERIFIED)"),
│ +    ("M1 pn invoke", "cf", "scripts/project-node.sh", 449, 452, r"inst"),
│ +    ("M2 nbw key binding", "cf", "scripts/node-bus-worker.py", 381, 388, r"key_path|bus_path"),
│ +    ("M2 nbw identity bad", "cf", "scripts/node-bus-worker.py", 600, 610, r"identity"),
│ +    ("M2 nbw brief digest", "cf", "scripts/node-bus-worker.py", 1000, 1006, r"digest"),
│ +    ("M2 nbw reply fields", "cf", "scripts/node-bus-worker.py", 1176, 1192, r"dispatch_id|corr_id|status"),
│ +    ("M2 crier max cap", "cr", "internal/registry/handler.go", 1718, 1731, r"max must be <= 100"),
│ +    ("M3 ig venv hook", "cf", "scripts/install-gitreins.sh", 124, 138, r"gitreins-venv|\$VENV"),
│ +    ("M3 clone main", "cf", "scripts/clone_lane.py", 126, 130, r"main\("),
│ +    ("M7 tok key mode", "cf", "scripts/github-app-token.py", 344, 352, r"0600"),
│ +    ("M7 ref store exists", "cf", "scripts/github-app-refresh.sh", 125, 133, r"git-credentials|-e \"|exists"),
│ +    ("M8 rd AGED_PARENTS", "cf", "scripts/reclaim_disk.py", 19, 23, r"AGED_PARENTS"),
│ +    ("M8 rd PROTECTED", "cf", "scripts/reclaim_disk.py", 19, 24, r"PROTECTED"),
│ … omitted 32 diff line(s) across 1 additional file(s)/section(s)
All verification complete. The evidence base: 253 file:line claims mechanically checked against the five code bases (3 locator defects found), all 20 line-count claims exact, and every repeatable command the chapters claim to have run was re-run this round and reproduced (greps, board census/validate/drift, master_doc_check, four unit-test suites, verify-patch, scheduler flag/route/log counts, scheduler.db table census, both Go builds, crier slog/test/metric counts, dispatcher log census, proxy sha256 + live 401 + systemd state, board-row statuses, both CF-354 commits). Spine run: findings=0.

VERDICT: FAIL

BLOCKING: 4 — findings that must be fixed before this chapter set can be called written

NON-BLOCKING: 5

FINDINGS:

1. kind CONTRADICTION — chapter M9 (§6 CT-06) vs M11 (§6 CT-06), with M2/M10/README as third parties.
   Claim quoted: M9: CT-06 state "**broken** — CF-355: the node sends `status`, the scheduler reads `ok`". M11, same canonical id: CT-06 state "**works** — the dispatcher always sends `ok` (`:501`) ... CF-355 (status-vs-ok) belongs to the **node worker** (CT-04), not this producer". M2 §6 CT-04 and M10 §6 CT-04 both say CF-355 "is downstream at CT-06"; README Part IV says "CF-355 ... is carried at CT-06".
   Evidence: the two rows themselves (M9-scheduler.md §6, M11-dispatcher.md §6). Both cite the same producer (`dispatcher.py:500-508`) and consumer (`dispatch_leg.go:713`), which is why the spine reports 0 — it compares function tokens, never state words. Code read this round confirms the substance of both sides (`dispatcher.py:501` sends `ok`; `dispatch_leg.go:716` reads only `payload["ok"]`; `node-bus-worker.py:1180` sends `status`), so the defect is in the register, not the facts.
   Fix: give CT-06 one scope and one state. Either CT-06 = the dispatcher completion bridge (works; producer `dispatcher.py:500-508`) and CF-355 lives on the node reply path (CT-04→settlement, consumer `dispatchReplyVerdict`), or CT-06 = every completion into the scheduler inbox (broken, because node replies score success-on-failure). Make M9, M11, M2, M10 and the README say the same words for the same id.

2. kind FALSE CLAIM (evidence locator) — chapter M2 (§9 log row; §11 first bullet).
   Claim quoted: "`FAIL brief_digest — {label} brief.digest {expected[:16]}… != sha256(text) … refused, not run` (`node-bus-worker.py:1002-1005`)"; "refuses a dispatch without a `text` directive (`:987`) and a `brief.digest` mismatch (`:997-1012`)".
   Evidence: measured — `node-bus-worker.py:1002-1005` is `directive_text`'s legacy-member fallback; the no-text refusal is at `:1036-1042`, the digest gate at `:1044-1052` (the quoted log text is emitted at `:1050-1052`). Lines 987/997 sit inside the `directive_text` docstring and decoder.
   Fix: re-pin the three locators to `:1036-1042` (no-text refusal) and `:1044-1052` (brief.digest gate, emission `:1050-1052`). The quoted strings are real; only the pins are wrong.

3. kind FALSE CLAIM (quoted command output not reproducible) — chapter M3 (§2, §13, S2 row).
   Claim quoted: "`grep -rn 'land-node-branch' scripts/ tests/` matches only the script itself and `tests/selftest.sh:2465,2473,2502`".
   Evidence: re-run this round — selftest matches are at 2463, 2469, 2470, 2471, 2477, 2506, 2729; none of 2465/2473/2502 contains the string (2465 is the arm's `say` banner). The "no in-repo invoker" conclusion is correct (verified: only the script's own lines 2/4/120 plus the selftest arm), but the quoted grep result is not what the command returns.
   Fix: quote the real match lines (the arm bounds `:2463-2729` are already correct in §7).

4. kind CONTRADICTION (board copies; must be reconciled before merge) — chapter M4 (§1, §7, F4-4).
   Claim quoted: "`board_drift` `RESULT: DRIFT (4 failed)` with 1 divergent id (CF-270) ... workdir=`pending`, published=`complete`; HEAD=`47d68b4` vs `origin/main=4dc0ef0`".
   Evidence: re-measured this round, identical: `RESULT: DRIFT (4 failed)`; `jq` on the worktree gives CF-270 `pending`, `git show origin/main:...tasks.jsonl` gives CF-270 `complete`. The chapter reports it honestly and itself demands reconciliation before the merge that carries it — but an unreconciled board is exactly the sibling-reversion hazard M4 §10 names, and merging this round would carry the stale `pending` copy.
   Fix: reconcile CF-270 (re-sync the worktree board or accept the split as a live row with a recorded decision), then re-run `board_drift` and re-stamp M4 §7. A finding, not a PASS — as the chapter says.

Non-blocking findings:

5. kind FALSE CLAIM (off-by-one locator) — chapter M8 §5: "`AGED_PARENTS` (`:20`)", "`PROTECTED` (`:21`)". Measured: AGED_PARENTS at `reclaim_disk.py:21`, PROTECTED at `:22` (umbrella range `:14-22` is correct). Fix: shift both pins one line.

6. kind CONTRADICTION (internal, minor) — chapter M2 §6 CT-03 says CF-354 "fixed and closed (commit `1f1c0fe` ... board `complete`)"; M2 F2-5 says "closed in commit `6184e52`". Measured: `1f1c0fe` is the fix, `6184e52` is the board close (git log). Fix: §6 should credit the close to 6184e52 as F2-5 does.

7. kind FALSE CLAIM (grep exhaustiveness, substance intact) — chapter M4 §6 CT-14: "`grep -rn boardctl scripts/` matches only `board_lock.py:98/:100` ... and `gen_unit_map.py:45`". Measured: also matches `scripts/boardctl:2,9` (the wrapper itself) and `handbook_spine.py:58,71-75` (comments). No producer invoking `boardctl create` exists (verified), so the conclusion stands; the quoted exhaustive result does not. Fix: re-quote or scope the claim to non-self invocations.

8. kind CONTRADICTION (range drift, immaterial) — M4 §12 cites the admission decision at `admission_mode.go:230-242`; M9 §3 says `:230-243`. Measured: `func tasksAdmissionDue` at `:230`; one-line tail difference only.

9. UNVERIFIED TOOL CLAIM (spine blind spot, not a chapter) — the brief mandates treating `handbook_spine.py` findings as blocking; it reports `findings=0`, but finding 1 above (state-word disagreement on CT-06) is a defect class the spine cannot see: `has_fq`/`func_tokens` never compare the state column. Fix: extend the spine to compare state words for internal contracts (CT-02/03/04/06) across chapters, the same way it compares function tokens.

DEFECT CLASSES: STATE-WORD DISAGREEMENT ON A CANONICAL ID (spine-blind) · FALSE LOCATOR (evidence pin drift after file growth) · QUOTED GREP OUTPUT NOT REPRODUCIBLE · BOARD COPY DIVERGENCE (workdir vs published) · OFF-BY-ONE CONSTANT PINS · INTERNAL COMMIT-ATTRIBUTION DRIFT

CHAPTER SCORECARD:
- M0 shared-contract — PARTIAL: every helper pin verified (78 lines, 11/17 source greps reproduced, fails-closed probe repeatable from the chapter's own listing); Metrics RED (absence-proved).
- M1 provisioning — PARTIAL: all checked pins true (token "mode 600" lie F1-1, TTL fallback, destroy gate, floor precedence, seed state machine, ladder asymmetry F1-5 all confirmed at cited lines); four unit bodies settings-surface-only and the ladder not run on a live node — named RED.
- M2 dispatch — PARTIAL: contracts and settlement ordering verified (CT-03/04 rows match the code; same-batch duplicate and dispatch_wall analysis confirmed); fails on the brief-digest locator set (finding 2) and metrics RED.
- M3 repository — PARTIAL: landing arm exists at `selftest.sh:2463-2729` exactly, gate-empty-by-default and no-invoker conclusions verified; the quoted grep lines are false (finding 3); `repo_freshness.py` body unread.
- M4 board — PARTIAL: 357/518, validate OK (7 warnings), lock classifier lines all verified; drift unresolved (finding 4), CT-13/14 honestly UNVERIFIED.
- M5 harness — PARTIAL: adapter-capability matrix verified per line (conditional `:47`, TIMEOUT_S 300, lib.sh-vs-harness-vars split, computed installer dispatch at project-node.sh:440/449-452); 28-test count reproduced; conformance battery not run.
- M6 documentation — PARTIAL: the UNBUILDABLE finding (B13: `[0-9][0-9]-*.md` glob cannot select `M*.md`) re-confirmed at `master_doc_check.py:188`, `gen_nasa_handbook.py:18,253-259`, `master_doc_fill.py:26,422`; own gate FAIL 44/37/50 reproduced exactly.
- M7 github — PARTIAL: all settings pins verified (MIN_AGE 2400, mode-600-before-store-rewrite, JWT windows); mint never run on this host — honestly UNVERIFIED.
- M8 safety — PARTIAL: cleanest chapter; both files read in full, 9 tests pass, 15 scan claims reproduced; only the two off-by-one constant pins (finding 5).
- M9 scheduler — PARTIAL: every count reproduced exactly (57 flags, 43 routes, 379 log.Printf sites, 10 LoadRootConfig sites at the exact cited lines, 30 tables/no verdicts, build PASS); S1 grep-level, 32-of-57 flags consequence-scoped, 2-of-379 log sites — all named RED, not hidden.
- M10 crier — PARTIAL: 3/3 slog sites, 91 test files, 67 metric strings, port/guard/policy pins all reproduced; 1895-line handler body and per-metric register RED.
- M11 dispatcher — PARTIAL: 538 lines, 25 log( lines, every settings pin verified; F11-8 kill-guarantee withdrawal is well-evidenced; live-job tests are decoration that cannot fail — named RED.
- M12 inference proxy — PARTIAL: sha256 matches the stamped digest, live 401 reproduced, service active (PID 2603939) confirmed, sink-path correction verified at `:50/:52`; node-client half and stream completion UNVERIFIED — named RED.

Basis, stated per the brief's repeatability rule: every verification command named above was run by this seat this round; the one claim I could not repeat is the same one M2 §7 already marks not-repeatable-from-this-host (the cf-node bus-worker ladder, FACT-04). No claim was graded on the outline's language or on a previous seat's word.

PANEL REVIEW COMPLETE

session_id: local-685d712001f59163fbf01fc1e8216ed94ddb9f27a2b12badae5f347fa22b13a2

EXIT=0
```

### grok

```
⚠️  Primary auth failed — switching to fallback: fireworks / accounts/fireworks/models/deepseek-v4p1-flash-1017
│ cache/scratch/mutate.py
│ @@ -0,0 +1,34 @@
│ +#!/usr/bin/env python3
│ +"""Mutate a copy of the handbook with five defects the spine claims to catch."""
│ +import pathlib
│ +import sys
│ +
│ +hb = pathlib.Path(sys.argv[1])
│ +
│ +def edit(name, old, new, must=1):
│ +    p = hb / "chapters" / name
│ +    t = p.read_text()
│ +    n = t.count(old)
│ +    if n != must:
│ +        print(f"MUTATION-FAILED {name}: found {n} of {old!r}")
│ +        return False
│ +    p.write_text(t.replace(old, new))
│ +    print(f"mutated {name}: {old!r} -> {new!r}")
│ +    return True
│ +
│ +# 1. setting conflict: M2 says 40, M5 says 40; make M2 say 41
│ +edit("M2-dispatch.md", "| `CF_MAX_TURNS` | 40 (`:113`) | 1..1000 (`:113`) |",
│ +     "| `CF_MAX_TURNS` | 41 (`:113`) | 1..1000 (`:113`) |")
│ +# 2. dangling module reference
│ +edit("M8-safety.md", "## 12. Cross-references\n",
│ +     "## 12. Cross-references\n\nSee M99 for the missing chapter.\n")
│ +# 3. count claim that disagrees with the document
│ +edit("M7-github.md", "## 12. Cross-references\n",
│ +     "## 12. Cross-references\n\nThis document contains 12 modules in total.\n")
│ +# 4. internal contract pair disagreement: M2 CT-03 producer renamed
│ +edit("M2-dispatch.md", "crier `internal/registry/handler.go:1690` `HandleRetrieve`",
│ +     "crier `internal/registry/handler.go:1690` `HandleFrobnicate`")
│ +# 5. state contradiction on one canonical id, both directions of a pair named identically
│ +edit("M11-dispatcher.md", "| **works** — the dispatcher always sends `ok` (`:501`)",
│ +     "| **missing** — the dispatcher never sends `ok` (`:501`)")
│ +print("done")
All 13 chapters read; claims verified against code at the stamped revisions; the spine exercised with a mutation probe. Verdict below.

```
VERDICT: FAIL
BLOCKING: 8
NON-BLOCKING: 6
```

FINDINGS

B1 — CONTRADICTION — M9 §6 vs M11 §6 (CT-06), and OUTLINE Part IV says a third thing.
  Claim (M9:200): "| CT-06 | crier | in | `dispatcher.py:500-508` builds the completion reply `{in_reply_to, agent, ok, …}` … | **broken** — CF-355: the node sends `status`, the scheduler reads `ok` |"
  Claim (M11:94): "| CT-06 | scheduler | out | `dispatcher.py:500-508` … | **works** — the dispatcher always sends `ok` (`:501`) … CF-355 belongs to the **node worker** (CT-04), not this producer |"
  Claim (OUTLINE:211): "crier → scheduler — completion event for a finished run · **missing**"
  Evidence: one canonical id, three states. The M9 row is internally incoherent before any comparison — its producer cell names the dispatcher, its state explanation names the node. Measured: `dispatcher.py:501` `"in_reply_to": mid, "agent": agent, "ok": ok,` (dispatcher always sends ok → M11 correct); `node-bus-worker.py:1180` `"status": "failed" if failed_status else "completed"` (node never sends ok); `internal/scheduler/dispatch_leg.go:713-726` reads only `payload["ok"]` and returns true when absent (`:709-712`). There are two real edges under one id: dispatcher→scheduler (works) and node→scheduler (broken).
  Fix: split CT-06 into the two producer edges (or add a producer qualifier to the id), state each verdict once from its own measured producer, and make OUTLINE Part IV agree.

B2 — CONTRADICTION — `scripts/handbook_spine.py` returns findings=0 while B1 is live; the gate was relaxed 18→4 in the working tree.
  Claim (brief-mandated command): "chapters=13  canonical contracts=18 / findings=0 / RC=0" (reproduced this round).
  Evidence: mutation probe on a scratch copy of the handbook shows the four implemented checks do fire — one injected default conflict, one dangling `M99`, one "12 modules" claim and one renamed producer produced `findings=4` (CONTRACT PAIR DISAGREEMENT / SETTING CONFLICT / DANGLING REFERENCE / COUNT CLAIM), rc=1. Flipping M11's CT-06 state `works`→`missing` produced **no finding**: the spine has no state clause at all. And `git diff HEAD -- scripts/handbook_spine.py` adds the `BOUNDARY` set (CT-01, CT-05, CT-07…CT-18) plus `func_tokens` to the working tree, uncommitted: the committed gate at 47d68b4 demanded both sides for all 18, this round's verdict rests on an uncommitted exemption of 14.
  Fix: add a state-agreement check (one CT id → one state word, or an explicit per-row producer qualifier); commit the gate change as part of the round rather than beneath it.

B3 — FALSE CLAIM — M9 §6 exempts CT-05 as an LLM-lane boundary while its own row names both ends in covered code.
  Claim (spine BOUNDARY:67): "CT-05 … the foreman is an LLM lane; its prompt text only".
  Claim (M9:201): producer "`scripts/load_lane_config.py:31-37` (reads `prompts/*.md` → `UPDATE projects SET prompt=?, prompt_mode='append'`)", consumer "`internal/scheduler/spawn.go:1244` `buildForemanPrompt`".
  Evidence: both exist and are in the five covered systems — `load_lane_config.py:31-37` reads `prompts/<name>.md` and writes `projects.prompt`; `spawn.go:1244` `func buildForemanPrompt(project PackedProject, tickID string) string`. CT-05 is internal. It is also the one contract the document calls broken (OUTLINE VIII.1, M9:201) and its evidence, "3 of 11 prompt files disagree", is measured nowhere: `ls prompts/` = 11 files, but no chapter names the three, quotes the disagreement, or gives the command that shows it.
  Fix: move CT-05 to internal; name the three disagreeing prompt files with the command that exposes the disagreement, or downgrade the state to UNVERIFIED and say the count is unmeasured.

B4 — FALSE CLAIM — OUTLINE Part IV prints a current-state sentence the delivered chapters refute.
  Claim (OUTLINE:204): "Current: **0 of 18** name both implementations."
  Claim (OUTLINE:207): "scheduler → crier … **broken**"; (OUTLINE:211): "crier → scheduler … **missing**".
  Evidence: README:164 states "4 of 18 internal contracts name both `file:function`", and the rows do: M2 CT-03 (`handler.go:1690` HandleRetrieve ↔ `node-bus-worker.py:1007` process), M2 CT-04 (`node-bus-worker.py:1208` deliver ↔ `handler.go:990` HandleDeliver), M9/M10 CT-02 (`dispatch.go:202` payload ↔ `handler.go:990`), M11 CT-03/CT-06. CT-02 is reported "works" by both M9:199 and M10:128 while the outline says "broken"; the chapters assert supersession (M10:128) instead of the register being corrected.
  Fix: re-derive Part IV and I.5 from the chapters, or delete the word "Current:" and mark the register as pre-round structure text — a register the chapters call stale three separate times is not a register.

B5 — OMISSION — M6 DOCUMENTATION omits the documentation gate it exists to describe.
  Claim (M6:8, §3, §5, §7): the module's unit list is `master_doc_skeleton.py`, `master_doc_fill.py`, `master_doc_check.py`, `master_doc_panel.py`, `gen_nasa_handbook.py`, `gen_system_views.py`, `sheet_style.py`, `extract_owner_decisions.py`, `gen_unit_map.py`, `verify-patch.sh`, `panel_loop.py`, `ownership.py`.
  Evidence: `scripts/handbook_spine.py` is committed at the exact revision every chapter stamps (47d68b4, "handbook: the spine — alignment becomes a check, not a memory"), is named in README:115 as the enforcement of the contract rule, and is the command the panel brief makes mandatory. `grep -rn 'handbook_spine' docs/handbook/chapters/` → 0 matches. M6's own finding F6-1 says the legacy gate cannot select these chapters; the tool that can is undocumented, so §3 inventory, §5 settings, §7 verification and §10 failure modes all lack their real gate.
  Fix: add M6.S9 with its four checks, the BOUNDARY policy and the state blind spot (B2), or M6's account of "what makes this document checkable" is materially wrong.

B6 — UNVERIFIED — M2 cites four locators that do not contain the claim they support.
  Claims: "a `brief.digest` mismatch (`:997-1012`)" (§11); "(`node-bus-worker.py:1002-1005`)" (§9, `FAIL brief_digest` row); "`:603` `bad("identity", f"{ident.error}; refusing`)" (§4a); "`node-bus-worker.py:381-382` binds `key_path`/`bus_path`" (§4a).
  Evidence (measured at 47d68b4): the digest check is `node-bus-worker.py:1044-1060`, emitter `:1049-1053`; `:997-1012` is the tail of `directive_text` and the head of `process`; the identity refusal is `:608`; `:381` is `class Identity:`, the bindings are `:386` `bus_path` and `:387` `key_path`. The surrounding prose is correct in every case — only the pointers are wrong, which is worse than no pointer because it reads as evidence.
  Fix: re-point all four; add a mechanical locator check to the spine (open the cited file, assert the cited line is within it and non-blank).

B7 — FALSE CLAIM — M2 §9 misdescribes the mechanism of the module's entire observable surface.
  Claim (M2:116-117): "The worker prints via `lib.sh` helpers plus three local aliases (`node-bus-worker.py:124-137`: `PASS`/`FAIL`/`WARN`/`..`)."
  Evidence: `node-bus-worker.py` is Python and cannot source `lib.sh`; it re-implements the row vocabulary at `:129-138` (`def ok`, `def bad`, `def warn`, printing `  PASS  {name} — {value}`). The format is a copy of lib.sh's, not a call into it — and a copy can drift (which is the reason M0's F0-4 matters).
  Fix: state that the worker re-implements lib.sh's row vocabulary locally at :129-138, and that the two formats are only convention-identical.

B8 — FALSE CLAIM — two quoted "evidence" greps whose output does not reproduce.
  Claim (M4:92): "`grep -rn boardctl scripts/` matches only `board_lock.py:98/:100` (a grep over the wrapper) and `gen_unit_map.py:45`".
  Claim (M1:39): "`grep -rn 'bunker-provision' scripts/` matches only `bunker_config_gen.py` docstrings".
  Evidence: measured — the boardctl grep also matches `scripts/boardctl:2,9` (the wrapper itself), `board_lock.py:18`, `handbook_spine.py:58,71,74,75`; the bunker-provision grep also matches `scripts/bunker-provision.sh:2,5,6,7,178`. The conclusion in both rows (no in-repo invoker) survives; the quoted output does not.
  Fix: quote the real output and read it, or add `--exclude`/`-l` so the quoted result matches what the command prints.

NON-BLOCKING

N1 — CONTRADICTION — M3 gives two ranges for one selftest arm: §7 table "(`:2463-2729`)"; §7 B07 paragraph "`tests/selftest.sh:2459-2709` (arm `cf213-land-node-branch`, `:2463-2729`)". Measured: `# BEGIN cf213-land-node-branch` at 2463, `# END` at 2729. Delete 2459-2709.

N2 — CONTRADICTION — M2 gives two "closed in" commits for CF-354: §6 "closed in commit `1f1c0fe`", §13 F2-5 "`complete` on the board (closed in commit `6184e52`)". Both exist (`1f1c0fe fix(node-bus-worker): decode … text_b64 (CF-354)`; `6184e52 board: close CF-354 with the tier-2 verdict as evidence`). The words "fixed in" vs "board-closed in" would remove it.

N3 — CONTRADICTION — M9 §1 status cites "the API route table (`internal/api/server.go:289-346`)" while §3 corrects it: "spans `:289-370`, not just `:289-346`". §1 still carries the superseded range.

N4 — UNBUILDABLE — the document's own acceptance rule makes WRITTEN unreachable for 11 of 13 chapters. README:70-71: "a chapter with a RED metrics field stays PARTIAL until the system emits metrics or an explicit schema exception is approved"; 11 chapters prove Metrics = RED by absence. No writer can close them: the remaining work is to build metrics or to grant an exception, and neither is scheduled anywhere in the document. Fix: file the exception decision as one owner ask, or state that PARTIAL-by-metrics is terminal for this issue.

N5 — PADDING — round-history inside chapters. M0:115-116 ("The round-3 draft's literal source-count commands were over-escaped … (sol B05)"), M3:114 ("Round-6 said 'none is shipped' — false"), M9:182-189, M10:146-149. Outline Part III heading 13 asks for evidence of record (board rows, verdicts, run ids), and Appendix D is reserved for "change log and supersession record" — which does not exist. Roughly 10-20% of several chapters is the document narrating its own review; it is traceable but not actionable for a reader trying to operate the system. Fix: move round-N history to Appendix D, leave the row and the board id.

N6 — OMISSION (declared) — README:52-56 states the deliverable is Part III only; Parts I (beyond rendered sheets), II.6-II.10, IV as a re-derived register, V-VIII have no chapters, and 11 of the 16 flows (F6-F16) have no written flow chapter. Declared as F-ROOT-1, so not concealed — but the brief grades against an outline that commits to 8 parts and 16 flows, and the document is 13 module chapters of that commitment.

DEFECT CLASSES

  state-register-drift (one contract id, three measured states)
  self-granted-exemption (gate relaxed 18→4, uncommitted)
  covered-implementation-labelled-external (CT-05)
  gate-cannot-see-its-own-subject (no state clause in the spine)
  locator-drift (four M2 pointers, one M5, one M9 range)
  quoted-command-not-reproduced (M1, M4 greps)
  mechanism-misdescription (lib.sh helpers in a Python module)
  intra-chapter inconsistency (M3 ranges, M2 commits, M9 route span)
  unsatisfiable-acceptance-rule (metrics RED blocks WRITTEN)
  stale-structure-text (OUTLINE Part IV vs delivered chapters)
  review-history-as-prose (round-N narration in chapters)
  declared-scope-gap (Parts I/II/IV-VIII, 11 of 16 flows)

CHAPTER SCORECARD

  M0-shared-contract.md    PARTIAL — every helper, line and count independently reproduced (78 lines; :5-9, :19-42, :48-57, :60-64, :67-70, :75-78; 11/17 sourcing greps exact); only RED is Metrics. Would be WRITTEN but for N4.
  M1-provisioning.md       PARTIAL — F1-1 (`:214` `[ -s ]` vs `:233` "mode 600") and F1-5 (checkout WARN at `:150` without `unverified()`, seed WARN calls it at `:198`) both verified exactly; floor precedence `:126-141` exact. Blocked by B8 (quoted grep) and unread `node_env`/`node_seed_drift`/`node_freshness`/`bunker_config_gen` bodies.
  M2-dispatch.md           PARTIAL — contract rows and CF-355 mechanism are right; blocked by B6 (four dead locators), B7 (lib.sh mechanism), N2 (two close commits).
  M3-repository.md         PARTIAL — landing script read correctly (`:38`, `:74-75`, `:202`, `:278-300`, `:304`), F3-2/F3-3/F3-5 right; blocked by N1 (two arm ranges) and `repo_freshness.py` body unread.
  M4-board.md              PARTIAL — store census (357/518), validate (OK, 7 warnings incl. the named CF-150/CF-192/CF-371 and event line 337) and drift (DRIFT 4 failed, CF-270, HEAD 47d68b4 vs origin/main 4dc0ef0) all reproduce; blocked by B8 (grep) and by its own unreconciled drift.
  M5-harness.md            PARTIAL — CFV_DECLARED 12 / CFV_REQUIRED 6, defaults 40/1800, ranges, `[0-7]00` predicate, the three `--apply` refusals and `project-node.sh:440` computed dispatch all verified; conformance battery not run. Minor locator slack (`:459-469` vs `harness_argv` at `:464`).
  M6-documentation.md      PARTIAL — gate internals exact (`:52`, `:188` `[0-9][0-9]-*.md`, `:191-209`, rc=1, "44 module(s): 37 VERIFIED, 50 error(s)") and the `docs/master` hardcodes confirmed (`gen_nasa:18,255`; `fill:422`; `panel:70`); blocked by B5 (omits `handbook_spine.py`).
  M7-github.md             PARTIAL — CLI exit 2, `:344-348` mode-0600 refusal, `:28` MIN_AGE, `:47/:652/:575` boundaries verified; the mint itself unrun, so M7-C1 stays UNVERIFIED.
  M8-safety.md             PARTIAL — 169/118 lines, TTL/AGED_PARENTS/PROTECTED constants, inclusive `<=` boundary, 9 reclaim tests, 15 scan-scope claims all reproduce. Only RED is Metrics (N4).
  M9-scheduler.md          PARTIAL — the strongest chapter: 43 routes, 57 flags, 379 `log.Printf`, 30 tables, 10 `LoadRootConfig` sites, admission locators `:98/:112/:143/:177/:230/:266`, `reserveUsagePools` semantics `:26-74`, `dispatch.go:202`/`:184`, `dispatch_leg.go:709-726` all exact; build + three env tests + `internal/scheduler` (174s) green. Blocked by B1 (CT-06) and N3.
  M10-crier.md             PARTIAL — 1895 handler lines, `:598/:613/:990/:1014/:1690/:1812`, slog exactly 3 sites at `:1332/:1795/:1885`, 91 test files, 67 metric strings, every `config.go` default `:622-654`, `metrics.go:2` "opt-in" contradiction, `:673` default-ON — all exact; build + `go test ./...` green (registry 7.85s). RED: per-metric contract, guard log surface.
  M11-dispatcher.md        PARTIAL — 538 lines, 25 `log(` lines, `:38-53` settings, `:500-508` body with `ok`, `:260`/`:291`/`:329` kill path, serial loop — all exact; the F11-8 descendant-kill withdrawal is honest and correct. RED: metrics, no-assert tests.
  M12-inference-proxy.md   PARTIAL — sha256 `b12a0ac5…` reproduced, 273 lines, `:43-62` settings, `:265-273` fail-closed, live 401 on `:8775`, unit active — all reproduced by me this round; streaming framing (F12-7) unproven.

  Totals: 0 WRITTEN, 13 PARTIAL, 0 SKELETON. Under the document's own rule (README:70-71) no chapter reaches WRITTEN while its Metrics field is RED, and 11 of 13 carry that RED.

What I could not repeat: the live-node legs (M1 `verify-node.sh`, M2/M10 `node-bus-worker.py --check` on cf-node, M5 conformance battery, M12 disallowed-model 403 with a real node token) — no node and no token file from this host. The M9 "25/25 packages" claim I confirmed for `internal/scheduler` (174.181s, green) and by `go build ./...`, not for all 25 in one run. The M4 board drift I reproduced exactly and it is still unreconciled.

The document is materially better than the state register it ships with. B1/B3/B4 are one defects: nobody re-derived the contract states, and the gate that should have caught it was made blind to states in an uncommitted edit. Fix that register and the gate, add the spine to M6, re-point M2's four locators, and this collection is close.

PANEL REVIEW COMPLETE

session_id: local-ca8b9d21445196413ead7d9d5cd8f84f0d227f44f344647f4fb1ef396857e7ce

EXIT=0
```

### kimi

```
Verification complete. Every load-bearing claim I re-ran reproduced; the full tally is below.

VERDICT: FAIL

BLOCKING: 5 — findings that must be fixed before this chapter can be called written

NON-BLOCKING: 7

FINDINGS:

B1 — CONTRADICTION · OUTLINE.md (document-level, the one undisclosed defect)
  Claim: "Current: **0 of 18** name both implementations" (OUTLINE.md:204) and "Contract register — 18 interfaces, measured state (10 works, 6 broken, 2 missing)" (OUTLINE.md:46).
  Evidence: chapters M2 §6, M9 §6 and M10 §6 now name both sides of CT-02, CT-03, CT-04 and CT-06 (`internal/bus/dispatch.go:202` ↔ `handler.go:990`; `handler.go:1690` ↔ `node-bus-worker.py:1007`; `node-bus-worker.py:1208` ↔ `handler.go:990`; `dispatcher.py:500-508` ↔ `dispatch_leg.go:713`), and CT-02/03/04 are marked works with CF-354 closed. The three per-row supersession parentheticals exist, but the two totals carry no supersession marker and are false against the chapters. `handbook_spine.py` (re-run by me: chapters=13, contracts=18, findings=0, rc=0) does not check these prose counts.
  Fix: re-count the register from the chapters and restamp OUTLINE.md:46 and :204, or mark them superseded the way the rows are.

B2 — UNVERIFIED (NAME ONLY) · M9 §5
  Claim: 32 of the 57 `schedulerd` flags are registered as "name = default" with no range and no consequence column.
  Evidence: measured this round — `grep -cE 'flag\.(String|Int|Int64|Bool|Duration|Float64)' cmd/schedulerd/main.go` = 57; the chapter's own aux-list (`main.go:102-200`) gives defaults only. By the outline's own decision rule (OUTLINE.md:118-120) a name with no consequence counts as unwritten. The chapter self-declares this RED (B19/sol) — confirmed, not discovered.
  Fix: expand default/range/governs/breakage per flag for the remaining 32.

B3 — UNVERIFIED · M9 §9
  Claim: log inventory covers 2 of 379 `log.Printf` sites.
  Evidence: measured this round — `grep -rn "log.Printf" internal/scheduler/*.go | wc -l` = 379. MASTER-DOC-SCHEMA §6 requires every operator-visible line. Self-declared RED (deepseek #1) — confirmed.
  Fix: tabulate or explicitly scope-limit the remaining 377 with a stated selection rule.

B4 — UNVERIFIED · M10 §8
  Claim: the per-metric type/labels/question/scrape contract is not filled; 67 unique `crier_*` strings inventoried by grep census only.
  Evidence: measured this round — `grep -rhoE 'crier_[a-z_]+' internal/ cmd/ --include='*.go' | sort -u | wc -l` = 67. Schema §5 requires per-metric Type/Labels/What-it-answers/Where-scraped. Self-declared RED (B21) — confirmed.
  Fix: fill the per-metric table for the runtime series (excluding the test-only `crier_test_*` family and exposition components, as the chapter itself scopes).

B5 — UNVERIFIED · M10 §9
  Claim: the handler's slog surface is complete (3/3 — verified: `grep -c 'slog.(Info|Error|Warn|Debug)' internal/registry/handler.go` = 3) but the guard's log surface (`guard.go:430-457`) is not tabulated, so the module-wide log inventory is incomplete.
  Evidence: code read confirms `guard`/`guard blocked` records at `internal/guard/guard.go:430-457` exist and are absent from the chapter's table. Self-declared RED (B22/sol) — confirmed.
  Fix: tabulate the guard's log records with kind classification.

N1 — stale revision stamp · M9 §1/§13. Chapter stamps `1771d3aa` "re-stamped this round"; live HEAD is `5444fa5b` (one commit later, 2026-11-06 19:35). Verified the delta is board-only (`.coding-hermes/board/{tasks,events}.jsonl`), so no code claim is invalidated. Re-stamp at merge.
N2 — M10 §5: the storage-selection register names controls and consequences, but the custody-proof procedure (how an operator proves which backend is serving) is not written. Named RED in the chapter; one verification command short of rule 4.
N3 — M10 §1: the 1895-line handler body is not read line-by-line (slog surface is complete, verified). Honestly UNVERIFIED status — recorded, not blocking.
N4 — M2 §7 / M10 §7: the cf-node live bus-worker ladder is not repeatable from this control host. Verified `~/node-bus-worker.py` does not exist here; the chapter says so itself. Compliant with rule 4.
N5 — M12 §7: the 403 disallowed-model row is carried from round-3 judge kimi, not re-run this round (disclosed). I re-verified the proxy side live: no-token POST → 401, systemd unit active since 2026-11-05 09:21, Main PID 2603939, content sha256 `b12a0ac5…` matches.
N6 — M4 §7: the duplicate-id refusal probe was not re-run by this judge (a write attempt against the live board; CF-357 confirmed present, so refusal is the only possible outcome; the quoted message vocabulary is consistent with this round's `boardctl validate` output).
N7 — quoted timings differ on re-run (crier internal/registry 6.962s → 8.322s; scheduler internal/scheduler 158.3s → 174.8s). Variance consistent with real, uncached runs; not a defect.

Verification performed by this judge (all reproduced as the chapters claim):
  handbook_spine.py → findings=0. M0: lib.sh 78 lines, source counts 11 and 17, `bash -n` clean. M1: F1-1 (`bunker-provision.sh:214` `-s` probe vs `:233` "mode 600" print), F1-2 (`disk_floor.py:123-125` + exit 2), F1-5 (verify-node.sh checkout leg warns without `unverified()` at ~:150 while the seed leg calls it at ~:194-198), `project-node.sh:173`/`:212` invocations. M2: `text_b64` decode `:989-999`, reply fields `:1176-1192` (no `run_id`/`outcome`), F2-2 PID-1755676 hardcode true, bus 100-cap at `handler.go:1727-1730`; test_lane_target (40), test_disk_floor, test_harness_resolve all OK. M3: GATE default empty `:38`/`:74-75`/`:108`, no numbered arms, cf213 arm at 2463-2729, no in-repo lander invoker. M4: 357 rows / 518 events, `RESULT: OK (7 warning(s))`, `RESULT: DRIFT (4 failed)` with 1 divergent id CF-270, `board_lock.py:149-158` three-outcome classifier, `boardctl --help:25` evidence requirement. M5: `project-node.sh:440`/`:449-452` computed installer dispatch, `harness-vars.sh:203` `[0-7]00` predicate, codex `:47` conditional source + 300s re-default, claude `:36` lib.sh source, deepseek/pi `--apply` refusals, no production caller for harness_resolve. M6: gate FAIL `44 module(s): 37 VERIFIED, 50 error(s)` exit 1, `[0-9][0-9]-*.md` globs at `master_doc_check.py:188`, `master_doc_fill.py:422`, `gen_nasa_handbook.py:18/:253-259` (pipeline genuinely cannot select M*.md), verify-patch PASS. M7: bare CLI exit 2. M8: constants `:14-22`, test_reclaim OK, scan-scope 15 claims RESULT: OK. M9: `go build ./...` PASS, 30 tables (no `verdicts`), 43 routes, 57 flags, 379 log sites, 10 LoadRootConfig sites, full `env -u SCHEDULER_OPERATOR_RESTART_APPROVED go test ./...` PASS (25 packages ok), `dispatchReplyVerdict` reads only `payload["ok"]` with absence-as-success at `:709-726`. M10: build + `go test ./...` PASS (91 registry test files), 3 slog sites, 67 metric strings, `metrics.go:2` "opt-in" comment vs `EnableMetrics: true` at `config.go:673`, port 8767 at `:622`. M11: 538 lines, 25 `log(` lines, 0 asserts in test_durable_job.py, F11-8 kill structure (`timeout … &` :260, `setsid` :291, `kill -TERM -$(cat pid)` :329). M12: sha256, 401, systemd, `_node` `:115-123`, `_forward` `:164` union annotation, fail-closed `:265-270`. Host go: `~/.local/bin/go` → sdk/go1.26.5 symlink confirmed (a bare `go version` inside the module dirs re-execs 1.26.6 via GOTOOLCHAIN=auto — the chapter's claim is accurate).

No FALSE CLAIM found in any chapter. No hidden OMISSION found: the open system defects the chapters carry (CF-355 silent success, F11-8 kill-group miss, F12-7 unframed stream, CF-270 board drift, the M6 glob mismatch) were each re-verified as true statements about the code. No PADDING found — every chapter's prose carries locators, measured values, or a named RED.

DEFECT CLASSES: stale-count-claim (OUTLINE totals vs chapters) · name-only-setting (M9 aux flags) · partial-log-inventory (M9 §9, M10 §9) · partial-metric-register (M10 §8) · stale-revision-stamp (M9, board-only) · external-peer-unverifiable (boundary contracts, honestly labelled) · live-fixture-unreachable (cf-node ladder, disclosed)

CHAPTER SCORECARD:
  M0  WRITTEN — every re-run claim reproduced; single RED (metrics, absence-proved) disclosed.
  M1  WRITTEN — both "what breaks if it lies" claims (F1-1, F1-5) verified true against the code; REDs disclosed.
  M2  WRITTEN — reply shape, digest refusal, PID hardcode and settlement ordering verified; non-repeatable cf-node leg disclosed.
  M3  WRITTEN — gate-by-default, named-arm correction and F3-5 invoker claim all reproduced.
  M4  WRITTEN — census, validate and DRIFT measurements reproduced exactly, including the CF-270 divergence carried as a live finding.
  M5  WRITTEN — computed-dispatch correction (F5-5), credential predicate and adapter matrix verified.
  M6  WRITTEN — own gate's FAIL reproduced (exit 1, 44/37/50); the pipeline's inability to select M*.md chapters verified and honestly carried as UNBUILDABLE against the current set.
  M7  WRITTEN — small module, CLI surface verified; mint UNVERIFIED disclosed (no App creds on host — same constraint this judge hit).
  M8  WRITTEN — both files' constants and tests reproduced.
  M9  PARTIAL — all structural claims (build, 30 tables, 43 routes, 57 flags, 379 log sites, clean-env test green) reproduced, but §5 is 25/57 written (B2) and §9 is 2/379 (B3); revision stamp one board-only commit stale.
  M10 PARTIAL — build/test/custody/guard-degradation claims reproduced, but §8 per-metric contract (B4) and §9 guard log surface (B5) are self-declared incomplete.
  M11 WRITTEN — full-body read claims verified, including the F11-8 kill-group analysis and the decoration-test finding.
  M12 WRITTEN — hash, live 401, systemd state and code-line claims reproduced; carried-over 403 row and stream-completion UNVERIFIED disclosed.

PANEL REVIEW COMPLETE

session_id: local-eff9f3cfb4e3e60f7ef6ed8db981eccf43e453d8ea11c2a5981cb895cfb38459

EXIT=0
```

### sol

```
│ cache/scratch/round9_judge_probes.py
│ @@ -0,0 +1,109 @@
│ +import ast
│ +import contextlib
│ +import importlib.util
│ +import io
│ +import json
│ +import os
│ +from pathlib import Path
│ +import re
│ +import subprocess
│ +import tempfile
│ +import threading
│ +import urllib.error
│ +import urllib.request
│ +import http.client
│ +from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
│ +
│ +ROOT = Path('/home/kara/code-factory')
│ +TMP = Path(tempfile.mkdtemp(prefix='round9-judge-', dir=os.environ['TMPDIR']))
│ +print('PROBE_ROOT=' + str(TMP))
│ +
│ +def load(name, path):
│ +    spec = importlib.util.spec_from_file_location(name, str(path))
│ +    mod = importlib.util.module_from_spec(spec)
│ +    spec.loader.exec_module(mod)
│ +    return mod
│ +
│ +# Source census, without executing installers.
│ +for label, pattern in [('DIRECT_SOURCES', r'\. "\$HERE/lib\.sh"'), ('ALL_SOURCES', r'\. "\$HERE/(\.\./)?lib\.sh"')]:
│ +    hits = [str(p.relative_to(ROOT)) for p in (ROOT/'scripts').rglob('*') if p.is_file() and re.search(pattern, p.read_text(errors='replace'))]
│ +    print(label + '=' + str(len(hits)))
│ +
│ +libprobe = subprocess.run(['bash','-c', '. "$1"; fetch_verified http://127.0.0.1:1/nothing "$2" wrong; rc=$?; printf "FETCH_RC=%s ARTIFACT=%s\\n" "$rc" "$([ -e "$2" ] && printf yes || printf no)"', 'probe', str(ROOT/'scripts/lib.sh'), str(TMP/'artifact')], capture_output=True, text=True)
│ +print(libprobe.stdout.strip())
│ +
│ +# Execute only the exact extracted landing arm in disposable local repositories.
│ +text = (ROOT/'tests/selftest.sh').read_text()
│ +arm = text.split('# BEGIN cf213-land-node-branch',1)[1].split('# END cf213-land-node-branch',1)[0]
│ +armfile = TMP/'landing-arm.sh'
│ +armfile.write_text('set -u\nHERE=/home/kara/code-factory\nfails=0\nsay() { printf "%s\\n" "$*"; }\n' + arm + '\nprintf "LANDING_ARM_FAILURES=%s\\n" "$fails"\nexit "$fails"\n')
│ +env = dict(os.environ, GIT_CONFIG_GLOBAL='/dev/null', GIT_CONFIG_NOSYSTEM='1')
│ +r = subprocess.run(['bash', str(armfile)], capture_output=True, text=True, env=env, timeout=100)
│ +(TMP/'landing-output.txt').write_text(r.stdout+r.stderr)
│ +print('LANDING_ARM_RC='+str(r.returncode))
│ +print('\n'.join(l for l in r.stdout.splitlines() if 'FAIL' in l or 'FAILURES' in l))
│ +
│ +# Actual lock classifier, isolated absent/residue/held fixtures.
│ +lockmod=load('round9_board_lock', ROOT/'scripts/board_lock.py')
│ +lock=TMP/'lock'
│ +print('LOCK_ABSENT='+lockmod.adjudicate(lock))
│ +lock.write_text('fixture')
│ +print('LOCK_RESIDUE='+lockmod.adjudicate(lock))
│ +p = subprocess.Popen(['python3','-c','import fcntl,sys; f=open(sys.argv[1]); fcntl.flock(f,fcntl.LOCK_EX); print("ready",flush=True); sys.stdin.read()',str(lock)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
│ +try:
│ +    assert p.stdout.readline().strip()=='ready'
│ +    print('LOCK_HELD='+lockmod.adjudicate(lock))
│ +finally:
│ +    p.stdin.close(); p.wait(timeout=5)
│ +
│ +# Dispatcher function and dead-setting census without importing credentials/scoper.
│ +pth=Path('/home/kara/crier-fleet/dispatcher.py')
│ +tree=ast.parse(pth.read_text())
│ +refs=[(n.lineno,type(n.ctx).__name__) for n in ast.walk(tree) if isinstance(n,ast.Name) and n.id=='EXEC_TIMEOUT']
│ +print('EXEC_TIMEOUT_AST_REFERENCES='+json.dumps(refs))
│ +fn=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='task_seconds')
│ +ns={'CAP_S':7200,'MARGIN_S':60,'TASK_S':'240'}
│ +exec(compile(ast.Module(body=[fn],type_ignores=[]),str(pth),'exec'),ns)
│ +print('DISPATCH_TASK_SECONDS='+json.dumps({str(x):ns['task_seconds'](x) for x in [0,10,60,10000]}))
│ +
│ +# Actual proxy Handler against a finite LOCAL SSE server. No production tokens,
│ +# upstreams, request logs, or provider calls are used.
│ +proxy=load('round9_proxy', Path('/home/kara/.hermes/scripts/cf-inference-proxy.py'))
│ +proxy.load_tokens=lambda:{'fixture':'round9-fixture-token'}
│ +proxy.upstream_key=lambda:'round9-fixture-upstream-key'
│ +proxy.USAGE_LOG=TMP/'usage.jsonl'
│ +proxy.CAPTURE_LOG=TMP/'capture.jsonl'
│ +class Upstream(BaseHTTPRequestHandler):
│ +    protocol_version='HTTP/1.1'
│ +    def do_POST(self):
│ … omitted 31 diff line(s) across 1 additional file(s)/section(s)
│ cache/scratch/round9_spine_adversarial.py
│ @@ -0,0 +1,29 @@
│ +import contextlib
│ +import importlib.util
│ +import io
│ +import json
│ +from pathlib import Path
│ +p=Path('/home/kara/code-factory/scripts/handbook_spine.py')
│ +spec=importlib.util.spec_from_file_location('spine',p)
│ +s=importlib.util.module_from_spec(spec); spec.loader.exec_module(s)
│ +original=s.chapters()
│ +for label, mutate in [
│ +    ('UNKNOWN_CANONICAL_ID', lambda d: d.__setitem__('M0-shared-contract',d['M0-shared-contract'].replace('## 7. Verification','| CT-99 | invented | out | `fake.py:1` `send()` | `fake.go:1` `Receive` | works |\n\n## 7. Verification'))),
│ +    ('CONTRADICTORY_BACKTICKED_DEFAULT',lambda d:d.__setitem__('M5-harness',d['M5-harness'].replace('| `CF_MAX_TURNS` | 40 (','| `CF_MAX_TURNS` | `999` ('))),
│ +]:
│ +    data=dict(original); mutate(data); s.chapters=lambda:data
│ +    out=io.StringIO()
│ +    with contextlib.redirect_stdout(out): rc=s.main()
│ +    print(label+' RC='+str(rc)+' OUTPUT='+json.dumps(out.getvalue()))
│ +# The error/free probe distinction is thrown away by the public lock classifier.
│ +spec=importlib.util.spec_from_file_location('lock', '/home/kara/code-factory/scripts/board_lock.py')
│ +l=importlib.util.module_from_spec(spec); spec.loader.exec_module(l)
│ +l.fd_holders=lambda _:[]
│ +l.consumer_count=lambda:0
│ +l.commits_after_mtime=lambda _:'unknown'
│ +path=Path('/home/kara/.hermes/cache/scratch/round9-synthetic-existing-lock')
│ +path.write_text('fixture')
│ +for state,detail in [('free','uncontended'),('error','open-failed')]:
│ +    l.flock_probe=lambda _:(state,detail)
│ +    print('LOCK_'+state.upper()+'='+l.adjudicate(path))
│ +path.unlink()
│ cache/scratch/round9-blocking-findings.txt
│ @@ -0,0 +1,25 @@
│ +B01 metrics RED
│ +B02 boundary contract waiver
│ +B03 provisioning settings
│ +B04 provisioning certification
│ +B05 digest locators
│ +B06 dispatch defaults
│ +B07 activation classification
│ +B08 board drift contradiction
│ +B09 lock recovery
│ +B10 harness settings
│ +B11 conformance verification
│ +B12 chapter delivery
│ +B13 mint verification
│ +B14 scheduler settings
│ +B15 scheduler admission
│ +B16 projection semantics
│ +B17 operator API contracts
│ +B18 log registers
│ +B19 metric registers
│ +B20 custody settings
│ +B21 TypeScript client semantics
│ +B22 unused exec timeout
│ +B23 dispatcher failure oracles
│ +B24 proxy reproduction
│ +B25 CT-06 disagreement
VERDICT: FAIL
BLOCKING: 25 — findings that must be fixed before the affected chapters can be called written
NON-BLOCKING: 1

FINDINGS:

Evidence basis

Read all 13 chapters, OUTLINE.md, MASTER-DOC-SCHEMA.md, and the relevant implementations in all five specified systems. Did not use previous seats’ verdicts as evidence.

Ran python3 scripts/handbook_spine.py:
  chapters=13  canonical contracts=18
  findings=0
  Exit 0.

There are consequently no checker-reported findings to promote to CONTRADICTION. The clean result does not establish semantic consistency: B25 identifies a contract-state disagreement the checker misses.

Independent verification returned:
  disk_floor: 12 tests passed.
  lane_target: 40 tests passed.
  harness_resolve: 28 tests passed.
  reclaim: 9 tests passed.
  Scan-scope check: 15 claims, RESULT: OK.
  Extracted shipped landing arm: exit 0, LANDING_ARM_FAILURES=0.
  Harness conformance --vars-only, isolated HOME: 8 pass, 0 fail, 0 skip.
  Board validation: 357 tasks, 518 events, RESULT: OK (7 warning(s)).
  Board drift: RESULT: DRIFT (4 failed), divergent id CF-270.
  Documentation gate: 44 modules, 37 declared VERIFIED, 50 errors, MASTER-DOC: FAIL.
  Gate explicitly targeting chapters/: no matching module files, exit 1.
  Renderer: “no modules found”, exit 1.
  Patch chain: VERIFY-PATCH: PASS.
  Live proxy without a token: HTTP 401.
  Proxy systemd unit: loaded, enabled, active/running.
  Isolated actual proxy Handler: disallowed model HTTP 403; healthy finite SSE response HTTP 200 but EOF read timed out.

Full Go suites, live node certification, real GitHub token minting, and paid inference were not repeated. Their historical PASS claims are not independent execution evidence from this review.

Acknowledged RED fields remain blocking under the supplied schema. Naming an incompleteness honestly does not make it WRITTEN.

B01 — OMISSION — M0–M8, M11, M12
  Claim: Each chapter’s §8 reports “RED — none” for metrics.
  Evidence: These eleven chapters explicitly leave the metrics field RED. MASTER-DOC-SCHEMA.md:74-79 requires metric type, labels, question answered and scrape location, and expressly makes “none” RED. README.md:67-71 likewise says these chapters stay PARTIAL until instrumentation exists or an explicit exception is approved.
  Fix: Supply the required instrumentation and metric contracts, or obtain and record an explicit schema exception. Do not promote these chapters to WRITTEN merely because absence has been proved.

B02 — UNVERIFIED — M0, M2, M3, M6, M8, M9, M10, M12
  Claim: Missing/external implementation halves are described as an “honest terminal state, not a chapter defect”; several such rows nevertheless say “works.”
  Evidence: Examples include M0:90-93, M2:89-96, M8:73, M9:202-206, M10:131-134 and M12:95. The brief requires producer AND consumer as file:function; MASTER-DOC-SCHEMA.md:56-57 supplies no blanket external-boundary exemption. In particular, M2 CT-11, M9 CT-15 and M12 CT-07 assert external success without a corresponding implementation locator or quoted execution proving that success.
  Fix: Distinguish an intentionally excluded implementation from a verified contract. Mark unsupported success assertions UNVERIFIED and retain the blocking field, or document an approved boundary-specific acceptance rule. Where a covered implementation exists, name it rather than substituting “external.”

B03 — OMISSION — M1
  Claim: “Settings register,” followed by registers for selected provisioning units.
  Evidence: M1:89-134 does not register the operational controls of node_env.py, node_seed_drift.py, node_freshness.py and verify-node.sh. Those are not inert files: node_env.py:459-487 parses --check/--apply, --env-file and repeated --config-set; :495-503 selects HOME and destination files. verify-node.sh:147-150 and :191-198 implement distinct strictness controls with different terminal consequences.
  Fix: Complete the per-unit register with actual defaults, accepted values, precedence, readers and consequences. A statement that settings surfaces were read is not the settings contract itself.

B04 — UNVERIFIED — M1
  Claim: M1-C1 says the registration producer “is not established”; the certification ladder is “not run this round.”
  Evidence: M1:140 and :150 leave both enrollment and certification unresolved. The inspected provisioning code installs supplied agent keys/bearers at bunker-provision.sh:380-382 and later calls the connection checker at :536-540; installing supplied material is not evidence that an agent was registered. verify-node.sh:205-214 also has three materially different exits.
  Fix: Identify the actual registration/key-issuance authority and provide an executable enrollment-to-signed-read procedure. Supply a concrete certification invocation, named prerequisites and per-leg readback. Until exercised, retain enrollment and certification as separate UNVERIFIED fields.

B05 — FALSE CLAIM — M2
  Claim: The brief-digest log is attributed to node-bus-worker.py:1002-1005, and §11 attributes digest refusal to :997-1012.
  Evidence: M2:125 and :140-141 cite regions that do not perform the digest comparison. Current node-bus-worker.py:1000-1004 selects legacy directive members; :1007-1012 starts process(). The digest comparison and refusal are at :1044-1060, with the quoted log at :1050-1052.
  Fix: Re-pin the digest claims and log emitter to the actual implementation, then check the remaining M2 locators for semantic support rather than mere existence.

B06 — OMISSION — M2
  Claim: “--harness-wall / --timeout” defaults are “DEFAULT_HARNESS_WALL / DEFAULT_TIMEOUT.”
  Evidence: M2:77 gives symbol names, not usable default values. node-bus-worker.py:83-84 defines 10 seconds and 1800 seconds respectively. The chapter also omits controls such as --gateway-port=10800 and the identity, token and workdir overrides at :1437-1476. Its “positive int” description does not describe the parser’s actual validation surface.
  Fix: Expand the CLI register. State numeric defaults, explicitly identify which ranges are enforced versus recommended, and describe refusal, fallback or runtime failure for invalid inputs.

B07 — CONTRADICTION — M3, M6, M10
  Claim: Submodules are classified “active” using “main() entrypoint,” “read,” or their own handler definitions as evidence.
  Evidence: M3:38 calls S1 active while simultaneously saying clone_lane.py is operator-invoked with no in-repo caller. M6:42-44 uses entrypoints as activation evidence. M10:34 uses only “read.” OUTLINE.md:108-113 requires a scheduler lane, cron, timer or another unit’s invoking line; self-definition is not invocation.
  Fix: Classify units individually and cite their actual invokers. Where invocation is manual or unproved, use the corresponding operator-invoked/UNVERIFIED classification rather than active.

B08 — CONTRADICTION — M4
  Claim: S2’s evidence says board_drift returned “RESULT: OK this round (see §7).”
  Evidence: M4:34 conflicts with :108 and :113-121. Independent execution returned RESULT: DRIFT (4 failed), with CF-270 pending locally and complete in origin/main.
  Fix: Replace the S2 PASS claim with the measured DRIFT result and its timestamp/ref. Preserve the distinction between an accurate drift detector and a board copy that actually passes parity.

B09 — UNBUILDABLE — M4
  Claim: On RESIDUE, “proceed”; but a failed/unreadable probe must instead be treated as UNKNOWN.
  Evidence: M4:49-56 and :153 require an operator to distinguish those cases. board_lock.py:155-158 discards the probe error/detail and emits the same public RESIDUE shape for both. An isolated probe returned identical output for a free lock and an injected open-failed probe:
    RESIDUE consumers=0 commits_after_mtime=unknown
  Fix: Document a concrete, independent diagnostic that establishes observation quality before proceeding, or expose that quality in the classifier. The current procedure branches on information its prescribed output does not contain.

B10 — OMISSION — M5
  Claim: “Per-adapter installation registers” complete the harness settings surface.
  Evidence: M5:99-114 omits the toolchain installer’s concrete controls. install-go.sh:7-15 defines go1.26.5, architecture-specific digests, a 1 GiB floor, the probe module/version, and GO_INSTALL_ROOT; :72-73 fixes a 30-second module-resolution timeout. M5 describes Go only as “pinned.”
  Fix: Register these controls and their consequences, alongside the remaining project-node and adapter-specific controls. Name the actual pin and installation path rather than “pinned.”

B11 — UNVERIFIED — M5
  Claim: The conformance battery is unrun because it “needs a live node.”
  Evidence: M5:128 and :141 blanket the whole battery under that prerequisite. tests/harness-conformance.sh:24 exposes --vars-only; :317-328 creates synthetic fixtures and runs adapters in a scrubbed environment. I ran that shipped mode in an isolated HOME: 8 pass, 0 fail, 0 skip, exit 0, without a remote node or real credential.
  Fix: Split verification by leg. Record the locally repeatable variable-contract result separately from installation, real-turn and memory/certification legs. Give each unrun leg its actual prerequisite; do not hide available verification behind an overbroad dependency.

B12 — UNBUILDABLE — M6
  Claim: The fill/render/panel pipeline does not operate on these M-numbered chapters.
  Evidence: This acknowledged defect is independently reproducible. master_doc_check.py:186-199 selects NN-*.md; targeting chapters/ produced zero selected modules and exit 1. gen_nasa_handbook.py selected no modules and exited 1. The default appendix gate additionally returned 50 errors. master_doc_fill.py:422 uses the same incompatible filename convention.
  Fix: Establish one chapter-aware selection and delivery path, make its gate inspect the actual chapter set, and provide a successful artifact-generation command with readback. Describing the broken legacy path does not supply the required delivery mechanism.

B13 — UNVERIFIED — M7
  Claim: Token verification is “python3 scripts/github-app-token.py token …,” with minting not run.
  Evidence: M7:91 contains an ellipsis rather than an executable command. github-app-token.py:598-618 performs the actual mint/write operation; :582-590 can instead skip by age. Refresh has separate local/no-op/node branches at github-app-refresh.sh:104-174.
  Fix: Provide complete commands using credential-file paths, expected redacted output, and checks of file privacy, freshness and scope. Separate mint, age-based skip, local refresh and node installation. If credentials are unavailable, name that prerequisite and retain the appropriate UNVERIFIED state.

B14 — OMISSION — M9
  Claim: The remaining 32 flags are listed with “consequence … not expanded per row.”
  Evidence: M9:160-180 explicitly leaves the register incomplete. These include execution-affecting controls, not incidental switches: cmd/schedulerd/main.go:183 suppresses real spawning; :195-198 configures auto-disable; :102-103 requires a complete TLS pair.
  Fix: Give each remaining control its default value, valid range, precedence, reader and consequence. Expand referenced constants to values. A grouped name/default list is NAME ONLY under the brief’s decision rule.

B15 — OMISSION — M9
  Claim: “Ordered admission procedure … in order of authority.”
  Evidence: M9:58-86 covers mode, ownership, workability, last failure and pool reservation but does not explain the actual packer’s allocation, eligibility, concurrency and fairness decisions. packer_select.go:36-42 selects fallback/allocation paths; :136-166 filters namespaces/projects and budget-blocked lanes; :184-190 applies namespace concurrency context; :216-226 applies starvation priority.
  Fix: Complete the composed decision path through selection and reservation, including refusal/defer reasons, ordering, disabled/empty cases and observable readbacks. Preserve the correct waiver-versus-refusal distinction already written.

B16 — FALSE CLAIM — M9
  Claim: execution_projections is “the materialized run state.”
  Evidence: M9:99 and :102-104 misdescribe the table. migrations.go:1470-1476 keys it by run_id plus projection, restricts projection to task_router/duckbrain/board/notification, and stores delivery state, remote_id, attempts and last_error. execution_store.go:607-647 implements that projection-delivery record.
  Fix: Describe it as per-destination projection/synchronization state, distinct from the execution run’s authoritative lifecycle. Document its writer, idempotency key and retry/recovery interpretation.

B17 — OMISSION — M9
  Claim: The route inventory is complete, but “per-route request/response shapes and write-authority readbacks are not written.”
  Evidence: M9:38-55 admits the missing operator contract. internal/api/server.go:289-370 mounts operational surfaces including projects, namespaces, hooks, pause/resume, agents and federation.
  Fix: Supply the operator-facing method, authentication, request/response shape, failure semantics and authoritative readback for each surface. Forty-three route names do not constitute an operating procedure.

B18 — OMISSION — M7, M9, M10
  Claim: The chapters provide their required log-line fields.
  Evidence: M9:238-242 explicitly covers only two of its stated 379 scheduler log sites. M10:198-203 leaves guard records untabulated despite guard.go:430-457 providing the emitters and fields. M7:104-105 lists helper formats and one refresh line but omits terminal outcomes implemented at github-app-token.py:561-566, :585-589 and :616-619.
  Fix: Complete the module-level inventory with verbatim messages/placeholders, severity, trigger and descriptive/evidentiary classification. File-local completeness must not stand in for module-wide completeness.

B19 — OMISSION — M9, M10
  Claim: M9 metrics are “Measured — real, not RED”; M10 inventories runtime series.
  Evidence: M9:224-234 provides endpoint/block prose but not the schema’s complete type/labels/question/scrape contract. server_metrics.go:38-70 distinguishes windowed measurements and empty-sample nulls, while :125 onward defines sources. M10:177-180 expressly leaves per-series contracts unfinished.
  Fix: Complete the metric contracts, including reset/window semantics, label domains, unavailable/no-sample meaning, and scrape/auth requirements. For M9, mark the incomplete documentation field RED rather than treating endpoint existence as completion.

B20 — OMISSION — M10
  Claim: Storage-selection controls are described, but the active-backend proof is “not yet written.”
  Evidence: M10:114-119 lacks default/range/consequence rows for the custody store. config/config.go:732-767 implements URL precedence, CR_REGISTRY_BACKEND and CR_REGISTRY_SQLITE_PATH, including memory, sqlite and postgres; :770-808 validates pool settings. The chapter’s PostgreSQL-versus-SQLite description also leaves the memory case unexplained.
  Fix: Register backend resolution and pool controls, describe the memory backend’s durability consequence, and provide a command/readback that establishes which backend currently owns custody.

B21 — OMISSION — M10
  Claim: S4 covers Python and TypeScript client libraries as one versioned contract.
  Evidence: M10:35 and :73 document essentially the Python side. The implementations differ materially: Python crier_client.py:1003-1005 body-signs delivery when sender equals agent_id; TypeScript crier.ts:709-717 invokes raw delivery without signed:true. Python also exposes delivery options absent from the TypeScript signature.
  Fix: Document the two client surfaces independently, including signature behavior, supported fields and service-recipient compatibility. Do not imply equivalent delivery semantics without a parity test.

B22 — FALSE CLAIM — M11
  Claim: DISPATCH_EXEC_TIMEOUT is “the timeout prefix on every bunker exec run,” and an invalid value fails at runtime.
  Evidence: M11:73 is contradicted by dispatcher.py. EXEC_TIMEOUT is assigned at :47 and never read. AST inspection found exactly one reference, a Store. _bunker() uses its timeout argument at :204-209; the synchronous path derives limits at :345-348.
  Fix: Mark DISPATCH_EXEC_TIMEOUT as unused/inert in this revision. Document the actual per-call and outer subprocess limits. Do not tell an operator this environment variable changes execution behavior.

B23 — UNBUILDABLE — M11
  Claim: “Harness overruns deadline … job killed … automatic; check the rc= log.”
  Evidence: M11:149 gives an operational guarantee that §2:28-37 has withdrawn. dispatcher.py:260 runs the harness under GNU timeout, while :329 targets the run.sh PID’s process group; the chapter supplies no descendant-termination acceptance command. Its §7 live-job scripts are also admitted to lack the required behavioral assertions.
  Fix: Give the deadline failure row a procedure that verifies harness/descendant termination rather than assuming it, with a failing oracle for survivors, wrong exit status and incomplete settlement. Retain the kill guarantee as unverified until that test passes.

B24 — UNVERIFIED — M12
  Claim: A previous verifier reproduced HTTP-completion failure, while streaming correctness remains UNVERIFIED.
  Evidence: M12:174-183 gives measured strings but no executable reproduction. I independently exercised the actual Handler against a finite local SSE upstream:
    LOCAL_STREAM_STATUS=200
    Content-Length=None
    Transfer-Encoding=None
    Connection=None
    LOCAL_STREAM_EOF_COMPLETED=False:TimeoutError
  Fix: Include a complete isolated reproduction and expected failure oracle in §7. Distinguish source verification, admission verification, upstream behavior and known-failing downstream completion. The reproduction used here is:
    python3 /home/kara/.hermes/cache/scratch/round9_judge_probes.py
  It uses synthetic tokens and a local upstream, not production credentials or paid inference.

B25 — CONTRADICTION — M9, M11
  Claim: CT-06 is “broken” in M9 and “works” in M11.
  Evidence: M9:200 names dispatcher.py:500-508 as its producer but justifies “broken” using the different node worker’s status field. M11:94 names that same dispatcher producer and correctly explains that it sends ok. dispatcher.py:501 sends ok; node-bus-worker.py:1180 sends status; dispatch_leg.go:713-725 reads ok.
  Fix: Model the producer variants explicitly and give each its matching state. The dispatcher reply path and node-worker reply path cannot share an unqualified state while the row names only one producer. Extend the consistency check to catch incompatible state/variant claims; its current zero findings missed this disagreement.

N01 — PADDING — M0–M12
  Claim: Repeated accounts of what “round-3,” “round-4” and later drafts falsely claimed.
  Evidence: Examples include M3:185-191, M5:205-215 and M12:74-80. Some correction history is useful, but repeated historical narration interrupts the current operational contract and duplicates evidence-of-record sections.
  Fix: Keep the current behavior, consequence and locator in the chapter body; move superseded claims and seat attribution to the designated change/supersession appendix. Non-blocking because this does not itself falsify the current implementation description.

DEFECT CLASSES:

  Unsupported external success
  Unapproved boundary exemptions
  RED-field completion gaps
  Incomplete settings and ranges
  Stale semantic locators
  Activation inferred from existence
  Conflicting measured state
  Recovery branching on unavailable evidence
  Unbuildable chapter delivery
  Placeholder verification commands
  Incomplete admission and operator contracts
  Misidentified durable-state semantics
  Partial log and metric registers
  Undocumented client divergence
  Inert setting presented as effective
  Missing behavioral failure oracles
  Unrepeatable historical probes
  Unqualified multi-producer contract states
  Repeated correction-history padding

CHAPTER SCORECARD:

  M0 — PARTIAL
    Helper inventory and source counts reproduced; metrics remains RED and the one-sided bunker contract is not fully verified.

  M1 — PARTIAL
    Useful seed and certification descriptions; settings coverage, enrollment authority and live certification remain incomplete.

  M2 — PARTIAL
    Directive decoding and settlement code are described substantively; digest locators are wrong, settings remain incomplete, and the live ladder is not independently repeated.

  M3 — PARTIAL
    Shipped landing behavior independently passed. Freshness coverage is incomplete, activation classification is inconsistent, and metrics remains RED.

  M4 — PARTIAL
    Census, semantic validation and drift are reproducible. The active/PASS table contradicts the drift result, and the RESIDUE recovery procedure requires information the classifier discards.

  M5 — PARTIAL
    Resolver tests and the locally runnable variable-contract battery passed. Toolchain/settings coverage and installation/real-turn certification remain incomplete.

  M6 — PARTIAL
    The chapter correctly identifies important pipeline defects, but there is still no working chapter-aware gate/render delivery path; the appendix gate also fails.

  M7 — PARTIAL
    Credential domains and several lifecycle controls are useful. Mint/refresh acceptance evidence and the complete log register are missing; metrics remains RED.

  M8 — PARTIAL
    Reclaim tests and scope checks passed, with concrete target/TTL semantics. The schema-required metrics field remains RED.

  M9 — PARTIAL
    Substantial settlement and admission material exists, but projection semantics are wrong and admission, settings, operator, log and metric contracts remain incomplete.

  M10 — PARTIAL
    Useful custody, guard and Python-client detail. Backend controls, TypeScript differences, module-wide logs and per-metric contracts are unfinished.

  M11 — PARTIAL
    Full-source description is substantial, but the execution-timeout setting is documented falsely, CT-06 is inconsistent with M9, and deadline assurance lacks an executable oracle.

  M12 — PARTIAL
    Hash, live admission and service state reproduced. Healthy-stream completion independently fails; the chapter lacks a self-contained reproduction and verified node/upstream contract halves.

PANEL REVIEW COMPLETE

session_id: local-04f8a327f392899d4dbc69443bf6e60f150070092f08c462528ce1e6e4906872

EXIT=0
```

