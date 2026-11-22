# docs/ — 00-INDEX

Entry point for every tracked document in this tree, and the statement of who
the documentation is for and the boundary it obeys. The boundary is enforced by
`tests/test_docs_template_boundary.py`; this file is graded by the same check.

## Audience and the template boundary

code-factory is published as a **base template**: a reader clones this repo to run
their own fleet of coding agents on their own hosts. The reader of `docs/` is that
template user — an operator provisioning a control host, bunker servers and nodes
from this tree — not the operator of any particular existing deployment. Nothing in
a tracked document may read as configuration that only works on one machine.

- Tracked documents use `$HOME`, `~/` or `<path>` placeholders for operator-owned
  paths. A document that names a real host home path fails
  `tests/test_docs_template_boundary.py`, which scans every tracked `docs/**/*.md`
  and `README.md` for `/home/<name>/…` spellings and lists every offender as
  `file:line`.
- Quoted measured output — log lines, probe transcripts, audit records — may keep
  the path the run really touched; evidence stays verbatim. Every such survivor is
  an explicit waiver entry in `tests/test_docs_template_boundary.py` carrying its
  file, an anchor substring and the reason. The check fails if a waiver stops
  matching the tree, so the waiver list cannot rot into a silent allowlist.
- Replayable command lines are instructions, not evidence: they are written
  against `$HOME`/`~` so a template user can follow the documents without editing
  paths. Where a published transcript records host-specific addressing, the
  addressing is replaced and the verdict kept verbatim — the convention already
  carried by `docs/handbook/chapters/M6-documentation.md` §III.M6.S7 and the
  CF-378 redactions inside the handbook.
- This extends, and does not replace, the publication gate in
  `tests/selftest.sh` section 61 (`cf050_publish_gate`, CF-050), which grades the
  same leak family over the whole published tree at HEAD plus index.

## Map

| Entry | What it is |
|---|---|
| `DESIGN.md` | the node design authority (`README.md`, "What a node is") |
| `PRD-code-factory.md` | the product requirements record |
| `OPERATIONS.md` | operator-side runbook for the node lifecycle |
| `SCHEDULER-ADMISSION.md` | scheduler admission contract |
| `handbook/` | the master handbook; `handbook/README.md` is its table of contents and honest status |
| `handbook/appendices/units/` | the per-file evidence layer (its own `00-INDEX.md` lists every unit) |
| `handbook/chapters/` | the handbook chapters (M-numbered) |
| `audits/` | dated audit and fix records; an audit's job is to quote what it measured |
| `dogfood/` | dated dogfood run records |
| top-level plan/threat/trace documents | `ACCEPTANCE-PLAN`, `HARDWARE-PLAN`, `HARNESS-CONFORMANCE`, `LOOP-CODEX`, `MASTER-DOC-SCHEMA`, `MVP-PLAN`, `REPOSITORIES`, `RUMSFELD`, `SECURITY-TRIAGE`, `THREAT-MODEL`, `BOARD`, `traceability-doctrine` |
| registries | `SYSTEM-MODEL.yaml`, `UNIT-MAP.yaml` |
