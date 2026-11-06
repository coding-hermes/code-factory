# PANEL LOOP — one writer, five judges, repeat until the document stops losing

Bane's model, stated plainly: *one ancient DeepSeek writes the handbook. The panel
reviews. DeepSeek makes the corrections. It goes back to the panel. Loop until the
document is aligned.*

This is the DAGger-v2 panel pattern applied to the handbook. One writer session, five
judge families, an explicit iteration cap, and a durable record of every round so the
loop can be inspected after the fact rather than trusted.

## The loop

```
writer  →  docs/handbook/round-N/   (writes/rewrites chapters)
panel   →  _panel/round-N/seat-<family>.txt  (judges, independent, staggered)
triage  →  _panel/round-N/CORRECTIONS.md     (dedupe, classify, rank)
repeat  →  writer applies CORRECTIONS, round N+1
```

Stop conditions, in order — first one reached wins:

1. **UNANIMOUS PASS** — all five seats return `VERDICT: PASS` with zero blocking findings.
2. **NO NEW DEFECT CLASS** — two consecutive rounds where no seat names a *class* of defect
   not raised in an earlier round, and every blocking finding from the previous round is
   either fixed or explicitly rejected with a reason.
3. **CAP** — the round cap configured for the run, whichever of 1 or 2 has not fired.

A round that counts is a round with a written `CORRECTIONS.md`. A round where a seat
failed to return, or returned without headings, does not count toward the cap and is
re-run for that family only.

## Writer rules (DeepSeek)

- Writes against `docs/handbook/OUTLINE.md` and reports which chapters it touched.
- **Evidence-or-RED.** A claim needs a `file:line` or a command actually run. A chapter
  that stays RED is a valid outcome; a green chapter without evidence is a lie the panel
  will find, and finding it costs a whole round.
- May not invent an acceptance command without running it at least once.
- May not adopt the document over the code: if they disagree, the code is right and the
  disagreement is a finding to file in the round.
- Every round ends with a manifest: chapters written, chapters still skeleton, RED field
  count by chapter, commands run with their output.

## Judge rules (five families)

- Judge the **document against the code**, never the document against its own outline.
- Every finding carries the chapter id and either a `file:line` or a measured value.
- Classify each finding: `FALSE CLAIM`, `OMISSION`, `CONTRADICTION`, `UNBUILDABLE`,
  `UNVERIFIED`, `PADDING`.
- A finding that cannot be repeated by a command or a quoted line is `UNVERIFIED` and
  blocks until the writer either produces the evidence or deletes the claim.
- Do not soften. The owner has rejected one version already; a lenient round wastes the
  loop.

## Why the loop is capped

Five families do not converge on "nothing left to say" — they converge on "nothing left
to say that changes the structure." Sol's round-3 list was not a subset of its round-2
list, which is the signature of a reviewer re-reading a system, not of a document
converging. The cap makes the stopping condition a property of the work rather than a
property of the reviewer's stamina.
