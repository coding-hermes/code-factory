#!/usr/bin/env python3
"""Check the P5G-02 durable-records specification oracle offline."""

from __future__ import annotations

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
M9 = ROOT / "docs" / "handbook" / "chapters" / "M9-scheduler.md"
FLOWS = ROOT / "docs" / "handbook" / "parts" / "II-flows.md"

REQUIRED_M9_TERMS = (
    "target contract",
    "logical records",
    "The scheduler\nowns",
    "the supervisor\nowns",
    "Crier owns",
    "store_version: 1",
    "state_version",
    "transition_id",
    "Foreign keys",
    "allowance >= consumed + reserved",
    "One local atomic transaction",
    "only then call create-or-discover",
    "only then send result",
    "only then acknowledge report custody",
    "only then emit success/follow-up",
    "unknown/hold",
    "integrity incident",
    "This vector is a specification oracle, not a runtime test",
)

REQUIRED_VECTOR_CASES = (
    "No admission commit",
    "Admission and Crier delivery",
    "l=NEVER_ACCEPTED",
    "l=?",
    "native is running",
    "Result `R` and outbox durable",
    "sink contains matching `P`",
    "sink authoritatively absent",
    "final commit absent",
    "Crier says acked but supervisor has no result",
)


def check(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)
    print(f"PASS {message}")


def section(text: str, heading: str, next_heading: str) -> str:
    start = text.index(heading)
    end = text.index(next_heading, start)
    return text[start:end]


def main() -> int:
    m9 = M9.read_text(encoding="utf-8")
    flows = FLOWS.read_text(encoding="utf-8")
    durable = section(
        m9,
        "### 17.1 Durable transition groups and recovery oracle (P5G-02)",
        "## 18. Hook plan and receipts",
    )

    check("P5G-02-V1" in durable, "M9 names the P5G-02-V1 oracle")
    for term in REQUIRED_M9_TERMS:
        check(term in durable, f"M9 contains {term!r}")
    for case in REQUIRED_VECTOR_CASES:
        check(case in durable, f"vector contains {case!r}")

    # Count the named cases as the oracle; markdown table formatting is not
    # itself a contract and may include a separator/header representation.
    check(
        sum(case in durable for case in REQUIRED_VECTOR_CASES) == 10,
        "vector has ten named crash cases",
    )
    for count in ("(0,0,0,0)", "(0,1,0,0)", "(1,0,1,0)", "(1,0,1,1)"):
        check(count in durable, f"vector includes expected count {count}")

    check("M9\n§17.1" in flows, "F1/F8 points to the single M9 recovery oracle")
    check("M10 §16" in flows, "F1 names Crier custody version 16")
    check(
        "legacy node bus worker" in flows,
        "F1 labels measured legacy behavior separately",
    )
    check(
        len(
            re.findall(
                r"^ch:trace row=P5G-02 .*test=tests/test_durable_records_vector\.py",
                m9,
                re.MULTILINE,
            )
        )
        == 1,
        "M9 has one P5G-02 trace marker for this command",
    )
    check(
        "spec=docs/handbook/OUTLINE.md#p5g-02-or-III.M9.S3" in m9,
        "trace marker names the outline authority",
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, ValueError) as error:
        print(f"FAIL {error}")
        raise SystemExit(1)
