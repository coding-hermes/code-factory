# Part VIII — Delivery

The book is itself a delivered artifact, and it is delivered the way work is: through
gates. This part records what the book is built from, the gates a build must pass in
order, the audit rubric that grades the result, and the delivery rule that follows from
them — a build that fails a gate is not delivered.

## VIII.1 The book as data

`docs/handbook/BOOK.yaml` is the single manifest: the document identity (`CF2A-01`, title,
subtitle, issue date, scope, classification), the nine parts with their files, and the
figure registry that maps every figure code to its SVG (BOOK.yaml). Its four rules are
load-bearing (BOOK.yaml, `rules:`):

1. One id resolves to exactly one object across the set, and ids are never reused.
2. A chapter that measures a contract state different from Part IV amends the register row
   in the same commit.
3. The contents table is generated from the manifest; a file present on disk and absent
   from the manifest is a build error.
4. A part with no files renders as one page naming what is missing — never silently
   skipped.

The addresses come from the manifest, not from the file tree: parts `I–IX`, figure codes
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
line style: solid PROVEN, long-dash PARTIAL, fine-dash BROKEN, dotted MISSING,
dash-dot UNVERIFIED
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

A build that fails a gate is not delivered. The rule has teeth because the builder stops
at the first failure: a lint finding never reaches print, an overflow never reaches a
folio, and a headless page never reaches the font census. Gates that reject the artifact
exit non-zero; manifest assembly currently renders a visible BUILD ERROR sheet without
itself stopping the process, so that exception is named and release-blocking in the
acceptance record (VIII.11). The gates also make silence impossible in both directions —
`.page { overflow: hidden }` hides an overfull page from the reader, which is why the fit
measurement exists at all (`build_book.py:409-412`), and a missing manifest entry is a
build error rather than a quietly absent part (BOOK.yaml, rule 3).

The corollary governs the working tree: a build run against a tree whose sources fail lint
is not a near-miss, it is a different artifact, and its output is not cited as evidence
about the book. The build's OK line is the only *mechanical* delivery receipt — it closes
the build/render stage and no other stage; the semantic, conformance and owner stages
carry their own results (VIII.9).

## VIII.5 The disposition log as a standing gate

The gates in VIII.2 grade the artifact; the disposition log grades the review. Every
finding — from the CF2A-01 running review, the audit rubric, or any later pass — is
recorded in the change/redline disposition log and receives exactly one disposition:
**adopted**, **rejected**, **deferred**, or **unresolved**. The log row carries the
finding's identity bound to the actual supplied revision it was raised against, the
disposition, the rationale, the owner, the replacement section, figure or contract that
implements it, and the relevant proof — a build line, a command, or a quoted page. More
pages or more audit history do not establish a corrected buildable specification; the
disposition log, not the page count, is the record that the review was answered.

The rule is a standing gate with the same teeth as the build gates:

1. A finding with no recorded disposition is an open blocker. A release whose findings
   are not all dispositioned does not ship, regardless of gate color.
2. A rejection states why the review standard does not apply — it is a decision, not a
   silence. An adoption names what replaces the defect, so the same finding cannot be
   re-adopted and re-fixed in different waves without anyone noticing.
3. Deferred and unresolved rows are re-decided at the next pass, never dropped: the next
   pass reviews newly filled pages while checking earlier redlines (handoff §3, Part
   VIII), and the log is the checklist that pass works from.
4. Dispositions are monotonic in visibility: a row may move from unresolved to adopted,
   never from adopted back to silently absent.

The log is where the review's "explicit dispositions with exact revision identities"
requirement (handoff §1.9) lives. A wave that folds review findings into the parts and
does not leave each finding dispositioned in the log has moved the defect, not closed it.

## VIII.6 Draft, release and approval identity

A draft, a release and an approval are three distinct facts about three distinct
artifacts, and each is identified exactly. No artifact carries two of the states at once,
and no state is claimed without its identity.

- **Draft.** Rendered output whose gates passed but whose review is open. Identified by
  document id, issue date, the exact source commit (full sha, not a branch name), and the
  build's OK line. A draft is not cited as evidence of correctness anywhere in the book.
