# CORRECTIONS — round 15

Generated 2026-11-06T21:56:16-0500.

## Verdicts

- **deepseek** — FAIL, blocking 4, 7724 bytes, complete=True
- **glm** — FAIL, blocking 1, 8562 bytes, complete=True
- **grok** — FAIL, blocking 5, 18850 bytes, complete=True
- **kimi** — FAIL, blocking 10, 15480 bytes, complete=True
- **sol** — FAIL, blocking 18, 25324 bytes, complete=True

## Verdict text (verbatim, per seat)

### deepseek

```
Verification complete. Every source claim I independently reproduced matched its cited `file:line` exactly; the spine gate runs clean. The document has converged on accuracy but is not yet callable "written" against its own Part VII.3 bar. Verdict follows.

```
VERDICT: FAIL
BLOCKING: 4 — findings that must be fixed before these chapters can be called written
NON-BLOCKING: 5
```

FINDINGS (blocking):

1. UNBUILDABLE — M6. Claim: the documentation pipeline delivers the handbook ("S5 render", "S9 spine gate" is "the chapter-aware gate"). Evidence (measured this round): `python3 scripts/master_doc_check.py` → `44 module(s): 37 VERIFIED, 50 error(s) … MASTER-DOC: FAIL`, exit 1; `gen_nasa_handbook.py:253-260`, `master_doc_fill.py:422`, `master_doc_check.py:188` all select `[0-9][0-9]-*.md`, which does not match `M0-…-*.md`. The only chapter-aware gate is `handbook_spine.py` (structural; `chapters=13 canonical contracts=18 findings=0`), and there is no render leg — CT-18 (handbook→owner approval artifact) is UNVERIFIED. The document cannot be rendered or pass its own gate. Fix: point the renderer/fill/check globs at `M*.md` (or add a chapter-aware render path) so `MASTER-DOC` can pass over the delivered chapters and CT-18 gains a producer; this is F6-1, carried since round 3.

2. UNVERIFIED (not-measured, closable) — M1/M3/M5/M9/M10. Claim: modules carry `Status: UNVERIFIED (bodies)` because files were read at settings surface only. Evidence: M1 `node_env.py` (589), `node_seed_drift.py` (558), `node_freshness.py` (732), `bunker_config_gen.py` (724) settings-surface only; M3 `repo_freshness.py` body unread; M5 `install-claude-code.sh`/`install-codex.sh` full bodies unread; M9 `tick_process.go`/`packer_select.go`/`namespace_alloc.go` grep-level; M10 1895-line `internal/registry/handler.go` body not line-by-line. Per OUTLINE Part VII.3 these are "not measured" REDs, not "absence proved", so the chapters are not WRITTEN. Fix: read the named bodies line-by-line and re-grade the §3/§5 rows they back; this is the writer's remaining diligence, not a code property.

3. UNVERIFIED (incomplete log inventory) — M9. Claim: "§9 log inventory narrowed to the settlement/batch-dispatch surface (2 of 379 sites)". Evidence: `grep -rn "log.Printf" internal/scheduler/*.go | wc -l` = 379 (reproduced); 377 distinct operator-visible lines untabulated for the control plane's central module. Schema §6 requires every operator-visible line verbatim. Fix: tabulate the 377 remaining `log.Printf` sites (they are distinct strings, unlike the generic `ok`/`bad` helper rows).

4. UNVERIFIED (incomplete log inventory) — M1/M2/M3/M5/M7. Claim: the per-measurement `ok`/`bad`/`warn`/`note` rows are "not inventoried one-per-site". Evidence (measured): M1 108+33=141 sites/5 tabulated, M2 70/4, M3 35/5, M5 215/4, M7 103/2. The chapters correctly name the uncovered count as RED, but the schema field remains unfilled. Fix: either complete the tabulation or get an explicit schema exemption that a generic repeated helper row may be counted rather than enumerated (the OUTLINE's "absence proved" rule).

FINDINGS (non-blocking):

1. Metrics RED across all 13 modules — "absence proved" via quoted `grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics'` → 0 matches (reproduced for M0/M2/M9/M10/M12). OUTLINE Part VII.3 explicitly sanctions a chapter staying RED on metrics as a code property; board rows filed. Not a writing defect.

2. Unrun live-node/credential ladders — M1 certification ladder (`verify-node.sh`), M2 bus-worker ladder (`~/node-bus-worker.py --check`), M5 conformance battery, M10 signed-read ladder, M7 token mint. Environment-gated (no live node / no App creds on this host), honestly UNVERIFIED with named reason. Cannot be closed from here.

3. Code defects correctly surfaced (not writing defects): CF-355 open — verified `dispatchReplyVerdict` (`dispatch_leg.go:713-726`) reads only `payload["ok"]`; `node-bus-worker.py:1180` sends `status`; absence of `ok` = success. M12 F12-7 streaming FAILING — reproduced `_forward` sends no `Content-Length`/`Transfer-Encoding`/`Connection: close` (`cf-inference-proxy.py:206-224`). Both are demonstrated code defects the document carries as OPEN/FAILING.

4. Boundary-contract UNVERIFIED states — CT-01/07/11/12/13/14/15/17 and M12-C1/M12-C2, M7-C1, M1-C1/M1-C2: every side is an external peer (human owner, gitreins/boardctl binary, duckbrain, gateway, GitHub API) with no in-repo `file:function`. The two-register convention (OUTLINE Part IV) sanctions marking the covered side + "external"; honest terminal state, not a rumour-with-verdict.

5. Moving-tree revision drift — M4 §7 claims "HEAD == origin/main == 08a2c8a", but measured `git rev-parse HEAD` = `3fba8a7` (the tailnet-scrub commit) and `board_drift` reports HEAD == origin/main == 3fba8a7. The panel loop committed three times mid-derivation (`9372dc0`, `060c90e`, `242cc47`) plus `3fba8a7`, so chapters carry unsynchronized stamps (M0–M3 `9372dc0`, M4/M5/M7/M8 `08a2c8a`, M6 `242cc474`); the scheduler stamp `7a7afc0f` is one board-commit stale (`81ce9fc`). All cited FILES verified byte-identical through HEAD, so no substance is wrong — only the identity stamps. Fix: re-stamp every chapter to one derivation point and re-run `board_drift`.

DEFECT CLASSES: unbuildable-delivery · not-measured-unread-bodies · incomplete-log-inventory · moving-tree-revision-drift · code-property-red (non-blocking) · environment-gated-unverified (non-blocking) · code-defect-surfaced (non-blocking)

CHAPTER SCORECARD:

- M0 WRITTEN — full read; every helper tabulated; all log lines present; only Metrics RED (absence-proved).
- M4 WRITTEN — store verified 357 rows/519 events, `board_drift RESULT: OK`, 0 divergent ids; contract states honestly UNVERIFIED external; only Metrics RED + the stale HEAD stamp.
- M8 WRITTEN — both files read in full, `test_reclaim` 9/9 + scan-scope 15 claims reproduced; only Metrics RED.
- M11 WRITTEN — full read, complete 23-site log inventory reproduced, `EXEC_TIMEOUT` inert + `CF_DURABLE_JOB` path confirmed; only Metrics RED + decoration tests; F11-8 is a code defect the chapter surfaces.
- M3 PARTIAL — landing arm shipped and run (`SHIPPED_LANDING_ARM_RC=0`); `repo_freshness.py` body unread, hook enforcement unverified.
- M1 PARTIAL — four settings-surface-only bodies, certification ladder unrun, inventory partial.
- M2 PARTIAL — `node-bus-worker.py` contracts verified exactly, but S1 trio structure-mapped, operational overrides NAME ONLY, inventory partial.
- M5 PARTIAL — two full bodies unread, conformance unrun, inventory partial.
- M6 PARTIAL — own gate reads FAIL (44/50), delivery pipeline UNBUILDABLE.
- M7 PARTIAL — mint environment-gated; inventory partial.
- M9 PARTIAL — settlement/admission authority verified exactly (30 tables/43 routes/57 flags/379 log sites reproduced), but S1 grep-level, 2/379 log inventory, per-route/per-write-authority unwritten.
- M10 PARTIAL — ports/defaults/slog surface/91 test files verified exactly; handler body not line-by-line, per-metric contract unfilled, inventory partial.
- M12 PARTIAL — sha256/273 lines/401/LISTEN/sinks reproduced; streaming FAILING (code defect), node-client half unprovable in-repo.

This is the strongest round yet: zero FALSE CLAIMS, zero cross-chapter CONTRADICTIONS (spine = 0), and every spot-check reproduced. The blocker is no longer accuracy — it is the four closable structural gaps above, headed by the fact that the document's own delivery pipeline cannot select or pass it.

PANEL REVIEW COMPLETE

session_id: local-f75323daa36a2f720b9fbdbafe0141e345ac7e9efcfd78f87450c7cbc5028067

EXIT=0
```

### glm

```
│ cache/scratch/ffc_probe_judge.sh
│ @@ -0,0 +1,5 @@
│ +#!/bin/bash
│ +. /home/kara/code-factory/scripts/lib.sh
│ +fetch_verified http://127.0.0.1:1/nothing "$1" deliberately-wrong-digest
│ +printf 'rc=%s artifact=' "$?"
│ +[ -e "$1" ] && echo yes || echo no
All verification complete. Compiling the verdict.

Judge's method note: I read all 13 chapters, the OUTLINE, and the schema, then re-derived ~130 of the chapters' claims against live code (file:line reads across all five systems, re-ran the chapters' §7 commands where repeatable: spine, master_doc_check, verify-patch, board census/validate/drift, the three python unit suites, go build, the M0 fail-closed probe, live 401 on :8775, and the quoted grep censuses). The mandated spine run reported `chapters=13 canonical contracts=18 findings=0` — no blocking CONTRADICTION from that gate.

```
VERDICT: FAIL

BLOCKING: 1 — findings that must be fixed before this chapter can be called written

NON-BLOCKING: 4

FINDINGS:

BLOCKING
1. Kind: UNVERIFIED — chapter M12 (M12-C1, §6). Claim quoted: "matches **four** text
   sites: `scripts/panel_loop.py:145`, `scripts/master_doc_skeleton.py:25` and `:211`,
   … `config/node.env.example:22`". Evidence: re-running the chapter's own command
   (`grep -rnE '8775|CF_PROXY|cf-inference-proxy' scripts/ config/ specs/`) resolves the
   panel_loop hit at `scripts/panel_loop.py:188`, not `:145` — `panel_loop.py` grew in
   `060c90e`/`242cc474` mid-round; M6 re-pinned its own panel_loop locators and says so,
   M12's was not re-pinned and M12 pins no code-factory revision to anchor it. A reader
   following `:145` lands on unrelated code — exactly the spine's documented locator blind
   spot (M6 §10) biting in the round that documented it. Rule 4 violated: the quoted
   measurement does not reproduce as quoted. Fix: re-run the grep at current HEAD, re-quote
   the four sites (`panel_loop.py:188`), and pin the code-factory revision the row was
   measured at.

NON-BLOCKING
2. Kind: CONTRADICTION (self, snapshot) — chapter M4 (§1 vs §7). §7's drift row reports
   "HEAD=origin/main=`08a2c8a`" as re-measured this round while §1 says re-verified to
   `242cc474`; live HEAD is `3fba8a7`. Evidence: my re-run of `board_drift.py check` at
   `3fba8a7` returns `RESULT: OK`, 357 vs 357, 0 divergent ids, and the same
   events.jsonl sha256 `783d556c…` the chapter quotes — the substance reproduces; only the
   HEAD literal is a stale mid-round snapshot and §1/§7 disagree on which snapshot is
   current. Fix: quote the drift result with the commit it was taken at, and make §7
   reference §1's range rather than a second HEAD value.
3. Kind: CONTRADICTION (label drift, systemic) — chapters M0–M3, M7, M8 §1 stamps read
   "code-factory HEAD" = `9372dc0`/`08a2c8a`; HEAD is `3fba8a7` (three same-round commits:
   `060c90e`, `242cc47`, `3fba8a7`). Evidence: `git log`; the cited-file byte-identity
   claims all still hold (`3fba8a7` touched only `_panel/round-9/writer.txt` and the M11
   chapter), so no cited claim is false — but "HEAD" is stale at publication in six
   chapters, and the document issue carries multiple revisions against schema §1's "one
   revision per document issue". Fix: stamp "derivation base" (with the byte-identity
   range, as M9/M10 already do) instead of "HEAD".
4. Kind: CONTRADICTION (accounting) — boundary-UNVERIFIED contract rows are counted as RED
   in M4 (CT-13/CT-14 in its RED count) but the same class of row is not counted in M2
   (CT-11), M8 (local edge), or M10. Evidence: the four chapters' "RED field count" lines.
   Same row class, different scorecard math. Fix: one rule — either boundary-UNVERIFIED
   terminal states are RED everywhere or nowhere.
5. Kind: PADDING-adjacent (cosmetic, not prose) — chapter M12 §6 prints the grep pattern
   with backslashed pipes (`8775\|CF_PROXY\|…`) while labelling it ERE; as printed under
   `-E` it is not the pattern that returns the quoted four sites. Evidence: my clean-ERE
   re-run. Fix: print the pattern exactly as run.

Spine gate: `python3 scripts/handbook_spine.py` → `chapters=13  canonical contracts=18
findings=0`, exit 0 — zero CONTRADICTION findings from the mandated gate.

Otherwise verified true this round (sampled, all exact): M0 every line ref + 11/17 source
counts + fail-closed probe (`rc=1 artifact=no` reproduced); M1 the mode-600 lie (`:214` vs
`:233`), the F1-5 checkout false-green asymmetry, floor precedence, 108+33 counts; M2 the
PID hardcode `1755676`, dry-run 5 s lease, same-batch duplicate window, crier
`HandleRetrieve/HandleDeliver` anchors and `max must be <= 100`; M3 all landing locators,
the hook's `exit 0` when `.gitreins/config.yaml` is absent, `clone_lane` cloning a lane row
not a git repo, arm boundaries `:2463-2729`/`:3433-3670`; M4 357/519 census, validate
`OK (7 warning(s))`, 20 boardctl verbs, `admission_mode.go:230-242`; M5 the `[0-7]00`
predicate vs "must be 600" message, all six pins/digests, the computed `install-$HARNESS.sh`
dispatch, 215 count; M6 gate FAIL `44/37/37→50 errors` exit 1, verify-patch
`5 stages, 4 patches, 57432007…`, spine internals at `:216-374`, panel_loop's inert
`--start-round` and three-way exit-0 semantics; M7 bare exit 2, exact-0600 refusals,
MIN_AGE 2400; M8 constant sets and TTL `<=` boundary; M9 43 routes, 57 flags, all binary
defaults, 30 tables/0 verdicts, `dispatchReplyVerdict` reading only `ok` with
absence-as-success (CF-355 analysis exact), bus payload `board` field/no `run_id`,
LoadRootConfig×10, 379 log sites, `execution_projections` PK, `go build` rc 0; M10 handler
anchors 598/990/1690/1812, retrieve precedence + KNOWN LIMIT verbatim, guard pipeline,
slog=3, 67 metric strings; M11 every settings row incl. the inert `DISPATCH_EXEC_TIMEOUT`
(1 ref) and no-assert tests; M12 sha256 match, live 401, systemd active, unframed-SSE
defect confirmed in code (`:206-224` sends neither Content-Length nor Transfer-Encoding
nor Connection).

DEFECT CLASSES: stale-locator-under-moving-HEAD · snapshot-vs-live-HEAD drift ·
quoted-output drift · inconsistent RED accounting · not-measured REDs (honest, named) ·
decoration tests (M11, named) · carried system defects (CF-355, F12-7 streaming, F1-1,
F1-5 — filed, not writing defects)

CHAPTER SCORECARD:
- M0 — WRITTEN: every sampled claim reproduces incl. the fail-closed probe; sole RED is
  absence-proved metrics (a filled RED per VII.3).
- M8 — WRITTEN: both files read in full, both §7 checks re-run green by this judge; sole
  RED is absence-proved metrics.
- M1 — PARTIAL: three not-measured REDs (four bodies unread line-by-line, certification
  ladder not run on a live node, 5/141 log sites) — honest, but not WRITTEN under VII.3.
- M2 — PARTIAL: live bus-worker ladder not repeatable from the control host; 4/70 log
  sites; §5 overrides registered NAME ONLY.
- M3 — PARTIAL: `repo_freshness.py` body unread; hook *enforcement* UNVERIFIED (the
  landing arm does not prove git invokes the gate); 5/35 log sites.
- M4 — PARTIAL: store fully measured, but CT-13/CT-14 wires UNVERIFIED and the §1/§7
  snapshot contradiction (finding 2).
- M5 — PARTIAL: conformance battery not run; two installer bodies unread; M5-C2 a
  one-sided port contract.
- M6 — PARTIAL: its own gate reads FAIL over the legacy unit corpus (50 errors) and the
  render leg (CT-18) is missing — both named OPEN, correctly.
- M7 — PARTIAL: mint never exercisable on this host (no App creds); M7-C1 UNVERIFIED.
- M9 — PARTIAL: 2/379 log sites; S1 grep-level; per-route API contract and store
  write-authorities unwritten (all named REDs).
- M10 — PARTIAL: 1895-line handler body not line-by-line; per-metric table unfilled;
  log inventory 5 sites; storage-backend proof unwritten.
- M11 — PARTIAL: live-job tests cannot fail (decoration); metrics absence-proved; chapter
  itself edited post-derivation by the tailnet scrub `3fba8a7` (disclosed in git, not in
  the chapter).
- M12 — PARTIAL: streaming completion FAILING (reproduced in code); node-client half
  UNVERIFIED; carries the round's one blocking finding (stale `panel_loop.py:145`).

Document-level: Part II (all 16 flows) remains unwritten — honestly declared MISSING in
OUTLINE and README and cross-referenced from every chapter; not a chapter defect, but the
handbook as a whole is not complete until the flow chapters exist.
```

PANEL REVIEW COMPLETE

session_id: local-1a0d0ce8018a2c819f44511d9139efb28ac74f411ec87f75f367de9a5dcee492

EXIT=0
```

### grok

```
⚠️  Primary auth failed — switching to fallback: fireworks / accounts/fireworks/models/deepseek-v4p1-flash-1017
│ cache/scratch/citecheck15.py
│ @@ -0,0 +1,55 @@
│ +#!/usr/bin/env python3
│ +"""Round-15: resolve every file:line citation and print the cited source line."""
│ +import re, sys, os, glob
│ +
│ +ROOTS = [
│ +    "/home/kara/code-factory",
│ +    "/home/kara/coding-hermes-scheduler/coding-herms-scheduler",
│ +    "/home/kara/coding-hermes-scheduler",
│ +    "/home/kara/crier",
│ +    "/home/kara/crier-fleet",
│ +    "/home/kara/.hermes/scripts",
│ +    "/home/kara/.hermes",
│ +]
│ +CITE = re.compile(r'([A-Za-z0-9_][A-Za-z0-9_./-]*\.(?:py|go|sh|ts|js|yaml|toml|json|db)):(\d+)(?:-(\d+))?')
│ +
│ +def resolve(p):
│ +    p = p.lstrip('./')
│ +    for r in ROOTS:
│ +        c = os.path.join(r, p)
│ +        if os.path.isfile(c):
│ +            return c
│ +    return None
│ +
│ +def main():
│ +    target = sys.argv[1] if len(sys.argv) > 1 else None
│ +    files = sorted(glob.glob('/home/kara/code-factory/docs/handbook/chapters/M*.md'))
│ +    if target:
│ +        files = [f for f in files if target in os.path.basename(f)]
│ +    unfound = []
│ +    for f in files:
│ +        print("=" * 18, os.path.basename(f), "=" * 18)
│ +        seen = set()
│ +        text = open(f, errors='replace').read()
│ +        for m in CITE.finditer(text):
│ +            path, ln, ln2 = m.group(1), int(m.group(2)), m.group(3)
│ +            if (path, ln) in seen:
│ +                continue
│ +            seen.add((path, ln))
│ +            real = resolve(path)
│ +            if not real:
│ +                print(f"?UNRESOLVED  {path}:{ln}")
│ +                unfound.append((os.path.basename(f), path, ln))
│ +                continue
│ +            lines = open(real, errors='replace').read().splitlines()
│ +            if ln > len(lines):
│ +                print(f"?OOR {path}:{ln} (file has {len(lines)} lines)")
│ +                unfound.append((os.path.basename(f), path, f"{ln}>LEN{len(lines)}"))
│ +                continue
│ +            print(f"  {path}:{ln}{'-'+ln2 if ln2 else ''} | {lines[ln-1].strip()[:150]}")
│ +    if unfound:
│ +        print("\n---- UNRESOLVED / OUT OF RANGE ----")
│ +        for u in unfound:
│ +            print(" ", u)
│ +
│ +main()
│ cache/scratch/citecheck15.py
│ @@ -1,6 +1,7 @@
│  #!/usr/bin/env python3
│  """Round-15: resolve every file:line citation and print the cited source line."""
│  import re, sys, os, glob
│ +from collections import defaultdict
│
│  ROOTS = [
│      "/home/kara/code-factory",
│ @@ -13,13 +14,31 @@
│  ]
│  CITE = re.compile(r'([A-Za-z0-9_][A-Za-z0-9_./-]*\.(?:py|go|sh|ts|js|yaml|toml|json|db)):(\d+)(?:-(\d+))?')
│
│ +IDX = defaultdict(list)
│ +for r in ROOTS:
│ +    for dp, dn, fn in os.walk(r):
│ +        dn[:] = [d for d in dn if d not in ('.git', 'node_modules', '__pycache__', '.venv', 'dist', 'build')]
│ +        for f in fn:
│ +            IDX[f].append(os.path.join(dp, f))
│ +
│  def resolve(p):
│      p = p.lstrip('./')
│      for r in ROOTS:
│          c = os.path.join(r, p)
│          if os.path.isfile(c):
│ -            return c
│ -    return None
│ +            return c, None
│ +    if '/' in p:
│ +        sub = [c for c in IDX.get(os.path.basename(p), []) if c.endswith('/' + p)]
│ +        if len(sub) == 1:
│ +            return sub[0], None
│ +        if len(sub) > 1:
│ +            return sub[0], f"ambiguous({len(sub)})"
│ +    cands = IDX.get(os.path.basename(p), [])
│ +    if len(cands) == 1:
│ +        return cands[0], None
│ +    if cands:
│ +        return cands[0], f"AMBIG({len(cands)})"
│ +    return None, None
│
│  def main():
│      target = sys.argv[1] if len(sys.argv) > 1 else None
│ @@ -36,17 +55,18 @@
│              if (path, ln) in seen:
│                  continue
│              seen.add((path, ln))
│ -            real = resolve(path)
│ +            real, note = resolve(path)
│              if not real:
│                  print(f"?UNRESOLVED  {path}:{ln}")
│                  unfound.append((os.path.basename(f), path, ln))
│                  continue
│              lines = open(real, errors='replace').read().splitlines()
│              if ln > len(lines):
│ -                print(f"?OOR {path}:{ln} (file has {len(lines)} lines)")
│ +                print(f"?OOR {path}:{ln} (file {len(lines)}L, {real})")
│                  unfound.append((os.path.basename(f), path, f"{ln}>LEN{len(lines)}"))
│                  continue
│ -            print(f"  {path}:{ln}{'-'+ln2 if ln2 else ''} | {lines[ln-1].strip()[:150]}")
│ +            tag = f" [{note}]" if note else ""
│ +            print(f"  {path}:{ln}{'-'+ln2 if ln2 else ''}{tag} | {lines[ln-1].strip()[:150]}")
│      if unfound:
│          print("\n---- UNRESOLVED / OUT OF RANGE ----")
│          for u in unfound:
│ .hermes/cache/scratch/citecheck15.py
│ @@ -37,7 +37,15 @@
│      if len(cands) == 1:
│          return cands[0], None
│      if cands:
│ -        return cands[0], f"AMBIG({len(cands)})"
│ +        # prefer a candidate long enough to contain the cited line, then the largest file
│ +        sized = []
│ +        for c in cands:
│ +            try:
│ +                sized.append((sum(1 for _ in open(c, errors='replace')), c))
│ +            except Exception:
│ +                pass
│ +        sized.sort(reverse=True)
│ +        return sized[0][1], f"AMBIG({len(cands)})"
│      return None, None
│
│  def main():
│ cache/scratch/ctstate15.py
│ @@ -0,0 +1,46 @@
│ +#!/usr/bin/env python3
│ +"""Compare every chapter's CT state word against OUTLINE Part IV's declared state."""
│ +import re, glob, os
│ +
│ +CH = '/home/kara/code-factory/docs/handbook/chapters'
│ +OUT = open('/home/kara/code-factory/docs/handbook/OUTLINE.md').read()
│ +
│ +# OUTLINE bullets: - **CT-01 owner → scheduler** — ... · **UNVERIFIED (boundary)** ...
│ +outline = {}
│ +for m in re.finditer(r'\*\*(CT-\d\d)[^*]*\*\*(.*?)(?=\n- \*\*CT-|\n\n)', OUT, re.S):
│ +    cid, body = m.group(1), m.group(2)
│ +    st = re.search(r'\*\*(works[^*]*|broken|missing|UNVERIFIED[^*]*)\*\*', body, re.I)
│ +    outline[cid] = (st.group(1).strip() if st else '??')
│ +
│ +def norm(s):
│ +    s = s.lower()
│ +    m = re.search(r'\b(works?|broken|missing|unverified)\b', s)
│ +    return m.group(1) if m else s[:30]
│ +
│ +print("OUTLINE:", {k: norm(v) for k, v in outline.items()})
│ +seen = {}
│ +for f in sorted(glob.glob(CH + '/M*.md')):
│ +    text = open(f).read()
│ +    m = re.search(r'^##\s*6\..*?$(.*?)(?=^##\s)', text, re.S | re.M)
│ +    body = m.group(1) if m else ''
│ +    for line in body.splitlines():
│ +        if not line.startswith('|') or set(line) <= set('|-: '):
│ +            continue
│ +        cells = [c.strip() for c in line.strip('|').split('|')]
│ +        if len(cells) < 6:
│ +            print(f"  ! {os.path.basename(f)}: §6 row with {len(cells)} cells: {line[:90]}")
│ +            continue
│ +        cid = re.search(r'CT-\d\d', cells[0])
│ +        if not cid:
│ +            continue
│ +        cid = cid.group(0)
│ +        st = norm(cells[5])
│ +        seen.setdefault(cid, []).append((os.path.basename(f), st, cells[5][:60]))
│ +
│ +for cid in sorted(seen):
│ +    o = norm(outline.get(cid, '??'))
│ +    for ch, st, raw in seen[cid]:
│ +        flag = '' if st == o else '   <<< DISAGREES WITH OUTLINE'
│ +        print(f"{cid} outline={o:10s} {ch:22s} chapter={st:10s}{flag}")
│ +print()
│ +print("contracts never cited in any chapter §6:", sorted(set(outline) - set(seen)))
│ cache/scratch/spineparse15.py
│ @@ -0,0 +1,14 @@
│ +import sys, glob, os, importlib.util
│ +sys.path.insert(0, '/home/kara/code-factory/scripts')
│ +spec = importlib.util.spec_from_file_location('hs', '/home/kara/code-factory/scripts/handbook_spine.py')
│ +hs = importlib.util.module_from_spec(spec)
│ +spec.loader.exec_module(hs)
│ +for f in sorted(glob.glob('/home/kara/code-factory/docs/handbook/chapters/M*.md')):
│ +    text = open(f).read()
│ +    body = hs.section(text, 6)
│ +    for line in body.splitlines():
│ +        if not line.startswith('|') or set(line) <= set('|-: '):
│ +            continue
│ +        cells = [c.strip() for c in line.strip('|').split('|')]
│ +        if len(cells) != 6:
│ +            print(f"{os.path.basename(f)}: {len(cells)} cells | {line[:110]}")
VERDICT: FAIL
BLOCKING: 5 — findings that must be fixed before this chapter set can be called written
NON-BLOCKING: 4

FINDINGS

1. FALSE CLAIM — M4 (§1 Status, §7 row 3, §9, F4-4)
   Claim: "byte parity identical on both files, 0 divergent ids, HEAD == origin/main == `08a2c8a`", and §7: "HEAD=origin/main=`08a2c8a`".
   Evidence (measured now): `git rev-parse HEAD origin/main` → `3fba8a7eb258264cb957e07add2fbaea30262d70` for both. `python3 scripts/board_drift.py check` re-run returns RESULT: OK but its own line reads "HEAD — git rev-parse HEAD: 3fba8a7e…; HEAD=3fba8a7e… origin/main=3fba8a7e…". The parity substance holds (sha256 5aa15431…/783d556c…, 357 vs 357, 0 divergent ids, both confirmed); the quoted measured sha does not.
   Fix: re-run the drift command and quote its actual HEAD line; do not print a sha the command no longer emits.

2. CONTRADICTION — document-wide, §1 Identity / schema §1 ("One revision per document issue")
   Claims: M0/M1/M2/M3 "Revision = `9372dc0…` (code-factory HEAD, round-15 derivation)"; M4 "`08a2c8a2ea…` (code-factory HEAD at round-11 derivation)"; M5/M7/M8 "`08a2c8a2ea…` (round-11)"; M6 "`242cc47493…` (code-factory HEAD this round)"; M9 "`7a7afc0f` (scheduler repo HEAD, re-stamped round 15)".
   Evidence: actual code-factory HEAD = 3fba8a7; actual scheduler HEAD = 81ce9fcb (`git log --oneline -1` → "board: file SCHED-GAP-16998"), whose diff vs 7a7afc0f is board JSONL only. Five different revisions claim to be "HEAD" in one document issue; two of them are demonstrably not HEAD.
   Fix: one revision per document issue (or per repo, stated once in Part I), all §1 rows and all §9/§7 "Last run, rev" stamps regenerated from it; M4's stamp and M9's "re-stamped round 15" wording corrected together.

3. FALSE CLAIM — M6 §12, M8 §3, §12 and F8-2
   Claim: "ownership is M6.S8 per OUTLINE (`OUTLINE.md:170`)" / "`verify-patch.sh` is **not** an M8 unit — OUTLINE assigns it to M6.S8 (`OUTLINE.md:170`)".
   Evidence: `OUTLINE.md:170` = "**S5 variable contract** (`harness/harness-vars.sh`, matrix §5, sourced by every installer)" — M5.S5. M6.S8 is at `OUTLINE.md:176` ("**S8 patch-chain drift gate** (`verify-patch.sh`)"). Verified identical at HEAD (`git show HEAD:docs/handbook/OUTLINE.md`) and in the working copy; the working-tree OUTLINE diff starts at line 208 and does not touch 170.
   Fix: change both chapters to `OUTLINE.md:176`. (This is the citation class my mechanical locator sweep cannot catch: 317/317 `file:line` citations resolve in range, and this one resolves to the wrong content.)

4. CONTRADICTION (gate false pass) — M2 §6 CT-09, M4 §6 CT-10, M6 §6 CT-16, M12 §6 M12-C1
   Claim: `python3 scripts/handbook_spine.py` → "findings=0", taken as proof the register agrees.
   Evidence: those four §6 rows carry a `|` inside a code span (`grep -nE 'duckbrain|/api/memories' …`, `grep -nE 'boardctl|tasks.jsonl|events.jsonl' …`, `MASTER-DOC: PASS\|FAIL`), so `handbook_spine.py:104-123` splits them into 7–9 cells and slices producer/consumer/state from shifted columns. A re-parse prints exactly those four rows as non-6-cell. Today all four are boundary/local rows (exempt from the both-sides and state checks), so no verdict is currently wrong — but the 0-findings result does not prove the internal pairs agree, and it will silently pass a mis-sliced internal row.
   Fix: make the cell splitter backtick-aware (or require escaped `\|`), and report a row whose column count != 6 as a finding.

5. UNBUILDABLE (document level) — Part II
   Claim: OUTLINE "PART II — FLOWS (16)"; README "II.1 … II.16 … **MISSING**"; every chapter §12 says "flow chapter not written".
   Evidence: `docs/handbook/chapters/` contains 13 files, all `M*.md`, zero flow chapters; README files it as F-ROOT-1. Ten of sixteen flows have no owning chapter anywhere, and F1/F2/F5 are the flows the three primary module chapters say they own.
   Fix: either write the flow chapters or amend OUTLINE Part II to declare the flow set out of scope for this issue — a declared gap is acceptable, an OUTLINE that still promises 16 flows with 0 written is not.

NON-BLOCKING

6. UNVERIFIED (seat scope) — M10, M11, M12. I did not read these three bodies line-by-line; I verified only that their citations resolve, that the spine sees them, and specific rows (M11 §7's decoration rows, M10's contract rows). No seat may grade a chapter WRITTEN that it has not read, so they are PARTIAL by this seat regardless of what a prior round said.

7. FALSE CLAIM (citation repeatability) — M10 `config.go:622`, `config.go:1139-1187`, `handler.go:1711`, `policy.go:172`; M9 `main.go:640`, `main.go:102-208`; M4 `board_lock.py:18`. Bare basenames in repos with many same-named files (my resolver found 281 `config.go`, 276 `handler.go`, 868 `main.go` candidates under the four roots) cannot be repeated by a stranger without guessing. Fix: full relative paths (`internal/config/config.go:622`, `cmd/schedulerd/main.go:640`).

8. PADDING (cumulative) — the round-N correction narrative ("Round-4's … was false", "round-3 draft …", "sol B13", "kimi B42") occupies a large share of M1, M2, M3, M6, M9 and is not operator-usable. The facts it carries are real and often the best content in the chapter; the history belongs in Appendix D, not in §3/§5/§11.

9. OMISSION (gate coverage) — no chapter documents that the spine never verifies a cited line exists, and M6 §10 states it as an M6 blind spot while the spine is the chapter-aware gate (S9). That gap is why finding 3 survived twelve rounds. Fix: one sentence in M6.S9 plus a spine check, or a board row.

What I verified as true, so the next round does not re-litigate it
- Spine: `python3 scripts/handbook_spine.py` → `chapters=13 canonical contracts=18 findings=0`, rc 0 (reproduced).
- Every one of the 317 `file:line` citations resolves to a file of sufficient length; no dangling locator, no out-of-range line.
- Exact reproductions: lib.sh sources 11 direct / 17 total; `tests/test_disk_floor.py` 12 tests OK; helper call sites 108+33 (bunker-provision/verify-node), 35 (land-node-branch), 70 (node-bus-worker), 215 (harness/), 103 (github-app-*), grep counts for `prometheus|Counter|Gauge|Histogram|/metrics` = 0 in every module where the chapter claims 0.
- M4: 357 rows / 519 events; `boardctl validate` → "357 tasks, 519 events, 0 fixtures", "RESULT: OK (7 warning(s))" with exactly the seven warnings named; 20 subcommands, same set; duplicate-id refusal reproduced; drift RESULT: OK.
- M6: `master_doc_check.py` → "44 module(s): 37 VERIFIED, 50 error(s)… MASTER-DOC: FAIL", exit 1; `verify-patch.sh` → 5 stages, 4 patches, 57432007…, PASS; `panel_loop.py:342/352-353` does make `--start-round` inert; the `[0-9][0-9]-*.md` globs at :188/:422/:253 really do exclude `M*.md`.
- M9: 43 routes, 57 flag definitions, 379 `log.Printf`, 30 tables, 10 `LoadRootConfig` sites at exactly 640/673/762/854/870/968/995/1023/1054/1309; CT-02 payload carries `board` and `text_b64` and has no `run_id`; `dispatchReplyVerdict` scores absent `ok` as success (CF-355 real).
- M0/M1/M2/M3/M5/M7/M8 line numbers and defaults: every spot-checked locator matched verbatim, including the two documented code defects (`bunker-provision.sh:233` claims mode 600 while `:214` tests `[ -s … ]`; `harness-vars.sh:203` accepts `[0-7]00` while `:204` demands 600) and the honest self-corrections (M1 F1-5 checkout-WARN asymmetry; M2 F2-3 `dispatch_wall` int() truncation).

DEFECT CLASSES
stale-measured-value · multi-revision-identity · wrong-locator-right-line · gate-column-misparse · declared-scope-gap · non-repeatable-bare-path · correction-history-padding

CHAPTER SCORECARD
- M0 WRITTEN→PARTIAL. Every helper cite exact, counts reproduce, metrics RED absence-proved. PARTIAL only because metrics is RED (schema §5) and §7 stamps an earlier rev than §1.
- M1 PARTIAL. Strongest chapter read: ladder locators, `disk_floor` precedence, seed state machine, 108+33 counts all exact; four unit bodies unread by its own admission.
- M2 PARTIAL. Contracts, reply fields, `dispatch_wall`, dry-run lease 5 s all exact; metrics RED; operational overrides NAME ONLY by its own admission.
- M3 PARTIAL. Landing arm, hook generator, gate-by-default, freshness flags all exact; hook *enforcement* untested (its own RED).
- M4 PARTIAL. Store and validate exact; findings 1 and 2 land here.
- M5 PARTIAL. Installer/resolver/vars registers exact to the line; conformance unrun.
- M6 PARTIAL. Gate behaviour and its own FAIL reproduced; finding 3 lands here.
- M7 PARTIAL. Settings/lifecycle register exact; mint unrun, no App creds.
- M8 PARTIAL. Both units read in full, exact; metrics RED; finding 3 repeats here.
- M9 PARTIAL. Counts, defaults, admission order, store keys exact; 377 of 379 log sites uncovered by its own admission; finding 2 stamps it.
- M10 PARTIAL. Citations resolve, CT rows parse (with finding 4); body not read by this seat.
- M11 PARTIAL. CT-06/CT-03 rows and the `dispatchReplyVerdict` citation exact; body not read by this seat.
- M12 PARTIAL. Local edge row and proxy health line exact; body not read by this seat.
No chapter is SKELETON; none is WRITTEN, and under OUTLINE Part VII three of them (M0, M3, M8) cannot be until metrics exist or a schema exception is approved.

PANEL REVIEW COMPLETE

⚠️ File-mutation verifier: 1 file edit(s) FAILED this turn despite any wording above that may suggest otherwise. Run `git status` or `read_file` to confirm what actually landed.
  • `/home/kara/.hermes/cache/scratch/citecheck.py` — [write_file] Refusing to overwrite `/home/kara/.hermes/cache/scratch/citecheck.py`: `/home/kara/.hermes/cache/scratch/citecheck.py` exists but this task has not seen its full current content (neve…

session_id: local-6c6a4b2cfdae8c27ba15fea21b5db111bf326903a31b7e8f6e74e656898ed67e

EXIT=0
```

### kimi

```
VERDICT: FAIL

BLOCKING: 10 — findings that must be fixed before this chapter can be called written
NON-BLOCKING: 3

Spine run (mandated): `python3 scripts/handbook_spine.py` → `chapters=13  canonical contracts=18  findings=0`, exit 0. No blocking CONTRADICTION is imposed by the spine this round. It cannot see locator existence, submodule counts, or README↔chapter status — the three places this verdict does find defects.

FINDINGS:

B1. FALSE CLAIM — M0, M1, M2, M3
  Claim: Revision `9372dc004be5c5eaa5f49b383079862e0abf4ba8` "(code-factory HEAD, round-15 derivation)".
  Evidence: `git log -1` → `3fba8a7…`; three commits landed after the stamp (`242cc47`, `060c90e`, `3fba8a7`). The content claim is true — `git diff --name-only 47d68b4..9372dc0` over each chapter's cited files returns nothing (`scripts/lib.sh`, `node-bus-worker.py`, `land-node-branch.sh`, `verify-node.sh` etc.), so only the stamp is wrong.
  Fix: re-stamp to `3fba8a7` (or state "derived at 9372dc0; no cited file changed through 3fba8a7") and drop the words "HEAD".

B2. FALSE CLAIM — M9
  Claim: Revision `7a7afc0f` "(scheduler repo HEAD, re-stamped round 15)".
  Evidence: `git log -1` in `/home/kara/coding-hermes-scheduler/coding-herms-scheduler` → `81ce9fcb` "board: file SCHED-GAP-16998". Cited Go files are still byte-identical to `34e44897` (`git diff --name-only 34e44897..HEAD` = both board JSONL + `.qa/chaos-probes/errorpath.sh`, no `.go`), so no locator is invalidated.
  Fix: same as B1 — re-stamp, or say "derived at 7a7afc0f; HEAD has advanced by board-only commits".

B3. FALSE CLAIM — M4
  Claim (§7, verification table): drift re-measured this round with "HEAD=origin/main=`08a2c8a`".
  Evidence: I ran the chapter's own command — `python3 scripts/board_drift.py check --workdir /home/kara/code-factory --ref origin/main` → `RESULT: OK`, `HEAD=3fba8a7… origin/main=3fba8a7…`, parity identical, 357 vs 357, 0 divergent ids, sha256 `5aa15431…`/`783d556c…` (matching the chapter). Only the HEAD value quoted in the row is wrong; a quoted command output that the command does not return is a false claim, not a rounding.
  Fix: re-quote the HEAD line from an actual run.

B4. CONTRADICTION — M10 (self, within §7)
  Claim: same check, two revisions — table row: "`go test ./...` … 2026-11-06, rev `0a372209` (re-run this round) … PASS … `internal/registry` 7.569s"; prose immediately below: "Re-run this round at HEAD `33c1f388` … `internal/registry` 7.488s … the row is a clean PASS at `33c1f388`"; and earlier "ran them in 6.962 s". Three durations, two revisions, one "this round".
  Evidence: chapter lines 147, 154, 164–168. The PASS itself reproduces — `go test -count=1 ./...` at HEAD `0a372209` → rc 0, 0 `FAIL` lines (my first run, under concurrent fleet load, returned an overall FAIL with no per-test FAIL line; the `-count=1` re-run was clean, consistent with the chapter's own flake history).
  Fix: one run, one revision, one duration set; delete the `33c1f388` sentence or mark it as the round-11 measurement.

B5. CONTRADICTION — OUTLINE Part VII.3 (acceptance gate)
  Claim: "A chapter is **WRITTEN** only when its remaining RED fields are all 'absence proved' … " and, four lines later, "a module on the critical path with no metrics can never be WRITTEN until the module emits metrics or the schema explicitly approves a metrics exception".
  Evidence: OUTLINE.md:266–282. Every one of the 13 chapters has an absence-proved metrics RED and no metrics; under the first sentence several are WRITTEN-eligible, under the last sentence none can ever be. README already applies the strict reading ("No chapter is `WRITTEN` this round").
  Fix: state one rule. Until then no chapter can be graded deterministically and the scorecard below is advisory.

B6. CONTRADICTION — README Part III vs M12 §1
  Claim: README table `| III.13 | M12 INFERENCE PROXY | VERIFIED | PARTIAL |`; M12 §1 `Status | VERIFIED (admission/routing/capture), FAILING (streaming)`.
  Evidence: README.md Part III row III.13; M12 line 12 ("**Streaming completion is FAILING** … reproduced as a `200` with no `Content-Length`/`Transfer-Encoding`/`Connection`").
  Fix: one status word per module in both places; a chapter that is FAILING in a submodule is not "VERIFIED" in the index.

B7. CONTRADICTION — OUTLINE Part II heading vs its own rows
  Claim: "**Primary (5, rendered today)**" followed by F1–F5, each marked "*(MISSING)*"; README Part II lists all 16 as **MISSING**.
  Evidence: OUTLINE.md:61–71; README.md Part II table.
  Fix: delete "rendered today" — the phrase asserts a rendered state the document contradicts.

B8. OMISSION — OUTLINE Part I.9 (no home anywhere)
  Claim: I.9 "**What this census does NOT cover** — named areas, and services described only from the client side. Mandatory: a set that claims coverage it does not have was the root complaint in both quorum rounds."
  Evidence: README Part I table stops at I.5 (`I.1`…`I.5`, README lines 21–31); no chapter carries an I.9; the closest thing is 13 per-chapter RED counts, which are not the mandated document-level negative census. The outline calls this field mandatory and it is absent.
  Fix: write I.9 (named uncovered areas: Hermes gateway internals, task-router, duckbrain, boardctl, gitreins, session store, the 40 other fleet projects) or remove the mandate.

B9. OMISSION — Part II: 0 of 16 flows written
  Claim: every chapter's §12 says it — "F1 DISPATCH AND SETTLEMENT … **flow chapter not written**"; "F5 LANDING … **flow chapter not written**"; `docs/handbook/chapters/` contains 13 `M*.md` and no flow file.
  Evidence: `ls docs/handbook/chapters/` (13 files, M0–M12 only); README Part II all 16 rows **MISSING**; OUTLINE Part II specifies 13 mandatory elements per flow. Declared as F-ROOT-1, but a declared omission is still an omission: a reader can describe each module and still cannot operate a run end to end, which is the complaint that produced v2.
  Fix: write F1, F2 and F11 first — the three flows the chapters cite in §12 most often — each with the outline's per-flow element list.

B10. FALSE CLAIM — M12 §6 (M12-C1)
  Claim: the ERE `grep -rnE '8775|CF_PROXY|cf-inference-proxy' scripts/ config/ specs/` "matches **four** text sites: `scripts/panel_loop.py:145`, `scripts/master_doc_skeleton.py:25` and `:211` … and `config/node.env.example:22`".
  Evidence: I ran it — the four text sites are real, but `panel_loop.py`'s match is at **:188**, not :145 (`scripts/panel_loop.py:188:  `/home/kara/crier-fleet`, `/home/kara/.hermes/scripts/cf-inference-proxy.py``). Lines 25, 211 and `config/node.env.example:22` are exact.
  Fix: correct the locator and re-quote the command output.

NON-BLOCKING:

N1. FALSE CLAIM (locator drift) — M9 §6 and M10 §6 both cite the CT-02 producer as `internal/bus/dispatch.go:202` `payload()`. `payload()` is declared at `:175`; `:202` is the `p["text_b64"] = …` assignment inside it. Both chapters agree with each other (which is why the spine passes), so this is a shared locator error, not a disagreement. Fix: `dispatch.go:175` (or `:175-208`).

N2. CONTRADICTION (minor, same chapter) — M9 §3 corrects the route tree to "`Handler()` tree spans `:289-370`, not just `:289-346`", while §13 evidence still lists "`internal/api/server.go:289-346`". Fix: make §13 carry the corrected range.

N3. UNVERIFIED-BY-POLICY — M11 §5 gives `CRIER_URL` default as `http://<bus-host>:8767`, while `dispatcher.py:38` holds a literal address (the round-15 scrub commit `3fba8a7` removed that literal from the chapter and from `_panel/round-9/writer.txt`). The redaction is the right call for a public repo, but the row must say so, otherwise a reader treats `<bus-host>` as a configuration placeholder. Fix: add "(the host literal is redacted; see dispatcher.py:38)".

DEFECT CLASSES:
- stale-revision-stamp (4 chapters claim "HEAD" for a commit that is not HEAD)
- quoted-output-not-reproducible (a measured HEAD value the command no longer prints)
- self-inconsistent-verification-row (one check, two revisions, three durations)
- index-vs-chapter-status-drift (README status disagrees with the chapter it indexes)
- acceptance-gate-ambiguity (rule says WRITTEN is and is not reachable)
- outline-self-contradiction ("rendered today" vs "MISSING")
- mandated-section-absent (I.9)
- whole-part-omission (Part II: 16/16 flows)
- locator-off-by-N (function cited at a field's line; one grep site at the wrong line)
- redaction-not-labelled

REPEATABILITY (rule 4 — stated, not hidden):
Repeated and matched: `handbook_spine.py` (0 findings); `board_drift check` (OK, both sha256s); `boardctl validate` (RESULT OK, 7 warnings, incl. the exact warnings the chapter names — free-form CF-034, priority/title CF-150/CF-192/CF-371, duplicate event id line 337, headerless board); `master_doc_check.py` (44 module(s), 37 VERIFIED, 50 errors, `MASTER-DOC: FAIL`); `test_disk_floor.py` (12), `test_harness_resolve.py` (28), `test_lane_target.py` (40), `test_reclaim.py` (9); `check_scan_scope.py` (15 claims, RESULT OK); lib.sh source counts (11/17); the 108+33, 35, 70 and 103 helper-site counts; scheduler `go build` (rc 0), 57 flags, 43 routes, 30 tables, 379 `log.Printf`, 10 `LoadRootConfig` sites, 8 migration table locators, all sampled `main.go` flag defaults; crier `go build` (rc 0), `go test -count=1 ./...` (rc 0), 1895-line handler, 91 registry test files, 3 slog sites, 67 `crier_*` strings, `crier_client.py` deliver/retrieve/ack at 975/1009/1038; dispatcher 538 lines, 25 `log(` lines, 23 sites, every settings locator sampled, `grep -c EXEC_TIMEOUT` = 1, both "test" scripts contain 0 assert/raise/exit; proxy sha256 `b12a0ac5…` (273 lines), live POST → 401, systemd unit active since 2026-11-05 09:21 PID 2603939 with `10-upstream.conf`.
Not repeated, and therefore UNVERIFIED from this seat: the M3 shipped landing arm (`tests/selftest.sh` `:2463-2729` — 4,852-line whole-file runner with no arm filter, `SHIPPED_LANDING_ARM_RC=0` is the writer's measurement, not mine); the M9 full suite at `34e44897` (275.7 s quiet / 1100 s+ under fleet load — I ran `go build` only); the M1 `verify-node.sh` certification ladder and the M2/M10 node bus-worker ladder (both need a live node; `~/node-bus-worker.py` does not exist on this host, which the chapters already say); the M4 lock fixture; the M10 signed-read ladder. Each of these is already RED in its own chapter, so their absence adds no new blocking finding — but no reader should treat them as seen passing.

CHAPTER SCORECARD:
- M0 SHARED CONTRACT — PARTIAL. 13/13 headings, every claim located and reproduced (`lib.sh:5-9`, `:13`, `:19-42`, `:60-64`, `:67-70`, `:75-78` all exact; 11/17 source counts exact; metrics RED is genuinely absence-proved). Not WRITTEN: stamp says HEAD and is not (B1); metrics RED under the strict reading of VII.3 (B5).
- M1 PROVISIONING — PARTIAL. Strong: port-validation ladder re-pinned to the exact 241-line file (`:40-55`, `:76`, `:225`, `:233-241` all exact), the "six not five" re-apply block is correct, the `--check` "mode 600" lie (`:214`/`:233`) is real. Not WRITTEN: four script bodies unread by its own admission, live ladder unrun, stamp stale (B1).
- M2 DISPATCH — PARTIAL. Core worker locators verified (`:977`, `:1007`, `:1176-1192`, `:1200-1205`, `:1208`, `:1312`, `:1381-1385`, `:1389-1422`), 70 helper sites exact, the same-batch idempotency gap is a real read. Not WRITTEN: 4 REDs (name-only CLI overrides, non-repeatable ladder), stamp stale (B1).
- M3 REPOSITORY — PARTIAL. Clone-is-a-lane-row correction, empty `--gate-cmd` default, hook-presence-is-not-enforcement are all correct and located exactly; the 35-site count is exact. Not WRITTEN: hook enforcement unproven (declared), `repo_freshness.py` body unread, landing arm not repeatable from here, stamp stale (B1).
- M4 BOARD — PARTIAL. Every store number reproduces exactly (357/519, both sha256s, 0 divergent ids, 7 named warnings). Not WRITTEN: §7 quotes a HEAD that the command does not return (B3); lock classifier read but never exercised; metrics RED.
- M5 HARNESS — PARTIAL. Register is the best-developed one in the set (12 declared/6 required CF_* vars exact, per-adapter pins and digests exact, `install-deepseek`/`-pi-agent` refuse `--apply` at the cited lines); F5-5's computed-call-site correction is right (`project-node.sh:439-452`). Not WRITTEN: foreign installer bodies partly unread, conformance battery unrun (CT-17), metrics RED.
- M6 DOCUMENTATION — PARTIAL. The gate reproduces exactly (44/37/50, FAIL, exit 1), the spine anchor lines (`:216-227`, `:234`, `:251`, `:276`, `:300`, `:321`, `:337/:345`, `:357`, `:370`), `gen_nasa_handbook.py:18` and `:253-259`, and `panel_loop.py:323-332` are all exact, including the correct +1 offset a careless reader would doubt. Not WRITTEN: its own gate reads FAIL, the render leg does not select `M*.md` (CT-18 UNVERIFIED), metrics RED.
- M7 GITHUB — PARTIAL. Settings/lifecycle lines exact (`:28`, `:120`, `:127-131`, `:344-352`, `:362`, `:371`, `:579`, `:719-723`), the "M7 does not mint the scoped token" correction is right (`fleet-gh-scope.py` → `gh-app-token.py`). Not WRITTEN: the mint has never run on this host; no canonical contract; metrics RED.
- M8 SAFETY — PARTIAL. Both bodies read in full; TTL scope (`AGED_PARENTS` only, `<=` boundary), protected set, dry-run projections and the empty-selection "OK" all match the code and both commands reproduce. Not WRITTEN: metrics RED only — the closest chapter in the set to WRITTEN, which is exactly what B5 makes undecidable.
- M9 SCHEDULER — PARTIAL. The most load-bearing chapter and the most accurate register I sampled: 57 flags, 43 routes, 30 tables, 379 log sites, 10 bootstrap sites, every sampled flag default and every `admission_mode.go`/`dispatch_leg.go`/migrations locator exact; the CT-06/CF-355 split is argued correctly from `:709-726`. Not WRITTEN: 5 declared REDs, stamp stale (B2), CT-02 locator drift (N1), §13 range drift (N2).
- M10 CRIER — PARTIAL. Counts all reproduce (1895, 91, 3, 67), `go build` and `go test -count=1` green, custody/guard/auth locators exact, and the "supersedes OUTLINE's broken" argument is correct. Not WRITTEN: §7 reports the same run at two revisions with three durations (B4) — the single clearest self-contradiction in the set.
- M11 DISPATCHER — PARTIAL. Read in full and honest about the thing most documents hide: the deadline kill does not reach the GNU-timeout group (`:260`, `:329`), and its own tests cannot fail (verified: 0 `assert`/`raise`/`sys.exit` in both). Every settings locator and all 23 log sites are exact. Not WRITTEN: metrics RED, live-job rows UNVERIFIED, `CRIER_URL` redaction unlabelled (N3).
- M12 INFERENCE PROXY — PARTIAL. Hash, 273 lines, live 401, systemd PID/drop-in, sink paths (`:50`/`:52`) and the `[200, 502]` double-status correction all reproduce; the streaming FAILING verdict is properly distinguished from UNVERIFIED. Not WRITTEN: one stale grep locator (B10), node-client half UNVERIFIED, metrics RED, streaming FAILING.

No chapter is WRITTEN. No chapter is SKELETON — every one carries all 13 headings, a code-derived body, and a RED count; the failures are stamp/locator/gate defects, not absent work.

PANEL REVIEW COMPLETE

session_id: local-2f19fa5f00ba73eefe4e0518d2b67a7d6c91fc74b7886a0ff087d6fce0174eea

EXIT=0
```

### sol

```
│ cache/scratch/round15_judge_probe.py
│ @@ -0,0 +1,100 @@
│ +#!/usr/bin/env python3
│ +"""Read-only source review plus explicitly synthetic isolated probes."""
│ +import ast
│ +import contextlib
│ +import importlib.util
│ +import io
│ +import json
│ +import os
│ +from pathlib import Path
│ +import re
│ +import socket
│ +import tempfile
│ +import threading
│ +import http.client
│ +from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
│ +
│ +ROOT = Path('/home/kara/code-factory')
│ +def load(name, path):
│ +    spec = importlib.util.spec_from_file_location(name, path)
│ +    mod = importlib.util.module_from_spec(spec)
│ +    spec.loader.exec_module(mod)
│ +    return mod
│ +
│ +spine = load('r15_spine', ROOT/'scripts/handbook_spine.py')
│ +chapters = spine.chapters()
│ +inventories = {}
│ +for name, text in chapters.items():
│ +    inventories[name.split('-')[0]] = len(set(re.findall(r'^\|\s*S(\d+)', spine.section(text, 3), re.M)))
│ +print('SUBMODULE_INVENTORIES='+json.dumps(inventories, sort_keys=True))
│ +print('SUBMODULE_TOTAL='+str(sum(inventories.values())))
│ +for label, left, right in [('fraction', '0.85', '0.0'), ('units', '120 s', '120 min')]:
│ +    print('DEFAULT_NORMALIZATION_'+label+'='+json.dumps([left, spine.norm_default(left), right, spine.norm_default(right)]))
│ +# In-memory chapter fixtures only; never edit the actual handbook.
│ +fixture = dict(chapters)
│ +for name, rate in [('M0-shared-contract', '0.85'), ('M8-safety', '0.0')]:
│ +    fixture[name] = fixture[name].replace('## 5. Settings register', '## 5. Settings register\n\n| CF_PANEL_RATE | '+rate+' | positive float | test-only | test-only |', 1)
│ +original = spine.chapters
│ +spine.chapters = lambda: fixture
│ +buf = io.StringIO()
│ +with contextlib.redirect_stdout(buf):
│ +    rc = spine.main()
│ +print('SPINE_IN_MEMORY_FRACTION_CONFLICT_RC='+str(rc))
│ +print(buf.getvalue().strip())
│ +spine.chapters = original
│ +print('HAS_IMPLEMENTATION_BARE_FILENAME='+str(spine.has_fq('does-not-exist.py')))
│ +
│ +# Execute ONLY pure function ASTs from dispatcher, avoiding its imports,
│ +# credential scoper, registry load and main loop.
│ +source = Path('/home/kara/crier-fleet/dispatcher.py').read_text()
│ +tree = ast.parse(source)
│ +nodes = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in {'task_seconds','payload_task'}]
│ +ns = {'CAP_S':7200, 'MARGIN_S':60, 'TASK_S':'240', 'json':json, '__builtins__':__builtins__}
│ +import base64
│ +ns.update(base64=base64, log=lambda msg: None)
│ +exec(compile(ast.Module(body=nodes, type_ignores=[]), '<actual-dispatcher-functions>', 'exec'), ns)
│ +print('DISPATCH_TASK_SECONDS='+json.dumps({str(n):ns['task_seconds'](n) for n in (10,60,120,0)}))
│ +msg = type('Message', (), {'payload':{'text_b64':'not-valid-base64!', 'text':'legacy text'}})()
│ +print('DISPATCHER_BAD_B64_FALLBACK='+ns['payload_task'](msg))
│ +
│ +# Actual proxy Handler; ephemeral loopback upstream and listener, synthetic
│ +# authorization, in-memory logging, no real secrets or production sinks.
│ +proxy = load('r15_proxy', Path('/home/kara/.hermes/scripts/cf-inference-proxy.py'))
│ +class Upstream(BaseHTTPRequestHandler):
│ +    protocol_version = 'HTTP/1.1'
│ +    def do_POST(self):
│ +        self.rfile.read(int(self.headers.get('Content-Length','0')))
│ +        body = b'data: [DONE]\n\n'
│ +        self.send_response(200)
│ +        self.send_header('Content-Type','text/event-stream')
│ +        self.send_header('Content-Length',str(len(body)))
│ +        self.end_headers()
│ +        self.wfile.write(body)
│ +        self.wfile.flush()
│ +    def log_message(self,*args): pass
│ +upstream = ThreadingHTTPServer(('127.0.0.1',0), Upstream)
│ +upstream.daemon_threads = True
│ +proxy.UPSTREAM = 'http://127.0.0.1:'+str(upstream.server_address[1])
│ +proxy.upstream_key = lambda:'synthetic-upstream-key'
│ … omitted 22 diff line(s) across 1 additional file(s)/section(s)
VERDICT: FAIL
BLOCKING: 18 — grouped findings that prevent the affected chapters from being called written
NON-BLOCKING: 0

FINDINGS:

Review scope and reproduced evidence

I read all 13 module chapters, OUTLINE.md, MASTER-DOC-SCHEMA.md, and inspected the implementation paths supporting the findings below. This is a review of the current on-disk documents and code, including existing uncommitted changes—not solely the committed handbook.

Path abbreviations:
  CF = /home/kara/code-factory
  SCH = /home/kara/coding-hermes-scheduler/coding-herms-scheduler
  CR = /home/kara/crier
  DISP = /home/kara/crier-fleet
  PROXY = /home/kara/.hermes/scripts/cf-inference-proxy.py

The mandatory spine command was run and repeated:
  python3 scripts/handbook_spine.py
  chapters=13  canonical contracts=18
  findings=0
  exit 0

Therefore, there are no spine-reported findings to add automatically. Its clean result does not establish compliance with the four admissibility rules; B02 demonstrates a false-negative case.

Independent verification returned:
  Disk-floor tests: 12 passed.
  Lane-target tests: 40 passed.
  Harness-resolution tests: 28 passed.
  Reclaim tests: 9 passed.
  Scan-scope check: 15 claims; RESULT: OK.
  Board validation: 357 tasks, 519 events, 0 fixtures; 7 warnings.
  Board drift: identical task/event bytes; 0 divergent IDs; RESULT: OK.
  Legacy documentation gate: 44 modules, 37 declared VERIFIED, 50 errors; MASTER-DOC: FAIL.
  Patch-chain verification: 5 stages, 4 patches; VERIFY-PATCH: PASS.
  Scheduler: build passed; configuration tests and selected urgency/settlement tests passed.
  Crier: build and the complete uncached Go test suite passed.
  Proxy: documented SHA-256 matched; live unauthenticated POST returned 401; service was enabled and running.
  Isolated actual-proxy-handler probe: healthy SSE returned 200 but reading to EOF timed out.

The complete scheduler suite was not repeated. Live provisioning, credential minting, node certification and harness-conformance operations were not performed. An attempt to execute the isolated shipped landing arm was blocked by the execution approval gate; I do not independently confirm that arm’s published PASS. A live scheduler-metrics readback command was also blocked; B14 is established from the actual return type and implementation, not a claimed live response.

B01 — OMISSION — M2, M10, M11: protected service-delivery authorization is absent from the contracts.

  Claim quoted:
    M2 §6: “works (transport) — crier accepts the reply verbatim.”
    M10 §6 repeats this characterization.

  Evidence:
    CR/internal/registry/handler.go:1147 calls authorizeServiceDelivery before decoding and delivering the request.
    CR/internal/registry/service_auth.go:128-168 requires, for protected recipients, a signed sender, matching body sender, allowed sender→recipient pair, and—when the audience is configured—idempotency_key and the matching audience.
    CF/scripts/node-bus-worker.py:1208-1215 sends a body containing only {"payload": result}; it supplies no body sender or idempotency_key.
    DISP/dispatcher.py:500-508 supplies sender through the Python client but does not supply the protected-delivery idempotency or audience controls at this call site.
    Searching the chapters found no CR_SERVICE_DELIVERY_ALLOWLIST or CR_SERVICE_DELIVERY_AUDIENCE documentation.
    The existing Crier missing-sender rejection test was independently rerun and passed, logging the protected request’s 403.

  Fix:
    Document this authorization layer, its defaults and activation requirements, and the compatibility of each producer. Scope “works” to the measured recipient policy. Do not imply that the currently constructed requests work against protected service recipients. This finding does not assert that protection is enabled on the live relay.

B02 — FALSE CLAIM — M6: the documented setting-conflict check silently discards meaningful differences.

  Claim quoted:
    M6 §3 S9: “setting-default conflicts (`SETTING CONFLICT`, `:321`)”.

  Evidence:
    CF/scripts/handbook_spine.py:150-151 normalizes a numeric default to its initial integer substring.
    An isolated in-memory fixture, without editing the chapters, inserted CF_PANEL_RATE defaults of 0.85 and 0.0 in two settings registers. The actual gate returned exit 0 and findings=0.
    Actual normalization also made “120 s” and “120 min” identical.

  Fix:
    Preserve fractional values and normalize units explicitly. Add regression cases for fractional and unit-bearing defaults. Until repaired, disclose these limits instead of describing the check as general default-conflict enforcement.

B03 — OMISSION — M6: explicit parallel groups can bypass the documented reconciliation pass.

  Claim quoted:
    M6 §5: “`--groups` … explicit section groups (overrides `--parallel`)”.
    The parallel-writing description says the reconcile pass checks the resulting seams.

  Evidence:
    CF/scripts/panel_loop.py:357-370 invokes parallel writers when either groups are supplied or parallel > 1.
    The spine/reconcile block at :383-413 runs only when parallel > 1.
    Thus multiple explicit groups with the default parallel=1 run concurrent writers without that reconciliation block.

  Fix:
    Document the actual condition and the bypass case. Preferably make reconciliation depend on the effective writer-group count, then verify that branch with an isolated test.

B04 — FALSE CLAIM — M9: a settings consequence is contradicted by the implementation.

  Claim quoted:
    M9 §5, num-levels: “0 breaks the priority sort”.

  Evidence:
    SCH/internal/scheduler/urgency.go:18-22 clamps any value below 2 to 2 and logs a warning.
    SCH/internal/config/loader.go:421-422 rejects a configured value below 1.
    The existing urgency-clamping test and configuration suite passed independently.

  Fix:
    Distinguish configuration rejection from constructor clamping. State that 1 is also clamped to 2 by the calculator. Do not substitute an invented sorting failure for the actual rejection/clamping behavior.

B05 — CONTRADICTION — M11 and the schema’s worked example disagree about the actual client contract.

  Claim quoted:
    MASTER-DOC-SCHEMA.md:130-134 says the dispatcher relies on “Crier.send/retrieve/complete”.
    M11 §4 correctly says “retrieve/deliver/ack”.

  Evidence:
    DISP/dispatcher.py:435, :508 and :519 call retrieve, deliver and ack.
    CR/clients/python/crier_client.py:975, :1009 and :1038 define those interfaces.
    The schema example also presents live-job checks as successful proof, while M11 §7 explicitly withdraws that assurance because the scripts lack an adequate failure oracle.

  Fix:
    Correct the worked example against the current dispatcher and client. A normative field-contract document must not teach the obsolete interface and assurance model that its own chapter has corrected.

B06 — CONTRADICTION — M1: the same external edge is simultaneously “works” and UNVERIFIED.

  Claim quoted:
    M1 §6, M1-C2: consumer “rumour — one side only”; state “works (short create/exec/cp calls)”.
    M0 §6 marks the bunker_exec boundary UNVERIFIED.

  Evidence:
    CF/scripts/lib.sh:75-78 establishes only command composition.
    M1 provides neither an implementing consumer function nor a quoted execution result establishing its “works” verdict.
    Its producer is the same bunker_exec helper named in M0.

  Fix:
    Mark the unmeasured edge UNVERIFIED, consistently with M0, or supply the exact measured operation and narrowly scope its state. Do not grant a blanket works verdict to an unnamed, unexercised consumer.

B07 — OMISSION — M1: the settings register does not cover its owned certification controls.

  Claim quoted:
    M1 §5 registers node_freshness settings but has no corresponding node_seed_drift register.

  Evidence:
    CF/scripts/node_seed_drift.py:488-519 exposes agent/server selection, local --home mode, --strict-seed, timeout default 180, JSON output, and timeout validation.
    CF/scripts/verify-node.sh:20-28 separately exposes port, artifact, strict-freshness and strict-seed controls.
    These controls decide target selection and whether an unknown observation becomes FAIL or UNVERIFIED.

  Fix:
    Register the omitted operational controls individually with defaults, accepted values, readers and consequences. Describing some of their behavior elsewhere does not complete the promised settings register.

B08 — OMISSION — M2: critical operational overrides remain NAME ONLY.

  Claim quoted:
    M2 §5 expressly labels --home, identity/key/token selectors, destination, workdir, executable template and gateway-port overrides “NAME ONLY”.

  Evidence:
    CF/scripts/node-bus-worker.py:1442-1476 defines those controls.
    Identity resolution at :385-415 applies their precedence.
    :1520-1526 validates the workdir boundary.
    The register does not give those controls their individual defaults, validation and consequences.

  Fix:
    Complete the rows. These are not incidental switches: they select credentials, execution location, recipient and the executable that receives the directive.

B09 — OMISSION — M3, M5: gate installation’s identity and repository controls are missing from the settings contract.

  Claim quoted:
    M3 §5 registers the GitReins pin and venv, but not the installer’s repository/identity controls; M5’s installation registers do not fill that gap.

  Evidence:
    CF/scripts/install-gitreins.sh:25-29 reads NODE_REPO, GIT_AUTHOR_NAME, GIT_AUTHOR_EMAIL and GIT_CO_AUTHOR.
    :86-87 refuses apply without author name and email.
    :144-157 writes global Git identity and the co-author environment entry.
    :168-171 exposes the corresponding CLI overrides.

  Fix:
    Name one authoritative register and link it from the other chapter. Include defaults, precedence, apply-time refusal, and the persistent effects on Git identity and the Hermes environment file.

B10 — OMISSION — M9: the auxiliary settings table still fails the range requirement.

  Claim quoted:
    M9 §5: “The remaining 33 of the 57” have consequence rows.

  Evidence:
    That table has no Range column and does not state accepted ranges individually.
    SCH/cmd/schedulerd/main.go:165-170 explicitly documents that session-poll-loop-min-ticks values 1–5 clamp to 6; the chapter’s row states only “0 disables”.
    Defaults such as PeerFreshnessWindowDefault and DefaultHermesReapStaleAfter are left as symbols rather than resolved operational values in their rows.

  Fix:
    Supply each setting’s effective default and accepted range, including zero/negative handling and clamping. A completed consequence column alone does not satisfy the brief’s three-part setting rule.

B11 — OMISSION — M9: durable-state keys are documented, but write authority and recovery are not.

  Claim quoted:
    M9 §3: “The write authorities and recovery queries per table are not yet written”.

  Evidence:
    SCH/internal/database/execution_store.go:63 creates execution runs; :247-251 inserts outbox work and advances run state; :369 creates workspace leases; :543 applies a state transition.
    SCH/internal/database/parent_run_store.go contains additional parent lifecycle mutations.
    A table-name/key inventory cannot tell an operator which transition owns the row or how to distinguish recoverable work from uncertain settlement.

  Fix:
    Add the write-authority functions, transaction boundaries, transition predicates, recovery selectors and expected post-recovery indications. Keep S3 PARTIAL until those operational relationships are written.

B12 — OMISSION — M9: a route census is not an operator contract.

  Claim quoted:
    M9 §3: “Per-route request/response shapes and write-authority readbacks are not written”.

  Evidence:
    SCH/internal/api/server.go:289-370 mounts the routes, including evaluate, pause/resume, agent management and federation.
    The chapter supplies their names but not the methods, request shapes, authorization/refusal behavior or readbacks needed to use those surfaces safely.

  Fix:
    Provide source-linked operation contracts, including explicit mutations and the readback proving each effect. An operator cannot derive safe work from the current list alone.

B13 — OMISSION — M10: emitted metric names have not become the schema’s metric contract.

  Claim quoted:
    M10 §8: “the full per-metric type/labels/question/scrape table is a named RED”.

  Evidence:
    CR/internal/registry/handler.go:38-45 defines concrete delivery and guard-decision counters.
    CR/internal/guard/metrics.go defines the guard counters and duration histogram.
    The chapter groups many remaining families under wildcard names without their individual types, label domains or operational questions.

  Fix:
    Complete the per-metric table for the runtime series. Keep test-only strings and histogram exposition components separate from independently defined metrics.

B14 — FALSE CLAIM — M9: not every metrics block carries available.

  Claim quoted:
    M9 §8 says the blocks are “each carrying an available: true|false honesty shape”.

  Evidence:
    SCH/internal/api/server_metrics.go:65-70 defines the successful tickDurationMs shape with count, window and percentile fields—but no available field.
    :451-459 returns that struct directly.
    The unavailable error path at :76-81 is a different shape containing available:false.

  Fix:
    Document the actual successful and unavailable schemas separately, including the empty-sample null percentiles. Do not infer the wire contract from the file’s introductory comment.

B15 — UNVERIFIED — M0–M8, M11, M12: measured absence of metrics still blocks WRITTEN under the current schema.

  Claim quoted:
    These chapters’ §8 fields state “RED — none”.

  Evidence:
    MASTER-DOC-SCHEMA.md:72-79 explicitly makes “none” a RED field.
    The chapters disclose the absence; searches of the inspected helper, safety, node-worker, credential-minter, dispatcher and proxy implementations reproduced no metric-registry matches.
    This is not a finding that the authors concealed the absence. It is an unsatisfied acceptance requirement.

  Fix:
    Supply the required observability, or obtain an explicit schema-approved exception for appropriately scoped components. Do not promote these chapters to WRITTEN merely because the absence was honestly measured.

B16 — OMISSION — M1, M2, M3, M5, M6, M7, M9, M10: the operator-visible log contract is incomplete.

  Claim quoted:
    Multiple chapters expressly say their generic rows or remaining emitters “are not inventoried one-per-site”.
    M6 lists only the legacy checker’s principal output rows.

  Evidence:
    The schema requires every operator-visible line, condition and descriptive/evidentiary classification.
    CF/scripts/panel_loop.py:442-456 alone has distinct acceptance, no-new-class and cap-reached stop lines absent from M6’s table.
    The other affected chapters explicitly retain uncovered log surfaces, including scheduler and Crier emitters.

  Fix:
    Inventory the owned emitters with their trigger and evidentiary meaning. A coverage count or declaration of an uncovered remainder is useful evidence of incompleteness, not completion of the field.

B17 — UNVERIFIED — M1, M2, M3, M4, M5, M7, M11, M12: decisive behavioral verification remains missing or unreproducible.

  Claim quoted:
    Published rows include “not run this round”, “not repeatable from this control host”, hook enforcement “UNVERIFIED”, and live-job tests described as “decoration”.

  Evidence:
    M1 §7 leaves certification unrun.
    M2 §7 leaves the node-side signed bus ladder unverified.
    M3 §1/§11 does not prove Git invokes the effective installed hook.
    M4 §7 leaves the held/unheld lock fixture unexercised.
    M5 §7 leaves conformance unrun.
    M7 §7 leaves authenticated minting unrun.
    M11 §7 lacks an adequate execution/termination failure oracle.
    M12 §7 leaves authenticated disallowed-model admission unrun.
    Parsing and unit checks do not establish those properties.

  Fix:
    Provide executable, bounded verification procedures and captured results for the relevant artifact revision. Use disposable fixtures where possible. Keep unavailable live checks explicitly UNVERIFIED; do not substitute compilation or source reading for behavioral proof.

B18 — FALSE CLAIM — M11: the absence consequence overstates the dispatcher’s authority.

  Claim quoted:
    M11 §2: “No task leaves the bus: every dispatch sits in the inbox until it expires.”

  Evidence:
    CF/scripts/node-bus-worker.py independently retrieves inbox messages at :1320-1340, processes them at :1374, invokes the harness at :1148-1149, delivers replies at :1389-1395 and acknowledges afterward.
    Its independent entrypoint at :1528-1539 does not require DISP/dispatcher.py.
    M2 and M10 also identify it as the other inbox consumer.

  Fix:
    Restrict the absence consequence to agents served by the control-host dispatcher. Explain the distinction between the two consumer arrangements and what deployment evidence determines which one an agent uses.


DEFECT CLASSES:

  Missing authorization preconditions
  Gate false negatives
  Parallel-path omission
  Incorrect setting consequences
  Contradictory normative example
  Unsupported contract verdict
  Incomplete settings registers
  Missing state-transition authority
  Name-only operator surfaces
  Incomplete metric contracts
  Incorrect response schema
  Unsatisfied observability requirement
  Incomplete log inventory
  Missing behavioral proof
  Overstated failure blast radius


CHAPTER SCORECARD:

M0 — PARTIAL
  The helper inventory and source-count claims were corroborated. The metrics field remains RED; the external bunker edge is unverified. No basis for WRITTEN under the present acceptance contract.

M1 — PARTIAL
  Useful provisioning, seed and certification detail, but certification remains unrun, owned controls are missing, log coverage is incomplete, and M1-C2 carries an unsupported works verdict.

M2 — PARTIAL
  Directive decoding, reply shape and settlement ordering are source-grounded. Operational overrides remain NAME ONLY, the live ladder is unverified, and protected service-delivery compatibility is omitted.

M3 — PARTIAL
  Landing and hook limitations are substantially described. Effective hook enforcement remains unproved; installer identity controls and log coverage are incomplete. The landing-arm PASS was not independently reproduced because execution was blocked.

M4 — PARTIAL
  Store census, semantic validation and byte parity were independently reproduced. Lock behavior remains unexercised in the published verification record, external write contracts remain unverified, and metrics are absent.

M5 — PARTIAL
  Resolver tests passed and adapter differences are documented. Live conformance remains unrun, installer controls are incomplete, and the metric/log requirements remain unsatisfied.

M6 — PARTIAL
  The spine and patch chain run, and the legacy checker’s 50-error failure was reproduced. The spine misses meaningful default conflicts; explicit-group reconciliation is incompletely described; the delivery pipeline and log contract remain incomplete.

M7 — PARTIAL
  The bare CLI refusal and source-described credential handling are grounded. Authenticated minting was not exercised; the external exchange and full log contract remain unverified/incomplete; metrics are absent.

M8 — PARTIAL
  Reclaim tests and the scan-scope command passed. Target sets and TTL behavior agree with the inspected code. The current schema’s RED metrics requirement still prevents WRITTEN.

M9 — PARTIAL
  Build, selected tests and the 30-table census were corroborated. Incorrect setting and metrics-schema claims remain, and the settings, durable-state, operator-surface and log contracts are incomplete.

M10 — PARTIAL
  Build and the complete uncached test suite passed. Protected service authorization is omitted from the chapter, and metric/log contracts remain incomplete. A green repository suite does not fill those document fields.

M11 — PARTIAL
  Job, ledger and completion paths were read against the code; budget behavior was independently probed. The absence consequence is false, decisive execution/termination proof remains missing, and the schema example contradicts the current client contract.

M12 — PARTIAL
  Hash, live unauthenticated refusal and service state were corroborated. The healthy-stream EOF defect was independently reproduced with the actual handler against an isolated finite upstream. Authenticated admission and boundary contracts remain unverified; metrics are absent.

PANEL REVIEW COMPLETE

session_id: local-2daeaf5466c0206307da597c329fb00a56c2173feec5c6f5ac55cc761066a158

EXIT=0
```

