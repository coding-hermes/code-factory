# M6 — DOCUMENTATION

## 1. Identity

| Field | Value |
|---|---|
| Module name | DOCUMENTATION |
| Path | `/home/kara/code-factory/scripts/` — `master_doc_skeleton.py`, `master_doc_fill.py`, `master_doc_check.py`, `master_doc_panel.py`, `gen_nasa_handbook.py`, `gen_system_views.py`, `sheet_style.py`, `extract_owner_decisions.py`, `gen_unit_map.py`, `verify-patch.sh`, `panel_loop.py`, `ownership.py`, `handbook_spine.py` |
| Revision | `fbc19cbc807de729e25c358fa7e94207b912f010` (code-factory HEAD; `panel_loop.py` was rewritten for `--groups`/`--parallel` and `panel_supervise.sh`/`reap_orphan_writers.py` were added in `08a2c8a..fbc19cb`; every M6 file:line re-pinned) |
| Language / runtime | Python 3.14.9 (measured) |
| Owner lane | code-factory (control host) |
| Status | **UNVERIFIED** — `master_doc_check.py` (268 lines) read in full and its FAIL reproduced; the rest of the pipeline (`master_doc_fill.py`, `gen_nasa_handbook.py`, `master_doc_panel.py`, `gen_unit_map.py`, …) not read line-by-line; the gate reads `MASTER-DOC: FAIL`. **The legacy fill/render/panel pipeline is UNBUILDABLE against these M-numbered chapters** (B13): `master_doc_check.py:188`, `gen_nasa_handbook.py:253-260` and `master_doc_fill.py:422` all select `[0-9][0-9]-*.md`, which does not match `M0-…-*.md`, so the legacy pipeline cannot select or deliver these chapters. **The chapter-aware gate is `handbook_spine.py` (S9)**, which *does* select `M*.md` and exits 1 on any finding (`python3 scripts/handbook_spine.py` → `chapters=13 canonical contracts=18 findings=0`, exit 0); the legacy fill/render/check pipeline is retired for the M-numbered handbook, and the render-to-owner-artifact leg remains missing (CT-18 UNVERIFIED, §6) |

## 2. Purpose, authority and position

The system's description of itself, and the gate that checks the *structure* of that description.
`master_doc_check.py` validates headings, locator existence/bounds and citation requirements, then
**reports the document's declared status — it does not recompute it** (F6-2).
`panel_loop.py` is the loop this handbook chapter is a product of.

**What breaks if this module is absent.** The gate that grades the description is gone: a document
can lose its structure, cite lines that no longer exist, or stamp VERIFIED without locators, and
nothing refuses it. Concretely, without `master_doc_check.py` the empty-selection PASS returns — a
root with zero `NN-*.md` modules printing a vacuous `MASTER-DOC: PASS` — which is the exact failure
the gate now names at `:191-209` instead of silently passing.

**What breaks if it lies.** Two distinct failure modes:
- The PASS-over-zero failure (fixed): `DEFAULT_ROOTS` (`master_doc_check.py:52`) falls back to
  `docs/handbook/appendices/units`, and an empty selection is a named failure (`:191-209`).
- **The gate is a structural/citation gate, not a semantic truth verifier (F6-2).**
  `master_doc_check.py:128-138` reads the document's *supplied* status and imposes citation
  requirements (`VERIFIED` needs >=3 locators and at least one cited FACT-nn); `:214-216` retains
  and counts that supplied status. It does **not** verify that cited code supports the prose. The
  live result — `44 module(s): 37 VERIFIED, 50 error(s)`, `MASTER-DOC: FAIL` — shows 37 unit sections
  stamped VERIFIED alongside 50 errors: the stamp is the document's own claim, re-emitted, not a
  re-derivation of truth.

## 3. Submodule inventory

