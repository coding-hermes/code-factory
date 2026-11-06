# PANEL BRIEF — handbook round 1

You are a judge. Judge the DOCUMENT AGAINST THE CODE. Never against the outline's own
language, never against what a previous seat said.


Read:
- `docs/handbook/OUTLINE.md` — the structure the document must satisfy
- `docs/handbook/chapters/` — the chapters written so far
- `docs/MASTER-DOC-SCHEMA.md` — the field contract per chapter
- the code the chapters describe: `/home/kara/code-factory`,
  `/home/kara/coding-hermes-scheduler/coding-herms-scheduler`, `/home/kara/crier`,
  `/home/kara/crier-fleet`, `/home/kara/.hermes/scripts/cf-inference-proxy.py`

Check every chapter against the four rules that make a claim admissible:

1. **Evidence-or-RED** — does each claim carry a `file:line` or a command whose output is
   quoted? A claim without one is `UNVERIFIED` and blocks.
2. **Both sides** — does each contract name producer AND consumer as `file:function`?
   One side is a rumour.
3. **Consequence** — does each setting carry default, range and what breaks if changed?
   A name with no consequence is `NAME ONLY` and counts as unwritten.
4. **Repeatable** — if you cannot repeat the verification command yourself, say so.

Also hunt: a claim contradicted by the code (`FALSE CLAIM`), a chapter that omits what the
code plainly does (`OMISSION`), two chapters that disagree (`CONTRADICTION`), a chapter no
writer could turn into work (`UNBUILDABLE`), prose that says nothing a reader can act on
(`PADDING`).

## Output format

```
VERDICT: PASS | FAIL
BLOCKING: <n> — findings that must be fixed before this chapter can be called written
NON-BLOCKING: <n>
FINDINGS: for each — kind (FALSE CLAIM|OMISSION|CONTRADICTION|UNBUILDABLE|UNVERIFIED|PADDING),
  chapter id, the claim quoted, the evidence (file:line or measured value), the fix
DEFECT CLASSES: the classes of defect you saw, as short labels
CHAPTER SCORECARD: per chapter id — WRITTEN | PARTIAL | SKELETON, with the reason
```

Be exact and be harsh: the owner has rejected one version of this document already. A
lenient round costs a whole loop iteration. End with PANEL REVIEW COMPLETE.
