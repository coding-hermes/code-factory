# CORRECTIONS — round 5

Generated 2026-11-06T17:48:37-0500.

## Verdicts

- **deepseek** — FAIL, blocking 5, 7209 bytes, complete=True
- **glm** — FAIL, blocking 5, 9124 bytes, complete=True
- **grok** — FAIL, blocking 3, 11751 bytes, complete=True
- **kimi** — FAIL, blocking 3, 11237 bytes, complete=True
- **sol** — FAIL, blocking 25, 37035 bytes, complete=True

## Verdict text (verbatim, per seat)

### deepseek

```
All load-bearing claims verified against the code. Here is my full verdict.

VERDICT: FAIL

BLOCKING: 5 — findings that must be fixed before the affected chapters can be called written

NON-BLOCKING: 7

FINDINGS:

BLOCKING

1. [OMISSION] M9 §9 (Log lines). The chapter documents 2 of 379 operator-visible log sites and self-declares "This is a sample, not an inventory." Evidence: `grep -rn "log.Printf" internal/scheduler/*.go | wc -l` = 379 (reproduced). The schema requires "every operator-visible line, verbatim." Fix: complete the verbatim inventory, or explicitly narrow M9 §9 to the settlement/batch-dispatch surface and record the uncovered count as a named RED, not a sample.

2. [OMISSION] M9 §5 (Settings register). The register lists ~14 settings; `cmd/schedulerd/main.go` carries 57 flag definitions (reproduced via `grep -c 'flag\.(...' main.go` = 57). Unregistered live flags: `tls-cert`, `tls-key`, `public-url`, `peer-freshness-window`, `spawn-mem-limit-mb`, `board-stasis-gate` (all present at main.go:100-150). Fix: register every flag with default/range/consequence, or declare the unregistered surface explicitly out of scope with a quoted grep proving the boundary.

3. [UNVERIFIED] M10 §1/§9. The 1895-line handler.go body was not read line-by-line and the §9 log inventory is self-declared non-exhaustive. Evidence: `wc -l internal/registry/handler.go` = 1895 (reproduced). Fix: read the handler body and complete the slog inventory, or downgrade the §9 claim to an explicit sample with a measured uncovered-count.

4. [UNVERIFIED/OMISSION] M1 §3/§5. Six S1-S4 unit bodies are unread — node_identity.py, node_seed.py, node_seed_drift.py, node_env.py, node_freshness.py, bunker_config_gen.py — so their settings and behaviour are undocumented; only the orchestrator invoking lines are cited. Fix: read the six bodies and register their settings/consequences.

5. [UNVERIFIED/OMISSION] M5 §3/§5. Four foreign-installer bodies are unread (install-claude-code.sh, install-deepseek.sh, install-pi-agent.sh, install-opencode.sh; install-codex.sh partial). Fix: read the bodies and register their settings and capability uniformly (the §11 matrix currently rests on line-range reads).

NON-BLOCKING

- [class] Metrics "none" on 11 chapters (M0, M1, M2, M3, M4, M5, M6, M7, M8, M11, M12) — each absence-proved by a quoted repo grep. Correctly documented; this is a system observability defect, not a document defect. It blocks the system, not the document.
- M6 §7 — the documentation module's own gate reads MASTER-DOC: FAIL (44 modules, 37 VERIFIED, 50 errors). Correctly documented live state; the FAIL is a stale-locator condition, reported not hidden.
- M12-C1 — node-client half UNVERIFIED; no in-repo file:function exists (config-wired via node.env.example:22,26). Genuinely unnameable, correctly marked.
- M12 F12-7 — healthy SSE stream unframed to completion; UNVERIFIED until an HTTP-completion test passes. System defect, correctly documented.
- M4-C1/M4-C2 — UNVERIFIED; every side is an external peer (foreman, gitreins binary, boardctl binary, JSONL store). Correctly re-derived from round-3's "works"/"broken".
- M7-C1 — UNVERIFIED; consumer is the external github.com API. Correctly marked.
- M2 §7 / M11 §7 — live-node ladders not repeatable from this control host; M11's live-job test scripts print without asserting (decoration, correctly flagged).

DEFECT CLASSES

incomplete-log-inventory · incomplete-settings-register · unread-unit-body · metrics-absent (system) · one-sided-or-external-contract (UNVERIFIED) · decoration-test (no failing oracle) · live-state-gated-verification (unrepeatable)

CHAPTER SCORECARD

- M0 shared-contract — PARTIAL — Metrics RED only; all cited lines re-verified; nearest to written.
- M1 provisioning — PARTIAL — S1-S4 bodies unread (UNVERIFIED); Metrics RED.
- M2 dispatch — PARTIAL — Metrics RED; live ladder unrepeatable; contract states both-sided and correct.
- M3 repository — PARTIAL — Metrics RED; S2 correctly reclassified operator-invoked (F3-5).
- M4 board — PARTIAL — Metrics RED; M4-C1/C2 UNVERIFIED (external peers).
- M5 harness — PARTIAL — foreign installer bodies unread; Metrics RED.
- M6 documentation — PARTIAL — own gate reads FAIL; Metrics RED.
- M7 github — PARTIAL — mint UNVERIFIED; M7-C1 UNVERIFIED; Metrics RED.
- M8 safety — PARTIAL — Metrics RED only; nearest to written.
- M9 scheduler — PARTIAL — §9 log inventory 2/379; §5 settings incomplete; S1 grep-level.
- M10 crier — PARTIAL — handler body unread; §9 non-exhaustive.
- M11 dispatcher — PARTIAL — Metrics RED; live-job tests decoration.
- M12 inference-proxy — PARTIAL — node-client half UNVERIFIED; stream completion UNVERIFIED; Metrics RED.

0 WRITTEN, 13 PARTIAL, 0 SKELETON.

WHAT I VERIFIED AS TRUE (so the next round keeps it)

- F9-3 correction is TRUE: `LoadRootConfig` is called at exactly main.go:640, 673, 762, 854, 870, 968, 995, 1023, 1054, 1309; loader.go implements the three-layer merge (LoadConfig:110, applyEnvOverrides:206, LoadRootConfig:630). Round-4's "root sections not loaded" was FALSE.
- F9-6 correction is TRUE: the ambient `SCHEDULER_OPERATOR_RESTART_APPROVED=1` is present in this shell; `env -u SCHEDULER_OPERATOR_RESTART_APPROVED go test ./internal/scheduler/ -run '...OperatorRestart...|...SCHEDGAP091...|...AbortInFlightTicks...' -count=1` = ok (0.288s). The var is load-bearing (restart_approval.go:57 EnvOperatorRestartApproved).
- F9-4 locator re-pin TRUE: metricsSpawns func at server_metrics.go:195 (doc comment :192).
- F9-2 TRUE: scheduler.db = 30 tables, no verdicts table.
- F9-5 TRUE: binary defaults 30s/24h/10/100/10/false/7200s at main.go:108-114; load-gate-threshold 0 at :144.
- boardOwnedByLane def :177, called :234 (admission_mode.go) — round-4's ":208+" was tasksAdmissionDue, not the function.
- S1 locators exact: tick_process.go:40 evaluate, packer_select.go:19 Pack, namespace_alloc.go:131 Allocate, usage_pool_policy.go:21 reserveUsagePools (all receiver methods).
- CF-354 both sides TRUE: dispatch.go emits text_b64; node-bus-worker.py:986 reads dispatch.get("text"); no text_b64 in the worker.
- CF-355 both sides TRUE: node sends "status" (:1132); scheduler reads payload["ok"] (:714).
- F2-4 correction TRUE: configure_family.py:17 imports, :149 calls lane_target.parse.
- F3-5 TRUE: land-node-branch matched only by selftest.sh arms (syntax+usage), no in-repo invoker.
- M12 ERE grep TRUE: 4 text sites (panel_loop.py:136, master_doc_skeleton.py:25/:211, node.env.example:22 — a live assignment, not a comment).
- M4 census TRUE: 357 tasks / 515 events. M11 log sites TRUE: 23 calls (25 grep lines incl. def+comment). M10 metrics grep TRUE: crier_[a-z_]+ = 67 unique; registry = 91 test files.

The document is honest and the two operator-facing FALSE CLAIMs are genuinely fixed. It is not yet WRITTEN: the closable completeness gaps (two control-plane modules with incomplete log/settings registers, two node-side modules with unread unit bodies) are what hold it at 0/13.

PANEL REVIEW COMPLETE

session_id: local-47ea127066ff9bbe19c9973da79b654c1cc5b7ba5967aec81739fc0351eb9b4a

EXIT=0
```

### glm

```
VERDICT: FAIL

BLOCKING: 5 — findings that must be fixed before this chapter can be called written
NON-BLOCKING: 3

Judged document-against-code at the stamped revisions (code-factory 943ef98, scheduler 1771d3aa, crier 691f0c78, crier-fleet 283bca9; proxy sha256 b12a0ac5… reproduced). Every round-5 correction I tested re-derives true from the code — F9-3 (LoadRootConfig called at exactly main.go:640,673,762,854,870,968,995,1023,1054,1309; the stale NOTE is in config.example.toml:12-16, not the daemon), F9-6 (clean-env `go test ./...` rc 0, 25/25 packages — reproduced; my own shell carries SCHEDULER_OPERATOR_RESTART_APPROVED=1, confirming the contamination mechanism), F2-4 (lane_target called at configure_family.py:17,149), F3-5 (land-node-branch has no in-repo invoker; selftest.sh:2465/2473/2502 exact), F11-6 (ledger check :470-475, put :481-483 covers both modes), F10-3 (metrics.go:2), F12-7 (protocol_version="HTTP/1.1" at :105 with no Content-Length/Transfer-Encoding/Connection on the stream path — the unframed-SSE defect is real), F0-6 (`[0-7]00` predicate at :203 vs "must be 600" message at :204), M6 B14 (ThreadPoolExecutor at :450), M12-C1 (node.env.example:22 is the live assignment). The failures below are what remains.

FINDINGS:

1. FALSE CLAIM — M12 (§5 settings register)
   Claim quoted: "`USAGE_LOG` | `~/.hermes/logs/cf-usage.jsonl` (`:49`)" and "`CAPTURE_LOG` | `~/.hermes/logs/cf-capture.jsonl` (`:50`)"
   Evidence: `sed -n '50p;52p' /home/kara/.hermes/scripts/cf-inference-proxy.py` → :50 `USAGE_LOG = …"cf-inference-usage.jsonl"`, :52 `CAPTURE_LOG = …"cf-inference-requests.jsonl"`. Both filenames in the chapter are invented; both line cites land on the wrong statements (:49 is ENV_PATH).
   Fix: replace with the measured names and lines; an operator hunting the capture log at the documented path finds nothing — in a chapter whose §2 stakes is "what breaks if it lies".

2. CONTRADICTION — M10 (§6 M10-C1) vs OUTLINE Part IV and README I.3/I.5
   Claim quoted: M10-C1 "**works (transport)** — … the mismatch is a node-consumption defect … Round-4's 'broken (CF-354)' mis-scoped the break"; OUTLINE Part IV still reads "scheduler → crier — envelope … **broken**" and "crier → node — … **works**"; README still carries "10 works / 6 broken / 2 missing".
   Evidence: OUTLINE.md lines 207-209 vs chapters/M10-crier.md:82; the measured break (node reads `text` at node-bus-worker.py:986) sits on the crier→node leg, the inverse of the register.
   Fix: write the re-scope back into the Part IV register rows (and README I.3/I.5 counts) or footnote each row with the chapter that supersedes it. A register of record that contradicts the chapters it registers is worse than a rumour — it is a measured fact undone by a stale table.

3. UNVERIFIED — M4 (§7 verification table)
   Claim quoted: "drift … **PASS** (RESULT: OK; HEAD==origin/main `943ef98`), 2026-11-06"
   Evidence: re-run this round: `RESULT: DRIFT (4 failed)` — tasks/events byte parity FAIL, CF-051 pending(local) vs complete(published); origin/main has advanced 3 commits past the stamped HEAD (b82a5df…). MASTER-DOC-SCHEMA §4: "A check that passed three revisions ago is UNVERIFIED" — here, literally three.
   Fix: re-run board_drift after resync, re-stamp; or record the drift as the current honest row. Not the writer's fabrication — the repo moved mid-panel — but the printed PASS no longer repeats.

4. UNVERIFIED — M9 (§5 settings register, six rows)
   Claim quoted: rows `api-read-timeout` 5 s, `gateway-response-timeout` 30 m, `gateway-transient-retries` 3, `slot-patience` 5 m, `tasks-pacing` 60 s, `feature-prune-weeks` 8 — all carry default/governs/consequence but no `file:line`.
   Evidence: rule 1 — a claim without a locator blocks. I measured them true (main.go:122, :128, :138, :142, :143, :145), so the fix is mechanical, but the chapter as written asks the reader to trust unlocated numbers — the exact defect F9-5 was filed against round-3 for.
   Fix: add the six locators (now measured) or drop the rows to the RED note.

5. OMISSION — README Part II flow ledger (document-level)
   Claim quoted: the flow table tracks II.1–II.10 only; `grep -n 'F1[1-6]\|SCHEDULING ADMISSION\|CREDENTIAL LIFECYCLE\|MULTI-NODE' docs/handbook/README.md` → 0 rows.
   Evidence: OUTLINE Part II commits to 16 flows; the six quorum-added flows (F11 admission, F12 credentials, F13 upgrade, F14 observability ingestion, F15 backup/restore, F16 fan-out) — the panel's largest structural addition — have no status row at all, not even MISSING. A ledger that silently drops a third of the committed scope repeats the v1 sin (coverage claimed but not tracked).
   Fix: add II.11–II.16 rows marked MISSING with an owner module pointer (M9, M1/M7/M12, M9/M6, M14-none, ops, M11).

6. CONTRADICTION (non-blocking) — M11 (§5 vs §13 F11-7)
   Claim quoted: §5 "`int(TASK_S)` at `:196`"; F11-7 "(`task_seconds` `:193`)".
   Evidence: actual `return int(TASK_S)` at dispatcher.py:195 (def :185, guard :194). The claim (string until int() at use, ValueError at use) is true; the chapter cites two different wrong lines for it.
   Fix: pin :195 in both places.

7. OMISSION (non-blocking) — M10 (§8 metrics inventory)
   Claim quoted: "Inventory (B56, completed this round — `grep -rhoE 'crier_[a-z_]+' internal/ cmd/ --include='*.go' | sort -u`)"
   Evidence: the same command returns 67 unique strings this round; the chapter enumerates ~40 base series and neither distinguishes histogram `_bucket/_sum/_count` components nor excludes the test-only `crier_test_*` family (the writer's own manifest said 60). "Completed" overstates a partial enumeration.
   Fix: state the count the command returns and the scope (runtime series vs test helpers vs exposition components).

8. UNVERIFIED — declared, confirmed (non-blocking) — M2/M10 §7 and M1 §7
   Claim quoted: signed-read ladder / certification ladder / bus-worker ladder "not repeatable from this control host".
   Evidence: I cannot repeat them either (no `~/node-bus-worker.py`, no live node from this host); correctly carried as RED/UNVERIFIED rather than asserted. No fix demanded beyond keeping them RED until a node-side run re-dates them.

DEFECT CLASSES: register-not-reconciled (measured state not written back to the register of record) · settings-drift (defaults/names not re-derived from code) · verification-currency (PASS rows gone stale after origin advanced) · locator-drift (±1 line, self-inconsistent within a chapter) · true-claim-no-evidence · honest-RED accounting (working as intended).

CHAPTER SCORECARD:
- M0 — PARTIAL. Every locator verified (11/17 source counts reproduce; lib.sh :5-11,22,26,54,67-78 exact); metrics RED is a system defect, not a writing defect.
- M1 — PARTIAL. F1-1 verified in both directions (:214 probes `-s`, :233 claims mode 600); five re-applied CLI flags at :604-608 exact; S1–S4 bodies honestly declared unread.
- M2 — PARTIAL. All cited lines verified including the same-batch duplicate structure (:1304-1331 vs :1341-1347); ladder correctly RED as unrepeatable.
- M3 — PARTIAL. F3-3/F3-5 verified (GATE="" :36, gate :171-193, no in-repo invoker); repo_freshness rows cite the add_argument statement line — acceptable, flag literals sit at :559+.
- M4 — PARTIAL. Census 357/515 and `validate` OK(7 warnings) reproduce; the drift row itself is now stale (finding 3).
- M5 — PARTIAL. Mode predicate and per-installer sourcing/refusals all verified; foreign bodies declared unread.
- M6 — PARTIAL. Gate FAIL reproduced exactly (44 modules / 37 VERIFIED / 50 errors); fill/render locators verified; own-gate-FAIL honestly RED.
- M7 — PARTIAL. Every locator verified (mint :362/:371, --dry-run exits at :106/:154, say_q :55); mint correctly UNVERIFIED without creds.
- M8 — PARTIAL. Scan-scope 15-claim PASS reproduced; reclaim locators verified; both files read in full.
- M9 — PARTIAL. The two inverted operator-facing facts (F9-3, F9-6) now verified true against code and reproduced by me; blocked on finding 4 plus its own declared REDs (§9 2/379, S1 grep-level).
- M10 — PARTIAL. Locators and test/build reproduction solid; blocked on finding 2 (register) and finding 7 (inventory overstatement).
- M11 — PARTIAL. Near-complete: 23 log sites, ledger semantics, always-`ok` reply all verified; blocked on decoration tests (cannot fail) and finding 6.
- M12 — PARTIAL. F12-7 proven real (HTTP/1.1 at :105 + unframed stream); blocked on finding 1 — the one outright false claim that survived this round.

No chapter reaches WRITTEN: each carries at least one RED field, and the four with new blocking findings (M4, M9, M10, M12) cannot be called written even under the round's own lenient standard. The corrections themselves are sound — every one I re-derived from code came back true — which is why the verdict is FAIL on completeness and currency, not on honesty.

PANEL REVIEW COMPLETE

session_id: local-a2621b0defbd77e4cbb2261da5b7d341dedc93bafbf1b8e4c37ab338e3279d70

EXIT=0
```

### grok

```
⚠️  Primary auth failed — switching to fallback: fireworks / accounts/fireworks/models/deepseek-v4p1-flash-1017
VERDICT: FAIL
BLOCKING: 3 — findings that must be fixed before this chapter can be called written
NON-BLOCKING: 9

Method note (repeatability, brief rule 4): I re-ran every command I could from this host. Not repeatable here, and therefore graded on the chapter's own admission: M1's `verify-node.sh` ladder (needs a live node), M5's conformance battery, M7's token mint (no App creds), M2/M10's `~/node-bus-worker.py --check` (no such file on this host). I did NOT run full `go test ./...` on scheduler or crier (time/revision cost); I ran the three named env-sensitive scheduler tests instead, which is the load-bearing part of F9-6. Chapters that declare these gaps themselves are graded accordingly, not penalised twice.

FINDINGS

B1. FALSE CLAIM — M12 (settings register, §5). Claim: "`USAGE_LOG` | `~/.hermes/logs/cf-usage.jsonl` (`:49`)"; "`CAPTURE_LOG` | `~/.hermes/logs/cf-capture.jsonl` (`:50`)". Evidence: the file the chapter stamps (sha256 `b12a0ac5…e0b5` — reproduced byte-identical) sets `USAGE_LOG = /home/kara/.hermes/logs/cf-inference-usage.jsonl` (:49) and `CAPTURE_LOG = /home/kara/.hermes/logs/cf-inference-requests.jsonl` (:50). Both defaults are wrong by a distinctive infix. Fix: correct both values; a paths register whose paths do not exist on disk is the one row an operator will act on first, and it sends them to a file that is never written.

B2. OMISSION (classification) — M12 §3 S1. Claim: "no systemd unit or invoking script exists in-repo (kimi B71); it is started by an operator/systemd drop-in, which is unmeasured" → classified **operator-invoked**. Evidence, measured: `~/.config/systemd/user/cf-inference-proxy.service` — loaded, enabled, `active (running)` since 2026-11-05 09:21, 1d08h, Main PID 2603939, drop-in `cf-inference-proxy.service.d/10-upstream.conf`; live checks reproduce the chapter's: `POST /v1/chat/completions` → **401**, `GET /health` → **200**, listener `0.0.0.0:8775`. The OUTLINE classification rule decides this: "active if a scheduler lane, cron, timer or another unit invokes it." A systemd unit invokes it, continuously, on this host, and one `systemctl --user status` finds it. Fix: classify S1 **active**, cite the unit file + drop-in as the invoking artifact, and drop the "unmeasured" hedge — the invoker was measurable and unmeasured.

B3. UNVERIFIED / non-reproducible evidence — M4 §7 + §1. Claim: "drift | `python3 scripts/board_drift.py check --workdir /home/kara/code-factory --ref origin/main` | byte parity, RESULT OK | 2026-11-06 | **PASS** (RESULT: OK; HEAD==origin/main `943ef98`)". Measured now, same command: `FAIL board rows — 357 vs 357 rows; 1 divergent ids: CF-051` → **`RESULT: DRIFT (4 failed)`**, and `HEAD=943ef98` vs `origin/main=b82a5df`. Cause is concurrent fleet work, not invention (origin/main gained CF-051's closeout in `b82a5df`/`0c1f20e`/`388c7cb` after the chapter was stamped; the working tree still has CF-051 `status:"pending"`). But the chapter prints this as a reproducible PASS and the §1 Status row leans on it. Fix: re-stamp the drift row with the measurement and its date, state that board parity is a moving target (a check against `origin/main` cannot be quoted as a standing PASS), and re-run `board_drift` after the merge that carries the chapter. Everything else in M4 reproduced exactly: 357 rows, 515 events, `boardctl validate` → `357 tasks, 515 events, 0 fixtures`, `key uniformity 357/357`, `RESULT: OK (7 warning(s))`, and the duplicate-id refusal.

NON-BLOCKING

N1. Locator precision — M1 §10. "`refusing to destroy without --yes`, exit 2 (`:550`)" — the message is at `bunker-provision.sh:552`; :550 is `destroy() {`. Fix: :552.

N2. Locator precision — M1 §10/§13. "unknown explicit role raises `FloorError` (`disk_floor.py:122-125`)" — the raise is `:123-125` (:122 is `if role not in ROLE_DEFAULTS:`). Fix: :121-125.

N3. Locator points at prose, not the emitter — M5 §9. `FAIL harness_foreman_requires_hermes: lane=<L> harness=<H>` cited at `harness_resolve.py:53`; line 52-53 is the module docstring's refusal list. The string is emitted at `:284` (`f"harness_foreman_requires_hermes: lane={lane or '-'} harness={harness}"`), surfaced by `print(f"FAIL {exc}")` at :389. Fix: cite :284 (and :389 for the FAIL prefix).

N4. Internal CONTRADICTION — M10 §5 vs §13 F10-3. §5: "`internal/metrics/metrics.go:2` still calls the surface 'the opt-in GET /metrics surface' — the comment (line 2, not 5)". F10-3: "`metrics.go:5` still says 'opt-in'". Code: line 2 (`// behind the opt-in GET /metrics surface (DF-CRIER-142)`). §5 is right, F10-3 repeats the very error §5 corrects. Fix: F10-3 → `:2`.

N5. Internal CONTRADICTION — M9 §6 M9-C1 vs §5 F9-3. M9-C1 does not know what its own §5 settles: producer cell says "FEAT-005 `LoadConfig`, partially wired", while F9-3 proves `LoadRootConfig` is called ten times at boot (`main.go:640, 673, 762, 854, 870, 968, 995, 1023, 1054, 1309` — all ten lines verified) and calls the "not loaded" story FALSE. Fix: M9-C1 must say what §5 says — root config is loaded through `config.LoadRootConfig`; only the example file's NOTE is stale.

N6. Unqualified cross-repo locator — M2 §6 M2-C1 and M10 §6 M10-C1. Both cite `internal/bus/dispatch.go:202` for the scheduler's payload while the chapter's Path is `code-factory/scripts` (M2) and `/home/kara/crier` (M10). A reader in the described repo cannot resolve it; crier has no `internal/bus/`. Fix: name the repo in the cell (`<scheduler>/internal/bus/dispatch.go:202`), as M9 does.

N7. Locator drift (three instances, one class) — M6 §10 cites `panel_loop.py:33-34` for FANOUT/MANIFEST (actual :34-35); M7 §5 cites `say_q` at `github-app-refresh.sh:55` (actual :56); M8 §9 cites the per-target row print at `:160` (actual :161). Individually trivial; together they are the difference between a locator a stranger can follow and one that lands one line off. Fix: re-pin all three.

N8. Classification without an invoking line — M12 §3 S2/S3/S4. S1's evidence cell is a grep; S2, S3 and S4 are classified **active** with evidence "read". The OUTLINE's rule is explicit: evidence must be the invoking line, or absence proven by a quoted repo-wide grep. Reading a function proves it exists, not that anything calls it. Fix: give each an invoking line, or prove the absence the same way S1 did.

N9. Evidence not shipped — M4 §9. Every log line is prefixed "they carry no file:line in this repo; they are quoted from the captured run output this round", but no capture path, no timestamp and no command is given, so the "verbatim" claim cannot be re-derived by a stranger (schema §6 wants the level, the line and the trigger). Contrast M1/M9/M11, which cite emitter lines. Fix: cite the `boardctl` source location if it is on disk, or ship the captured run under `docs/handbook/_panel/`.

DEFECT CLASSES
1. Setting value wrong while the consequence is right (register passes the shape test, fails the value test) — B1.
2. Classification asserted from code presence, not from a measured invoker, when the invoker is one command away — B2, N8.
3. A reproducible PASS quoted as standing truth against a moving external (`origin/main`) — B3.
4. Internal self-contradiction: one section corrects a fact another section still asserts — N4, N5.
5. Locator off-by-one / pointing at a docstring instead of the emitter — N1, N2, N3, N7.
6. Cross-repo locator without a repo name — N6.
7. "Verbatim" claims backed by an unshipped capture — N9.
(Named-and-honest, and therefore not counted as defects: 12 chapters declare their own RED fields, M3 refuses its dry-run row rather than claiming a PASS, M4/M7/M12 mark external-only contracts UNVERIFIED instead of "works", and M11's F11-6 refutes the round-4 claim that the synchronous path has no ledger — verified at `:470-483`.)

CHAPTER SCORECARD
M0 — WRITTEN. 78 lines, every cited line exact (`:5-9`, `:19-42`, `:48-57`, `:75-78`); 11 direct / 17 total sourcing reproduced; metrics-absence grep 0. One-row contract table, but the one-sided flag is justified for an external peer.
M1 — PARTIAL. Orchestrator mechanics verified exactly (`:181`, `:214` probes `[ -s … ]` while `:233` claims "mode 600", `:550-558`, `:589`, `:604-608`), `project-node.sh:173` caller confirmed, `ROLE_DEFAULTS`/`DEFAULT_ROLE`/bounds confirmed. Held back by its own Status: six of thirteen unit bodies unread; two locators off.
M2 — WRITTEN. Constants and shapes landed exactly (`:80/:81/:84/:112/:113`, `:986`, `:1128-1144`, `:1152-1157`, `:1300-1367`, `:603`, `:37`); the same-batch duplicate finding (§11) is real — `process()` loops the batch holding one `seen` dict while the cache is written in the later delivery loop. Only N6 dents it.
M3 — WRITTEN. `land-node-branch.sh` citations exact (`:36`, `:56`, `:76`, `:167`, `:171-193`, `:214`, `:231`, `:265`, `:276-283`, `:291`); F3-2 (clone_lane clones a DB row, `:74-118`) and F3-3 (`--gate-cmd` empty ⇒ no gate) both correct; the hook-effectiveness caveat is the most valuable paragraph in the set.
M4 — PARTIAL. Censuses and validation reproduced exactly, `boardctl --help:25` verified; but the drift PASS is false at review time (B3).
M5 — PARTIAL. The variable contract is documented to the line (CFV sets `:28-33`, `:66`, `[0-7]00` at `:203` against a "must be 600" message at `:204`, ambient non-emptiness `:176-185`, `--contract` `:313`), and F5-2's "no production caller" grep reproduces; held back by unread installer bodies and N3.
M6 — WRITTEN. At a FAIL: gate reproduced to the digit (`44 module(s): 37 VERIFIED, 50 error(s)`, exit 1, `MASTER-DOC: FAIL`), `verify-patch.sh` PASS with the same `f393a681…` digest, `gen_nasa_handbook.py` `:17`/`:18`/`:253-258` exactly right, stale panel selection confirmed.
M7 — PARTIAL. Controls verified (`:45/:47/:50-52`, `:348-352`, `:371`, `:579`, `:719-723`, dry-run `:106`); the mint itself unrun, so the credential path is documented but unexercised.
M8 — WRITTEN. 169+118 lines, cited exactly (`:14-22`, `:21`, `:42-47`, `:110/:112`); 9 tests, 15 scoped claims reproduced.
M9 — PARTIAL. Every locator I checked landed on the byte: `main.go:108-114`/`:144`, ten `LoadRootConfig` sites, 379 `log.Printf` sites, `metricsSpawns` at `:195` (F9-4's own correction), `.tables` → 30 with no `verdicts`. F9-6 now reproduced: the three tests PASS unset (0.32 s) and FAIL set (`orphan_reason = "operator_restart", want "drain_timeout"`). Not WRITTEN because it declares §9 (2 of 379) and §5 (unregistered flag surface) RED, plus N5.
M10 — PARTIAL. Handler/guard/config locators exact (`:598/:990/:1690/:1812`, 1895 lines, 91 test files, `:622/:627/:628/:629/:673`, `guard.go:167`, `ResolvePolicy` at `:187`, metrics mount `:102-108`); 1895-line body unread and N4.
M11 — WRITTEN. 538 lines; 25 `log(` hits = 23 call sites + comment `:81` + `def log` `:112`, exactly as claimed; settings `:43/:45/:46/:48/:52/:53/:60/:68` and `:334/:336/:501/:510` exact; the "tests are decoration" finding verified (0 `assert`/`exit` in both scripts).
M12 — PARTIAL, blocking. The analysis is the sharpest in the set — sha256 reproduced byte-identical, `_node` `:115`, the 4-site grep reproduced, `/health` truly unauthenticated, F12-5's `bytes | None` at `:164`, F12-7's unframed stream (no `Content-Length`/`Transfer-Encoding`/`Connection: close` before `end_headers()`) all correct — and it is undone by B1 and B2, both in the one section an operator reads first.

PANEL REVIEW COMPLETE

session_id: local-ae553a537c2a8fafdd0a35cc1f5e7a0e5af66efc392a29019849c7c213862e93

EXIT=0
```

### kimi

```
All verification passes are done. Compiling the verdict from the measured results.

VERDICT: FAIL

BLOCKING: 3 — findings that must be fixed before this chapter can be called written
NON-BLOCKING: 6

FINDINGS:

1. kind: FALSE CLAIM
   chapter: M12-inference-proxy (§5 settings register)
   claim: "USAGE_LOG | ~/.hermes/logs/cf-usage.jsonl (`:49`)" and "CAPTURE_LOG | ~/.hermes/logs/cf-capture.jsonl (`:50`)"
   evidence: /home/kara/.hermes/scripts/cf-inference-proxy.py:49-50 — actual code: USAGE_LOG = "~/.hermes/logs/cf-inference-usage.jsonl", CAPTURE_LOG = "~/.hermes/logs/cf-inference-requests.jsonl". The F12-6 consequence analysis (silent capture loss vs usage-write raising into the request path) is attached to two filenames that do not exist on disk. An operator following the register to inspect the sinks would open nonexistent files.
   fix: correct both paths to the measured values; re-derive F12-6's sink rows against them.

2. kind: FALSE CLAIM
   chapter: M4-board (§7 drift row)
   claim: "byte parity, RESULT OK … HEAD==origin/main `943ef98`"
   evidence: re-run this round: `python3 scripts/board_drift.py check --workdir /home/kara/code-factory --ref origin/main` prints HEAD=943ef984… origin/main=388c7cbe2f… — HEAD is an ANCESTOR of origin/main, not equal to it. RESULT: OK is real (byte parity of the board files), but "HEAD==origin/main" is contradicted by the tool's own output quoted two lines above it.
   fix: restate the row as "board files byte-identical to origin/main; HEAD is an ancestor of origin/main (943ef98 → 388c7cbe), not equal".

3. kind: FALSE CLAIM (locator)
   chapter: M11-dispatcher (F11-7)
   claim: "`DISPATCH_TASK_S` is a string until `int()` at use (`task_seconds` `:193`)"
   evidence: /home/kara/crier-fleet/dispatcher.py — `def task_seconds` is at :185, the `int(TASK_S)` conversion is at :196; :193 is inside the function's docstring. The chapter's own §5 register cites :196 correctly, so the chapter contradicts itself.
   fix: change the F11-7 locator to :196 (or :185-197).

4. kind: UNVERIFIED (declared, residual)
   chapter: M1, M5, M6, M7, M9, M10 (identity Status)
   claim: module statuses UNVERIFIED because unit bodies were not read line-by-line (M1 S1–S4 bodies, M5 four foreign installers, M6 fill/render/panel pipeline, M9 tick_process/packer/namespace/usage_pool at grep level, M10 the 1895-line handler body)
   evidence: each chapter §1/§13 names the unread spans; I confirmed the unread spans exist as named (handler.go is 1895 lines; the M5 installers exist and refuse --apply as documented at install-deepseek.sh:95-97 and install-pi-agent.sh:107-109)
   fix: read the named spans or keep the chapters below WRITTEN. This is honest labelling, not hidden padding — non-blocking for accuracy, blocking for any future WRITTEN claim.

5. kind: UNVERIFIED (live-surface checks not repeatable from this host)
   chapter: M2 §7, M10 §7 (node-bus-worker --check on cf-node), M5 §7 (conformance battery), M7 §7 (token mint), M12 §7 (disallowed-model 403)
   evidence: each row names why it cannot run here (no live node, no App creds, token file not read); I confirmed the live 401 admission on the proxy DOES reproduce (curl no-token → 401, this round)
   fix: run on the live node or keep the rows UNVERIFIED. Honest; non-blocking.

6. kind: OMISSION (minor locator imprecision)
   chapter: M0-shared-contract (§2)
   claim: "what a shell script may print (`ok`/`bad`/`warn`/`note`, `lib.sh:5-9`)"
   evidence: lib.sh:5 is `say()` — ok:6, bad:7, warn:8, note:9. The :5-9 range silently includes say() while the claim's list excludes it. The §9 log table cites the correct lines individually.
   fix: cite :6-9 or include say().

7. kind: CONTRADICTION (documented in-chapter, residual)
   chapter: M10-crier (F10-3)
   claim: metrics default-ON vs internal/metrics/metrics.go:2 "the opt-in GET /metrics surface"
   evidence: config/config.go:667-673 sets EnableMetrics: true; the stale comment at metrics.go:2 confirmed verbatim this round. The chapter documents the contradiction correctly — the residual is in the CODE, not the chapter.
   fix: board row against the stale comment; no chapter change needed.

8. kind: PADDING (self-declared gaps counted as RED)
   chapter: M9 (§9 log inventory: 2 of 379 log.Printf sites), M9 §5 (B52 flag surface unregistered), M10 §9 (slog inventory non-exhaustive)
   evidence: `grep -c 'log.Printf' internal/scheduler/*.go` sums to 379 this round — the 2-row inventory is 0.5% of the surface. The chapters declare these RED themselves, so this is disclosed, not hidden.
   fix: expand or explicitly defer with a named acceptance row. Non-blocking because disclosed.

DEFECT CLASSES: false measured value (paths), false equality claim, stale locator, self-contradictory locator, unread-body UNVERIFIED, unrepeatable live check, disclosed RED (metrics absence), external-peer one-sided contract (correctly labelled "rumour"), stale comment in code (documented), decoration test row (M11 §7, correctly removed/downgraded)

What I re-ran and reproduced this round (so the PASS side is also measured):
- code-factory HEAD 943ef98; lib.sh 78 lines, ok/bad/warn/note :6-9, fetch_verified :19-42 with --max-time 120 :22, require_disk :48-57, bunker_exec :75-78; source counts 11 direct / 17 total; metrics grep 0.
- bunker-provision.sh:214 ([ -s ] probe) and :233 ("mode 600" claim) — F1-1 confirmed live. disk_floor.py:36-40, resolve() :115-141 precedence; project-node.sh:173 disk_floor caller, :212 reclaim caller.
- configure_family.py:24-28 PID 1755676 hardcode (F2-2 confirmed); configure_family.py:17,149 lane_target caller (F2-4 confirmed).
- node-bus-worker.py: text read :986, reply shape :1128-1144 (no run_id/outcome — OUTLINE §IV stale, chapter correct), dispatch_wall :1152-1157, settlement loop :1300-1367, CLI defaults :1430-1449.
- land-node-branch.sh 295 lines, GATE="" :36, gate-only-if-nonempty :171, explicit push refspec; install-gitreins.sh PIN 0.17.1 :19, version bad :53, hook exit-0-without-config :120-138; clone_lane.py 130 lines.
- board: 357 rows / 515 events; boardctl wrapper exit-127 path; board_drift RESULT OK.
- harness-vars.sh [0-7]00 :203, CFV_DECLARED 12 / CFV_REQUIRED 6, defaults 40/1800 and ranges 1..1000/1..86400; install-hermes python gate >=3.11,<3.14 :108-115; harness_resolve has no production caller (grep: self + tests only).
- master_doc_check.py re-run: "44 module(s): 37 VERIFIED, 50 error(s), 0 warning(s)" / MASTER-DOC: FAIL — exact reproduction; glob [0-9][0-9]-*.md :188 confirmed not to select M*.md; gen_nasa_handbook.py:18 docs/master hardcode; fill --workers ThreadPoolExecutor :450.
- github-app-token.py 0600 check :344-348; refresh --dry-run exits before mint :106.
- reclaim_disk.py AGED_PARENTS :21 (no .cf-jobs — F8-3 confirmed), reclaim() :42-47; check_scan_scope.py empty-selection OK :109-114, re-run: 15 claims, RESULT OK.
- scheduler HEAD 1771d3aa; dispatchReplyVerdict :713-726 reads only payload["ok"] (CF-355 confirmed); payload() emits text_b64 with field `board` (CF-354 confirmed); admission_mode.go :98/:112/:143/:177/:234; main.go defaults :108-114 and load-gate 0 :144; LoadRootConfig at exactly the 10 cited sites; scheduler.db has 30 tables, no verdicts table; go build PASS; the three env-sensitive tests PASS clean-env (0.230s); log.Printf sites = 379.
- crier HEAD 691f0c78; handler funcs :598/:613/:990/:1690/:1812; 91 registry test files; EnableMetrics true :673; guard pipeline :25-28, Check :167; crier_client deliver/retrieve/ack :975/:1009/:1038; front 127.0.0.1:8770 :39; go build PASS.
- dispatcher.py HEAD 283bca9, 538 lines; settings :41-53 (TASK_S is a string :48 confirmed), BUNKER :60, dispatch switch :334-336, ledger replay :470-475, body with ok :500-508; grep 'log(' = 25 lines.
- cf-inference-proxy.py sha256 b12a0ac5… reproduced; 273 lines; LISTEN :53, MAX_BODY :54, _node :115-123, fail-closed startup :265-270, union annotation :164; live no-token POST → 401.
- Unit tests re-run: test_disk_floor (12 tests OK), test_lane_target, test_harness_resolve, test_reclaim — all OK. verify-patch.sh VERIFY-PATCH: PASS.

CHAPTER SCORECARD:
- M0 — WRITTEN: file read in full; every cited locator reproduced; one off-by-one range (:5-9) is cosmetic.
- M1 — PARTIAL: orchestrator call sites verified and two round-3 errors genuinely corrected (F1-4 confirmed), but S1–S4 unit bodies unread (self-declared); F1-1 defect confirmed live.
- M2 — WRITTEN: contract-bearing spans read and reproduced; both broken contracts (CF-354/CF-355) confirmed at the cited lines; same-batch idempotency gap consistent with the loop at :1300-1331.
- M3 — WRITTEN: all three units read in full; GATE-empty default, hook exit-0, explicit push refspec all reproduced.
- M4 — PARTIAL: store census, drift and validate reproduced, but the drift row asserts HEAD==origin/main against the tool's own output (FALSE CLAIM, blocking #2).
- M5 — PARTIAL: contract predicates and installer ladder confirmed ([0-7]00 vs "must be 600" predicate/message mismatch is real), but four installer bodies unread (self-declared).
- M6 — PARTIAL: the gate's exact FAIL line reproduces; F6-2 (gate reports supplied status, does not recompute) confirmed at :128-138; most of the pipeline unread (self-declared).
- M7 — PARTIAL: settings/controls read and confirmed (0600 check, dry-run-before-mint), but the mint has never been run; M7-C1 correctly UNVERIFIED.
- M8 — WRITTEN: both files read in full; every claim reproduced, including the .cf-jobs reaper gap (F8-3).
- M9 — PARTIAL: every load-bearing claim I re-ran reproduced (settlement defect, admission locators, binary defaults, LoadRootConfig×10, 30 tables, clean-env tests); but §9 is 2 of 379 sites and §5 self-declares an unregistered flag surface — the chapter knows its own gaps.
- M10 — PARTIAL: handler surface, config defaults, metrics default-ON, 91 test files, and the metrics.go stale comment all reproduced; the 1895-line body remains unread (self-declared).
- M11 — PARTIAL: full read confirmed plausible and the ledger/bridge/settings claims reproduced; F11-7 carries a wrong locator (:193, blocking #3) and the live-job tests are correctly demoted to decoration.
- M12 — PARTIAL: the most-thorough chapter by measurement (hash, 401 live, full read), but the settings register names two log paths that do not exist in the code (FALSE CLAIM, blocking #1); stream completion (F12-7) remains honestly UNVERIFIED.

Summary for the owner: this round is measurably better than the outline's v1 — I re-ran over forty of the chapters' own commands and locators and the overwhelming majority reproduced exactly, including every headline defect (CF-354, CF-355, F1-1, F2-2, F9-3, F10-3, F12-4 through F12-7). It fails on three small but real false claims: two wrong log paths in M12, a false HEAD==origin/main equality in M4, and one wrong locator in M11. Fix those three rows and the declared-UNVERIFIED spans remain the only thing between this document and PASS; those spans are honestly labelled, not hidden.

PANEL REVIEW COMPLETE

session_id: local-84ded7017182b5c9d7a93806acfd38697e41b9da956dc12204d762058e6c9013

EXIT=0
```

### sol

```
│ cache/scratch/round5_independent_probes.py
│ @@ -0,0 +1,124 @@
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
│ +import tempfile
│ +import threading
│ +import time
│ +from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
│ +
│ +ROOT = Path('/home/kara/code-factory')
│ +BASE = Path(tempfile.mkdtemp(prefix='quorum-r5-', dir='/home/kara/.hermes/cache/scratch'))
│ +print('probe_root=' + str(BASE), flush=True)
│ +
│ +# Static inventories, independently derived, never read earlier seat verdicts.
│ +chapters = sorted((ROOT / 'docs/handbook/chapters').glob('M*.md'))
│ +print('chapter_count=' + str(len(chapters)))
│ +for expr in [r'\. "\$HERE/lib\.sh"', r'\. "\$HERE/(\.\./)?lib\.sh"']:
│ +    import re
│ +    found = [str(p.relative_to(ROOT)) for p in (ROOT/'scripts').rglob('*') if p.is_file() and re.search(expr, p.read_text(errors='replace'))]
│ +    print('source_count ' + expr + ' = ' + str(len(found)))
│ +main = Path('/home/kara/coding-hermes-scheduler/coding-herms-scheduler/cmd/schedulerd/main.go').read_text()
│ +flags = re.findall(r'flag\.(?:String|Int|Int64|Bool|Duration|Float64)\("([^\"]+)"', main)
│ +print('schedulerd_declared_flags=' + str(len(flags)))
│ +print('proxy_sink_constants=' + repr([line for line in Path('/home/kara/.hermes/scripts/cf-inference-proxy.py').read_text().splitlines() if line.startswith(('USAGE_LOG =','CAPTURE_LOG ='))]))
│ +
│ +# Repeat the cheap documented unit checks; isolate all generated caches/temp files.
│ +env = dict(os.environ, TMPDIR=str(BASE), PYTHONPYCACHEPREFIX=str(BASE/'pycache'))
│ +for name in ['disk_floor', 'lane_target', 'harness_resolve', 'reclaim']:
│ +    result = subprocess.run(['python3', '-B', 'tests/test_' + name + '.py'], cwd=ROOT, env=env, capture_output=True, text=True, timeout=60)
│ +    print('REPEAT test_' + name + ' rc=' + str(result.returncode))
│ +    print((result.stdout + result.stderr).strip())
│ +
│ +# Isolate the actual proxy implementation on ephemeral loopback ports with fake credentials.
│ +spec = importlib.util.spec_from_file_location('r5_proxy', '/home/kara/.hermes/scripts/cf-inference-proxy.py')
│ +proxy = importlib.util.module_from_spec(spec)
│ +spec.loader.exec_module(proxy)
│ +payload = b'data: {"ok":true}\n\ndata: [DONE]\n\n'
│ +class Upstream(BaseHTTPRequestHandler):
│ +    def do_POST(self):
│ +        self.rfile.read(int(self.headers['Content-Length']))
│ +        self.send_response(200)
│ +        self.send_header('Content-Type', 'text/event-stream')
│ +        self.send_header('Content-Length', str(len(payload)))
│ +        self.end_headers()
│ +        self.wfile.write(payload)
│ +    def log_message(self, *args):
│ +        pass
│ +up = ThreadingHTTPServer(('127.0.0.1', 0), Upstream)
│ +relay = ThreadingHTTPServer(('127.0.0.1', 0), proxy.Handler)
│ +proxy.UPSTREAM = 'http://127.0.0.1:' + str(up.server_port)
│ +proxy.UPSTREAM_MODEL = ''
│ +proxy.upstream_key = lambda: 'fixture-only-not-a-real-key'
│ +proxy.load_tokens = lambda: {'fixture-node': 'fixture-token'}
│ +proxy.USAGE_LOG = BASE/'usage.jsonl'
│ +proxy.CAPTURE_LOG = BASE/'capture.jsonl'
│ +for server in (up, relay):
│ +    threading.Thread(target=server.serve_forever, daemon=True).start()
│ +conn = http.client.HTTPConnection('127.0.0.1', relay.server_port, timeout=0.5)
│ +try:
│ +    conn.request('POST', '/v1/chat/completions', body=json.dumps({'model':'hermes','stream':True,'messages':[]}), headers={'Authorization':'Bearer fixture-token','Content-Type':'application/json'})
│ +    response = conn.getresponse()
│ +    received = response.read(len(payload))
│ +    print('PROXY healthy_stream status=' + str(response.status) + ' bytes_match=' + str(received == payload) + ' headers=' + repr(response.getheaders()))
│ +    try:
│ +        extra = response.read(1)
│ +        print('PROXY healthy_stream eof=' + repr(extra))
│ +    except TimeoutError:
│ +        print('PROXY healthy_stream EOF_TIMEOUT (upstream already completed)')
│ +finally:
│ +    conn.close()
│ +    relay.shutdown()
│ +    up.shutdown()
│ … omitted 46 diff line(s) across 1 additional file(s)/section(s)
│ cache/scratch/round5_verifier_probe.py
│ @@ -0,0 +1,63 @@
│ +from pathlib import Path
│ +import os
│ +import subprocess
│ +import tempfile
│ +
│ +root = Path('/home/kara/code-factory')
│ +base = Path(tempfile.mkdtemp(prefix='quorum-r5-verify-',dir='/home/kara/.hermes/cache/scratch'))
│ +bin_dir = base/'bin'
│ +bin_dir.mkdir()
│ +def executable(name, text):
│ +    p = bin_dir/name
│ +    p.write_text(text)
│ +    p.chmod(0o700)
│ +executable('bunker', '''#!/bin/sh
│ +case "$*" in
│ + *'echo ALIVE'*) printf 'ALIVE fixture\n' ;;
│ + *'hostname -I'*) printf '127.0.0.1\n' ;;
│ + *) exit 1 ;;
│ +esac
│ +''')
│ +executable('curl', '''#!/bin/sh
│ +case "$*" in
│ + *'/api/status'*)
│ +  dest=""
│ +  while [ "$#" -gt 0 ]; do
│ +   if [ "$1" = -o ]; then dest="$2"; break; fi
│ +   shift
│ +  done
│ +  printf '{"auth_required":true}\n' > "$dest"
│ +  printf 200 ;;
│ + *'/api/system/stats'*) printf 401 ;;
│ + *) exit 1 ;;
│ +esac
│ +''')
│ +executable('python3', '''#!/bin/sh
│ +case "$*" in
│ + *node_freshness.py*) printf 'RESULT: UNVERIFIED fixture checkout unavailable\n' >&2; exit 3 ;;
│ + *node_seed_drift.py*) printf '  PASS  seed_drift — fixture seed matches\n' >&2; exit 0 ;;
│ + *) exit 99 ;;
│ +esac
│ +''')
│ +# Keep the tested shell intact except relocating its fixed /tmp status sink into scratch.
│ +# No production files or live node are touched.
│ +source = (root/'scripts/verify-node.sh').read_text().replace('HERE="$(cd "$(dirname "$0")" && pwd)"', 'HERE="/home/kara/code-factory/scripts"').replace('/tmp/node-status.json', str(base/'node-status.json'))
│ +probe = base/'verify-node.sh'
│ +probe.write_text(source)
│ +env = dict(os.environ, PATH=str(bin_dir)+':'+os.environ['PATH'], TMPDIR=str(base))
│ +for extra in ([],['--strict-freshness']):
│ +    result = subprocess.run(['bash',str(probe),'--agent','fixture','--server','fixture',*extra],env=env,capture_output=True,text=True,timeout=10)
│ +    print('VERIFIER FIXTURE ' + repr(extra) + ' rc=' + str(result.returncode))
│ +    print(result.stdout + result.stderr)
│ +# Exercise the actual lib.sh helper on a loopback-refused URL.
│ +helper = base/'fetch-refusal.sh'
│ +helper.write_text('''#!/bin/bash
│ +. /home/kara/code-factory/scripts/lib.sh
│ +fetch_verified http://127.0.0.1:1/nothing "$1" deliberately-wrong-digest
│ +rc=$?
│ +printf 'fetch_rc=%s artifact_present=' "$rc"
│ +if [ -e "$1" ]; then printf 'yes\n'; else printf 'no\n'; fi
│ +''')
│ +result = subprocess.run(['bash',str(helper),str(base/'artifact')],env=dict(os.environ,TMPDIR=str(base)),capture_output=True,text=True,timeout=10)
│ +print(result.stdout+result.stderr)
│ +print('FIXTURE_ROOT=' + str(base))
VERDICT: FAIL
BLOCKING: 25 — findings that prevent the affected chapters from being called WRITTEN
NON-BLOCKING: 1

FINDINGS:

Review basis:
  Read all 13 chapters, OUTLINE.md and MASTER-DOC-SCHEMA.md. Checked claims against the implementations, not previous seat verdicts.

  Source revisions verified:
    code-factory: 943ef984dc093e5780605ac6e54cd043122126ef
    scheduler: 1771d3aad61e6c1ce2845e3f1450f88aa73340b3
    crier: 691f0c78fc75717295abf3bd85aaa9192616aac0
    crier-fleet: 283bca91091933177ec521e52f37f1bc987cf7da
    inference proxy SHA-256: b12a0ac521c4b5a9cd7e2b76883a7edf2c9e0efd87d9bc3be3d2056d3f39e0b5

  Path abbreviations below:
    CF = /home/kara/code-factory
    SCH = /home/kara/coding-hermes-scheduler/coding-herms-scheduler
    CR = /home/kara/crier
    DISP = /home/kara/crier-fleet
    PX = /home/kara/.hermes/scripts/cf-inference-proxy.py
    Chapter references are files under CF/docs/handbook/chapters/.

  Independently repeated:
    disk_floor: 12 tests, PASS.
    lane_target: 40 tests, PASS.
    harness_resolve: 28 tests, PASS.
    reclaim: 9 tests, PASS.
    boardctl validate: 357 tasks, 515 events, RESULT: OK with 7 warnings.
    board_drift: RESULT: OK, board bytes match origin/main.
    verify-patch: PASS, four stages and three patches.
    default documentation gate: 44 modules, 37 declared VERIFIED, 50 errors, exit 1.
    gate explicitly targeting chapters/: zero selected modules, exit 1.
    handbook renderer: “no modules found”, exit 1.
    live proxy without a token: HTTP 401.
    GitHub minter without a subcommand: usage, exit 2.

  Additional offline probes exercised the actual proxy handler, the dispatcher's generated runner template, and the verifier's decision branches with disposable stand-ins. They used no production credentials and dispatched no real work.

  I did not repeat the full Go suites, live node certification, live conformance battery or GitHub token mint. Their historical PASS claims are not new execution evidence from this review.

B01 — FALSE CLAIM
  Chapter: M11-dispatcher.md, §2/§3/§11.
  Claim: “kill the process group on deadline”; the durable job model is presented as ensuring descendants stop with the job.

  Evidence:
    DISP/dispatcher.py:246-260 explicitly starts GNU timeout in its own process group.
    DISP/dispatcher.py:328-330 kills the group identified by run.sh's pid, not the separate timeout group recorded in hpid.
    My disposable execution of the actual runner template produced distinct runner and timeout process groups. After terminating the runner group, the timeout process was still live:
      distinct=True
      timeout_still_live=True

  Fix:
    Document the two process groups and the surviving-harness failure mode. Withdraw the descendant-termination guarantee until a test proves that the deadline path kills the harness group and its children. The corresponding implementation repair must target the supervised execution boundary, not merely run.sh's group.

B02 — FALSE CLAIM
  Chapter: M5-harness.md:40-42.
  Claim: The installers are operator-invoked; the source search finds no production invocation, and “all five run by an operator, not a unit.”

  Evidence:
    CF/scripts/project-node.sh:440 constructs:
      inst="$HERE/harness/install-$HARNESS.sh"
    CF/scripts/project-node.sh:449-452 invokes that installer with --apply or --check.
    CF/scripts/node-create.sh:24,31 also constructs the selected installer path for staging.
    A literal search for “install-hermes” misses these computed call sites.

  Fix:
    Correct the invocation graph and classifications. Name project-node.sh's layer-20 dispatch as the caller and distinguish installation orchestration from the operator who initially starts provisioning. Search computed paths before asserting that no caller exists.

B03 — FALSE CLAIM
  Chapter: M12-inference-proxy.md:65-66.
  Claim:
    USAGE_LOG = ~/.hermes/logs/cf-usage.jsonl
    CAPTURE_LOG = ~/.hermes/logs/cf-capture.jsonl

  Evidence:
    PX:50:
      /home/kara/.hermes/logs/cf-inference-usage.jsonl
    PX:52:
      /home/kara/.hermes/logs/cf-inference-requests.jsonl
    These are the constants in the exact file whose hash the chapter correctly records.

  Fix:
    Replace both paths in the settings register. Identify them as hardcoded paths, not configurable environment settings. An operator following the current register looks in the wrong files for attribution and request capture.

B04 — FALSE CLAIM
  Chapter: M4-board.md:130.
  Claim: “M9 SCHEDULER and M10 CRIER read board rows as admission gates.”

  Evidence:
    SCH/internal/scheduler/admission_mode.go:230-242 performs the board-ownership/workability admission decision.
    CR/internal/registry/handler.go:1690 and its retrieval implementation operate on inbox messages and leases.
    A source search across Crier's Go files found no matches for tasks.jsonl, board_ownership, boardWorkable or board/admission terminology.

  Fix:
    Assign board-driven scheduling admission to M9. Describe M10's actual transport, authentication and guard admission separately. Do not give the bus responsibility for the scheduler's board gate.

B05 — OMISSION
  Chapter: M1-provisioning.md, §10/§11.
  Claim: The certification ladder describes checkout unmeasurability as WARN and the final FAIL/UNVERIFIED precedence, but omits that checkout unmeasurability can still finish as VERIFY: PASS.

  Evidence:
    CF/scripts/verify-node.sh:145-151 prints a checkout WARN without calling unverified().
    The seed equivalent does call unverified() at :194-198.
    Final selection is at :206-214.
    My controlled fixture, with reachable/authenticated gateway checks and a passing seed check, returned:
      WARN checkout_freshness — UNVERIFIED fixture checkout unavailable
      VERIFY: PASS
      rc=0
    The same fixture with --strict-freshness returned VERIFY: FAIL, rc=1.

  Fix:
    Explicitly document this asymmetric false-green path and its operational consequence. State that default certification does not prove checkout freshness when that measurement is unavailable. Provide a regression test and require strict freshness wherever freshness is an acceptance condition.

B06 — OMISSION
  Chapter: M1-provisioning.md, S4.
  Claim: “seed prompts/skills/env”; the inventory names the seeder but does not explain its update contract.

  Evidence:
    CF/scripts/node_seed.py:205-247 stages extraction and verifies recorded digests.
    :249-312 distinguishes new, changed, removed and local-only files.
    Without --force, changed, removed and local-only files are preserved.
    With --force, :280-291 removes and replaces destination trees.
    :320-324 writes the applied seed record.
    These behaviors determine whether a provisioned node actually carries the intended procedure.

  Fix:
    Write the seed state machine: build → transfer → digest verification → preservation/replacement → applied record → drift check. Include the consequences of preserved local edits and --force. Naming the seeder and its invocation is not sufficient documentation of S4.

B07 — OMISSION
  Chapter: M1-provisioning.md, §5.
  Claim: The settings register covers provisioning inputs through a single “config keys” row and a mode row.

  Evidence:
    CF/scripts/bunker-provision.sh:38-46 declares the provisioning defaults.
    :356 uses a 6h spawn TTL fallback.
    :562-609 implements the CLI/config precedence surface.
    CF/scripts/node_seed.py:43-44 defines the default manifest and 16 MiB seed budget; :373-387 exposes manifest, budget, destination and destructive force controls.
    These controls have no individual default/range/consequence entries in M1.

  Fix:
    Replace the aggregated KEY=VALUE row with the actual provisioning and seeding controls. Give each control its default, accepted values, reader and consequence. Include TTL, credential/profile paths, namespaces, config-set inputs and seed limits. The present aggregate is NAME ONLY.

B08 — FALSE CLAIM
  Chapter: M2-dispatch.md:71,77.
  Claim:
    DEFAULT_INBOX_LIMIT range: “positive int”.
    --harness-wall / --timeout defaults: symbolic constant names rather than values.

  Evidence:
    CR/internal/registry/handler.go:1718-1731 rejects an inbox batch above 100.
    CF/scripts/node-bus-worker.py:80-83 defines concrete defaults:
      inbox limit 10
      lease 30 seconds
      request timeout 10 seconds
      harness wall 1800 seconds
    The worker's CLI does not uniformly validate all these arguments as positive integers; :1463-1478 validates specific other inputs.

  Fix:
    Document the effective producer-and-consumer bounds, including the bus's 100-message ceiling. Expand symbolic defaults into values. Distinguish accepted argparse types, local validation, downstream refusal and runtime exceptions.

B09 — OMISSION
  Chapter: M0-shared-contract.md, S1.
  Claim: The shell contract is described through printing, verified fetch, disk admission and quoting.

  Evidence:
    CF/scripts/lib.sh:59-64 implements once(): sentinel existence suppresses execution; successful execution is followed by directory creation and sentinel writing.
    :13 implements have() with an intentionally successful empty result on absence.
    :45 implements the rounded free-space measurement.
    The chapter does not explain once() at all, or the caller obligations arising from these helper return/value contracts.

  Fix:
    Inventory every exported helper with inputs, output, exit behavior and caller obligations. Explain sentinel semantics, lack of a concurrency lock around once(), and how callers must detect an empty have() result. M0 is the shared behavioral contract, not a selection of its most visible helpers.

B10 — UNVERIFIED
  Chapter: M3-repository.md, §7.
  Claim: The module is VERIFIED, while the landing dry-run was refused and the named freshness arm was not rerun.

  Evidence:
    M3:106 records refusal rather than execution of a valid landing plan.
    M3:107 records only that the freshness test arm exists.
    CF/scripts/land-node-branch.sh:145-214 implements ancestry, idempotency, gate and local-main refusal branches.
    :265-287 implements push, post-push fetch, ancestry verification and remote disagreement handling.
    Syntax checking does not exercise these behaviors.

  Fix:
    Supply a disposable local bare remote and clean worktree fixture. Exercise successful dry-run, gate rejection, successful landing, repeated landing, rejected ancestry and failed remote-proof cases with asserted exits and ref readback. Keep the behavioral verification field UNVERIFIED until those results exist.

B11 — OMISSION
  Chapter: M4-board.md, S1/§7/§10.
  Claim: “board_lock.py adjudicates the lock”; verification expects “RESIDUE / HELD”.

  Evidence:
    CF/scripts/board_lock.py:149-158 has three outcomes, including ABSENT.
    It first checks open file descriptors and returns HELD for a discovered descriptor holder; otherwise it tries the flock probe.
    :49-65 begins the /proc descriptor inspection.
    The chapter does not explain these distinct kinds of evidence, the absent-path case, or the operator decision following each outcome.

  Fix:
    Document the classifier algorithm and its limits. Distinguish an open descriptor from proof of an advisory flock, explain permission/race limitations, and give safe next actions for ABSENT, HELD and RESIDUE. Supply held/unheld fixtures rather than a command without a concrete lock setup.

B12 — OMISSION
  Chapter: M5-harness.md, §5.
  Claim: “harness-vars.sh … is the register for the CF_* set it enforces,” used as the module's settings register.

  Evidence:
    CF/scripts/harness/install-hermes.sh:23-30 reads NODE_GATEWAY_PORT, HERMES_PIN and HERMES_PYTHON_BIN and defines interpreter bounds.
    CF/scripts/harness/install-codex.sh:49-60 defines pin, installation paths, digest, disk floor, sandbox and turn controls.
    :428 reads CF_CODEX_SHA256.
    The chapter's CF_* table does not register these installer/toolchain controls with their defaults, ranges and consequences.

  Fix:
    Retain the shared variable contract and add per-adapter installation, interpreter, artifact-integrity, sandbox and gateway registers. Explain coordinated pin/digest changes. The shared run-variable table is not the entire harness settings surface.

B13 — UNBUILDABLE
  Chapter: M6-documentation.md, S1–S8.
  Claim: The chapter describes a documentation pipeline but acknowledges that its gate, fill and render paths do not operate on this chapter set.

  Evidence:
    CF/scripts/master_doc_check.py:188 selects NN-*.md.
    CF/scripts/gen_nasa_handbook.py:253-260 uses the same filename convention.
    CF/scripts/panel_loop.py:33-34 depends on dated scratch paths; :62-70 searches III.* identifiers.
    Independent execution:
      master_doc_check.py docs/handbook/chapters
        zero modules selected, exit 1
      gen_nasa_handbook.py
        “no modules found”, exit 1

  Fix:
    Provide one executable, chapter-aware entry path from source selection through verification to the delivered artifact. Document its actual inputs, outputs, failure behavior and acceptance command. The current chapter correctly admits the disconnection, but that admission does not make the pipeline buildable or the chapter WRITTEN.

B14 — OMISSION
  Chapter: M7-github.md, §5.
  Claim: “refresh controls … | per-flag” constitutes the lifecycle settings register.

  Evidence:
    CF/scripts/github-app-refresh.sh:24-33 defines actual refresh defaults, including MIN_AGE=2400, credential-store destination and local/node mode flags.
    :53 validates the min-age spelling.
    :104-142 is the local refresh path; :145-174 is a different node installation path.
    CF/scripts/github-app-token.py:582-590 skips minting based on destination age.
    The aggregate row does not give individual defaults, ranges and consequences for these controls.

  Fix:
    Split the lifecycle controls into individual rows. Explain min-age versus token lifetime, local/node behavior, destination precedence, credential-store rewriting and failure before/after installation. “Per-flag” is NAME ONLY, not a range.

B15 — OMISSION
  Chapter: M8-safety.md, §5/§11.
  Claim: The reaper is governed by --job-ttl-hours, --root and --dry-run.

  Evidence:
    CF/scripts/reclaim_disk.py:14-22 fixes the actual target and protection lists.
    :102-103 processes build caches without an age condition.
    :104-111 applies age handling only to job/clone children.
    :90 keeps a directory when its age is less than or equal to the TTL.
    :119-123 reports byte totals even in dry-run mode.
    The chapter does not enumerate the cache targets or explicitly warn that the TTL does not protect those caches and dry-run byte totals are projected, not actually reclaimed.

  Fix:
    List the exact cache, aged-parent and protected paths. State the TTL's scope and boundary behavior and distinguish planned from actual deletion totals. This is necessary for an operator to predict what a maintenance run will remove.

B16 — UNBUILDABLE
  Chapter: M9-scheduler.md, S1.
  Claim: “eligibility, tasks-vs-cooldown, board gates, fairness, budget reservation” describes admission and allocation.

  Evidence:
    SCH/internal/scheduler/admission_mode.go:98-129 implements mode precedence.
    :177-184 implements ownership overrides.
    :230-242 requires owned, readable, workable board work for the waiver.
    :266-267 identifies the last-failed-tick condition.
    SCH/internal/scheduler/usage_pool_policy.go:26-63 distinguishes disabled policy, missing authority, local/remote pools, observe-only checks, lease recovery and reservation.
    M9 names these responsibilities but does not describe their composed decision sequence or refusal outcomes.

  Fix:
    Write an ordered admission procedure with input authority, gate order, waiver rules, observe-only versus enforcing behavior, reservation/release ownership and named deferrals. Provide worked positive, refused, empty-board and unavailable-authority cases. A list of Go filenames and policy nouns cannot be turned into a reliable implementation task.

B17 — OMISSION
  Chapter: M9-scheduler.md, S3.
  Claim: “live store has 30 tables” plus selected migration locators documents durable state.

  Evidence:
    SCH/internal/database/migrations.go:1217-1232 defines the tick dispatch receipt and indexes.
    :1391-1408 defines run states, verification states and submission idempotency.
    :1412-1425 defines workspace lease ownership and the single-active-writer index.
    :1427-1447 defines attempt generation and process/session attribution.
    :1449-1489 defines event sequence uniqueness, verification receipts, projections and outbox state.
    These are run-correctness and recovery contracts, not incidental package internals.

  Fix:
    Add the store's keys, relationships, state vocabularies, uniqueness guarantees, write authorities and recovery queries. Explain how tick receipts, execution runs, attempts, workspace leases and projections relate. A table count is a census, not a durable-state chapter.

B18 — OMISSION
  Chapter: M9-scheduler.md, S4.
  Claim: “ls cmd/ → 7 command dirs” documents operator surfaces.

  Evidence:
    SCH/cmd/schedulerd/main.go:95-107 defines database, listener, TLS and public-origin controls.
    SCH/internal/api/server.go:289-346 mounts health, configuration, projects, hooks, lanes, namespaces, groups, templates, ticks, evaluation, pause/resume, events, queue and metrics routes.
    S4 supplies neither an operator surface inventory nor request/response examples and operational failure semantics.

  Fix:
    Document the surfaces at submodule granularity: daemon/service entry, read operations, authenticated mutations, dashboard, MCP and recovery commands. Include who may invoke each operation, its durable effect and the readback proving success. Command-directory presence is not an invocation or an operating procedure.

B19 — OMISSION
  Chapter: M9-scheduler.md, §5.
  Claim: The selected binary defaults form the settings register.

  Evidence:
    An independent extraction from SCH/cmd/schedulerd/main.go found 57 flag declarations.
    Important omitted examples:
      :149 spawn-mem-limit-mb
      :150 board-stasis-gate
      :151 hooks-file
      :159 session-silence-grace
      :170 session-poll-loop-min-ticks
      :172 disable-tick-push
      :190 no-exec-fallback
    These change admission, execution termination, hooks or publication behavior.

  Fix:
    Derive the complete register from flag, TOML and environment readers, reconcile precedence, and attach each reader and consequence. Keep the chapter PARTIAL until the omitted controls are registered; acknowledging an incomplete register does not satisfy the field contract.

B20 — OMISSION
  Chapter: M10-crier.md, S1.
  Claim: “registration, routing, acceptance, leases, retrieval, ack, TTL, transfer and dead letters” describes custody.

  Evidence:
    CR/internal/registry/handler.go:1711-1743 implements parameter aliases and precedence, default batch 10, maximum batch 100 and default lease 30 seconds.
    :1770-1775 explains that messages removed by a post-retrieval tag filter remain leased.
    CR/clients/python/crier_client.py:975-1006 defines signed delivery behavior and absent TTL versus ttl_seconds=0.
    :1009-1036 returns decoded messages carrying the batch lease.
    These operational distinctions are missing from the chapter's custody description.

  Fix:
    Write the custody lifecycle and wire contract, including defaults, aliases, lease ownership, ack requirements, empty responses, expiry behavior, idempotent replay/busy cases and filtering consequences. This is required to distinguish an empty queue, a held queue and failed delivery.

B21 — OMISSION
  Chapter: M10-crier.md, §5/§8.
  Claim: Grouped Webhook.* and Guard.* rows, with range “—”, are documented settings; the metric-name list is a completed inventory.

  Evidence:
    CR/config/config.go:635-655 supplies individual defaults.
    :1131-1136 and :1147-1187 reject invalid/non-positive values for individual controls.
    CR/internal/guard/metrics.go:22-29 defines counters; :46-49 defines a histogram and its labels; :38-45 fixes label domains and seeded children.
    M10 uses grouped consequences, dash ranges and wildcard metric names rather than the required per-setting and per-metric contracts.

  Fix:
    Expand the settings into individually admissible rows. Expand metrics into exact names, types, labels, label domains, questions answered and scrape location/authentication. A broad list is useful orientation, but is not the schema's completed register.

B22 — UNVERIFIED
  Chapters: M0, M1, M2, M3, M4, M5, M6, M7, M8, M9, M10, M11 and M12, §6.
  Claim: The contract tables satisfy the two-sided contract rule.

  Evidence:
    Examples that still lack the required producer AND consumer file:function:
      M0-C1: external bunker handler unnamed, state “works”.
      M5-C2: gateway is a port/service, state “works”.
      M6-C1: consumer is “the handbook's status word”, state “works”.
      M8-C1: “filesystem” and target roots stand in for a consumer, state “works”.
      M9-C2: consumer is “node/dispatcher decode”, not named functions.
      M12-C2: upstream is explicitly “rumour — one side only”, yet state “works”.
    Other tables honestly retain UNVERIFIED sides. That is admissible uncertainty, but remains a closure blocker.
    Concrete nameable implementations include SCH/internal/bus/dispatch.go:175 payload(), CF/scripts/node-bus-worker.py:972 process(), and DISP/dispatcher.py:135 payload_task().

  Fix:
    Name both implementation functions and payload/timing/error semantics for each in-scope software contract. Where a peer is outside the reviewable boundary, state that limitation and retain UNVERIFIED rather than inventing an exception that promotes “rumour” to “works”. Remove filesystem/status-word pseudo-contracts or replace them with the actual producing and consuming units.

B23 — UNVERIFIED
  Chapters: M0–M8, M11 and M12, §8.
  Claim: Each reports “RED — none” for emitted metrics, while several identities remain VERIFIED.

  Evidence:
    These RED fields are explicitly present in the chapters.
    MASTER-DOC-SCHEMA.md:72-79 makes missing metrics a required RED field.
    The handbook README:61-65 likewise states that such chapters stay PARTIAL until instrumentation exists or an explicit exception is approved.
    Structured logs and a replay ledger do not themselves satisfy the requested emitted metric contract.

  Fix:
    Keep these chapters PARTIAL. Close the observability gap with defined metrics and measured scrape evidence, or obtain a recorded schema exception. Honest reporting of “none” is correct writing; it is not authorization to call the required field complete.

B24 — OMISSION
  Chapters: M0, M1, M2, M5, M6, M7, M8, M9 and M10, §9.
  Claim: The log-line sections satisfy the required verbatim operator-visible inventory.

  Evidence:
    CF/scripts/lib.sh:32 and :37 emit destination-directory and move failures omitted from M0.
    M2:118 contains explanatory prose about a digest mismatch, not a verbatim emitted line.
    M9:136-138 explicitly admits that its two entries are only a sample.
    M10:138-140 explicitly admits a non-exhaustive inventory.
    CF/scripts/verify-node.sh:53 emits RESULT: FAIL on an early branch, in addition to the terminal VERIFY forms.
    Required log condition/action detail is therefore incomplete even where the selected entries are accurate.

  Fix:
    Derive operator-visible emission sites, group repetitive helpers without losing their call-specific conditions, and quote actual format strings. For each entry give level, trigger, descriptive/evidentiary status and operator action. Do not substitute a prose summary for a log string.

B25 — UNVERIFIED
  Chapters: M0, M1, M2, M3, M5, M7 and M10, §7.
  Claim: The verification tables provide checks a stranger can repeat.

  Evidence:
    M0 names a staged ffc_probe.sh without its location or complete invocation.
    M1 uses live-node placeholders without an established node/transport fixture.
    M2 and M10 cite ~/node-bus-worker.py on cf-node and explicitly say the check is not repeatable from this host.
    M3 records a refused dry-run instead of a successful clean-fixture check.
    M5's real-node conformance command is not accompanied by a complete setup and target contract.
    M7's mint row is “token …”, not an executable command with declared inputs.
    My independently staged helper probe did confirm fetch_rc=1 and artifact_present=no, but that does not make the chapter's missing probe artifact reproducible.

  Fix:
    Provide complete offline fixtures where possible and complete live prerequisites where not. State execution host, working directory, target selection, credential-file roles without values, command, asserted exit, expected output, revision and retained result artifact. Keep unavailable live checks UNVERIFIED; do not replace them with syntax compilation or inherited seat results.

N01 — PADDING — non-blocking
  Chapters: M0, M2, M3, M5, M6, M7, M9, M10, M11 and M12.
  Claim: Repeated “round-3 said”, “round-4 was false” and named-seat correction narratives remain embedded in operating sections.

  Evidence:
    Examples include M0:89-90, M3:109-112, M5:46-47 and M12:82-85.
    These describe the review's history rather than the operator's next decision.

  Fix:
    Move superseded wording and seat attribution into the change/supersession appendix. Keep the corrected behavior, its source and any unresolved limitation in the operational chapter. Preserve provenance without making the operator reconstruct previous rounds.

DEFECT CLASSES:
  Unproven descendant termination
  Computed-call-site blindness
  Incorrect operational paths
  Misassigned system authority
  Unmeasurable-to-PASS certification
  Undocumented seed replacement semantics
  NAME ONLY settings
  Producer/consumer range mismatch
  Incomplete shared helper contract
  Census substituted for specification
  Disconnected documentation pipeline
  One-sided contracts promoted to works
  Missing metric contracts
  Sample logs presented as inventory
  Non-repeatable verification
  Review-history padding

CHAPTER SCORECARD:

  M0 — PARTIAL
    Shared helper coverage is incomplete; the fetch probe is not fully reproducible from the chapter; contract and metrics fields remain unresolved.

  M1 — PARTIAL
    Omits the checkout-unmeasurable-to-PASS path and consequential seed/update behavior. Provisioning settings and live verification remain incomplete.

  M2 — PARTIAL
    Useful source-backed dialect and settlement analysis, but effective input bounds, two-sided contracts, log inventory and repeatable live verification are incomplete.

  M3 — PARTIAL
    Important landing constraints are accurately described, but behavioral verification has not exercised a valid fixture. Metrics and full contract closure remain absent. Operator invocation alone is not a defect.

  M4 — PARTIAL
    Store census and validation reproduce. The Crier board-admission claim is false; lock adjudication and write-boundary contracts are not fully specified.

  M5 — PARTIAL
    The no-production-installer-caller claim is false because project-node.sh computes and invokes the selected installer. Per-adapter settings and conformance evidence remain incomplete.

  M6 — PARTIAL
    Correctly admits structural rather than semantic verification, but there is no demonstrated end-to-end pipeline for these M-numbered chapters.

  M7 — PARTIAL
    Credential-domain separation and bare-CLI behavior are supported. Lifecycle controls remain aggregated, and mint/installation verification is unexecuted and incompletely specified.

  M8 — PARTIAL
    Unit tests and scan-scope behavior reproduce. Exact deletion targets, unconditional-cache behavior, dry-run accounting, metrics and contract closure remain incomplete.

  M9 — PARTIAL
    The settlement mismatch and selected defaults are source-backed. Admission composition, durable execution state, operator surfaces, settings and log inventory are not yet a buildable subsystem specification.

  M10 — PARTIAL
    Guard degradation and default-on metrics are supported by code. Custody semantics, individual settings, metric contracts, client coverage and repeatable signed-read verification remain incomplete.

  M11 — PARTIAL
    Ledger ordering and serial execution are substantially documented, but the deadline descendant-termination assurance is contradicted by both the generated runner and an independent disposable execution.

  M12 — PARTIAL
    Hash and live no-token refusal reproduce. The recorded sink paths are wrong; the node-client contract is unproven. An independent healthy-stream fixture confirms forwarded bytes followed by an EOF timeout, so streaming completion remains defective.

  No chapter qualifies as WRITTEN. All 13 are PARTIAL, not SKELETON: each contains substantive source-backed work, but each retains required unresolved fields or the findings above.

  Reproducible review probes:
    /home/kara/.hermes/cache/scratch/round5_independent_probes.py
    /home/kara/.hermes/cache/scratch/round5_verifier_probe.py

PANEL REVIEW COMPLETE

session_id: local-4a8989dd28595c194bf17d87081ccbd4553853a009e3a37f1d3b0918c501a198

EXIT=0
```

