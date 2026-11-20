#!/usr/bin/env python3
"""Check the P5G-02 durable-records specification oracle offline.

CF-497: every required element of M9 §17.1 is asserted structurally — an exact
markdown table row (cell by cell), an exact full line or contiguous line block,
or an exact count tuple parsed out of a table cell — so a one-character drift in
the chapter fails the oracle by name instead of leaving a substring alive.

The same assertions run a second time against in-memory mutations of the chapter
(the red control) inside this invocation. The control writes no file.
"""

from __future__ import annotations

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
M9 = ROOT / "docs" / "handbook" / "chapters" / "M9-scheduler.md"
FLOWS = ROOT / "docs" / "handbook" / "parts" / "II-flows.md"

SECTION_HEADING = "### 17.1 Durable transition groups and recovery oracle (P5G-02)"
NEXT_HEADING = "## 18. Hook plan and receipts"

COMMIT_TABLE_HEADER = "| Commit point, in order | One local atomic transaction; action permitted only after durable commit |"
VECTOR_TABLE_HEADER = (
    "| Durable / observed facts at crash | Required next action and expected counts |"
)

# Eight commit-point rows, in order: (element name, exact first cell, exact second cell).
COMMIT_POINTS = (
    (
        "M9.commit-point[Manager admission]",
        "Manager admission",
        "§1.9.2 CAS, operation, dedupe receipt and event outbox; return accepted only after fsync and required config projection readback.",
    ),
    (
        "M9.commit-point[Scheduler admission].then-send-the-same-round-admission.v1-identity-to-Crier",
        "Scheduler admission",
        "round, held capacity, admission digest and dispatch outbox/event; then send the same `round-admission.v1` identity to Crier. Grant consume and delivery custody are separate commits (§1.9.10; M10 §16).",
    ),
    (
        "M9.commit-point[Crier delivery/retrieve]",
        "Crier delivery/retrieve",
        "Delivery plus initial reservation/receipt; later lease plus signed chain receipt. Only then return that operation's receipt; lease receipt is not a launch or result acknowledgement.",
    ),
    (
        "M9.commit-point[Supervisor worker intent].only-then-call-create-or-discover",
        "Supervisor worker intent",
        "reserve worker, attempt intent, launch identity and launch outbox/event together; only then call create-or-discover. Launcher fsyncs START_INTENT before creating a gated child, fsyncs STARTED with native identity before release (M2 §15.2). Charge exactly once upon proven start; unproven start stays reserved.",
    ),
    (
        "M9.commit-point[Supervisor terminal].only-then-send-result",
        "Supervisor terminal",
        "terminal state CAS, canonical `worker-result.v1` bytes/digest, event and result-delivery outbox together; only then send result. No input ack until Crier durably accepts matching result and returns its custody receipt (M10 §16).",
    ),
    (
        "M9.commit-point[Crier result/ack]",
        "Crier result/ack",
        "result custody, result outbox and receipt commit together; ack separately commits the same delivery/lease/result digest and receipt before returning ack. Lost response is read back, not a new execution.",
    ),
    (
        "M9.commit-point[Scheduler report].only-then-acknowledge-report-custody",
        "Scheduler report",
        "`round-report.v1` canonical bytes/digest, immutable execution outcome, received state, event and required pending projection/outbox records together; only then acknowledge report custody. Projection owner reads the sink and sends the stable effect ID only after its intent commits.",
    ),
    (
        "M9.commit-point[Projection / settlement].only-then-emit-success-follow-up",
        "Projection / settlement",
        "After sink readback, CAS its exact digest and receipt to applied with event; unavailable/conflicting readback cannot become applied. Scheduler commits settlement revision, final accounting and follow-up outbox/event together only after §1.9.9 evidence, hooks, revocation and quiescence requirements; only then emit success/follow-up. Terminal failure or partial remains distinct from success.",
    ),
)

