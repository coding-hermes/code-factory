# Part VIII — Delivery

The book is itself a delivered artifact, and it is delivered the way work is: through
gates. This part records what the book is built from, the gates a build must pass in
order, the audit rubric that grades the result, and the delivery rule that follows from
them — a build that fails a gate is not delivered.

## VIII.1 The book as data

`docs/handbook/BOOK.yaml` is the single manifest: the document identity (`CF2A-01`, title,
subtitle, issue date, scope, classification), the eight parts with their files, and the
figure registry that maps every figure code to its SVG (BOOK.yaml). Its four rules are
load-bearing (BOOK.yaml, `rules:`):

1. One id resolves to exactly one object across the set, and ids are never reused.
2. A chapter that measures a contract state different from Part IV amends the register row
   in the same commit.
3. The contents table is generated from the manifest; a file present on disk and absent
   from the manifest is a build error.
4. A part with no files renders as one page naming what is missing — never silently
   skipped.

The addresses come from the manifest, not from the file tree: parts `I–VIII`, figure codes
`x.y`, table codes `TABLE x.y-n` assigned mechanically at build time, and the `M0–M12`
module ids survive only as a crosswalk into the addresses (STYLE-CORRECTIONS.md, "The fix
that makes the rest hold"). The contents sheet is generated from the manifest for the same
reason — an index that disagrees with the pages cannot be produced (BOOK.yaml, header).

## VIII.2 The build gates, in order

The builder is `scripts/build_book.py`; it renders the manifest through the nasa-handbook
skill's own template, renderer and checker (build_book.py header). The gates run in this
order, and each one owns an exit code:

| # | Gate | Fails on | Exit | Where |
|---|---|---|---|---|
| 1 | markdown lint | stray backslash-newline, unbalanced backticks, markdown-escaped pipes in code spans, stray quote escapes — in any file the manifest renders | 2 | `handbook_lint.py` (`:53-90`), called at `build_book.py:485-490` |
| 2 | manifest assembly | a manifest file missing from disk, or a module chapter whose centered-view figure SVG is missing, each rendered as a BUILD ERROR sheet | — (visible in the book) | `build_book.py:610-652` |
| 3 | pagination | any `.page` div taller than one page's content area — split by forward assembly, tables split between rows with the header cloned and a "Table continues — units a–b of N" placard | — | `PAGINATE_JS` (`build_book.py:89-429`) |
| 4 | fit line | `data-fit` reads OVERFLOW — the template's own measurement over every page | 3 | `build_book.py:716-720` |
| 5 | page parity | the `.page` div count and the PDF page count disagree | 2 | `build_book.py:721-723` |
| 6 | folio stamp | — (stamps the document number and issue date in Letter Gothic after print) | — | `build_book.py:725` |
| 7 | furniture: running heads | any page after the cover whose top band lacks `CF2A-01 ·` | 2 | `build_book.py:730-741` |
| 8 | furniture: body fit | any page whose body blocks end below the 276 mm limit | 2 | `build_book.py:744-756` |
| 9 | furniture: codes, tabs, notices, ink | fewer than 100 `TABLE x.y-n` codes, any page without a thumb tab, no NOTE/CAUTION/WARNING label rendered, any `#999999` stroke or fill | 2 | `build_book.py:758-799` |
| 10 | skill checker | page size, black-and-white-only, or 300 dpi tile checks fail in the skill's `check.py` | 2 | `build_book.py:801-821` |
| 11 | font census | Routed Gothic or Letter Gothic absent from the embedded fonts | 2 | `build_book.py:824-831` |

A green build prints one line that names every gate: page count, head + tab + dated foot on
every page, the fit reading, table-code count, continuation unit counts, notice-label count,
checker status and the font list (`build_book.py:833-838`). The figure generator runs its
own three gates upstream of any build — every SVG parses, the smallest label clears the
2.05 mm floor at print scale, and the ink is black and white only — with state carried by
line style: solid PROVEN, long-dash PARTIAL, fine-dash BROKEN, dotted MISSING/UNVERIFIED
(`gen_handbook_figures.py` header and `:780-885`).

## VIII.3 The audit rubric

Delivery is judged against the nasa-handbook genre by a vision audit, mechanically
cross-checked. The 2026-11-07 audit was a five-seat pass over all 68 pages of
`CF2A-01-house-style.pdf` — every page vision-checked, plus mechanical verification of
fonts, span colours, fills, rule geometry and block coordinates — and returned
**FAIL — 26 findings** (AUDIT-2026-11-07.md header). The findings are grouped in five
families and tagged with the wave that owns the fix:

- **A — set-wide shell** (A1–A11): ink not pure black, wrong typeface and size, missing
  running heads, orphaned headings, footer defects, cover duplication, markdown debris
  printed verbatim, hyphen breaks inside code tokens, list numbering restarting, gap-sheet
  presentation.
- **B — figures** (B1–B8): graphviz-look instead of line drafting, edge labels not `CT-nn`,
  missing components, wrong figure-code family, sub-floor labels, cited-but-missing
  figures (a build error), undersized figures, colour where the genre is black and white.
- **C — tables** (C1–C4): no table codes, carried tables without continuation declarations,
  cells breaking frames, typos and non-monotonic register order on table faces.
- **D — genre blocks** (D1–D4): no NOTE/CAUTION/WARNING notices, no flight data file card,
  no change bars, no thumb tabs.
- **E — structure and prose** (E1–E5): no set-wide paragraph numbering, round chatter and
  second person on page faces, a contents table that cannot locate anything, register rows
  contradicting the chapters, and six of eight parts not written.

The re-audit grades each prior finding, one by one. Its output is a per-finding table with
page evidence, a grade of **FIXED**, **PARTIAL**, or **STILL PRESENT** for every finding in
the baseline, any new regressions the rebuild introduced, a letter grade against the genre,
and the single highest-impact remaining fix (deleg_3af37f09 kickoff; AUDIT-2026-11-07.md,
re-audit section). The three grades are exact, and each grade is a claim bound to page
evidence: FIXED where the page evidence shows the defect class gone, PARTIAL where the
class is gone from the formerly flagged pages but survives on new ones (the C4 table-typo
finding was graded PARTIAL on exactly that shape — the register now monotonic, the
`coding-herms-scheduler` typo still on the IDENTITY face), STILL PRESENT where the class
shows no progress (the notice family graded STILL PRESENT with 2 NOTE, 0 CAUTION, 0
WARNING in 184 pages). The W3 re-audit returned
**12 FIXED · 12 PARTIAL · 8 STILL PRESENT**, grade **C+** on a prior FAIL
(AUDIT-2026-11-07.md, re-audit header).

## VIII.4 The delivery rule

A build that fails a gate is not delivered. The rule has teeth because every gate exits
non-zero and the builder stops at the first failure: a lint finding never reaches print, an
overflow never reaches a folio, a headless page never reaches the font census. The gates
also make silence impossible in both directions — `.page { overflow: hidden }` hides an
overfull page from the reader, which is why the fit measurement exists at all
(`build_book.py:409-412`), and a missing manifest entry is a build error rather than a
quietly absent part (BOOK.yaml, rule 3).

The corollary governs the working tree: a build run against a tree whose sources fail lint
is not a near-miss, it is a different artifact, and its output is not cited as evidence
about the book. The build's OK line is the only delivery receipt.

## VIII.5 Worked example — the 2026-11-07 wave sequence

The same day produced the book's first full delivery cycle, and it is the worked example
because every rule above was exercised once:

1. **Audit.** The five-seat audit graded the 68-page house-style build FAIL with 26
   findings in families A–E, and published a fix order: house-style render and pagination
   first, then the type system and ink, then line-drawn figures from the corrected model,
   then prose voice and set-wide numbering, then genre blocks, register reconcile and the
   missing parts (AUDIT-2026-11-07.md, "Fix order").
2. **Waves W1–W5.** Five fix waves ran in that order — W1 shell, W2 visual graph, W3 genre
   blocks, W4 prose voice, W5 reconcile and fill — each owning the findings tagged to it
   (AUDIT-2026-11-07.md header).
3. **Rebuild.** The rebuilt book was a new artifact: pure black ink, 8pt serif, head and
   folio on every page, build-time pagination, 16 hero figure sheets including 13 module
   centered views from a 27-component, 16-flow model — 184 pages (deleg_3af37f09 context).
4. **Re-audit.** The W3 re-audit graded it C+ against the same 26 findings — 12 FIXED,
   12 PARTIAL, 8 STILL PRESENT — and filed the W6 correctness wave as FIRST, "blocks
   trust": inverted imposition order, a table-merge corruption, stranded header-only tables
   and negative byte counts printed as data (AUDIT-2026-11-07.md, W6 section).
5. **W6 root cause.** The audited hypothesis was wrong. Block order inside pages was
   correct; the PAGE order was inverted. The old splitter peeled trailing blocks off the
   end into one continuation div, so when the continuation itself overflowed, page k+1
   always received content earlier than page k and every multi-page split imposed in
   reverse. The fix rewrote the pagination as forward assembly — walk content in reading
   order, cut at the first block or first non-fitting table row that crosses the budget,
   carry the cut onward — proven by hashing the pre- and post-pagination content streams
   in a live browser: identical (AUDIT-2026-11-07.md, W6 resolution, R1).
6. **Gates green, then delivered.** The W6 build (`CF2A-01-w6.pdf`, 156 pages) passed lint
   clean, dochead and folio on every page, and a clean fit — the old splitter's
   mostly-empty continuation sheets were gone with the page-count drop from 184 to 156
   (AUDIT-2026-11-07.md, W6 resolution). The build's OK line is what made 156 pages the
   delivered count.

The loop that drove the waves is the panel loop: one writer, five judge families, a
triage step that dedupes and ranks corrections, and repeat — with three stop conditions
in order: unanimous pass, two consecutive rounds with no new defect class, or the cap
(PANEL-LOOP.md, "The loop" and "Why the loop is capped"). The waves are that loop with the
fix order as the group boundary, and the re-audit is the loop's own evidence discipline:
every grade carries page evidence, and a finding that cannot be repeated by a command or a
quoted line does not count (PANEL-LOOP.md, "Judge rules").

## VIII.6 What delivery owes the reader

The delivery surface is two contracts in the register. CT-16 carries the module status
word from the documentation gate to the handbook, read at build time; CT-18 carries the
approval artifact from the handbook to the owner, and its state is the register's own:
UNVERIFIED until the build runs and the OK line exists (Part IV). A delivered book with no
green OK line is a rumour of a book — the same rule the rest of the system runs on.
