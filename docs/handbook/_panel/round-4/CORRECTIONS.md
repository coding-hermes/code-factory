# CORRECTIONS — round 4

Generated 2026-11-06T17:27:30-0500.

## Verdicts

- **deepseek** — PASS, blocking 0, 7889 bytes, complete=True
- **glm** — FAIL, blocking 4, 17623 bytes, complete=True
- **grok** — FAIL, blocking 9, 19435 bytes, complete=True
- **kimi** — FAIL, blocking 71, 27240 bytes, complete=True
- **sol** — FAIL, blocking 28, 29004 bytes, complete=True

## Verdict text (verbatim, per seat)

### deepseek

```
VERDICT: PASS

BLOCKING: 0 — no false claim, contradiction, unbuildable prose, padding, or hidden unverified claim found. Every claim I spot-checked against the code verified, and every region the document could not prove is explicitly marked UNVERIFIED rather than asserted.

NON-BLOCKING: 8

FINDINGS:

1. kind: UNVERIFIED (disclosed) — M1 PROVISIONING — claim: "remaining unit bodies (node_identity.py, node_seed.py, node_seed_drift.py, node_env.py, node_freshness.py, bunker_config_gen.py) not read line-by-line" — evidence: chapter §1 Status self-declares UNVERIFIED; I confirmed the orchestrator call sites are correct (project-node.sh:173 invokes disk_floor.py resolve; bunker-provision.sh:454 invokes node_seed.py build; node_gateway_auth staged at :483-495) but the six bodies themselves remain unread — fix: line-by-line read of the six bodies, or narrow the §1 Status scope claim to what was read.

2. kind: UNVERIFIED (disclosed) — M5 HARNESS — claim: "install-codex.sh partial; install-claude-code.sh/install-deepseek.sh/install-pi-agent.sh/install-opencode.sh bodies not read line-by-line" — evidence: chapter §1 Status UNVERIFIED; I confirmed the §11 adapter matrix is derived from line-level reads (install-claude-code.sh:36 sources lib.sh; deepseek/pi-agent --apply refusal) — fix: read the four foreign installer bodies in full.

3. kind: UNVERIFIED (disclosed) — M9 SCHEDULER — claim: "tick_process.go / packer_select.go / namespace_alloc.go / usage_pool_policy.go grep-level, not line-by-line" — evidence: chapter §1 Status UNVERIFIED; I confirmed admission_mode.go:143-208, dispatch_leg.go:713-726, dispatch.go:202, main.go:108-144 read and accurate — fix: line-by-line read of the four S1 units.

4. kind: UNVERIFIED (disclosed) — M10 CRIER — claim: "the full 1895-line handler body not read line-by-line" — evidence: chapter §1 Status UNVERIFIED, §9 "inventory not exhaustive"; I confirmed HandleRegister(:598)/HandleDeliver(:990)/HandleRetrieve(:1690)/HandleAck(:1812) and the 91 test files exist and pass — fix: complete the §9 slog inventory or accept grep-level as the honest granularity per OUTLINE scope.

5. kind: FALSE CLAIM (locator off-by-one) — M6 DOCUMENTATION — claim: "gen_nasa_handbook.py:17 hardcodes MODULES = REPO/docs/master" — evidence: measured, MODULES is at gen_nasa_handbook.py:18; line 17 is `REPO = pathlib.Path(__file__).resolve().parent.parent`. The substance is correct (MODULES hardcodes docs/master), only the line number drifts by one — fix: change :17 to :18.

6. kind: OMISSION (operational, self-declared) — M6 DOCUMENTATION — claim: "the gate/render pipeline does not operate on the delivered M*.md chapters" — evidence: master_doc_check.py:52 DEFAULT_ROOTS = ("docs/master", "docs/handbook/appendices/units"); gen_nasa_handbook.py:18 + :255 glob "[0-9][0-9]-*.md"; neither selects M0-M12; the live gate returns MASTER-DOC: FAIL (44 modules / 50 errors) against the stale docs/master root — fix: re-point the gate and renderer at chapters/ (F6-1).

7. kind: CODE-FAIL (correctly surfaced, not a document defect) — M9 SCHEDULER — claim: "go test ./... FAIL (rc 1), SCHED-GAP-1726" — evidence: chapter §7 records it; it is the code's liveness leak (1 goroutine parked in evalDrain at suite exit), and the document reports it honestly as evidence-of-record rather than hiding it — fix: none for the document; the code leak is a board-row item (SCHED-GAP-1726).

8. kind: METRICS-ABSENT (systemic) — M0-M8, M11, M12 — claim: every node-side module §8 is "RED — none" — evidence: schema §5 mandates "none" as RED; only M9 (server_metrics.go, /api/v1/metrics) and M10 (guard metrics + observability, default-ON /metrics) emit real metrics — fix: instrument the node-side path or accept the RED as the standing finding (the document already surfaces it correctly).

DEFECT CLASSES: DISCLOSED-UNVERIFIED (submodule bodies unread), LOCATOR-DRIFT (one line), CODE-FAIL-SURFACED (go test, doc gate — reported, not hidden), METRICS-ABSENT (node-side observability).

Verification performed this round (real tool output, not the document's word): all four repo HEAD revisions match the stamps (code-factory 943ef984, scheduler 1771d3aa, crier 691f0c78, crier-fleet 283bca9); lib.sh=78 lines, harness-vars.sh=318, node-bus-worker.py=1498, cf-inference-proxy.py=273 with sha256 b12a0ac5… reproduced. Load-bearing contract claims all confirmed against code: node reads `dispatch.get("text")` at node-bus-worker.py:986 while scheduler emits only `p["text_b64"]` (dispatch.go:202, no `"text"` key anywhere — CF-354 true); node reply sends `status:"failed"/"completed"` (node-bus-worker.py:1132) while dispatchReplyVerdict reads only `payload["ok"]` and treats absence as success (dispatch_leg.go:709-726 — CF-355 true); dispatcher always sends `ok` (dispatcher.py:501) so M11-C2 "works" and CF-355 is correctly scoped to the node worker; configure_family.py:24-28 hardcodes PID 1755676 reading /proc environ (F2-2 true); reclaim_disk.py:21 AGED_PARENTS=(.node/jobs,.node/clones) excludes .cf-jobs (F8-3 true); master_doc_check.py:128-138 reads a supplied status and :214-216 re-emits it (F6-2 true, gate is structural not semantic); install-gitreins.sh:130-131 hook exits 0 when .gitreins/config.yaml absent (gate-silently-not-run true); harness_resolve.py has no production caller (grep self+pyc only, F5-2 true); scheduler.db has 30 tables and no verdicts table (F9-2 true, OUTLINE's "26 tables" is wrong and correctly corrected).

CHAPTER SCORECARD:

M0 SHARED CONTRACT — WRITTEN (read in full; every cited line re-verified; 1 RED=metrics).
M1 PROVISIONING — PARTIAL (S1-S4 unit bodies self-declared unread; orchestrator call sites verified and correct).
M2 DISPATCH — WRITTEN (node-bus-worker contracts verified; CF-354/CF-355 confirmed true against code).
M3 REPOSITORY — WRITTEN (land-node-branch, install-gitreins, clone_lane read in full; gate-by-default and hook-silent-noop confirmed).
M4 BOARD — WRITTEN (store measured 357/515, board_drift RESULT OK, boardctl validate RESULT OK(7 warnings); external peers honestly UNVERIFIED not "works").
M5 HARNESS — PARTIAL (foreign installer bodies unread; harness-vars/install-hermes/install-gitreins/harness_resolve verified).
M6 DOCUMENTATION — WRITTEN (gate read in full and its FAIL reproduced; locator off-by-one at gen_nasa_handbook.py:18, non-blocking).
M7 GITHUB — WRITTEN (CLI surface exercised exit 2; mint UNVERIFIED only because no App creds exist on host — environment limit, not a writing gap).
M8 SAFETY — WRITTEN (both units read in full; reclaim unit 9 tests pass; scan scope 15 claims).
M9 SCHEDULER — PARTIAL (grep-level for 4 S1 units; go test FAIL correctly surfaced; 30-table store confirmed).
M10 CRIER — PARTIAL (1895-line handler not line-by-line; 91 test files pass; guard degradation policy written).
M11 DISPATCHER — WRITTEN (read in full; 23 log sites inventoried; redelivery-not-crash-safe confirmed).
M12 INFERENCE PROXY — WRITTEN (read in full; sha256 reproduced; 401 admission reproduced; F12-3/F12-4/F12-5/F12-6 real).

Summary: the document is admissible. The owner's earlier rejections drove exactly the corrections now present — M9-M12 are real systems with measured contract state, external boundaries are named "rumour" instead of overclaimed, and every broken contract (CF-354 text/text_b64, CF-355 status/ok) is confirmed against the code rather than asserted. The four PARTIAL chapters owe their status to honestly-disclosed unread regions, not to hidden holes; under the OUTLINE's stated "submodule granularity, not package granularity" boundary those regions are the remaining verification work, not a reason to reject.

PANEL REVIEW COMPLETE

session_id: local-7526a6db83b74a42cf0d57e9c3ae31331cc7cd1c8e88ab230688ab5a25630a17

EXIT=0
```

### glm