- **Release.** The artifact published with its required checks satisfied. Identified by
  document id and revision, the exact source commit sha, the PDF's hash, the retained
  gate reports, and the disposition-log state — every finding dispositioned. Named
  unresolved findings still block an accepted release; deferred findings require an
  explicit scope waiver as VIII.15 specifies. A release with failed or unapproved output staged beside it identifies that
  output explicitly; it is never silently bundled (M6 review, deliverable integrity).
- **Approval.** The owner's recorded decision, bound to the exact release identity — id,
  revision, commit sha and artifact hash. An approval of "the handbook" without that
  identity approves nothing; human approval is an external decision contract, not an
  unverifiable destination (M6 review).

Supersession is explicit: a new release names the release it replaces, and the replaced
artifact is retained, not overwritten — a re-print that is indistinguishable from its
predecessor cannot be read in order of authority. CT-18 carries the approval artifact and
stays UNVERIFIED until this identity chain exists end to end (Part IV).

## VIII.7 Worked example — the 2026-11-07 wave sequence

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

## VIII.8 What delivery owes the reader — and the two wires that are not connected

Two contracts in the register carry the delivery surface, and both must be stated
truthfully (V2-DLV-02):

- **CT-16 (docsgate → handbook, UNVERIFIED).** The closing paragraph of earlier
  revisions said the module status word is "read at build time"; the register's own
  measured defect row says the opposite — *the handbook build reads no MASTER-DOC
  output*, so the receiver half is uncited (Part IV, CT-16). The register row is the
  authority: the wire is a target requirement, not a connected one, and no gate result
  is claimed to flow across it today. Saying "read at build" while the builder reads
  nothing is exactly the record-that-lies class (VI §11) — this paragraph is the
  correction.
- **CT-18 (handbook → owner, UNVERIFIED).** The owner-approval artifact is not
  verified by a build. A green OK line is a machine result about the artifact; the
  owner's acceptance is a human decision contract bound to the release identity
  (VIII.6). Structured gate-result fields and their enforcement/readback are defined in
  VIII.9/VIII.10 — and none of them closes CT-18. A green build cannot automatically
  close a human/owner acceptance boundary.

A delivered book with no green OK line is a rumour of a book; a delivered book with one
is still only *mechanically* delivered (VIII.4) — the same rule the rest of the system
runs on, applied to the book itself.

## VIII.9 The seven acceptance results

Delivery is seven separate results, each with its own evidence; no single line closes
more than its own stage (V2-DLV-01). A process cap, a no-new-defect-class STOP, or the
build's OK line cannot alone establish acceptance:

| # | Result | What it closes | Evidence | Closed by |
|---|---|---|---|---|
| 1 | Source validation | the markdown sources are valid, citable and lint-clean | gate 1 exit 0 (VIII.2) | mechanical |
| 2 | Artifact build/render | the PDF exists, paginated, furniture complete | the OK line (gates 2–11) | mechanical |
| 3 | Visual QA | rendered pages actually show what the sources say — layout semantics, labels, adjacency | the layout-semantics battery (VIII.12) on 300 dpi tiles | review, page-evidenced |
| 4 | Specification/interface completeness | the book specifies a buildable system — schemas, contracts, settings, flows | the acceptance-package map (VIII.13) checked against the product definition | review, page-evidenced |
| 5 | Cross-section consistency | parts, chapters, register and figures agree | the spine gate (M6 §5) + the same-commit amend rule + cross-page reconciliation | mechanical + review |
| 6 | Operational conformance | the specified behavior is implementable against the measured sources — states, contracts, settings map to real surfaces | source locators verified against measured revisions; UNVERIFIED contract rows named, not hidden | review with source evidence |
| 7 | Owner acceptance | the owner accepts the release | the recorded decision bound to the release identity (VIII.6) — CT-18 | human, external to this pipeline |

Results 1–2 are mechanical; 3–6 are review results with page or source evidence; 7 is an
external decision. A release claims a stage only with that stage's recorded result, and
the working-draft/accepted distinction of VIII.6 governs which of them a delivered
artifact may cite.

### VIII.9.1 Six build stages mapped to seven acceptance results

The six-stage build pipeline and seven acceptance results are not a one-to-one count.
This mapping is normative for the build receipt and disposition log:

