# CORRECTIONS — round 2

Generated 2026-11-06T16:21:12-0500.

## Verdicts

- **deepseek** — FAIL, blocking 6, 10695 bytes, complete=True
- **glm** — FAIL, blocking 4, 20089 bytes, complete=True
- **grok** — FAIL, blocking 7, 14390 bytes, complete=True
- **kimi** — FAIL, blocking 4, 9992 bytes, complete=True
- **sol** — FAIL, blocking 34, 34193 bytes, complete=True

## Verdict text (verbatim, per seat)

### deepseek

```
All verification complete. I read all 13 chapters, the outline, the schema, and re-verified the load-bearing claims against the five codebases with my own commands. Here is the verdict.

---

VERDICT: FAIL

BLOCKING: 6 — findings that must be fixed before these chapters can be called written

NON-BLOCKING: 2

FINDINGS:

BLOCKING

1. FALSE CLAIM — M0–M12 (writer manifest) — "every §6 contract now names producer file:function AND consumer file:function."
   Evidence: the both-sides rule (brief rule 2; schema §3c line 56 "a contract with one side named is a rumour") is still violated by the residual one-sided rows I measured. M9-C1 names NEITHER side — producer "operator config", consumer "scheduler config load" (M9-scheduler.md §6). M3-C2 producer "the node's result envelope (branch, commit)" is not a file:function. M5-C1 consumer "per-leg verdict" is not a file:function. M7-C1 consumer "github.com App installation". M8-C1 consumer "the target roots it enumerates". M0-C1 consumer "the bunker binary the CLI invokes". M12-C1/M12-C2 consumer is a protocol description, not a function. The fix was claimed complete in the manifest ("every §6 contract now names both") when ~8 rows still have a name-only side.
   Fix: either put the real producer/consumer file:function on every remaining row (the producer side of M9-C1 is findable — the config-load path in the scheduler; the consumer side of M12-C2 is the upstream handler), or mark each remaining row honestly as one-sided instead of claiming the rule is satisfied.

2. OMISSION — M9 — Settings register is empty. M9 §5 reads "config.example.toml is the register … its individual keys were not read line-by-line this round."
   Evidence: zero default/range/consequence rows for the scheduler, whose intervals, weight budget, max_concurrent and tick timeout are the outline's Part V.6. Under the outline's decision rule ("a name with no consequence is NAME ONLY and counts as unwritten"), every scheduler setting is still unwritten. This is the round-1 "missing settings register" finding, fixed for the node-side chapters (M0/M2/M5/M8/M11/M12 now carry real registers) but deferred for the one module that most needs it.
   Fix: read config.example.toml and emit the register, or mark the whole M9 settings surface RED rather than deferring it.

3. OMISSION — M9, M10 — the scheduler/crier core authorities are still contract-table entries, not systems. M9 S1 (admission_mode, tick_process, packer_select, namespace_alloc, usage_pool_policy) and S5 (doctrine) are "named by OUTLINE M9.S1" with no source read; M10 S1 (handler.go, 1895 lines) and S2 (the guard) are "not read this round". I confirmed: `grep -c admission_mode M9-scheduler.md` = 1 (the outline-derived name only).
   Evidence: the v1→v2 correction's whole point (OUTLINE.md lines 6-9) was to stop documenting the scheduler/bus/dispatcher/proxy "as entries in a contract table rather than as systems." M9 now reads only settlement (dispatch_leg.go:260-336, :713-726) and dispatch.go; the admission authority — the scheduler's reason to exist — is unread. The crier guard, the security-critical path, is unread. Round 1's largest single finding is half-addressed.
   Fix: read admission_mode/tick_process and the guard; classify them with invoking file:line, or drop M9/M10 to honest SKELETON instead of PARTIAL.

4. UNVERIFIED — M9 — revision stamp stale. M9 §1 stamps `dfa9c84f`; the scheduler HEAD is now `1771d3aa` (measured). I confirmed dfa9c84f is an ancestor but 2 commits behind, and that no commit since touched dispatch_leg.go (so the cited lines still hold), but the stamp violates schema §1 ("one revision per document issue") and sol's rule that "any locator written into an external repo must carry the external repo's own HEAD."
   Fix: re-stamp at the current scheduler HEAD and re-verify the two cited ranges.

5. OMISSION — the document as a whole — Parts I, II (16 flows), IV (18 contracts), V (~83 env vars, ~215 CLI switches), VI (risk), VII (work derivation), VIII (delivery mechanisms) have no chapters. Only Part III (13 module chapters) exists.
   Evidence: OUTLINE.md commits to 8 parts; 7 are unwritten. The flows (F1–F16) named as the panel's largest finding, the 18-contract register (OUTLINE §IV still says "0 of 18 name both implementations"), and the settings register at scale have no home. This was grok #9 in round 1 and was neither fixed nor rejected.
   Fix: either write those parts or get an explicit quorum ruling that this round's deliverable is Part III only; as written the handbook is 1/8 of its own structure.

6. OMISSION — M1/M6/orphan — `scripts/ownership.py` (5606 bytes, added at HEAD 943ef98, the "ops: ownership tooling" commit) is in no chapter and no UNIT-MAP entry.
   Evidence: `grep -rl ownership.py docs/handbook/chapters/` → no match; `grep -c ownership docs/UNIT-MAP.yaml` → 0. Per the outline's scope rule ("anything a run does reach that this outline has no home for is a defect and gets a chapter"), the unit is orphaned. This is round-1 deepseek #14, unfixed.
   Fix: classify ownership.py into a submodule inventory (or explicitly rule it out of scope with a reason).

NON-BLOCKING

7. Metrics RED in 11 of 13 chapters (M0–M8, M11, M12). This is the honest, schema-mandated answer ("none" is RED), and I confirmed the honesty is real (only M9 server_metrics.go and M10 metrics.go were actually measured). But the observability gap stands: dispatch/settlement/landing rate, refusal count and latency are all answered by grepping logs. Not a defect in the writing; a defect in the systems it describes, which the chapters correctly report.

8. CONTRADICTION (spec-vs-spec, unresolved) — M5 §3 files the UNIT-MAP(3) vs OUTLINE(5) submodule split as a parenthetical. Round-1 grok #17 asked it be a board row; it was not. The two structure maps still disagree with no reconciliation, so a reader cannot tell which submodule inventory is authoritative.

DEFECT CLASSES:

one-sided-contract-residual · overclaimed-fix · empty-settings-register · unread-core-authority · stale-external-stamp · missing-parts · orphaned-unit · red-observability · spec-vs-spec-unreconciled

WHAT I VERIFIED AS TRUE (so the next round keeps it):

- All 22 new findings F0-1..F12-2 are accurate. I independently confirmed each: F0-1 bunker_exec is a bunker CLI call (lib.sh:75-78), not crier; F0-4 lib.sh:6-7 print unconditionally (descriptive, not evidentiary); F1-1 provisioner resolves bunker via `have` (PATH) while :233 prints "mode 600" over a `[ -s ]` probe; F2-1 node imports urllib not crier_client; F3-1 clone_lane refuses same-lane before sqlite3.connect; F8-1 reclaim_disk HAS the age gate (--job-ttl-hours 24); F9-2 scheduler.db is 30 tables / 0 verdicts; F10-1 crier auth order is headers→lookup→caller→timestamp→key→sig, not sig-first; F11-2 the dispatcher test scripts print without asserting; F12-2 the proxy carries a CONTRACT section at :9-19.
- CF-354 both sides: `dispatch.go:202` emits `text_b64`; `node-bus-worker.py:986` reads `dispatch.get("text")`; `grep -c text_b64 node-bus-worker.py` = 0.
- CF-355 both sides: node sends `status` at :1132; `dispatchReplyVerdict` (dispatch_leg.go:713-726) reads only `payload["ok"]`, absence = SUCCESS.
- Line cites exact for lib.sh (:5-9, :13, :19-42, :48-57, :60-64, :67-70, :75-78), harness-vars.sh (:34, :66, :176-192, :218-220, :276-292), land-node-branch.sh, install-gitreins.sh, clone_lane.py (:38-45/:65-68), reclaim_disk.py (:42/:46-47/:90-92/:104-111), master_doc_check.py (:52/:188/:191-209), dispatcher.py (:43/:46/:48/:52-53/:60/:142-150/:365-374/:470-475/:500-519), cf-inference-proxy.py (:9-19/:43/:45/:48/:53-54/:58-62/:115-123/:154-160/:164-180/:204/:237/:265-270).
- Measured values all reproduce: bash 5.3.9, python 3.14.9, go 1.26.5; lib.sh 78 / harness-vars.sh 318 / land-node-branch.sh 295 / install-gitreins.sh 180 / clone_lane.py 130 / node-bus-worker.py 1498 / reclaim_disk.py 169 / master_doc_check.py 268 / harness_resolve.py 400 / install-hermes.sh 375 / cf-inference-proxy.py 273 / dispatcher.py 538; board 357 rows / 515 events; boardctl exactly 20 subcommands; crier config.go:622 = 8767, crier-front:39 = 127.0.0.1:8770, crier go.mod = 1.26.10, crier_client deliver:975/retrieve:1009/ack:1038.

CHAPTER SCORECARD:

- M0 shared-contract — PARTIAL. Line-accurate and the four findings F0-1..F0-4 are all true, but M0-C1 is one-sided and metrics RED.
- M1 provisioning — PARTIAL. Honest UNVERIFIED status; F1-1 true; M1-C1 one-sided; metrics RED.
- M2 dispatch — PARTIAL. CF-354/355 verified on both sides; contracts now name both producer and consumer file:function (the best contract rows in the set); RED metrics only.
- M3 repository — PARTIAL. Strongest chapter: every cited line exact, CF-357 fix reproduced, dry-run fixture reproduced; held back by the one-sided M3-C2 and RED metrics.
- M4 board — PARTIAL. Store counts and drift reproduced; verb count now correct at 20; RED metrics.
- M5 harness — PARTIAL. F5-1 true; the UNIT-MAP/OUTLINE split unresolved; M5-C1 one-sided; RED metrics.
- M6 documentation — PARTIAL. Gate state re-run and correct (44/37/50, FAIL, exit 1); F6-1 true; RED metrics.
- M7 github — PARTIAL (thin). CLI surface measured (exit 2, no mint) and correct; but all three script bodies unread; M7-C1 one-sided; RED metrics.
- M8 safety — PARTIAL. reclaim_disk read in full, F8-1/F8-2 true; M8-C1 one-sided; RED metrics.
- M9 scheduler — PARTIAL. Settlement/verdict read and CF-355 correctly located; but S1/S5 unread, settings register empty, stamp 2 commits stale.
- M10 crier — PARTIAL. Auth order and client surface read and correct; but handler.go (1895 lines) and the guard unread.
- M11 dispatcher — PARTIAL. Read in full, every cite exact, F11-1/F11-2 true; M11-C2 one-sided; RED metrics.
- M12 inference-proxy — PARTIAL. Read in full, F12-1/F12-2 true, CONTRACT section correctly identified; M12-C1/C2 one-sided; RED metrics.

Bottom line: the round-2 rewrite is a genuine, measurable improvement — the line cites are precise, all 22 filed findings are true, the four missing headings were added, and M9/M10 were promoted from SKELETON with real source reads. But the document is not written. The both-sides contract fix was overclaimed, the scheduler's admission authority and crier's guard remain unread, the scheduler's settings register is deferred, seven of the outline's eight parts have no chapter, and a unit added at HEAD is orphaned. None of the 13 chapters is WRITTEN.

PANEL REVIEW COMPLETE

session_id: local-c29e07941c9b53e85f353b3f9f1b6e51a542923ddb6d0c77f7351f19aee4ff0a

EXIT=0
```

### glm

