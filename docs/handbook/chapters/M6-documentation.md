# M6 — DOCUMENTATION

## 1. Identity

| Field | Value |
|---|---|
| Module name | DOCUMENTATION |
| Path | `/home/kara/code-factory/scripts/` — `master_doc_skeleton.py`, `master_doc_fill.py`, `master_doc_check.py`, `master_doc_panel.py`, `gen_nasa_handbook.py`, `gen_system_views.py`, `sheet_style.py`, `extract_owner_decisions.py`, `gen_unit_map.py`, `verify-patch.sh`, `panel_loop.py`, `ownership.py` |
| Revision | `943ef984dc093e5780605ac6e54cd043122126ef` (code-factory HEAD, 2026-11-06) |
| Language / runtime | Python 3.14.9 (measured) |
| Owner lane | code-factory (control host) |
| Status | **UNVERIFIED** — `master_doc_check.py` (268 lines) read in full and its FAIL reproduced; the rest of the pipeline (`master_doc_fill.py`, `gen_nasa_handbook.py`, `master_doc_panel.py`, `gen_unit_map.py`, …) not read line-by-line; the gate reads `MASTER-DOC: FAIL`. **The fill/render/panel pipeline is UNBUILDABLE against these M-numbered chapters** (B13): `master_doc_check.py:188`, `gen_nasa_handbook.py:253-260` and `master_doc_fill.py:422` all select `[0-9][0-9]-*.md`, which does not match `M0-…-*.md`, so no chapter-aware path exists from source selection to delivered artifact |

## 2. Purpose, authority and position

The system's description of itself, and the gate that checks the *structure* of that description.
`master_doc_check.py` validates headings, locator existence/bounds and citation requirements, then
**reports the document's declared status — it does not recompute it** (F6-2, corrected this round).
`panel_loop.py` is the loop this handbook chapter is a product of.

**What breaks if this module is absent.** The system cannot describe itself, and no one can check
the description.

**What breaks if it lies.** Two distinct failure modes:
- The PASS-over-zero failure (fixed): `DEFAULT_ROOTS` (`master_doc_check.py:52`) falls back to
  `docs/handbook/appendices/units`, and an empty selection is a named failure (`:191-209`).
- **The gate is a structural/citation gate, not a semantic truth verifier (F6-2).**
  `master_doc_check.py:128-138` reads the document's *supplied* status and imposes citation
  requirements (`VERIFIED` needs >=3 locators and at least one cited FACT-nn); `:214-216` retains
  and counts that supplied status. It does **not** verify that cited code supports the prose. The
  live result — `44 module(s): 37 VERIFIED, 50 error(s)`, `MASTER-DOC: FAIL` — shows 37 modules
  stamped VERIFIED alongside 50 errors: the stamp is the document's own claim, re-emitted, not a
  re-derivation of truth.

## 3. Submodule inventory

| Submodule | Unit | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 skeleton + census | `master_doc_skeleton.py` | **active** | `main()` entrypoint; structure-mapped |
| S2 fill | `master_doc_fill.py` | **operator-invoked** | `main()` (`:393`); `--engine api\|hermes`, `--workers 2`, `--provider deepseek` (`:394-411`); no in-repo production caller |
| S3 gate | `master_doc_check.py` | **active** | `main()` at `:160`; selects `[0-9][0-9]-*.md` at `:188` |
| S4 panel | `master_doc_panel.py`, `panel_loop.py`, `ownership.py` | **active** (panel), **optional** (ownership) | `panel_loop.py` runs this loop; `ownership.py` has no code caller (`grep -rn ownership.py scripts/` → self only) |
| S5 render | `gen_nasa_handbook.py`, `gen_system_views.py`, `sheet_style.py` | **operator-invoked** | `gen_nasa_handbook.py:247` `main()`; no in-repo caller (`grep -rn gen_nasa_handbook scripts/` → only `gen_unit_map.py:31` NOT_CALLERS) |
| S6 corpus | `extract_owner_decisions.py` | **operator-invoked** | no in-repo caller (grep empty) |
| S7 unit-map | `gen_unit_map.py` | **operator-invoked** | `main()`; no in-repo caller |
| S8 patch-chain drift | `verify-patch.sh` | **operator-invoked** | no in-repo caller, no cron/timer; run manually this round (VERIFY-PATCH: PASS) |

Round-3 classified S5–S8 "active" on prose ("render the handbook", "extracts owner decisions",
"measures who references a unit", "chain-break detection"). The classification rule requires the
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
| fill `--workers` | 2 (`:396`) | positive int | parallel fill workers | **0 or negative raises `ValueError: max_workers must be greater than 0`** — there is no serial fallback; `1` is serial execution (`ThreadPoolExecutor(max_workers=a.workers)` at `:450`). Round-4's "0 serialises" was false (sol B14) |
| fill `--provider` | `deepseek` (`:397`) | a `PROVIDERS` key | fill provider | an unknown provider is refused |

