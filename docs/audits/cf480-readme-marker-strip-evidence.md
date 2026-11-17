# CF-480 — README ended with a marker block that closed nothing

Measured on the readme lane tick `code-factory-readme-2026-11-17-02-40-53` at `origin/main`
`feda6bd4`.

ch:trace row=CF-480 spec=docs/traceability-doctrine.md test=none:no-arm-guards-the-absence-of-the-block doc=docs/audits/cf480-readme-marker-strip-evidence.md prompt=none:lane-brief evidence=docs/audits/cf480-readme-marker-strip-evidence.md witness=path@origin:docs/audits/cf480-readme-marker-strip-evidence.md verdict=pending:rejudge-for-this-artifact commit=none:self-referential-hash memory=/project/code-factory/readme-audit-2026-11-17-02-40-53

## What was wrong

The last fifteen lines of `README.md` were a traceability block: seven `ch:trace` markers followed by
`STATUS:` / `TIER:` / `EVIDENCE:` lines. Every one of them pointed at itself —

```
ch:trace row=CF-188 … doc=README.md evidence=README.md witness=README.md#the-lanes \
         verdict=none:foreman-judges-after-merge commit=none:self-referential-hash
STATUS: complete | partial | blocked
TIER: T1
EVIDENCE: README.md#the-lanes
```

— which is the closure-by-reference the doctrine refuses: `evidence=` must be an artifact the author
produced, and a `STATUS:` line whose evidence is the document carrying it closes nothing. The block
also mixed several unrelated rows (CF-188, CF-038, CF-014, CF-013, CF-065, CF-064, CF-151) into a
public front page, where a stranger reads "STATUS: complete | partial | blocked" as the project's own
state. A README is not a marker host: markers belong in the audit document and the commit footer.

## The measurement, before and after

```
# before (at origin/main feda6bd4)
$ grep -c 'ch:trace' README.md                       -> 7
$ grep -cE '^(STATUS|TIER|EVIDENCE):' README.md      -> 3
$ wc -l < README.md                                  -> 365

# after
$ grep -c 'ch:trace' README.md                       -> 0
$ grep -cE '^(STATUS|TIER|EVIDENCE):' README.md      -> 0
$ wc -l < README.md                                  -> 352
```

The stripped block is preserved verbatim outside the repository
(`README.before-tail-strip-20261117.md` in the lane scratch directory) and is not shipped, because
shipping it would put the same self-referential claims in a second public file.

The removal replaces the block with one sentence naming where the evidence actually lives — the
audit transcripts under `docs/audits/` — so a reader still has a path to the runs behind the page.

## Why this is safe to land

The suite reads `README.md` in several arms (Quick start names `HERMES_PYTHON_BIN`; the census block
is byte-parity-pinned to `docs/audits/cf089-census-recipe.sh`; §32 checks the quick start names
`BUNKER_SERVER`). None of them touch the tail, and the full suite was re-run after the strip:

```
$ bash tests/selftest.sh
...
SELFTEST: PASS
EXIT=0
```

The diff is deletion-only above the closing sentence: no section, table or command block was edited.

## The gap this leaves, stated instead of papered over

Nothing prevents the block from returning. The first version of this artifact cited
`test=tests/selftest.sh::readme-content-arms`; no such arm exists — a judge re-read the tree,
grepped for it, and found the string only in this file. That is exactly the closure-by-reference
this row is about, committed in the row's own evidence, so the citation is corrected above to
`test=none:no-arm-guards-the-absence-of-the-block` and the missing guard is filed as **CF-481**
(add an arm that reds when `README.md` carries a `ch:trace` or `STATUS:`/`TIER:`/`EVIDENCE:` line).

What DOES stand behind the strip today: the arms that read README's real content still pass (prompt
reference, census byte-parity with `docs/audits/cf089-census-recipe.sh`, `HERMES_PYTHON_BIN` in
Quick start, `BUNKER_SERVER`), and the absence itself is verifiable in one command —
`git show origin/main:README.md | grep -c 'ch:trace'` prints 0.