| Build stage (M6 §16.2) | Acceptance result(s) | Evidence owner |
|---|---|---|
| 1. markdown lint | **lint** | `handbook_lint.py` output; build fails before rendering on debris. |
| 2. manifest assembly | **build** (input half) | Resolved BOOK/source inventory; any BUILD ERROR is a failed build, not a cosmetic sheet. |
| 3. pagination plus render/fit/furniture | **build** (artifact half) | PDF exists, page parity/fit/furniture/font checks and the verbatim OK line. |
| 4. visual QA | **visual_qa** | Independent rendered-page readback, figure/prose/table/font checks; build success alone cannot pass it. |
| 5. completeness plus cross-section consistency | **completeness** and **cross_section_consistency** | Separate finding/disposition and contract/state/reference reviews; neither inherits visual QA. |
| 6. operational conformance | **operational_conformance** | Executed runtime cells and their artifacts; specification-only matrices remain pending. |
| External owner decision, not a build stage | **owner_acceptance** | Human acceptance of the exact document digest; never implied by stages 1–6. |

M6 §16.2 links its six-stage pipeline overview and stage-16 receipt to this mapping;
no earlier partial or misaligned description overrides it.

## VIII.10 The release manifest

A release publishes a machine-readable manifest binding the artifact to everything that
was claimed about it (V2-DLV-01, V2-DLV-02):

```json
{
  "schema_version": "handbook-release.v1",
  "doc_id": "CF2A-01",
  "revision": "vd",
  "source_commit": "<full sha of the tree the build ran against>",
  "document_sha256": "<hash of the delivered PDF>",
  "artifacts": [{"path": "CF2A-01-vd.pdf", "pages": 182}],
  "checks": [
    {"stage": "lint",          "tool": "handbook_lint.py", "result": "pass", "exit": 0},
    {"stage": "build",         "tool": "build_book.py",    "result": "pass", "ok_line": "<the verbatim OK line>"},
    {"stage": "visual_qa",     "tool": "layout-semantics battery", "result": "<pass|fail|pending>", "findings": []},
    {"stage": "completeness",  "result": "pending", "open": ["V2-* dispositions not yet adopted"]},
    {"stage": "cross_section_consistency", "result": "pending", "findings": []},
    {"stage": "operational_conformance", "result": "pending", "findings": []},
    {"stage": "owner_acceptance", "result": "pending", "note": "human decision; never implied by any check"}
  ],
  "dispositions": {"log": "change/redline disposition log", "open_count": 0,
                   "open_ids": []}
}
```

