# CORRECTIONS — round 6

Generated 2026-11-06T18:50:30-0500.

## Verdicts

- **deepseek** — FAIL, blocking 3, 9899 bytes, complete=True
- **glm** — FAIL, blocking 6, 9905 bytes, complete=True
- **grok** — FAIL, blocking 10, 18653 bytes, complete=True
- **kimi** — MISSING, blocking 0, 376 bytes, complete=False
- **sol** — FAIL, blocking 26, 35203 bytes, complete=True

## Verdict text (verbatim, per seat)

### deepseek

```
I've read all 13 chapters, the outline, and the schema, and independently verified the load-bearing claims against the code. Every spot-check I ran (revisions, `lib.sh` helpers, `text_b64`/`text` and `status`/`ok` mismatches, the `configure_family.py` PID hardcode, the `[0-9][0-9]-*.md` glob, the inference-proxy sinks, `dispatchReplyVerdict`, the `board` field, the 30-table store, metrics default-ON) came back accurate. Here is the verdict.

---

VERDICT: FAIL

BLOCKING: 3 — findings that must be fixed before this handbook can be called written

NON-BLOCKING: 4

FINDINGS:

1. kind UNBUILDABLE — M6 (§1, §11, F6-1). Claim quoted: "The fill/render/panel pipeline is UNBUILDABLE against these M-numbered chapters ... master_doc_check.py:188, gen_nasa_handbook.py:253-260 and master_doc_fill.py:422 all select [0-9][0-9]-*.md, which does not match M0-…-*.md". Evidence: verified live — `scripts/master_doc_check.py:188` globs `[0-9][0-9]-*.md`; the only chapter filenames present are `M0-…` through `M12-…`. The document's own acceptance gate (OUTLINE VII.3, enforced by `master_doc_check.py`) cannot select a single one of the 13 chapters it must grade, the filler cannot fill them, and `gen_nasa_handbook.py:18` hardcodes `REPO/"docs/master"` (deleted) so the renderer refuses an empty selection. The handbook cannot be delivered by the pipeline the handbook describes. Fix: change the three selectors to match the `M*.md` set (or rename the chapters to the `NN-*.md` scheme the tooling expects), re-run `master_doc_check.py` over the real chapters, and record the gate's live verdict rather than the writer's own stamp.

2. kind CONTRADICTION — OUTLINE Part IV vs chapters M2/M3/M10/M11/M12. Claim quoted: "Current: 0 of 18 name both implementations" and Part I.5 "18 interfaces, measured state (10 works, 6 broken, 2 missing)". Evidence: M2 §6 names both sides of M2-C1/M2-C2 (`node-bus-worker.py:986`/`:1128` vs `dispatch.go:202`/`dispatch_leg.go:713`); M3 §6 names both sides of M3-C1/M3-C2; M10 §6 names both sides of M10-C1/C2/C3; M11 §6 names both sides of M11-C1/C2; M12 §6 names the proxy side and proves the node-client half is config-wired. "0 of 18" is therefore factually stale, and the 10/6/2 split is superseded in-chapter (M10 §6 explicitly supersedes README I.3's "10 works / 6 broken / 2 missing") — but the OUTLINE's own summary lines are not updated in the same issue. Fix: update OUTLINE Part I.5 and the Part IV count line to the measured states in the chapters, or mark them superseded in-place as was done for the two annotated rows.

3. kind OMISSION (systemic, honestly surfaced) — M2, M3, M4, M5, M6, M7, M8, M11, M12, M1, M0 (11 of 13 chapters). Claim quoted: "RED — none (absence-proved this round)" in every Metrics §8 except M9 and M10. Evidence: verified greps return 0 metric emitters across the node-side dispatch, landing, board, harness, github, safety, docs, proxy and dispatcher modules. The schema's own rule grades "none" RED because "a module on the critical path with no metrics cannot be observed." The two primary-flow contracts CF-354 (`text_b64` sent / `text` read) and CF-355 (`status` sent / `ok` read, absence = success) are additionally broken-and-verified live — so F1 DISPATCH AND SETTLEMENT is non-functional for node-dispatched work as documented. These are not fabrications (the doc reports them accurately); they are still open and still block the outline's definition of done (measured contract states, observed critical path). Fix: add metrics to the node-side critical path, and land CF-354/CF-355 — or have the owner explicitly accept the RED surface and the broken primary flow in a recorded decision.

NON-BLOCKING findings:

4. kind UNVERIFIED — M1 §7, M3 §7, M5 §7, M7 §7. Live-node verification not repeatable from this control host (certification ladder, landing dry-run, conformance battery, token mint all require a live node or absent App creds). Correctly stated with the reason; the honest UNVERIFIED word is present, so no admission-rule violation — but the "measured state" the outline requires is still not demonstrated for these legs.

5. kind UNVERIFIED — M9 §9. Log inventory covers 2 of 379 `log.Printf` sites (settlement/batch-dispatch only); the remaining 377 are named RED, not claimed complete. Honest, but the §9 field is substantively unwritten for the largest control-plane module. Same class: M9 §5 leaves the 32 auxiliary flags' consequence column unexpanded (named RED), and M9 §3 S1 is grep-level not line-by-line.

6. kind PARTIAL — M5 §2/F5-2. `harness_resolve.py` has no production caller (verified: `grep -rln harness_resolve scripts/` returns self + tests only); runtime selection is `node-bus-worker.py:407-409,459-469` / `dispatcher.py:260`. The chapter corrects round-2's "runtime authority" claim, but this means OUTLINE M5.S4 documents an optional facility, not a wired component — the classification now says "optional" while the outline lists it as a submodule of a node-side system.

7. kind revision-drift — all 11 code-factory chapters stamp `943ef98`; code-factory HEAD is now `48ae2c9` (one commit: "panel_loop: the defect-class parser admitted fragments and disabled stop condition 2"). `943ef98` is a verified ancestor of HEAD, so the stamp is internally consistent, but the issue is one commit stale on the very repo that owns the panel loop.

DEFECT CLASSES:

- unbuildable-delivery
- stale-register-counts
- metrics-absent (systemic)
- broken-primary-contracts (CF-354 / CF-355)
- unverified-contracts (external peers, wire not re-run)
- partial-read (grep-level bodies, named RED)
- revision-drift

Notably absent from this round: FALSE CLAIM (zero found across ~15 independent spot-checks of the highest-stakes citations) and PADDING (no prose found that a reader cannot act on).

CHAPTER SCORECARD:

- M0 SHARED CONTRACT — WRITTEN. `lib.sh` read in full, every helper located and verified (`say` :5, `ok/bad/warn/note` :6-9, `have` :13 with the empty-success trap, `fetch_verified` :19, `require_disk` :48, `once` :60 no-flock, `shq` :67, `bunker_exec` :75). Reproduced `fetch_verified` fail-closed probe. 1 RED (metrics).
- M1 PROVISIONING — WRITTEN. Provisioner/verify/seeder state machines read; F1-1 "mode 600" lie verified against the real `[ -s … ]` probe; floor precedence and seed preserve/force semantics located. 3 RED (4 file bodies at settings-surface only, ladder not run live, metrics).
- M2 DISPATCH (NODE SIDE) — WRITTEN. Contracts VERIFIED; `text` read at :986 and `status` reply at :1132 confirmed; CF-354/CF-355 correctly attributed. 2 RED (metrics, live ladder).
- M3 REPOSITORY — WRITTEN (source) / PARTIAL (behavioral). Landed, hook, and clone files read in full; F3-2 (clone_lane clones a lane row, not a repo) is a real, correctly-flagged surprise; behavioral landing dry-run UNVERIFIED for want of a clean fixture.
- M4 BOARD — WRITTEN. Store measured (357/515/0), drift honestly re-measured as DRIFT not PASS, lock classifier's 3-outcome `adjudicate` read. 3 RED (metrics, UNVERIFIED external contracts, moving-target drift).
- M5 HARNESS — PARTIAL. `harness-vars.sh` register accurate (12/6 var split verified); CF_* validation and per-adapter pins located; but two installer bodies unread line-by-line, conformance UNVERIFIED, and F5-2 (resolver has no production caller) leaves S4 half-documented.
- M6 DOCUMENTATION — PARTIAL / UNBUILDABLE. Gate read in full and its FAIL reproduced; the `[0-9][0-9]-*.md` selector is the blocking UNBUILDABLE finding above.
- M7 GITHUB — WRITTEN (settings) / PARTIAL (mint). Credential-lifecycle register is thorough and the F7-3 correction (scoped token from `fleet-gh-scope.py`, not M7) is verified; mint UNVERIFIED for want of App creds.
- M8 SAFETY — WRITTEN. Both files read in full; `AGED_PARENTS` (.node/jobs, .node/clones) verified so F8-3 (dispatcher `.cf-jobs` unreaped) is real. 1 RED (metrics).
- M9 SCHEDULER — PARTIAL. Settlement/verdict, admission authority, binary defaults, auth, and route table read; clean-env `go test` PASS verified (25/25); but S1 grep-level, log inventory 2/379, 32 auxiliary flags without consequence, per-route contract unwritten (5 RED).
- M10 CRIER — WRITTEN. Build/test PASS, 91 registry test files measured, 3/3 slog sites, metrics default-ON corrected and verified against `config.go:673`. 2 RED (handler body not line-by-line; metric register names-only).
- M11 DISPATCHER — WRITTEN. Full 538-line read, all 23 log sites inventoried; F11-8 (kill targets run.sh's group, not GNU-timeout's group holding the harness) is a serious verified defect the doc correctly withdraws. 2 RED (metrics, decoration tests).
- M12 INFERENCE PROXY — WRITTEN. Full read, content hash reproduced, live 401 reproduced, systemd unit active; F12-8 sink-filename correction verified against :50/:52. 3 RED (metrics, node-client half UNVERIFIED, F12-7 healthy-stream not framed).

Summary: the document is accurate and honest — no fabricated claims found, every load-bearing citation I checked against the code was correct, and RED/UNVERIFIED are used where the truth is incomplete rather than papered over. What keeps it from PASS is structural, not factual: the delivery pipeline and its gate cannot select or grade these chapters (UNBUILDABLE), the outline's contract-register counts are stale against the chapters (CONTRADICTION), and the outline's completion bar — measured contract states and an observable critical path — is not met (OMISSION, 11/13 metrics RED plus two broken primary contracts). The fixes are bounded and specific; one more round with the three selectors corrected, the OUTLINE counts reconciled, and the RED surface either filled or owner-accepted would clear it.

PANEL REVIEW COMPLETE

session_id: local-d19caa2bd5d824601ee86a028f9032c1d6edc1980d862a04036486c73be9dfa0

EXIT=0
```

