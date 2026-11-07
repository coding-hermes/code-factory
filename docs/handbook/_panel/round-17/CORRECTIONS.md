# CORRECTIONS — round 17

Generated 2026-11-06T23:17:55-0500.

## Verdicts

- **deepseek** — FAIL, blocking 3, 8006 bytes, complete=True
- **glm** — FAIL, blocking 2, 8341 bytes, complete=True
- **grok** — FAIL, blocking 5, 21923 bytes, complete=True
- **kimi** — FAIL, blocking 6, 18789 bytes, complete=True
- **sol** — FAIL, blocking 26, 28533 bytes, complete=True

## Verdict text (verbatim, per seat)

### deepseek

```
I have read all 13 chapters, the outline, the schema, run the spine, and spot-checked ~18 load-bearing claims directly against the code. Here is the verdict.

```
VERDICT: FAIL

BLOCKING: 3

NON-BLOCKING: 4

FINDINGS
========

B1 — UNBUILDABLE — M6-documentation
  Claim: "the legacy fill/render/panel pipeline is UNBUILDABLE against these
  M-numbered chapters" and CT-18 state UNVERIFIED.
  Evidence: verified in code. scripts/gen_nasa_handbook.py:18 hardcodes
  `MODULES = REPO / "docs/master"`; :255 selects `[0-9][0-9]-*.md`; :259 prints
  "no modules found". master_doc_check.py:52 DEFAULT_ROOTS=("docs/master",
  "docs/handbook/appendices/units") and :188 globs the same `[0-9][0-9]-*.md`.
  Neither selects `M0-...-*.md`, so the only renderer that produces the owner's
  approval artifact cannot render these chapters. The document has no working
  path to the owner's desk. Documenting the breakage (F6-1) does not fix it.
  Fix: add a chapter-aware render leg (or make gen_nasa_handbook select M*.md)
  so CT-18 is satisfiable.

B2 — OMISSION (coverage) — document-wide / OUTLINE Part II
  Claim: OUTLINE Part II lists 16 flows (F1-F16), all marked MISSING.
  Evidence: `ls docs/handbook/chapters/` yields only M0-M12; no F*.md or flow
  file exists. Verified. This is the panel's historically largest single
  finding (OUTLINE header names "Secondary (5, missing — the panel's largest
  single finding)") and it is still open: every chapter §12 reads "flow
  chapter not written." In-scope per the outline's own scope boundary.
  Fix: write the 16 flow chapters, or record an explicit quorum scope ruling
  that defers them with a dated owner decision.

B3 — INCOMPLETE-RED — M9-scheduler, M10-crier
  Claim: M9 §8 per-metric contract, M9 §9 log inventory (372 distinct
  log.Printf strings), M10 §8 per-metric contract are named REDs as
  "not measured."
  Evidence: verified. `grep -rn "log.Printf" internal/scheduler/*.go |
  grep -v _test.go | wc -l` = 381 sites (370 distinct) — only 2 tabulated in
  M9 §9. These are distinct operator-visible strings, not the four house-style
  templates that justify M0/M1/M2/M3's "counted-not-enumerated" exemption.
  Under OUTLINE Part VII.3 a "not measured" field is UNVERIFIED and blocks
  WRITTEN. These are enumerable with a grep and within the loop's power to
  complete.
  Fix: tabulate M9 §8/M10 §8 per-metric (type/labels/question/scrape) and M9
  §9's remaining distinct log strings, or obtain an explicit schema exception.

NON-BLOCKING FINDINGS
=====================

