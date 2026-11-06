# 44. Documentation pipeline — how these modules were made and graded

| Field | Value |
|---|---|
| Path | `scripts/master_doc_fill.py`, `scripts/master_doc_panel.py`, `scripts/master_doc_check.py`, `scripts/gen_nasa_handbook.py` |
| Repository | `code-factory` |
| Revision | `9f343f0` |
| Status | **VERIFIED — the pipeline is documented from its own source, and its one measured weakness is named in §6** |

## 1. Purpose and why it matters

The set of documents you are reading was produced, graded and printed by four scripts that were
themselves undocumented — the set could not certify itself. This module is that missing page: what
each script does, what it refuses, and where the process is still weak.

What breaks if it is ABSENT: a reader cannot tell an author's claim from a machine's check, and the
next operator regenerates the corpus with no idea which steps were gates. What breaks if it LIES:
`VERIFIED` becomes a word a model can write, which is exactly the failure that gutted module `09` on
the first fill pass (`docs/master/09-scripts-clone-lane-py.md` records the repair).

## 2. Dependencies and library contracts

| script | role | contract |
|---|---|---|
| `scripts/master_doc_skeleton.py` | writes the 43 skeletons | one file per component, eight headings, status `RED` |
| `scripts/master_doc_fill.py` | fills a module from its source | two engines: `--engine api` (one completion, no tools) and `--engine hermes` (a real seat with tools); lanes are `deepseek-v4-flash` and `xkiro` only (`scripts/master_doc_fill.py:42`) |
| `scripts/master_doc_check.py` | the gate | eight headings, resolving `file:line` locators, ≥3 locators for VERIFIED, a `fact:` citation, no unresolved marker inside VERIFIED (`scripts/master_doc_check.py:21`, `:53`) |
| `scripts/master_doc_panel.py` | the review | three seats from three families (`scripts/master_doc_panel.py:29`); reports splits, because a split marks a section that needs a measurement, not a vote |
| `scripts/gen_nasa_handbook.py` | the artifact | markdown → A4 chapters + a generated deficiency chapter (`scripts/gen_nasa_handbook.py:171`, `:247`) |

The gate and the artifact read the same source: a module the checker refuses to mark VERIFIED prints
its status word as `RED` in the handbook's contents page, so the PDF cannot claim more than the gate
allows.

## 3. Verification

The pipeline's own acceptance is the gate, run over the whole set:

```
python3 scripts/master_doc_check.py docs/master --strict
```

Measured after this module was added (tip of 2026-11-05): **44 modules, 34 VERIFIED, 0 errors, `MASTER-DOC: PASS`**. The handbook build is
verified by construction — `scripts/gen_nasa_handbook.py --out …` prints the page count, and the
2026-11-05 build measured **273 pages** (10 design sheets + 3 deficiency pages + 260 module pages).

The pipeline's own regression arm lives in `tests/selftest.sh` §45, which proves the fill selector and
the checker's refusals; a change that makes the checker accept a structurally broken document turns
that arm red.

## 4. Metrics emitted

None. The counts that matter — modules VERIFIED, errors, warnings, facts cited — are printed by the
gate on every run (`scripts/master_doc_check.py:110`) and are the numbers quoted in this set's
summaries. There is deliberately no metrics endpoint: the gate is a build step, not a service.

## 5. Log lines it can generate

Verbatim shapes from the gate and the filler:

```
  <file>  VERIFIED   ok
  <file>  RED        4 error(s) 0 warning(s)
   FAIL  locator past EOF: specs/HARNESS-MEMORY.md:125 (file has 153 lines)
  MASTER-DOC: PASS
```

and from the filler, the two that distinguish an honest failure from a silent one:

```
09-scripts-clone-lane-py.md     filled    8 sections, 85 locators
09-scripts-clone-lane-py.md     error     empty reply; finish=length
```

The second line is the one worth keeping: a reasoning model can spend its whole budget thinking and
return nothing, and the filler says so instead of writing an empty document (`scripts/master_doc_fill.py:80`).

## 6. Failure modes

| failure | direction | consequence |
|---|---|---|
| the model's structure is trusted | **fail open** | the first fill pass deleted 7 of 8 sections in `09` and stamped it VERIFIED — hence the census gate |
| a gate rejects a true citation | **fail closed, wrongly** | a `\b` that cannot match a leading dot rejected `.coding-hermes/board/tasks.jsonl:7`; a gate that rejects truth teaches writers to avoid honest references |
| VERIFIED written by the author | **fail open** | the status is now computed from locators; the author's word is ignored |
| the panel and the gate are confused | **fail open** | the gate grades shape; only a seat can notice that a section is true-shaped and false (`docs/master/05` was VERIFIED and wrong in four sections until the panel measured it) |
| the handbook is built from a stale tree | **fail open** | the PDF would carry statuses the gate no longer agrees with; rebuild after every landing |

The measured weakness, stated plainly: **the gate cannot tell whether a sentence is true**, only
whether it is citable. Every error the panel found (`05`, `04`, `11`, `33`) passed the gate first.

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| `DEEPSEEK_API_KEY` / `XKIRO_API_KEY` | `~/.hermes/.env` or the environment | required for `--engine api`; the project spends no Ollama credits |
| `--engine hermes` | a real Hermes seat | needs the gateway; the seat inherits tools and DuckBrain |
| `--provider` | `deepseek` \| `xkiro` | anything else is refused by `choices` |
| Chrome | `/usr/bin/google-chrome` | required for the PDF; `--headless --print-to-pdf` |
| pymupdf | `uv run --with pymupdf` | page numbering and the merge with the design sheets |

## 8. Evidence of record

- The four scripts, cited above by line — `scripts/master_doc_check.py:21,53,110`,
  `scripts/master_doc_fill.py:42,80`, `scripts/master_doc_panel.py:29`, `scripts/gen_nasa_handbook.py:171,247`.
- `tests/selftest.sh` §45 — the pipeline's regression arm.
- `docs/master/05-scripts-bunker-provision-sh.md` and `docs/master/33-scripts-project-node-sh.md` — the
  two modules whose panel adjudication is the evidence that the gate alone is insufficient.
- Facts: `fact: FACT-08` governs the harness battery this pipeline's §3 quotes; `fact: FACT-10` governs the board rows named below.

Board rows filed from this module's findings: the commit gate has no owning module, `tests/selftest.sh`
  is not a module, and the secrets scanner's fallback path is undocumented.

To re-establish this page's status: `python3 scripts/master_doc_check.py docs/master --strict` prints
PASS with this module counted among the VERIFIED, and a run of `tests/selftest.sh` §45 is green.