### glm

```
All verification complete. I independently re-checked ~70 load-bearing claims across the 13 chapters against the five codebases, re-ran the chapters' own verification commands (builds, tests, greps, live probes), and found the document's evidence layer to be exact. Full verdict:

═══════════════════════════════════════════════════════════

VERDICT: FAIL

BLOCKING: 6 — findings that must be fixed before the affected chapters can be called WRITTEN and this document issue can be certified

NON-BLOCKING: 7

JUDGE'S VERIFICATION BASIS (what I repeated myself): ~70 claim spot-checks across M0–M12 in all five codebases; scheduler `go build` PASS + the 3 env-sensitive tests PASS at rev 1771d3aa; crier config defaults, handler locators (:598/:613/:990/:1690/:1812), slog count = 3, metric census = 67 all exact; dispatcher settings/kill-template/replay-ordering/25-line log census exact; proxy sha256 match, live 401 reproduced, systemd active; board census 357/515 and `validate` OK (7 warnings) reproduced; master_doc_check FAIL rc 1 reproduced; lib.sh sourcing counts 11/17 reproduced. ZERO FALSE CLAIMS found; every file:line locator I checked was exact.

FINDINGS:

BLOCKING

1. UNBUILDABLE — M6. Claim: "no chapter-aware path exists from source selection to delivered artifact" (§1). Evidence: `master_doc_check.py:188`, `gen_nasa_handbook.py:18,253-259`, `master_doc_fill.py:26,422` all select `[0-9][0-9]-*.md` only; my re-run of the gate returns `44 module(s): 37 VERIFIED, 50 error(s)` → `MASTER-DOC: FAIL`, rc 1, and selects none of the 13 M*.md chapters. The handbook's own delivery mechanism cannot gate, fill, or render this document. Fix: chapter-aware selection (or re-point DEFAULT_ROOTS) plus re-pointing the 50 stale unit locators; the gate must select these chapters before the issue is certifiable.

2. NAME ONLY — M9. Claim: auxiliary register "Remaining 32 of the 57 … consequence is scoped, not expanded per row" (§5). Evidence: 57 flag definitions reproduced; by the outline's own heading-5 decision rule (default + range + one consequence, else unwritten) 32 rows are names with defaults but no consequence. The chapter declares this RED rather than hiding it — it is still an unwritten register for the majority of the daemon's flag surface. Fix: expand per-row consequences or split the register across S4 sub-sections.

3. OMISSION — M9. Claim: §9 log inventory = 2 of 379 sites, "the remaining 377 are the named RED". Evidence: `grep -rn "log.Printf" internal/scheduler/*.go | wc -l` = 379 (reproduced). Schema §6 requires every operator-visible line verbatim; a 0.5%-filled field is a stub with an honest label. Fix: inventory the operator-actionable subset with a named boundary and count, per submodule.

4. NAME ONLY — M10. Claim: §8 "series names are inventoried, but the full per-metric type/labels/question/scrape table is a named RED". Evidence: census reproduced (67 unique `crier_*` strings); no per-metric table exists. Schema §5 requires the table per metric; the bus is the fleet's critical path and its metrics field is unfilled. Fix: fill the runtime-series table (guard at `internal/guard/metrics.go:22-49`, inbox at `handler.go:38-45`, capability at `capability.go:99-105` at minimum).

5. UNVERIFIED — M1. Claim: status "UNVERIFIED (bodies)" — `node_env.py` (589), `node_seed_drift.py` (558), `node_freshness.py` (732), `bunker_config_gen.py` (724) read at settings-surface only; `node_gateway_auth.py` unread; certification ladder not run on a live node. These units ARE the F2 certification legs; a provisioning chapter whose proving legs are unread-and-unrun cannot be WRITTEN. (The two measured lies — F1-1 mode-600 claim at `:214/:233`, F1-5 checkout/seed asymmetry at `:150` vs `:194-198` — I verified against the code and they are real.) Fix: line-by-line reads or one dated live ladder run.

6. UNVERIFIED — document-wide. Claim: all 13 chapters stamp revision `943ef984…` as "code-factory HEAD, 2026-11-06". Evidence: measured at judging time HEAD = `48ae2c9`, `origin/main` = `5b11bdc`, and `board_drift` now returns `RESULT: DRIFT (6 failed)` with 2 divergent ids (CF-051, CF-303) and HEAD NOT an ancestor — M4 §7's quoted "DRIFT (4 failed) … ancestor … 1 divergent id" no longer reproduces. Schema: one revision per document issue; a stale check row is UNVERIFIED. The mechanism is pre-disclosed (M4 B3/F4-4 mandates re-running after the carrying merge) — the fix is procedural: re-stamp and re-run the drift/census rows in the publish merge.

NON-BLOCKING

1. UNVERIFIED — M2. The bus-worker ladder "PASS (FACT-04)" is cf-node-only and not repeatable from the control host (chapter says so). Fix: archive the cf-node transcript as a cited artifact.

2. UNVERIFIED — M3. No clean-worktree/bare-remote fixture ships, so the landing dry-run refusal stands in for behavioral proof (B10); `repo_freshness.py` body unread. Fix: ship the disposable fixture — small and buildable.

3. UNVERIFIED — M5. Conformance battery not run this round (needs a live node); `install-codex.sh`/`install-claude-code.sh` bodies partially read. Fix: one dated live run. (F5-5's computed-call-site correction verified real at `project-node.sh:440,449-452`.)

4. UNVERIFIED — M7. Token mint never executed (no App credentials on this host). Fix: one run on the credentialed host, or name the operator who can run it.

5. UNVERIFIED — M11. The live-job tests cannot fail — reproduced: `tests/test_durable_job.py` contains zero assert/raise/exit — so §7 has no behavioral oracle, and the F11-8 kill-guarantee (kill reaches run.sh's group, not GNU timeout's group holding the harness — the `:246-249` comment and `:329` kill line confirm the premise) is withdrawn pending a falsifiable test. Fix: make the tests assert.

6. UNVERIFIED — M12. Node-client half of M12-C1 is config-wired but unproven; F12-7 healthy-stream framing unverified. Fix: a framing test plus one node-side capture row. (The F12-8 path correction verified: `:50`/`:52` are the real sinks.)

7. CONTRADICTION — OUTLINE ↔ chapters (filed against M2/M9/M10). OUTLINE Part IV still says the node reply carries `run_id`/`outcome` (M2 §6 measures `status, dispatch_id, …` at `node-bus-worker.py:1128-1144` — verified) and the envelope field `board_row` (`internal/bus/dispatch.go:184` emits `board` — verified); OUTLINE M9.S3 says "26 tables … verdicts" (measured: 30 tables, no `verdicts`). The chapters supersede with measurements; the outline itself is not folded back. Fix: outline v5 fold-back.

DEFECT CLASSES: self-declared-RED registers (NAME ONLY); honest coverage margins (UNVERIFIED bodies/ladders); stale-revision moving-target; missing falsifiable fixtures; no chapter-aware delivery gate (UNBUILDABLE); outline fold-back debt; decoration tests that cannot fail.

CHAPTER SCORECARD (convention: an absence-proved "metrics: none" is a filed system defect, not prose unwrittenness):

- M0 — WRITTEN. Every helper, line number, and count independently reproduced (11/17 sourcing greps, all log lines, `--max-time` at :22, helper table exact). Only RED is metrics=none, absence-proved.
- M1 — PARTIAL. Two verified lies (F1-1, F1-5) and exact locators, but four certification-leg bodies are settings-surface only and the ladder never ran (blocking 5).
- M2 — PARTIAL. node-bus-worker contracts verified to the line (CF-354 at :986 vs dispatch.go:202; CF-355 at :1128 vs dispatch_leg.go:713-726 — both reproduced in code); S1 trio structure-mapped only; live ladder not repeatable here.
- M3 — PARTIAL. Source read in full; F3-2 (lane-row clone), F3-3 (no default gate), F3-5 (no invoker) all verified; behavioral verification unproven (no fixture).
- M4 — PARTIAL. Store measurements reproduced exactly (357/515, OK with 7 warnings); `boardctl --help:25` verified against the external binary's help; external contracts honestly UNVERIFIED; drift row superseded by movement (blocking 6).
- M5 — PARTIAL. CF_* register complete and verified against harness-vars.sh (:203/:204 predicate-vs-message mismatch confirmed); conformance legs unrun; M5-C2 a port, not a file:function.
- M6 — PARTIAL. Gate internals verified and honestly FAILING; the module cannot deliver this document (blocking 1).
- M7 — PARTIAL. Lifecycle register complete (MIN_AGE 2400, mode-0600 refusals, POST route all verified); mint unrun.
- M8 — WRITTEN. Both units read in full; `tests/test_reclaim.py` and `tests/test_disk_floor.py` re-run by this judge: OK, rc 0; constants and TTL-inclusive boundary exact.
- M9 — PARTIAL. Settlement, admission authority, 57-flag surface, 30 tables, 10 LoadRootConfig sites all verified exact; five named REDs (aux flags, log 2/379, grep-level S1, per-route contract, store write-authorities).
- M10 — PARTIAL. Config defaults, handler locators, guard degradation, signed-read ladder, slog=3 and census=67 all verified exactly; per-metric table unfilled (blocking 4); handler body residue.
- M11 — PARTIAL. Full read verified (25 log lines, replay ordering at :470-483, kill template, task_seconds floor); no failing-capable check exists.
- M12 — PARTIAL. Full read, hash match, live 401 and systemd status all reproduced by this judge; client half and stream framing unproven.

BALANCE: this is a FAIL on completeness, not on truth — an adversarial re-verification of ~70 claims found zero false claims and zero wrong locators, which no prior round achieved. The distance to PASS is: one chapter-aware gate path (M6), two register fills (M9 aux flags, M9/M10 log+metric fields), one read-or-run pass (M1 bodies/ladder), and a re-stamp at publish.

PANEL REVIEW COMPLETE

session_id: local-3560cf131113777552a10eefcd4be1e2e5bd103565f39665842320b653c6b3b3

EXIT=0
```

### grok

```
⚠️  Primary auth failed — switching to fallback: fireworks / accounts/fireworks/models/deepseek-v4p1-flash-1017
│ cache/scratch/locator_check.py
│ @@ -0,0 +1,58 @@
│ +#!/usr/bin/env python3
│ +"""Check every file:line citation in the round-6 handbook chapters against the code."""
│ +import os, re, sys, collections
│ +
│ +ROOTS = [
│ +    "/home/kara/code-factory",
│ +    "/home/kara/coding-hermes-scheduler/coding-herms-scheduler",
│ +    "/home/kara/crier",
│ +    "/home/kara/crier-fleet",
│ +    "/home/kara/.hermes/scripts",
│ +]
│ +CH = "/home/kara/code-factory/docs/handbook/chapters"
│ +
│ +# index: basename -> [paths]
│ +index = collections.defaultdict(list)
│ +for root in ROOTS:
│ +    for dirpath, dirnames, filenames in os.walk(root):
│ +        dirnames[:] = [d for d in dirnames if d not in (".git", "node_modules", "__pycache__", ".venv", "venv", "dist")]
│ +        for f in filenames:
│ +            index[f].append(os.path.join(dirpath, f))
│ +
│ +CIT = re.compile(r"([A-Za-z0-9_][A-Za-z0-9_./\-]*\.(?:py|sh|go|md|toml|json|ya?ml|txt|jsonl|ts|db)):(\d+)(?:-(\d+))?")
│ +
│ +bad = []
│ +stats = collections.Counter()
│ +for name in sorted(os.listdir(CH)):
│ +    if not name.endswith(".md"):
│ +        continue
│ +    path = os.path.join(CH, name)
│ +    for lineno, line in enumerate(open(path, encoding="utf-8", errors="replace"), 1):
│ +        for m in CIT.finditer(line):
│ +            ref, a, b = m.group(1), int(m.group(2)), m.group(3)
│ +            base = os.path.basename(ref)
│ +            cands = index.get(base) or []
│ +            if not cands:
│ +                bad.append((name, lineno, ref, a, "NO SUCH FILE ON DISK"))
│ +                continue
│ +            # pick the candidate that has enough lines
│ +            ok = False
│ +            maxtot = 0
│ +            for c in cands:
│ +                try:
│ +                    tot = sum(1 for _ in open(c, "rb"))
│ +                except OSError:
│ +                    continue
│ +                maxtot = max(maxtot, tot)
│ +                hi = int(b) if b else a
│ +                if a >= 1 and hi <= tot:
│ +                    ok = True
│ +                    break
│ +            if not ok:
│ +                bad.append((name, lineno, ref, a, "OUT OF RANGE (candidates=%d max_lines=%d)" % (len(cands), maxtot)))
│ +            stats["refs"] += 1
│ +
│ +print("citations checked:", stats["refs"])
│ +print("suspect:", len(bad))
│ +for row in bad:
│ +    print("%s:%d  %s:%d  -> %s" % (row[0], row[1], row[2], row[3], row[4]))
│ cache/scratch/route_census.py
│ @@ -0,0 +1,17 @@
│ +#!/usr/bin/env python3
│ +import re, sys
│ +src = open("/home/kara/coding-hermes-scheduler/coding-herms-scheduler/internal/api/server.go").read().splitlines()
│ +start = next(i for i, l in enumerate(src) if "func (s *Server) Handler()" in l)
│ +routes = []
│ +for l in src[start:]:
│ +    for m in re.finditer(r'mux\.HandleFunc\("([^"]+)"', l):
│ +        routes.append(m.group(1))
│ +    if "return " in l and routes and "Handler" not in l and l.strip().startswith("return"):
│ +        break
│ +uniq = sorted(set(routes))
│ +print("registered routes in Handler():", len(uniq))
│ +chap = open("/home/kara/code-factory/docs/handbook/chapters/M9-scheduler.md").read()
│ +missing = [r for r in uniq if r.replace("/api/v1", "") not in chap and r not in chap]
│ +print("routes NOT named in the chapter:", len(missing))
│ +for r in missing:
│ +    print("   ", r)
VERDICT: FAIL
BLOCKING: 10 — findings that must be fixed before these chapters can be called written
NON-BLOCKING: 6

SCOPE OF THIS SEAT
  All 13 chapters in docs/handbook/chapters/ (2,816 lines) read in full against
  code-factory, the scheduler repo (rev 1771d3aa), crier (691f0c78), crier-fleet
  (283bca9) and cf-inference-proxy.py. 274 file:line citations machine-checked
  (script: /home/kara/.hermes/cache/scratch/locator_check.py — 272 resolve, 2 do
  not); ~70 claims then opened at the cited line and read. Commands I re-ran
  myself and whose output I quote below: git log/diff, go build/test, go version,
  sqlite3 .tables, boardctl validate/create, board_drift, jq/wc censuses, the
  M0 ffc_probe, the 401 admission probe, unittest batteries. Not repeatable from
  this seat: the cf-node bus-worker ladder (M2 §7, M10 §7) and the certification
  ladder (M1 §7) need a live node; the M9 full `go test ./...` (~500-1100 s) I
  ran only the three named env-sensitive tests for; the GitHub mint (M7) has no
  App credentials on this host. Those are marked below, not silently passed.

FINDINGS

1. FALSE CLAIM — M4 BOARD (§1 Status, §7 row 3, §13 F4-4)
   Claim: "board_drift returns RESULT: DRIFT (4 failed) because origin/main
   advanced 3 commits past HEAD … 357 vs 357 rows with 1 divergent id (CF-051);
   HEAD=943ef98 is an ancestor of origin/main=6bb3ac8".
   Evidence: I ran the chapter's own command —
     python3 scripts/board_drift.py check --workdir /home/kara/code-factory --ref origin/main
     → FAIL byte parity tasks.jsonl; FAIL byte parity events.jsonl;
       FAIL board status — CF-051 workdir=pending published=complete;
       FAIL board status — CF-303 workdir=pending published=complete;
       "FAIL board rows — 357 vs 357 rows; 2 divergent ids: CF-051,CF-303";
       "FAIL HEAD ancestry — HEAD=48ae2c9 origin/main=5b11bdc; not an ancestor";
       RESULT: DRIFT (6 failed)
   The status word is right; every number under it is wrong (4→6 failures,
   1→2 divergent ids) and the ancestry direction is inverted (ancestor → not an
   ancestor). Fix: paste this run verbatim with its date, drop the "is an
   ancestor" inference, and re-run at merge time as §7 already instructs.
   (The chapter's own "drift is a moving target" caveat is correct but does not
   license a stale row: this is the module's headline status evidence.)

2. FALSE CLAIM — M9 §1 and M10 §1/F10-2 (shared environment fact), with a
   derived buildability claim in M9 §4a
   Claim: "host `go version` = go1.26.5 (default PATH /home/kara/.local/bin/go)";
   M9 §4a: "with GOTOOLCHAIN=local the 1.26.5 host would be below the toolchain
   directive".
   Evidence: `/home/kara/.local/bin/go -> go version go1.26.6 linux/amd64`;
   `go env GOVERSION` → go1.26.6; `/usr/bin/go` 1.26.8 and `/snap/bin/go` 1.27.1
   are as stated. `GOTOOLCHAIN=local go build ./...` in
   coding-hermes-scheduler → rc 0 (not a refusal). Fix: re-measure the host
   toolchain and state the local-build result as measured; the crier half of the
   same sentence (go.mod go 1.26.10, auto-fetch required) does hold.

3. OMISSION — M9 §3 "Operator surfaces (B18)"
   Claim: "the route inventory is [written]" and "The daemon mounts its HTTP
   routes in internal/api/server.go:289-346", followed by an enumeration.
   Evidence: `internal/api/server.go` registers 43 routes in Handler(); the
   chapter names 33. Missing: /api/v1/hooks/reload (server.go:300 — inside the
   cited range), /features, /features/prune-candidates, /peers, /peers/,
   /agents, /agents/, /federation/query, /federation/catalogue,
   /cooldown/residue. Fix: enumerate all 43, or rescope the sentence to "read
   surfaces, 25 of 43" and name the remainder as RED like §9 does for logs.

4. OMISSION — settings registers, 13 of 13 chapters
   Claim (representative, M9 §5): the register gives "Default | Range | Governs |
   What breaks if changed".
   Evidence: OUTLINE §5 requires "default, valid range, what it governs, what
   breaks if changed, who reads it". No settings table in any chapter carries a
   reader. `grep -l 'who reads|Read by' chapters/*.md` → 0 files. The gap is
   document-wide and mechanical to close (argparse/flag/getenv read site gives
   the file:line). Fix: add a "read by (file:function)" column per row.

5. OMISSION — submodule inventory, 13 of 13 chapters
   Claim (representative, M2 §3): table columns "Submodule | Unit |
   Classification | Evidence (invoking line)".
   Evidence: OUTLINE §3 requires per submodule "responsibility, owner,
   invocation, execution location, producer/consumer links, and classification".
   Four of the six required fields are absent in every chapter. Fix: add the
   columns, or mark each absent field RED per row (the schema's §1 rule for an
   empty field: the empty field is the finding).

6. CONTRADICTION — structure maps (M1, M2, M3, M4, M6, M7, M8, M9–M12)
   Claim: OUTLINE "13 modules, 47 submodules"; the chapters enumerate 47; M1
   cites "docs/UNIT-MAP.yaml:26-77 (M1 S1–S5)", M2 ":78-102", M4 ":122-138",
   M7 ":208-220", M8 ":222-236".
   Evidence: docs/UNIT-MAP.yaml records 9 modules and 25 submodules — M3 has
   S1–S2 only (no S3), M6 has S1–S6 (no S7/S8), and M9/M10/M11/M12 are absent
   entirely (`grep -n 'id: M' docs/UNIT-MAP.yaml` ends at M8.S2). Only M5
   discloses its own disagreement (F5-4). Chapters M3/M6/M9–M12 cite no map at
   all, so the drift is invisible where it is largest. Fix: extend UNIT-MAP or
   state the disagreement once for the document and repeat M5's disclosure
   pattern in M3/M6/M9–M12.

7. CONTRADICTION — M10-C2 vs M2-C1/M9-C2 (same contract, opposite state words)
   Claim, M10-C2: "HandleRetrieve (lease); client side crier_client.py:1009
   retrieve → scripts/node-bus-worker.py:972 process (the node's inbox consumer;
   reads text at :986) | works".
   Counter-claim, M2-C1: same consumer "node-bus-worker.py:986 reads
   dispatch.get("text")" → "broken — CF-354: the node reads text, the scheduler
   sends text_b64".
   Evidence: both citations are correct (node-bus-worker.py:986, bus/dispatch.go:202);
   therefore the pair cannot be both "works" and "broken" as printed. The
   README's re-scope note reconciles the OUTLINE, not these two rows. Fix:
   M10-C2 = "works (lease/transport); consumption broken — see M2-C1/CF-354".

8. OMISSION (NAME ONLY) — M9 §5
   Claim: "Remaining 32 of the 57 … name = default; consequence is scoped, not
   expanded per row … which is a named RED on the register".
   Evidence: OUTLINE §5 decision rule — "a name has no consequence is NAME ONLY
   and counts as unwritten". The 57-flag count is right
   (`grep -cE 'flag\.(String|Int|Int64|Bool|Duration|Float64)' cmd/schedulerd/main.go`
   = 57), so 32 rows are unwritten by the outline's own rule. Disclosing a RED
   field is honest but does not fill it. Fix: expand consequence per row, or
   move the 32 into an explicitly-out-of-scope list with the reason.

9. OMISSION — M9 §9
   Claim: "The control plane has 379 log.Printf call sites … the remaining 377
   sites are uncovered and are the named RED on this field".
   Evidence: 379 confirmed (`grep -rn "log.Printf" internal/scheduler/*.go | wc -l`).
   OUTLINE §9 requires every operator-visible line, verbatim, classified. 2 of
   379 is 0.5% coverage of a field the outline treats as mandatory. Fix: either
   generate the inventory mechanically (`grep -n` + level + trigger) or split the
   field: the settlement surface (written) + a mechanical appendix (to write).

10. OMISSION — M10 §8
   Claim: "the series names are inventoried, but the full per-metric
   type/labels/question/scrape table is a named RED on this field".
   Evidence: 67-string census confirmed; OUTLINE §8 requires type, labels, the
   question answered, where scraped, per metric. The inventory is a name list.
   Fix: fill the table for the runtime series (the emitters are already located:
   guard/metrics.go:22-49, handler.go:38-45, capability.go:99-105).

NON-BLOCKING FINDINGS

A. LOCATOR OFF-BY-ONE — M5 §9: "surfaced by print(f"FAIL {exc}") at :389".
   Evidence: harness_resolve.py:388 is the print; :389 is `return 2`.
   Fix: cite :388.
B. MIS-ATTRIBUTED LOCATOR — M5 §3: "the harness adapter :440/:449-452; other
   units (`disk_floor.py:173`, `reclaim_disk.py:212`)". reclaim_disk.py is 169
   lines; 212 is project-node.sh:212. Fix: "project-node.sh:173, :212".
C. ONE-SIDED CONTRACT WITH A VERDICT — M9-C3 producer cell reads only
   "completion reply" (no file:function) yet the state is "broken". M10-C3 names
   both sides (node-bus-worker.py:1160 deliver → dispatch_leg.go:713). Rule 2
   makes that row a rumour. Fix: point M9-C3 at M10-C3's producer or demote the
   state to "rumour (producer named in M10-C3)".
D. PADDING (mild) — M6 §2: "What breaks if this module is absent. The system
   cannot describe itself, and no one can check the description." Names nothing
   observable; the schema asks what fails, not a restatement. Fix: name the
   concrete failure (the gate's empty-selection PASS, which the same chapter
   documents at :191-209).
E. STALE "HEAD" LABEL — all 11 code-factory chapters: "Revision
   943ef984dc093e5780605ac6e54cd043122126ef (code-factory HEAD, 2026-11-06)".
   Evidence: HEAD is now 48ae2c9 (one commit later, panel_loop fix). The stamp
   is still the correct derivation revision; only the words "code-factory HEAD"
   are false. Fix: "at derivation" instead of "HEAD".
F. COMPOUND STATUS FIELD — M4 §1: "Status | VERIFIED at store level … board
   parity is now DRIFT". MASTER-DOC-SCHEMA §1 allows VERIFIED / UNVERIFIED /
   FAILING only. Fix: one word (VERIFIED for the store, FAILING for parity) with
   the detail in prose.

DEFECT CLASSES
  stale-measurement · environment-fact-drift · inventory-claimed-complete ·
  missing-required-field (document-wide) · structure-map-drift ·
  cross-chapter-state-disagreement · self-declared-RED-left-unfilled ·
  locator-off-by-one · external-peer-rumour · stale-status-label

CHAPTER SCORECARD
  M0  SHARED CONTRACT      PARTIAL — lib.sh read end-to-end, all 9 helpers, 11/17
                           source counts and the ffc probe reproduce (rc=1,
                           artifact=no); only the Metrics RED and a one-sided
                           bunker contract remain.
  M1  PROVISIONING         PARTIAL — strongest chapter of the set; F1-1, F1-2,
                           F1-4 and the B05 false-green asymmetry (verify-node.sh
                           :150 warn vs :198 unverified) all reproduce. Held back
                           by five unread bodies (node_env, node_seed_drift,
                           node_freshness, bunker_config_gen, node_gateway_auth)
                           and an unrun live ladder.
  M2  DISPATCH (NODE)      PARTIAL — every claim I opened reproduced (:80-114
                           constants, :986 text read, :1128-1144 reply fields,
                           :1152-1157 dispatch_wall, same-batch idempotency at
                           :1304-1347). S1 trio structure-mapped only; metrics RED.
  M3  REPOSITORY           PARTIAL — source read and citations right (295/180/130
                           lines, GATE="" at :36, gate at :171-193, proof at
                           :265-287); behavioural status honestly UNVERIFIED with
                           no clean fixture; UNIT-MAP S3 gap undisclosed.
  M4  BOARD                PARTIAL — counts (357/515), validate (7 warnings,
                           named exactly) and lock classifier reproduce; the
                           drift row is the round's clearest false claim (finding 1).
  M5  HARNESS              PARTIAL — pins, python gate, CF_* bounds and the
                           F0-6 predicate (mode [0-7]00 vs "must be 600") all
                           verified; two locator slips (A, B); conformance unrun.
  M6  DOCUMENTATION        PARTIAL — gate output reproduces exactly (44 modules,
                           37 VERIFIED, 50 errors, MASTER-DOC: FAIL), and the
                           chapter correctly refuses to call its own gate a truth
                           verifier. Its B13/B15 finding is load-bearing for the
                           whole document: no renderer or gate selects M*.md, so
                           nothing in this set can be built or gated by the
                           project's own pipeline. PADDING in §2.
  M7  GITHUB               PARTIAL — CLI exit 2, refresh controls (MIN_AGE 2400,
                           dry-run at :106, mode gate at :127-130) verified; the
                           mint itself is unrun and says so.
  M8  SAFETY               PARTIAL — both units read in full, 9 reclaim tests
                           pass, scan-scope returns 15 claims/OK; only Metrics
                           RED stands between it and WRITTEN.
  M9  SCHEDULER            PARTIAL — defaults (30s/10/false), 57 flags, 379 log
                           sites, 30 tables, LoadRootConfig ×10 and the CF-355
                           silent-success reading all verified; failed by the
                           route inventory (finding 3), name-only flags (8) and
                           2/379 log coverage (9).
  M10 CRIER                PARTIAL — 91 test files, 1895 lines, 3/3 slog sites,
                           67 metric strings, retrieve aliases/caps and the
                           default-ON metrics contradiction all verified; one
                           contradictory state word (finding 7) and an unfilled
                           metric contract (10).
  M11 DISPATCHER           PARTIAL — 538 lines, 23 call sites, the B01 kill-group
                           analysis and the CF_DURABLE_JOB=0 correction are
                           accurate, and the "tests are decoration" claim is
                           true (test_durable_job.py, 11 lines, no assert).
  M12 INFERENCE PROXY      PARTIAL — sha256, 273 lines, sink paths, 401 live
                           admission and the [200,502] framing defect verified;
                           node-client half and stream completion honestly
                           UNVERIFIED.

  No chapter reaches WRITTEN. Under the outline's own gate (VII.3) and the
  schema's "an empty required field is the finding", the four document-wide
  field gaps (findings 4, 5) plus three unfilled RED fields (8, 9, 10) are what
  hold all 13 at PARTIAL — not prose quality. Where these chapters make a
  locatable claim, the claim is overwhelmingly true; where they enumerate, the
  enumerations are short and presented as complete; and where the environment
  moved under them, the measurement was not re-taken.

PANEL REVIEW COMPLETE

session_id: local-18dfac354252ac87f3b7bb76bcc26c9849b71af594f1b8ff8346aa20793b828c

EXIT=0
```

### kimi

```
│ /tmp/ffc_direct.sh
│ @@ -0,0 +1,5 @@
│ +#!/bin/bash
│ +. /home/kara/code-factory/scripts/lib.sh
│ +fetch_verified http://127.0.0.1:1/nothing /tmp/ffc-art2 wrong-digest 2>/dev/null
│ +echo "rc=$?"
│ +[ -e /tmp/ffc-art2 ] && echo artifact=yes || echo artifact=no

session_id: local-e714272c13d23957b85396c7e8d7ae16fbb78c0dcf3f6f2cbc02e97ac43c0974

EXIT=0
```

### sol

```
│ cache/scratch/quorum-r6-sol-verify.py
│ @@ -0,0 +1,62 @@
│ +#!/usr/bin/env python3
│ +"""Read-only source audit plus disposable local fixtures; no live credentials."""
│ +from pathlib import Path
│ +import ast
│ +import hashlib
│ +import os
│ +import subprocess
│ +import tempfile
│ +
│ +ROOT = Path('/home/kara/code-factory')
│ +BASE = Path('/home/kara/.hermes/cache/scratch')
│ +env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1', GIT_CONFIG_GLOBAL='/dev/null', GIT_CONFIG_NOSYSTEM='1')
│ +
│ +# Run the shipped landing arm, not a substitute implementation. All remote refs
│ +# in this block belong to bare repositories created inside its own mktemp tree.
│ +text = (ROOT / 'tests/selftest.sh').read_text()
│ +block = text.split('# BEGIN cf213-land-node-branch\n', 1)[1].split('# END cf213-land-node-branch', 1)[0]
│ +prelude = 'set -uo pipefail\nHERE=/home/kara/code-factory\nfails=0\nsay() { printf "%s\\n" "$*"; }\n'
│ +with tempfile.TemporaryDirectory(prefix='quorum-r6-landing-', dir=BASE) as temp:
│ +    script = Path(temp) / 'landing-arm.sh'
│ +    script.write_text(prelude + block + '\nprintf "LANDING_ARM_FAILURES=%s\\n" "$fails"\n[ "$fails" -eq 0 ]\n')
│ +    proc = subprocess.run(['bash', str(script)], text=True, capture_output=True, env=env, timeout=100)
│ +    print('SHIPPED_LANDING_ARM_RC=%d' % proc.returncode)
│ +    for line in (proc.stdout + proc.stderr).splitlines():
│ +        if 'FAIL' in line or 'PASS  ' in line or 'LANDING_ARM' in line:
│ +            print(line)
│ +
│ +# Exercise the real seeder under a fake home; the only local modifications are
│ +# files owned by this TemporaryDirectory.
│ +with tempfile.TemporaryDirectory(prefix='quorum-r6-seed-', dir=BASE) as temp:
│ +    base = Path(temp)
│ +    src, home = base / 'src', base / 'home'
│ +    (src / 'prompts').mkdir(parents=True)
│ +    (home / '.hermes/prompts').mkdir(parents=True)
│ +    (src / 'prompts/foreman.md').write_text('seed source\n')
│ +    (home / '.hermes/prompts/foreman.md').write_text('node local edit\n')
│ +    (home / '.hermes/prompts/local.md').write_text('local only\n')
│ +    manifest = src / 'manifest.txt'
│ +    manifest.write_text('prompts/foreman.md\n')
│ +    tar = base / 'seed.tar.gz'
│ +    build = subprocess.run(['python3', '-B', str(ROOT / 'scripts/node_seed.py'), 'build', '--repo-root', str(src), '--manifest', str(manifest), '--out', str(tar)], capture_output=True, text=True, env=env)
│ +    print('SEED_BUILD_RC=%d' % build.returncode)
│ +    if build.returncode == 0:
│ +        apply = subprocess.run(['python3', '-B', str(ROOT / 'scripts/node_seed.py'), 'apply', '--tar', str(tar), '--record', str(tar) + '.json', '--home', str(home), '--force'], capture_output=True, text=True, env=env)
│ +        print('SEED_FORCE_RC=%d' % apply.returncode)
│ +        print(apply.stdout.strip())
│ +        print('SEED_LOCAL_ONLY_DELETED=%s' % (not (home / '.hermes/prompts/local.md').exists()))
│ +    else:
│ +        print(build.stderr)
│ +
│ +# Scope-counts are recomputed, not copied from the document.
│ +chapters = sorted((ROOT / 'docs/handbook/chapters').glob('M*.md'))
│ +print('CHAPTER_COUNT=%d' % len(chapters))
│ +print('METRICS_NONE_CHAPTERS=' + ','.join(p.name.split('-')[0] for p in chapters if '**RED — none' in p.read_text()))
│ +# Compile only the pure budget helper; do NOT import dispatcher (it loads live
│ +# agent/scoper configuration at import time).
│ +source = Path('/home/kara/crier-fleet/dispatcher.py').read_text()
│ +fn = next(n for n in ast.parse(source).body if isinstance(n, ast.FunctionDef) and n.name == 'task_seconds')
│ +ns = {'CAP_S': 7200, 'MARGIN_S': 60, 'TASK_S': '240'}
│ +exec(compile(ast.Module(body=[fn], type_ignores=[]), '<real task_seconds>', 'exec'), ns)
│ +print('DISPATCH_BUDGET_10=%s DISPATCH_BUDGET_60=%s' % (ns['task_seconds'](10), ns['task_seconds'](60)))
│ +print('PROXY_SHA256=' + hashlib.sha256(Path('/home/kara/.hermes/scripts/cf-inference-proxy.py').read_bytes()).hexdigest())
│ .hermes/cache/scratch/quorum-r6-sol-verify.py
│ @@ -60,3 +60,53 @@
│  exec(compile(ast.Module(body=[fn], type_ignores=[]), '<real task_seconds>', 'exec'), ns)
│  print('DISPATCH_BUDGET_10=%s DISPATCH_BUDGET_60=%s' % (ns['task_seconds'](10), ns['task_seconds'](60)))
│  print('PROXY_SHA256=' + hashlib.sha256(Path('/home/kara/.hermes/scripts/cf-inference-proxy.py').read_bytes()).hexdigest())
│ +
│ +# Import has no network/credential side effects. Replace credential resolvers
│ +# and sinks BEFORE starting two loopback-only disposable servers.
│ +import http.client
│ +import importlib.util
│ +import json
│ +import threading
│ +from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
│ +spec = importlib.util.spec_from_file_location('quorum_proxy', '/home/kara/.hermes/scripts/cf-inference-proxy.py')
│ +proxy = importlib.util.module_from_spec(spec)
│ +spec.loader.exec_module(proxy)
│ +class Upstream(BaseHTTPRequestHandler):
│ +    def do_POST(self):
│ +        self.rfile.read(int(self.headers.get('Content-Length', '0')))
│ +        body = b'data: [DONE]\n\n'
│ +        self.send_response(200)
│ +        self.send_header('Content-Type', 'text/event-stream')
│ +        self.send_header('Content-Length', str(len(body)))
│ +        self.end_headers()
│ +        self.wfile.write(body)
│ +    def log_message(self, *args):
│ +        pass
│ +with tempfile.TemporaryDirectory(prefix='quorum-r6-proxy-', dir=BASE) as temp:
│ +    upstream = ThreadingHTTPServer(('127.0.0.1', 0), Upstream)
│ +    proxy.UPSTREAM = 'http://127.0.0.1:%d' % upstream.server_port
│ +    proxy.UPSTREAM_MODEL = ''
│ +    proxy.upstream_key = lambda: 'disposable-test-key'
│ +    proxy.load_tokens = lambda: {'fixture-node': 'disposable-node-token'}
│ +    proxy.ALLOWED_MODELS = {'hermes'}
│ +    proxy.USAGE_LOG = Path(temp) / 'usage.jsonl'
│ +    proxy.CAPTURE_LOG = Path(temp) / 'capture.jsonl'
│ +    relay = ThreadingHTTPServer(('127.0.0.1', 0), proxy.Handler)
│ +    for server in (upstream, relay):
│ +        threading.Thread(target=server.serve_forever, daemon=True).start()
│ +    client = http.client.HTTPConnection('127.0.0.1', relay.server_port, timeout=1)
│ +    try:
│ +        client.request('POST', '/v1/chat/completions', json.dumps({'model':'hermes','stream':True}), {'Authorization':'Bearer disposable-node-token','Content-Type':'application/json'})
│ +        response = client.getresponse()
│ +        print('PROXY_STREAM_STATUS=%s CONTENT_LENGTH=%r TRANSFER_ENCODING=%r CONNECTION=%r' % (response.status, response.getheader('Content-Length'), response.getheader('Transfer-Encoding'), response.getheader('Connection')))
│ +        try:
│ +            response.read()
│ +            print('PROXY_STREAM_EOF_COMPLETED=True')
│ +        except TimeoutError:
│ +            print('PROXY_STREAM_EOF_COMPLETED=False: TimeoutError')
│ +    finally:
│ +        client.close()
│ +        relay.shutdown()
│ +        upstream.shutdown()
│ +        relay.server_close()
│ +        upstream.server_close()
VERDICT: FAIL
BLOCKING: 26 — findings that must be fixed before the affected chapters or the complete handbook can be called written
NON-BLOCKING: 2

FINDINGS:

Scope and evidence

I read all thirteen M0–M12 chapters, OUTLINE.md, MASTER-DOC-SCHEMA.md and the handbook README, then checked claims against the implementations. I did not read another seat’s verdict.

Path abbreviations below:
  CF = /home/kara/code-factory
  SCHED = /home/kara/coding-hermes-scheduler/coding-herms-scheduler
  CRIER = /home/kara/crier
  DISPATCH = /home/kara/crier-fleet
  PROXY = /home/kara/.hermes/scripts/cf-inference-proxy.py

Source revisions:
  CF began at 943ef984dc093e5780605ac6e54cd043122126ef.
  SCHED: 1771d3aad61e6c1ce2845e3f1450f88aa73340b3.
  CRIER: 691f0c78fc75717295abf3bd85aaa9192616aac0.
  DISPATCH: 283bca91091933177ec521e52f37f1bc987cf7da.
  PROXY SHA256: b12a0ac521c4b5a9cd7e2b76883a7edf2c9e0efd87d9bc3be3d2056d3f39e0b5.

CF advanced during review to 48ae2c9dbee4132326a3239e90a86269393278f1. I inspected the intervening diff: it changes only scripts/panel_loop.py’s defect-class parser. It does not change the seeding, landing, board, harness or proxy implementations used for the findings below.

Independently repeated:
  python3 -B tests/test_disk_floor.py
    “Ran 12 tests … OK”
  python3 -B tests/test_lane_target.py
    “Ran 40 tests … OK”
  python3 -B tests/test_harness_resolve.py
    “Ran 28 tests … OK”
  python3 -B tests/test_reclaim.py
    “Ran 9 tests … OK”
  bash scripts/verify-patch.sh
    “VERIFY-PATCH: PASS”
  python3 -B scripts/check_scan_scope.py
    “15 gitleaks claim(s) name their --log-opts”; “RESULT: OK”
  scripts/boardctl validate
    “357 tasks, 515 events, 0 fixtures”; “RESULT: OK (7 warning(s))”
  python3 -B scripts/master_doc_check.py
    “44 module(s): 37 VERIFIED, 50 error(s)”; “MASTER-DOC: FAIL”
  CF_MASTER_DIR=/home/kara/code-factory/docs/handbook/chapters python3 -B scripts/master_doc_check.py
    “no module files (NN-*.md)”; “MASTER-DOC: FAIL”

Fresh targeted Go tests also passed:
  SCHED: go test ./internal/bus -count=1
  SCHED: env -u SCHEDULER_OPERATOR_RESTART_APPROVED go test ./internal/scheduler -run 'TestDispatchReply|Test.*AutoDisable' -count=1
  CRIER: go test ./internal/guard ./internal/registry -run 'Test.*(ServiceDelivery|ServiceIdentit|ErrorResult|FailClosed|GuardError|Retrieve)' -count=1

I did not repeat the full Go suites, live provisioning/certification, real credential minting or live harness termination. Those results are not inferred from the targeted tests.

A disposable verification script is available at:
  /home/kara/.hermes/cache/scratch/quorum-r6-sol-verify.py

It exercises the shipped landing test arm, actual seeder and actual proxy handler using local fixtures, without real credentials or paid inference.

Blocking findings

B01 — OMISSION — M0, M1, M2, M3, M4, M5, M6, M7, M8, M11, M12
  Claim: Each chapter’s metrics section states “RED — none”.
  Evidence: MASTER-DOC-SCHEMA.md:72–79 explicitly makes absent metrics a RED field. I independently enumerated the eleven affected chapters. Source inspection confirms printf/log/JSONL outputs rather than the required emitted metric contracts; examples include CF/scripts/lib.sh:5–11, CF/scripts/reclaim_disk.py:119–124 and PROXY:98–101.
  Fix: Keep these chapters PARTIAL. Supply the required observability contracts and implementation evidence, or obtain an explicit schema exception. Honest disclosure does not itself satisfy this mandatory field. This is one cross-cutting finding, not eleven independently counted findings.

B02 — FALSE CLAIM — M1
  Claim: “The --force path deletes such local edits without reporting them as data loss”; the register repeats “without data-loss reporting”.
  Evidence: CF/scripts/node_seed.py:280–288 reports changed, removed and local-only paths before rmtree at :290. My actual forced-apply fixture returned:
    “changed prompts/foreman.md”
    “local-only prompts/local.md (removed by --force)”
    SEED_FORCE_RC=0
    SEED_LOCAL_ONLY_DELETED=True
  Fix: Describe the actual distinction: force is destructive and names the affected paths; whether it provides a sufficiently explicit warning or confirmation is a separate question. Do not document “no reporting” when reporting exists.

B03 — FALSE CLAIM — M1
  Claim: M1-C1 says registration is the node’s own act “or node_identity.py/node_gateway_auth.py”.
  Evidence: CF/scripts/node_identity.py:50–107 reads, merges and atomically replaces local JSON. CF/scripts/node_gateway_auth.py:29–91 writes dashboard basic-auth configuration and a local password file. Neither registers an agent with crier. CF/scripts/bunker-crier-connect.sh:107–139 stages cr ier.json and probes connectivity; it also does not register an identity.
  Fix: Remove both suggested registration producers. Name the actual key-generation, registration and credential-installation producer, or explicitly retain that producer as an unresolved boundary.

B04 — OMISSION — M1
  Claim: The provisioning settings register collapses the configuration into “PROJECT AGENT SERVER REPO REF HARNESS … CONFIG_SET_* *_TOKEN_FILE …”.
  Evidence: CF/scripts/bunker-provision.sh:38–50 and :109–119 implement separate controls; :65–92 implements namespace precedence and validation. CF/scripts/node_env.py:459–487 implements --env-file, --config-set and mutually exclusive modes; :548–576 preserves unmanaged variables and writes or corrects file modes. These behaviors do not receive individual default/range/consequence entries in M1.
  Fix: Register the controls individually, including namespace precedence, credential-file inputs, configuration overrides and unmanaged-variable preservation. Complete the operational descriptions of node_env, seed-drift, freshness and gateway-auth rather than treating a settings-surface read as coverage of their behavior.

B05 — OMISSION — M2
  Claim: S1 is described as “declare and configure lanes”, but its operational procedure and settings are effectively absent.
  Evidence: CF/scripts/load_lane_config.py:13–18 reads SCHEDULER_DB and CODE_FACTORY_ROOT; :29–37 directly updates namespace, admission mode and prompt data in SQLite. configure_family.py:102–114 overwrites prompt files, :128–138 defines pacing ceilings, and :160–189 combines API calls with direct SQL updates. add_family_lanes.py:87–96 also writes directly to SQLite.
  Fix: Document each entry point’s write set, defaults, precedence, transaction boundary, partial-failure behavior and required daemon readback. The PID-hardcode finding is valid, but it is not a substitute for describing these production mutations.

B06 — UNVERIFIED — M0, M1, M2, M3, M4, M5, M6, M7, M9, M12
  Claim: Several contracts are called “works” or “the correct completion” while a side remains a “rumour”, a file, a command, a port or an unnamed external peer.
  Evidence: Examples include M0-C1, M1-C2, M3-C1, M6-C1 and M12-C2. M2-C1/C2 identify useful source lines but do not consistently supply the enclosing producer and consumer function names. MASTER-DOC-SCHEMA.md:51–57 requires both implementations; the brief provides no automatic external-peer exemption.
  Fix: Identify both software implementations where available. For genuinely external boundaries, name the versioned protocol operation and reproducible boundary test, and seek an explicit exception where the field cannot be satisfied literally. Do not turn “external” into permission to label an unverified contract complete.

B07 — FALSE CLAIM — M3
  Claim: “A disposable local bare remote plus a clean worktree fixture is the missing evidence; none is shipped”; the chapter also reduces selftest references to “syntax + usage arms”.
  Evidence: CF/tests/selftest.sh:2459–2709 ships exactly that fixture. It creates a bare origin and clean clones at :2482–2494, tests gate rejection at :2541–2548, dry-run at :2551–2563, successful landing and fresh-clone proof at :2566–2584, repeat landing at :2586–2595, refused push at :2597–2615 and no-ff isolation at :2618–2708.
  I executed this shipped arm independently:
    SHIPPED_LANDING_ARM_RC=0
    LANDING_ARM_FAILURES=0
  Fix: Cite and use the existing fixture. Replace “none is shipped” with the measured result. Identify genuinely missing cases separately instead of claiming the behavioral battery does not exist.

B08 — OMISSION — M4
  Claim: “RESIDUE → the file is a stale artifact, not a barrier — proceed”.
  Evidence: CF/scripts/board_lock.py:73–94 can return an indeterminate probe error, including open-failed or a non-contention errno. adjudicate at :149–158 maps every non-held probe result to RESIDUE. The /proc scan also skips inaccessible processes at :58–61.
  Fix: Document that RESIDUE can include degraded observation, not just positively established staleness. Explain the operator response to an unreadable lock or failed flock probe. “Proceed” needs an explicit limitation or a distinct UNKNOWN outcome; the current explanation overstates what the classifier established.

B09 — OMISSION — M5
  Claim: S3’s Go toolchain is merely “pinned”; the chapter presents its expanded tables as the installation register.
  Evidence: CF/scripts/install-go.sh:7–16 defines go1.26.5, architecture digests, a disk floor and GO_INSTALL_ROOT. :55–73 defines GOPROXY handling and a cold-cache proof with a 30-second timeout. :138 allows GO_DL_BASE substitution. None receives a complete M5 register entry.
  Fix: Document the actual Go pin, supported architectures, install root, download-base override, proxy behavior, proof timeout and the differences between --check and --apply. These settings directly determine whether a node can build the control-plane repositories.

B10 — UNBUILDABLE — M6
  Claim: The chapter describes the handbook pipeline while acknowledging that no chapter-aware path reaches the delivered artifact.
  Evidence: CF/scripts/master_doc_check.py:186–209 selects only NN-*.md. master_doc_fill.py:422 uses the same selection. master_doc_panel.py:67–72 selects the deleted docs/master root. The explicit chapter-root gate independently selected zero modules and failed.
  Fix: Specify and verify one end-to-end path that selects these thirteen M*.md chapters, checks them and produces the owner artifact. Record the exact invocation, selected chapter count, output artifact and revision. The existing appendix gate is not a gate over this deliverable.

B11 — OMISSION — M6
  Claim: The settings register covers CF_MASTER_DIR, DEFAULT_ROOTS, --engine, --workers and --provider.
  Evidence: CF/scripts/master_doc_fill.py:395–418 additionally implements --limit, --force, --only, --model and --dry-run. --force changes which documents may be rewritten; --dry-run explicitly suppresses provider calls and writes. :438–455 implements their selection and execution consequences.
  Fix: Register the remaining mutating, selection and spending controls individually. “Every flag” cannot be satisfied by documenting only five controls while omitting the switches that determine whether writing or provider execution occurs.

B12 — UNVERIFIED — M1, M2, M5, M7, M11
  Claim: Verification entries use placeholders, unavailable host-local paths or bare test descriptions: “--agent <id> --server <host>”, “python3 ~/node-bus-worker.py --check”, “token …”, and live-job scripts without a reliable exit-code oracle.
  Evidence: M1 §7, M2 §7, M5 §7, M7 §7 and M11 §7. DISPATCH/tests/test_durable_job.py:8–11 merely prints the returned outcome. tests/test_job_kill.py:23–35 prints a verdict without converting FAIL into a failing process exit.
  Fix: Provide complete commands, concrete prerequisites, execution location and expected exit/output, with assertive fixtures where a live dependency is unavailable. Record FAIL or UNVERIFIED honestly. I did not repeat the live certification, minting or kill procedures, and syntax checks do not establish their results.

B13 — FALSE CLAIM — M9
  Claim: The auxiliary flags include simulation, routing and auto-disable controls, but “none is an admission/execution-settlement control”.
  Evidence: SCHED/cmd/schedulerd/main.go:183 makes --simulate suppress real spawning. :196–198 configures failure-rate auto-disable. internal/scheduler/alert_escalation.go:462–548 evaluates the policy and writes projects.enabled=0.
  Fix: Remove the exclusion. Document these controls with their actual admission and execution consequences, particularly the threshold, window, minimum sample and failure-attribution exclusions for auto-disable.

B14 — FALSE CLAIM — M9
  Claim: The usage-pool procedure says a “nil authority returns (false, nil)” and that refusal outcomes are “false, <named error>”.
  Evidence: SCHED/internal/scheduler/usage_pool_policy.go:26–30 distinguishes disabled policy from a nil database: nil DB returns an authority-unavailable error. :67–74 emits a capacity event and returns false, nil for a denied reservation. Those are different outcomes with different caller obligations.
  Fix: Document disabled, observe-only, authority failure, misconfiguration, capacity denial and successful reservation separately. Name the caller’s interpretation of the boolean/error pair. The current prose would lead a reader to conflate disabled enforcement with denied admission.

B15 — OMISSION — M9
  Claim: “Ordered admission procedure … the composed decision sequence, in order of authority”.
  Evidence: The chapter’s five steps omit load-bearing stages present in SCHED/internal/scheduler/tick_process.go:88–91, :105–133, :224–285 and :299–335: pause, board-stasis arming, budget gates, cadence loading, namespace/flat packing and final admission emission. packer_select.go:216–280 implements starvation, pending-work, bump, cadence adjustment and hold rotation.
  Fix: Either rename the existing list as a partial tasks/usage-pool explanation or complete the actual ordered procedure. Include selection versus final spawn admission, fairness, allocation, failure/degradation branches and the authoritative reason emitted for each refusal.

B16 — OMISSION — M9
  Claim: The durable-state section supplies “run-correctness keys and their relationships” but leaves write authorities and recovery queries unwritten.
  Evidence: SCHED/internal/database/migrations.go:1391–1489 defines idempotency, state checks, attempts, event sequences, leases, projections and outbox states. :1950–1971 adds parent deadlines, settlement references, step identity and generation uniqueness. The chapter omits their operational state machine and recovery authorities. Its “single-active-writer” statement also needs the exact indexed tuple from :1423–1424, not an unqualified workspace guarantee.
  Fix: Give the exact keys and predicates, state transitions, writer functions, claim/release/recovery operations and failure indications. Explain which guarantees come from constraints and which require application enforcement. Table existence is not an executable recovery contract.

B17 — OMISSION — M9
  Claim: “The route inventory is [written]” using internal/api/server.go:289–346.
  Evidence: The same Handler continues through :370. It mounts /hooks/reload, /features, /features/prune-candidates, /peers, /agents, /federation/query, /federation/catalogue and /cooldown/residue outside or missing from the chapter’s list. :356–366 also states that agent and federation surfaces have operator-gated reads, not merely gated mutations.
  Fix: Derive the inventory from the entire mounted handler tree. Add methods, read/write authority, request/response shapes, error statuses and readback procedures. Stop claiming inventory completion at an arbitrary source-line cutoff.

B18 — OMISSION — M9
  Claim: The log field documents two of 379 log.Printf sites and leaves the other 377 as RED.
  Evidence: I repeated the census and obtained 379. MASTER-DOC-SCHEMA.md:81–91 requires every operator-visible line, its trigger and descriptive/evidentiary classification.
  Fix: Complete an operator-oriented inventory covering admission, holds, execution, settlement, recovery and degraded dependencies. Deduplicate identical formats if useful, but retain emitter and condition coverage. A correctly counted omission remains an omission.

B19 — OMISSION — M9, M10
  Claim: Metrics are “Measured — real, not RED”, while M10 later admits its per-metric contract is RED.
  Evidence: M9 §8 describes JSON blocks and selected sources, but not the complete required type/labels/question/scrape register. M10 §8 inventories families and explicitly leaves exact label domains and per-series contracts unfinished. CRIER/internal/guard/metrics.go and SCHED/internal/api/server_metrics.go are implementation evidence, not completed documentation tables.
  Fix: Supply the required contract for each metric or response series. Distinguish scheduler JSON snapshots from Prometheus series, process-local counters from persisted aggregates, and unavailable measurements from zero. Do not headline an incomplete field as “not RED”.

B20 — OMISSION — M10
  Claim: S1 covers custody, durable transport and backend selection, but its settings register omits the storage-selection controls.
  Evidence: CRIER/config/config.go:732–767 implements database-URL precedence, CR_REGISTRY_BACKEND and CR_REGISTRY_SQLITE_PATH, with explicit backend validation and refusal conditions. :770–808 implements pool controls. These change durability, startup requirements and failure behavior, yet the chapter mainly supplies a PostgreSQL/SQLite dependency row and transport defaults.
  Fix: Document backend selection, defaults, accepted values, precedence, durable paths and failure modes. Include how an operator proves which backend is actually serving inbox custody.

B21 — OMISSION — M10, M11, M2
  Claim: M11-C2 is “works” because the dispatcher always sends ok; M10’s transport explanation does not cover the protected-service admission contract.
  Evidence: CRIER/internal/registry/service_auth.go:104–168 requires protected recipients to receive a body-bound sender signature, matching sender, nonempty idempotency_key and configured audience. DISPATCH/dispatcher.py:500–508 sends no idempotency key, and clients/python/crier_client.py:975–1005 supplies no audience argument. CF/scripts/node-bus-worker.py:1160–1167 sends a different envelope again.
  Fix: Document ordinary versus protected service delivery and the exact compatibility preconditions for each producer. “The verdict field matches” proves only one part of the completion contract. Do not imply these producers satisfy every configured crier delivery posture. I did not assert that the live allowlist is enabled.

B22 — OMISSION — M10
  Claim: The log inventory declares the handler’s three slog sites complete.
  Evidence: That narrow census is correct—I repeated it and obtained three—but M10 owns the guard too. CRIER/internal/guard/guard.go:430–457 emits “guard” and “guard blocked” records with request_id, provider, model, patterns, decision, risk and error status. These critical operational records are absent from M10 §9.
  Fix: Preserve the accurate handler census, but complete the module’s log inventory across S1–S4. A complete file-local census does not satisfy a module-wide field contract.

B23 — OMISSION — M11
  Claim: The settings register gives DISPATCH_LEASE_S=1800 and DISPATCH_TASK_CAP_S=7200, without explaining their interaction during a running job.
  Evidence: DISPATCH/dispatcher.py:435 retrieves with the lease, then :479 blocks synchronously in dispatch. dispatch_durable at :296–331 polls the node, not the inbox lease. No lease renewal appears on that execution path; ledger persistence occurs after execution at :481.
  Fix: Document lease expiry during active work, the conditions under which another consumer can reclaim it, and the actual protection—if any—against concurrent execution before the result reaches the ledger. The existing crash-before-ledger discussion does not cover active execution outliving custody.

B24 — UNVERIFIED — M12
  Claim: Healthy stream completion is declared UNVERIFIED, with an inherited experimental conclusion but no executable verification command in §7.
  Evidence: PROXY:105 selects HTTP/1.1; :206–224 sends no Content-Length, Transfer-Encoding or Connection: close and does not close the connection. I independently exercised the actual Handler against a finite local SSE upstream:
    PROXY_STREAM_STATUS=200
    CONTENT_LENGTH=None
    TRANSFER_ENCODING=None
    CONNECTION=None
    PROXY_STREAM_EOF_COMPLETED=False: TimeoutError
  Fix: Include an assertive, repeatable stream-completion fixture and record the measured failure. This is not a request to hide the defect or require a healthy implementation before describing it; it is a request to turn the claimed experiment into reproducible evidence. Also distinguish admission verification from end-to-end inference verification.

B25 — CONTRADICTION — M12
  Claim: §12 says “no node file in this repo references the proxy”; M12-C1 identifies a live configuration assignment referencing it.
  Evidence: M12-C1 quotes config/node.env.example:22, ENV_CF_PROXY_API_KEY=*** and :26’s cf-proxy provider mapping. CF/scripts/node_env.py:490–509 implements the configuration path. The chapter itself distinguishes configuration-driven wiring from a direct Python client.
  Fix: State the narrower supported claim: no direct client function has been established in this repository, while node configuration does reference the proxy. Keep configuration evidence, actual call-site evidence and successful live use distinct.

B26 — OMISSION — ROOT
  Claim: “This round’s deliverable is Part III only”, although the requested document is assessed against the eight-part outline.
  Evidence: Handbook README.md:40–56 names missing maintenance, monitoring, recovery, degradation, teardown, admission, credential lifecycle, upgrade, observability, backup/restore and fan-out flows. :141–146 leaves requirement and work derivation unwritten. The implementations plainly reach these responsibilities—for example SCHED tick cleanup at tick_process.go:186–215 and credential refresh at CF/scripts/github-app-refresh.sh:104–174.
  Fix: Keep this explicitly labeled a Part III draft rather than the completed handbook. Complete the missing flow, contract, settings, risk, derivation and delivery-mechanism sections, or obtain an explicit reduction of the acceptance scope. A writer’s scope declaration cannot silently override the review brief.

Non-blocking findings

N01 — PADDING — M0–M12
  Claim: Repeated paragraphs describe what “round-3”, “round-4” and previous named seats got wrong.
  Evidence: Examples include M0:115–116, M3:117–120 and M12:74–80. Much of this is useful change history, but it repeatedly interrupts the current operating contract.
  Fix: Move supersession history to Appendix D. Keep the current rule, evidence and operator consequence in each chapter. This becomes blocking only where historical text obscures or contradicts the current rule.

N02 — CONTRADICTION — ROOT, M6
  Claim: The handbook presents its round/revision summaries as current.
  Evidence: README.md:85 still calls M10 §9 “non-exhaustive”, while M10 explicitly withdraws that hedge for the handler’s three sites. README.md:167 labels the completeness count “round 5” inside the round-6 review set. CF also acquired the panel-parser commit during this review.
  Fix: Regenerate the summary from the chapter set and stamp the final revision manifest. Do not mechanically change every source citation: distinguish unchanged implementation evidence from the panel parser that actually changed.

DEFECT CLASSES:
  Unsupported guarantees
  Incorrect producer attribution
  Missing contract endpoints
  Incomplete settings registers
  Unrepeatable verification
  Ignored existing fixtures
  Partial admission procedures
  Incomplete recovery contracts
  Truncated surface inventories
  Incomplete observability contracts
  Undocumented custody overlap
  Broken document delivery
  Conflicting configuration claims
  Unfinished handbook scope

CHAPTER SCORECARD:

M0 — PARTIAL
  The helper inventory and source citations are substantive, and the seventeen sourcing sites are supported. Mandatory metrics remain RED, and the external contract exception is not authorized by the field contract.

M1 — PARTIAL
  The certification ladder and seeding sequence contain useful implementation evidence. Force-reporting and registration claims are wrong; settings, component behavior and live certification evidence remain incomplete.

M2 — PARTIAL
  The text_b64/text and status/ok mismatches are supported by both implementations. S1’s mutation procedure, settings, service-policy compatibility and repeatable operational verification are incomplete.

M3 — PARTIAL
  The landing implementation is well identified, and its shipped behavioral fixture passed independently. The chapter falsely says that fixture is absent. Metrics and complete contract treatment still block WRITTEN.

M4 — PARTIAL
  Store census and semantic validation reproduced. Write-boundary contracts remain UNVERIFIED, metrics are RED, and the lock explanation omits degraded observation being classified as residue.

M5 — PARTIAL
  Resolver tests pass, adapter differences are materially described, and computed installer invocation is correctly recognized. Toolchain settings and conformance evidence are incomplete; metrics and service contracts remain RED or UNVERIFIED.

M6 — PARTIAL
  The structural gate’s limitations and stale selection are accurately exposed. There is still no verified chapter-to-artifact pipeline, and mutating/spending controls are missing from the register.

M7 — PARTIAL
  Installation tokens are correctly distinguished from the separate per-dispatch minter. The mint procedure is not reproducible as written; its external contract and metrics remain unresolved.

M8 — PARTIAL
  The reclaim target sets, TTL distinction, dry-run semantics and narrow scanner scope agree with code. Reclaim tests and the scanner reproduced. The mandatory metrics field remains RED.

M9 — PARTIAL
  The chapter has real settlement, schema and default evidence. Usage-pool semantics contain a false claim; admission, durable recovery, operator surfaces, settings, metrics and logs are not complete contracts.

M10 — PARTIAL
  Retrieve aliases, signed-read ordering, default-on metrics and guard degradation are supported. Storage selection, protected-service delivery, module-wide logging and per-metric contracts are incomplete.

M11 — PARTIAL
  Job supervision, replay limitations, serial execution and the synchronous alternative are substantially described. Completion compatibility is overgeneralized, active-job lease expiry is omitted, and behavioral test oracles and metrics remain deficient.

M12 — PARTIAL
  The content hash and unauthenticated 401 reproduced. Sink paths agree with code, and the healthy-stream framing defect independently reproduced. Client wiring is internally contradictory; boundary and behavioral verification remain incomplete, and metrics are RED.

No chapter is SKELETON: every chapter contains meaningful source-derived material. No chapter satisfies the mandated WRITTEN contract.

PANEL REVIEW COMPLETE

session_id: local-20a6a0f1e279c54dad9d6e28c4cae6d57d43e195a3a6dd6c55f83a8940ef1947

EXIT=0
```

