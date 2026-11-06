# Outline quorum — four rounds

| Round | Outline | Sol | GLM | Kimi | Grok | DeepSeek | Result |
|---|---|---|---|---|---|---|---|
| 1 | v1 (9 modules, 10 flows) | REJECT | ACCEPT-C | ACCEPT-C | REJECT | ACCEPT-C | 2 REJECT |
| 2 | v2 (+M9–M12, 16 flows) | REJECT | ACCEPT-C | ACCEPT-C | REJECT | ACCEPT-C | 2 REJECT |
| 3 | v3 (scope boundary, decision rules) | REJECT | ACCEPT-C | ACCEPT-C | ACCEPT-C | ACCEPT-C | 1 REJECT |
| 4 | v4 (+M3.S3 hooks) | **ACCEPT-C** | ACCEPT-C | ACCEPT-C | ACCEPT-C | ACCEPT-C | **5/5 ACCEPT — unanimous** |

ACCEPT-C = ACCEPT WITH CORRECTIONS: the structure is right, the remaining items are
detail to fold in while writing, not structural defects.

## What each round changed, and why

1 → 2: four seats independently named the same omission — the scheduler, crier, the
dispatcher and the inference proxy were entries in a contract table, not systems. They
became M9–M12. Six flows added (admission, credentials, upgrade/migration,
observability ingestion, backup/restore, multi-node fan-out). Part VIII added for
prompts, skills, config, patches, tests. Headings 11 → 13 with each heading required to
name the empty sentence it prevents.

2 → 3: the gaps turned out to be a **scope disagreement**, not omissions — one seat
counted every internal Go package, another counted what a run reaches end to end.
v3 states the boundary (submodule granularity, not package granularity) and gives two
headings decision rules: classification of a unit, and what makes a setting *documented*
(default + range + one consequence, else `NAME ONLY` and unwritten).

3 → 4: clustered all five seats' gap lists by keyword and folded in only items named by
three or more. Exactly one qualified that had no home: **git hooks** (5/5 seats). Now
M3.S3 — including the bypass, because a hook that silently does not run is
indistinguishable from a clean tree.

## The merge proposal

FAIL in every round, 5/5. Settled. Criterion: a module that owns a rendered primary
flow, a live credential surface or an emergency-class failure mode stays independently
addressable however small its code. M3 owns F5 LANDING, so it cannot be folded.

## Residual corrections (detail, not structure)

- Heading 5 needs an enumeration source and a count reconciliation, so a writer cannot
  claim "selected settings" and stop.
- Heading 10 needs the indication expected after each recovery step, in Apollo form.
- Per-seat grouping moves: 4–12 each, mostly units sitting in a neighbour's submodule.

These are taken into the writing pass; each produces `file:line` evidence as it is
written, which is cheaper and more accurate than another outline round.
