#!/usr/bin/env python3
"""bunker_exec.py — the ONE definition of the bunker exec stream ceiling (CF-247).

`bunker exec` streams a single gRPC call whose client deadline is a hard 300 s.
The `--timeout` flag it accepts is NOT that deadline: it is spent on the remote
side, so a budget above the ceiling cannot be honoured through one exec stream —
the call dies at the client first. Measured on 2026-11-21:

  bunker --server bunker-las-03 exec cf-node --timeout 600 -- sh -c "sleep 330; echo SURVIVED-330"
  -> deadline_exceeded ... Client.Timeout exceeded while awaiting headers, real 5m0.106s

So the probe scripts that hand their own `--timeout` to a `bunker exec` must not
pretend a larger budget works. They refuse up front, before any network call,
and say why. That refusal lives here rather than in either probe so there is a
single ceiling to change and a single sentence to quote:

  scripts/node_freshness.py   (III.M1.S5 — prove the node works)
  scripts/node_seed_drift.py  (III.M1.S4 — seed/env drift)

Values at or below the ceiling are untouched: they behave exactly as before.
A caller that needs to outlive the ceiling must stage the run and detach it, or
split it into several exec round trips of <= 300 s each.

stdlib only, no imports of the siblings (they import this).
"""

from __future__ import annotations

# The gRPC client deadline of one `bunker exec` stream. Not a suggestion: it is
# fixed client-side, so a larger remote budget is silently unreachable.
BUNKER_EXEC_CEILING_S = 300


def exceeds_ceiling(requested: int) -> bool:
    """True when a requested exec budget cannot be honoured by one exec stream."""
    return requested > BUNKER_EXEC_CEILING_S


def ceiling_error(flag: str, requested: int) -> str:
    """The refusal sentence: names the flag, its value, and the ceiling.

    One wording for every caller — a CLI that re-typed this would drift from the
    ceiling it quotes, which is the defect this module exists to prevent (the
    QA-CODE-FACTORY-2 lesson: a copied sentence loses a word and the copy is what
    an operator reads).
    """
    return (
        f"{flag} {requested} exceeds the bunker exec stream ceiling "
        f"({BUNKER_EXEC_CEILING_S}s); the client deadline is fixed — stage the run "
        f"and detach, or keep the budget <= {BUNKER_EXEC_CEILING_S}s"
    )