| Submodule | Unit | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 skeleton + census | `master_doc_skeleton.py` | **active** | `main()` entrypoint; structure-mapped |
| S2 fill | `master_doc_fill.py` | **operator-invoked** | `main()` (`:393`); `--engine api|hermes`, `--workers 2`, `--provider deepseek` (`:394-411`); no in-repo production caller |
| S3 gate | `master_doc_check.py` | **active** | `main()` at `:160`; selects `[0-9][0-9]-*.md` at `:188` |
| S4 panel | `master_doc_panel.py`, `panel_loop.py`, `ownership.py`, `panel_supervise.sh`, `reap_orphan_writers.py` | **active** (panel), **optional** (ownership) | `panel_loop.py` runs this loop; `panel_supervise.sh` supervises it and restarts on crash/cap/provider outage (`panel_supervise.sh:30` `while true`); `reap_orphan_writers.py` kills writer sessions whose parent round died (ppid==1 + the writer-prompt signature, `reap_orphan_writers.py:47-49`); `ownership.py` has no code caller (`grep -rn ownership.py scripts/` → self only) |
| S5 render | `gen_nasa_handbook.py`, `gen_system_views.py`, `sheet_style.py` | **operator-invoked** | `gen_nasa_handbook.py:247` `main()`; no in-repo caller (`grep -rn gen_nasa_handbook scripts/` → only `gen_unit_map.py:31` NOT_CALLERS) |
| S6 corpus | `extract_owner_decisions.py` | **operator-invoked** | no in-repo caller (grep empty) |
| S7 unit-map | `gen_unit_map.py` | **operator-invoked** | `main()`; no in-repo caller |
| S8 patch-chain drift | `verify-patch.sh` | **operator-invoked** | no in-repo caller, no cron/timer; run manually (VERIFY-PATCH: PASS) |
| S9 spine gate | `handbook_spine.py` | **operator-invoked** (run manually) | `python3 scripts/handbook_spine.py` — the cross-chapter consistency gate that *does* select `M*.md` chapters (the legacy `[0-9][0-9]-*.md` globs in `master_doc_fill.py`/`gen_nasa_handbook.py`/`master_doc_check.py` do not). What it actually enforces (verified against `handbook_spine.py:178-336`): (1) each canonical id CT-01..CT-18 is **cited** — it does **not** reject an unknown CT id (B01: an injected CT-99 passes rc 0); (2) cross-chapter producer/consumer **function-token** and **state-word** agreement for the 5 internal contracts only; (3) setting-default conflicts where `norm_default` yields a comparable value — it strips backticked spans, so defaults cited in different backtick refs compare equal, but a backticked-only default normalizes to '' (B01: `norm_default('`alpha`')` = ''); (4) dangling M/F references; (5) prose count claims (module/chapter/flow/contract — `submodule` is `None` at `:308`, so no submodule count is ever compared) |