```
│ cache/scratch/round4-judge/check_claims.py
│ @@ -0,0 +1,444 @@
│ +#!/usr/bin/env python3
│ +"""Round-4 quorum judge: mechanical verification of chapter file:line citations."""
│ +import sys, os
│ +
│ +CF = "/home/kara/code-factory"
│ +SCHED = "/home/kara/coding-hermes-scheduler/coding-herms-scheduler"
│ +CRIER = "/home/kara/crier"
│ +FLEET = "/home/kara/crier-fleet"
│ +PROXY = "/home/kara/.hermes/scripts/cf-inference-proxy.py"
│ +
│ +CHECKS = []
│ +def at(label, path, lo, hi, *subs):
│ +    CHECKS.append(("at", label, path, lo, hi, subs))
│ +def cnt(label, path, n):
│ +    CHECKS.append(("cnt", label, path, n))
│ +def absent(label, path, sub):
│ +    CHECKS.append(("abs", label, path, sub))
│ +
│ +# ---------------- M0 ----------------
│ +cnt("M0 lib.sh line count 78", f"{CF}/scripts/lib.sh", 78)
│ +at("M0 ok/bad/warn/note rows :5-9", f"{CF}/scripts/lib.sh", 5, 9, "PASS", "FAIL", "WARN")
│ +at("M0 FAILED counter :11", f"{CF}/scripts/lib.sh", 11, 11, "FAILED")
│ +at("M0 have() :13", f"{CF}/scripts/lib.sh", 13, 13, "have")
│ +at("M0 fetch_verified :19-42", f"{CF}/scripts/lib.sh", 19, 42, "fetch_verified")
│ +at("M0 --max-time 120 :22", f"{CF}/scripts/lib.sh", 22, 22, "max-time", "120")
│ +at("M0 sha compare :24-27", f"{CF}/scripts/lib.sh", 24, 27, "sha256")
│ +at("M0 digest mismatch :26", f"{CF}/scripts/lib.sh", 26, 26, "digest mismatch")
│ +at("M0 require_disk :48-57", f"{CF}/scripts/lib.sh", 48, 57, "require_disk")
│ +at("M0 disk FAIL row :54", f"{CF}/scripts/lib.sh", 54, 54, "disk")
│ +at("M0 shq :67-70", f"{CF}/scripts/lib.sh", 67, 70, "shq")
│ +at("M0 bunker_exec :75-78", f"{CF}/scripts/lib.sh", 75, 78, "bunker_exec", "bash -lc")
│ +
│ +# ---------------- M1 ----------------
│ +at("M1 load_config :95-123", f"{CF}/scripts/bunker-provision.sh", 95, 123, "load_config")
│ +at("M1 KEY=VALUE refusal :103", f"{CF}/scripts/bunker-provision.sh", 103, 103, "=")
│ +at("M1 unknown key :118", f"{CF}/scripts/bunker-provision.sh", 118, 118, "unknown")
│ +at("M1 node_env --check :147", f"{CF}/scripts/bunker-provision.sh", 147, 147, "node_env", "--check")
│ +at("M1 have bunker :181", f"{CF}/scripts/bunker-provision.sh", 181, 181, "bunker")
│ +at("M1 no bunker on PATH :182", f"{CF}/scripts/bunker-provision.sh", 182, 182, "no bunker client on PATH")
│ +at("M1 timeout :187", f"{CF}/scripts/bunker-provision.sh", 187, 187, "timeout")
│ +at("M1 bunker cp/exec probe :225-226", f"{CF}/scripts/bunker-provision.sh", 225, 226, "bunker")
│ +at("M1 -s token probe :214", f"{CF}/scripts/bunker-provision.sh", 214, 214, "-s", "github.token")
│ +at("M1 mode-600 claim :233", f"{CF}/scripts/bunker-provision.sh", 233, 233, "mode 600")
│ +at("M1 node_env --apply :426", f"{CF}/scripts/bunker-provision.sh", 426, 426, "node_env")
│ +at("M1 node_seed build :454", f"{CF}/scripts/bunker-provision.sh", 454, 454, "node_seed")
│ +at("M1 node_gateway_auth :483-495", f"{CF}/scripts/bunker-provision.sh", 483, 495, "node_gateway_auth")
│ +at("M1 node_identity :518-533", f"{CF}/scripts/bunker-provision.sh", 518, 533, "node_identity")
│ +at("M1 destroy --yes :550", f"{CF}/scripts/bunker-provision.sh", 550, 550, "--yes")
│ +at("M1 modes :561-609", f"{CF}/scripts/bunker-provision.sh", 561, 609, "destroy", "apply")
│ +at("M1 CLI wins :598", f"{CF}/scripts/bunker-provision.sh", 598, 598, "command line always wins")
│ +at("M1 ROLE_DEFAULTS :34-42", f"{CF}/scripts/disk_floor.py", 34, 42, "worker", "builder", "full", "5", "10", "20")
│ +at("M1 DEFAULT_ROLE :37", f"{CF}/scripts/disk_floor.py", 37, 37, "worker")
│ +at("M1 MIN/MAX_GIB :60-75", f"{CF}/scripts/disk_floor.py", 60, 75, "MIN_GIB", "MAX_GIB")
│ +at("M1 resolve() :115-141", f"{CF}/scripts/disk_floor.py", 115, 141, "def resolve")
│ +at("M1 cli floor :127", f"{CF}/scripts/disk_floor.py", 127, 127, "disk")
│ +at("M1 env floor :129", f"{CF}/scripts/disk_floor.py", 129, 129, "NODE_DISK_FLOOR")
│ +at("M1 role default :141", f"{CF}/scripts/disk_floor.py", 141, 141, "ROLE_DEFAULTS")
│ +at("M1 FloorError unknown role :122-125", f"{CF}/scripts/disk_floor.py", 122, 125, "FloorError", "unknown role")
│ +at("M1 exit 2 :169-171", f"{CF}/scripts/disk_floor.py", 169, 171, "2")
│ +at("M1 agent_alive :50-54", f"{CF}/scripts/verify-node.sh", 50, 54, "ALIVE")
│ +at("M1 gateway_reachable :57-87", f"{CF}/scripts/verify-node.sh", 57, 87, "api/status")
│ +at("M1 auth_required :70-74", f"{CF}/scripts/verify-node.sh", 70, 74, "auth_required")
│ +at("M1 000=UNVERIFIED :75-84", f"{CF}/scripts/verify-node.sh", 75, 84, "000")
│ +at("M1 unauth_refused :90-103", f"{CF}/scripts/verify-node.sh", 90, 103, "system/stats")
│ +at("M1 artifact_digest :104-115", f"{CF}/scripts/verify-node.sh", 104, 115, "artifact")
│ +at("M1 checkout_freshness :118-155", f"{CF}/scripts/verify-node.sh", 118, 155, "node_freshness")
│ +at("M1 seed_drift :157-202", f"{CF}/scripts/verify-node.sh", 157, 202, "node_seed_drift")
│ +at("M1 ladder exit :205-214", f"{CF}/scripts/verify-node.sh", 205, 214, "VERIFY: FAIL", "UNVERIFIED")
│ +at("M1 disk_floor caller :173", f"{CF}/scripts/project-node.sh", 173, 173, "disk_floor.py")
│ +at("M1 reclaim caller :212", f"{CF}/scripts/project-node.sh", 212, 212, "reclaim_disk.py")
│ +
│ +# ---------------- M2 ----------------
│ +at("M2 urllib import :66-78", f"{CF}/scripts/node-bus-worker.py", 66, 78, "urllib")
│ +absent("M2 no crier_client import", f"{CF}/scripts/node-bus-worker.py", "crier_client")
│ +at("M2 DEFAULT_INBOX_LIMIT 10 :80", f"{CF}/scripts/node-bus-worker.py", 80, 80, "DEFAULT_INBOX_LIMIT")
│ +at("M2 DEFAULT_LEASE_SECONDS 30 :81", f"{CF}/scripts/node-bus-worker.py", 81, 81, "DEFAULT_LEASE_SECONDS")
│ +at("M2 SEEN_LIMIT 200 :84", f"{CF}/scripts/node-bus-worker.py", 84, 84, "SEEN_LIMIT")
│ +at("M2 turns range :111", f"{CF}/scripts/node-bus-worker.py", 111, 111, "1000")
│ … omitted 366 diff line(s) across 1 additional file(s)/section(s)
│ .hermes/cache/scratch/round4-judge/check_claims.py
│ @@ -404,9 +404,14 @@
│  sel = sys.argv[1] if len(sys.argv) > 1 else ""
│  fails = 0
│  total = 0
│ -for kind, label, path, lo, hi, subs in CHECKS:
│ -    if sel and not sel.lower() in label.lower():
│ -        continue
│ +for c in CHECKS:
│ +    kind, label, path = c[0], c[1], c[2]
│ +    if kind == "cnt":
│ +        lo, hi, subs = c[3], c[3], ()
│ +    elif kind == "abs":
│ +        lo, hi, subs = 1, 1, (c[3],)
│ +    else:
│ +        lo, hi, subs = c[3], c[4], c[5]
│      total += 1
│      try:
│          with open(path, errors="replace") as f:
All verification is complete: ~380 claim checks against the code, every repeatable command re-run (both Go suites, all unit tests, board census/validate/drift, doc gate, patch chain, scan-scope, proxy hash + live 401, fail-closed probe), and the two ambiguous claims (crier idempotency branches, scheduler `board` field) resolved by reading the code. Verdict:

```
VERDICT: FAIL

BLOCKING: 4 — findings that must be fixed before this chapter set can be called written
NON-BLOCKING: 5

FINDINGS:

BLOCKING

1. FALSE CLAIM — M9 (§7 Verification, §1 Status, §13 Evidence)
   Claim: "go test ./... → FAIL (rc 1) — SCHED-GAP-1726 goroutine census: 1
   goroutine(s) still parked in evalDrain at suite exit (169.8s)" and "It is a
   liveness leak, not a build break … real and reproduced this round (not a
   one-off)."
   Evidence: at the SAME revision `1771d3aad61e6c1ce2845e3f1450f88aa73340b3`,
   `env -u SCHEDULER_OPERATOR_RESTART_APPROVED go test ./...` → rc=0, 25/25
   packages ok, internal/scheduler ran 169.265s NOT cached and passed. The
   writer's shell carried the ambient var (my shell reports it =1; it is
   documented in the repo's own docs/reference/env-vars.md and load-bearing in
   schedgap1608_operator_restart_test.go / restart_approval.go). With the var
   set I reproduce three FAILs (TestSCHEDGAP091_DrainTimeoutStampsOrphan,
   TestOperatorRestartApprovalEnv, TestAbortInFlightTicks_OperatorApprovedStamp)
   plus the census line; with `env -u` those three tests pass in 0.268s. The
   "reproduced twice" runs inherited the same artifact. Rule 4 violated in the
   strongest form: I repeated the command and got the opposite result.
   Fix: re-stamp §7 with the clean-env command and its PASS (or record the env
   precondition in the row), and correct §1 Status and §13's command log. Do
   not carry "SCHED-GAP-1726 liveness leak" as a finding of the code without a
   clean-env reproduction.

2. UNVERIFIED (classification rule not applied) — M1 §3, M3 §3, M5 §3, M9 §3
   Claim: submodules classified **active** whose evidence is not an invoking
   line: M3 S2 land-node-branch.sh ("invoked by the node's result envelope"),
   M1 S2 bunker-provision.sh ("is the orchestrator"), M5 S1 install-hermes.sh
   ("measured adapter; certified by the conformance battery"), M9 S4/S5
   (`ls cmd/` → 7 commands; "six doctrine docs present").
   Evidence: repo-wide greps run this round — `land-node-branch` is referenced
   only by tests/selftest.sh; `bunker-provision` only in bunker_config_gen.py
   docstrings; `install-hermes` only by tests/ (install-claude-code.sh:649 is a
   comment); `ls cmd/` and "docs present" are existence, not invocation. The
   document's own rule (OUTLINE §III.3, quoted by the chapters) requires the
   invoking `file:line` or a quoted absence-proof — M2 (F2-4), M6 (F6-4) and
   M8 (F8-4) apply exactly that and demote to operator-invoked. Counter-proof
   the chapters missed: verify-node.sh IS invoked (node-create.sh:131) and
   node-bus-worker.py --check IS invoked (bunker-crier-connect.sh:53) — those
   two "active" rows are right but still cite no invoking line.
   Fix: one standard everywhere — either grep-proof each classification (and
   re-classify land-node-branch / bunker-provision / install-hermes as
   operator-invoked) or cite the invoking lines that justify "active".

3. UNVERIFIED (citations that land on the wrong code) — M7 §5, M9 §11
   Claim: M7 "`--env-file` … (`:300-304`)" and "`--api-base` … (`:305-309`)";
   M9 "`:208+` boardOwnedByLane".
   Evidence: github-app-token.py:300-309 is GITHUB_APP_ID/INSTALLATION_ID
   validation prose — the actual defaults are DEFAULT_ENV_FILE at :45,
   DEFAULT_API at :47, argparse at :110/:115. admission_mode.go's
   boardOwnedByLane is at :173-177 (comment :173, func :177); ":208+" lands on
   tasksAdmissionDue. A reader following the pin reads the wrong code.
   Fix: re-pin those three rows (M7 §5 → :45/:110, :47/:115; M9 §11 → :173-177;
   also M7 APP_ID/INSTALLATION_ID rows shift ~5-10 lines, access_tokens POST is
   :371 not :367-369).

4. UNVERIFIED (verification command not repeatable as printed) — M12 §13
   Claim: "grep -rn '8775|CF_PROXY|cf-inference-proxy' scripts/ config/
   specs/" with the three matches listed (panel_loop.py:136,
   master_doc_skeleton.py:25/:211, node.env.example:22).
   Evidence: the command AS QUOTED (BRE, no -E) returns nothing — measured
   rc=1, 0 matches; with -E the three matches reproduce exactly (this round).
   A stranger running the documented command concludes the opposite of the
   row. This is the same defect class the panel already burned a round on
   (round-3's over-escaped greps, M0 §7).
   Fix: print the command with -E (or three -e branches).

NON-BLOCKING

5. Citation drift, adjacent lines, claims all TRUE — M1, M2, M6, M10, M11
   M1 :118→:119 (unknown-key refusal), :598→:589 (the quoted comment), five
   re-applied flags :605-611→:604-608; M2 branch/commit :1141-1142→:1139-1140,
   seen-cache warn :1355→:1352-1353, --interval :1442→:1441, range :111→:112;
   M6 MODULES :17→:18; M10 metrics.go:5→:2; M11 int(TASK_S) :193→:196.
   Verified TRUE in every case within the cited function. Fix: one re-pin pass.

6. OMISSION (disclosed) — M9 §9, M10 §9
   M9's log-line inventory is 2 of 379 `log.Printf` sites (count re-measured:
   379); M10's §9 is explicitly non-exhaustive over the 1895-line handler.
   Both self-flagged RED. Sections exist but are not inventories; they gate
   the WRITTEN score for those two chapters, not the document's honesty.

7. UNVERIFIED-by-conditions (honestly disclosed) — M1 §7 certification ladder,
   M2 §7 bus-worker ladder, M5 §7 conformance legs, M7 §7 token mint, M10 §7
   signed-read ladder, M12 §7 disallowed-model leg
   Each needs a live node or App credentials this host does not have; every
   row is already marked UNVERIFIED with the precondition named. I could not
   repeat them either. No action beyond keeping the markings.

8. OMISSION (system-level, disclosed as F6-1/CF-360) — M6
   The module's own gate cannot select this chapter set: master_doc_check.py
   glob `[0-9][0-9]-*.md` at :188 (re-run: 44 modules, 37 VERIFIED, 50 errors,
   MASTER-DOC: FAIL, exit 1 — exact) and gen_nasa_handbook.py:18 hardcodes
   docs/master. Consequence: this document has no automated gate; the only
   gate that runs on it is this panel. Keep the finding; it needs a board row
   with the chapter-aware gate as acceptance, which CF-360 appears to be.

9. Metrics RED (inherent, code not doc) — M0, M1, M2, M3, M4, M5, M6, M7, M8,
   M11, M12
   Eleven chapters correctly report "none" with the schema's RED marking; M9
   and M10 have real metric surfaces, verified (server_metrics.go blocks;
   crier_guard_* counters/histogram at metrics.go:19-49, default-ON at
   config.go:667-673, mount at observability.go:101-109). The RED fields are
   findings against the code, not the document; fixing them is code work.

DEFECT CLASSES:
env-contaminated-verification · classification-without-invoking-line ·
citation-mispin-wrong-construct · unrepeatable-quoted-command ·
adjacent-line-drift · disclosed-unread-bodies · external-boundary-contracts ·
metrics-absent-in-code · self-gating-impossible

CHAPTER SCORECARD:
- M0  WRITTEN — 78-line file read; 11/17 source counts exact; fail-closed
  probe re-run (curl(7), rc=1, no artifact); only RED is inherent metrics.
- M1  PARTIAL — orchestrator paths and the ladder verified leg-by-leg
  (precedence exit 0/1/3 confirmed at verify-node.sh:205-214), but S1-S4 unit
  bodies unread (self-declared) and S2 classification lacks an invoking line.