# Ten crash cases, in order: (element name, exact facts cell, exact action cell, tuples).
VECTOR_CASES = (
    (
        "M9.vector.case[C01-no-admission-commit]",
        "No admission commit; no external effects",
        "Retry original request; before its new commit `(0,0,0,0)` and no acknowledgement.",
        ((0, 0, 0, 0),),
    ),
    (
        "M9.vector.case[C02-admission-and-Crier-delivery]",
        "Admission and Crier delivery `d` committed, response lost; no worker",
        "Read `d`, replay original receipt; `(0,0,0,0)`, no launch.",
        ((0, 0, 0, 0),),
    ),
    (
        "M9.vector.case[C03-l-NEVER_ACCEPTED]",
        "`w=reserved`, `a=intent`, launch outbox committed, `l=NEVER_ACCEPTED`",
        "Submit `l` once; before start observation `(0,1,0,0)`. On proven start charge once: `(1,0,1,0)`.",
        ((0, 1, 0, 0), (1, 0, 1, 0)),
    ),
    (
        "M9.vector.case[C04-l-unknown]",
        "Same reservation, `l=?`",
        "Quarantine; consumed 0, reserved 1, known native starts 0, final success effects 0; no new start or refund, and actual prior start count is unknown.",
        (),
    ),
    (
        "M9.vector.case[C05-native-is-running]",
        "Started `l`, charged `w`, no result; native is running",
        "Reattach, never submit another; `(1,0,1,0)`. If native state is unknown, quarantine instead.",
        ((1, 0, 1, 0),),
    ),
    (
        "M9.vector.case[C06-result-and-outbox-durable]",
        "Result `R` and outbox durable, result custody and input ack replies lost",
        "GET `d` and result; replay exact `R` and missing ack only; `(1,0,1,0)`. A different result is `RESULT_CONFLICT`.",
        ((1, 0, 1, 0),),
    ),
    (
        "M9.vector.case[C07-sink-contains-matching-P]",
        "Report `D`, projection `b` pending for `P`, sink contains matching `P`, receipt lost",
        "Adopt readback receipt and CAS `b=applied`; `(1,0,1,0)`. No second sink effect.",
        ((1, 0, 1, 0),),
    ),
    (
        "M9.vector.case[C08-sink-authoritatively-absent]",
        "Same report/projection, sink authoritatively absent",
        "Replay original effect identity once, verify `P`, then persist receipt; `(1,0,1,0)`. Unknown or conflicting sink instead holds.",
        ((1, 0, 1, 0),),
    ),
    (
        "M9.vector.case[C09-final-commit-absent]",
        "All required receipts, passing report, revocation and quiescence durable; final commit absent",
        "Commit one `settled_success` revision and follow-up outbox; after its delivery `(1,0,1,1)`. Repeat query returns the same revision, never a second success effect.",
        ((1, 0, 1, 1),),
    ),
    (
        "M9.vector.case[C10-Crier-acked-no-supervisor-result]",
        "Crier says acked but supervisor has no result and no Crier result custody",
        "Integrity incident, fence and hold; `(1,0,1,0)` if the start was proven; never invent `R` or rerun.",
        ((1, 0, 1, 0),),
    ),
)

EXPECTED_COUNT_TUPLES = frozenset(
    {(0, 0, 0, 0), (0, 1, 0, 0), (1, 0, 1, 0), (1, 0, 1, 1)}
)

# Normative prose: each element is an exact full line, or an exact contiguous block.
PROSE_BLOCKS = (
    (
        "M9.prose[target-contract]",
        (
            "This is the target contract, not a claim that the measured tables in §3 implement",
        ),
    ),
    (
        "M9.prose[logical-records]",
        (
            "these logical records or that the current dispatcher provides crash safety. The",
        ),
    ),
    (
        "M9.prose[actors.scheduler-owns]",
        (
            "logical record names in §17 are not physical SQLite table names. The scheduler",
            "owns its round/capacity, result, projection, outbox and event records; the supervisor",
        ),
    ),
    (
        "M9.prose[actors.supervisor-owns]",
        (
            "owns its worker/attempt/result/outbox/event and launcher journal; Crier owns its",
        ),
    ),
    (
        "M9.prose[actors.crier-owns]",
        (
            "delivery, lease, result custody and receipt; the manager owns its own §1.9.2 log.",
        ),
    ),
    (
        "M9.prose[envelopes.store-version-1]",
        (
            "Manager/supervisor JSONL uses `store_version: 1`; scheduler schema migration must",
        ),
    ),
    (
        "M9.prose[fields.state-version]",
        (
            "known. Every state change has a nonnegative integer `state_version` incremented",
        ),
    ),
    (
        "M9.prose[fields.transition-id]",
        (
            "once by CAS, and each event has a unique transition_id and monotonically increasing",
        ),
    ),
    (
        "M9.prose[foreign-keys-and-allowance-sentence]",
        (
            "an overwrite. Foreign keys and allowance >= consumed + reserved are checked in the",
            "same transaction; concurrent reservations cannot both spend the last unit. A sink",
        ),
    ),
    (
        "M9.prose[failure.unknown-hold-never-an-empty-set]",
        (
            "hook receipts by the identities in §1.9.9. Store or readback unavailable means",
            "unknown/hold, never an empty set. Repeat these scans until each pending item is",
        ),
    ),
    (
        "M9.prose[failure.integrity-incident]",
        (
            "An impossible combination, such as acknowledged input without matching durable",
            "result custody, or an applied projection without its matching receipt, is an",
            "integrity incident: fence, retain evidence and do not synthesize the missing fact.",
        ),
    ),
    (
        "M9.prose[standalone-vector-P5G-02-V1]",
        (
            "**Standalone vector P5G-02-V1.** Treat `D`, `R`, `P` as three distinct immutable",
        ),
    ),
    (
        "M9.prose[count-tuple-legend]",
        (
            "above once; the expected counts are `(consumed,reserved,native starts,final success",
            "effects)`, including already committed starts/effects. A sink lookup marked absent",
        ),
    ),
    (
        "M9.prose[vector-is-a-specification-oracle-not-a-runtime-test]",
        (
            "This vector is a specification oracle, not a runtime test or live qualification.",
        ),
    ),
)