A prose classification ("render the handbook", "extracts owner decisions",
"measures who references a unit", "chain-break detection") does not satisfy the classification rule,
which requires the
invoking line; a repo-wide grep finds no invoker for any of S5–S8 (only self-references and
`gen_unit_map.py`'s own `NOT_CALLERS` set at `:31`). They are **operator-invoked (optional)**.

**Finding F6-3.** `scripts/ownership.py` (170 lines) decides who owns the canonical checkout before
a lane blocks on it (`status`/`claim`/`release` over `.coding-hermes/panel.lock`). No script
invokes it; the writer/judge session runs it manually. Classification: **optional**.

## 4. Dependencies

**4a. Runtime dependencies**

| Dependency | Version constraint | Where | How absence is detected |
|---|---|---|---|
| python3 | 3.x | control host | import/compile failure |
| hermes CLI (fill engine) | on the host | `--engine hermes` | `master_doc_fill.py` engine switch |

**4b. Library contracts**

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `sheet_style.py` | this repo | render language for the sheets | a style change rewrites every sheet |
| `yaml` (PyYAML) | external | `gen_unit_map.py:20` `import yaml` — required to parse `docs/UNIT-MAP.yaml` | an absent PyYAML breaks the unit-map generator, not the gate |
| `/usr/bin/google-chrome` | external binary | `gen_nasa_handbook.py:305` invokes it headless with `--print-to-pdf`, 900 s subprocess timeout (`:315`) | an absent chrome (or a page that exceeds 900 s) fails the PDF render |
| `gen_unit_map.py` | this repo | measures trigger (who references a unit, the line text) | a wrong trigger mis-classifies active vs legacy |

**4c. Service contracts** — see §6.

## 5. Settings register

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `CF_MASTER_DIR` | unset | a directory | overrides root resolution (`master_doc_fill.py:26`, `master_doc_check.py:67`) | pointing it at a nonexistent dir yields a named failure |
| `DEFAULT_ROOTS` | `("docs/master", "docs/handbook/appendices/units")` (`:52`) | existing dirs | root discovery order | `docs/master` no longer exists, so the gate resolves to `appendices/units` |
| fill `--engine` | `api` (`master_doc_fill.py:409-412`) | `api` / `hermes` | which seat fills a module | `hermes` runs a real seat; `api` is one completions call |
| fill `--workers` | 2 (`:396`) | positive int | parallel fill workers | **0 or negative raises `ValueError: max_workers must be greater than 0`** — there is no serial fallback; `1` is serial execution (`ThreadPoolExecutor(max_workers=a.workers)` at `:450`) (B14) |
| fill `--provider` | `deepseek` (`:397`) | a `PROVIDERS` key | fill provider | an unknown provider is refused |
| fill `--limit` | 0 (`:395`) | int | cap on modules filled in one run | 0 = no cap; a positive N fills only the first N candidates |
| fill `--force` | false (`:401`) | flag | refill modules already FILLED/VERIFIED | without it, already-complete modules are skipped |
| fill `--only` | `""` (`:404`) | comma prefixes | narrow the candidate set (e.g. `05-,07-`) | a prefix matching none yields an empty run |
| fill `--model` | `""` (`:411`) | a model id | the seat model for `--engine hermes` | empty falls back to `openai/gpt-6.1-sol` (`:454`) |
| fill `--dry-run` | false (`:413`) | flag | list candidates without provider calls or writes | **`--dry-run` suppresses all provider calls and writes** (`:438-440`); `--force` decides *which* documents may be rewritten — the documented five controls omit the switches that decide whether writing or provider execution occurs (B11) |

**Spine gate (S9, B5).** `handbook_spine.py` carries no settings surface;
its policy is four hardcoded sets: `CANON` (the 18 contract ids + expected producer/consumer
systems), `BOUNDARY` (the **13** boundary contracts whose far side is a human/LLM/service with no
in-repo file), the `SETTING_ROW`/`REF`/`COUNT_CLAIM` regexes, and the internal-vs-boundary split
that decides which contracts must name both `file:function`. The defect this gate closes:
its predecessor compared function tokens but never the **state** column, so M9 ("broken") and
M11 ("works") could both cite CT-06 and pass while flatly disagreeing. The state-agreement check
(and the CT-05 boundary→internal re-grade) are part of the gate; the remaining blind spots are that
it does **not** verify cited line numbers exist in the cited file, and it trusts the chapters'
self-reported status word rather than re-deriving it.

**`panel_loop.py` settings and stop semantics (B14).** The loop that
produces this handbook carries its own controls; a process exit 0 is **not** document acceptance:

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `--rounds` | 6 (`:323`) | int; **0 = no cap** (`:340` maps 0 → `10**9`) | **absolute round ceiling** — the loop condition (`:351` `while st["round"] < rounds`) compares the *stored* round against `--rounds`; it does **not** count iterations from `--start-round` (B12) | a cap is a session budget, not a definition of done |
| `--max-seconds` | 21000 (`:324`) | int; 0 = no cap (`:341` budget) | the wall-clock budget | same |
| `--start-round` | None (`:325`) | int | **inert for the loop body** — `:342` (`rnd = args.start_round or (st["round"] + 1)`) sets only the printed "start round" value, then `:352` (`rnd = st["round"] + 1`) overwrites it from stored state before each writer runs, so the loop always resumes at `st["round"] + 1` (B12) | the flag does not resume at a specific round as its help implies — it is an inert override |
| `--writer-timeout` | 4200 (`:326`) | seconds | writer session deadline | too short kills the writer mid-round |
| `--judge-timeout` | 2700 (`:327`) | seconds | judge session deadline | too short yields MISSING seats |
| `--chapters` | "" (`:328`) | comma list | narrow the chapter set | empty = all chapters |
| `--groups` | "" (`:329`) | `M0,M1;M4,M5` semicolon-separated | explicit section groups (one writer per group, PANEL-LOOP's `--groups`) | overrides `--parallel`; a wrong grouping splits a contract seam across writers |
| `--parallel` | 1 (`:331`) | int | writers per round (0/1 = single writer) | >1 splits chapters by interleaved slice when `--groups` is absent (`:365-366`) |
| `PANEL_WRITER_MODEL` / `PANEL_WRITER_PROVIDER` | `deepseek-v4-pro` / `deepseek` (`:37-38`) | env override | writer seat model/provider | a wrong model runs the writer on an unmeasured seat |
| `FANOUT` / `MANIFEST` | hardcoded `cf-quorum-20261104` scratch paths (`:34-35`) | a path | the external fanout script + seat manifest | a dated scratch dir that no longer exists breaks the loop |

**Stop semantics (distinguish process success from acceptance).** `panel_loop.py:442-457` exits 0
on three conditions: unanimous PASS (`:445`), `clean_streak >= 2` (`:447-451`) — two consecutive
rounds with no *new defect class*, **even while blocking findings remain open** — or the cap
(`:456`). A `STOP: no new defect class` exit is a successful process termination, not proof the
document is aligned; the operator must read back the outstanding findings (the `CORRECTIONS.md`
per round) separately.

## 6. Contracts in and out

Canonical ids are the register of record (OUTLINE Part IV, CT-01..CT-18). Local ids are
retired; each row carries the CT id its peer chapter cites.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| CT-16 | docsgate | out | `master_doc_check.py:263` prints `MASTER-DOC: PASS|FAIL` | **external** — "the handbook's status word", no in-repo function | works (exit 1 = FAIL) — but it is a structural gate, not a truth gate (F6-2) |
| CT-18 | handbook | out | `gen_nasa_handbook.py:247` `main()` (the render entry) | **external** — "the owner's approval artifact" (the owner is a human) | **UNVERIFIED** — the renderer hardcodes `docs/master` and selects `[0-9][0-9]-*.md`, so it does **not** render these `M*.md` chapters (see §11) |

CT-18 is a boundary contract: the consumer is a human owner, so "producer named + consumer
marked external" is the honest terminal state, not a chapter defect.

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| python compile | `python3 -m py_compile scripts/master_doc_*.py scripts/gen_*.py scripts/sheet_style.py scripts/extract_owner_decisions.py scripts/panel_loop.py scripts/ownership.py` | exit 0 | 2026-11-06 | PASS |
| shell parse | `bash -n scripts/verify-patch.sh` | exit 0 | 2026-11-06 | PASS |
| patch chain | `bash scripts/verify-patch.sh` | VERIFY-PATCH: PASS | 2026-11-06 | **PASS** — `5 stages, 4 patches, 57432007…` (the `deploy-doc` stage landed in commit `8ae4f82`) |
| doc gate over real modules | `python3 scripts/master_doc_check.py` | exit 1 with named errors | 2026-11-06 | **FAIL** — `44 module(s): 37 VERIFIED, 50 error(s), 0 warning(s), 10 fact(s)`, `MASTER-DOC: FAIL`, exit 1 |
| spine | `python3 scripts/handbook_spine.py` | `findings=0`, exit 0 | 2026-11-06 | **PASS** — `chapters=13  canonical contracts=18  findings=0` (after the CT-06 state reconciliation; the pre-fix run reported `CONTRACT STATE DISAGREEMENT=1` on CT-06) |

## 8. Metrics

**RED — none (absence-proved).** The documentation pipeline emits no counters or gauges.
`grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics' scripts/master_doc_*.py scripts/gen_*.py
scripts/panel_loop.py scripts/ownership.py` → 0 matches. Module count, VERIFIED/FAILING split and
coverage are derived by the census, not emitted.

## 9. Log lines (verbatim)

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| — | `%-46s %-10s %d error(s) %d warning(s)` (`master_doc_check.py:220-223`) | a module has errors/warns | evidentiary |
| — | `MASTER-DOC: FAIL` / `MASTER-DOC: PASS` (`:263`) | the gate completes | evidentiary (PASS is earned only over a non-empty, non-vacuous selection) |

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Stale locators | 50 locator errors naming nonexistent `docs/master` paths | a vacuous PASS (now named, not silent) | **OPEN** — re-point the unit locators to the real root |
| Gate does not select these chapters | the glob `[0-9][0-9]-*.md` (`:188`) does not match `M0-shared-contract.md` | a chapter-aware gate | **OPEN** — add a chapter-aware gate or a separate path (F6-1) |
| File-shaped census | 44 unit sections, 0 of docs/tests/prompts/skills/config covered | a system-shaped census | **OPEN** — CF-360 |
| Panel selection is stale | `master_doc_panel.py:67-71` globs `docs/master` (deleted); `panel_loop.py:33-34` depends on a fanout script + seat manifest under a dated scratch dir; `unfinished_chapters` (`:62-70`) searches `III.*` ids, not `M*.md` filenames | a deployable panel loop | **OPEN** — F6-3: the two panel mechanisms use incompatible selection conventions |
| Stale doc drift | unit 12 still records CF-320 as live | current doc | **OPEN** — CF-381 |
| Spine state blind spot (closed) | M9 and M11 both cite CT-06 with different state words and the spine passed | a gate that compares states | **resolved** — the spine now compares the normalized state word for internal contracts, and CT-06 is reconciled to "works (dispatcher leg)" |
| Spine locator blind spot (open) | a chapter cites a line that does not exist, or a line outside the cited file | a gate that verifies locators | **OPEN** — the spine checks the *presence* of a `file:line` pattern, not that the line exists at that number in that file (B6) |

## 11. Limits and margins

- `LOCATOR` regex (`:39-41`) requires a leading lookbehind that allows a dot so
  `.coding-hermes/board/tasks.jsonl:7` is a valid locator — a checker bug that silently dropped
  the dot once failed a correct document.
- A module stamped VERIFIED needs >=3 locators and at least one cited FACT-nn (`:130-138`).
- **The chapter-fill and render stages of the build pipeline do not operate on the delivered chapter set (B15).** `gen_nasa_handbook.py:18` hardcodes `MODULES = REPO/"docs/master"` (line 17 is
  `REPO = pathlib.Path(__file__).resolve().parent.parent`); `:253-259` selects `[0-9][0-9]-*.md` and
  refuses an empty selection (`no modules found`, exit 1). `master_doc_fill.py:26` defaults `MASTER`
  to `docs/master` and `:422` globs `[0-9][0-9]-*.md`. Neither selects these `M*.md` chapters, so the
  legacy renderer is **not** the working delivery path for this handbook.

## 12. Cross-references

- This handbook chapter is a product of M6's `panel_loop.py`.
- M4 BOARD rows are the evidence-of-record entries the gate's locators point at.
- M8 SAFETY also touches `verify-patch.sh`; ownership is M6.S8 per OUTLINE (`OUTLINE.md:170`).

## 13. Evidence of record

- Code read: `master_doc_check.py` (268 lines, read in full); `master_doc_fill.py:24-28, 390-422`;
  `gen_nasa_handbook.py:15-20, 247-262`; `master_doc_panel.py:55-80`; `panel_loop.py:33-38, 321-461`
  (main() + config); `panel_supervise.sh` (47 lines); `reap_orphan_writers.py`
  (61 lines); `ownership.py` (170 lines, read in full).
- Commands run: `python3 scripts/master_doc_check.py` (FAIL, 44/37/50); `bash scripts/verify-patch.sh`
  (PASS); `grep -rn gen_nasa_handbook scripts/` (no caller).
- Board rows: CF-360, CF-374 (complete), CF-381.
- **Findings:**
  - **F6-1** (carried) — the gate exits 1 over 44 unit sections / 50 errors; the `[0-9][0-9]-*.md` glob
    does not select these M-numbered chapters.
  - **F6-2** — the gate is structural/citation, not a semantic truth verifier
    (`:128-138`, `:214-216`); the gate reports the supplied status rather than recomputing it.
  - **F6-3** — `ownership.py` classified (optional); `master_doc_panel.py` and `panel_loop.py` use
    incompatible, dated selection paths.
  - **F6-4** (new) — S5–S8 have no in-repo invoker (grep empty); reclassified operator-invoked
    (optional), not "active".
  - **F6-5** (B5) — `handbook_spine.py` is the gate that actually selects these `M*.md`
    chapters and was undocumented in M6; added as S9 with its five checks, the BOUNDARY policy, and
    the state-agreement check (and its residual locator blind spot).
  - **F6-6** (new) — `panel_loop.py` was rewritten for `--groups`/`--parallel` (the
    PANEL-LOOP "sections written together" rule); `panel_supervise.sh` (supervisor) and
    `reap_orphan_writers.py` (orphan reaper) are new S4 units. All M6 `panel_loop.py` locators
    re-pinned to the rewritten file (`main()` at `:321`, config `:33-38`, stop `:442-457`).

## RED field count: 2 (Status §1 — own gate reads FAIL, Metrics §8)

## FLIGHT DATA FILE - M6 DOCUMENTATION

```checklist
TITLE: M6 DOCUMENTATION
WHO: DOC PANEL
LINT - python3 scripts/master_doc_check.py
√ PASS - MASTER-DOC: PASS, exit 0; a FAIL names the section and line
BUILD - python3 scripts/build_book.py --out <pdf>
√ GATES - lint, fit, furniture and check.py all green; page count printed
FIGURE FIT - svg_fit scales a sheet by min(1, 170/w_mm, 250/h_mm), aspect kept
√ ONE RULE - the builder's fit rule and gen_handbook_figures.min_label_mm agree
CROSSWALK - spot-check one M-id against its chapter section
√ MATCHES - the crosswalk row and the chapter agree
```
