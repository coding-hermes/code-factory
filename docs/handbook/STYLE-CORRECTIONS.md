# Style corrections — five-seat panel vs the NASA root design

**Verdict: 5 FAIL / 5.** The panel's subject was the delivered set (Part 0, Part IV, M9,
M0, README, OUTLINE, figures), judged against `~/.hermes/skills/nasa-handbook/SKILL.md`.
Owner's complaint confirmed mechanically: the orientation layer exists as a file and is
referenced by nothing.

## Blocking defects, in fix order

1. **No front matter, no document number, no folio.** Zero `CF2A` / `SHEET n OF N` strings
   in `docs/handbook` outside panel transcripts. `README.md` opens with a round-status
   report, not a cover. The machinery exists unused: `scripts/sheet_style.py` `cover()`,
   `dochead()`, `stamp()`.
2. **Numbering is local, not set-wide.** All 13 chapters restart `## 1` … `## 13`, so "§5"
   names thirteen sections. Zero `FIGURE n-n` / `TABLE n-n` codes across 143 tables.
3. **Part 0 is orphaned.** `grep 00-overview` returns only the file itself. README's contents
   starts at I.1 and lists Part I as MISSING while line 162 says "Yes — Part I, rendered".
4. **Prose is drafting-room, not AOH.** `00-overview.md:3` addresses the reader ("Read this
   page before any chapter"); `:52` moralises ("a board that only ever moves forward is a
   board that is lying"); M9 carries **34** round-references arguing with earlier drafts;
   Part IV repeats "To close: quote the encode site…" 18 times — repair tickets in book prose.
5. **Visual layer is 3 figures in one file and 4 orphans.** 0 of 13 module chapters has a
   figure; 0 error paths drawn; model carries 16 components where README claims 27 and
   **dispatcher (M11) and inference proxy (M12) have no box at all**; contract edges are
   labelled `1`–`18` not `CT-01…CT-18`.
6. **Part IV contradicts the chapters on 11 of 18 contracts** (CT-01 PROVEN vs M9 UNVERIFIED;
   CT-02 BROKEN vs M10/M9 works; CT-06 MISSING vs M9 works; …) and contradicts itself in
   every row: state `PROVEN` beside "Sender guarantee: RED".
7. **The gate cannot see any of it.** `handbook_spine.py` passes an injected `CT-99` and
   never compares a chapter's §6 state to the register row — why 13 id schemes survived 13 rounds.

## The fix that makes the rest hold

One manifest, one numbering, one contents table.

- `docs/handbook/BOOK.yaml` — `CF2A-01`, issue date, every part / chapter / figure / table code.
- Render through `sheet_style.py` so every sheet carries `CF2A-01 · PART n · §x.y` and
  `CF2A-01 · SHEET n OF N` with the date. No hand-maintained shell.
- Addresses: parts `I–VIII`; chapters `2.1–2.16` (flows), `3.1–3.13` (modules), `4.x`;
  sections `x.y.z`; `FIGURE x.y-n`, `TABLE x.y-n`. `M0–M12` survive as one crosswalk table,
  never as addresses. `CT-nn` stays a registry id with five states:
  `PROVEN | PARTIAL | BROKEN | MISSING | UNVERIFIED`, and Part IV's table is the only authority —
  a chapter that measures a different state amends the row in the same commit.
- Findings become `FIND-nnn`, one global sequence, so `F9-2` can never be read as a flow step.
- The overview becomes front matter (`FM`), not "Part 0", and the contents table is generated
  from the manifest so it cannot disagree with the book.

## Gate additions (spine must fail on)

`CT-nn` absent from the register · chapter §6 state ≠ register row · `FIGURE|TABLE x.y-n` with
no caption · `§` reference to a missing heading · `M\d+-C\d+`, `Part 0`, `§IV`, `F\d+-\d+`,
`II\.\d+`, `III\.\d+`, `F-ROOT` present at all.

## Model gaps that block the visual layer

`SYSTEM-MODEL.yaml` defines 5 flows (F1–F5) and 16 components. The outline claims 16 flows and
27 components. **F6–F16 cannot be drawn until they exist as steps**, and the dispatcher and
proxy must be added as components before any map is honest.

## Wave 2 — the visual graph, closed (this round)

Defect 5 of this file is addressed at the model, not in prose:

- `docs/SYSTEM-MODEL.yaml` now defines **27 components** — the dispatcher (M11) and the
  inference proxy (M12) have boxes, joined by the guard, the scope minter, the provisioner,
  the verifier, the lander, the safety reaper, the doc panel and the spine gate — every one
  traceable to its module chapter, with `impl` the only volatile column.
- **F6–F16 exist as steps** (16 flows total). Every step cites the chapter text or contract
  row it came from; nothing is invented. Where a chapter measures a contract UNVERIFIED or
  MISSING, the model says so, and the contract states are the five-state vocabulary
  (`PROVEN | PARTIAL | BROKEN | MISSING | UNVERIFIED`), keyed `CT-01..CT-18` on every edge.
- `scripts/gen_handbook_figures.py` generates **32 figures**: the full system map
  (`system-map.svg`), one centred view per module (`module-M0..M12.svg` — inputs left,
  outputs right, flows below, drawn mechanically from the model), one sequence diagram per
  flow (`F1..F16.svg`), and the two state machines (`board-lifecycle.svg`,
  `tick-lifecycle.svg`). Edges carry `CT-nn` labels, state is line style + dark ink on
  white — no pastel chips — and every sheet carries a legend.
- Print legibility is a **gate in the generator**: build_book.py constrains a landscape
  figure to 170 mm (portrait 200 mm), so every shipped SVG is measured at that scale and
  the build fails if the smallest label prints below 2.05 mm. Measured minimum across the
  set: 2.18 mm (system map), 2.25 mm (module views), 2.38 mm (flows), 2.51/3.41 mm
  (state machines). All 32 parse as XML.

Known residue, disclosed: on the system map the CT-nn labels of edges that share both
endpoints can sit close enough to read as one token (CT-01/CT-05, CT-02/CT-06); graphviz
places mid-edge labels and a 27-node, 18-edge map has no collision-free spline layout at
this print width. The module views disambiguate every such pair one-to-one. `BOOK.yaml`
still lists the three old figure names (`00-system-map`, `00-board-row-lifecycle`,
`F1-dispatch`); the builder manifest needs those three rows re-pointed at
`system-map.svg`, `board-lifecycle.svg`, `F1.svg` and the module/flow figures filed in.