# Cross-references in F1/F8, asserted as exact lines/blocks in II-flows.md.
FLOW_BLOCKS = (
    (
        "F1/F8.flows[recovery-oracle-pointer]",
        (
            "The target recovery query and independently checkable interruption vector are M9",
            "§17.1; it reconciles all simultaneous local/custody/native/sink states without",
        ),
    ),
    (
        "F1.flows[Crier-custody-version-16]",
        (
            "   the target consumer holds the 60-second `custody.v1` lease (M10 §16), and the",
        ),
    ),
    (
        "F1.flows[measured-legacy-labelled-separately]",
        (
            "   legacy node bus worker uses a 30-second lease (`scripts/node-bus-worker.py:1356,1383`),",
        ),
    ),
)

COUNT_TUPLE = re.compile(r"\((\d+),(\d+),(\d+),(\d+)\)")
SEPARATOR_CELL = re.compile(r":?-+:?")

# (label, anchor, replacement, elements the mutation must break)
RED_CONTROL_MUTATIONS = (
    (
        "No admission commit -> No admission commitX",
        "No admission commit",
        "No admission commitX",
        ("M9.vector.case[C01-no-admission-commit].row",),
    ),
    (
        "allowance >= consumed + reserved -> allowance >= consumed + reservedX",
        "allowance >= consumed + reserved",
        "allowance >= consumed + reservedX",
        ("M9.prose[foreign-keys-and-allowance-sentence]",),
    ),
)


def section(text: str, heading: str, next_heading: str) -> str:
    start = text.index(heading)
    end = text.index(next_heading, start)
    return text[start:end]