- M2  PARTIAL — node-bus-worker.py contracts and settlement ordering verified
  exactly (deliver → seen-after-delivery :1347-1349 → ack-last :1359-1367);
  PID 1755676 hardcode confirmed; but the S1 trio is structure-mapped only and
  the live ladder is not repeatable from this host.
- M3  WRITTEN — all three units read in full; gate-empty-by-default (:36,
  :171-193) and the clone_lane-is-a-lane-row correction (:74-118) verified;
  dry-run honestly re-refused on a dirty workdir; numbered-arm hoax confirmed
  (0 matches). Classification of S2 is the one open row (finding 2).
- M4  PARTIAL — 357/515 census, drift OK, validate OK(7 warnings) all
  reproduced exactly; both contract rows are UNVERIFIABLE in-repo by nature
  (all sides external) and the chapter says so.
- M5  PARTIAL — harness-vars.sh predicate `[0-7]00` vs "must be 600" message,
  resolver-with-no-caller, and the non-uniform adapter matrix all verified
  exactly; four installer bodies unread and conformance not run.
- M6  PARTIAL — the gate's behavior (structural, reports supplied status;
  44/37/50 FAIL) reproduced exactly and F6-2's correction is right; but most
  of the pipeline is unread and the module cannot gate this document set.
- M7  PARTIAL — CLI surface, 0600 enforcement, JWT constants, credential
  separation from fleet-gh-scope.py:52/:81-94 all verified; mint never run
  (no creds) and §5 carries the wrong-construct pins (finding 3).
- M8  WRITTEN — both files read in full; 9 reclaim tests and the 15-claim
  scan-scope run repeated exactly; PROTECTED list and the .cf-jobs gap
  verified in code.
- M9  PARTIAL — settlement, dispatchReplyVerdict's ok-only read (:712-726),
  text_b64/board envelope (:184, :202), binary defaults (main.go:108-144), 30
  tables, 379 sites: all verified — but the chapter's one FAIL row is false
  (finding 1), admission internals are grep-level, and §9 is 2/379.
- M10 PARTIAL — handler function map, guard oversize/fail-open branches
  (errorResult :318-361 verified verbatim), policy precedence, default-ON
  metrics, 91 test files and a green 40-package suite all confirmed; the
  1895-line body is not read line-by-line and §9 admits it.
- M11 WRITTEN — read in full; all 23 log() sites confirmed with exact line
  numbers (25 grep hits minus comment :81 and def :112); reply shape and the
  always-`ok` field verified at :500-508; decoration tests confirmed (0
  asserts); task_seconds(10)=30 confirmed in code.
- M12 WRITTEN — read in full; sha256 exact; live 401 reproduced; the
  [200,502] double-status analysis confirmed against :232-238; the only defect
  is the -E missing from one quoted grep (finding 4).

The set is close: 5 of 13 chapters are genuinely written, every headline
contract defect (CF-354/355/356, F2-2, F3-2/3/3, F5-2/3, F10-4, F11-3/4/5/6,
F12-4/5/6) verified true against the code, and I found no invented claim other
than M9's test verdict. The four blocking findings are all cheap to fix and
all sit in evidence rows, not prose.

PANEL REVIEW COMPLETE
```

session_id: local-dfd1db9c6d31b7aec935dba6ac091292f53f80d39957d277657e0c6f5a97166d

EXIT=0
```

### grok

```
⚠️  Primary auth failed — switching to fallback: fireworks / accounts/fireworks/models/deepseek-v4p1-flash-1017
VERDICT: FAIL
BLOCKING: 9
NON-BLOCKING: 11

FINDINGS

1. FALSE CLAIM — M9 — "the `[daemon]` / `[gateway]` / `[duckbrain]` root sections are **not loaded** until FEAT-005 wires `LoadConfig`" (M9 §5, "Load caveat (F9-3)").
   Evidence: `config.LoadRootConfig(*configFile)` is called ten times in `cmd/schedulerd/main.go` (640, 673, 762, 854, 870, 968, 995, 1023, 1054, 1309), i.e. at daemon boot. `internal/config/loader.go:110` implements the three-layer merge. The repo's own `AGENTS.md:98` states "**Root schedulerd.toml layer is LIVE (FEAT-005 landed)**".
   The chapter took its caveat from `config.example.toml:12-16` — a stale NOTE in a file — not from the code. That is the precise failure the brief forbids: judging the document by another document's language. Consequence: an operator is told that editing a root section has no effect, which is false and will cause wrong configuration decisions.
   Fix: delete F9-3's "not loaded" claim; replace with the measured position — `LoadRootConfig` is called at boot from `main.go:640/673/…`, precedence is defaults → TOML → `SCHEDULER_*` → flags, and name the keys actually applied; keep only the true residue (the example header is stale; file it as a board row against `config.example.toml`).

2. FALSE CLAIM — M12 — "`grep -rn '8775|CF_PROXY|cf-inference-proxy' scripts/ config/ specs/` matches only `panel_loop.py:136`, `master_doc_skeleton.py:25/:211` … and `config/node.env.example:22` (a comment). The producer is the node over the tailnet … **UNVERIFIED**".
   Evidence: the quoted command is BRE, so `|` is literal and it returns **0** lines (measured). With `-E` it returns 4, and `config/node.env.example:22` is not a comment — it is the live assignment `ENV_CF_PROXY_API_KEY=*** line 26 of the same file sets `CONFIG_SET_MODEL_PROVIDER=cf-proxy`, which is the node's model provider wired straight at this proxy, consumed by `node_env.py`/provisioner config generation.
   Fix: re-run with `-E`, quote the four matches, name the real producer half (`config/node.env.example:22,26` → `scripts/node_env.py` → `~/.hermes/config.yaml model.provider=cf-proxy`) and restate M12-C1's state.

3. FALSE CLAIM — M2 — "`lane_target.py` … **active** … `tests/test_lane_target.py` exercises it (40 tests PASS this round); **no production caller in-repo**" (M2 §3 S2) and "F2-4 — `add_family_lanes.py`/`configure_family.py`/`load_lane_config.py` have no in-repo production caller (grep empty)".
   Evidence: `scripts/configure_family.py:17` `import lane_target` and `:149` `lane_target.parse(workdir)` — a production caller inside the repo. The stated grep also contradicts the chapter's own S1 row ("matches only the files themselves").
   Fix: correct the evidence to `configure_family.py:17,149`; re-derive S2's classification from that (active only if it is reached on a run path — otherwise `optional`), and delete F2-4.

4. FALSE CLAIM / UNVERIFIED — M3 — S2 evidence: "`land-node-branch.sh` … **active** | owns F5 LANDING; **invoked by the node's result envelope (M3-C2)**".
   Evidence: nothing invokes the script. `grep -rn land-node-branch` over `scripts/ tests/` matches only the script itself and `tests/selftest.sh:2465,2473,2502` (syntax + usage arms). The envelope *names* `branch`/`commit`; it does not call the lander. So the classification row's invoking line is fabricated — the one thing OUTLINE §3 says must be an actual `file:line`.
   Fix: state the truth — no in-repo invoker; the operator (or an out-of-repo foreman step) runs it with `--branch/--commit` from the envelope — and classify per the outline rule (optional), or produce the invoking line.

5. CONTRADICTION — README vs chapters, identity status, 4 of 13 modules.
   `docs/handbook/README.md` Part III: M5 "VERIFIED", M6 "VERIFIED", M9 "PARTIAL", M10 "PARTIAL".
   Chapters: M5 §1 "**UNVERIFIED**", M6 §1 "**UNVERIFIED**", M9 §1 "**UNVERIFIED**", M10 §1 "**UNVERIFIED**".
   The README is the document's own "honest status of every part" and closes with "Nothing in this file is marked green that a command has not produced". It marks green exactly the chapters its own text declares unverified. `PARTIAL` is also not in the schema's Status vocabulary (VERIFIED/UNVERIFIED/FAILING).
   Fix: one source of truth — generate the Part III table from the chapters' §1 Status fields, and drop `PARTIAL` from the Identity column.

6. OMISSION (systematic, 13 chapters) — the submodule inventory is missing four of the six fields OUTLINE §3 requires.
   OUTLINE:107-113 requires per submodule: "responsibility, owner, invocation, execution location, producer/consumer links, and classification". Every chapter's §3 table is `Submodule | Unit | Classification | Evidence` only — no responsibility, no owner, no execution location, no producer/consumer link. 47 submodule rows across M0–M12.
   Fix: either add the two missing columns and a per-row responsibility/owner/location sentence, or amend OUTLINE to the table actually delivered. As written the structure test the outline sets cannot be passed by any chapter.

7. CONTRADICTION — submodule count: 47 delivered, 34 claimed.
   Measured per chapter: M0 1, M1 5, M2 3, M3 3, M4 2, M5 5, M6 8, M7 1, M8 2, M9 5, M10 4, M11 4, M12 4 = **47**. OUTLINE line 95 ("13 modules, 34 submodules") and its Counts table (line 272) say 34; README I.4 repeats "13 modules, 34 submodules". The outline's own enumeration (lines 142-198) sums to 47.
   Fix: correct the arithmetic in OUTLINE and README to 47, or state which 13 are excluded and why.