N1 — REVISION-DRIFT — M10-crier
  Claim: "Revision: e50e55ee (crier repo HEAD at this round's stamp)."
  Evidence: git rev-parse HEAD = 1587a03f (one commit past e50e55ee).
  e50e55ee IS an ancestor; the new commit is test-only ("test(crier): keep the
  dead-endpoint control honest ... INT-CI-027"), so no cited non-test claim is
  affected. The chapter's own closed-world "git diff" discipline (F10-11)
  already acknowledges HEAD advances.
  Fix: re-stamp to 1587a03f next round.

N2 — COUNT-DRIFT — M9-scheduler
  Claim: "378 call sites ... producing 372 distinct format strings."
  Evidence: measured 381 sites / 370 distinct at the same stamped rev 251d11db.
  Immaterial — the field is RED either way — but the census numbers are off by
  ~3. The spine's COUNT CLAIM check does not cover prose log-site counts
  (M6 §3 S9: submodule is None).
  Fix: re-run the grep and re-quote the exact number.

N3 — CONFLICTED-EXEMPTION — M0/M1/M2/M3/M5/M7
  Claim: the "counted not enumerated" §9 schema exemption (house templates
  with data-interpolated labels) is a writer argument, self-flagged "if the
  panel rejects it, the field is RED."
  Evidence: M5 §9 (274 sites, 4 tabulated) and M7 §9 (103 sites, 2 tabulated)
  already declare the uncovered count a named RED; M1/M2/M3 assert the
  exemption. No uniform panel ruling exists across the group.
  Fix: settle the exemption once (one ruling, applied M0-M8) so RED counts are
  comparable.

N4 — TERMINAL-RED (resource-gated) — M1/M2/M5/M7/M10/M12
  Claim: not-measured REDs that require a live node or a credential absent on
  this host.
  Evidence: M1 §7 certification ladder, M2 §7 bus-worker ladder, M5 §7
  conformance battery, M10 §7 signed-read ladder (all need a live cf-node);
  M7 §1 token mint (no GitHub App creds on host); M12 §7 disallowed-model 403
  (needs the node token file). These are valid terminal UNVERIFIED states per
  OUTLINE Part IV, not writing defects.
  Fix: none in-loop; a live-node certification pass would close them.

DEFECT CLASSES
==============
UNBUILDABLE-DELIVERY, OMISSION-FLOWS, INCOMPLETE-RED, REVISION-DRIFT,
CONFLICTED-EXEMPTION, TERMINAL-RED.
(None observed this round: FALSE CLAIM, CONTRADICTION, PADDING, SKELETON.)

CHAPTER SCORECARD
=================
M0  shared-contract    WRITTEN  — 1 RED (metrics, absence-proved); all claims file:line-verified
M1  provisioning       PARTIAL  — §7 certification ladder not-measured (needs live node)
M2  dispatch           PARTIAL  — §7 bus-worker ladder not-measured (needs cf-node)
M3  repository         PARTIAL  — S3 hook enforcement + freshness arm not-measured
M4  board              WRITTEN  — 1 RED (metrics, absence-proved); store census 357/519 re-verified
M5  harness            PARTIAL  — §7 conformance battery + §9 inventory incomplete
M6  documentation      PARTIAL  — Status UNVERIFIED (own gate reads FAIL: 44/37/50), CT-18 leg unbuildable
M7  github             PARTIAL  — §1 mint not-measured (no App creds) + §9 inventory incomplete
M8  safety             WRITTEN  — 1 RED (metrics, absence-proved)
M9  scheduler          PARTIAL  — 6 REDs (per-metric, log inventory, per-route, post-recovery, aux-flag range, CT-05 internal unmeasured)
M10 crier              PARTIAL  — 5 REDs (per-metric, module log inventory, custody-proof, signed-read ladder, TS/front/MCP activation)
M11 dispatcher         PARTIAL  — §7 live-job tests are decoration (cannot fail)
M12 inference-proxy    PARTIAL  — streaming completion FAILING (F12-7 reproduced: 200 with no Content-Length/Transfer-Encoding/Connection, client EOF timeout)

VERIFICATION NOTES
==================
Spine gate: `python3 scripts/handbook_spine.py` -> "chapters=13 canonical
contracts=18 findings=0", exit 0. No unregistered contract id, no setting
default conflict, no dangling reference, no count-claim mismatch.

Spot-checks that held against live code (no FALSE CLAIM found):
- dispatchReplyVerdict reads only payload["ok"]; absence = success
  (dispatch_leg.go:709-726) -> CF-355 real, carried at CT-04.
- node-bus-worker.py:1176-1192 reply carries `status`, no `ok`/`run_id`/`outcome`.
- handbook_spine.py is dirty: 443 lines vs HEAD 340, sha256 afbc65fc (M6 F6-8 exact).
- board census 357 rows / 519 events (M4 exact).
- crier: handler slog=3, Port 8767, metrics default-ON with metrics.go:2 "opt-in" contradiction (M10 F10-3 exact).
- scheduler: 30 tables, no-exec-fallback=true, board-stasis-gate=true, load-gate=0, buildForemanPrompt:1249 (M9 exact).
- cf-inference-proxy sha256 b12a0ac5; streaming framing defect reproduced (M12 exact).
- master_doc_check.py -> "44 module(s): 37 VERIFIED, 50 error(s)", MASTER-DOC: FAIL, exit 1 (M6 exact).
```

The document is the most evidence-dense and self-correcting round this loop has produced: the spine is clean, there are zero false claims and zero cross-chapter contradictions in my verification, and the delicate self-corrections (CF-354/CF-355, the F12-7 streaming defect, the dirty `handbook_spine.py`, the `metrics.go` "opt-in" comment) all check out against the code. It fails on delivery, not on honesty: the render leg (CT-18) cannot produce the owner's artifact, the 16 flow chapters remain unwritten, and M9/M10 carry enumerable "not measured" REDs that are within the loop's power to close.

PANEL REVIEW COMPLETE

session_id: local-c7e92acb721229ca61eb14a3bfb538b93d1d330d98378eaa4c491dbdd6b6f1c7

EXIT=0
```

### glm

```
VERDICT: FAIL

BLOCKING: 2 — findings that must be fixed before this chapter set can be called written
NON-BLOCKING: 6

Verification basis: spine re-run by this seat (chapters=13, canonical contracts=18, findings=0, exit 0);
~150 cited locators, defaults, counts and commands independently re-executed across all five code bases
(code-factory @ce2f875, scheduler @251d11db, crier @1587a03f, crier-fleet @283bca9, cf-inference-proxy
sha256 b12a0ac5…). Zero false claims found in the sample. Every quick unit test repeated OK
(disk_floor 12, lane_target, clone_lane 4, harness_resolve 28, reclaim 9); both Go builds PASS; board
census 357/519, boardctl validate OK (7 warnings), board_drift OK @e07d031, master_doc_check FAIL
44/37/50 rc 1, verify-patch PASS (5 stages, 4 patches, 57432007…), proxy 401 + systemd active — all
exactly as the chapters quote.

FINDINGS:

BLOCKING 1 — kind UNVERIFIED, chapter M6 (round certification).
  Claim: §7 "spine … PASS — chapters=13 canonical contracts=18 findings=0" over a document whose
  cross-chapter consistency is certified by scripts/handbook_spine.py.
  Evidence: the gate is uncommitted working-tree content — working file 443 lines, sha256
  afbc65fc7bfec…, `git status` M; `git show HEAD:scripts/handbook_spine.py` is 340 lines and lacks
  the backtick-aware split_row, the CONTRACT ROW MISPARSE 6-column check and the CONTRACT UNKNOWN-ID
  rejection (M6 F6-8 discloses this). A fresh clone at the stamped revision runs a weaker,
  behaviorally different gate over the very §6 rows (M4 CT-10, M6 CT-16, M2 CT-09, M12 M12-C1) the
  working-tree splitter exists to parse. The findings=0 certification every chapter's §7 leans on is
  reproducible from no commit. I could repeat it only from the dirty tree.
  Fix: commit scripts/handbook_spine.py and re-stamp. Note: the whole round-17 deliverable
  (13 chapters + OUTLINE) is uncommitted mid-round, which is expected — the spine is the one file
  where a conflicting, weaker version lives at HEAD.

BLOCKING 2 — kind UNVERIFIED (stale quoted evidence), chapters M4, M5, M6, M7, M8 (§1).
  Claim: "`git diff --name-only 3fba8a7..HEAD -- scripts/ docs/ tests/` is empty — e07d031 touched
  only prompts/…".
  Evidence: the command now returns two paths — scripts/panel_loop.py, scripts/panel_supervise.sh —
  because commit ce2f875 ("panel: the loop can own its own worktree") landed 2026-11-06T23:04:54-05,
  after the chapters' last write (22:28–22:59) and before this judgment. The substance survives:
  neither file is cited by M4/M5/M7/M8, and both M6-cited files were re-verified by this seat at
  ce2f875 (panel_loop.py still 461 lines with :323/:357/:383/:385 resolving; panel_supervise.sh:41
  and :42-43 resolve — the commit's change is a one-line REPO default above them). But the quoted
  command's stated output no longer repeats — the exact staleness class M9 F9-12 and M10 F10-11
  already treat as a defect in their own chapters; the code-factory group must hold itself to the
  same rule. (M0–M3 pinned explicit ranges 9372dc0..3fba8a7, which I verified path-for-path and
  which remain true; only their "(current HEAD)" parentheticals are stale.)
  Fix: re-quote the diff with the two real paths, re-affirm cited-file byte-identity, re-stamp at
  ce2f875.

NON-BLOCKING 1 — M10: revision stamp drift e50e55ee → 1587a03f (one test-only commit, INT-CI-027);
  `git diff --name-only e50e55ee..HEAD -- <all cited paths>` = 0 files (this seat). Stamp
  methodology holds; re-stamp next round.
NON-BLOCKING 2 — M10 §7: first full-suite repeat by this seat flaked one package; the second run was
  clean rc 0 (41 ok / 3 no-test-files — exactly the chapter's numbers). "0 FAIL" is load-conditioned,
  not unconditional; the chapter's own flakiness history already says so.
NON-BLOCKING 3 — M9 §7: this seat's full ./internal/scheduler repeat at the same rev FAILED under
  host load 12–20 (TestSCHEDGAP1666_SevenDaySimulation board_empty assertion + SCHED-GAP-1726
  goroutine census); SCHEDGAP1666 passes solo at load 15. Corroborates F9-13; the load-window flake
  set is wider than the chapter's named CTL002 instance — worth naming 1666 alongside it.
NON-BLOCKING 4 — Part II: all 16 flows remain MISSING. No chapter claims otherwise and every
  cross-reference says so; a pass on the module half must not be read as a finished handbook.
NON-BLOCKING 5 — M4 §12 vs M9 §3: tasksAdmissionDue cited as :230-242 vs :230-243 — same function,
  ±1 end line. Harmless.
NON-BLOCKING 6 — M12 F12-7/F12-4: this seat verified the mechanism in code (:200-238 — upstream
  status/headers sent before the first read; healthy stream returns with no Content-Length /
  Transfer-Encoding / Connection; post-header failure attempts a second status → [200,502]). The
  dynamic EOF-timeout repro remains a quoted third-party measurement this seat did not re-run.

DEFECT CLASSES: stale-stamp evidence (quoted diff output raced by a later commit); uncommitted
certification gate; honest absence-proved metrics REDs (system observability debt, filed, not
hidden); environment-gated live-node/credential legs; load-window test flakes (green only quiet or
solo); disclosed carried code defects (CF-355 silent success, stream framing, kill scope F11-8, PID
hardcode F2-2, mode-600 lie F1-1, checkout false-green F1-5); doc-pipeline structural debt (legacy
gate/renderer cannot select the M-chapters; render leg missing, CT-18).

CHAPTER SCORECARD:
  M0  — WRITTEN. Sole RED is the absence-proved metrics field; range stamp explicit and verified;
        all anchors repeated this seat (lib.sh helpers line-for-line, 11/17 source counts,
        fails-closed fetch path).
  M1  — PARTIAL. Source-verified exhaustively (10 files, line counts exact); certification ladder
        needs a live node — its own named RED.
  M2  — PARTIAL. node-bus-worker verified end to end (reply dict, dry-run lease 5 s, same-batch
        duplicate, settlement ordering); live ladder not repeatable from this host (FACT-04
        provenance).
  M3  — PARTIAL. Landing arm and gates verified; hook enforcement unproven (no rejecting-commit
        fixture) and cf244 arm unrun — both named REDs.
  M4  — PARTIAL. Substance complete — store, drift, validate, lock classifier, admission gate and
        crier-negative all repeated by this seat — blocked solely by Blocking 2's stale §1 sentence.
  M5  — PARTIAL. Conformance battery unrun (live node); §9 inventory partial; adapter-capability
        matrix verified against every installer line cited; blocked by Blocking 2.
  M6  — PARTIAL. Own gate reads FAIL over the legacy 44-unit corpus (filed CF-360/F6-1); render leg
        missing; Blockings 1 and 2 both land here.
  M7  — PARTIAL. Mint env-gated (no App creds); scoped-token attribution to fleet-gh-scope.py
        verified; blocked by Blocking 2.
  M8  — PARTIAL. Would be WRITTEN — sole RED absence-proved, both files verified and both §7 rows
        repeated — except Blocking 2's stale §1 sentence.
  M9  — PARTIAL. Six named REDs (per-metric contract, per-route contract, recovery readbacks,
        aux-flag ranges, CT-05 unmeasured, log inventory); everything sampled — 24 flag defaults,
        57/43/378/10 counts, payload(), dispatchReplyVerdict, packer order, metrics blocks —
        verified verbatim; suite green only quiet.
  M10 — PARTIAL. Five named REDs; handler/config/guard/client anchors all verified; the
        default-ON metrics vs metrics.go:2 "opt-in" contradiction is real and correctly filed.
  M11 — PARTIAL. Every settings row and log site verified (EXEC_TIMEOUT inert, kill-scope
        withdrawal, ledger replay, excerpt semantics); live-job tests are decoration — its own
        named RED.
  M12 — PARTIAL. Admission/routing/capture verified and repeated (sha256, 401, systemd, all
        constants); streaming FAILING is a demonstrated defect correctly carried as RED.

The document is one commit and five re-quoted §1 cells away from a clean round. No false claim
survived ~150 independent checks; the two blockers are reproducibility defects in the evidence
layer, not in the prose.

PANEL REVIEW COMPLETE

session_id: local-211e286526d53f3f43960cda6abe8cbe5ecd823e06e772432af952295fc6c688

EXIT=0
```

### grok

```
⚠️  Primary auth failed — switching to fallback: fireworks / accounts/fireworks/models/deepseek-v4p1-flash-1017
│ cache/scratch/spine_probe.py
│ @@ -0,0 +1,8 @@
│ +import sys
│ +sys.path.insert(0, '/home/kara/code-factory/scripts')
│ +import handbook_spine as hs
│ +ch = hs.chapters()
│ +for name, text in ch.items():
│ +    rows = hs.contract_rows(text)
│ +    st = sum(1 for l in hs.section(text, 5).splitlines() if hs.SETTING_ROW.match(l))
│ +    print(name, "s6_rows=", len(rows), "s5_setting_rows=", st)
│ cache/scratch/inject.py
│ @@ -0,0 +1,51 @@
│ +import pathlib, re, subprocess, sys
│ +
│ +S = pathlib.Path("/home/kara/.hermes/cache/scratch/spine_t1")
│ +CH = S / "docs/handbook/chapters"
│ +M0 = CH / "M0-shared-contract.md"
│ +M4 = CH / "M4-board.md"
│ +orig0 = M0.read_text()
│ +orig4 = M4.read_text()
│ +
│ +def run():
│ +    r = subprocess.run([sys.executable, str(S / "scripts/handbook_spine.py")],
│ +                       capture_output=True, text=True)
│ +    return r.returncode, [l for l in r.stdout.splitlines()[1:] if l.strip()]
│ +
│ +try:
│ +    # A: unknown canonical id
│ +    M0.write_text(orig0.replace("| (local) | bunker CLI", "| CT-99 | bunker CLI"))
│ +    print("A unknown ct id  ->", run())
│ +
│ +    # B: setting default conflict injected into M4 section 5
│ +    M0.write_text(orig0)
│ +    inj = orig4.replace("## 6. Contracts in and out",
│ +                        "## 5. Settings register\n\n| Setting | Default | Range | Governs | Breaks |\n|---|---|---|---|---|\n| `CF_TIMEOUT_S` | 900 (`x:1`) | n/a | t | t |\n\n## 6. Contracts in and out", 1)
│ +    M4.write_text(inj)
│ +    print("B setting conflict ->", run())
│ +
│ +    # C: count claim lie
│ +    M4.write_text(orig4.replace("## 12. Cross-references", "## 12. Cross-references\n\nThis handbook now documents 20 modules.\n", 1))
│ +    print("C count claim    ->", run())
│ +
│ +    # D: dangling flow ref
│ +    M4.write_text(orig4.replace("## 12. Cross-references", "## 12. Cross-references\n\nSee F42 for the flow.\n", 1))
│ +    print("D dangling ref   ->", run())
│ +
│ +    # E: state disagreement on an INTERNAL contract (CT-02) across two chapters
│ +    M9 = CH / "M9-scheduler.md"
│ +    o9 = M9.read_text()
│ +    M9.write_text(o9.replace("**works**", "**broken**", 1))
│ +    print("E state disagree ->", run())
│ +    M9.write_text(o9)
│ +
│ +    # F: one-sided internal contract (blank producer on CT-05 row)
│ +    M2 = CH / "M2-dispatch.md"
│ +    o2 = M2.read_text()
│ +    M2.write_text(o2.replace("| `load_lane_config.py:31-37`", "| see M9", 1))
│ +    print("F one-sided      ->", run())
│ +    M2.write_text(o2)
│ +finally:
│ +    M0.write_text(orig0)
│ +    M4.write_text(orig4)
│ +print("restored ->", run()[0])
│ cache/scratch/locator_audit17.py
│ @@ -0,0 +1,53 @@
│ +import re, pathlib
│ +
│ +CH = pathlib.Path("/home/kara/code-factory/docs/handbook/chapters")
│ +ROOTS = [
│ +    pathlib.Path("/home/kara/code-factory"),
│ +    pathlib.Path("/home/kara/coding-hermes-scheduler/coding-herms-scheduler"),
│ +    pathlib.Path("/home/kara/crier"),
│ +    pathlib.Path("/home/kara/crier-fleet"),
│ +    pathlib.Path("/home/kara/.hermes/scripts"),
│ +]
│ +LINE_RE = re.compile(r"(?<![\w/.-])([\w./-]+\.(?:py|go|sh|ts|js|toml|yaml|yml|jsonl|md)):(\d+)(?:[-–](\d+))?")
│ +
│ +def resolve(p):
│ +    rel = p.lstrip("./")
│ +    if rel.startswith("internal/") or rel.startswith("cmd/"):
│ +        for r in (pathlib.Path("/home/kara/coding-hermes-scheduler/coding-herms-scheduler"),
│ +                  pathlib.Path("/home/kara/crier")):
│ +            if (r / rel).exists():
│ +                return r / rel
│ +    for r in ROOTS:
│ +        cand = r / rel
│ +        if cand.exists():
│ +            return cand
│ +    if "/" not in rel and (pathlib.Path("/home/kara/crier-fleet") / rel).exists():
│ +        return pathlib.Path("/home/kara/crier-fleet") / rel
│ +    return None
│ +
│ +missing, out_of_range = [], []
│ +for f in sorted(CH.glob("M*.md")):
│ +    text = f.read_text()
│ +    for m in LINE_RE.finditer(text):
│ +        p, start, end = m.group(1), int(m.group(2)), m.group(3)
│ +        path = resolve(p)
│ +        if path is None:
│ +            missing.append((f.stem, p, start))
│ +            continue
│ +        try:
│ +            n = sum(1 for _ in path.open("rb"))
│ +        except Exception:
│ +            continue
│ +        hold = int(end) if end else start
│ +        if hold > n:
│ +            out_of_range.append((f.stem, p, hold, n))
│ +
│ +print("=== FILE NOT RESOLVABLE ===")
│ +for row in missing:
│ +    print(row)
│ +print("count:", len(missing))
│ +print()
│ +print("=== LINE BEYOND EOF ===")
│ +for row in out_of_range:
│ +    print(row)
│ +print("count:", len(out_of_range))
VERDICT: FAIL

BLOCKING: 5
NON-BLOCKING: 9

---

SPINE (rule 3 of the brief, run as instructed)

  $ python3 scripts/handbook_spine.py
  chapters=13  canonical contracts=18
  findings=0          exit 0

  Treating that as "no blocked CONTRADICTION from the spine" — not as absolution. I falsified the
  gate before trusting it (injected faults into a scratch copy):
    injected CT-99 row            -> CONTRACT UNKNOWN ID, rc 1        fires
    injected "20 modules" prose   -> COUNT CLAIM, rc 1                fires
    injected "See F42"            -> DANGLING REFERENCE, rc 1         fires
    flipped CT-02 state in M9     -> CONTRACT STATE DISAGREEMENT, rc 1 fires
    injected CF_TIMEOUT_S conflict *outside* §5 -> findings=0         does NOT fire
  The last one is the section-scoped scan the document already admits (M6 §5, blind spot (a)).
  I also ran HEAD's committed spine (340 lines) against the same chapters: findings=0, so the
  strengthened working-tree gate does not change the verdict, only its coverage.

---

FINDINGS

1. CONTRADICTION + FALSE CLAIM — M0, M1, M2, M3 vs M4, M5, M6, M7, M8, M12
   Claim (M0:9): "derivation base `9372dc0` ... byte-identical through `3fba8a7` (current HEAD)".
   Claim (M4:9, repeated verbatim in M5/M6/M7/M8/M12): "`e07d031d...` (code-factory HEAD ==
   origin/main == gh/main, round-17 derivation; `git diff --name-only 3fba8a7..HEAD -- scripts/
   docs/ tests/` is empty ...)".
   Evidence — measured:
     git log -1                        -> ce2f875 2026-11-06 23:04:54  panel: the loop can own its own worktree
     git log --format=%ci e07d031      -> 2026-11-06 22:24:12
     git diff --name-only 3fba8a7..HEAD -- scripts/ docs/ tests/
       scripts/panel_loop.py
       scripts/panel_supervise.sh          <- the command the six chapters quote returns two paths
   Two different commits are called HEAD for one repository, in one document issue, and neither is
   HEAD. `3fba8a7` was already superseded at 22:24 by `e07d031`, before M0's mtime (22:36). Schema §1
   requires one revision per issue; the schema's own worked example (MASTER-DOC-SCHEMA:110) puts the
   revision in the identity row, so a reader uses it to check cited lines.
   Fix: re-stamp every code-factory chapter to `ce2f875`, delete "current HEAD" phrasing, re-run and
   re-quote the diff with its real two paths, and re-verify each cited locator in the post-commit
   files (M6's `panel_loop.py` locators do still resolve at 461 lines; M5/M7/M8 cite none of the two
   changed files, so their substance survives the re-stamp).

2. CONTRADICTION — README (§ front matter) against the chapters it indexes
   Claims:
     README:162  "Does it open with a general arrangement? | Yes — Part I, rendered"
     README:25   "I.1 ... **MISSING** (no rendered artifact — the renderer globs docs/master/...)"
     README:84   "III.10 | M9 SCHEDULER | ... §9 log inventory 2/379, settings register incomplete"
     README:85   "III.11 | M10 CRIER | UNVERIFIED | PARTIAL | handler body unread, §9 inventory
                  non-exhaustive"
     README:167  "Chapter completeness | 0 WRITTEN, 13 PARTIAL, 0 SKELETON (round 9)"
   Evidence: M9:314 measures 378 `log.Printf` sites (I reproduced: 378 excluding `_test.go`, 379
   including) — not 379 with 2 tabulated; M10:12 states "the full 1895-line handler body read
   line-by-line this round" (I reproduced `wc -l internal/registry/handler.go` = 1895); README:162
   contradicts README:25 in the same file, one screen apart. The status table is stamped round 9
   in a round-17 document.
   Fix: regenerate the Part III status table and the "Measured status" block from the chapters'
   own §1/§13 (or delete the table and point at the chapters), and reconcile the Part I row.

3. CONTRADICTION — the acceptance rule that decides every grade, stated three incompatible ways
   OUTLINE:277-278: "Neither RED state is WRITTEN. A chapter is WRITTEN only when its remaining RED
     fields are all 'absence proved'" — adjacent sentences, opposite instructions.
   OUTLINE:271: "A module with no metrics is correctly RED ... not a defect in the writing."
   README:69-71: "a chapter with a RED metrics field stays PARTIAL until the system emits metrics or
     an explicit schema exception is approved."
   M4:200-207: "RED accounting rule — one rule, document-wide ... a boundary UNVERIFIED row is a
     terminal state, not a RED" (a third rule, which M0/M1/M2/M3/M5/M6/M7/M8/M12 then apply).
   Consequence: 11 of 13 modules emit no metrics (every chapter's §8 absence-proof), so under
   README's rule no chapter can ever be WRITTEN; under OUTLINE:271 they are all WRITTEN-eligible;
   under the chapters' RED counts half the RED columns disappear. The document's central verdict is
   unfalsifiable until one rule is chosen.
   Fix: state the rule once (OUTLINE Part VII.3), have README and the chapters cite it by line, and
   delete the other two formulations.

4. OMISSION (document level) — OUTLINE Part II, all 16 flows
   Quote (M9:351, and identically in all 13 chapters' §12): "F11 SCHEDULING ADMISSION is the primary
   flow ... — **flow chapter not written** (OUTLINE Part II, all 16 flows MISSING)."
   Evidence: `ls docs/handbook/chapters/` = 13 files, M0..M12 only; README:35-50 lists II.1-II.16
   "MISSING"; README:164 "Are secondary flows covered? No"; README:56 files it as F-ROOT-1.
   The outline calls the flows the panel's largest single finding (OUTLINE:73) and the thing that
   makes the node deliverable ("A reader cannot operate a fleet from the node's side of it",
   OUTLINE:6-9). Thirteen module chapters with sixteen flows deferred is a module census, not the
   document the outline specifies. Filed ≠ written.
   Fix: write Part II as its own chapters (the outline already fixes the field set per flow:
   trigger · exit · actors · preconditions · numbered steps naming modules · branches · state ·
   contracts · timing · duplicate case · empty case · degradation · diagram), or amend the outline's
   deliverable claim and the README's "Yes — Part I, rendered" line in the same commit.

5. OMISSION — M10, the capability delivery route
   Claim (M10:32, S1 custody and transport): the handler surface is "`HandleRegister` (`:598`),
   `HandleDeliver` (`:990`), `HandleRetrieve` (`:1690`), `HandleAck` (`:1812`)".
   Evidence: crier registers a second deliver route — `cmd/server/main.go:112`
   `r.HandleFunc("/capabilities/{capability}/inbox", h.HandleDeliverByCapability).Methods("POST")`,
   implemented at `internal/registry/handler.go:1014`, with its own authorization rule at
   `internal/registry/service_auth.go:117-126` ("capability routing cannot authorize a service
   recipient") and its own counters (`crier_capability_routed_total`,
   `crier_capability_unheld_total` — which M10:204-205 quotes in §8 without the route that emits
   them). OUTLINE M10.S1 names "routing" as in scope. The chapter therefore documents the metrics of
   a delivery path it never describes.
   Fix: add the capability route to §3 S1 (handler + registration line + the refusal rule), add a
   §10 failure-mode row for a capability addressed to a protected recipient, and cross-reference it
   from §8.

6. UNVERIFIED — M6 (and the CT-16 "works" row): the gate that certifies cross-chapter consistency is
   uncommitted working-tree content
   Quote (M6:9): "**Dirty-source disclosure (sol B10):** `scripts/handbook_spine.py` is
   **uncommitted in the working tree** — the reviewed file is 443 lines, `git show
   HEAD:scripts/handbook_spine.py` is 340 lines".
   Evidence — reproduced: `git status --porcelain scripts/handbook_spine.py` → ` M`; working sha256
   `afbc65fc...2163` (443 lines); `git show HEAD:...` sha256 `5f55a267...d2cf` (340 lines). The
   checks M6 §5 credits to the gate (`CONTRACT UNKNOWN ID` :267, `CONTRACT ROW MISPARSE` :254,
   backtick-aware `split_row`) do not exist at HEAD; HEAD's gate also returns findings=0, so the
   verdict is stable but the *gate* a stranger gets is weaker than the one certified.
   Fix: commit the spine (and pin M6's locators to the committed sha), or mark CT-16 and M6 §7's
   spine row UNVERIFIED-by-revision. Disclosure is not the same as a reproducible artifact.

7. FALSE CLAIM (minor) — M0 §5
   Quote (M0:82): "`lib.sh` carries one tunable constant and no env-var surface".
   Evidence: `scripts/lib.sh:11` — `FAILED=${FAILED:-0}` reads `FAILED` from the environment; a
   caller that exports `FAILED=5` changes `bad()`'s counter semantics. The next sentence concedes the
   point ("FAILED ... is a per-script failure counter, not a setting"), so the fix is one clause.
   Fix: "no tunable env surface; the only environment read is the `FAILED` counter seed at `:11`".

8. FALSE CLAIM (stale revision) — M10 §1
   Quote (M10:9): "`e50e55ee` (crier repo HEAD at this round's stamp)".
   Evidence: crier HEAD is `1587a03f` ("test(crier): keep the dead-endpoint control honest under a
   privileged runner"), which changed only `cmd/server/session_dispatch_live_test.go`. The chapter's
   six-path diff (`git diff --name-only 0a372209..HEAD` → 6 paths) and its claim that every cited
   non-test Go file is byte-identical to `33c1f388` both still reproduce (verified: zero cited files
   changed), so only the "HEAD" wording is false.
   Fix: "stamp `e50e55ee`; HEAD `1587a03f` is a test-only commit, cited files byte-identical to
   `33c1f388`".

9. UNVERIFIED (citation imprecision) — M4 §2/§5/§11
   Quote (M4:17, :81, :164): "a completion REQUIRES `--evidence-run-id` — `boardctl update --help`".
   Evidence: `boardctl update --help` lists `[--evidence-run-id RUN]` and says nothing about a
   requirement (grep for "required|complete|evidence" returns only the synopsis line). The
   requirement is enforced at runtime and named there: I created a scratch board,
   `boardctl -C <scratch> create --id BX-1 --title probe`, then `update BX-1 --status complete` →
   "evidence run required: completion REFUSED ... `--evidence-run-id` is REQUIRED when setting
   status "complete" (TR-251)". The behaviour is real; the cited source cannot show it.
   Fix: cite the refusal string (and the TR-251 row) rather than `update --help`.

10. CONTRADICTION (schema field) — M1 §1, M12 §1
    Quote (M12:12): "Status | **VERIFIED (admission/routing/capture), FAILING (streaming)**";
    (M1:12) "**VERIFIED (source)** ... **UNVERIFIED (behavioural)**".
    Evidence: `MASTER-DOC-SCHEMA.md:21` — "Status | `VERIFIED` / `UNVERIFIED` / `FAILING` — never
    blank, never 'done'". Two values in one field break any consumer that reads the word (the
    schema's own gate, `master_doc_check.py:128-138`, key-words on the supplied status).
    Fix: one status word per chapter (the weaker one) with the qualifier moved into §2/§13.

11. CONTRADICTION (unfixed companion) — UNIT-MAP
    Quote (M5:55-56): "OUTLINE v2 lists M5 as 5 submodules (S1–S5); `docs/UNIT-MAP.yaml` lists 3
    (S1–S3). The two structure maps still disagree".
    Evidence: `grep -oE 'M[0-9]+\.S[0-9]+' docs/UNIT-MAP.yaml | sort -u | wc -l` → **25** (the v1
    count), while OUTLINE Part III declares **48** and the chapters' §3 tables carry 50 rows for 48
    submodules (M1 splits S1, M3 splits S1 into a/b). README:28 calls the unit map "MAPPED (13
    modules, 48 submodules)" — the map it points at does not contain them.
    Fix: regenerate UNIT-MAP from the chapters (gen_unit_map.py exists) or downgrade I.4 to PARTIAL.

12. CONTRADICTION (count terminology) — OUTLINE Counts
    Quote (OUTLINE:311): "Submodule chapters | 25 | 48".
    Evidence: 13 chapter files exist; 48 is a row count inside them, not a chapter count, and the
    spine cannot catch it (`"submodule": None`, handbook_spine.py:401 — admitted at M6:117).
    Fix: "Submodule rows (inside 13 chapters) | 25 | 48", or emit per-submodule chapters.

13. UNBUILDABLE (document level) — OUTLINE Part VII
    Quote (README:168): "Can a task list be derived? | **Not yet** — Part VII unwritten".
    Evidence: README:145-146 VII.1/VII.2 "NOT WRITTEN"; no R-nnn table exists anywhere under
    docs/handbook/. The chapters are individually actionable (each §13 files findings F*-n with
    board-row ids), but the document cannot be converted into dispatchable tasks without a separate
    derivation step it does not contain.
    Fix: write VII.1/VII.2 from the chapters' §13 findings, or state in the outline that derivation
    is out of scope for this issue.

14. UNVERIFIED (not repeatable by this seat) — the live-ladder and long-suite rows
    M9:265-267 (`internal/scheduler` 376.454s PASS; full `go test ./...` rc 1 under parallel load),
    M10:175 (`go test -count=1 ./...`, 44 packages), M1:237 / M5:170 / M7:98 / M12:121 (live-node and
    credential-gated ladders). I did not re-run any of these: the scheduler package run alone costs
    376 s under the load this host is under, the live ladders need a bunker agent and App creds that
    do not exist here. Every one of them is already marked UNVERIFIED/RED by its writer — the note is
    that no judge can promote them, only a live node can.

---

DEFECT CLASSES

  revision-stamp drift · two-HEADs-for-one-repo · stale front matter · acceptance-rule
  self-contradiction · section-scoped gate blind spot · uncommitted evidence artifact ·
  named-scope omission (route-without-documentation) · citation imprecision (help text vs
  enforcement) · schema field drift (compound status word) · stale companion artifact
  (UNIT-MAP) · count terminology (rows called chapters) · declared-but-unrun live ladders

---

CHAPTER SCORECARD

  M0  PARTIAL   — §3/§4/§8-§11 verified against lib.sh line by line; one false clause ("no env-var
                  surface", :11); metrics RED absence-proved.
  M1  PARTIAL   — 10 units read, settings register complete; certification ladder unrun (RED),
                  compound status word.
  M2  PARTIAL   — reply dict, deliver, text_b64 refusal, dry-run lease all reproduced; live
                  bus-worker ladder not repeatable from this host (RED).
  M3  PARTIAL   — landing script + selftest arm locators exact; hook *enforcement* unproven, cf244
                  arm unrun, 3 REDs.
  M4  PARTIAL   — store measured live (357/519, validate OK +7 warnings, drift OK); §1 revision row
                  false now, `update --help` cannot show the evidence-run rule.
  M5  PARTIAL   — installer dispatch (`project-node.sh:440,449-452`), pins, CF_* predicates all
                  verified; conformance battery unrun, §9 partial, stale revision row.
  M6  PARTIAL   — master_doc_check FAIL reproduced (exit 1, 44/37/50), spine locators exact; own
                  gate reads FAIL, the certifying spine is uncommitted.
  M7  PARTIAL   — CLI surface (exit 2), MIN_AGE, refresh guards verified; mint unrun (no App creds),
                  §9 partial.
  M8  PARTIAL   — only metrics RED; reclaim TTL/targets and scanner surface verified. Closest to
                  WRITTEN; blocked only by the shared revision row.
  M9  PARTIAL   — 57 flags, 43 routes, 30 tables, 378 log sites, packer gate order, execution_store
                  authorities all reproduced; six declared REDs.
  M10 PARTIAL   — 1895-line handler, 3 slog sites, guard log forms, client surfaces verified; five
                  REDs plus the undocumented capability route.
  M11 PARTIAL   — 538 lines, 25 log( lines, EXEC_TIMEOUT inert, timeout-group kill defect all
                  reproduced; metrics RED, live-job tests cannot fail.
  M12 PARTIAL   — sha256, 273 lines, sink paths, 401 admission, framing defect reproduced; streaming
                  FAILING, metrics RED.

  0 WRITTEN, 13 PARTIAL, 0 SKELETON. The evidence discipline is real — I reproduced more than sixty
  cited locators and every one I sampled resolved to the line claimed, and the spine's five checks
  fire when faulted. What keeps this from PASS is not sloppiness in the chapters: it is that the
  document's own status apparatus (revision rows, front matter, acceptance rule) is now false, and
  the flow half of the outline does not exist.

PANEL REVIEW COMPLETE

⚠️ File-mutation verifier: 1 file edit(s) FAILED this turn despite any wording above that may suggest otherwise. Run `git status` or `read_file` to confirm what actually landed.
  • `/home/kara/.hermes/cache/scratch/locator_audit.py` — [write_file] Refusing to overwrite `/home/kara/.hermes/cache/scratch/locator_audit.py`: `/home/kara/.hermes/cache/scratch/locator_audit.py` exists but this task has not seen its full current conte…

session_id: local-d8ff3127c4859f6fc827bbcef6b8a5c3e2889db9506236e0d86646bd074c7f99

EXIT=0
```

### kimi

```
│ cache/scratch/citecheck-r17.py
│ @@ -0,0 +1,60 @@
│ +#!/usr/bin/env python3
│ +"""Round-17 citation verifier: every `path:line` in the chapters vs the tree."""
│ +import re, os
│ +from pathlib import Path
│ +
│ +CH = Path("/home/kara/code-factory/docs/handbook/chapters")
│ +ROOTS = [
│ +    "/home/kara/code-factory",
│ +    "/home/kara/coding-hermes-scheduler/coding-herms-scheduler",
│ +    "/home/kara/crier",
│ +    "/home/kara/crier-fleet",
│ +    "/home/kara/.hermes/scripts",
│ +]
│ +CIT = re.compile(r"`(/?[\w.@+/-]*[\w-]+\.(?:go|py|sh|ts|js|md|toml|yaml|yml|json|jsonl)):(\d+)(?:-(\d+))?`")
│ +
│ +def resolve(p):
│ +    raw = p.lstrip("/")
│ +    cands = []
│ +    if raw.startswith("home/"):
│ +        cands.append("/" + raw)
│ +    for r in ROOTS:
│ +        cands.append(os.path.join(r, raw))
│ +    # basename fallback
│ +    base = os.path.basename(raw)
│ +    for r in ROOTS:
│ +        for dp, dn, fn in os.walk(r):
│ +            if "/.git" in dp or "node_modules" in dp:
│ +                continue
│ +            if base in fn:
│ +                cands.append(os.path.join(dp, base))
│ +    for c in cands:
│ +        if os.path.isfile(c):
│ +            return c
│ +    return None
│ +
│ +tot = 0
│ +bad = []
│ +files = set()
│ +for f in sorted(CH.glob("M*.md")):
│ +    text = f.read_text()
│ +    for m in CIT.finditer(text):
│ +        path, a = m.group(1), int(m.group(2))
│ +        tot += 1
│ +        r = resolve(path)
│ +        if not r:
│ +            bad.append((f.stem, path, a, "MISSING_FILE", ""))
│ +            continue
│ +        files.add(os.path.realpath(r))
│ +        lines = open(r, errors="replace").read().splitlines()
│ +        n = len(lines)
│ +        if a > n:
│ +            bad.append((f.stem, path, a, "LINE_OOR", f"file has {n} lines"))
│ +        elif a < 1:
│ +            bad.append((f.stem, path, a, "BAD_LINE", ""))
│ +        elif not lines[a-1].strip():
│ +            bad.append((f.stem, path, a, "LINE_EMPTY", ""))
│ +
│ +print(f"citations={tot} distinct_files={len(files)} problems={len(bad)}")
│ +for b in bad:
│ +    print("  %-9s %-52s :%-5s %-12s %s" % b)
│ cache/scratch/cite_r17b.py
│ @@ -0,0 +1,68 @@
│ +#!/usr/bin/env python3
│ +"""Round-17 citation verifier (fast variant): index only plausible subtrees."""
│ +import os, re, subprocess
│ +from pathlib import Path
│ +
│ +CH = Path("/home/kara/code-factory/docs/handbook/chapters")
│ +ROOTS = [
│ +    "/home/kara/code-factory",
│ +    "/home/kara/coding-hermes-scheduler/coding-herms-scheduler",
│ +    "/home/kara/crier",
│ +    "/home/kara/crier-fleet",
│ +]
│ +SKIP = re.compile(r"/(\.git|node_modules|__pycache__|\.venv|dist|build|vendor|\.hermes/cache)/")
│ +CIT = re.compile(r"`(/?[\w.@+/-]*[\w-]+\.(?:go|py|sh|ts|js|md|toml|yaml|yml|json|jsonl)):(\d+)(?:-(\d+))?`")
│ +
│ +index = {}
│ +for r in ROOTS:
│ +    for dp, dn, fn in os.walk(r):
│ +        if SKIP.search(dp + "/"):
│ +            dn[:] = []
│ +            continue
│ +        rel = os.path.relpath(dp, r)
│ +        if rel.count(os.sep) > 4:
│ +            dn[:] = []
│ +            continue
│ +        for f in fn:
│ +            index.setdefault(f, []).append(os.path.join(dp, f))
│ +index.setdefault("cf-inference-proxy.py", []).append("/home/kara/.hermes/scripts/cf-inference-proxy.py")
│ +
│ +def resolve(p):
│ +    raw = p.lstrip("/")
│ +    base = os.path.basename(raw)
│ +    cands = index.get(base, [])
│ +    if "/" in raw:
│ +        exact = [c for c in cands if c.endswith("/" + raw) or c.endswith(raw)]
│ +        if exact:
│ +            return exact[0]
│ +    if cands:
│ +        # prefer code-factory then scheduler then crier
│ +        order = {"/home/kara/code-factory": 0, "/home/kara/.hermes/scripts": 1}
│ +        cands.sort(key=lambda c: (order.get(c.rsplit("/", 1)[0], 5), len(c)))
│ +        return cands[0]
│ +    return None
│ +
│ +tot = 0
│ +bad = []
│ +resolved_uniq = set()
│ +for f in sorted(CH.glob("M*.md")):
│ +    for m in CIT.finditer(f.read_text()):
│ +        path, a = m.group(1), int(m.group(2))
│ +        tot += 1
│ +        r = resolve(path)
│ +        if not r:
│ +            bad.append((f.stem, path, a, "MISSING_FILE", ""))
│ +            continue
│ +        resolved_uniq.add(r)
│ +        lines = open(r, errors="replace").read().splitlines()
│ +        n = len(lines)
│ +        if a > n:
│ +            bad.append((f.stem, path, a, "LINE_OOR", f"{os.path.basename(r)} has {n} lines"))
│ +        elif a < 1:
│ +            bad.append((f.stem, path, a, "BAD_LINE", ""))
│ +        elif not lines[a-1].strip():
│ +            bad.append((f.stem, path, a, "LINE_EMPTY", ""))
│ +
│ +print(f"citations={tot} resolved_files={len(resolved_uniq)} problems={len(bad)}")
│ +for b in bad:
│ +    print("  %-9s %-50s :%-5s %-12s %s" % b)
VERDICT: FAIL

BLOCKING: 6 — findings that must be fixed before this chapter can be called written

NON-BLOCKING: 4

FINDINGS:

1. FALSE CLAIM — M0, M1, M2, M3 (§1 Revision)
Claim quoted: "`lib.sh` and every file M0 cites byte-identical through `3fba8a7` (current HEAD). `git diff --name-only 9372dc0..3fba8a7` touches only `scripts/panel_loop.py`, `scripts/panel_supervise.sh`, `scripts/reap_orphan_writers.py`, `docs/handbook/_panel/round-9/writer.txt` and the M11 chapter".
Evidence: `3fba8a7` is NOT HEAD and was not HEAD when these chapters were written. Commit times: `3fba8a7` 21:34:28, `e07d031` 22:24:12, `ce2f875` 23:04:54; the four chapters' mtimes are 22:36–22:43, i.e. all four assert "current HEAD" for a commit already superseded at write time. The quoted diff output proves it: it omits `prompts/foreman.md` and `prompts/unblock.md`, which are exactly the files `e07d031` touched. `git rev-parse --short HEAD` now returns `ce2f875` (== `origin/main`).
Fix: drop every "(current HEAD)" phrase; stamp the derivation base and state the checked range, e.g. "derived at `9372dc0`; M-cited files byte-identical through `e07d031` (checked 2026-11-06 22:24; document HEAD has since advanced to `ce2f875`)".

2. CONTRADICTION — M0/M1/M2/M3 vs M4/M5/M6/M7/M8 vs M12 (document revision)
Claim quoted: M4/M5/M7/M8: "`e07d031…` (code-factory HEAD == origin/main == gh/main, round-17 derivation)"; M12: "Locators re-verified at code-factory HEAD `e07d031` (this round)" while M12-C1 says the grep was "re-run this round at CF HEAD `3fba8a7`".
Evidence: one document issue names two different code-factory HEADs, and M12 names both inside itself. `docs/MASTER-DOC-SCHEMA.md` §1 requires "One revision per document issue". Actual HEAD == `origin/main` == `ce2f875`, so neither stamp is current and every §7 "Last run … rev" cell (M0–M8) refers to a revision the document does not declare.
Fix: one revision line for the whole issue (code-factory `ce2f875`, scheduler `251d11db`, crier `1587a03f`, crier-fleet `283bca9`, proxy sha256 `b12a0ac5…`), re-stamp §7, and delete the per-chapter claims of being "HEAD".

3. FALSE CLAIM — M9 §1 and §4a, M10 §1 and §4a (host Go toolchain)
Claim quoted: "`go env GOVERSION` resolves **go1.26.10**. Host bootstrap `go` = **go1.26.10** both at `/usr/bin/go` … and `/home/kara/.local/bin/go` (this round; the round-16 judges measured 1.26.8/1.26.5 — the host was upgraded to 1.26.10 since)" (M9); the same claim repeated in M10 with "`go build ./...` **PASS**" as its absence-detection.
Evidence, measured this round: `cat /usr/lib/go-1.26/VERSION` → `go1.26.8`; `readlink -f /home/kara/.local/bin/go` → `/home/kara/sdk/go1.26.5/bin/go` and `/home/kara/.local/bin/go version` → `go1.26.5`; `/usr/bin/go version` from `/home/kara` → `go1.26.8`; only inside the module (`GOTOOLCHAIN=auto`) does `go version` print `go1.26.10`, because `/home/kara/go/pkg/mod/golang.org/toolchain@v0.0.1-go1.26.10.linux-amd64` exists — i.e. the fetch already happened. The round-16 judges' 1.26.8/1.26.5 was CORRECT; the "host was upgraded" narrative is false.
Fix: state the measured pair (`/usr/bin/go` = go1.26.8, `~/.local/bin/go` = go1.26.5) and that `go1.26.10` is selected by `GOTOOLCHAIN=auto` from the module cache; delete "no `GOTOOLCHAIN` fetch is needed" and the assertion that the binary defaults are met without a download.

4. OMISSION — M5 §5 (`GO_PIN`), cross-referenced to M9 §4a
Claim quoted: "`GO_PIN` | `go1.26.5` (`:7`) | exact version | the Go toolchain installed | drift installs an unmeasured toolchain".
Evidence: `scripts/install-go.sh:7` `GO_PIN="go1.26.5"` (verified) while `/home/kara/coding-hermes-scheduler/coding-herms-scheduler/go.mod` declares `go 1.26.0` + `toolchain go1.26.10` and `/home/kara/crier/go.mod` declares `go 1.26.10`. The register never states the consequence: a node provisioned through this installer carries a toolchain below both control-plane modules' declared floor, so any build of either module silently downloads `go1.26.10`. The one setting on the critical path has a "what breaks if changed" cell that describes drift, not the requirement it already violates.
Fix: add the requirement row (scheduler `toolchain go1.26.10`, crier `go 1.26.10`) and the consequence "a node at `GO_PIN` cannot build either module without a `GOTOOLCHAIN` fetch"; either raise the pin or file the pin bump as a board row and say so.

5. UNVERIFIED — M9 §9 (log-line inventory arithmetic)
Claim quoted: "**378** call sites … producing **372 distinct format strings** … the remaining **376** sites (370 distinct strings) are uncovered".
Evidence: 378 call sites reproduces (`grep -rn "log.Printf" internal/scheduler/*.go | grep -v _test.go | wc -l` → 378), but no command for 372/370 is quoted anywhere in §9 or §13, and three natural readings give different answers: 367 (quoted-first-arg extraction), 371 (`sed 's/^[[:space:]]*log\.Printf\(//' | sort -u`), 374 (`sed 's/.*log\.Printf(//' | sort -u`). A derived number presented as measured, feeding a RED total, is exactly what rule 1 excludes. (Method note: one of these three is what the writer must publish; the number is not yet settleable.)
Fix: publish the exact command and its output for the distinct-string count, or restate the field as "378 sites; distinct-string count not measured".

6. OMISSION — document level, evidenced by every chapter's §12
Claim quoted (M0 §12, M2 §12, M3 §12, M4 §12, M5 §12, M11 §12, and identical text in M1, M6, M7, M8, M9, M10): "F1 DISPATCH AND SETTLEMENT is the primary flow … — **flow chapter not written** (OUTLINE Part II, all 16 flows MISSING)".
Evidence: `ls docs/handbook/chapters/` → 13 files, `M0…M12` only; OUTLINE Part II requires 16 flow chapters and Parts I (surface inventory / invariants / I.9 non-coverage), V (global settings register), VI (risk quadrants), VII (work derivation) and VIII (delivery mechanisms) have no artifact at all. Every chapter's cross-references therefore point at content that does not exist, and no chapter can be turned into work for its primary flow (F1/F2/F5/F11 are the flows four chapters own).
Fix: file the missing Parts as explicit, dated RED items with their own status word (the spine's reference check passes because the references are honest, not because the targets exist), and stop counting this handbook as satisfying OUTLINE Part II.

NON-BLOCKING FINDINGS:

7. Locator drift — M3 §4b: "`refuse` (`land-node-branch.sh:53-58`) is local, not shared". Measured: `refuse() {` is at `:55`, body `:55-60`; `:53` is a blank line before the comment. Fix: `:55-60`.
8. Locator outside the named file — M10 §5: "`config/config.go:1139-1187` fixes the guard's env bounds". `config/config.go` is 1606 lines so the range exists, but the guard's `CR_GUARD_*` bounds live in `internal/guard/guard.go:49-55` (struct fields with their defaults) and `config/config.go`'s `cfg := Config{…}` block starts at `:621`. The row's citation does not name the file that defines those bounds. Fix: cite `internal/guard/guard.go:49-55` plus the `config/config.go` reader.
9. Stale external stamp — M10 §1: crier HEAD is now `1587a03f` (one test-only commit past `e50e55ee`: `cmd/server/session_dispatch_live_test.go`). Non-test Go files are still byte-identical, so no content claim is affected; the stamp should say so explicitly.
10. Gate provenance — M6 discloses that `scripts/handbook_spine.py` is uncommitted (443 working-tree lines vs 340 at HEAD, sha256 `afbc65fc…`). I confirmed the working tree differs by 161 insertions / 58 deletions, so `python3 scripts/handbook_spine.py → findings=0` is not reproducible from any commit. I did reproduce it against a redirected copy and verified the gate can fail: injected mutants produced `SETTING CONFLICT` (CF_MAX_TURNS 41 vs 40), `CONTRACT UNKNOWN ID` (CT-99), `CONTRACT STATE DISAGREEMENT` (CT-06 works vs broken), `DANGLING REFERENCE` (M13) and `COUNT CLAIM` (17 flows vs 16) — all rc 1. The gate has teeth; it must be committed before a round can cite it.

DEFECT CLASSES: stale-revision-stamp; two-stamps-one-issue; unmeasured-value-presented-as-measured; host-environment drift mis-blamed on an upgrade; cross-module setting requirement absent from the register; locator off-by-two; locator citing the wrong file; missing document parts behind honest cross-references; uncommitted gate used as evidence.

CHAPTER SCORECARD:
- M0 SHARED CONTRACT — PARTIAL. 13/13 schema sections, every `lib.sh` line I checked is exact (78 lines; `say` :5, `ok/bad/warn/note` :6-9, `FAILED` :11, `fetch_verified` :19-42, `require_disk` :48-57, `bunker_exec` :75-78), grep counts 11/17 reproduce. Fails on finding 1 (false "current HEAD"). Its one RED is absence-proved.
- M1 PROVISIONING — PARTIAL. Sections complete, all ten units' line counts reproduce (verify-node 241, node_seed 405, node_env 589, node_seed_drift 558, node_freshness 732, bunker_config_gen 724, node_gateway_auth 95, node_identity 111). Two REDs, one of them not-measured (live certification ladder) → not WRITTEN; plus finding 1.
- M2 DISPATCH — PARTIAL. Strongest node chapter: §6 protected-delivery scoping, the dry-run lease correction, the same-batch duplicate finding are all real. Two REDs (live ladder not repeatable from this host) → not WRITTEN; plus finding 1.
- M3 REPOSITORY — PARTIAL. Land-node-branch 308 / install-gitreins 180 / clone_lane 130 / repo_freshness 662 / selftest 4852 all reproduce, and the selftest arm bounds `:2463-2729` and `:3433-3670` land exactly on the BEGIN/END banners. Three REDs (hook enforcement, cf244 arm, metrics) → not WRITTEN; findings 1 and 7.
- M4 BOARD — PARTIAL. Store claims are exact: 357 rows, 519 events, `tasks.jsonl` sha256 `5aa15431…` identical to `origin/main`. Fails on finding 2 (its stamp is no longer HEAD == origin/main).
- M5 HARNESS — PARTIAL. Every number checks: harness-vars 318, harness_resolve 400, installers 375/592/673/101/113/98, helper sites 274 with the per-file split (9/98/86/13/36/15/17). Three REDs + findings 2 and 4.
- M6 DOCUMENTATION — PARTIAL. Honest about the legacy pipeline being unbuildable against `M*.md`, and its spine blind-spot list is accurate — I independently confirmed the locator blind spot (findings 7, 8). Two REDs (its own gate reads `MASTER-DOC: FAIL` over 44 unit sections) → not WRITTEN.
- M7 GITHUB — PARTIAL. Three REDs (mint never run — no App creds), self-reported and correctly labelled; the F7-3 correction (a different minter produces the scoped token) is a real, useful finding.
- M8 SAFETY — PARTIAL. Only its §8 metrics RED, which is absence-proved, so content-wise it was the nearest to WRITTEN; finding 2's false "HEAD == origin/main" is what stops it.
- M9 SCHEDULER — PARTIAL. Best-evidenced chapter and it still carries six declared REDs. Verified exact: 57 flags, 43 routes (all `/api/v1/`, mux at `internal/api/server.go:289-370`), 378 log sites, 30 tables, `buildForemanPrompt` :1249, `dispatchReplyVerdict` :713, `payload()` :175 emitting `board`/`text_b64` and no `run_id`, 7 `cmd/` dirs. Fails on findings 3 and 5.
- M10 CRIER — PARTIAL. Handler locators exact (`HandleRegister` :598, `HandleDeliver` :990, `HandleRetrieve` :1690, `HandleAck` :1812), config defaults exact (8767 / 100 / 1<<20 / true), `HeaderServiceAudience` at `agentsig.go:35`, front `defaultListen` at `:39`, `deploy/crier.service:44`. Five REDs; findings 3 and 9.
- M11 DISPATCHER — PARTIAL. Best log inventory in the document: all 23 call sites at the cited lines, `grep -n 'log('` = 25 (comment :81 + def :112), file 538 lines, HEAD `283bca9` current. Its kill-scope withdrawal (F11-8) is the kind of finding that pays for the chapter. Two REDs → not WRITTEN.
- M12 INFERENCE PROXY — PARTIAL. Content sha256 `b12a0ac5…` and 273 lines reproduce exactly; the four grep sites reproduce; the streaming FAILING verdict is a demonstrated defect, not a hedge. Fails on finding 2's internal two-stamp contradiction.

Summary of the mechanical layer: `python3 scripts/handbook_spine.py` → `chapters=13  canonical contracts=18  findings=0`, rc 0, and I verified the gate is capable of failing (five mutant classes, all caught). The spine is therefore doing its job and the document is clean on the checks it performs. Everything I am blocking on is in the classes it explicitly does not check — revision agreement, locator existence, and cross-module setting requirements — which is why a green spine and a FAIL verdict are consistent here, not contradictory.

The document is not a skeleton: 13/13 chapters carry all 13 schema fields, 368 locators resolve to 84 real files with no missing file and no beyond-EOF line, and the evidence discipline is real. It is not writable yet either: two of the three things a stranger needs to trust it — *which revision this is* and *which toolchain the host actually has* — are currently stated falsely, and the missing 16 flows plus Parts I/V/VI/VII/VIII mean no chapter's cross-references land.

PANEL REVIEW COMPLETE

⚠️ File-mutation verifier: 1 file edit(s) FAILED this turn despite any wording above that may suggest otherwise. Run `git status` or `read_file` to confirm what actually landed.
  • `/home/kara/.hermes/cache/scratch/citecheck.py` — [write_file] Refusing to overwrite `/home/kara/.hermes/cache/scratch/citecheck.py`: `/home/kara/.hermes/cache/scratch/citecheck.py` exists but this task has not seen its full current content (neve…

session_id: local-dd565eaf0cf0e3a3b2787e513b798820300ed4d73b97ba63dc2f8931a047f7ab

EXIT=0
```

### sol

```
│ cache/scratch/round17_judge_probe.py
│ @@ -0,0 +1,85 @@
│ +import contextlib
│ +import importlib.util
│ +import io
│ +import json
│ +import os
│ +from pathlib import Path
│ +import socket
│ +import tempfile
│ +import threading
│ +from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
│ +import http.client
│ +
│ +ROOT = Path('/home/kara/code-factory')
│ +def load(name, path):
│ +    spec = importlib.util.spec_from_file_location(name, path)
│ +    mod = importlib.util.module_from_spec(spec)
│ +    spec.loader.exec_module(mod)
│ +    return mod
│ +
│ +proxy = load('r17proxy', '/home/kara/.hermes/scripts/cf-inference-proxy.py')
│ +proxy.load_tokens = lambda: {'fixture': 'local-fixture-token'}
│ +proxy.upstream_key = lambda: 'local-fixture-upstream-key'
│ +proxy.capture_request = lambda *a: None
│ +proxy.log_usage = lambda rec: None
│ +class Upstream(BaseHTTPRequestHandler):
│ +    def do_POST(self):
│ +        self.rfile.read(int(self.headers.get('Content-Length', '0')))
│ +        body = b'data: {"test":true}\n\ndata: [DONE]\n\n'
│ +        self.send_response(200)
│ +        self.send_header('Content-Type', 'text/event-stream')
│ +        self.send_header('Content-Length', str(len(body)))
│ +        self.end_headers()
│ +        self.wfile.write(body)
│ +    def log_message(self, *args):
│ +        pass
│ +class Server(ThreadingHTTPServer):
│ +    daemon_threads = True
│ +    def handle_error(self, request, client_address):
│ +        import sys
│ +        print('PROXY_HANDLER_EXCEPTION=' + type(sys.exception()).__name__)
│ +up = Server(('127.0.0.1', 0), Upstream)
│ +proxy.UPSTREAM = 'http://127.0.0.1:%d' % up.server_port
│ +pr = Server(('127.0.0.1', 0), proxy.Handler)
│ +for srv in (up, pr):
│ +    threading.Thread(target=srv.serve_forever, daemon=True).start()
│ +try:
│ +    c = http.client.HTTPConnection('127.0.0.1', pr.server_port, timeout=0.5)
│ +    c.request('POST', '/v1/chat/completions', json.dumps({'model':'hermes','stream':True}), {'Authorization':'Bearer local-fixture-token'})
│ +    r = c.getresponse()
│ +    print('PROXY_STREAM_STATUS=%s FRAMING=%s' % (r.status, {k:r.getheader(k) for k in ('Content-Length','Transfer-Encoding','Connection')}))
│ +    try:
│ +        body = r.read()
│ +        print('PROXY_STREAM_EOF_COMPLETED=True bytes=%d' % len(body))
│ +    except (TimeoutError, socket.timeout) as exc:
│ +        print('PROXY_STREAM_EOF_COMPLETED=False: ' + type(exc).__name__)
│ +    c.close()
│ +    c = http.client.HTTPConnection('127.0.0.1', pr.server_port, timeout=1)
│ +    c.request('POST','/v1/chat/completions',json.dumps({'model':['hermes']}),{'Authorization':'Bearer local-fixture-token'})
│ +    try:
│ +        r = c.getresponse()
│ +        print('PROXY_NONSTRING_MODEL_HTTP=%d' % r.status)
│ +        r.read()
│ +    except http.client.RemoteDisconnected:
│ +        print('PROXY_NONSTRING_MODEL_HTTP=RemoteDisconnected')
│ +    c.close()
│ +finally:
│ +    for srv in (pr, up):
│ +        srv.shutdown()
│ +        srv.server_close()
│ +
│ +reclaim = load('r17reclaim', ROOT/'scripts/reclaim_disk.py')
│ +with tempfile.TemporaryDirectory(prefix='r17-reclaim-', dir=os.environ['TMPDIR']) as tmp:
│ +    path = Path(tmp)/'.cache/pip/a'
│ +    path.parent.mkdir(parents=True)
│ +    path.write_bytes(b'fixture')
│ +    result = reclaim.reclaim(tmp, dry_run=True)
│ +    print('RECLAIM_DRY_RUN_BYTES=%d FILE_STILL_EXISTS=%s' % (result['reclaimed_bytes'], path.exists()))
│ +
│ … omitted 7 diff line(s) across 1 additional file(s)/section(s)
VERDICT: FAIL
BLOCKING: 26 — findings that must be fixed before the affected chapters can be called written
NON-BLOCKING: 0

FINDINGS:

Review basis: all 13 module chapters, OUTLINE.md, MASTER-DOC-SCHEMA.md, and the implementation paths named below. Findings are grouped by independently fixable defect, not counted once per affected chapter.

Path abbreviations:
  CF = /home/kara/code-factory
  SCH = /home/kara/coding-hermes-scheduler/coding-herms-scheduler
  CR = /home/kara/crier
  DISP = /home/kara/crier-fleet
  PROXY = /home/kara/.hermes/scripts/cf-inference-proxy.py

Required spine execution, independently repeated:
  Command: python3 scripts/handbook_spine.py
  Output: chapters=13  canonical contracts=18
          findings=0
  Exit: 0

There are no spine-reported findings to add. This result does not establish schema completeness or semantic correctness: the implementation deliberately exempts boundary contracts and does not verify locator truth.

B01 — CONTRADICTION — M0–M12: boundary contracts are being waived out of acceptance.

  Claim: M4, lines 200–207: an external-peer contract is a “terminal state” and “is not counted as a RED.” Equivalent exemptions appear throughout the chapters.

  Evidence: the quorum brief, lines 17–22, says unsupported claims are UNVERIFIED and blocking, and requires both contract implementations. MASTER-DOC-SCHEMA.md:56–57 likewise calls a one-sided contract a rumour. CF/scripts/handbook_spine.py:284–288 explicitly skips further checking of boundary contracts.

  Fix: preserve honest external/unmeasured annotations, but do not turn them into acceptance exemptions. Identify the missing evidence and retain the blocking state. A human endpoint need not be invented as a function; that limitation must remain explicit rather than being counted as completed verification.

B02 — OMISSION — M0–M8, M11, M12: critical-path metrics remain absent.

  Claim: the affected chapters’ §8 says “RED — none.”

  Evidence: independent source searches for prometheus|Counter|Gauge|Histogram|/metrics returned zero exact matches across CF/scripts, DISP/dispatcher.py and PROXY. The chapters also supply absence evidence. MASTER-DOC-SCHEMA.md:72–79 explicitly makes “none” RED; the handbook’s acceptance rule retains that requirement.

  Fix: implement and document suitable observable metrics, or obtain an explicit schema exception. This is principally a documented system deficiency, not a charge that the writers concealed it. It nevertheless prevents WRITTEN under the supplied acceptance contract.

B03 — OMISSION — document-wide; especially M1, M2, M3, M9, M11: operational flows remain unwritten.

  Claim: cross-references repeatedly say “flow chapter not written.”

  Evidence: OUTLINE.md:54–93 requires F1–F16, including branches, timing, duplicate/concurrent cases, empty-state behaviour and degradation. README.md:35–50 marks all sixteen missing. The independent file probe found no F-numbered flow chapter files.

  Fix: deliver the operational flow sections, with executable exit checks and component handoffs. The README’s Part-III-only scope disclosure is honest, but it does not satisfy the complete outline requested by this brief.

B04 — OMISSION — M1, M2, M3, M5, M6, M7, M9, M10: log inventories are incomplete; the template exemption is insufficient.

  Claim: M1/M2/M3 argue that enumerating helper labels adds no operator knowledge and may be treated as padding. Other chapters explicitly leave most emitters untabulated.

  Evidence: MASTER-DOC-SCHEMA.md:81–91 requires every operator-visible line, its trigger, and descriptive/evidentiary classification. Missing entries are not confined to interpolated helper labels. CF/scripts/node-bus-worker.py:1349,1384–1385,1419,1421 emits BUS WORKER terminal forms absent from M2’s §9 table. CF/scripts/bunker-provision.sh:546 emits BUNKER APPLIED/BUNKER INCOMPLETE, absent from M1’s claimed distinct-terminal inventory. M6 tabulates only the legacy checker despite covering the panel and spine.

  Fix: generate a complete emitter inventory, including fixed labels, terminal forms and their conditions. Shared formatting may be factored out; distinct failure meanings and terminal outcomes may not.

B05 — OMISSION — M2, M9, M10, M11: internal contract rows are not complete operational contracts.

  Claim: CT-02/CT-03/CT-04/CT-06 are marked “works,” largely from named implementation sites and compatible fields.

  Evidence: OUTLINE.md:209–210 also requires payload, timing, failure semantics and breaking-change policy. The §6 rows do not supply a complete version/compatibility and timing contract. For example, DISP/dispatcher.py:435 leases a message, :479 executes synchronously, and :508–519 delivers then acknowledges; field compatibility alone does not establish the operational behaviour of that sequence.

  Fix: document each internal contract’s complete request/reply schema, correlation, deadlines, lease/retry/idempotency rules, refusal behaviour and compatibility policy. Attach a repeatable wire observation to the “works” scope rather than treating matching field names as end-to-end proof.

B06 — OMISSION — M1: the provisioning input register still contains NAME ONLY entries.

  Claim: §5 collapses “PROJECT AGENT SERVER REPO REF HARNESS NAMESPACE NAMESPACES … CONFIG_SET_* *_TOKEN_FILE …” into one config-keys row.

  Evidence: CF/scripts/bunker-provision.sh:38–50 initializes these independently; :65–92 implements namespace precedence and normalization; :110–118 loads separate input classes; :128–134 maps independent configuration overrides; :564–609 implements CLI overrides. A generic KEY=VALUE range does not give these settings’ individual defaults, accepted values or consequences.

  Fix: register each operational input individually, including namespace precedence, credential-file selectors and CONFIG_SET_* controls. State required/unset behaviour and distinguish syntactic validation from semantic validity.

B07 — UNVERIFIED — M1, M2, M5, M7, M10, M11, M12: behavioural acceptance evidence is still missing.

  Claim: verification tables retain “not run this round,” “needs a live node,” “no App creds,” or historical single-host results.

  Evidence: M1 §7 certification; M2 §7 bus-worker ladder; M5 §7 conformance; M7 §7 token mint; M10 §7 signed-read ladder; M11 §7 live jobs; M12 §7 valid-token/disallowed-model admission. Compile checks cannot substitute for these behaviours. DISP/tests/test_durable_job.py:7–11 prints a result without asserting it.

  Fix: provide concrete, runnable prerequisites and failure-capable behavioural checks, with captured outputs and source revisions. I did not execute authenticated node certification, credential minting or paid harness jobs in this review; those outcomes remain unverified, not implicitly passing.

B08 — OMISSION — M2: add_family_lanes.py is inventoried but its controls and mutation sequence are not documented.

  Claim: §5 supplies registers for load_lane_config.py and configure_family.py, but not add_family_lanes.py.

  Evidence: CF/scripts/add_family_lanes.py:14–32 selects the scheduler/API and obtains its credential from the service process; :50–65 fixes the lane set; :69–82 creates directories and performs API mutations; :87–96 then updates the scheduler database directly.

  Fix: document this script’s inputs, credential acquisition, API/SQL write sequence, partial-failure behaviour, defaults and readback. “Structure-mapped only” is an admission of unfinished coverage, not a completed submodule.

B09 — FALSE CLAIM — M2: missing credentials are described as remote authentication failures when the worker refuses locally.

  Claim: the --key row says a missing key breaks signing and “the reply is unsigned or refused”; --token-file says a missing token produces “401 on the inbox read.”

  Evidence: CF/scripts/node-bus-worker.py:1278–1290 returns before polling when the key cannot be loaded; :1291–1294 returns locally when no bearer is available. The first network health request is at :1302, after both checks.

  Fix: document the actual local signing_key/bus_bearer refusal and absence of outbound inbox/reply requests. Add negative tests that assert this ordering.

B10 — OMISSION — M2: one failed delivery prevents later successful results in the batch from entering the seen-cache.

  Claim: §11 describes the sequence as recording results “only after delivery succeeds.”

  Evidence: CF/scripts/node-bus-worker.py:1389–1395 uses a cumulative delivered_ok variable. Once it becomes false, a later deliver() still executes, but the successful later result is not inserted because the cache condition tests cumulative batch success.

  Fix: document this additional duplicate-execution window, separate from the already documented same-batch duplicate and crash-before-persistence cases. If corrected in code, use per-result delivery success for caching and a separate aggregate for batch acknowledgement.

B11 — UNVERIFIED — M3: hook presence still does not prove commit-gate enforcement.

  Claim: §1 and §11 correctly admit S3 enforcement is UNVERIFIED.

  Evidence: CF/scripts/install-gitreins.sh:59–63 checks an executable file containing “gitreins”; :120–138 writes or retains that file. The generated hook exits successfully when policy is absent (:130–131). None of these observations establishes the effective core.hooksPath or proves a rejected commit cannot advance HEAD.

  Fix: supply the missing disposable rejecting-commit oracle, resolving effective hook configuration and asserting the before/after commit identity. Keep S3 blocking until that evidence exists.

B12 — OMISSION — M4: the drift checker’s controls are missing from the settings register.

  Claim: §5 registers boardctl controls but does not register board_drift.py’s verification selectors.

  Evidence: CF/scripts/board_drift.py:193–199 exposes --workdir, --ref, --repo, --published-dir and --no-head. In particular, --no-head changes what the check proves; selecting a different ref or published directory changes the comparison authority.

  Fix: add default/range/consequence/reader entries for these controls, including an explicit statement of which proof --no-head removes.

B13 — OMISSION — M5: project-node.sh’s scope controls are undocumented despite changing certification semantics.

  Claim: S3 includes project-node.sh, but its controls are absent from §5.

  Evidence: CF/scripts/project-node.sh:37–49 reads NODE_PROJECT, NODE_HARNESS, NODE_REF, NODE_GATEWAY_PORT, NODE_ROLE and NODE_KINDS; :59–82 parses the CLI. Lines 20–28 explicitly state that --layers is not node certification and suppresses node.json writing even under --apply. Lines 110–136 validate --kinds and change the toolchain evidence population.

  Fix: register the node entrypoint’s settings and explain scoped-check versus full-certification output. Omitting this distinction lets a reader mistake a scoped PASS for a certified node.

B14 — FALSE CLAIM — M6: entrypoint existence is still used as activation evidence.

  Claim: S1 is “active” on “main() entrypoint; structure-mapped,” and S3 is “active” on the existence of main() and its selection glob.

  Evidence: OUTLINE.md:113–119 requires an invoking lane, cron, timer or unit. An executable entrypoint establishes none of these. M6’s S9 row supplies actual panel_loop.py call sites; S1/S3 do not.

  Fix: cite real invoking sites or classify those units as operator-invoked/unproven. Apply the same activation test already used to correct other chapters.

B15 — CONTRADICTION — M6: CT-16 is called working while its named producer does not select this handbook.

  Claim: §6 marks CT-16 “works,” naming master_doc_check.py as the producer of the handbook status word. §1 simultaneously says the legacy checker cannot select M-numbered chapters and is retired for this handbook.

  Evidence: CF/scripts/master_doc_check.py:186–209 selects NN-*.md. Independently running:
    python3 scripts/master_doc_check.py docs/handbook/chapters
  produced:
    FAIL  no module files (NN-*.md) in the resolved root
    0 module(s): 0 VERIFIED, 0 error(s), 0 warning(s), 0 fact(s) in the ledger
    MASTER-DOC: FAIL
    exit 1

  Fix: bind CT-16 to the actual chapter-aware producer/consumer path, or scope the legacy contract explicitly to the appendix corpus. A functioning legacy command is not a functioning handbook-status contract.

B16 — CONTRADICTION — M6: the RED total excludes its own admitted incomplete evidence.

  Claim: §1 says the rest of the documentation pipeline was not read line-by-line; §13 reports only two RED fields, status and metrics.

  Evidence: M4:200–207 defines unread bodies and untabulated inventories as RED, while M6:12 explicitly leaves pipeline bodies unreviewed. M6’s small §9 inventory also does not cover the module-wide emitter surface.

  Fix: count incomplete source and log coverage consistently, or complete that evidence. Do not use a two-field summary to imply that all other schema fields have been established.

B17 — OMISSION — M7: first-install controls remain NAME ONLY.

  Claim: §5’s setup paragraph lists --env-file, --token-file, --app-id, --installation-id, --key-file, --slug, --repo, --org, --name, --api-base and --yes.

  Evidence: CF/scripts/github-app-setup.sh:32–43 assigns independent defaults; :76–95 parses the controls; :102 resolves a default repository. The paragraph does not register individual defaults/ranges/consequences for the listed controls, especially the approval and destination selectors.

  Fix: add the actual per-setting register. The useful write-before-verify analysis does not fill the omitted setting fields.

B18 — OMISSION — M9: auxiliary settings do not satisfy the consequence rule’s complete field contract.

  Claim: §5 calls the auxiliary register “default + consequence,” then admits ranges and reader/precedence have not been verified per flag.

  Evidence: M9:195–228. The table has no range column. SCH/cmd/schedulerd/main.go:174–200 includes simulation, session-reaping and automatic-disable controls with materially different bounds and mutation effects.

  Fix: establish each control’s accepted range, validation behaviour, reader and effective precedence. Group-level prose does not satisfy per-setting registration.

B19 — UNBUILDABLE — M9: the operator surface is a route list, not an operational contract.

  Claim: §3 says all 43 routes are inventoried, but request/response shapes and write-authority readbacks are not written.

  Evidence: M9:39–40 explicitly admits this. Knowing that projects/, pause, resume, hooks or groups exists does not tell an operator how to issue a valid mutation or prove its result.

  Fix: write the run-affecting operator procedures with methods, payloads, authorization requirements, refusal responses and exact readback checks. A route census alone cannot be turned into safe operational work.

B20 — UNBUILDABLE — M9: crash recovery stops at selector names.

  Claim: §3 names write authorities and RecoverExecutionState, then says post-recovery indications remain unwritten.

  Evidence: M9:124–141. The chapter identifies run, attempt, workspace-lease, outbox and projection responsibilities, but gives no executable per-failure recovery/readback sequence.

  Fix: supply procedures distinguishing recoverable work, uncertain settlement, stale leases and pending delivery, with expected observations after every action. Naming a recovery selector is not a recovery procedure.

B21 — OMISSION — M9, M10: emitted metrics still lack the schema-required per-metric contract.

  Claim: both chapters initially describe metrics as “Measured — real, not RED,” then explicitly identify their per-metric registers as RED.

  Evidence: M9:303–307 and M10:220–223 admit missing type/labels/question/scrape fields. MASTER-DOC-SCHEMA.md:72–75 requires those fields. Names, prefixes and aggregate wire shapes are not substitutes for exact metric semantics.

  Fix: fill a per-metric register, including reset/window semantics, exact labels/domains, consumer/scrape location and the operator question answered. Make the section’s leading status agree with its incomplete contract.

B22 — UNVERIFIED — M9: isolated package passes do not establish that the full suite is green.

  Claim: §7 says “The suite is green when packages get an adequate timeout or run quiet” and classifies the observed failures as load artifacts rather than regressions.

  Evidence: the chapter’s actual full-suite observation at 251d11db is FAIL. The cited counterchecks are an isolated scheduler-package pass and an isolated CTL002 pass; they are not a successful full-suite execution under the proposed corrected conditions.

  Fix: report the narrower proven result. To establish the broader claim, capture a complete clean-environment full-suite pass with explicit timeout/parallelism and revision. I did not rerun the long Go suites, so this review does not independently certify that broader result.

B23 — OMISSION — M10: settings coverage leaves run-affecting controls unregistered.

  Claim: §5 supplies a selected control table and a partial storage-selection narrative.

  Evidence: CR/config/config.go:634 and :697–716 implement MCP nudge controls; :656–665 assign federation and database-pool defaults; :771–786 validate database connection counts and their relationship. These settings are absent from the chapter’s register. The chapter also explicitly leaves the serving backend’s custody readback unwritten.

  Fix: derive the register from the real configuration loader, document those controls’ defaults/bounds/consequences, and provide an operator command that establishes the active custody backend rather than merely describing resolution precedence.

B24 — FALSE CLAIM — M11: log levels are presented as emitted attributes although the logger emits none.

  Claim: §9 assigns warn/error/info levels to dispatcher lines.

  Evidence: DISP/dispatcher.py:112–120 accepts one message string and emits only a timestamp plus that message to a file/stdout. Calls such as :97, :422 and :510 do not carry a severity parameter or structured level.

  Fix: mark the actual emitted level as absent. If retaining operator-assigned severity, label it explicitly as inferred classification, not an emitted log level. Document the resulting filtering limitation.

B25 — UNVERIFIED — M12: streaming is demonstrably failing, and the chapter does not ship its completion oracle.

  Claim: §11 quotes a prior independent verifier’s status/header/timeout results but provides no complete repeatable command or shipped test.

  Evidence: PROXY:200–224 sends HTTP/1.1 streaming responses without Content-Length, Transfer-Encoding or connection closure. I exercised the actual Handler against a finite local SSE upstream, without real credentials or provider calls. The probe produced:
    PROXY_STREAM_STATUS=200
    FRAMING={'Content-Length': None, 'Transfer-Encoding': None, 'Connection': None}
    PROXY_STREAM_EOF_COMPLETED=False: TimeoutError

  Repeat command:
    python3 -B /home/kara/.hermes/cache/scratch/round17_judge_probe.py

  Fix: ship a failure-capable, repository-owned framing/completion test and reference its invocation and output. Keep streaming FAILING until that oracle passes. The chapter’s current FAILING status is correct; prior-seat provenance alone does not satisfy repeatability.

B26 — OMISSION — M12: malformed model types escape the documented admission/refusal model.

  Claim: §10 describes malformed bodies as 400 and disallowed models as 403, without naming a handler-crash branch.

  Evidence: PROXY:148 accepts any JSON model value; :155 uses it in set membership without verifying it is a string. The isolated actual-Handler probe sent a valid JSON body containing model=["hermes"] and produced:
    PROXY_HANDLER_EXCEPTION=TypeError
    PROXY_NONSTRING_MODEL_HTTP=RemoteDisconnected

  Fix: document the current disconnect/error indication and add malformed-type admission cases to verification. If repaired, require string validation and prove a stable client error response with no upstream request.

Independent checks that did reproduce:
  disk-floor tests: 12 passed.
  lane-target tests: 40 passed.
  clone-lane tests: 4 passed.
  harness-resolution tests: 28 passed.
  reclaim tests: 9 passed.
  scan-scope gate: 15 claims, RESULT: OK.
  patch-chain gate: 5 stages, 4 patches, VERIFY-PATCH: PASS.
  board validation: 357 tasks, 519 events, RESULT: OK with 7 warnings.
  board drift: identical bytes, 0 divergent IDs, RESULT: OK.
  proxy unauthenticated POST: HTTP 401.
  proxy service: active/running.
  proxy source digest matched the chapter.
  legacy document gate: reproduced 44 modules, 37 declared VERIFIED, 50 errors, MASTER-DOC: FAIL.

These successful checks are credited. They do not close the distinct blocking findings above.

DEFECT CLASSES:

  acceptance-exemption drift
  absent critical-path observability
  missing operational flows
  incomplete log contracts
  incomplete wire contracts
  NAME-ONLY settings
  missing behavioural oracles
  incorrect failure-path description
  batch settlement/cache omission
  hook-presence versus enforcement
  scope-changing controls omitted
  entrypoint versus activation
  wrong-corpus gate attribution
  inconsistent RED accounting
  route census versus procedure
  incomplete recovery ladder
  incomplete metric semantics
  isolated-pass overgeneralization
  invented emitted severity
  unshipped stream oracle
  malformed-input disconnect

CHAPTER SCORECARD:

  M0 — PARTIAL
    Substantial source-backed helper documentation. Metrics remain RED; the boundary-contract exemption does not satisfy the brief.

  M1 — PARTIAL
    Useful provisioning and seed semantics. Config inputs remain incompletely registered, log coverage is incomplete, and certification was not exercised.

  M2 — PARTIAL
    Dispatch decoding and settlement ordering are meaningfully documented. Credential failure descriptions are wrong, add_family_lanes coverage is unfinished, and the cumulative delivery/cache branch is omitted.

  M3 — PARTIAL
    Landing behaviour and gate-by-default limitations are described. Commit-hook enforcement remains unproven; metrics and log completeness remain blocking.

  M4 — PARTIAL
    Store census, semantic validation and published-byte parity reproduced. Drift-check controls are omitted, and boundary-UNVERIFIED accounting weakens the mandated acceptance rule.

  M5 — PARTIAL
    Adapter distinctions and resolver isolation are useful and supported. Conformance remains unrun, project-node scope controls are omitted, and metrics/log coverage is incomplete.

  M6 — PARTIAL
    Legacy-pipeline limitations and spine implementation are substantially described. CT-16 is attributed to the wrong corpus, activation evidence is insufficient for two units, and the RED total omits admitted unfinished coverage.

  M7 — PARTIAL
    Credential-domain separation and refresh effects are useful. First-install controls remain NAME ONLY, mint behaviour is unverified, and the log register is incomplete.

  M8 — PARTIAL
    Reclaim tests and scan-scope behaviour reproduced. The implementation description is comparatively strong; the explicit metrics RED and unresolved boundary evidence still prevent WRITTEN.

  M9 — PARTIAL
    Admission ordering, durable stores and settlement source are substantially documented. Operator/recovery procedures, auxiliary setting ranges, metric contracts and logs remain incomplete; full-suite health is overgeneralized.

  M10 — PARTIAL
    Custody, protected-delivery authorization and guard degradation have meaningful source support. Configuration coverage, backend custody proof, per-metric semantics, module-wide logs and behavioural verification remain incomplete.

  M11 — PARTIAL
    Execution, replay and lossy output retention are well developed. Behavioural tests lack a failure oracle, runtime guarantees remain unverified, emitted severity is misrepresented, and metrics are absent.

  M12 — PARTIAL
    Admission refusal, source identity and stream-framing failure were independently reproduced. Streaming remains failing, its oracle is not shipped, malformed model types disconnect, and metrics are absent.

PANEL REVIEW COMPLETE

session_id: local-52882b9adff4e3023eedefa6cd72c03e07390353c46df60f9b2f90a70e90a8a9

EXIT=0
```