## 6. Contracts in and out

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| M6-C1 | docsgate | out | `master_doc_check.py:263` prints `MASTER-DOC: PASS\|FAIL` | **external** — "the handbook's status word", no in-repo function | works (exit 1 = FAIL) — but it is a structural gate, not a truth gate (F6-2) |
| M6-C2 | handbook | out | `gen_nasa_handbook.py:247` `main()` (the render entry) | **external** — "the owner's approval artifact", no in-repo function | **UNVERIFIED** — the renderer hardcodes `docs/master` and selects `[0-9][0-9]-*.md`, so it does **not** render these `M*.md` chapters (see §11) |

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| python compile | `python3 -m py_compile scripts/master_doc_*.py scripts/gen_*.py scripts/sheet_style.py scripts/extract_owner_decisions.py scripts/panel_loop.py scripts/ownership.py` | exit 0 | 2026-11-06 | PASS |
| shell parse | `bash -n scripts/verify-patch.sh` | exit 0 | 2026-11-06 | PASS |
| patch chain | `bash scripts/verify-patch.sh` | VERIFY-PATCH: PASS | 2026-11-06 | **PASS** — `4 stages, 3 patches, f393a681…` |
| doc gate over real modules | `python3 scripts/master_doc_check.py` | exit 1 with named errors | 2026-11-06 | **FAIL** — `44 module(s): 37 VERIFIED, 50 error(s), 0 warning(s), 10 fact(s)`, `MASTER-DOC: FAIL`, exit 1 |

## 8. Metrics

**RED — none (absence-proved this round).** The documentation pipeline emits no counters or gauges.
`grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics' scripts/master_doc_*.py scripts/gen_*.py
scripts/panel_loop.py scripts/ownership.py` → 0 matches. Module count, VERIFIED/FAILING split and
coverage are derived by the census, not emitted.

## 9. Log lines (verbatim)

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| — | `%-46s %-10s %d error(s) %d warning(s)` (`master_doc_check.py:220-223`) | a module has errors/warns | evidentiary |
| — | `MASTER-DOC: FAIL` / `MASTER-DOC: PASS` (`:263`) | the gate completes | evidentiary (PASS is earned only over a non-empty, non-vacuous selection) |

(The round-3 `WRITER ROUND COMPLETE` / `PANEL REVIEW COMPLETE` "row" had no locator in any module;
it was this loop's own marker, not a log line, and is removed.)

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Stale locators | 50 locator errors naming nonexistent `docs/master` paths | a vacuous PASS (now named, not silent) | **OPEN** — re-point the unit locators to the real root |
| Gate does not select these chapters | the glob `[0-9][0-9]-*.md` (`:188`) does not match `M0-shared-contract.md` | a chapter-aware gate | **OPEN** — add a chapter-aware gate or a separate path (F6-1) |
| File-shaped census | 44 modules, 0 of docs/tests/prompts/skills/config covered | a system-shaped census | **OPEN** — CF-360 |
| Panel selection is stale | `master_doc_panel.py:67-71` globs `docs/master` (deleted); `panel_loop.py:33-34` depends on a fanout script + seat manifest under a dated scratch dir; `unfinished_chapters` (`:62-70`) searches `III.*` ids, not `M*.md` filenames | a deployable panel loop | **OPEN** — F6-3: the two panel mechanisms use incompatible selection conventions |
| Stale doc drift | unit 12 still records CF-320 as live | current doc | **OPEN** — CF-381 |

## 11. Limits and margins

- `LOCATOR` regex (`:39-41`) requires a leading lookbehind that allows a dot so
  `.coding-hermes/board/tasks.jsonl:7` is a valid locator — a checker bug that silently dropped
  the dot once failed a correct document.
- A module stamped VERIFIED needs >=3 locators and at least one cited FACT-nn (`:130-138`).
- **The fill/render pipeline does not operate on the delivered chapter set (B15, locator re-pinned
  this round).** `gen_nasa_handbook.py:18` hardcodes `MODULES = REPO/"docs/master"` (line 17 is
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
  `gen_nasa_handbook.py:15-20, 247-262`; `master_doc_panel.py:55-80`; `panel_loop.py:25-75`;
  `ownership.py` (170 lines, read in full).
- Commands run: `python3 scripts/master_doc_check.py` (FAIL, 44/37/50); `bash scripts/verify-patch.sh`
  (PASS); `grep -rn gen_nasa_handbook scripts/` (no caller).
- Board rows: CF-360, CF-374 (complete), CF-381.
- **Findings:**
  - **F6-1** (carried) — the gate exits 1 over 44 modules/50 errors; the `[0-9][0-9]-*.md` glob
    does not select these M-numbered chapters.
  - **F6-2** — the gate is structural/citation, not a semantic truth verifier (`:128-138`, `:214-216`).
    Round-3's "recomputes VERIFIED" claim was **false** — the gate reports the supplied status.
  - **F6-3** — `ownership.py` classified (optional); `master_doc_panel.py` and `panel_loop.py` use
    incompatible, dated selection paths.
  - **F6-4** (new) — S5–S8 have no in-repo invoker (grep empty); reclassified operator-invoked
    (optional), not "active".

## RED field count: 2 (Status §1 — own gate reads FAIL, Metrics §8)