```
│ cache/scratch/panel2-verify.sh
│ @@ -0,0 +1,160 @@
│ +#!/usr/bin/env bash
│ +# Round-2 panel verification battery — judge chapters M0..M12 against code
│ +CF=/home/kara/code-factory
│ +SCHED=/home/kara/coding-hermes-scheduler/coding-herms-scheduler
│ +CRIER=/home/kara/crier
│ +FLEET=/home/kara/crier-fleet
│ +SC=/home/kara/.hermes/cache/scratch
│ +BOARD=$CF/.coding-hermes/board/tasks.jsonl
│ +
│ +echo "===== R REPO STATE ====="
│ +git -C $CF log -1 --format='code-factory HEAD %H' 2>&1
│ +git -C $SCHED log -1 --format='scheduler HEAD %H' 2>&1
│ +git -C $CRIER log -1 --format='crier HEAD %H' 2>&1
│ +git -C $FLEET log -1 --format='crier-fleet HEAD %H' 2>&1
│ +echo "code-factory dirty files: $(git -C $CF status --short | wc -l)"
│ +git -C $CF status --short | head -8
│ +echo "scheduler dirty files: $(git -C $SCHED status --short | wc -l)"
│ +
│ +echo "===== M0 SHARED CONTRACT ====="
│ +wc -l $CF/scripts/lib.sh $CF/scripts/harness/harness-vars.sh
│ +echo "direct sourcers: $(grep -rl '\. "$HERE/lib.sh"' $CF/scripts/ | wc -l)"
│ +echo "total sourcers: $(grep -rlE '\. "\$HERE/(\.\./)?lib\.sh"' $CF/scripts/ | wc -l)"
│ +echo "total .sh under scripts/: $(find $CF/scripts -name '*.sh' | wc -l)"
│ +bash --version | head -1
│ +python3 --version
│ +echo "--- lib.sh:19-27 (fetch_verified head)"; sed -n '19,27p' $CF/scripts/lib.sh
│ +echo "--- lib.sh:75-78 (bunker_exec)"; sed -n '75,78p' $CF/scripts/lib.sh
│ +echo "--- lib.sh:5-11"; sed -n '5,11p' $CF/scripts/lib.sh
│ +echo "--- harness-vars CF_MAX_TURNS/CF_TIMEOUT_S"; grep -n 'CF_MAX_TURNS\|CF_TIMEOUT_S' $CF/scripts/harness/harness-vars.sh
│ +echo "--- harness-vars:176-192 (key refusals)"; sed -n '176,192p' $CF/scripts/harness/harness-vars.sh
│ +echo "--- harness-vars:204,218-220,247-249"; sed -n '204p;218,220p;247,249p' $CF/scripts/harness/harness-vars.sh
│ +echo "--- lib.sh:15,47 (CF-105/CF-109 comments)"; sed -n '15p;47p' $CF/scripts/lib.sh
│ +echo "--- harness-vars:292 (CF-229)"; sed -n '292p' $CF/scripts/harness/harness-vars.sh
│ +for id in CF-105 CF-109 CF-280 CF-229; do
│ +  n=$(jq -r --arg i "$id" 'select(.id==$i)|.id' $BOARD | wc -l); echo "board $id rows: $n"
│ +done
│ +
│ +echo "===== M1 PROVISIONING ====="
│ +echo "--- bunker-provision.sh:181-187"; sed -n '181,187p' $CF/scripts/bunker-provision.sh
│ +echo "--- bunker-provision.sh:207-233"; sed -n '207,233p' $CF/scripts/bunker-provision.sh
│ +echo "--- disk_floor.py:36-40"; sed -n '36,40p' $CF/scripts/disk_floor.py
│ +grep -n 'MIN_GIB\|MAX_GIB' $CF/scripts/disk_floor.py | head -4
│ +(cd $CF && timeout 90 python3 tests/test_disk_floor.py > $SC/t1.out 2>&1; echo "test_disk_floor rc=$?"); tail -2 $SC/t1.out
│ +
│ +echo "===== M2 DISPATCH ====="
│ +echo "--- node-bus-worker.py:66-78 (imports)"; sed -n '66,78p' $CF/scripts/node-bus-worker.py
│ +echo "--- node-bus-worker.py:80-84,110-114"; sed -n '80,84p;110,114p' $CF/scripts/node-bus-worker.py
│ +echo "--- node-bus-worker.py:986-991"; sed -n '986,991p' $CF/scripts/node-bus-worker.py
│ +echo "--- node-bus-worker.py:1128-1144 (reply fields)"; sed -n '1128,1144p' $CF/scripts/node-bus-worker.py
│ +echo "--- node-bus-worker.py:1152-1157"; sed -n '1152,1157p' $CF/scripts/node-bus-worker.py
│ +grep -n 'urllib' $CF/scripts/node-bus-worker.py | head -3
│ +grep -cn 'crier_client' $CF/scripts/node-bus-worker.py
│ +(cd $CF && timeout 120 python3 tests/test_lane_target.py > $SC/t2.out 2>&1; echo "test_lane_target rc=$?"); tail -2 $SC/t2.out
│ +echo "node-bus-worker on control host: $(ls ~/node-bus-worker.py 2>&1)"
│ +
│ +echo "===== M3 REPOSITORY ====="
│ +wc -l $CF/scripts/land-node-branch.sh $CF/scripts/install-gitreins.sh $CF/scripts/clone_lane.py $CF/scripts/repo_freshness.py
│ +echo "--- land-node-branch.sh:8-9"; sed -n '8,9p' $CF/scripts/land-node-branch.sh
│ +echo "--- land-node-branch.sh:22-24,53-58"; sed -n '22,24p;53,58p' $CF/scripts/land-node-branch.sh
│ +echo "--- land-node-branch.sh:265,276,282,291,294"; sed -n '265p;276p;282p;291p;294p' $CF/scripts/land-node-branch.sh
│ +grep -n 'LANDED:\|LAND: REFUSED\|LAND: FAIL\|DRY-RUN' $CF/scripts/land-node-branch.sh | head -8
│ +echo "--- install-gitreins.sh:19,23,53"; sed -n '19p;23p;53p' $CF/scripts/install-gitreins.sh
│ +echo "--- install-gitreins.sh:124-136"; sed -n '124,136p' $CF/scripts/install-gitreins.sh
│ +echo "--- clone_lane.py:38-45,65-70"; sed -n '38,45p;65,70p' $CF/scripts/clone_lane.py
│ +echo "scripts/hooks/: $(ls $CF/scripts/hooks/ 2>&1)"
│ +echo "CF-357 status: $(jq -r --arg i CF-357 'select(.id==$i)|.status' $BOARD | head -1)"
│ +
│ +echo "===== M4 BOARD ====="
│ +echo "tasks rows: $(jq -r '.id' $BOARD | wc -l)"
│ +echo "events lines: $(wc -l < $CF/.coding-hermes/board/events.jsonl)"
│ +echo "--- scripts/boardctl:"; cat $CF/scripts/boardctl
│ +command -v boardctl; boardctl version 2>&1 | head -2
│ +boardctl --help 2>&1 | sed -n '1,30p'
│ +git -C $CF fetch origin main --quiet 2>&1 | head -2
│ +(cd $CF && timeout 60 python3 scripts/board_drift.py check --workdir $CF --ref origin/main 2>&1 | tail -4)
│ +
│ +echo "===== M5 HARNESS ====="
│ +wc -l $CF/scripts/harness_resolve.py $CF/scripts/harness/install-hermes.sh $CF/scripts/harness/install-gitreins.sh
│ … omitted 82 diff line(s) across 1 additional file(s)/section(s)
│ cache/scratch/panel2-verify2.sh
│ @@ -0,0 +1,62 @@
│ +#!/usr/bin/env bash
│ +CF=/home/kara/code-factory
│ +SCHED=/home/kara/coding-hermes-scheduler/coding-herms-scheduler
│ +CRIER=/home/kara/crier
│ +FLEET=/home/kara/crier-fleet
│ +SC=/home/kara/.hermes/cache/scratch
│ +
│ +echo "== A scheduler stamp =="
│ +git -C $SCHED cat-file -t dfa9c84fbf0c0de0be5de6259609a13fc6ca8b1b 2>&1
│ +git -C $SCHED merge-base --is-ancestor dfa9c84fbf0c0de0be5de6259609a13fc6ca8b1b HEAD 2>&1; echo "ancestor rc=$?"
│ +git -C $SCHED log --oneline -3
│ +echo "commits since stamp: $(git -C $SCHED rev-list --count dfa9c84fbf0c0de0be5de6259609a13fc6ca8b1b..HEAD 2>&1)"
│ +
│ +echo "== B exact locators =="
│ +grep -n 'text_b64' $SCHED/internal/bus/dispatch.go | head -3
│ +grep -n 'func dispatchReplyVerdict' $SCHED/internal/scheduler/dispatch_leg.go
│ +grep -n 'DISPATCH: %s tick=%s agent=%s corr=%s' $SCHED/internal/scheduler/dispatch_leg.go
│ +grep -n 'inbox seen=' $SCHED/internal/scheduler/dispatch_leg.go
│ +grep -n 'MASTER-DOC' $CF/scripts/master_doc_check.py
│ +grep -n 'REMOTE=\|MAIN=' $CF/scripts/land-node-branch.sh | head -4
│ +grep -n 'dispatch_inbox' $SCHED/internal/scheduler/dispatch_leg.go | head -3
│ +
│ +echo "== C M11 log line numbers =="
│ +grep -n 'dispatcher up:\|job %s started on\|job %s finished rc=\|job %s progress\|already running as pid\|scoped token mint failed' $FLEET/dispatcher.py
│ +
│ +echo "== D crier pgx =="
│ +grep -n 'pgx' $CRIER/go.mod | head -3
│ +grep -rn 'postgres' $CRIER/config/config.go | head -3
│ +
│ +echo "== E M5 path field =="
│ +ls $CF/scripts/harness/
│ +ls $CF/scripts/install-go.sh $CF/scripts/install-gitreins.sh $CF/scripts/project-node.sh $CF/scripts/harness_resolve.py 2>&1
│ +ls $CF/tests/harness-conformance.sh 2>&1
│ +
│ +echo "== F test counts =="
│ +(cd $CF && timeout 90 python3 tests/test_disk_floor.py 2>&1 | grep -ci 'PASS\|ok=' | head -1)
│ +(cd $CF && timeout 90 python3 tests/test_disk_floor.py 2>&1 | grep -c 'ok$' )
│ +echo "---lane_target count:"
│ +(cd $CF && timeout 120 python3 tests/test_lane_target.py 2>&1 | tail -6)
│ +echo "---harness_resolve tail:"
│ +(cd $CF && timeout 120 python3 tests/test_harness_resolve.py 2>&1 | tail -4)
│ +echo "---reclaim tail:"
│ +(cd $CF && timeout 90 python3 tests/test_reclaim.py 2>&1 | tail -4)
│ +
│ +echo "== G boardctl verbs =="
│ +boardctl --help 2>&1 | sed -n '/^commands:/,$p' | grep -oE '^  [a-z][a-z-]+' | wc -l
│ +boardctl --help 2>&1 | grep -cE 'init|list|show|next-id|create|update|event|header|validate|sweep-status|normalize-statuses|normalize-board|doctor|version|stats|render|import|serve|install|umbrella'
│ +
│ +echo "== H M11 test oracle claim =="
│ +wc -l $FLEET/tests/test_durable_job.py $FLEET/tests/test_job_kill.py
│ +tail -8 $FLEET/tests/test_durable_job.py
│ +echo "---- kill tail:"
│ +tail -10 $FLEET/tests/test_job_kill.py
│ +
│ +echo "== I M0 fail-closed repeat =="
│ +mkdir -p $SC/fcbin && cp $(command -v sha256sum) $SC/fcbin/ 2>/dev/null
│ +bash -c 'source /home/kara/code-factory/scripts/lib.sh; PATH="/home/kara/.hermes/cache/scratch/fcbin:/usr/bin:/bin" fetch_verified https://127.0.0.1:1/x /dev/null abc; echo "fetch_verified-without-curl rc=$?"' 2>&1 | tail -2
│ +
│ +echo "== J M4 evidence rule =="
│ +boardctl --help 2>&1 | grep -c 'evidence-run-id'
│ +
│ +echo "BATTERY2 DONE"
All verification batteries are complete. I re-derived roughly 130 claims from the 13 chapters against the five code bases — every reproduced command, locator, count, and revision was checked, and I re-ran four unit suites, two Go builds, the doc gate, and the board drift check myself. Verdict follows.

```
VERDICT: FAIL