def split_row(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def table(lines: list[str], header: str) -> list[tuple[str, list[str]]] | None:
    """Parse the markdown table that starts at `header` into (line, cells) rows."""
    if header not in lines:
        return None
    rows: list[tuple[str, list[str]]] = []
    for body in lines[lines.index(header) + 1 :]:
        if not body.startswith("|"):
            break
        cells = split_row(body)
        if all(SEPARATOR_CELL.fullmatch(cell) for cell in cells):
            continue
        rows.append((body, cells))
    return rows


def has_block(lines: list[str], block: tuple[str, ...]) -> bool:
    wanted = list(block)
    width = len(wanted)
    return any(lines[index : index + width] == wanted for index in range(len(lines)))


def count_tuples(cell: str) -> tuple[tuple[int, ...], ...]:
    return tuple(
        tuple(int(part) for part in match) for match in COUNT_TUPLE.findall(cell)
    )


def evaluate(m9_text: str, flows_text: str) -> list[tuple[str, bool, str]]:
    """Run every structural element; return (element name, passed, failure detail)."""
    checks: list[tuple[str, bool, str]] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append((name, bool(ok), detail))

    try:
        durable = section(m9_text, SECTION_HEADING, NEXT_HEADING)
    except ValueError as error:
        check("M9.section[17.1] bounded by its next heading", False, str(error))
        return checks

    durable_lines = durable.split("\n")
    flow_lines = flows_text.split("\n")

    for name, block in PROSE_BLOCKS:
        check(
            name,
            has_block(durable_lines, block),
            f"expected exact line block {list(block)!r}, which is absent from §17.1",
        )

    commit_rows = table(durable_lines, COMMIT_TABLE_HEADER) or []
    check(
        "M9.commit-point-table.header[One local atomic transaction]",
        COMMIT_TABLE_HEADER in durable_lines,
        f"expected the exact header line {COMMIT_TABLE_HEADER!r}",
    )
    check(
        "M9.commit-point-table.eight-rows",
        len(commit_rows) == len(COMMIT_POINTS),
        f"expected {len(COMMIT_POINTS)} commit-point rows, parsed {len(commit_rows)}",
    )
    for position, (name, first_cell, second_cell) in enumerate(COMMIT_POINTS):
        actual = commit_rows[position][1] if position < len(commit_rows) else None
        expected = [first_cell, second_cell]
        check(
            f"{name}.row",
            actual == expected,
            f"expected cells {expected!r}, parsed {actual!r}",
        )

    vector_rows = table(durable_lines, VECTOR_TABLE_HEADER) or []
    check(
        "M9.vector-table.header",
        VECTOR_TABLE_HEADER in durable_lines,
        f"expected the exact header line {VECTOR_TABLE_HEADER!r}",
    )
    facts_cells = [cells[0] for _, cells in vector_rows if cells]
    check(
        "M9.vector-table.ten-named-crash-cases",
        len(vector_rows) == 10 and len(set(facts_cells)) == 10 and all(facts_cells),
        f"expected 10 distinct named crash cases parsed from the table, "
        f"parsed rows={len(vector_rows)} distinct-facts={len(set(facts_cells))}",
    )
    for position, (name, facts_cell, action_cell, tuples) in enumerate(VECTOR_CASES):
        actual = vector_rows[position][1] if position < len(vector_rows) else None
        expected = [facts_cell, action_cell]
        check(
            f"{name}.row",
            actual == expected,
            f"expected cells {expected!r}, parsed {actual!r}",
        )
        actual_tuples = count_tuples(actual[1]) if actual and len(actual) > 1 else ()
        check(
            f"{name}.count-tuples",
            actual_tuples == tuples,
            f"expected count tuples {tuples!r} parsed from the action cell, "
            f"parsed {actual_tuples!r}",
        )

    observed_tuples = set()
    for _line, cells in vector_rows:
        if len(cells) > 1:
            observed_tuples.update(count_tuples(cells[1]))
    check(
        "M9.vector.count-tuples.distinct-consumed-reserved-native-starts-final-success",
        frozenset(observed_tuples) == EXPECTED_COUNT_TUPLES,
        f"expected the four tuples {sorted(EXPECTED_COUNT_TUPLES)!r}, "
        f"parsed {sorted(observed_tuples)!r}",
    )

    for name, block in FLOW_BLOCKS:
        check(
            name,
            has_block(flow_lines, block),
            f"expected exact line block {list(block)!r}, which is absent from II-flows.md",
        )

    check(
        "M9.trace-marker.one-P5G-02-row-for-this-test",
        len(
            re.findall(
                r"^ch:trace row=P5G-02 .*test=tests/test_durable_records_vector\.py",
                m9_text,
                re.MULTILINE,
            )
        )
        == 1,
        "expected exactly one ch:trace row=P5G-02 line naming this test",
    )
    check(
        "M9.trace-marker.outline-authority",
        "spec=docs/handbook/OUTLINE.md#p5g-02-or-III.M9.S3" in m9_text,
        "expected the outline authority string in the P5G-02 trace marker",
    )
    return checks


def report(checks: list[tuple[str, bool, str]]) -> int:
    failures = 0
    for name, ok, detail in checks:
        if ok:
            print(f"PASS {name}")
        else:
            print(f"FAIL {name}: {detail}")
            failures += 1
    print(f"-- {len(checks) - failures} PASS, {failures} FAIL structural elements --")
    return failures


def red_control(m9_text: str, flows_text: str) -> int:
    """Mutate the chapter in memory and require the same assertions to break."""
    failures = 0
    for label, anchor, replacement, required in RED_CONTROL_MUTATIONS:
        occurrences = m9_text.count(anchor)
        if occurrences != 1:
            print(
                f"FAIL RED-CONTROL mutation={label!r}: anchor occurs {occurrences} "
                "times, need exactly 1"
            )
            failures += 1
            continue
        mutated = evaluate(m9_text.replace(anchor, replacement, 1), flows_text)
        failing = {name for name, ok, _detail in mutated if not ok}
        still_green = [name for name in required if name not in failing]
        if still_green:
            print(
                f"FAIL RED-CONTROL mutation={label!r}: mutated copy still PASSES "
                f"{still_green!r} — the checker cannot fail on this one-character drift"
            )
            failures += 1
            continue
        print(
            f"RED-CONTROL OK mutation={label!r} drifted={required[0]} "
            f"(failing elements: {len(failing)})"
        )
    return failures


def main() -> int:
    m9 = M9.read_text(encoding="utf-8")
    flows = FLOWS.read_text(encoding="utf-8")
    failures = report(evaluate(m9, flows))
    failures += red_control(m9, flows)
    return 1 if failures else 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, ValueError) as error:
        print(f"FAIL {error}")
        raise SystemExit(1)
