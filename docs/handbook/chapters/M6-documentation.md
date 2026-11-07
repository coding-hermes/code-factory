# M6 — DOCUMENTATION

## 1. Identity

| Field | Value |
|---|---|
| Module name | DOCUMENTATION |
| Path | `/home/kara/code-factory/scripts/` — `master_doc_skeleton.py`, `master_doc_fill.py`, `master_doc_check.py`, `master_doc_panel.py`, `gen_nasa_handbook.py`, `gen_system_views.py`, `sheet_style.py`, `extract_owner_decisions.py`, `gen_unit_map.py`, `verify-patch.sh`, `panel_loop.py`, `ownership.py`, `handbook_spine.py` |
| Revision | `dbf810b7adfa5231a8828f415e1dad6de26a4263` (code-factory HEAD == origin/main == gh/main, round-19 re-stamp; one commit past round-18's `ce2f875`). `git diff --name-only ce2f875..HEAD` = `prompts/foreman.md`, `scripts/board_read.py` (dbf810b) — neither is cited by M6, so every panel/gate locator M6 cites is byte-identical across `ce2f875..HEAD` (re-verified this round: `panel_loop.py` is 461 lines, `:30`/`:34-35`/`:37-38`/`:323`/`:357`/`:383-385` all resolve; `panel_supervise.sh` is 47 lines, `:41-43` resolves). **Dirty-source disclosure (F6-8, carried — sol B10):** `scripts/handbook_spine.py` is **uncommitted working-tree content** — the reviewed file is 443 lines, `git show HEAD:scripts/handbook_spine.py` is 340 lines, working sha256 `afbc65fc7bfec973969c27767bd5980b7d7ae5c1a3999c7d6511dfdaf3752163`; the backtick-aware `split_row`, `CONTRACT ROW MISPARSE`, `CONTRACT UNKNOWN ID` and backticked-default fallback are working-tree content not committed at HEAD, and their locators are pinned to the working tree |
| Language / runtime | Python 3.14.9 (measured) |
| Owner lane | code-factory (control host) |
| Status | **UNVERIFIED** — `master_doc_check.py` (268 lines) read in full and its FAIL reproduced; `handbook_spine.py` (443 lines) and `panel_loop.py` (461 lines) read in full; the rest of the pipeline (`master_doc_fill.py`, `master_doc_skeleton.py`, `gen_nasa_handbook.py`, `master_doc_panel.py`, `gen_unit_map.py`, `gen_system_views.py`, `sheet_style.py`, `extract_owner_decisions.py`) read in part only — an unread-body RED named below, not hidden (sol B16). The legacy gate reads `MASTER-DOC: FAIL`. **The legacy fill/render/panel pipeline is UNBUILDABLE against these M-numbered chapters** (B13): `master_doc_check.py:188`, `gen_nasa_handbook.py:253-260` and `master_doc_fill.py:422` all select `[0-9][0-9]-*.md`, which does not match `M0-…-*.md`, so the legacy pipeline cannot select or deliver these chapters. **The chapter-aware gate is `handbook_spine.py` (S9)**, which *does* select `M*.md` and exits 1 on any finding (`python3 scripts/handbook_spine.py` → `chapters=13 canonical contracts=18 findings=0`, exit 0 — **UNVERIFIED-by-revision**: the gate is uncommitted working-tree content, F6-8); the legacy fill/render/check pipeline is retired for the M-numbered handbook, and the render-to-owner-artifact leg remains missing (CT-18 UNVERIFIED, §6) |

## 2. Purpose, authority and position

The system's description of itself, and the gate that checks the *structure* of that description.
`master_doc_check.py` validates headings, locator existence/bounds and citation requirements, then
**reports the document's declared status — it does not recompute it** (F6-2, corrected this round).
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
| S1 skeleton + census | `master_doc_skeleton.py` | **operator-invoked (optional)** | `main()` entrypoint only — an entrypoint is not activation (sol B14); `grep -rn master_doc_skeleton scripts/ prompts/ config/` → 0 matches, and no `master_doc`/`handbook_spine`/`gen_nasa_handbook` job exists in `~/.hermes/cron/jobs.json`, so no unit/cron/timer invokes it |
| S2 fill | `master_doc_fill.py` | **operator-invoked** | `main()` (`:393`); `--engine api\|hermes`, `--workers 2`, `--provider deepseek` (`:394-411`); no in-repo production caller |
| S3 gate | `master_doc_check.py` | **operator-invoked (optional)** | `main()` at `:160`; selects `[0-9][0-9]-*.md` at `:188` — an entrypoint is not activation (sol B14); no in-repo caller and no cron job invokes it |
| S4 panel | `master_doc_panel.py`, `panel_loop.py`, `ownership.py` | **active** (panel), **optional** (ownership) | `panel_supervise.sh:41` invokes `python3 scripts/panel_loop.py --rounds 0 --max-seconds 0`; `ownership.py` has no code caller (`grep -rn ownership.py scripts/` → self only) |
| S5 render | `gen_nasa_handbook.py`, `gen_system_views.py`, `sheet_style.py` | **operator-invoked** | `gen_nasa_handbook.py:247` `main()`; no in-repo caller (`grep -rn gen_nasa_handbook scripts/` → only `gen_unit_map.py:31` NOT_CALLERS) |
| S6 corpus | `extract_owner_decisions.py` | **operator-invoked** | no in-repo caller (grep empty) |
| S7 unit-map | `gen_unit_map.py` | **operator-invoked** | `main()`; no in-repo caller |
| S8 patch-chain drift | `verify-patch.sh` | **operator-invoked** | no in-repo caller, no cron/timer; run manually this round (VERIFY-PATCH: PASS) |
| S9 spine gate | `handbook_spine.py` | **active** (unit-invoked) | `python3 scripts/handbook_spine.py` — the cross-chapter consistency gate that *does* select `M*.md` chapters (the legacy `[0-9][0-9]-*.md` globs in the fill/render/check pipeline do not). It is now invoked by `panel_loop.py:385,410` (the reconcile pass after a parallel write), not only manually. What it actually enforces (verified against `handbook_spine.py:217-439`): (1) each canonical id CT-01..CT-18 is **cited** (`CONTRACT UNREGISTERED`, `:278`) **and** an id outside the register is **rejected** (`CONTRACT UNKNOWN ID`, `:267` — added round 12; sol B01's "an injected CT-99 passes rc 0" is superseded); (2) cross-chapter producer/consumer **function-token** agreement (`CONTRACT ONE-SIDED` `:295`, `CONTRACT PAIR DISAGREEMENT` `:320`) and **state-word** agreement (`CONTRACT STATE DISAGREEMENT` `:344`) for the 5 internal contracts only; (3) setting-default conflicts (`SETTING CONFLICT`, `:365`) — `norm_default` strips backticked spans so defaults cited in different backtick refs compare equal, but a backticked-only default normalizes to the string itself (sol B13); (4) dangling M/F references (`DANGLING REFERENCE`, `:381/:389`); (5) prose count claims (`COUNT CLAIM`, `:414`) for module/chapter/flow/contract — `submodule` is `None` at `:401`, so no submodule count is ever compared |

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
| fill `--limit` | 0 (`:395`) | int | cap on modules filled in one run | 0 = no cap; a positive N fills only the first N candidates |
| fill `--force` | false (`:401`) | flag | refill modules already FILLED/VERIFIED | without it, already-complete modules are skipped |
| fill `--only` | `""` (`:404`) | comma prefixes | narrow the candidate set (e.g. `05-,07-`) | a prefix matching none yields an empty run |
| fill `--model` | `""` (`:411`) | a model id | the seat model for `--engine hermes` | empty falls back to `openai/gpt-6.1-sol` (`:454`) |
| fill `--dry-run` | false (`:413`) | flag | list candidates without provider calls or writes | **`--dry-run` suppresses all provider calls and writes** (`:438-440`); `--force` decides *which* documents may be rewritten — round-6 documented five controls and omitted the switches that decide whether writing or provider execution occurs (sol B11) |

**Spine gate (S9, added this round — grok B5; re-verified against the working tree this round).** `handbook_spine.py`
carries no settings surface; its policy is four hardcoded sets: `CANON` (the 18 contract ids +
expected producer/consumer systems), `BOUNDARY` (the **13** boundary contracts whose far side is a
human/LLM/service with no in-repo file), the `SETTING_ROW`/`REF`/`COUNT_CLAIM` regexes, and the
internal-vs-boundary split that decides which contracts must name both `file:function`. The round-9
defect this gate exists to close: its predecessor compared function tokens but never the **state**
column, so M9 ("broken") and M11 ("works") could both cite CT-06 and pass while flatly disagreeing.
The state-agreement check (and the CT-05 boundary→internal re-grade) are added that round; round 12
added the **`CONTRACT UNKNOWN ID`** check (`:267`) that rejects a chapter citing an id outside
CT-01..CT-18. **Round 16 fixed the column-slicing blind spot (grok #4):** the §6 cell splitter is
now backtick-aware (`split_row`, `handbook_spine.py`), so a literal `|` inside a code span (a grep
pattern, or `MASTER-DOC: PASS\|FAIL`) is cell content, not a separator, and a §6 row that splits to
other than 6 columns is a `CONTRACT ROW MISPARSE` finding. The remaining blind spots are that it does
**not** verify cited line numbers exist in the cited file, and it trusts the chapters' self-reported
status word rather than re-deriving it. **Four further coverage limits (kimi N-4, sol B12):** (a) the
contract and setting scans are **section-scoped** — `contract_rows` reads only `section(text, 6)`
(`:130`) and the setting scan only `section(text, 5)` (`:356`), so a CT-id citation or a setting row
placed outside §6/§5 is not scanned (a controlled test returned `findings=0` for each when injected
outside those sections); (b) `norm_default` reduces a decimal default to its **integer prefix**
(`:175-176`), so `0.15` and `0.66` both normalize to `0` and a decimal-default conflict between
chapters does not fire; (c) `SETTING_ROW` (`:87`) recognizes only `[A-Z][A-Z0-9_]{3,}` names, so a
CLI-switch row (`--timeout`) is not recognized as a setting; (d) the flow count is hardcoded
(`"flow": 16` at `:398`), not derived from the flow chapters that actually exist (all 16 are MISSING).

**`panel_loop.py` settings and stop semantics (sol B14; re-pinned this round — `panel_loop.py` grew
~+70 lines in `08a2c8a..242cc474` when the parallel-writer path landed, so every prior locator
shifted).** The loop that produces this handbook carries its own controls; a process exit 0 is
**not** document acceptance:

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `--rounds` | 6 (`:323`) | int; **0 = no cap** (`:340` maps 0 → `10**9`) | **absolute round ceiling** — the loop condition (`:351` `while st["round"] < rounds`) compares the *stored* round against `--rounds`; it does **not** count iterations from `--start-round` (sol B12) | a cap is a session budget, not a definition of done |
| `--max-seconds` | 21000 (`:324`) | int; 0 = no cap (`:341`) | the wall-clock budget | same |
| `--start-round` | None (`:325`) | int | **inert for the executed round** — `:342` (`rnd = args.start_round or (st["round"] + 1)`) feeds only the initial `start round` print at `:346`; the first loop iteration recomputes `rnd = st["round"] + 1` at `:352` and writes `st["round"] = rnd` at `:353`, so the loop always executes `st["round"] + 1` regardless (sol B12) | the flag does not resume at a specific round as its help implies — it is an inert override |
| `--writer-timeout` | 4200 (`:326`) | seconds | writer session deadline | too short kills the writer mid-round |
| `--judge-timeout` | 2700 (`:327`) | seconds | judge session deadline | too short yields MISSING seats |
| `--chapters` | "" (`:328`) | comma list | narrow the chapter set | empty = all chapters |
| `--groups` | "" (`:329-330`) | `M0,M1;M4,M5` | explicit section groups (overrides `--parallel`) | a wrong group list splits ownership across the wrong seams |
| `--parallel` | 1 (`:331-332`) | int; 0/1 = single writer | writers per round, one per section group | >1 runs concurrent writers that cannot see each other's edits — the reconcile pass (`:381-413`) then runs the spine and a reconciler that fixes only the named cross-section inconsistencies |
| `PANEL_WRITER_MODEL` / `PANEL_WRITER_PROVIDER` | `deepseek-v4-pro` / `deepseek` (`:37-38`) | env override | writer seat model/provider | a wrong model runs the writer on an unmeasured seat |
| `FANOUT` / `MANIFEST` | hardcoded `cf-quorum-20261104` scratch paths (`:34-35`) | a path | the external fanout script + seat manifest | a dated scratch dir that no longer exists breaks the loop |

**Stop semantics (distinguish process success from acceptance).** `panel_loop.py:442-457` exits 0
on three conditions: unanimous PASS (`:442-446`), **or** `clean_streak >= 2` (`:447-451`) — two
consecutive rounds with no *new defect class*, **even while blocking findings remain open** — or
the round cap (`:454-457`). A `STOP: no new defect class` exit is a successful process
termination, not proof the document is aligned; the operator must read back the outstanding
findings (the `CORRECTIONS.md` per round) separately.

**Reconcile bypass (B03, sol — round 15, carried).** The parallel-writer branch runs when *either*
`--groups` is set *or* `--parallel > 1` (`panel_loop.py:357`), but the reconcile pass — the spine
run and reconciler that repairs cross-section seams — is gated on `--parallel > 1` alone
(`panel_loop.py:383`). With an explicit `--groups` list and the default `--parallel 1`, concurrent
writers therefore run with **no** reconciliation pass. In the live `panel_supervise.sh` invocation
the two are always passed together (`--parallel "${PANEL_PARALLEL:-3}" --groups "${PANEL_GROUPS:-}"`,
`panel_supervise.sh:42-43`), so the production path is covered, but a `--groups`-only run bypasses
the seam check. The gate should depend on the effective writer-group count, not the `--parallel`
switch.

## 6. Contracts in and out

Canonical ids are the register of record (OUTLINE Part IV, CT-01..CT-18). Rows that are
cross-system contracts carry their CT id; an interface with no canonical entry is listed with a
`(local)` tag and is not a peer to any CT row, so it cannot be matched against another chapter.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| CT-16 | docsgate | out | **two gates, two corpora (sol B15):** the *legacy* status word is `master_doc_check.py:263` (`MASTER-DOC: PASS\|FAIL`), which selects `[0-9][0-9]-*.md` (`:188`) — the appendix unit corpus, **not** these `M*.md` chapters; the *chapter-aware* gate for this handbook is `handbook_spine.py` (`findings=N`, exit 1 on any finding), which selects `M*.md` | **external** — "the handbook's status word", no in-repo consumer function | **works (spine leg) / legacy leg scoped to the appendix corpus** — the legacy `master_doc_check` reads `MASTER-DOC: FAIL` over 44 appendix units and does **not** select the M-chapters (F6-1); the spine leg reports `findings=0` but is **UNVERIFIED-by-revision** (uncommitted gate, F6-8). The status word is a structural/citation word, not a truth verdict (F6-2) |
| CT-18 | handbook | out | `gen_nasa_handbook.py:247` `main()` (the render entry) | **external** — "the owner's approval artifact" (the owner is a human) | **UNVERIFIED** — the renderer hardcodes `docs/master` and selects `[0-9][0-9]-*.md`, so it does **not** render these `M*.md` chapters (see §11) |

CT-18 is a boundary contract: the consumer is a human owner, so "producer named + consumer
marked external" is the honest terminal state, not a chapter defect.

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| python compile | `python3 -m py_compile scripts/master_doc_*.py scripts/gen_*.py scripts/sheet_style.py scripts/extract_owner_decisions.py scripts/panel_loop.py scripts/ownership.py` | exit 0 | 2026-11-06 | PASS |
| shell parse | `bash -n scripts/verify-patch.sh` | exit 0 | 2026-11-06 | PASS |
| patch chain | `bash scripts/verify-patch.sh` | VERIFY-PATCH: PASS | 2026-11-06 | **PASS** — `5 stages, 4 patches, 57432007…` (the `deploy-doc` stage landed in commit `8ae4f82`, after the round-10 stamp's `4 stages, 3 patches, f393a681…`; re-quoted this round) |
| doc gate over real modules | `python3 scripts/master_doc_check.py` | exit 1 with named errors | 2026-11-06 | **FAIL** — `44 module(s): 37 VERIFIED, 50 error(s), 0 warning(s), 10 fact(s)`, `MASTER-DOC: FAIL`, exit 1 |
| spine | `python3 scripts/handbook_spine.py` | `findings=0`, exit 0 | 2026-11-06 | **PASS (dirty tree)** — `chapters=13  canonical contracts=18  findings=0`; **UNVERIFIED-by-revision** (F6-8): reproducible only from the uncommitted 443-line working tree, not from `git show HEAD:` (340 lines), so a fresh clone at the stamped revision runs a weaker gate |

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
| File-shaped census | 44 unit sections, 0 of docs/tests/prompts/skills/config covered | a system-shaped census | **OPEN** — CF-360 |
| Panel selection is stale | `master_doc_panel.py:67-71` globs `docs/master` (deleted); `panel_loop.py:34-35` depends on a fanout script + seat manifest under a dated scratch dir; `unfinished_chapters` (`:63-72`) searches `III.*` ids, not `M*.md` filenames | a deployable panel loop | **OPEN** — F6-3: the two panel mechanisms use incompatible selection conventions |
| Stale doc drift | unit 12 still records CF-320 as live | current doc | **OPEN** — CF-381 |
| Spine state blind spot (closed) | M9 and M11 both cite CT-06 with different state words and the spine passed | a gate that compares states | **resolved this round** — the spine now compares the normalized state word for internal contracts, and CT-06 is reconciled to "works (dispatcher leg)" |
| Spine locator blind spot (open) | a chapter cites a line that does not exist, or a line outside the cited file | a gate that verifies locators | **OPEN** — the spine checks the *presence* of a `file:line` pattern, not that the line exists at that number in that file (grok B6) |

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
- M8 SAFETY also touches `verify-patch.sh`; ownership is M6.S8 per OUTLINE (`OUTLINE.md:176`).

## 13. Evidence of record

- Code read: `master_doc_check.py` (268 lines, read in full); `master_doc_fill.py:24-28, 390-422`;
  `gen_nasa_handbook.py:15-20, 247-262`; `master_doc_panel.py:55-80`; `panel_loop.py` (461 lines, read
  in full — re-pinned this round); `handbook_spine.py` (443 lines, read in full);
  `ownership.py` (170 lines, read in full).
- Commands run: `python3 scripts/master_doc_check.py` (FAIL, 44/37/50); `bash scripts/verify-patch.sh`
  (PASS); `grep -rn gen_nasa_handbook scripts/` (no caller).
- Board rows: CF-360, CF-374 (complete), CF-381.
- **Findings:**
  - **F6-1** (carried) — the gate exits 1 over 44 unit sections / 50 errors; the `[0-9][0-9]-*.md` glob
    does not select these M-numbered chapters.
  - **F6-2** — the gate is structural/citation, not a semantic truth verifier (`:128-138`, `:214-216`).
    Round-3's "recomputes VERIFIED" claim was **false** — the gate reports the supplied status.
  - **F6-3** — `ownership.py` classified (optional); `master_doc_panel.py` and `panel_loop.py` use
    incompatible, dated selection paths.
  - **F6-4** (new) — S5–S8 have no in-repo invoker (grep empty); reclassified operator-invoked
    (optional), not "active".
  - **F6-5** (new, grok B5) — `handbook_spine.py` is the gate that actually selects these `M*.md`
    chapters and was undocumented in M6; added as S9 with its five checks, the BOUNDARY policy, and
    the state-agreement check (and its residual locator blind spot).
  - **F6-6** (new, sol B03) — `--groups` with `--parallel=1` runs parallel writers with **no**
    reconcile pass (`panel_loop.py:357` vs `:383`); the live supervisor passes both
    (`panel_supervise.sh:42-43`), so the production path is covered. Code defect, filed.
  - **F6-7** (new, grok #4) — the spine §6 splitter was naive `str.split("|")` and mis-sliced any row
    carrying a `|` inside a code span (M4 CT-10, M6 CT-16, M2 CT-09, M12 M12-C1), reading
    producer/consumer/state from shifted columns. Fixed this round: backtick-aware `split_row` plus a
    `CONTRACT ROW MISPARSE` finding for a row that splits to other than 6 columns.
  - **F6-8** (new, sol B10) — §1 revision attribution corrected: `handbook_spine.py`'s splitter and
    gate checks are uncommitted working-tree content (443 lines vs HEAD's 340, sha256 `afbc65fc…`),
    not a committed round-16 file. The spine is pinned to the working tree with the dirty delta
    disclosed.
  - **F6-9** (new, round 18) — CT-16's producer is now bound to the actual chapter-aware gate, not
    the wrong-corpus legacy one: `master_doc_check.py` selects `[0-9][0-9]-*.md` (the appendix unit
    corpus) and reads `MASTER-DOC: FAIL`, while `handbook_spine.py` selects `M*.md` and reports
    `findings=N` (sol B15); the spine leg and M6 §7's spine row are marked **UNVERIFIED-by-revision**
    because the gate is uncommitted (glm B1 / grok #6 / kimi #10); S1/S3 reclassified operator-invoked
    (entrypoint is not activation, sol B14); the §1 Status and RED count now name the unread pipeline
    bodies instead of implying they were covered (sol B16).

## RED field count: 5 (Status §1 — own gate reads `MASTER-DOC: FAIL` over the legacy 44-unit corpus and the spine leg is UNVERIFIED-by-revision; Metrics §8 — absence-proved; §1/§3 unread pipeline bodies — `master_doc_skeleton.py`/`master_doc_fill.py`/`gen_nasa_handbook.py`/`master_doc_panel.py`/`gen_unit_map.py`/`gen_system_views.py`/`sheet_style.py`/`extract_owner_decisions.py` read in part only (sol B16); §9 log inventory — only the two legacy-gate lines tabulated, the module-wide emitter surface not inventoried one-per-site; the Contracts-in-and-out field (§6) — not-measured: CT-16's spine leg is UNVERIFIED-by-revision (uncommitted gate, F6-8) and CT-18's render leg is UNVERIFIED (external owner, missing renderer)). Boundary `UNVERIFIED` states are RED, not exemptions — see the single RED accounting rule in M4 (OUTLINE Part VII.3, `OUTLINE.md:266-282`).