BLOCKING: 4 — findings that must be fixed before these chapters can be called written
NON-BLOCKING: 4

FINDINGS:

BLOCKING

1. kind: FALSE CLAIM — chapter M9 (§1 Identity, §7 build row)
   Claim: "Revision `dfa9c84fbf0c0de0be5de6259609a13fc6ca8b1b` (scheduler repo HEAD, stamped this round)"
   Evidence: `git -C /home/kara/coding-hermes-scheduler/coding-herms-scheduler log -1 --format=%H`
   → 1771d3aad61e6c1ce2845e3f1450f88aa73340b3. dfa9c84f exists and is an ancestor
   (merge-base --is-ancestor rc=0; `rev-list --count dfa9c84f..HEAD` → 2). The stamp is a real
   derivation rev mislabelled as HEAD.
   Fix: re-stamp at 1771d3aa. This is cheap because every M9 locator I re-checked still holds at
   current HEAD — `internal/bus/dispatch.go:202` is exactly the `p["text_b64"] = base64…` line,
   `dispatchReplyVerdict` begins exactly at `internal/scheduler/dispatch_leg.go:713`, the DISPATCH
   log at `:252`, and `go build ./...` PASS reproduced (rc=0).

2. kind: UNVERIFIED (classification without invoking evidence) — chapters M9.S1, M10.S2, M8.S2,
   M7.S1, M6 S1–S8, M1 S1–S4, M2.S1, M5.S2
   Claim: submodule rows classified **active** with evidence such as "named by OUTLINE M9.S1"
   (M9 §3), "named by OUTLINE M10.S2" (M10 §3), "named by `docs/UNIT-MAP.yaml:236`" (M8 §3),
   "token mint/refresh on the run path" (M7 §3), "pipeline head" / "render the handbook"
   (M6 §3), "run-path scripts" (M2 §3), "listed in `scripts/harness/`" (M5 §3).
   Evidence: OUTLINE §III rule 3 — "Evidence must be the invoking line (`file:line`) or the
   absence proven by a repo-wide grep quoted with its command." An outline or unit-map entry is
   a structure document, not an invoker; citing it is circular. M0, M3, M11, M12 show the
   compliant form (e.g. M0's `grep -rlE … → 17`, M3's `clone_lane.py:129 main()`).
   Fix: per row, cite the invoking line (a call site, a cron/timer entry, a sourcing line) or
   quote the absence grep. Until then those "active" classifications count as unwritten under
   the outline's own decision rule.