8. OMISSION (blocking per the outline's own buildability test) — 11 of 16 flows have no chapter and no rendered text.
   OUTLINE Part II commits to 16 flows; F6–F10 and F11–F16 are marked MISSING in the outline itself, and F11–F16 are the six the quorum added. Chapters only *cite* F1/F2/F5/F11 in cross-references. README discloses this ("II.6–II.10 missing", F-ROOT-1) — disclosure is right, but the document still cannot tell a reader what the system does when a dependency disappears (F9), after a crash (F8), or at admission time (F11), which are the flows an operator needs most.
   Fix: render F11 and F9 first (they are cited by M9/M10/M2 and decide correctness), then F6/F7/F8/F10/F12–F16, or cut the outline's commitment to them and say so in the same breath as the census gap (I.9).

9. OMISSION — Parts IV (re-derived), V.2/V.3, VI, VII, VIII have no content.
   README admits: IV "stale — the register's 10 works / 6 broken / 2 missing is the outline's structure text, not re-derived"; VII.1/VII.2 "NOT WRITTEN"; VI "sits outside the delivered document and its promotion path is not maintained". OUTLINE Part VII is the work-derivation gate ("Acceptance gate per chapter") — with it unwritten the handbook cannot be turned into tasks, which is the outline's stated purpose (line 242: "Task list derived from chapters, each citing the section it closes").
   Fix: either write VII (the highest-value of the missing parts — it is what makes the rest actionable) or narrow the outline's Parts list to what is actually delivered.

10. UNVERIFIED — M2 — classification vocabulary and locators in the settings register.
   `CF_MAX_TURNS` "1..1000 (`:111`)" — :111 is `SECTION5_INTS = {`; the bounds and default are both on `:112`. `--interval` 15 "(`:1442`)" — default is `:1441`, `:1442` is the help string. `--wait-seconds` range "(`:1464`)" — the test is `:1463`. `--reply-to` "(`:1431`)" — `:1431` opens the argument; the default is `:1432`.
   This is the defect class the document itself polices (M9 F9-4 corrects :192→:195), applied unevenly.
   Fix: re-point each locator at the executable line; add a locator-lint pass over all chapters.

11. UNVERIFIED — M11 — "Complete inventory (all 23 `log()` sites" + evidence "`grep -n 'log(' dispatcher.py` (23 sites)".
   Measured: the quoted command returns **25** lines (`:81` a comment mentioning `log()`, `:112` the `def log(`). The inventory itself is right — 23 call sites (97,147,294,316,319,397,405,413,415,422,425,437,446,450,463,467,475,477,510,521,523,526,537) — so the claim is true and the *command* is wrong.
   Fix: quote `grep -n 'log(' dispatcher.py | grep -v 'def log'` and state 23 call sites in 25 matching lines.

12. UNVERIFIED — M9 — `boardOwnedByLane` located at "`:208+`".
   The function is `admission_mode.go:177`; `:208` is `tasksAdmissionDue`. The override precedence is correct as prose (project override → filesystem derivation, call site `:234`), only the locator is wrong.
   Fix: `admission_mode.go:177` (definition), `:234` (call).

13. UNVERIFIED — M7 — installation-token POST cited at "`:367-369`".
   `:367-369` is `make_jwt`; the POST is `:370-371` (`"%s/app/installations/%s/access_tokens"`).
   Fix: re-point to `:370-371`.

14. UNVERIFIED — M6 — "`gen_nasa_handbook.py:17` hardcodes `MODULES = REPO/\"docs/master\"`".
   The assignment is `:18`; `:17` is `REPO = …`.
   Fix: `:17-18`.

15. UNVERIFIED — M4 — "`grep -rn boardctl scripts/` matches only `board_lock.py:98/:100` … and `gen_unit_map.py:45`".
   Measured: it also matches `board_lock.py:18`, six lines of `scripts/boardctl` itself (2, 9, 11, 15, 16, 21), and two `.pyc` files. The *conclusion* (no in-repo producer calls `boardctl create`) survives; the quoted evidence does not reproduce.
   Fix: re-quote with `--include=*.py --include=*.sh` and state the full match set.

16. CONTRADICTION — README Part II flow set differs from OUTLINE Part II.
   README II.3 is "MEMORY"; OUTLINE F3 is "RUN CAPTURE AND SEARCH". README lists 10 flows, OUTLINE 16 (F11–F16 absent from README entirely). Chapters cross-reference "F11 SCHEDULING ADMISSION" and "F5 LANDING" — a reader following a cross-reference into the README finds a different flow with a different name.
   Fix: derive the README's flow table from OUTLINE Part II, verbatim ids.

17. CONTRADICTION (count) — README "**6** name both producer and consumer `file:function` (M2-C1, M2-C2, M10-C1, M10-C3, M11-C1, M11-C2)".
   M10-C3's consumer cell reads "scheduler `dispatchReplyVerdict`" — a function with no file, in a chapter whose own rule is file:function. Strict count is **5** of 25. (Row total 25 checks out: 1+2+2+2+2+2+2+1+1+3+3+2+2.)
   Fix: give M10-C3 `internal/scheduler/dispatch_leg.go:713`, then the 6 holds.

18. UNVERIFIED — M1 — the blocking defect is correctly cited but the module is stamped UNVERIFIED while §2 asserts its own live defect as fact.
   Verified: `bunker-provision.sh:214` probes `[ -s "$HOME/.node/auth/github.token" ]`; `:233` prints `token file installed, mode 600 (value not read)`. The claim is **true** and well-cited — noted here because it is the model the other chapters should follow (claim + executable line + the consequence), and because §1's "UNVERIFIED — S1–S4 unit bodies not read line-by-line" is honest about its own coverage.

19. PADDING — none material. Prose in all 13 chapters is load-bearing; "what breaks if it lies" is used substantively in M0/M1/M3/M5/M9/M11 rather than as decoration. M10 §2's "Every node↔scheduler message rides crier" is the only unsupported absolute (the inference proxy is a node↔host path that does not ride it) — tighten to "every dispatch and completion message".

20. FALSE CLAIM (soft) — M10 §2 absolute. See 19.

DEFECT CLASSES
- stale-document-as-authority (M9 F9-3: a config-file NOTE read as code truth)
- broken-evidence-command (BRE vs ERE; grep that cannot return the quoted result — M12, M11, M4, M2)
- false-negative classification (unit called "active" with no invoking line; "operator-invoked" invented outside the outline's vocabulary — M2, M3, M5, M6)
- fabricated invocation (M3 S2 "invoked by the node's result envelope")
- self-contradiction between the status table and the chapters it indexes (README vs 4 chapters)
- arithmetic that does not survive a recount (34 vs 47 submodules)
- locator drift by one or two lines, applied selectively (:192→:195 corrected, :111/:1441/:1463/:177/:370/:18 not)
- outline-vs-delivery scope gap (Parts II/IV/V/VI/VII/VIII unwritten, 11 of 16 flows absent)
- undisclosed absolute ("every message rides crier")

CHAPTER SCORECARD (against the four admissibility rules + the outline's heading set)
- M0 SHARED CONTRACT — PARTIAL. Every locator re-verified exactly (78 lines; :5-9, :11, :19-42, :22, :26, :48-57, :54, :67-70, :75-78; source counts 11 and 17 reproduced). Metrics RED declared. Missing: the outline's per-submodule responsibility/owner/location/producer fields; `FAILED=${FAILED:-0}` is an env-read surface the register calls "no env-var surface".
- M1 PROVISIONING — PARTIAL. Best-evidenced chapter: `:181/:182/:214/:233` and `disk_floor.py:36/:37/:38-39/:122-125/:126-141` all exact; `project-node.sh:173` caller verified (the F1-4 correction is right). Blocked by unread unit bodies declared in its own status, and the same four missing per-submodule fields.
- M2 DISPATCH — PARTIAL. Reply shape `:1128-1144`, `status` at `:1132`, `dispatch_wall` `:1152-1157` (int-conversion of a sub-1 float → 0) all verified; `configure_family.py:24-28` PID hardcode verified verbatim. Fails on finding 3 (false "no production caller") and 10 (four locators off by one).
- M3 REPOSITORY — PARTIAL. `GATE=""` at `:36`, gate-only-when-set `:171-193`, `LANDED` `:291`, `FAIL` `:294`, push `:265`, `ls-remote` warn `:284-287` all exact; the hook `exit 0` at `install-gitreins.sh:130-131` and the executable+string check at `:59-63` are exact, and I reproduced the dry-run refusal (`workdir_clean`). Fails on finding 4 (fabricated invoking line).
- M4 BOARD — PARTIAL. Strongest measured chapter: 357 rows, 515 events, `boardctl validate` → "RESULT: OK (7 warning(s))" with all seven warning kinds named correctly, `board_drift` RESULT OK at HEAD==origin/main `943ef98`, 20 subcommands verified, duplicate-id refusal real. Fails on finding 15 (non-reproducing grep evidence) and on calling the external binary's rows UNVERIFIED while still asserting a "works" state for M3-C1 in the same table style.
- M5 HARNESS — PARTIAL. `harness-vars.sh:28-29` (12 declared), `:31` (6 required), `:203` `[0-7]00`, `:204` "must be 600", `:276-277` 40/1800, `:280-287` ranges, `install-hermes.sh:27-30/:108-115` all exact; F5-2 (resolver unwired; `node-bus-worker.py:407-409,459-469`, `dispatcher.py:260`) verified. Fails as a chapter because it is stamped UNVERIFIED while README calls it VERIFIED, and S2's "active (installed/checked by operator)" is a classification contradiction.
- M6 DOCUMENTATION — PARTIAL. `DEFAULT_ROOTS` `:52`, glob `:188`, VERIFIED-needs-3-locators `:128-138`, `MASTER-DOC` `:263` verified, and I reproduced the gate: 44 modules / 37 VERIFIED / 50 errors / 0 warnings / 10 facts / FAIL. F6-2 (structural gate, not a truth gate) is the single best correction in the set. Fails on finding 14 (locator) and on the README status contradiction.
- M7 GITHUB — PARTIAL. `:346-351` 0600 refusal with the exact message, `:362` `mint()`, `:579` destination, `:719-723` `--if-older` all verified; the credential-domain separation (F7-3) is correct. Fails on finding 13.
- M8 SAFETY — PARTIAL. Most complete small chapter: `:14-22` constants, `:21` AGED_PARENTS, `:25-39` safety_reason, `:42/:44-47` TTL and root guards, `check_scan_scope.py:31-32/:64-68/:110/:112` all exact; `tests/test_reclaim.py` 9 tests OK and `15 gitleaks claim(s)` reproduced. Only the shared per-submodule-field gap blocks it.
- M9 SCHEDULER — PARTIAL, and the most dangerous chapter in the set. Binary defaults `main.go:108-145` verified value-for-value (30s/24h/10/100/10/false/7200s/5s/30m/3/5m/60s/0/8), 30 tables, 379 `log.Printf`, `dispatch_leg.go:713-726` reads only `payload["ok"]` with absence-as-success, `go build` PASS — all exact, and it honestly declares its own `go test` FAIL and a 2-of-379 log inventory. But finding 1 inverts an operator-facing fact (root config sections *are* live), which is exactly the failure the chapter's own metric says it exists to prevent.
- M10 CRIER — PARTIAL. `config.go:622/:627/:628/:629/:673`, 91 `*_test.go`, 1895-line handler, `HandleRegister:598`/`Deliver:990`/`Retrieve:1690`/`Ack:1812`, the three guard metric names at `metrics.go:19-49`, the signed-read order and the `:204` 404, and `go test ./internal/registry` PASS — all verified. Blocked by the README status contradiction and the §9 non-exhaustive inventory it admits.
- M11 DISPATCHER — WRITTEN except its metrics field. 538 lines, `CF_DURABLE_JOB` switch `:336`, `ok` at `:501`, deliver `:508`, ack `:519`, all 23 log sites present with correct strings and lines, F11-3 (`:479` before `:481`), F11-4 (`:185-197`), F11-5 (serial loop) and F11-6 all correct. Its only defect is finding 11 — a wrong verification command over a right claim.
- M12 INFERENCE PROXY — PARTIAL. sha256 reproduced (`b12a0ac5…e0b5`), 273 lines, `:43-62` settings exact, `:130/:154/:158/:164/:204/:236-238` exact, the F12-4 `[200, 502]` analysis is correct on the code and is the sharpest observation in the set. Fails on finding 2, which is the difference between "unproven" and "wired by config".

SUMMARY
The chapters are, on the whole, source-grounded: of roughly 120 locators I re-ran, about 100 land exactly, and the four or five defects the writers self-report (F1-1 mode-600 lie, F6-2 status-not-recomputed, F9-4 locator, F11-2 tests that cannot fail, F12-4 streaming 502) are all real and correctly located. That is a different document from the one the owner rejected.

It still fails, for three reasons that are structural rather than stylistic:

(a) The one claim most likely to be acted on by an operator — that root config sections are inert — is false, and false because the writer believed a comment in a config file over ten call sites in `main.go`. The same mechanism (a quoted command or a document taken as evidence without being re-run) produces the M12 "unproven" verdict, the M3 "invoked by the envelope" line, and the M2 "no production caller" line.

(b) The document contradicts itself where a reader will look first: its own status table marks green four chapters that declare themselves unverified, counts 34 submodules where 47 are delivered, and names flow II.3 "MEMORY" where the outline names it "RUN CAPTURE AND SEARCH".

(c) The outline commits to eight parts and sixteen flows; the delivery is one part and five flows, with eleven absent — including F11 admission, which M9 and M10 both lean on. Disclosure in README is honest, but disclosure is not coverage, and the outline's own §I.9 rule ("a set that claims coverage it does not have was the root complaint") applies to the document as a whole.

Fix order for the next iteration: finding 1 (it is a lie about the running system), finding 2, findings 3–4, then the README/chapter reconciliation and the count — those are cheap and remove the credibility damage — then the four missing submodule fields, then F11 and F9 as the first two flows. M11 and M8 are one edit away from WRITTEN; M9 and M12 are one correction away from being trustable.

PANEL REVIEW COMPLETE

session_id: local-28fdc62ffc8c3ed6faad7edd2c1da87686b93c2861f7e9738dc9040c7ea5a04d

EXIT=0
```

### kimi

```
VERDICT: FAIL

BLOCKING: 71 — findings that must be fixed before this chapter can be called written

NON-BLOCKING: 5

FINDINGS:

B01 | UNBUILDABLE | HANDBOOK
  claim: the outline commits to PART I through PART VIII.
  evidence: `docs/handbook/README.md:46-50` says “This round's deliverable is Part III only” and that Parts I, II.6–II.10, IV, V, VI, VII and VIII “have no chapters”; `find docs/handbook/chapters` returns only `M0`–`M12`.
  fix: write the missing arrangement, flow, contract-register, settings, risk, work-derivation and delivery-mechanism parts, or reduce the outline to what is actually delivered.

B02 | CONTRADICTION | OUTLINE
  claim: “Submodule chapters | 25 | 34”.
  evidence: `OUTLINE.md:272` claims 34, but the module inventory at `OUTLINE.md:142-198` contains 47 `S<n>` entries; measured with `awk ... | grep -oE 'S[0-9]+' | wc -l` → 47.
  fix: correct the count or remove 13 submodule entries from the outline.

B03 | CONTRADICTION | README
  claim: “6 name both producer and consumer `file:function`”.
  evidence: `README.md:95-103`; measured against the 25 chapter contract rows, only M10-C1 and M11-C1 name both sides as `file:function`. M11-C2 is inline code with no function named; the M2 rows each omit one function name; the remaining rows are external, file-only or one-sided.
  fix: restamp the README from the round-4 chapters and the exact two-sided rule.

B04 | UNVERIFIED | M0
  claim: M0-C1 consumer is “**rumour — one side only**”.
  evidence: `M0-shared-contract.md:73-78`; the chapter explicitly leaves the bunker exec consumer unnamed.
  fix: name the external bunker API/handler and its compatibility rule, or mark the contract UNVERIFIED rather than “works”.

B05 | UNVERIFIED | M0
  claim: “staged probe `ffc_probe.sh`”.
  evidence: `M0-shared-contract.md:82-90`; `find /home/kara/code-factory -name '*ffc_probe*'` found no such shipped probe.
  fix: ship the probe at a durable path and quote the exact repeatable command and output.

B06 | UNVERIFIED | M0
  claim: “`lib.sh` emits no counters, gauges or histograms”.
  evidence: `M0-shared-contract.md:92-96`; the negative claim has no repo-wide grep command or output attached.
  fix: attach an absence-proof command and output, or emit metrics.

B07 | UNVERIFIED | M1
  claim: “the remaining unit bodies … not read line-by-line”.
  evidence: `M1-provisioning.md:12` and `:41-43` admit `node_identity.py`, `node_seed.py`, `node_seed_drift.py`, `node_env.py`, `node_freshness.py` and `bunker_config_gen.py` were not read.
  fix: read and verify those units before calling the module documented.

B08 | FALSE CLAIM | M1
  claim: M1-C1 consumer is `internal/registry/handler.go:598 HandleRegister` for `POST /agents/{id}`.
  evidence: `crier/internal/registry/handler.go:596-599` says `HandleRegister` handles `POST /agents`; the id-in-path spelling is `HandleRegisterByID` at `:613-614`.
  fix: cite `HandleRegisterByID` for `/agents/{id}` or correct the route.

B09 | UNVERIFIED | M1
  claim: M1-C1 producer is “`bunker-crier-connect.sh`” and the state is UNVERIFIED.
  evidence: `M1-provisioning.md:90`; the producer has no function name and the token exchange was not rerun.
  fix: name `file:function` on both sides and run a credential-exchange fixture.

B10 | UNVERIFIED | M1
  claim: M1-C2 consumer is “**rumour — one side only**”.
  evidence: `M1-provisioning.md:91`.
  fix: identify the bunker daemon handler or mark the external boundary UNVERIFIED without a “works” verdict.

B11 | UNVERIFIED | M1
  claim: the certification ladder command is `scripts/verify-node.sh --agent <id> --server <host>`.
  evidence: `M1-provisioning.md:100` says “not run this round” and requires a live node.
  fix: provide a live-node fixture or a hermetic substitute and record the actual per-leg result.

B12 | UNVERIFIED | M1
  claim: “No provisioner script exports counters, gauges or histograms”.
  evidence: `M1-provisioning.md:102-105`; no absence-proof grep is attached.
  fix: quote the negative-search command and output, or add metrics.

B13 | OMISSION | M1
  claim: §5 is the settings register.
  evidence: `M1-provisioning.md:70-75` covers only four rows, while `verify-node.sh:23-32` adds `--agent --server --port --artifact --strict-freshness --strict-seed`, `bunker-provision.sh:564-584` adds the provisioning flag surface, `node_seed.py:373-392` adds build/apply/check flags, and `node_freshness.py:674-690` adds mode/path/timeout/json flags.
  fix: register every flag, environment variable, timeout and cap with default, range and consequence.

B14 | UNVERIFIED | M2
  claim: M2-C1 and M2-C2 satisfy the two-sided contract rule.
  evidence: `M2-dispatch.md:83-84`; neither row names both endpoints as `file:function`. The actual node functions are `process` at `node-bus-worker.py:972` and `deliver` at `:1160`.
  fix: write the producer and consumer as `file:function` on both rows.

B15 | UNVERIFIED | M2
  claim: the bus-worker ladder passed on cf-node but is “not repeatable from this control host”.
  evidence: `M2-dispatch.md:97`.
  fix: ship a fixture or the cf-node command and captured output in the evidence record.

B16 | UNVERIFIED | M2
  claim: “The node-side dispatch path emits no counters or gauges”.
  evidence: `M2-dispatch.md:99-102`; no absence-proof command is attached.
  fix: attach the negative grep/output or emit metrics.

B17 | OMISSION | M2
  claim: §5 is the node-worker settings register.
  evidence: `M2-dispatch.md:67-77` omits `DEFAULT_TIMEOUT` and `DEFAULT_HARNESS_WALL` from `node-bus-worker.py:80-84`, `CRIER_AUTH_TOKEN` at `:454-457`, and most CLI flags at `:1377-1450` including `--check --once --loop --dry-run --home --identity --bus-identity --key --token-file --agent --project --crier --workdir --harness-cmd --gateway-port --limit --lease-seconds`.
  fix: enumerate every one with default, range and consequence.

B18 | CONTRADICTION | M2
  claim: “M0 SHARED CONTRACT is the CF_* contract source”.
  evidence: `M2-dispatch.md:149`; M0 says the variable contract is “not part of M0” at `M0-shared-contract.md:14-16`, while M5 says M5 owns it at `M5-harness.md:159-160`.
  fix: make M2 point to M5.S5 as the CF_* owner.

B19 | FALSE CLAIM | M3
  claim: “Status | VERIFIED … `repo_freshness.py` not read line-by-line”.
  evidence: `M3-repository.md:12`; a module containing an unread unit cannot carry an unqualified VERIFIED status.
  fix: read `repo_freshness.py` or downgrade the identity status.

B20 | FALSE CLAIM | M3
  claim: S1 is “active” while “operator-invoked; no in-repo caller”, and S2 is “invoked by the node's result envelope”.
  evidence: `M3-repository.md:37-39`; `node-bus-worker.py:1141-1142` only emits `branch`/`commit` fields, and a grep of `scripts/`/`tests/` finds only self-tests and documentation invoking `land-node-branch.sh`.
  fix: reclassify operator-only units as optional and replace the envelope-invocation claim with the actual caller or “none”.

B21 | UNVERIFIED | M3
  claim: M3-C1/M3-C2 are valid contracts.
  evidence: `M3-repository.md:84-89`; M3-C1 names an external remote with no consumer function, and M3-C2 names line ranges but no producer/consumer functions.
  fix: name both implementations or mark the external boundary UNVERIFIED.

B22 | UNVERIFIED | M3
  claim: the dry-run verification is repeatable.
  evidence: `M3-repository.md:97` says it was “refused on a dirty/scratch workdir” and needs a clean git-worktree fixture.
  fix: ship the fixture setup command and the expected `LAND: DRY-RUN` output.

B23 | UNVERIFIED | M3
  claim: “Landing and freshness emit no counters”.
  evidence: `M3-repository.md:105-108`; no absence-proof command is attached.
  fix: quote the search or add metrics.

B24 | OMISSION | M3
  claim: §5 is the repository settings register.
  evidence: `M3-repository.md:69-78` omits `SCHEDULER_DB`/`--db` from `clone_lane.py:20-21` and `:51-62`, and the landing flags from `land-node-branch.sh:71-79` (`--workdir --branch --commit --remote --main --ff-only --no-ff --dry-run`).
  fix: register each omitted control.

B25 | UNVERIFIED | M4
  claim: M4-C1/M4-C2 are honest contracts.
  evidence: `M4-board.md:67-73` says every side is external and both states are UNVERIFIED.
  fix: either identify the external implementations and run the wire, or leave the contracts explicitly unwritten.

B26 | UNVERIFIED | M4
  claim: lock adjudication verification exists.
  evidence: `M4-board.md:83` says it was “not re-run this round”.
  fix: run held and unheld lock fixtures and quote `RESIDUE`/`HELD` outputs.

B27 | UNVERIFIED | M4
  claim: “The board emits no counters or gauges as a service”.
  evidence: `M4-board.md:93-96`; no absence-proof command is attached.
  fix: quote the search or emit metrics.

B28 | OMISSION | M4
  claim: §5 is the board settings register.
  evidence: `M4-board.md:56-61` omits `board_lock.py`'s positional lock path (`board_lock.py:165-170`) and `board_drift.py`'s `--workdir --ref --repo --published-dir --no-head` (`board_drift.py:193-199`).
  fix: add every board-tool control.

B29 | UNVERIFIED | M5
  claim: foreign installer bodies are documented.
  evidence: `M5-harness.md:12` says `install-claude-code.sh`, `install-deepseek.sh`, `install-pi-agent.sh` and `install-opencode.sh` were not read line-by-line; `install-codex.sh` is only partial.
  fix: finish the source reads or downgrade the affected submodule claims.

B30 | UNVERIFIED | M5
  claim: M5-C1/M5-C2 are valid contracts.
  evidence: `M5-harness.md:98-99`; both consumers are external or “rumour — one side only”.
  fix: name both sides or mark the contracts UNVERIFIED without “works”.

B31 | UNVERIFIED | M5
  claim: harness conformance is the certification evidence.
  evidence: `M5-harness.md:108` says `tests/harness-conformance.sh` was “not run this round”.
  fix: run it on a real node and record every leg, or mark all certified-adapter claims UNVERIFIED.

B32 | UNVERIFIED | M5
  claim: S1/S2/S3 are “active” and S1 is “certified by the conformance battery”.
  evidence: `M5-harness.md:40-44` cites no scheduler, cron or production invoking line; the conformance battery is simultaneously unrun at `:108`.
  fix: cite the invoking line and current conformance output, or reclassify the installers.

B33 | UNVERIFIED | M5
  claim: “No harness installer or resolver emits counters or gauges”.
  evidence: `M5-harness.md:110-113`; no absence-proof command is attached.
  fix: quote the search or emit metrics.

B34 | OMISSION | M5
  claim: §5 is the harness settings register.
  evidence: `M5-harness.md:74-87` omits installer controls such as `NODE_GATEWAY_PORT`, `HERMES_PIN`, `HERMES_PYTHON_BIN` (`install-hermes.sh:23-30`), `CF_CODEX_PIN`, `CF_TURN_TOKEN`, `CF_TURN_FILE` and the codex timeout default (`install-codex.sh:49-60`), plus the installer mode flags.
  fix: add every installer setting and flag with consequence.

B35 | UNVERIFIED | M6
  claim: the documentation module is documented while its own gate fails.
  evidence: `M6-documentation.md:12`; rerunning `python3 scripts/master_doc_check.py` produced `44 module(s): 37 VERIFIED, 50 error(s)`, `MASTER-DOC: FAIL`, exit 1.
  fix: repair the stale locators/root selection and rerun the gate to PASS, or keep the chapter explicitly FAILING.

B36 | UNVERIFIED | M6
  claim: M6-C1/M6-C2 are valid contracts.
  evidence: `M6-documentation.md:89-90`; both consumers are external, and M6-C1 still says “works” without a consumer function.
  fix: name both implementations or mark the boundary UNVERIFIED.

B37 | OMISSION | M6
  claim: §9 is the log-line inventory.
  evidence: `M6-documentation.md:106-114` lists two lines, while `master_doc_check.py:179-180`, `:197-199` and `:258-264` contain additional operator-visible failure and summary lines not inventoried.
  fix: inventory every operator-visible line or scope the section to a named subset.

B38 | UNVERIFIED | M6
  claim: “The documentation pipeline emits no counters or gauges”.
  evidence: `M6-documentation.md:101-104`; no absence-proof command is attached.
  fix: quote the search or emit metrics.

B39 | OMISSION | M6
  claim: §5 is the documentation settings register.
  evidence: `M6-documentation.md:77-83` omits the fill CLI at `master_doc_fill.py:393-422`, renderer `--out/--html` at `gen_nasa_handbook.py:247-250`, and panel-loop paths/models at `panel_loop.py:30-37`.
  fix: register every control.

B40 | UNVERIFIED | M6
  claim: S1 and S4 are “active”.
  evidence: `M6-documentation.md:39-46` cites entrypoints but no scheduler/cron/other-unit invoking line; the panel-loop paths are dated scratch paths at `panel_loop.py:30-37`.
  fix: provide durable invocation evidence or reclassify the submodules.

B41 | UNVERIFIED | M7
  claim: the GitHub credential module is documented.
  evidence: `M7-github.md:12` and `:79` admit the token mint was not run because App credentials are absent.
  fix: run a fixture against a local API base or mark mint behaviour UNVERIFIED.

B42 | UNVERIFIED | M7
  claim: M7-C1 “works” while the consumer is “rumour — one side only”.
  evidence: `M7-github.md:70`.
  fix: name the GitHub API operation and compatibility contract, or remove the works verdict.

B43 | FALSE CLAIM | M7
  claim: S1 is “active”.
  evidence: `M7-github.md:31`; a grep of `scripts/` and `config/` finds no timer/cron/scheduler invocation, only `github-app-setup.sh` printing manual refresh instructions at `:201` and `:284`.
  fix: reclassify as operator-invoked or wire and cite the actual timer.

B44 | UNVERIFIED | M7
  claim: “No counters or gauges”.
  evidence: `M7-github.md:81-84`; no absence-proof command is attached.
  fix: quote the search or emit metrics.

B45 | OMISSION | M7
  claim: §5 is the credential settings register.
  evidence: `M7-github.md:54-64` aggregates the refresh flags into one row without per-flag defaults/ranges, while `github-app-refresh.sh:37-53` defines eleven flags and `:58` defines the token-file default.
  fix: one row per setting, each with default, range and consequence.

B46 | UNVERIFIED | M8
  claim: M8-C1 “works” while its consumer is “rumour — one side only”.
  evidence: `M8-safety.md:67`.
  fix: name the filesystem-side contract or mark the external boundary UNVERIFIED.

B47 | UNVERIFIED | M8
  claim: “No counters or gauges”.
  evidence: `M8-safety.md:77-80`; no absence-proof command is attached.
  fix: quote the search or emit metrics.

B48 | OMISSION | M8
  claim: §5 is the safety settings register.
  evidence: `M8-safety.md:57-61` omits the `targets` subcommand and `--json` at `reclaim_disk.py:129-137`, and `check_scan_scope.py`'s optional repo-root positional argument at `check_scan_scope.py:18-22`.
  fix: add the missing controls.

B49 | UNVERIFIED | M9
  claim: the scheduler's verification state is documented.
  evidence: `M9-scheduler.md:100-104`; rerunning `go test ./...` at `1771d3aa` failed with `SCHED-GAP-1726 goroutine census: 1 goroutine(s) still parked in evalDrain at suite exit`, exit 1.
  fix: fix the liveness leak and rerun the full suite green.

B50 | UNVERIFIED | M9
  claim: M9-C1/M9-C2/M9-C3 are valid contracts.
  evidence: `M9-scheduler.md:90-92`; M9-C1 has no producer function, M9-C2 has no consumer `file:function`, and M9-C3 has no producer `file:function`.
  fix: name both implementations on every row.

B51 | OMISSION | M9
  claim: §9 is a sample, “not an inventory”.
  evidence: `M9-scheduler.md:125-127`; measured `grep -rn "log.Printf" internal/scheduler/*.go | wc -l` → 379 call sites, while the chapter lists two.
  fix: produce the complete operator-line inventory or explicitly narrow the schema for this module.

B52 | OMISSION | M9
  claim: §5 is the scheduler settings register.
  evidence: `M9-scheduler.md:63-78` omits most daemon flags from `cmd/schedulerd/main.go:95-107` and `:148-208`, including `--db --listen --tls-cert --tls-key --public-url --peer-freshness-window --spawn-mem-limit-mb --board-stasis-gate --hooks-file --session-silence-grace --session-poll-loop-min-ticks --disable-tick-push --duckbrain-* --simulate --gateway-url --gateway-key --no-exec-fallback --foreman-home --config --log-file --show-config`.
  fix: enumerate every flag and environment override.

B53 | UNVERIFIED | M10
  claim: the crier chapter is source-verified.
  evidence: `M10-crier.md:12` and `:121-123` admit the 1895-line handler was not read line-by-line and the log inventory is not exhaustive.
  fix: complete the read or downgrade S1 and §9.

B54 | UNVERIFIED | M10
  claim: M10-C2/M10-C3 satisfy the two-sided contract rule.
  evidence: `M10-crier.md:83-84`; M10-C2 names no node function, and M10-C3 does not give the scheduler consumer as `file:function`.
  fix: write both sides as `file:function`.

B55 | FALSE CLAIM | M10
  claim: M10-C1 is “broken — CF-354 (node reads `text`)”.
  evidence: `M10-crier.md:82`; the named producer emits `text_b64` at `scheduler/internal/bus/dispatch.go:192-202` and the named crier consumer is only `HandleDeliver` at `crier/internal/registry/handler.go:990-991`. The failure occurs downstream in `node-bus-worker.py:986`.
  fix: move the broken state to the node-consumption contract or split transport acceptance from payload semantics.

B56 | OMISSION | M10
  claim: §8 is the crier metrics inventory.
  evidence: `M10-crier.md:102-110` lists only guard metrics and two gauges; a metrics grep finds additional production series including `crier_delivery_accepted_total` and `crier_guard_decisions_total` (`internal/registry/handler.go:38-44`), capability metrics (`internal/registry/capability.go:99-105`), inbox ownership metrics (`internal/registry/ownership.go:35-43`), middleware, webhook, harness and store gauges.
  fix: inventory every metric with type, labels, question and scrape path.

B57 | OMISSION | M10
  claim: §9 is the log-line inventory.
  evidence: `M10-crier.md:121-123` admits it is “not exhaustive”.
  fix: complete the inventory or mark the field UNWRITTEN.

B58 | OMISSION | M10
  claim: §5 is the crier settings register.
  evidence: `M10-crier.md:62-70` uses aggregate rows with range “—” and omits `AuthToken`, `LogLevel`, `LogFormat` (`config/config.go:624-626`), MCP (`:634`), Federation (`:656-659`) and Database (`:660-665`) settings.
  fix: one row per setting with default, valid range and consequence.

B59 | UNVERIFIED | M10
  claim: the signed-read ladder passed on cf-node.
  evidence: `M10-crier.md:93` says it is “not repeatable from this control host”.
  fix: provide the cf-node fixture/output or a local hermetic equivalent.

B60 | FALSE CLAIM | M11
  claim: “Status | VERIFIED”.
  evidence: `M11-dispatcher.md:12` simultaneously says the synchronous `CF_DURABLE_JOB=0` path is unmeasured; that path is real code at `crier-fleet/dispatcher.py:334-358`.
  fix: test the synchronous path or downgrade status to UNVERIFIED.

B61 | UNVERIFIED | M11
  claim: `tests/test_durable_job.py` and `tests/test_job_kill.py` are verification checks.
  evidence: `M11-dispatcher.md:83`; a grep for `assert`, `raise` or `exit` in both files returns nothing, so they cannot fail.
  fix: add failure oracles and rerun them.

B62 | OMISSION | M11
  claim: §5 is the dispatcher settings register.
  evidence: `M11-dispatcher.md:57-69` omits `CRIER_URL`, `TOKEN_FILE`, `KEYS`, `DISPATCH_EXEC_TIMEOUT` and the hardcoded `FLEET` root from `dispatcher.py:33-68`.
  fix: register every environment variable, path and timeout.

B63 | UNVERIFIED | M11
  claim: “The dispatcher emits no counters, gauges or histograms”.
  evidence: `M11-dispatcher.md:88-92`; no absence-proof command is attached.
  fix: quote the search or emit metrics.

B64 | FALSE CLAIM | M11
  claim: `client for %s failed` presents as “Node unreachable”.
  evidence: `M11-dispatcher.md:129`; `client_for` at `dispatcher.py:130-132` only constructs a `Crier` from the local bus URL, key path and token, and performs no network call.
  fix: relabel the failure as local credential/client configuration until a network operation proves node unreachability.

B65 | FALSE CLAIM | M12
  claim: “There is no anonymous path and no fallback”.
  evidence: `M12-inference-proxy.md:84-86`; the code explicitly exposes `GET /health` with no auth at `cf-inference-proxy.py:12` and `:126-127`.
  fix: qualify the claim as “no anonymous paid/model path”.

B66 | FALSE CLAIM | M12
  claim: “Status | VERIFIED”.
  evidence: `M12-inference-proxy.md:12`; M12-C1's producer is unproven at `:75`, and the valid-token disallowed-model check was not rerun at `:95`.
  fix: prove the node client half and the 403 check, or downgrade status.

B67 | UNVERIFIED | M12
  claim: M12-C1/M12-C2 are valid contracts.
  evidence: `M12-inference-proxy.md:75-82`; M12-C1 has no producer and M12-C2 has an external one-sided consumer.
  fix: name the node client implementation and the upstream API contract, or mark both UNVERIFIED.

B68 | UNVERIFIED | M12
  claim: the disallowed-model admission check was reproduced.
  evidence: `M12-inference-proxy.md:95` says it was “not re-run by this writer”.
  fix: run it with a test token and quote the 403 body.

B69 | OMISSION | M12
  claim: §5 is the inference-proxy settings register.
  evidence: `M12-inference-proxy.md:59-64` omits `TOKENS_PATH`, `ENV_PATH`, `USAGE_LOG` and `CAPTURE_LOG` (`cf-inference-proxy.py:48-52`) and the 300-second upstream timeout (`:204`, `:241`).
  fix: add every path, timeout and capture control.

B70 | UNVERIFIED | M12
  claim: “The proxy emits no counters, gauges or histograms”.
  evidence: `M12-inference-proxy.md:97-102`; no absence-proof command is attached.
  fix: quote the search or emit metrics.

B71 | UNVERIFIED | M12
  claim: S1 is “active (control-host service; operator/systemd-invoked…)”.
  evidence: `M12-inference-proxy.md:32`; a grep of `scripts/`, `config/` and `specs/` finds only self-references and a commented env example, with no systemd unit or invocation evidence.
  fix: provide the service unit/process evidence or reclassify the submodule.

N01 | NON-BLOCKING | M0
  claim: PASS/FAIL rows are descriptive, not evidentiary.
  evidence: `lib.sh:6-9` prints unconditionally from caller-supplied arguments; the chapter correctly classifies this at `M0-shared-contract.md:100-107`.
  fix: system improvement only: add correlated run IDs or structured evidence rows.

N02 | NON-BLOCKING | M4
  claim: board validation returns seven warnings.
  evidence: rerunning `scripts/boardctl validate` returned `RESULT: OK (7 warning(s))`: free-form guard/CI values, priority/title disagreements, a duplicate event id and a headerless board.
  fix: clean the board rows; the chapter accurately reports the state.

N03 | NON-BLOCKING | M10
  claim: metrics are default-ON despite a stale “opt-in” comment.
  evidence: `config/config.go:667-673` sets `EnableMetrics: true`; `internal/metrics/metrics.go:5` still says “opt-in”.
  fix: update the stale comment; the chapter already flags the contradiction.

N04 | NON-BLOCKING | M12
  claim: the startup diagnostic hardcodes `API_SERVER_KEY`.
  evidence: the selector is configurable at `cf-inference-proxy.py:47`, but the error at `:269` prints `API_SERVER_KEY` unconditionally.
  fix: print `UPSTREAM_KEY_ENV`; the chapter already documents the defect.

N05 | NON-BLOCKING | M11
  claim: `CF_DURABLE_JOB=0` selects a legacy synchronous path.
  evidence: `dispatcher.py:334-358`; the chapter documents the bypass at `M11-dispatcher.md:145-148`.
  fix: remove the legacy path or add deadline/failure tests; the chapter blocker is its unmeasured state, already counted above.

DEFECT CLASSES:
  missing handbook parts
  stale structure/count
  stale README status
  one-sided contracts
  wrong file/function citation
  unread code behind VERIFIED claims
  unsupported active classifications
  unrepeatable verification commands
  decoration tests without oracles
  unproven negative metrics claims
  incomplete settings registers
  incomplete metrics inventories
  incomplete log inventories
  cross-chapter ownership contradiction
  live test/build failure

CHAPTER SCORECARD:
  M0 — PARTIAL: real source read and repeatable syntax/count checks, but the only contract is one-sided, the fail-closed probe is not shipped, and the metrics absence is unproven.
  M1 — PARTIAL: substantial provisioning evidence, but several units are unread, one crier citation names the wrong registration function, both contracts are incomplete, the live ladder is unrun, and settings/metrics are incomplete.
  M2 — PARTIAL: the node worker path is well evidenced, but both contracts lack exact function names, the live check is not repeatable, the CF_* ownership cross-reference contradicts M0/M5, and settings/metrics are incomplete.
  M3 — PARTIAL: landing code is well covered, but VERIFIED is claimed despite an unread unit, active/invocation claims are false, contracts are incomplete, the dry-run fixture is missing, and settings/metrics are incomplete.
  M4 — PARTIAL: the store census, drift and validation were reproduced, but both contracts remain external/UNVERIFIED, lock adjudication was not run, and settings/metrics are incomplete.
  M5 — PARTIAL: the CF_* contract is deeply documented, but foreign installers are unread, conformance is unrun, active/certified claims lack invocation evidence, contracts are one-sided, and settings/metrics are incomplete.
  M6 — PARTIAL: the structural gate and its FAIL were reproduced, but the gate does not select these chapters, contracts are external, logs/settings are incomplete, and several active classifications lack invoking lines.
  M7 — PARTIAL: the credential controls are partially mapped, but minting is unverified, the contract is one-sided, active status has no invoking unit, and settings/metrics are incomplete.
  M8 — PARTIAL: both files were read and their tests were reproduced, but the filesystem contract is one-sided, the metrics absence is unproven, and the settings register omits real CLI controls.
  M9 — PARTIAL: build, settlement, admission and metrics evidence is substantial, but the full Go suite fails, contracts are incomplete, only 2 of 379 log sites are inventoried, and most daemon settings are omitted.
  M10 — PARTIAL: build/tests pass and the guard is well documented, but the handler is not fully read, one broken-state claim is mis-scoped, contract rows are incomplete, and metrics/logs/settings are materially incomplete.
  M11 — PARTIAL: the full dispatcher was read and the log inventory is complete, but VERIFIED is overstated, live-job tests cannot fail, the synchronous path is unmeasured, settings/metrics are incomplete, and one failure mode is falsely attributed to node unreachability.
  M12 — PARTIAL: the proxy was fully read, hashed and live-401 tested, but “no anonymous path” and VERIFIED are false, both contracts are incomplete, the 403 check is unrun, and settings/metrics/activation evidence are incomplete.

PANEL REVIEW COMPLETE

session_id: local-572f87c4ed80918100d5b7721199911b2fa1b1c410e96517dea21a18fac00f95

EXIT=0
```

### sol

```
│ cache/scratch/panel-r4-sol-probes.py
│ @@ -0,0 +1,104 @@
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
│ +import types
│ +from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
│ +
│ +ROOT = Path('/home/kara/code-factory')
│ +SCRATCH = Path(os.environ['TMPDIR'])
│ +
│ +print('=== literal search reproducibility ===')
│ +for flags in ['-rn', '-rnE']:
│ +    p = subprocess.run(['grep', flags, '8775|CF_PROXY|cf-inference-proxy', 'scripts/', 'config/', 'specs/'], cwd=ROOT, text=True, capture_output=True)
│ +    print('grep', flags, 'exit=', p.returncode)
│ +    print(p.stdout.strip() or '(no matches)')
│ +p = subprocess.run(['grep', '-rn', 'lane_target', 'scripts/configure_family.py'], cwd=ROOT, text=True, capture_output=True)
│ +print(p.stdout.strip())
│ +for pattern in [r'\. "$HERE/lib.sh"', r'\. "\$HERE/(\.\./)?lib\.sh"']:
│ +    flags = '-rlE' if '(\.\./)' in pattern else '-rl'
│ +    p = subprocess.run(['grep', flags, pattern, 'scripts/'], cwd=ROOT, text=True, capture_output=True)
│ +    print('source count:', flags, repr(pattern), 'files=', len(p.stdout.splitlines()), 'exit=', p.returncode)
│ +
│ +print('=== actual dispatcher function in isolation (no service import) ===')
│ +path = Path('/home/kara/crier-fleet/dispatcher.py')
│ +tree = ast.parse(path.read_text())
│ +fn = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'task_seconds')
│ +ns = dict(TASK_S='240', CAP_S=7200, MARGIN_S=60)
│ +exec(compile(ast.Module(body=[fn], type_ignores=[]), str(path), 'exec'), ns)
│ +for w in [0, 10, 60, 600, 10000]:
│ +    print('task_seconds(%d)=%d' % (w, ns['task_seconds'](w)))
│ +ns['TASK_S'] = 'not-a-number'
│ +for w in [0, 600]:
│ +    try:
│ +        print('bad TASK_S, wall=%d -> %s' % (w, ns['task_seconds'](w)))
│ +    except Exception as e:
│ +        print('bad TASK_S, wall=%d -> %s' % (w, type(e).__name__))
│ +
│ +with tempfile.TemporaryDirectory(prefix='panel-r4-', dir=SCRATCH) as tmp:
│ +    tmp = Path(tmp)
│ +    print('=== actual fill CLI with a scratch document, workers=0 ===')
│ +    (tmp / '01-fixture.md').write_text('| Path | `scripts/lib.sh` |\n| Status | RED |\n')
│ +    env = dict(os.environ, CF_MASTER_DIR=str(tmp), PYTHONDONTWRITEBYTECODE='1')
│ +    p = subprocess.run(['python3', '-B', 'scripts/master_doc_fill.py', '--workers', '0'], cwd=ROOT, env=env, text=True, capture_output=True)
│ +    print('exit=', p.returncode)
│ +    print(p.stdout.strip())
│ +    print(p.stderr.strip().splitlines()[-1])
│ +
│ +    print('=== fetch_verified failing URL fixture ===')
│ +    dest = tmp / 'artifact'
│ +    p = subprocess.run(['bash', '-c', '. "$1"; fetch_verified http://127.0.0.1:1/nothing "$2" wrong; rc=$?; printf "fetch_rc=%s artifact_exists=" "$rc"; if [ -e "$2" ]; then printf "yes\\n"; else printf "no\\n"; fi', 'probe', str(ROOT / 'scripts/lib.sh'), str(dest)], text=True, capture_output=True)
│ +    print(p.stdout.strip())
│ +    print(p.stderr.strip())
│ +
│ +    print('=== unchanged proxy handler, healthy local SSE upstream fixture ===')
│ +    spec = importlib.util.spec_from_file_location('panel_proxy_fixture', '/home/kara/.hermes/scripts/cf-inference-proxy.py')
│ +    proxy = importlib.util.module_from_spec(spec)
│ +    spec.loader.exec_module(proxy)
│ +    proxy.USAGE_LOG = tmp / 'usage.jsonl'
│ +    proxy.CAPTURE_LOG = tmp / 'capture.jsonl'
│ +    proxy.upstream_key = lambda: 'fixture-only-key'
│ +    class Upstream(BaseHTTPRequestHandler):
│ +        protocol_version = 'HTTP/1.1'
│ +        def do_POST(self):
│ +            self.rfile.read(int(self.headers.get('Content-Length', '0')))
│ +            body = b'data: [DONE]\n\n'
│ +            self.send_response(200)
│ +            self.send_header('Content-Type', 'text/event-stream')
│ +            self.send_header('Content-Length', str(len(body)))
│ +            self.end_headers()
│ +            self.wfile.write(body)
│ +            self.wfile.flush()
│ … omitted 26 diff line(s) across 1 additional file(s)/section(s)
VERDICT: FAIL
BLOCKING: 28 — findings that must be fixed before the affected chapters can be called written
NON-BLOCKING: 0

FINDINGS:

Review basis:
  Read all 13 chapters, OUTLINE.md, MASTER-DOC-SCHEMA.md, and the implementation paths cited below. Reviewed the working-tree document, not previous seats’ verdicts.

  Source revisions checked:
    code-factory: 943ef984dc093e5780605ac6e54cd043122126ef
    scheduler: 1771d3aad61e6c1ce2845e3f1450f88aa73340b3
    crier: 691f0c78fc75717295abf3bd85aaa9192616aac0
    crier-fleet: 283bca91091933177ec521e52f37f1bc987cf7da
    inference proxy SHA-256: b12a0ac521c4b5a9cd7e2b76883a7edf2c9e0efd87d9bc3be3d2056d3f39e0b5

  Source-path convention below: CF means /home/kara/code-factory; scheduler, crier and crier-fleet mean the repositories named above.

B01 — OMISSION — M0–M8, M11, M12
  Claim quoted: “RED — none.”
  Evidence: Eleven chapters explicitly declare no metrics in §8. MASTER-DOC-SCHEMA.md:72–79 expressly makes “none” a RED field; OUTLINE.md:123 repeats that requirement. These are honestly disclosed deficiencies, but disclosure does not satisfy the field contract.
  Fix: Keep these chapters PARTIAL. Derive the missing instrumentation work, then document metric name, type, labels, question answered and scrape destination. Do not count a log, census or replay ledger as the missing emitted metric.

B02 — FALSE CLAIM — M0, M1, M4, M5, M6, M7, M8, M12
  Claim quoted: “The one-sided flag here is the correct completion”; “external boundary, rumour correct.”
  Evidence: M0:75–78 and M7:70 explicitly treat an unnamed consumer as acceptable completion; M8:67 does likewise. MASTER-DOC-SCHEMA.md:56–57 requires both implementations, and the round brief grants no external-peer exception. M4:70–73 invents an exception while correctly retaining UNVERIFIED.
  Fix: Remove the claimed exception. Name both implementations where retrievable. Otherwise preserve the boundary as UNVERIFIED and the chapter as PARTIAL; an external binary or service name is not a file:function.

B03 — OMISSION — M0–M12
  Claim quoted: “Contracts in and out.”
  Evidence: The recurring contract table supplies ID, peer, direction, producer, consumer and state, but generally omits the complete payload, timing, failure semantics and breaking-change policy required by OUTLINE.md:200–204. For example, M11-C2 gives result fields but no complete compatibility or retry contract; M9-C2 abbreviates the actual construction in scheduler/internal/bus/dispatch.go:175–219.
  Fix: Expand each contract into the required fields, including optional members, correlation, acceptance versus completion, retry/idempotency behavior and version-change policy. Cross-link the chapter contracts to the system contract register.

B04 — UNVERIFIED — M1, M3, M5, M6, M9
  Claim quoted: “active”; “invoked by the node’s result envelope.”
  Evidence: OUTLINE.md:108–113 requires an invoking scheduler lane, cron, timer or another unit. M3:37 uses main() as activation evidence while admitting operator invocation; M3:38 claims an envelope invokes the landing script. CF/scripts/node-bus-worker.py:1128–1144 merely constructs result data, while CF/scripts/land-node-branch.sh:69–86 requires explicit CLI invocation. M6:39–41 similarly uses entrypoints as activation evidence; M9:37 uses the presence of doctrine documents.
  Fix: Separate callable, operator-invoked and automatically invoked units. Supply the actual invocation edge for every active classification. Explicitly identify the operator handoff between a result envelope and landing.

B05 — UNVERIFIED — M0, M1, M2, M3, M5, M7, M10, M11
  Claim quoted: “staged probe ffc_probe.sh”; “--workdir <clean-worktree>”; “token …”.
  Evidence: M0:87 references an unavailable probe body; M3:97 has placeholders and records refusal rather than the advertised successful dry-run; M7:79 supplies an ellipsis instead of a runnable mint command. Several live verification rows lack the complete staging, target-selection and credential-path procedure. M11:82–86 leaves compilation as its only executed verification.
  Fix: Ship reproducible fixture commands and precise prerequisites, without credential values. Separate syntax checks from behavior checks. Retain live checks as UNVERIFIED until the exact procedure and captured result exist.

  Independently repeated here: the failing-URL fetch returned rc=1 and left no artifact. That confirms this failure arm, not every installation arm.

B06 — FALSE CLAIM — M1
  Claim quoted: “bunker-crier-connect.sh (writes auth/crier.token)” → “HandleRegister”.
  Evidence: M1-C1 at chapter line 90 names the wrong producer and operation. CF/scripts/bunker-crier-connect.sh:107–139 stages .node/crier.json and calls check(); :27–29 and :50–57 probe inbox access. It does not write auth/crier.token or issue the claimed registration request.
  Fix: Split credential installation, bus registration, identity staging and signed-read certification into their real contracts. Cite the actual registration producer rather than attaching HandleRegister to a configuration-and-probe script.

B07 — OMISSION — M1
  Claim quoted: “S4 seed prompts/skills/env.”
  Evidence: The chapter names the seeder but omits its important preservation/destruction contract. CF/scripts/node_seed.py:250–311 preserves changed, removed and local-only files by default, but --force removes and replaces destination trees at :280–291. The manifest, budget and applied-record controls are at :43–44 and :370–392.
  Fix: Document build → verify → apply → check, the manifest and digest-record formats, the default 16 MiB budget, preservation semantics, --force destruction, and the expected drift indication after preserving a local edit.

B08 — OMISSION — M1
  Claim quoted: “config keys … *_TOKEN_FILE …”; “KEY=VALUE lines only.”
  Evidence: M1:74 collapses provisioning settings into a list of names and syntax. CF/scripts/bunker-provision.sh:109–119 accepts distinct project, identity, repository, namespace, TTL, endpoint, credential-path and config-scalar inputs. The chapter does not give their individual defaults, valid values, readers and consequences.
  Fix: Replace the aggregate row with per-setting records. Include configuration/CLI precedence and distinguish identity, credentials, transport endpoints, repository selection and lifetime controls. These entries are currently NAME ONLY under rule 3.

B09 — FALSE CLAIM — M2
  Claim quoted: “lane_target.py … no production caller in-repo.”
  Evidence: M2:34 is contradicted by CF/scripts/configure_family.py:17, which imports lane_target, and :148–154, which calls lane_target.parse(workdir) and branches on the result before filesystem/API changes.
  Fix: Name configure_family.py as the production consumer. Explain structural parsing versus actual remote verification; passing this call does not prove a remote checkout exists.

B10 — OMISSION — M2
  Claim quoted: “Settlement ordering … execute → deliver each result → write the seen-cache … → ack last.”
  Evidence: CF/scripts/node-bus-worker.py:1304–1331 processes every leased message using the same initially loaded seen dictionary. The dictionary is not updated until the later delivery loop at :1341–1347. Thus two previously unseen messages sharing a dispatch key in one retrieved batch can both execute before either result enters the cache. The chapter discusses crash-before-persistence but not this same-batch duplicate case.
  Fix: Document the actual duplicate boundary, cache key and batch behavior. Add a same-batch duplicate verification case and distinguish cached replay from an execution claim or in-flight reservation.

B11 — OMISSION — M3
  Claim quoted: “S1 clone and track freshness”; “repo_freshness.py not read line-by-line.”
  Evidence: CF/scripts/repo_freshness.py:558–604 implements --bound, --gate, --strict, --no-fetch, --max-fetch-age, --jobs and --timeout. Critically, stale rows need not produce a failing process without --gate; unknown measurements need not fail without --strict. M3’s settings and verification sections do not document these controls.
  Fix: Write the freshness submodule as an operational contract: target discovery, comparison-ref selection, fetch mutation, lag/ahead measurement, unknown status, gate exit and strictness. Distinguish local-lane freshness from node_freshness.py.

B12 — OMISSION — M4
  Claim quoted: “The fleet’s durable record of what it decided and what it proved.”
  Evidence: M4 documents counts and wrapper verbs but not the task/event record contract. The real event at CF/.coding-hermes/board/events.jsonl:1 contains id, timestamp, event_type, task_id, actor, detail and tick_number; detail is itself a JSON-encoded string. Task records contain materially different lifecycle and evidence fields. Neither schema nor its producer/consumer interpretation is specified.
  Fix: Publish representative task and event schemas, required/optional fields, status and event vocabularies, dependency semantics, evidence binding and concurrency/write rules. Counts and successful validation do not substitute for the storage contract.

B13 — OMISSION — M5
  Claim quoted: “S5 variable contract … is the register for the CF_* set it enforces.”
  Evidence: The CF_* table does not cover the module’s entire control surface. CF/scripts/harness/install-hermes.sh:23–25 reads NODE_GATEWAY_PORT and HERMES_PIN. CF/scripts/install-gitreins.sh:19–29 reads version, venv, repository and author controls. CF/tests/harness-conformance.sh:46–78 defines install/write/subset modes, smoke/apply timeouts, model selection and work-root controls.
  Fix: Add per-installer, resolver, toolchain and certification settings, with actual defaults, accepted versus enforced ranges and consequences. Document check-only versus install-capable adapters and which run variables each adapter actually enforces.

B14 — FALSE CLAIM — M6
  Claim quoted: “fill --workers … 0 serialises.”
  Evidence: M6:82 is false. CF/scripts/master_doc_fill.py:450 passes the value directly to ThreadPoolExecutor(max_workers=a.workers). I executed the real fill CLI against one scratch document with --workers 0. It exited 1:
    todo=1 provider=deepseek workers=0
    ValueError: max_workers must be greater than 0
  Fix: State that positive values are required when work is selected; 1 is serial execution. Document zero/negative rejection rather than inventing a serial fallback.

B15 — OMISSION — M6
  Claim quoted: runtime dependencies “python3” and “hermes CLI”; library contract “sheet_style.py”.
  Evidence: CF/scripts/gen_unit_map.py:20 imports yaml, and :23 imports named rendering helpers. CF/scripts/gen_nasa_handbook.py:305–315 requires /usr/bin/google-chrome and uses a 900-second subprocess timeout. These dependencies and failure indications are absent from M6 §4/§5.
  Fix: Inventory dependencies by pipeline stage, including PyYAML and the renderer executable, required locations, the actual imported symbols and absence detection. Add the renderer’s timeout/output-path controls and their consequences.

B16 — FALSE CLAIM — M7
  Claim quoted: “--dry-run/--quiet change write/no-write.”
  Evidence: M7:62 conflates two different controls. CF/scripts/github-app-refresh.sh:47–48 sets separate DRY and QUIET flags. QUIET is used by say_q at :55 to suppress output; DRY exits before mint/write at :106 and :154. --quiet does not prevent minting or credential installation.
  Fix: State explicitly: --dry-run prevents mutation; --quiet suppresses selected messages only. List --min-age’s actual default and validation separately rather than bundling lifecycle controls into one row.

B17 — OMISSION — M9
  Claim quoted: “The daemon’s actual flag defaults are in … :108–144.”
  Evidence: The register stops short of behavior-changing controls immediately below that range. scheduler/cmd/schedulerd/main.go:149–172 defines spawn memory limits, board-stasis admission, hooks, session-silence cancellation, sleep-poll cancellation and per-tick push suppression. These can change whether a run starts, survives or publishes.
  Fix: Derive the settings register from the full flag/env/TOML surface. Include precedence, disabling values, clamping and consequences for each control; distinguish binary defaults from library defaults and configured live values.

B18 — OMISSION — M9
  Claim quoted: “admission and allocation”; “durable state … live store has 30 tables.”
  Evidence: The chapter supplies filenames and table counts instead of the decision and storage contracts. scheduler/internal/scheduler/admission_mode.go:98–129 resolves admission modes; :143–184 resolves ownership; :18–29 describes different drained-board behavior for builder and reporter/shared-board lanes. M9 does not turn these into an executable admission decision table. Its durable-state subsection supplies table names without keys, transition ownership or recovery semantics.
  Fix: Document eligibility order and named refusal/defer outcomes, then map queue → dispatch → execution → terminal transitions onto the durable records and their writers/readers. Include crash/restart reconciliation.

  Independent count check: the live database has 30 non-internal tables. I am not alleging that the chapter’s table count is wrong.

B19 — OMISSION — M9
  Claim quoted: “This is a sample, not an inventory.”
  Evidence: M9:125–127 explicitly concedes that §9 is not the required operator-visible log inventory. MASTER-DOC-SCHEMA.md:81–91 requires every operator-visible line with its triggering condition and descriptive/evidentiary classification.
  Fix: Supply an indexed log inventory, which may live in an appendix, and reference the relevant admission, settlement, watchdog and recovery lines from the chapter. Keep §9 incomplete until then.

B20 — OMISSION — M10
  Claim quoted: “PostgreSQL … / SQLite … driver-pinned.”
  Evidence: This dependency row omits the persistence selection that determines whether custody survives restart. crier/config/config.go:113–123 selects explicit registry backend first, then SQLite URL, then PostgreSQL URL, otherwise memory. crier/cmd/server/main.go:429–460 constructs the selected store. Session backend selection is separate at config/config.go:85–98.
  Fix: Document registry versus session persistence independently: defaults, selection precedence, effective paths, ignored-path warnings, startup failure and restart durability. A SQLite path alone is not proof that the registry uses SQLite.

B21 — OMISSION — M10
  Claim quoted: “Webhook.* … Range —”; “Guard.* … Range —”.
  Evidence: M10:66–67 groups settings with no individual ranges or consequences. crier/config/config.go:635–655 defines independent controls. The chapter itself points to positive-only guard env parsing at :1139–1187 but does not supply a complete per-setting register.
  Fix: Give each timeout, retry count, semaphore cap, circuit threshold/cooldown and body/render limit its own default, accepted range, unit, reader and failure consequence. Group names with dashes for ranges remain NAME ONLY.

B22 — OMISSION — M10
  Claim quoted: “S4 client libraries”; “Client library undocumented … OPEN.”
  Evidence: The chapter lists Python method names but leaves the client contract unwritten, and gives essentially no TypeScript contract. crier/clients/python/crier_client.py:1009–1049 specifies keyword-only retrieve inputs, decoded payloads, lease propagation and ack requirements. crier/clients/typescript/crier.ts:196–208 defines the corresponding Message representation.
  Fix: Document construction/signing, payload decoding, lease ownership, ack inputs, errors/timeouts and compatibility for both clients, including differences. Link the actual dispatcher calls and explicitly exclude the urllib-based node worker from this client-library dependency.

B23 — OMISSION — M10
  Claim quoted: “Inventory …” followed by selected guard and observability series.
  Evidence: The inventory omits operational metrics already implemented in crier/cmd/server/metrics_guard.go:34–47, metrics_identity.go:64–90 and metrics_state.go:48–74, including guard inflight/circuit state, process/build/store health, webhook backlog and federation hold age.
  Fix: Complete the metric register with type, labels, availability/NaN semantics, reset behavior, scrape/auth location and the operational question each series answers. “Real, not RED” does not make a partial inventory complete.

B24 — FALSE CLAIM — M11
  Claim quoted: “The synchronous path has … no replay ledger.”
  Evidence: M11:147–148 is false. crier-fleet/dispatcher.py:334–358 changes execution mode only. main() checks the ledger before calling dispatch at :470–479 and records either execution mode’s result at :481–483.
  Fix: State that CF_DURABLE_JOB=0 bypasses detached supervision but still participates in the outer replay ledger. Preserve the separately documented crash-before-ledger-write limitation.

B25 — FALSE CLAIM — M11
  Claim quoted: “DISPATCH_PROGRESS_S … 0 or negative suppresses progress.”
  Evidence: M11:60 contradicts the generated runner in crier-fleet/dispatcher.py:250–257. Its loop writes a progress line and then executes sleep {hb}; there is no nonpositive-value suppression branch. Zero removes the intended delay, while a negative sleep argument fails and the surrounding loop continues.
  Fix: Document actual behavior and validation absence. Do not advertise a disabling value that is not implemented. Provide a supported off mechanism only after the code has one.

B26 — FALSE CLAIM — M11
  Claim quoted: “client for %s failed … node unreachable.”
  Evidence: M11:109 and :129 assign a node-connectivity meaning to local client construction. crier-fleet/dispatcher.py:130–132 constructs Crier. crier/clients/python/crier_client.py:759–795 parses the URL and loads the signing key without contacting the bunker node. Actual node execution failures arise later through _bunker at dispatcher.py:204–212 and the durable dispatch calls.
  Fix: Separate local client/key/configuration failure, bus retrieval failure and bunker/node execution failure. Give each its real indication and recovery path.

B27 — UNVERIFIED — M12
  Claim quoted: “grep -rn '8775|CF_PROXY|cf-inference-proxy' … matches only …”.
  Evidence: The printed command uses basic grep, where these vertical bars do not express alternation. I ran it literally: exit 1, no matches. With grep -rnE, it returned the listed script references and config/node.env.example:22. That line is an ENV_CF_PROXY_API_KEY declaration, not merely the comment claimed in the chapter.
  Fix: Correct the command and quote its actual output. Distinguish references/configuration declarations from a runtime client invocation. The corrected search still does not establish the node producer; retain that half as UNVERIFIED.

B28 — OMISSION — M12
  Claim quoted: “stream pass-through”; “Upstream dies mid-stream … the stream just ends.”
  Evidence: /home/kara/.hermes/scripts/cf-inference-proxy.py:105 selects HTTP/1.1. Its streaming response at :206–210 sends neither Content-Length nor Transfer-Encoding nor Connection: close, and the successful path returns at :224 without marking the connection closed.

  I exercised the unchanged handler with a healthy local SSE upstream fixture. The upstream completed; the proxy recorded status=200, bytes=14 and streamed=true. The downstream received HTTP 200 but read-to-EOF raised TimeoutError because the response was not framed to completion. This occurred without an upstream failure.
  Fix: Document the healthy-stream termination defect and its client-visible indication, not only exceptional truncation. Add a real HTTP completion/framing test; retain streaming correctness as UNVERIFIED until that test passes.

Independent verification and limits:
  Repeated successfully:
    python3 tests/test_disk_floor.py — 12 tests, OK
    python3 tests/test_lane_target.py — 40 tests, OK
    python3 tests/test_harness_resolve.py — 28 tests, OK
    python3 tests/test_reclaim.py — 9 tests, OK
    Shell syntax checks for the inspected helpers, landing, refresh and harness scripts
    Scan-scope check — 15 claims, RESULT: OK
    Patch-chain verification — PASS, four stages and three patches
    Board drift check — RESULT: OK
    Board validation — 357 tasks, 515 events, RESULT: OK with seven warnings
    Proxy content hash and live unauthenticated POST — expected digest and HTTP 401

  Repeated failures:
    Default master-document gate — 44 modules, 37 declared VERIFIED, 50 errors, exit 1
    Explicit chapter-root gate — zero matching NN-*.md modules, exit 1
    Fill --workers 0 with a selected scratch document — ValueError, exit 1
    Literal M12 grep command — no matches, exit 1
    Healthy SSE fixture — downstream response completion timed out

  Did not repeat the full scheduler or crier Go suites, live node provisioning/certification, authenticated inference, GitHub token minting or live remote harness jobs. Their chapter results are not independent execution evidence from this review. The SSE and fill probes used isolated fixtures, not production credentials or paid inference.

DEFECT CLASSES:
  Explicit RED fields remain
  Invented contract exceptions
  Incomplete wire contracts
  Entrypoints mistaken for activation
  Unreproducible verification procedures
  Wrong producer/consumer attribution
  Undocumented destructive controls
  Incomplete settings and enforcement registers
  Batch-idempotency gap
  Unwritten freshness and storage contracts
  Incorrect disabling-value semantics
  Missing persistence-selection doctrine
  Partial log and metric inventories
  Execution-mode/ledger confusion
  Misdiagnosed failure indications
  Invalid evidence-search commands
  HTTP stream-completion defect

CHAPTER SCORECARD:
  M0 — PARTIAL. Useful shell-helper evidence and reproducible source counts, but metrics remain RED, the external-contract exception is invalid, and the named verification fixture is not supplied.
  M1 — PARTIAL. Certification behavior is substantially described; connection-contract attribution, seed preservation/destruction, settings and activation evidence remain incomplete.
  M2 — PARTIAL. The text/status dialect mismatches are grounded in code; the lane-target caller claim is false and same-batch duplicate execution is omitted.
  M3 — PARTIAL. Landing mechanics are concrete; automatic invocation is unproven and the freshness submodule’s controls and exit semantics remain unwritten.
  M4 — PARTIAL. Store census and validation reproduced; the durable task/event schema and end-to-end write contracts are not documented.
  M5 — PARTIAL. The shared CF_* predicate is described, but installer/certification controls, enforcement differences and live acceptance evidence remain incomplete.
  M6 — PARTIAL. The structural gate’s limits and failure reproduced; --workers behavior is misstated and rendering/generation dependencies are omitted.
  M7 — PARTIAL. Credential-domain separation is useful; --quiet is incorrectly described as a mutation control, mint verification remains unproven, and metrics remain RED.
  M8 — PARTIAL. Reclaim and scan-scope behavior is supported by passing tests; the mandatory metrics field remains RED and the claimed one-sided-contract exception is invalid.
  M9 — PARTIAL. Settlement mismatch and selected defaults are grounded; admission/recovery/storage contracts, the full settings surface and log inventory remain incomplete.
  M10 — PARTIAL. Guard degradation and signed-read behavior have concrete evidence; persistence selection, tuning ranges, client contracts and metric inventory remain incomplete.
  M11 — PARTIAL. Detailed source coverage does not cure the false synchronous-ledger, progress-disable and node-unreachable claims; behavioral acceptance and metrics remain RED.
  M12 — PARTIAL. Hash and unauthenticated refusal reproduced; client attribution remains unproven, its search command is invalid, and healthy HTTP stream completion is omitted.

PANEL REVIEW COMPLETE

session_id: local-6c6c6a3646d8e49dbdcc5a2dd3c94c53bf823cd5203faefc098b14936c396468

EXIT=0
```

