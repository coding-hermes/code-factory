#!/usr/bin/env python3
"""CF-544 consistency arm: the M4 §15.2 claim-ordering rule and the CV-04 claim
vectors must state ONE ordering rule, and the digests the vectors assert must
recompute.

Surfaces reconciled (the rule must be identical on all of them):
  1. The JSON Schema const — docs/handbook/conformance/schemas/cf2a.board-claim.schema.json
     is the declared ONLY home of the ordering literal; a paraphrase cannot be
     represented at all.
  2. docs/handbook/contract-vectors.json — every embedded/standalone `ordering`
     value (CV-04-A, CV-04-D, CV-19-*) and the digests CV-04-A / CV-04-D assert
     (sha256 of the exact canonical JSON string, per the file's canonicalization
     header).
  3. docs/handbook/chapters/M4-board.md §15.2 — the normative prose: claims
     listed in ascending (created_seq, task_id) order, "The ordering does not
     include priority".

The chosen rule (CF-544): `created_seq ASC, id ASC; dependencies must be
settled; correction retains its original worker`, claims sorted ascending by
(created_seq, task_id), priority excluded. The implementation that ranks the
board agrees: the schema const refuses any other literal, CV-19-A and
tests/test_p5g15_schema_rules.py already enforce it, and neither boardctl nor
node-bus-worker.py reads priority when ranking claims (SYSTEM-MODEL.yaml:
"ordering: ascending (created_seq,id) ...; lane priority is not a task field").

Usage: test_claim_ordering_consistency.py [vectors_copy] [chapter_copy]
tests/selftest.sh passes fixture copies to prove this checker FAILS (naming
both surfaces) when §15.2's ordering sentence is reverted to the other rule.
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VECTORS = ROOT / "docs" / "handbook" / "contract-vectors.json"
CHAPTER = ROOT / "docs" / "handbook" / "chapters" / "M4-board.md"
SCHEMA = (
    ROOT
    / "docs"
    / "handbook"
    / "conformance"
    / "schemas"
    / "cf2a.board-claim.schema.json"
)

CHOSEN_LITERAL = (
    "created_seq ASC, id ASC; dependencies must be settled; "
    "correction retains its original worker"
)
DRIFT_LITERAL_PREFIX = "priority DESC"
S152_HEADING = "### 15.2"
S152_NEXT = "### 15.3"


def fail(surface_a: str, surface_b: str, detail: str) -> None:
    print(
        f"FAIL claim-ordering surfaces disagree: {surface_a} vs {surface_b}: {detail}"
    )
    raise SystemExit(1)


def main() -> int:
    vectors_path = Path(sys.argv[1]) if len(sys.argv) > 1 else VECTORS
    chapter_path = Path(sys.argv[2]) if len(sys.argv) > 2 else CHAPTER

    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    const = schema["properties"]["ordering"]["const"]
    if const != CHOSEN_LITERAL:
        fail(
            "cf2a.board-claim.schema.json properties.ordering.const",
            "CF-544 chosen rule",
            f"schema const is now {const!r}",
        )

    doc = json.loads(vectors_path.read_text(encoding="utf-8"))
    for vec in doc["vectors"]:
        vid = vec.get("id", "<no-id>")
        # Every standalone ordering field in the vectors must be the schema const.
        if "ordering" in vec and vec["ordering"] != const:
            fail(
                f"contract-vectors.json {vid}.ordering",
                "cf2a.board-claim.schema.json const",
                f"vector carries {vec['ordering']!r}",
            )
        # Every canonical claim request embeds the ordering literal in its body.
        for key in ("claim_request_canonical_json", "canonical_json"):
            body = vec.get(key)
            if not body or "ordering" not in body:
                continue
            embedded = json.loads(body).get("ordering")
            if embedded != const:
                fail(
                    f"contract-vectors.json {vid}.{key}",
                    "cf2a.board-claim.schema.json const",
                    f"canonical JSON carries {embedded!r}",
                )
        # The digests the claim vectors assert must recompute from the exact bytes.
        for ckey, hkey in (
            ("claim_request_canonical_json", "claim_request_sha256"),
            ("canonical_json", "canonical_sha256"),
        ):
            body = vec.get(ckey)
            claimed = vec.get(hkey)
            if body is None or claimed is None:
                continue
            actual = hashlib.sha256(body.encode("utf-8")).hexdigest()
            if actual != claimed:
                fail(
                    f"contract-vectors.json {vid}.{hkey}",
                    f"the {ckey} bytes it covers",
                    f"recomputes to {actual} (vector claims {claimed})",
                )

    chapter = chapter_path.read_text(encoding="utf-8")
    start = chapter.find(S152_HEADING)
    end = chapter.find(S152_NEXT, start)
    if start == -1 or end == -1:
        fail(
            f"{chapter_path.name} §15.2",
            "the vectors",
            "the §15.2 section heading is missing",
        )
    section = chapter[start:end]
    if "The ordering does not include priority" not in section:
        fail(
            f"{chapter_path.name} §15.2",
            "cf2a.board-claim.schema.json const / CV-04 vectors",
            "the priority-exclusion sentence is gone or reworded",
        )
    if "(created_seq, task_id)" not in section:
        fail(
            f"{chapter_path.name} §15.2",
            "cf2a.board-claim.schema.json const / CV-04 vectors",
            "the ascending (created_seq, task_id) sort is gone",
        )
    if DRIFT_LITERAL_PREFIX in section:
        fail(
            f"{chapter_path.name} §15.2",
            "cf2a.board-claim.schema.json const / CV-04 vectors",
            "the reverted priority-first rule reappeared",
        )

    print(
        "PASS claim ordering is single-sourced: schema const, CV-04/CV-19 vectors, "
        "digests and M4 §15.2 all state the chosen rule "
        f"({CHOSEN_LITERAL.split(';')[0]}; priority excluded)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