3. kind: UNVERIFIED (contract state inherited, not measured) — chapters M6-C2, M4-C2, M5-C1, M1-C1
   Claim: M6-C2 "handbook → the render pipeline | the owner's approval artifact | **works**" —
   no file:function on either side, no evidence at all; M4-C2 "**broken** — OUTLINE §IV";
   M5-C1 "**broken** (OUTLINE §IV)"; M1-C1 state word "broken" while its own text admits
   "token exchange not re-run this round; both sides not read".
   Evidence: OUTLINE Part IV made both-sides-plus-measured-state the headline correction ("0 of
   18 name both implementations"). A chapter re-asserting the register's state word without its
   own measurement regresses exactly that. Contrast the compliant rows this round: M2-C1/C2,
   M9-C2/C3, M11-C1/C2 name both sides and I verified each at the cited lines.
   Fix: measure the state in-chapter or write UNMEASURED. M6-C2 needs producer and consumer
   file:function before any state word may appear next to it.

4. kind: FALSE CLAIM (identity path) — chapter M5 (§1 Path)
   Claim: Path "`/home/kara/code-factory/scripts/harness/` — install-hermes.sh, …,
   harness-vars.sh; plus harness_resolve.py, install-go.sh, install-gitreins.sh, project-node.sh"
   — read as written, all 11 units live under scripts/harness/.
   Evidence: `ls scripts/harness/` → 7 files only (the six installers + harness-vars.sh);
   harness_resolve.py, install-go.sh, install-gitreins.sh, project-node.sh are in `scripts/`.
   M3 §1 correctly places install-gitreins.sh in `scripts/` — two chapters disagree where a unit
   lives, and schema §1 makes Path the identity anchor.
   Fix: name both directories in the Path field (`scripts/` + `scripts/harness/`).

NON-BLOCKING

5. kind: UNVERIFIED (locator precision) — chapter M9 (§9)
   Claim: inbox-summary log cited at `dispatch_leg.go:353`.
   Evidence: `:353` is the format-documenting comment; the emitting statement is
   `log.Printf("DISPATCH: %s tick=%s inbox seen=%d …")` at `:456` (grep verified).
   Fix: cite `:456` for the emission, keep `:353` as the format contract.

6. kind: UNVERIFIED (unsourced row) — chapter M2 (§4a)
   Claim: "`agent.key` + `crier.json` | mode 600 | node | bus worker refuses without them" — no
   file:line for the refusal.
   Fix: cite the refusal branch in node-bus-worker.py or drop the row to UNMEASURED.

7. kind: OMISSION — chapter M9 (§5)
   Claim: "Settings register: `config.example.toml` is the register …; its individual keys were
   not read line-by-line this round" — zero rows in the chapter's own register.
   Evidence: OUTLINE §III.5 decision rule: a setting is documented only with default + range +
   one consequence. Disclosed honestly, and Part V.6 is the outline's home for the full table,
   so non-blocking — but the headline four (intervals, weight budget, max_concurrent, tick
   timeout) belong in-chapter with consequences, or the punt must name V.6 explicitly.
   Fix: add the four rows or an explicit "see Part V.6" cross-reference with status.

8. kind: OMISSION — chapter M4 (§5)
   Claim: settings register carries a single row (`-C`).
   Evidence: the load-bearing semantics exist but live in prose — `--status complete REQUIRES
   --evidence-run-id` (§2/§11, verified in `boardctl --help`, TR-251) and the duplicate/fingerprint
   refusal exit 2 (§10). Verified true, misplaced.
   Fix: promote both into §5 rows with refusal semantics.

DEFECT CLASSES: stale-revision-stamp · circular-classification-evidence ·
inherited-contract-state · identity-path-error · locator-points-at-comment ·
unsourced-dependency-row · empty-settings-register

CHAPTER SCORECARD:

M0  WRITTEN  — both files read in full; all counts and refusal ranges re-derived by this judge
              (78/318 lines, 11 direct / 17 total sourcers, 20 .sh files, bash 5.3.9, python
              3.14.9); the writer's one UNVERIFIED row (fetch_verified fails closed) was
              repeated by this judge under a PATH restriction — rc=1, no artifact left.
M1  PARTIAL  — the --check probe and disk_floor verified, F1-1 confirmed true (`:214` tests
              `[ -s … ]`, `:233` prints "mode 600"); S1–S4 unit bodies unread and their
              classification rows carry no invoking lines (finding 2).
M2  PARTIAL  — the terminal contracts exactly verified (reply fields at :1128-1144 match
              field-for-field, `text` refusal :986, 40/40 tests re-run); S1 lane-config units
              structure-mapped only; one unsourced dependency row (finding 6).
M3  WRITTEN  — three units read in full; every quoted log line re-found at its cited line
              (LANDED :291, REFUSED :56, FAIL :294, DRY-RUN :231, pin refusal :105-equivalent);
              refuse_same_lane-before-connect confirmed; CF-357 `complete` confirmed; the
              `scripts/hooks/` absence proven. Strongest chapter.
M4  WRITTEN  — store re-measured (357 rows / 515 events), drift check reproduced (RESULT: OK,
              357 vs 357), 20-verb surface and evidence-run-id rule verified; deductions are
              the inherited-state row (finding 3) and the thin register (finding 8).
M5  PARTIAL  — resolver and hermes installer deeply verified (python >=3.11,<3.14 refusal at
              :108-115, HERMES_PIN 0.19.0, select() order, 28/28 tests); five installer bodies
              unread, S2 evidence is a directory listing, Path field wrong for 4 of 11 units
              (finding 4).
M6  PARTIAL  — the gate row reproduced byte-for-byte by this judge (`44 module(s): 37 VERIFIED,
              50 error(s)… MASTER-DOC: FAIL`, rc=1) and F6-1 confirmed (glob `[0-9][0-9]-*.md`
              at :188 cannot select these chapters); but all eight submodule rows lack invoking
              lines and M6-C2 asserts "works" with nothing behind it (findings 2, 3).
M7  PARTIAL (weak) — CLI surface claim verified exactly (bare invocation → usage, exit 2);
              bodies unread, the single submodule classified without an invoking line, §9 has
              no log lines of its own. One more read pass short of WRITTEN.
M8  PARTIAL  — reclaim_disk fully verified (TTL default 24 + ValueError branches, PROTECTED
              set, 9/9 tests); check_scan_scope.py unread and S2 classified by UNIT-MAP
              (finding 2).
M9  PARTIAL  — the settlement half is exactly verified (text_b64 at dispatch.go:202, verdict
              reading only payload["ok"] at :713 — the control-plane half of CF-355 is real,
              30 tables / no verdicts / 0-byte in-repo db all confirmed, build PASS); S1 and
              S5 unread with circular evidence, stamp stale (finding 1), §5 empty (finding 7).
M10 PARTIAL  — client surface, auth ladder order, ports, pgx/v5 and build all verified
              (F10-1 and F10-2 both true; deliver/retrieve/ack at :975/:1009/:1038 exact);
              the 1895-line handler and the guard unread; §9 empty (disclosed RED).
M11 WRITTEN  — dispatcher.py read in full and re-verified line-by-line by this judge: all six
              settings at their cited lines, task_seconds formula, ledger replay semantics,
              reply body :500-519 exact (deliver-before-ack, error_b64, unacked only on failed
              delivery); F11-2 confirmed — test_durable_job.py is 11 lines of prints with no
              assert and no exit code.
M12 WRITTEN  — read in full; sha256 prefix matches exactly (b12a0ac521c4b5a9…), CONTRACT
              section at :9-19, every settings line and failure branch (401/400/403, FATAL
              exit-2 startup) re-verified; control-host placement (F12-1) confirmed.

Scope note: this verdict covers the thirteen module chapters (Part III) that exist in
chapters/. Parts I, II and IV–VIII — including all eleven missing flows F6–F16 — are not
written yet and are not graded here; the outline itself marks them MISSING.
```

The measured core of this document is real: every command I re-ran reproduced its quoted output, both cross-system contract defects (CF-354 text_b64-vs-text at dispatch.go:202/node-bus-worker.py:986; CF-355 status-vs-ok at dispatch_leg.go:713/node-bus-worker.py:1132) are confirmed at the exact cited lines, and 34 of 34 cited board rows exist. What keeps it from PASS is narrow and fixable in one writer pass: four stale/circular/wrong identity-and-state assertions (findings 1–4), none of which require re-reading code the chapters already read — only re-stamping, citing invokers, measuring or downgrading four contract-state words, and correcting one path field.

PANEL REVIEW COMPLETE

session_id: local-63f5169149883543cce5068904cf6a9d5901325dedaaa540dafce9351cb2c6ab

EXIT=0
```

### grok

```
⚠️  Primary auth failed — switching to fallback: fireworks / accounts/fireworks/models/deepseek-v4p1-flash-1017
VERDICT: FAIL
BLOCKING: 7 — findings that must be fixed before these chapters can be called written
NON-BLOCKING: 9

Scope of this seat: all 13 chapters (M0–M12) read in full against the code at code-factory rev 943ef984, scheduler HEAD 1771d3aa (locators re-checked at that rev), crier 691f0c78, crier-fleet 283bca91, and `cf-inference-proxy.py` (sha256 b12a0ac5…). Every command below was run by me this round, not quoted from the chapters.

FINDINGS

1. BLOCKING — CONTRADICTION — M10 vs M2 (+ M10 §6)
   Claim (M10 §4b): "`crier_client.Crier` … a rename breaks the dispatcher (M11) **and the node worker (M2)**".
   Evidence: `scripts/node-bus-worker.py:68-78` imports `urllib.error`, `urllib.request` only — no `crier_client` anywhere in the file; M2 §4b and its own finding F2-1 measure exactly that ("the node imports urllib, not crier_client"). M10-C3 likewise attributes the node→crier reply to `crier_client.py:975 deliver`, which the node never calls.
   Fix: strike "and the node worker (M2)" from M10 §4b; re-source M10-C3 to the node's `urllib` deliver path (`node-bus-worker.py:1160-1201`) or mark the producer side unread.

2. BLOCKING — FALSE CLAIM — M9 §1 and M10 §1/§4a
   Claim: "host `go version` = go1.26.5" (M9:10, M10:10), and M10 §4a "the host go1.26.5 is below the declared 1.26.10" (implying build failure).
   Evidence: `go version` → go1.26.9 (`/home/kara/.local/bin/go`), `/usr/bin/go` → go1.26.8, `/snap/bin/go` → go1.27.1. No 1.26.5 exists on this host. `cd /home/kara/crier && go env GOVERSION` → go1.26.10, `GOTOOLCHAIN=auto`; `go build ./...` rc=0. The toolchain directive auto-selects, so the stated consequence is also wrong.
   Fix: state the measured host toolchain (1.26.9) and replace the consequence with the real one ("`GOTOOLCHAIN=auto` fetches 1.26.10; with `GOTOOLCHAIN=local` the build refuses").

3. BLOCKING — FALSE CLAIM — README §"Measured status" (document-level, contradicts its own chapters)
   Claim: "Are contracts both-sided? In chapters, yes — each §6 names producer and consumer `file:function`".
   Evidence: at least six §6 rows name a non-function consumer: M0-C1 "the `bunker` binary the CLI invokes"; M1-C1 "crier `POST /agents/{id}` handler"; M1-C2 "the `bunker` binary"; M4-C1 "the JSONL store (`tasks.jsonl`/`events.jsonl`)"; M4-C2 "`boardctl update --status complete`" (an invocation, not a function); M5-C1 "per-leg verdict"; M6-C1 "the handbook's status word"; M9-C1 both sides are prose ("operator config" / "scheduler config load"). Rule 2 is violated in 8 of 26 chapter contracts, and the README asserts the opposite.
   Fix: give every §6 row a real `file:function` on both sides, or mark the row `rumour — one side only` and change the README answer to "no — 8 of 26".

4. BLOCKING — CONTRADICTION — contract-state tally (README + OUTLINE Part I.3/IV vs chapters)
   Claim: "10 works / 6 broken / 2 missing" (README:27, README:90, OUTLINE:46).
   Evidence: the chapters measure 10 broken (M1-C1, M2-C1, M2-C2, M4-C2, M5-C1, M9-C2, M9-C3, M10-C1, M10-C3, M11-C2) and zero `missing`. The two contracts the register calls *missing* — `crier → scheduler` completion event and `node → duckbrain` (OUTLINE:211, 214) — appear in no chapter at all. The register and the chapters cannot both be right.
   Fix: recompute the register from the chapters, and either give the two missing contracts a home or list them as "no owning module" in Part I.9.

5. BLOCKING — OMISSION — M9 §5 (Settings register)
   Claim: §5 contains no setting at all — "its individual keys were not read line-by-line this round".
   Evidence: `config.example.toml` exists in the scheduler repo and OUTLINE V.6 names it as the register (intervals, weight budget, max_concurrent, tick timeout). Per the OUTLINE decision rule a setting is documented only with default + range + consequence; M9 documents zero, and its "RED field count: 3" does not count §5. Per the schema an unfilled required field *is* the finding.
   Fix: either fill §5 from `config.example.toml` with defaults/ranges/consequences, or add "§5 Settings — RED" to the chapter's RED count.

6. BLOCKING — OMISSION — M10 §9 (Log lines)
   Claim: "none captured this round … (RED)" while §1 status says only `handler.go` and the guard are unread.
   Evidence: `internal/registry/handler.go` is 1895 lines and is the custody/transport surface; the chapter cites no line of it, yet marks the module PARTIAL rather than RED for §9 and §3 S1. A critical-path bus with zero evidentiary log lines and an unread 1895-line handler is an unmeasured surface, and the chapter's own rule ("a log line that says something happened is not evidence") is not satisfiable from what was read.
   Fix: read the handler's operator-visible lines (grep `log.Printf`) and quote at least the refusal/accept/lease-expiry lines, or grade S1 and §9 RED and say the chapter is PARTIAL for that reason.

7. BLOCKING — UNVERIFIED — M1-C1 ("broken")
   Claim (M1 §6): state **broken**.
   Evidence: the same row says "token exchange not re-run this round; both sides not read". A state asserted with no command and no quoted line is `UNVERIFIED` by rule 1, not `broken` — and M1's own §1 status is UNVERIFIED.
   Fix: either run the exchange (or cite the failing board row with its log) or relabel `UNVERIFIED — both sides unread`.

8. NON-BLOCKING — CONTRADICTION — M11 §13 vs `docs/MASTER-DOC-SCHEMA.md:105` / `:111`
   Claim: "The schema worked example's own line cite was also wrong and is fixed".
   Evidence: the schema still carries two revisions for one file in the same section — header "revision `98eb5ce`" (:105) and identity "rev `283bca9`" (:111). Not fixed.
   Fix: reconcile the schema header to 283bca9.

9. NON-BLOCKING — FALSE CLAIM — M9 §8 label cite
   Claim: "Labels: namespace and outcome for `spawns` (`:235`)".
   Evidence: `internal/api/server_metrics.go:235` is the `byOutcome` seed map; the namespace/outcome labelling is described at `:20` and implemented in `metricsSpawns` (`:192`). Right idea, wrong locator.

10. NON-BLOCKING — FALSE CLAIM — M9 §6 M9-C2 field name
    Claim: `payload()` emits "field `board` (not `board_row`)".
    Evidence: `internal/bus/dispatch.go:184-186` emits `p["board"]` — correct — but the OUTLINE's contract line ("envelope: run_id, corr_id, lane, board_row, text_b64", OUTLINE:207) is left uncorrected, so the document still carries the wrong field name in Part IV while M9 corrects it in Part III.

11. NON-BLOCKING — FALSE CLAIM (stale numeric) — OUTLINE:181
    Claim: M9.S3 "`scheduler.db`, 26 tables".
    Evidence: `SELECT count(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'` → **30**; M9's F9-2 measures and reports this, but the OUTLINE text still says 26. The chapter's correction has not propagated upward.

12. NON-BLOCKING — FALSE CLAIM (outline) — OUTLINE:209 reply fields
    Claim: "node → crier — reply: `in_reply_to, corr_id, run_id, outcome`".
    Evidence: the node builds `env_version, dispatch_id, corr_id, status, host_identity, harness, vars, exit_codes, gate_exit, branch, commit, artifacts, wall_s, finished_at` (`node-bus-worker.py:1128-1144`); there is no `run_id` or `outcome` field. M2 §6 states this correctly; OUTLINE does not.

13. NON-BLOCKING — UNBUILDABLE — chapters with no derivable task
    Claim: M9 §3 S1 "active (not read this round)" and S5 "active (not read this round)".
    Evidence: classification is *evidence* under OUTLINE §"Submodule inventory" — "active" must be proven by the invoking line. Two of five submodules carry the OUTLINE's own text as their evidence ("named by OUTLINE M9.S1/S5"). A worker cannot act on "named by the outline"; it needs the invoking line (`internal/scheduler/admission_mode.go`, the cron/lane hook) or "no invoker found — grep quoted".
    Fix: replace both with a quoted grep/line, or classify `designed-not-built`/`unknown`.

14. NON-BLOCKING — PADDING (thin) — M9 §2 "What breaks if this module is absent"
    Claim: "No cadence tick fires; nothing is admitted, dispatched or settled."
    Evidence: true but consequence-free — it names no lane, no board gate, no failed row an operator would see, and no recovery, unlike the other twelve chapters which name the concrete symptom. Same shape at M7 §2 ("The fleet cannot authenticate without a human PAT") which is better because it names FACT-05.

15. NON-BLOCKING — OMISSION — M10.S3 port set
    Claim: §3/§5 document the server on 8767 and the front on 8770 only.
    Evidence: OUTLINE M10.S3 states "server :8767 / :18767". `18767` appears in no chapter and I did not verify it exists; if it does it is an undocumented listener a run can reach; if it does not, OUTLINE is wrong. Either way the chapter and the structure map disagree about the surface.

16. NON-BLOCKING — off-by-small locators (evidence hygiene, not claims)
    `harness-vars.sh` `CFV_DECLARED` cited `:28-29`, actual `:27-28`; `lib.sh` `fetch_verified` cited `:19-42`, function body is `:23-42`; `disk_floor.py` refusal cited `:68-71`, actual `:66-69`; `agentsig.go` "headers" cited `:167-186`, function starts `:162`. Each was re-checked by hand and the substance holds; the locators must still point at the line they describe, because the next reader will not re-derive them.

DEFECT CLASSES
- cross-chapter contradiction on a shared dependency (client library, contract field list)
- unmeasured host version copied between chapters (single stale number reused as measured fact)
- document-level register contradicted by its own chapters (contract tally, both-sides claim)
- outline numbers not propagated after chapter corrections (26 tables, reply fields, board_row)
- required field left empty and not counted as RED (M9 §5)
- status asserted without a command (M1-C1 "broken")
- classification carried on outline language instead of an invoking line (M9 S1/S5)
- critical-path surface unread but graded PARTIAL (M10 handler, §9)
- locator drift of ±1–4 lines

CHAPTER SCORECARD
- M0 SHARED CONTRACT — WRITTEN. Every cited line re-verified: `lib.sh:5-9,13,48-57,60-64,67-70,75-78` exact; `harness-vars.sh:66,176-185,190-192,204,218-220,249,276-277,286,292` exact; greps reproduce exactly (11 direct / 17 total / 20 `.sh`); CF-105/CF-109 absent from the board, CF-280/CF-229 `complete` — verified. Only defect: `CFV_DECLARED` off by one.
- M1 PROVISIONING — PARTIAL. `:181 have bunker`, `:182 bad bunker_cli`, `:214` non-emptiness probe, `:233` "mode 600 (value not read)", `:187/:225-226` timeouts all exact; `test_disk_floor.py` 12 tests OK. Blocked by M1-C1 "broken" with both sides unread.
- M2 DISPATCH — WRITTEN. Strongest chapter: `dispatch.go:202 text_b64` and `dispatch_leg.go:713 dispatchReplyVerdict`(reads only `ok`) both exact; reply field list `:1128-1144` exact; constants `:80-84,:111-113` exact; `test_lane_target.py` 40 tests OK; `urllib`-not-`crier_client` verified.
- M3 REPOSITORY — WRITTEN. 295/180/130-line counts exact; `:56,:167,:214,:231,:265,:291,:294,:284-287` exact; `refuse_same_lane` `:38-45` called `:65-68` **before** `sqlite3.connect:70` — verified, so CF-357 is genuinely closed. Its "arm 51 is the single RED case" claim reproduces: `ruff check` on the tracked surface returns F841 `scripts/panel_loop.py:114`.
- M4 BOARD — WRITTEN. 357 rows / 515 events reproduced; wrapper `exec boardctl -C "$ROOT"` + exit 127 reproduced; `boardctl --help` lists exactly 20 verbs and `version` → `dev`; `board_drift check` → `RESULT: OK`, 357 vs 357, HEAD ancestry pass.
- M5 HARNESS — WRITTEN. `install-hermes.sh:21,24,26,27-30,108-115,296,352` exact; host Python 3.14.9 vs adapter's `>=3.11,<3.14` refusal is a real, reproduced contradiction; `harness_resolve.py:211` default `hermes` exact; `test_harness_resolve.py` 28 tests OK; `install-gitreins.sh:12,105` exact.
- M6 DOCUMENTATION — WRITTEN. Headline reproduced byte-for-byte: `44 module(s): 37 VERIFIED, 50 error(s), 0 warning(s), 10 fact(s)`, `MASTER-DOC: FAIL`, rc=1; `:39-41,:52,:160,:188,:221,:263` exact.
- M7 GITHUB — WRITTEN (thin). `python3 -B scripts/github-app-token.py` → usage, rc=2 reproduced; four subcommands match. Status UNVERIFIED is honestly declared.
- M8 SAFETY — WRITTEN. 169 lines; `reclaim()` `:42`, root check `:44-45`, TTL validation `:46-47`, `main()` `:129`, `BUILD_CACHES/AGED_PARENTS/PROTECTED` `:14-22` all exact; `test_reclaim.py` 9 tests OK.
- M9 SCHEDULER — PARTIAL. Settlement/verdict locators exact at current HEAD; 30 tables / no `verdicts` / 0-byte in-repo db reproduced; `server_metrics.go:42,:76-80,:125` exact; `go build ./...` rc=0. Blocked by the wrong host Go version and the empty §5.
- M10 CRIER — PARTIAL. `691f0c78` matches stamped rev exactly; `go.mod go 1.26.10`; `handler.go` 1895 lines; `config.go:622 Port 8767`; `crier-front/main.go:39 127.0.0.1:8770`; `agentsig.go:162,204,365`; `detect.go:94 crier_detect_alerts_total`; build rc=0. Blocked by the Go-version claim and the `crier_client`/node contradiction.
- M11 DISPATCHER — WRITTEN. `283bca91` exact; 538 lines; `:43,46,48,52,53,60` settings exact; `:365 ledger_load` exact; compiles. Only defect is its claim that the schema cite is fixed.
- M12 INFERENCE PROXY — WRITTEN. Best-evidenced chapter: 273 lines and full content sha256 `b12a0ac5…` reproduce; `:43,:45,:48,:53,:54,:60-62,:115-123,:128-130,:154,:155-160` all exact, including the 400/403 bodies.

What this round actually gains: the chapters are no longer file-census prose — 12 of 13 carry line-exact, reproducible evidence, and three panels' worth of prior defects (PASS-over-zero, "no settlement", "no age gate", tree-only gates) are refuted with commands. What blocks them is not missing evidence but three unmeasured numbers reused across chapters (host Go, host Python in M5 is *correct*, contract tally), one register that contradicts its chapters, two required fields left empty and uncounted, and two chapters that still assert a cross-module dependency the other chapter measured false. Fix those seven and this is a PASS set.

PANEL REVIEW COMPLETE

session_id: local-26749eb267168b52903437b6a91fad3eaf2801b19a8d7678c7d5f34194afb9fb

EXIT=0
```

### kimi

```
All claims I could reach have now been exercised. Composing the verdict.

VERDICT: FAIL

BLOCKING: 4 — findings that must be fixed before this chapter set can be called written
NON-BLOCKING: 5

FINDINGS:

1. kind: FALSE CLAIM (stale measurement)
   chapter: M9 §1 Identity; M10 §1 Identity + F10-2
   claim: "host `go version` = go1.26.5" (both chapters)
   evidence: measured this panel, 2026-11-06: `cd /tmp && go version` -> go1.26.9; inside the scheduler repo the toolchain directive resolves go1.26.6. The Identity field's measured runtime is contradicted by the system it was measured on. Note: the substance of F10-2 (host toolchain below crier's declared `go 1.26.10`, go.mod verified) survives at 1.26.9 < 1.26.10 — only the number is wrong.
   fix: re-measure on the control host, restamp both Identity fields, adjust F10-2's values.

2. kind: UNVERIFIED (outline cited as evidence for code claims)
   chapter: M10 S1, S2, §9
   claim: custody/transport behaviour (registration, leases, ack, TTL, dead letters) and the guard pipeline "pattern pre-scan -> render -> router verdict -> escalation -> quarantine"; §9 log lines "none captured this round (RED)"
   evidence: the sole citation is "named by OUTLINE M10.S2". The 1895-line `internal/registry/handler.go` (wc -l, confirmed) and the guard were not read; no claim carries a file:line from the code. This is exactly the forbidden move — judging/writing from the outline's own language. M10 self-counts 4 RED fields.
   fix: read the handler and the guard, attach file:line per claim, capture verbatim operator log lines with descriptive/evidentiary classes.

3. kind: UNVERIFIED (outline cited as evidence; test row not run)
   chapter: M9 S1, S5, §7
   claim: S1 admission internals (admission_mode, tick_process, packer_select, namespace_alloc, usage_pool_policy) and S5 doctrine (six documents) are "active"; evidence "named by OUTLINE M9.S1/S5". §7 `go test ./...` "not run this round — UNVERIFIED".
   evidence: no invoking line, no package read, no test output. S1 is the module's stated core authority ("it decides whether a tick is admitted") and carries zero code evidence.
   fix: read the admission packages and the doctrine docs, cite file:line, run `go test ./...` at the stamped rev and record the result.

4. kind: CONTRADICTION (state word contradicted by the chapter's own evidence)
   chapter: M11 §6, contract M11-C2
   claim: "**broken** — CF-355 (scheduler reads `ok`, node-side sends `status`)"
   evidence: the row's own producer is the dispatcher, and `dispatcher.py:500-508` (verified) always sends `ok` (`body = {"in_reply_to": mid, "agent": agent, "ok": ok, ...}`), which is exactly the field `dispatchReplyVerdict` (dispatch_leg.go:713-726, verified) reads. The status-dialect defect is the node-bus-worker's (M2-C2, correctly marked broken there). M11-C2 as written disagrees with M2-C2 and with its own quoted payload.
   fix: mark M11-C2 works (ok-carrying leg), keep CF-355 attached to M2-C2 / M9-C3 only.

5. kind: UNVERIFIED -> verified by this panel (upgrade available)  [NON-BLOCKING]
   chapter: M1 §5
   claim: floor precedence "--disk-floor > NODE_DISK_FLOOR > [disk] config > role default", self-flagged UNVERIFIED
   evidence: `disk_floor.py:115-141` resolve() implements exactly that order (cli :127, env :129, config, role-default :141); 12 unit tests pass.
   fix: remove the UNVERIFIED flag; cite :115-141.

6. kind: IMPRECISE DEFECT NAME  [NON-BLOCKING]
   chapter: M3 §10 (python lint gate row)
   claim: "a tracked `.py` with an unused import is committed (selftest arm 51 FAIL)"
   evidence: arm 51's red sub-case is F841 "Local variable `rc` is assigned to but never used" at `scripts/panel_loop.py:114` (reproduced this panel: SELFTEST: FAIL (1)); the unused-import leg (F401) is the green fixture half.
   fix: name F841 and the file.

7. kind: TRUNCATED EVIDENCE  [NON-BLOCKING]
   chapter: M12 §1
   claim: content sha256 `b12a0ac521c4b5a9cd7e2b76883a7edf2c9e0efd`
   evidence: real digest is 64 hex chars: b12a0ac521c4b5a9cd7e2b76883a7edf2c9e0efd87d9bc3be3d2056d3f39e0b5 (sha256sum, reproduced). The chapter prints a 40-char prefix labelled as the sha256.
   fix: print the full digest or label it as a prefix.

8. kind: FORMAT BREAK (table cell corrupts a contract row)  [NON-BLOCKING]
   chapter: M12 §6, M12-C1
   claim: producer cell "node `POST /v1/chat/completions` with `Authorization: Bearer *** | ..."
   evidence: unclosed inline-code backtick; the token rendering bleeds across the column separator, so the row's producer/consumer columns do not parse as written.
   fix: repair the markdown.

9. kind: NAME-ONLY CLASSIFICATION + STATE-VOCABULARY MISUSE  [NON-BLOCKING]
   chapter: M5 S2 (five foreign installers), M6 S1/S2/S4-S8, M8 S2; M1-C1
   claim: classifications "active" resting on "listed in `scripts/harness/`" or "named by UNIT-MAP/OUTLINE"; M1-C1 state "broken" where the text says "not re-run this round; both sides not read".
   evidence: the outline's classification rule requires an invoking file:line or a quoted absence grep; a directory listing is neither. And a contract not exercised is UNVERIFIED, not broken — the state vocabulary is the register's whole point.
   fix: attach invoking lines or absence greps; reword M1-C1 to UNVERIFIED.

REPEATABILITY (panel re-ran the chapters' own commands):
  Reproduced exactly: M0 grep counts (11/17, 20 .sh files), ghost-row check (CF-105/CF-109 absent; CF-229/CF-280 real), M1 disk_floor 12 tests, M2 lane_target 40 tests, M3 land-node-branch.sh --dry-run against a scratch fixture ("LAND: DRY-RUN — 0 commands run, nothing merged or pushed, no ref moved", rc=0, both the ahead and already-landed variants), selftest arm 41 PASS / arm 51 FAIL, M4 357 rows / 515 events / board_drift RESULT OK / boardctl 20 subcommands / --evidence-run-id requirement / version dev, M5 harness_resolve 28 tests, M6 gate ("44 module(s): 37 VERIFIED, 50 error(s), 0 warning(s), 10 fact(s)", MASTER-DOC: FAIL, exit 1 — byte-identical), M7 exit 2 usage, M8 reclaim 9 tests, M9 30 tables / no verdicts table / 16.87 GB live store / 0-byte in-repo db / go build PASS, M10 go build PASS / agentsig refusal order / conditional enforcement / ports / client method lines, M11 every settings and log cite, M12 admission paths and fail-closed startup lines.
  Exercised for the first time: M0's UNVERIFIED fetch_verified row — with curl absent it returns 1 and leaves no artifact (fails closed, as the code at lib.sh:19-27 reads).
  Not repeatable from this control host, correctly flagged by the chapters: the two cf-node-only checks (M2 §7, M10 §7). Confirmed `~/node-bus-worker.py` does not exist on this host; the flag is honest.

DEFECT CLASSES:
  STALE-MEASUREMENT (identity-field value drifted from the system)
  OUTLINE-AS-EVIDENCE (code claims sourced from the outline, not the code — the round-1 disease, surviving in M9 S1/S5 and M10 S1/S2)
  WRONG-STATE-WORD (broken vs works vs UNVERIFIED misused, M11-C2, M1-C1)
  NAME-ONLY CLASSIFICATION (active/resting on a directory listing or a map row)
  IMPRECISE-DEFECT-NAME (F401 vs F841)
  TRUNCATED-DIGEST, FORMAT-BREAK

CHAPTER SCORECARD:
  M0  WRITTEN  — both files read in full; every cited line re-verified by this panel; findings F0-1..F0-4 exact (CF-105@:15, CF-280@:16, CF-109@:47 all confirmed); metrics RED honestly declared.
  M1  PARTIAL  — probe and disk_floor verified, but the chapter itself stamps UNVERIFIED: 9 of 13 unit bodies unread. Honest partial.
  M2  WRITTEN  — contracts, reply shape, constants and both broken dialects (CF-354/CF-355) verified line-exact against both repos; non-repeatable check flagged truthfully.
  M3  WRITTEN  — dry-run reproduced by the panel from a fresh fixture; hooks, gate pin, freshness arms all confirmed; one imprecise defect name (finding 6).
  M4  WRITTEN  — store counts, drift, wrapper 127, 20 verbs, evidence-run-id refusal all reproduced.
  M5  PARTIAL  — resolver, vars contract and hermes installer verified; five foreign installer bodies unread (classification by directory listing); conformance battery UNVERIFIED.
  M6  PARTIAL  — the gate is verified and its live FAIL reproduced byte-identical, but only one of ten units was read; the rest are active-by-name.
  M7  PARTIAL  — CLI surface and refusal shape verified; bodies unread, mint UNVERIFIED (no App creds on host — honestly stated); settings register is one row.
  M8  PARTIAL  — reclaim_disk fully verified (TTL, safety, tests); check_scan_scope unread, S2 classification by map row only.
  M9  PARTIAL  — settlement leg and durable state measured and correct (30 tables, no verdicts, F9-1/F9-2 valid); but admission (S1) and doctrine (S5) carry no code evidence, go test unrun, and the identity runtime is stale (finding 1).
  M10 PARTIAL  — auth order, client surface, ports, metrics and the F10-1 correction all verified; the custody handler and the guard — the bus itself — are outline-sourced; log-lines section empty (RED); identity runtime stale (finding 1).
  M11 WRITTEN  — full read, every cite verified, F11-2 (tests that don't assert) is a real catch; one wrong state word on C2 (finding 4).
  M12 WRITTEN  — full read, admission/routing/streaming/capture verified; live-admission row honestly UNVERIFIED; digest truncation and table-cell nits (findings 7, 8).

Summary for the loop: the measured work in this round is real and reproducible — the panel could re-run nearly every command and get the chapters' numbers. The failure is coverage, not fabrication: the scheduler's admission authority and the bus's custody/guard internals are still described from the outline instead of the code, one identity measurement is already stale, and one contract state contradicts its own evidence. Fix findings 1-4 and this document is within reach of PASS.

PANEL REVIEW COMPLETE

session_id: local-90d78e87482cfb292d002ec4735a7019476583d610f6e3a8f4ffb07aa1d4db77

EXIT=0
```

### sol

```
│ cache/scratch/quorum-round2-sol-probes.py
│ @@ -0,0 +1,75 @@
│ +"""Offline, isolated probes of the implementations; no fleet calls or keys."""
│ +import ast
│ +import io
│ +import json
│ +import os
│ +from pathlib import Path
│ +import runpy
│ +import subprocess
│ +import tempfile
│ +import types
│ +from unittest.mock import patch
│ +
│ +ROOT = Path('/home/kara/code-factory')
│ +with tempfile.TemporaryDirectory(prefix='quorum-cfv-', dir=os.environ['TMPDIR']) as td:
│ +    key = Path(td) / 'not-a-real-credential'
│ +    key.write_text('fixture-only\n')
│ +    env = dict(os.environ)
│ +    for name in ['CF_API_KEY', 'OPENAI_API_KEY', 'ANTHROPIC_API_KEY']:
│ +        env.pop(name, None)
│ +    shell = f'. {ROOT}/scripts/lib.sh; . {ROOT}/scripts/harness/harness-vars.sh; CFV_VALUE[CF_API_KEY_FILE]="$1"; cfv_validate check; cfv_refused && exit 2; exit 0'
│ +    for mode in [0o400, 0o600, 0o700, 0o644]:
│ +        key.chmod(mode)
│ +        p = subprocess.run(['bash', '-c', shell, 'probe', str(key)], env=env, text=True, capture_output=True)
│ +        rows = [s for s in p.stdout.splitlines() if 'contract:CF_API_KEY_FILE' in s and ('PASS' in s or 'FAIL' in s)]
│ +        print(json.dumps({'probe':'credential-file-mode','mode':oct(mode),'rc':p.returncode,'rows':rows}))
│ +    env['CF_API_KEY'] = ''
│ +    p = subprocess.run(['bash','-c',f'. {ROOT}/scripts/lib.sh; . {ROOT}/scripts/harness/harness-vars.sh; cfv_validate check; cfv_refused && exit 2; exit 0'], env=env, text=True, capture_output=True)
│ +    print(json.dumps({'probe':'empty-ambient-CF_API_KEY','rc':p.returncode}))
│ +
│ +# Load only the pure task_seconds implementation, never dispatcher import-time code.
│ +tree = ast.parse(Path('/home/kara/crier-fleet/dispatcher.py').read_text())
│ +fn = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'task_seconds')
│ +ns = {'TASK_S':'240','CAP_S':7200,'MARGIN_S':60}
│ +exec(compile(ast.Module(body=[fn],type_ignores=[]),'dispatcher.py','exec'),ns)
│ +for wall in [0,10,60,90,600]:
│ +    print(json.dumps({'probe':'dispatcher-deadline','wall_s':wall,'task_seconds':ns['task_seconds'](wall)}))
│ +
│ +# Run the real proxy forwarding method with an injected upstream that breaks after one chunk.
│ +# This is an offline failure-injection probe, not a live upstream measurement.
│ +proxy = runpy.run_path('/home/kara/.hermes/scripts/cf-inference-proxy.py',run_name='quorum_proxy_import')
│ +Handler = proxy['Handler']
│ +h = object.__new__(Handler)
│ +h.path = '/v1/chat/completions'
│ +h.wfile = io.BytesIO()
│ +statuses = []
│ +h.send_response = lambda code: statuses.append(code)
│ +h.send_header = lambda *args: None
│ +h.end_headers = lambda: None
│ +usage = []
│ +class BreakingUpstream:
│ +    status = 200
│ +    headers = {'Content-Type':'text/event-stream'}
│ +    reads = 0
│ +    def read1(self, size):
│ +        self.reads += 1
│ +        if self.reads == 1:
│ +            return b'data: {"fixture":"partial"}\n\n'
│ +        raise OSError('injected upstream disconnect')
│ +g = Handler._forward.__globals__
│ +with patch.dict(g, {'upstream_key': lambda: 'fixture-only', 'log_usage': usage.append}), patch('urllib.request.urlopen', return_value=BreakingUpstream()):
│ +    h._forward('POST','fixture-node',b'{"model":"hermes","stream":true}')
│ +print(json.dumps({'probe':'proxy-partial-stream','http_statuses_sent':statuses,'bytes_sent':len(h.wfile.getvalue()),'usage':usage}))
│ +
│ +# Exercise actual admission without a server socket, tokens, or provider traffic.
│ +h2 = object.__new__(Handler)
│ +h2.path = '/v1/chat/completions'
│ +body = b'{"model":"definitely-disallowed"}'
│ +h2.rfile = io.BytesIO(body)
│ +h2.headers = {'Content-Length':str(len(body))}
│ +h2._node = lambda: 'fixture-node'
│ +answers = []
│ +h2._json = lambda code, obj: answers.append((code,obj))
│ +with patch.dict(g, {'log_usage': usage.append}):
│ +    h2.do_POST()
│ +print(json.dumps({'probe':'proxy-disallowed-model','answers':answers}))
VERDICT: FAIL
BLOCKING: 34 — findings that must be fixed before the affected chapters can be called written
NON-BLOCKING: 0

FINDINGS:

Review basis:
  Read all 13 chapters, OUTLINE.md, MASTER-DOC-SCHEMA.md, and the implementation paths cited below. No previous judge verdict was used.

  Code-factory HEAD: 943ef984dc093e5780605ac6e54cd043122126ef
  Crier HEAD: 691f0c78fc75717295abf3bd85aaa9192616aac0
  Dispatcher HEAD: 283bca91091933177ec521e52f37f1bc987cf7da

  Scheduler HEAD at review was 1771d3aad61e6c1ce2845e3f1450f88aa73340b3, ahead of the chapter’s dfa9c84f stamp. The intervening commits did not change the dispatch, verdict, or metrics files used for the findings below. I do not classify an earlier live database census as false merely because that database subsequently changed.

  Independently repeated:
    test_disk_floor.py: 12 tests, OK, exit 0.
    test_lane_target.py: 40 tests, OK, exit 0.
    test_harness_resolve.py: 28 tests, OK, exit 0.
    test_reclaim.py: 9 tests, OK, exit 0.
    Shell syntax sweep: 20 files, 0 failures.
    lib.sh source census: 11 direct, 17 total.
    Board census: 357 task rows, 515 event lines.
    Board drift check: RESULT: OK, exit 0.
    Default documentation gate: 44 modules, 37 labelled VERIFIED, 50 errors, exit 1.
    Documentation gate pointed at chapters/: selected 0 modules, exit 1.
    Bare github-app-token.py: usage, exit 2.
    Isolated boardctl completion without evidence-run-id: refused, exit 1; row remained pending.

  Additional offline probes exercised the real credential validator, dispatcher deadline function, and proxy handler with injected fixtures. Their results are identified below; they are not live fleet measurements.

  Not repeated: provisioning or installation against a real node, live GitHub minting, remote durable-job/kill/boundary tests, scheduler/crier builds, or their full Go suites. Those historical results remain historical, not independently certified by this verdict.

B01 — BLOCKING — UNVERIFIED
  Chapters: M0–M12, contract registers.
  Claim: Tables headed “Producer file:function” and “Consumer file:function” declare contracts “works.”
  Evidence: M1:81 names a shell script and an unnamed HTTP handler; M4:64–65 names commands, a store, and “the judge’s verdict”; M5:80–81 substitutes “per-leg verdict” and “the node gateway” for implementation functions; M6:71–72 names “the handbook’s status word” and “the owner’s approval artifact.” M12:70 names only “the upstream gateway/provider.” These are not both implementation endpoints.
  Fix: For each in-scope contract, supply the actual producing and consuming file:function, payload, timing, acknowledgement, failure semantics, and compatibility rule. Identify external-system boundaries explicitly rather than pretending a product name is a function. Mark unresolved contracts UNVERIFIED.

B02 — BLOCKING — UNVERIFIED
  Chapters: M1–M12, submodule classifications.
  Claim: Units are “active” because they are “run-path scripts,” appear in a directory, have main(), are tested, or are named by OUTLINE.
  Evidence: M2:34–36 uses tests and descriptive statements; M3:35–36 uses an entrypoint and flow ownership; M5:34–37 uses comments, directory presence, and a pin; M9:33,37 and M10:33 use OUTLINE as evidence. OUTLINE:108–113 requires an invoking scheduler lane, cron, timer, or another unit, with an invoking line. Test invocation does not establish operational activation.
  Fix: Trace actual callers and deployment activation for each unit. Where no operational caller is established, classify it as optional, legacy, or unverified according to the evidence—not active by assertion.

B03 — BLOCKING — OMISSION
  Chapters: M0–M8, M11, M12.
  Claim: “RED — none” in Metrics is followed by treatment of the chapter as written.
  Evidence: Each affected chapter explicitly records missing metrics. MASTER-DOC-SCHEMA.md:72–79 makes “none” a mandatory RED field, not a completed field.
  Fix: Retain these chapters as PARTIAL while that requirement is unmet. Resolve the observability requirement through implementation or an explicit, approved schema exception; do not equate honestly naming RED with satisfying the field contract.

B04 — BLOCKING — CONTRADICTION
  Chapters: M0–M12 and handbook status register.
  Claim: README:63–75 labels M0–M8 and M11–M12 “WRITTEN”; README:77 defines WRITTEN as satisfying the field contract.
  Evidence: M1:12 and M7:12 explicitly say UNVERIFIED and acknowledge unread bodies. M5:12 leaves five installer bodies unread. M6:12 leaves most of the pipeline unread. M9:12 and M10:12 use PARTIAL as their Identity Status, although the schema at :21 permits VERIFIED / UNVERIFIED / FAILING. RED summaries also omit unresolved fields—for example M9’s unwritten settings register.
  Fix: Separate chapter completeness from implementation verification. Use the schema’s status vocabulary for Identity, and WRITTEN/PARTIAL/SKELETON for chapter completeness. Recompute the status register and RED inventories from actual unresolved fields.

B05 — BLOCKING — FALSE CLAIM
  Chapter: M0.
  Claim: “non-600 mode refused”; “CF_API_KEY … set at all → refusal” (M0:67–69).
  Evidence: harness-vars.sh:201–204 accepts the pattern [0-7]00, not exactly 600. Its ambient-key checks at :176 and :181 test nonempty values, not whether a variable is set.
  Measured: Fixture files at modes 400, 600, and 700 were accepted, exit 0; 644 was refused, exit 2. CF_API_KEY set to an empty string was accepted, exit 0.
  Fix: Document the predicates actually enforced, including their deviation from the stated credential law. Do not describe the stronger intended policy as implemented.

B06 — BLOCKING — FALSE CLAIM
  Chapters: M0, M5.
  Claim: The shell variable contract is “the single implementation” and CF_TIMEOUT_S defaults to 1800 across the harness register.
  Evidence: install-codex.sh sources harness-vars.sh at :47 but separately defines VAR at :67–72, validate_vars at :190, and credential validation at :276–280. It sets TIMEOUT_S from CF_TIMEOUT_S with a default of 300 at :60 and uses it for timeout at :551–555. That is not the shared 1800-second implementation described by M0/M5.
  Fix: Document the independent validator and adapter-specific defaults, including disagreement with shared-contract/help text. Do not claim centralized enforcement merely because a file is sourced.

B07 — BLOCKING — FALSE CLAIM
  Chapter: M1.
  Claim: “an unrecognised role falls to the worker floor” (M1:71).
  Evidence: disk_floor.py:122–125 raises FloorError for an unknown role; :169–171 returns exit 2.
  Measured: disk_floor.py resolve --role unknown-role --explain printed “FAIL disk-floor: unknown role …” and exited 2.
  Fix: State that an absent role defaults to worker, but an unknown explicit role is refused.

B08 — BLOCKING — OMISSION
  Chapter: M1.
  Claim: S5 is “prove the node works,” but its verification section supplies parsing/compilation and a disk-floor unit test.
  Evidence: verify-node.sh:49–103 checks execution, control-host reachability, and unauthenticated refusal; :105–114 checks optional artifact integrity; :131–153 checks checkout freshness; :172–198 checks seed drift and unknown-state policy. Its controls include --strict-freshness and --strict-seed at :20–28. These operational certification legs and their controls are not documented as repeatable procedures in M1.
  Fix: Document the actual certification invocation, prerequisites, per-leg expected observations, FAIL versus UNVERIFIED outcomes, strictness controls, and recovery/recheck sequence. Syntax checks cannot certify a node.

B09 — BLOCKING — FALSE CLAIM
  Chapter: M2.
  Claim: “dispatch_wall clamps limits.wall_s to 1..86400” (M2:114–115).
  Evidence: node-bus-worker.py:1152–1157 accepts a numeric value only when 0 < wall <= 86400, converts it to int, and otherwise falls back to args.harness_wall or 1800. It does not clamp. A fractional positive value below one is converted to zero.
  Fix: Describe acceptance, integer conversion, and fallback precisely. Add boundary examples instead of claiming a clamp the code does not perform.

B10 — BLOCKING — OMISSION
  Chapter: M2.
  Claim: “declare and configure lanes” is documented as an active, usable submodule.
  Evidence: configure_family.py:24–28 hardcodes PID “1755676,” reads /proc/<PID>/environ at module startup, and extracts SCHEDULER_OPERATOR_TOKEN without a fallback. This can fail before configuration or the chapter’s listed “partial write” failure mode.
  Fix: Document this prerequisite, startup failure, and safe operator diagnostic. Mark the configuration path unverified/nonportable until its credential acquisition contract is established. Compilation does not exercise this dependency.

B11 — BLOCKING — FALSE CLAIM
  Chapter: M3.
  Claim: “Gives the node the right tree (clone_lane.py, repo_freshness.py)” and “S1 clone and track freshness” (M3:16,35).
  Evidence: clone_lane.py:2 says it clones a lane row. Its implementation reads projects at :74, copies fields at :82–97, inserts/updates projects at :106–119, and sets enabled=0. It performs no Git clone.
  Fix: Distinguish lane-row cloning from repository checkout creation. Place lane cloning in its actual scheduler-configuration contract and identify the real producer of the node’s Git checkout.

B12 — BLOCKING — OMISSION
  Chapter: M3.
  Claim: The gate is described as part of landing without exposing its bypass-by-default.
  Evidence: land-node-branch.sh:36 initializes GATE to an empty string; :76 sets it only through --gate-cmd; :171–193 runs no project gate when it is empty. M3’s settings table omits this control. install-gitreins.sh:120–136 writes a target hook, but that does not make the landing command’s optional gate mandatory.
  Fix: Document --gate-cmd, its empty default, the no-gate path, and its consequence. Separately document how effective Git hook configuration is verified; a generated hook file is not proof Git invokes it.

B13 — BLOCKING — UNVERIFIED
  Chapter: M4.
  Claim: “store integrity” is proved by jq -r '.id' … | wc -l returning 357 (M4:71).
  Evidence: That command counts extracted IDs. It does not validate uniqueness, status vocabulary, dependency relationships, evidence binding, or other row invariants. Board drift proves byte equality with a reference, not semantic correctness.
  Measured: I reproduced the counts and byte parity. I also independently established the missing-evidence completion refusal in an isolated board, which is stronger than the chapter’s claimed help-text evidence.
  Fix: Rename the count check as a census. Add boardctl validation and explicit negative fixtures for the invariants claimed. Include the complete fixture command and expected refusal/readback.

B14 — BLOCKING — FALSE CLAIM
  Chapter: M5.
  Claim: The resolver “decides which harness runs a model” as the run’s “single resolver” (M5:16–18).
  Evidence: Searching scripts/ for harness_resolve/harness-resolve found only the resolver’s own file. The node’s actual selection at node-bus-worker.py:405–409,459–469 uses node identity/command configuration and otherwise constructs a Hermes command. Dispatcher execution at dispatcher.py:260 invokes Hermes directly.
  Fix: Describe the resolver as a standalone selection facility unless an operational caller is demonstrated. Document the actual run selection path and the missing integration instead of presenting a tested resolver as a wired runtime authority.

B15 — BLOCKING — FALSE CLAIM
  Chapter: M5.
  Claim: “It also installs and certifies each harness at an exact pin” (M5:17–18).
  Evidence: install-opencode.sh:4–6 identifies the installer as unverified; :92–94 unconditionally refuses --apply. The chapter does not explain this support limitation. Its settings/dependencies also omit concrete foreign-adapter controls such as CF_CODEX_PIN at install-codex.sh:49 and Claude’s Node minimum at install-claude-code.sh:43.
  Fix: Publish an adapter capability/status matrix distinguishing contract validation, installation, invocation, and certification. Document each adapter’s actual pin, runtime prerequisites, settings, and refused/unimplemented legs.

B16 — BLOCKING — FALSE CLAIM
  Chapter: M6.
  Claim: The gate “decides whether that description is true” and “recomputes VERIFIED” (M6:16–17).
  Evidence: master_doc_check.py:94–125 checks headings and locator existence/line bounds. At :128–138 it reads the document’s supplied status and imposes citation requirements; it does not verify that cited code supports the prose. At :215–216 it retains/counts that supplied status even when errors exist.
  Measured: The gate reported “37 VERIFIED” alongside 50 errors. It selected no M-numbered chapters when explicitly pointed at chapters/.
  Fix: Describe this as a structural/citation gate, not a semantic truth verifier. Explain how semantic review is supplied, how computed validity differs from an input status stamp, and how these chapters enter an enforceable check.

B17 — BLOCKING — OMISSION
  Chapter: M6.
  Claim: The documentation pipeline’s panel and loop are represented as active mechanisms without documenting their actual selection and launch dependencies.
  Evidence: master_doc_panel.py:67–71 still resolves modules under docs/master. panel_loop.py:33–34 depends on a fanout script and seat manifest under a dated scratch directory. Its unfinished_chapters at :62–70 searches III.* identifiers and filenames, while the submitted files are M*.md.
  Fix: Document both panel mechanisms, their incompatible selection conventions, persistent prerequisites, failure indications, and exact invocation paths. Mark unresolved paths RED. Listing “panel loop” is not a deployable procedure.

B18 — BLOCKING — OMISSION
  Chapter: M7.
  Claim: The module “decides how an App credential is minted, cached and refreshed,” but the entire settings register contains only “subcommand.”
  Evidence: github-app-token.py:45–52 defines credential/config paths, JWT timing, and HTTP timeout; :108–117 exposes env-file/API controls; :719–723 exposes cache-age control. github-app-refresh.sh:24–33,39–53 exposes destination, node/server, minimum age, and credential-store controls. Its local/no-op/mode-check and node-install branches at :104–174 have materially different effects.
  Fix: Write the lifecycle: initial human/App prerequisites, file locations and modes, mint/check distinctions, age-based reuse, refresh scheduling, local versus remote installation, expiry, failure, and readback. Provide complete commands, not “token …”.

B19 — BLOCKING — OMISSION
  Chapter: M8.
  Claim: check_scan_scope.py is summarized as ensuring a gitleaks claim names --log-opts.
  Evidence: check_scan_scope.py:31–34 limits inspection to two specific path patterns. At :64–68 the test is a case-sensitive, same-physical-line substring rule. At :109–114 no matching posture documents is an OK result.
  Fix: Document the exact scan surface, lexical rule, exit codes, empty-selection behavior, and a positive/negative fixture command. Without these, the reader cannot determine what a green scope check actually covered.

B20 — BLOCKING — OMISSION
  Chapters: M8, M11.
  Claim: M8 “reaps … expired job/clone directories,” adjacent to the dispatcher’s job/evidence discussion.
  Evidence: reclaim_disk.py:21 enumerates only .node/jobs and .node/clones. Dispatcher jobs are created under /home/bunker-<agent>/.cf-jobs at dispatcher.py:200–201,227–229. That directory is not a reaper target.
  Fix: Enumerate the actual deletion roots and explicitly identify the dispatcher-job retention gap. Do not imply this reaper maintains or threatens all job directories uniformly.

B21 — BLOCKING — OMISSION
  Chapter: M9.
  Claim: The scheduler’s admission authority is represented, but its settings register says individual keys were not read.
  Evidence: M9:59–60 is an explicit placeholder. Actual behavior includes admission-mode precedence at admission_mode.go:94–106, board-ownership distinctions at :48–69, and usage-pool authority/observe-only/reservation paths at usage_pool_policy.go:21–76. config.example.toml:12–16 also warns that portions of the example configuration are not loaded by daemon boot.
  Fix: Document operative configuration readers, precedence, defaults, ranges, and consequences for admission and allocation. Distinguish example/intended configuration from loaded configuration. Names of packages and settings are not a scheduler operating chapter.

B22 — BLOCKING — OMISSION
  Chapter: M9.
  Claim: S3 “durable state” is represented principally by a database path, size, table count, and absence of verdicts.
  Evidence: The implementation has distinct tick_dispatch storage at internal/database/migrations.go:1217 and execution_runs, execution_attempts, execution_events, execution_projections, and execution_outbox at :1391–1479, with migration entrypoint at :2036. Their ownership and transitions are not described in M9.
  Fix: Document run-affecting stores and their producer/consumer functions, keys, state transitions, transactions, migration, restart recovery, and failure indications. A table census is not a durable-execution contract.

B23 — BLOCKING — FALSE CLAIM
  Chapter: M10.
  Claim: Prometheus metrics are behind an “opt-in GET /metrics surface” (M10:81–84).
  Evidence: config/config.go:667–673 defaults EnableMetrics to true. At :1227–1232 CR_ENABLE_METRICS explicitly overrides it. cmd/server/observability.go:101–109 mounts the route and logs its authentication posture.
  Fix: State that metrics are enabled by default, document the disabling override, and distinguish metrics from opt-in pprof. Add scrape/auth instructions and the actual metric register.

B24 — BLOCKING — CONTRADICTION
  Chapters: M2, M10.
  Claim: M10:51 says renaming the Python client breaks “the dispatcher (M11) and the node worker (M2).”
  Evidence: M2:52,130–132 correctly says the node does not import crier_client. node-bus-worker.py uses its own HTTP/signing implementation, including deliver at :1160–1182 and ack at :1185–1201. Dispatcher imports Crier at dispatcher.py:34–36.
  Fix: Identify the dispatcher as the Python-library consumer and the node worker as an independent wire-protocol consumer. Correct M10’s contract rows that attribute the node’s transport to crier_client.

B25 — BLOCKING — OMISSION
  Chapter: M10.
  Claim: The bus chapter lists custody/transport and the guard, but leaves their actual behavior unread.
  Evidence: M10:12,32–33 explicitly acknowledges this. Concrete controls absent from its two-row settings register include RequireAgentSig, body/rate limits, webhook retry/circuit settings, and guard timeout/concurrency/payload limits at config/config.go:627–654. Delivery idempotency has distinct replay and busy branches at internal/registry/handler.go:1307–1365.
  Fix: Write the reachable custody, idempotency, lease/ack, expiry, guard, backend, and degradation behavior at submodule granularity. Supply their controls and recovery paths. This does not require one chapter per Go package; it requires documenting what the run reaches.

B26 — BLOCKING — FALSE CLAIM
  Chapter: M11.
  Claim: M11-C2 is “broken — CF-355 (scheduler reads ok, node-side sends status)” (M11:71).
  Evidence: This row’s stated producer is the dispatcher. dispatcher.py:500–507 sends a boolean ok and optional error_b64. dispatchReplyVerdict at scheduler/dispatch_leg.go:713–725 consumes those fields. The status/ok incompatibility belongs to the separate node worker.
  Fix: Grade dispatcher→scheduler and node-worker→scheduler as different contracts. Do not propagate a defect from one producer onto another producer that uses the expected dialect. Mark live end-to-end operation unverified if it has not been exercised.

B27 — BLOCKING — FALSE CLAIM
  Chapter: M11.
  Claim: The durable-execution contract is “redelivery replays, not re-runs” (M11:18–19).
  Evidence: dispatcher.py:479 runs the job before ledger_put at :481. A crash after work starts or completes but before ledger persistence leaves no replay record. ledger_put at :390–397 logs and swallows write failures; only the in-memory ledger is subsequently updated. This cannot establish unconditional crash-safe once-only execution.
  Fix: State the precise guarantee and crash windows. Document behavior after restart, failed ledger writes, and orphaned jobs. Retain any stronger guarantee as UNVERIFIED until a durable job identity/recovery protocol and failure-injection evidence establish it.

B28 — BLOCKING — FALSE CLAIM
  Chapter: M11.
  Claim: DISPATCH_MARGIN_S reserves time before the caller’s deadline so completion returns while the caller still listens.
  Evidence: dispatcher.py:195–197 returns max(30, min(CAP_S, wall_s - MARGIN_S)); it does not refuse a caller budget too small for that floor.
  Measured: The actual function returned a 30-second task budget for wall_s=10 and wall_s=60, and 540 for wall_s=600.
  Fix: Document the minimum budget, the small-deadline overrun, and the distinction between intended reserve and guaranteed reserve. Include admission/refusal behavior for insufficient budgets rather than promising a universal margin.

B29 — BLOCKING — FALSE CLAIM
  Chapter: M12.
  Claim: “content sha256 b12a0ac521c4b5a9cd7e2b76883a7edf2c9e0efd” (M12:9).
  Evidence: sha256sum returned:
    b12a0ac521c4b5a9cd7e2b76883a7edf2c9e0efd87d9bc3be3d2056d3f39e0b5
  Fix: Record the complete digest and the exact hashing command. If an abbreviated identifier is displayed elsewhere, label it explicitly as an abbreviation.

B30 — BLOCKING — FALSE CLAIM
  Chapter: M12.
  Claim: “partial upstream failure returns 502 … never a half-formed payload” (M12:117–118).
  Evidence: cf-inference-proxy.py:204–218 sends upstream status/headers and flushes chunks immediately. At :231–238 an exception after the first chunk merely returns because headers were already sent.
  Measured: An offline failure-injection probe of the real _forward method sent HTTP status 200 and 29 response bytes, then recorded an upstream OSError. It did not send 502.
  Fix: Separate buffered-response guarantees from streaming semantics. Document partial-stream termination, attribution, client detection/retry implications, and missing HTTP framing/completion guarantees. The stale source comment at :25–27 is not authoritative over the implementation.

B31 — BLOCKING — OMISSION
  Chapter: M12.
  Claim: The upstream credential dependency is API_SERVER_KEY, but its selector is absent from the settings register.
  Evidence: cf-inference-proxy.py:47 reads CF_PROXY_UPSTREAM_KEY_ENV, defaulting to API_SERVER_KEY; upstream_key at :75–80 reads the selected name. The startup error at :269 still hardcodes API_SERVER_KEY even when another name is configured.
  Fix: Document the selector, default, accepted value, evaluation timing, and failure consequence. Explain the misleading hardcoded diagnostic and the need to coordinate endpoint, model rewrite, and credential selection.

B32 — BLOCKING — OMISSION
  Chapters: M0–M12, especially M4, M10, M11.
  Claim: The “Log lines (verbatim)” sections satisfy the log field.
  Evidence: MASTER-DOC-SCHEMA.md:81–91 requires every operator-visible line, its condition, level, and descriptive/evidentiary classification. M4:85 supplies a description with ellipses, not a verbatim format. M10:90 explicitly captures none. M11 omits important actual lines, including ledger write failure at dispatcher.py:397, retrieval failure at :437, malformed-task refusals at :446,463, delivery failure at :510, and acknowledgement failure at :526.
  Fix: Derive a source-backed log inventory, distinguishing dynamic format strings from example observations. Include the failure lines operators must use and avoid promoting a self-report into evidence of a stronger external effect.

B33 — BLOCKING — UNBUILDABLE
  Chapters: M1–M12, failure/recovery sections.
  Claim: Tables headed “Failure modes, indications and recovery” contain entries such as “OPEN — CF-354,” “OPEN — CF-355,” “check bunker,” or “re-run.”
  Evidence: M2:104–108 is almost entirely board references; M11:103–107 gives no executable diagnostic ladder; M9:100–103 supplies defect labels without an operational recovery sequence. OUTLINE:125–127 requires an action and expected indication after each step.
  Fix: Separate engineering remediation from operator recovery. For each failure, provide safe diagnostic commands, discriminating observations, containment, recovery action or explicit “no safe recovery,” and the expected recheck result. A ticket number is not a procedure.

B34 — BLOCKING — OMISSION
  Chapter: M11.
  Claim: “one loop for every agent on every box” is presented without its capacity and head-of-line consequence.
  Evidence: dispatcher.py:428–442 iterates agents serially and :479 synchronously waits for dispatch to finish before servicing another agent. dispatch_durable can poll until its task deadline at :298–331. No per-agent concurrent worker is created.
  Fix: State that one long job blocks polling/execution for later agents in this process. Document the resulting queue delay, lease/expiry interactions, throughput bound, and measured or explicitly unmeasured worst case. Do not imply independent multi-node progress merely because the registry contains multiple agents.

DEFECT CLASSES:
  missing endpoint implementations;
  unproven activation;
  mandatory RED fields;
  completeness/status inflation;
  credential predicate mismatch;
  duplicated enforcement;
  incorrect defaults and boundaries;
  hidden startup dependencies;
  lane/store ownership confusion;
  optional gates presented without consequences;
  census mistaken for validation;
  unwired runtime authority;
  unsupported adapter capability;
  structural checks mistaken for truth checks;
  stale pipeline selection;
  incomplete lifecycle controls;
  incomplete scan/deletion boundaries;
  missing admission and durable-state contracts;
  incorrect observability defaults;
  contradictory client ownership;
  producer-specific defect misattribution;
  crash-window guarantee inflation;
  deadline overrun;
  invalid revision identity;
  incorrect streaming guarantee;
  incomplete log inventory;
  non-executable recovery;
  serial head-of-line blocking

CHAPTER SCORECARD:

  M0 — PARTIAL
    Useful shell-source evidence and a reproduced source census, but credential enforcement is overstated, centralized variable enforcement is false, contracts are incomplete, and metrics remain RED.

  M1 — PARTIAL
    Correctly identifies the credential-mode self-report defect, but gives the wrong unknown-role behavior and does not document operational certification or most provisioning controls.

  M2 — PARTIAL
    The text/text_b64 and status/ok mismatches are supported by code. Wall-budget semantics, configuration startup dependencies, activation evidence, and recovery remain incomplete.

  M3 — PARTIAL
    Landing source evidence is substantial, but lane-row cloning is misrepresented as checkout creation and the optional project-gate default is not exposed.

  M4 — PARTIAL
    Store counts and byte parity reproduced. The completion evidence requirement also reproduced in isolation. Those checks do not satisfy the claimed integrity coverage, endpoint contracts, or the remaining field contract.

  M5 — PARTIAL
    Resolver unit behavior reproduced, but runtime integration is not established, independent validators disagree, and the claim that every adapter installs/certifies at a pin is false.

  M6 — PARTIAL
    The reported 50-error gate result reproduced. The chapter nevertheless overstates semantic verification and leaves panel selection, scratch dependencies, and most pipeline behavior unwritten.

  M7 — PARTIAL
    Bare-command behavior is correct and reproduced. Credential lifecycle, settings, prerequisites, refresh branches, complete verification commands, and recovery are largely unwritten.

  M8 — PARTIAL
    Reclaimer unit behavior reproduced. Scanner semantics and actual deletion boundaries are missing, including the fact that dispatcher .cf-jobs is outside the reaper’s targets.

  M9 — PARTIAL
    Settlement-path analysis is useful, but admission, effective settings, durable execution stores, and operator recovery remain substantially unwritten.

  M10 — PARTIAL
    Signature-order analysis is useful. Metrics default and client ownership are wrong; custody, guard behavior, settings, log inventory, and recovery remain incomplete.

  M11 — PARTIAL
    Source-level job and reply details are useful, but contract grading is misattributed, crash-safe replay is overstated, short-deadline behavior is wrong, serial blocking is omitted, and live failure oracles remain unverified.

  M12 — PARTIAL
    Control-host placement and basic admission are supported; an offline handler probe confirmed disallowed-model refusal. Revision identity and partial-stream guarantees are wrong, and credential-selector, endpoint, metrics, and recovery fields remain incomplete.

No chapter qualifies as WRITTEN under the supplied field contract. Passing unit tests, truthful RED labels, and source-reading statements are useful evidence, but none substitutes for the missing operational contracts and procedures.

PANEL REVIEW COMPLETE

session_id: local-943a4addbe74a8014e75f6aea3a1a275032c52dc40aa4091fa6c59a2640b24f7

EXIT=0
```