Rules: the manifest is generated at release time, not hand-written; a check with no
recorded result is `pending`, never assumed pass; the disposition state is part of the
manifest (VIII.5's standing gate); and the produced approval *package* is separate from
the owner approval *decision* — the manifest carries the former and names the latter as
open until CT-18's decision record exists.

### VIII.10.18 Build-record layout and parse cases

`build_book.py` writes `<artifact-stem>.record.json` beside the PDF after every gate
succeeds. The `handbook-release.v1` payload contains `doc_id`, `revision`, full
`source_commit` and `source_tree`, `document_sha256`, exactly one
`{path,sha256,bytes,pages}` artifact, all seven VIII.9 check objects, current P6
`dispositions`, `build_errors`, a deterministic `record_id`, and the VIII.12.8
`memory` object. Canonical JSON is UTF-8, sorted keys, separators `,` and `:` with
no whitespace; `memory.payload_digest` is SHA-256 over the complete record except
`record_id` and `memory`. Unknown schema versions, missing fields, duplicate stages,
invalid digest/state combinations and artifact mismatches are parse refusals, not
warnings. A sidecar is a draft build receipt, never owner acceptance or a release
evaluation; external lint, visual, conformance and owner checks stay pending until
their own receipts are attached.

| Parse case | Required result |
|---|---|
| Built sidecar beside its unchanged PDF | `RECORD_OK`, with the recomputed payload digest printed. |
| Payload byte changed without updating `memory.payload_digest` | exit 2, `RECORD_FAIL … payload_digest`. |
| Artifact digest/bytes/pages or document digest changed | exit 2; artifact/document binding failure. |
| Missing/duplicate seven-stage check, unknown schema, malformed source OID | exit 2; no defaulting or partial acceptance. |
| ADOPTED disposition without a full resolving commit, or non-adopted row without reason | exit 2. |
| `sync_commit` set while `local_commit` is null, or either commit is not a full Git OID | exit 2. |

Probe: `python3 scripts/build_book.py --check-record <record.json>`. The negative
control mutates only a scratch copy; it never rewrites the delivered receipt.

## VIII.11 Per-stage failure behavior and negative controls

Every build stage's failure behavior is exact, and refusals are proven by negative
controls (V2-DLV-03). The gate table of VIII.2, completed with each stage's failure
outcome:

| Gate | On failure | Exit | Negative control |
|---|---|---|---|
| 1. markdown lint | stops the build; nothing prints | 2 | a file with a stray backslash-newline is refused before any render |
| 2. manifest assembly | renders a visible BUILD ERROR sheet naming the missing file — **and does not by itself stop the build with a nonzero exit**; that limitation is a named defect of the current builder, closed when assembly failure is promoted to an exit | — (in-book) | remove a manifest file; the BUILD ERROR sheet must appear and the release must not be cut from that build |
| 3. pagination | splits content forward; an unsplittable overflow falls through to gate 4 | — | a page that cannot split shows OVERFLOW at gate 4 |
| 4. fit line | stops the build | 3 | an oversized block yields `data-fit` OVERFLOW and exit 3 |
| 5. page parity | stops the build | 2 | — |
| 6. folio stamp | stamps after print; no failure path | — | — |
| 7. running heads | stops the build, naming the headless pages | 2 | — |
| 8. body fit | stops the build, naming page and measurement | 2 | — |
| 9. furniture | stops the build on missing tab, no notice label, or grey ink | 2 | a `#999999` stroke is refused by the ink check |
| 10. skill checker | stops the build | 2 | — |
| 11. font census | stops the build | 2 | a build with a missing face is refused |

The prose rule "every gate fails nonzero" holds for every gate **except** stage 2's
in-book BUILD ERROR sheet — the table above is the authority over the summary sentence,
and the summary sentence has been corrected to match (the record-that-lies class, VI
§11). Missing placeholder sheets render as named BUILD ERROR pages, never silently blank.

**Finding-ID arithmetic, made explicit.** The 2026-11-07 baseline audit returned **26**
findings (families A–E). The W3 re-audit's per-finding table carries **32** dispositions:
the 26 baseline findings re-graded, plus **6** new rows raised against the rebuilt
artifact (new regressions and splits introduced by the waves); 12 + 12 + 8 = 32 is the
sum over that table, not a recount of 26. Four of the new rows are the W6 correctness
wave's R1–R4; the full per-row identities are the re-audit table's record
(AUDIT-2026-11-07.md). Both denominators are now stated wherever the counts are quoted.

**Historical page counts are historical.** The 68-page house-style build, the 184-page
W3 build and the 156-page W6 build are dated evidence about those artifacts, each with
its identity — they are not proof about the current revision; the current revision's page
count is stated only by its own build line (VIII.6's identity rules).

**Review scope.** The gate commands and negative controls above are recorded as
specification, not executed against source-document instructions as part of any review;
the review reads the record.

## VIII.12 Layout-semantics tests

Fit and counts are necessary and not sufficient; the delivered pages are tested for the
intended layout semantics (V2-DLV-04):

| Test | Asserts |
|---|---|
| unique IDs | every figure/table id resolves to exactly one object in the set (BOOK.yaml rule 1) |
| heading-with-content | no heading is stranded without its first paragraph (no title-only sheets) |
| prose-under-diagram | each flow image is followed directly by its own explanatory text — no collected prose blocks pages away |
| unambiguous labels | line labels, arrows and boundaries are readable and do not cross text; leaders keep 0.6 mm clearance |
| readable widths / intact tokens | no over-shrunk cells; identifiers wrap intact, not broken |
| continuation identity | a split table repeats its identity and declares "units a–b of N" at the break |
| folios and navigation | every page carries completed page/revision furniture; the contents locates what it lists |
| fonts by role | Routed Gothic on drawing faces, Letter Gothic on the checklist card, the serif on prose — by role, not merely present somewhere; print-scale legibility on 300 dpi tiles |

**Font substitutions, assessed explicitly.** The sampled PDF embeds
LiberationSerif/DejaVuSansMono alongside Routed Gothic/Letter Gothic: the serif
substitution is the documented cross-platform body fallback (Georgia-class, acceptable
per the skill); DejaVuSansMono in code spans is accepted as the mono role. Each
substitution is a recorded acceptance in the manifest's visual-QA result, not a silent
pass.

**Footer-claim discipline.** Footer text is not declared absent or clipped from a
preview render alone: coordinate inspection of sampled pages found the footer words
present and no off-page characters. Blank field *values* and visual layout defects are
distinct findings and are recorded as the one that they are.

### VIII.12.8 Memory record durability fields

Every build receipt carries `memory.record_id`, `payload_digest`, `local_commit`,
`sync_commit`, `synced_at`, `revision` and `state`. Their meanings are exact:

- `record_id` is derived from the payload digest and is stable for identical bytes;
  a changed payload is a new record, not silent mutation.
- `payload_digest` authenticates the canonical payload before any persistence claim.
- `local_commit` is the full Git object ID only after record data, Git objects and the
  ref transaction are fsynced and read back. The build sidecar itself is fsynced, but
  it is not a Git commit, so the builder emits `local_commit: null`.
- `sync_commit` and `synced_at` remain null until the configured remote/controller
  readback names the synchronized commit. Remote sync never follows from a local file
  write; `sync_commit` without `local_commit` is invalid.
- `revision` starts at 1 for a new record identity. An authorized correction keeps the
  prior record immutable and creates a new payload/record identity with revision 1;
  synchronization metadata for the same payload may advance only through readback.

`LOCAL_RECORD_FSYNCED_NOT_GIT_COMMITTED` therefore proves only the sidecar's local
write. It does not prove DuckBrain persistence, a local Git commit, controller
replication or project acceptance.

### VIII.12.9 Builder implementation and negative control

The builder emits the VIII.10.18 record after PDF, furniture, `check.py` and font
checks pass; writes a temporary file; fsyncs it; atomically renames it; fsyncs the
containing directory; and immediately parses the result before printing `RECORD_OK`
and the normal `OK` line. A record failure fails the build. The parser independently
recomputes the artifact and payload digests and enforces the stage, disposition and
local/sync invariants.

Acceptance requires both arms: the delivered sidecar returns `RECORD_OK`; a scratch
copy whose payload is changed without its digest exits 2 with `RECORD_FAIL` naming
`payload_digest`. A successful PDF build with no record, or a record whose checks
silently turn pending external reviews into pass, is a failed delivery gate.

## VIII.13 The acceptance package map — and the three acceptance scopes

The complete build-from-spec acceptance package (V2-DLV-05) — what a reader must be able
to check out of this book to build and accept the system:

| Package element | Where it lives |
|---|---|
| Governing mission/architecture | Front matter, Part I |
| Deployment/capability profiles | Part V matrix; Part I arrangement |
| Desired-state and settings/secret schemas | Part V (V.0–V.8) |
| Management OpenAPI/utility contracts and native adapters | Part V V.6; Part IV register |
| State machines | Part VII (§2, §3, §11–§12); figures/board-lifecycle |
| Full normal/failure flows | Part II (F1–F16), Part VI (R-01…R-33) |
| Operational metrics/readout | Part VII §10; module §8 registers |
| Recovery/backup/revocation | Part VI (§17, §21, §25–§33); F8/F12/F15 |
| Version/source compatibility | Part V V.5 (pins); M5/M3 |
| Conformance scenarios | Part VI verification cases; CT-17 (UNVERIFIED, named) |

**Three separate acceptance scopes, never merged:**

1. **Handbook delivery** — the artifact of this part: gates, manifest, dispositions
   (VIII.1–VIII.12).
2. **Factory installation/readiness** — the specified infrastructure actually
   deployed and read back: profiles, credentials, memory, bindings verified per Part V
   and F2 — a different artifact (the deployment) with different evidence.
3. **Application/project delivery** — a requested project built end to end and accepted
   per Part VII §11.9 — a third scope again.

An acceptance in one scope closes nothing in another: a green handbook build does not
install the Factory, and an installed Factory does not deliver a project. Every agreed
user redline is mapped bidirectionally to its revised page/interface/figure and its
disposition-log row (VIII.5); source/version and user-feedback changes are tracked
through all affected artifacts in both directions.

## VIII.15 Machine release decision (P5-C-34/35)

VIII.10 is a normative manifest layout, not a recorded pass. The builder emits the
VIII.10.18 sidecar with unobserved external checks pending; the target release evaluator
accepts handbook-release.v1 JSON on stdin and emits `{decision,reasons,manifest_digest}`
on stdout; decision is draft/accepted/refused. Exit is 0 for accepted, 3 for a valid
review-pending draft and 2 for refused/invalid. This interface is a build-system
requirement; no existing command is asserted to implement it. Until implemented,
release is manual and must retain the same evaluated predicate and receipts.

Required manifest fields are schema_version, doc_id, revision, source_commit (full
Git OID), source_tree (full OID), document_sha256 (64 lowercase hex), artifacts,
checks, dispositions and build_errors (nonnegative integer). artifacts is a nonempty
list of `{path,sha256,bytes,pages}`, path relative, bytes/pages positive integers.
checks has exactly one of each of the seven VIII.9 stages: lint, build, visual_qa,
completeness, cross_section_consistency, operational_conformance, owner_acceptance.
Every check is `{stage,result,evidence_refs,reviewer,source_tree,document_sha256,
recorded_at,findings}` with result pass/fail/pending/waived, reviewer principal ID,
UTC time and digest-bound evidence refs; absent evidence permits pending only.
Mechanical checks additionally require exit:0 and build requires the verbatim OK line.
A review receipt is a signed JSON object with those same fields and reviewer role;
recording is an append keyed by (artifact digest,stage,reviewer,receipt digest), not
an editable checkbox. An owner decision uses a human principal and exact artifact.

Dispositions contains rows `{id,severity,state,resolving_commit,replacement_refs,
reason,owner,waiver_ref}`. State is ADOPTED/DEFERRED/UNRESOLVED/REJECTED; nullable
resolving_commit is allowed only when not adopted, nullable waiver_ref means no waiver.
Unknown/duplicate stages or finding IDs, missing digest/revision binding, unrepresented
findings or mismatching evidence are refusal. A literal BUILD ERROR sheet or a missing
manifest asset forces build_errors >0 and build.result=fail even if renderer exit=0;
the release evaluator checks both source manifest inventory and rendered page text.

Draft requires lint/build pass, build_errors=0, every finding represented and no
mechanical failure. Pending semantic reviews, unresolved findings and unapproved
deferrals are prominently listed; a draft makes no accepted-spec claim. Accepted
requires all seven stages pass, zero unresolved/undispositioned findings, and each
adoption tied to immutable source/evidence. A DEFERRED item is allowed only with an
owner-signed waiver excluding it from this release's claimed scope and a named next
review; critical security/correctness deferrals block any scope that exercises them.
Waivers never convert failed tests or pending review into pass. REJECTED findings
require recorded reviewer rationale and owner agreement. Runtime conformance and
owner acceptance cannot be inferred from lint, source additions or the build line.
A package without executable artifact pins (M11.17) remains a specification draft.

## VIII.14 Pass-3 consistency readback

Pass 3 treats cross-section consistency as a dated evidence check, not as a claim that
one corrected paragraph automatically corrected every view. Before an integrated issue
is released, the owner compares the selected normative path in Parts I–IX, the module
chapters, the contract register, the settings register, and every mounted figure. The
comparison records, for each interface, its initiator, receiver, execution location,
contract ID/version, state transition, durable writer, evidence required before the
next transition, and the disposition row that closes the review finding. A historical
measurement may remain in the record only when it is dated and explicitly labelled
historical; it cannot silently override the current contract.

The readback has four falsifiable outcomes:

1. **PASS** — every current reference resolves to one owner, location, schema and
   status vocabulary; the figure arrow and adjacent prose describe the same transition;
   and the disposition row cites the exact resolving revision.
2. **PARTIAL** — the current source is consistent, but a measured implementation or
   external boundary is not yet verified. The row names the missing evidence and stays
   `ADOPTED-IN-PROGRESS`, `DEFERRED`, or `UNRESOLVED`; it does not become a green
   conformance claim.
3. **FAIL** — any stale owner, contradictory state, duplicate identifier, unbound figure,
   or gate/status claim remains. The issue is not delivered, even when the mechanical
   build is green.
4. **NOT RUN** — no readback evidence exists. This is an open review result, never an
   inferred pass.

The pass-3 disposition log is the result ledger for this readback. Its P3 rows preserve
all 26 finding identities, identify the exact source and resolving commit (or the reason
for deferral), and distinguish a source correction from build proof, implementation
conformance, and owner acceptance. The integrated PDF's build line closes only the
mechanical stage; it does not erase a `PARTIAL`, `FAIL`, or `NOT RUN` result.
