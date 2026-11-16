#!/usr/bin/env python3
"""Deterministic P5G-15 schema and cross-reference acceptance vectors."""

from __future__ import annotations

import copy
import json
import re
import sys
from pathlib import Path

try:
    from jsonschema import Draft202012Validator
except (
    ImportError
) as error:  # pragma: no cover - the conformance dependency is required
    raise SystemExit(f"P5G-15 requires jsonschema>=4.18: {error}") from error


ROOT = Path(__file__).resolve().parents[1]
SCHEMA_PATH = ROOT / "docs/handbook/conformance/schemas/cf2a.board-claim.schema.json"
VECTOR_PATH = ROOT / "docs/handbook/contract-vectors.json"
REGISTER_PATH = ROOT / "docs/handbook/parts/IV-contract-register.md"
M4_PATH = ROOT / "docs/handbook/chapters/M4-board.md"
MODEL_PATH = ROOT / "docs/SYSTEM-MODEL.yaml"


def fail(message: str) -> None:
    raise AssertionError(message)


def expect_invalid(validator: Draft202012Validator, document: dict, label: str) -> None:
    if validator.is_valid(document):
        fail(f"negative vector accepted: {label}")


def semantic_errors(document: dict) -> list[str]:
    errors: list[str] = []
    claims = document.get("claims", [])
    task_ids = [item.get("task_id") for item in claims]
    if len(task_ids) != len(set(task_ids)):
        errors.append("duplicate task_id")
    ordering = [(item.get("created_seq"), item.get("task_id")) for item in claims]
    if ordering != sorted(ordering):
        errors.append("claims not sorted by created_seq, task_id")
    if document.get("ordering") != (
        "created_seq ASC, id ASC; dependencies must be settled; "
        "correction retains its original worker"
    ):
        errors.append("ordering literal")
    return errors


def expect_semantic_invalid(document: dict, label: str) -> None:
    if not semantic_errors(document):
        fail(f"semantic negative vector accepted: {label}")


def claim_from_vector(vectors: list[dict]) -> dict:
    vector = next(item for item in vectors if item["id"] == "CV-19-A")
    return copy.deepcopy(vector["group_claim"])


def main() -> int:
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    vectors_doc = json.loads(VECTOR_PATH.read_text(encoding="utf-8"))
    validator = Draft202012Validator(schema)
    claim = claim_from_vector(vectors_doc["vectors"])

    # CV-19-A is the positive, independently reproducible claim vector.
    validator.validate(claim)
    if claim["schema_version"] != "cf.board-group-claim.v1":
        fail("CV-19-A does not use the canonical claim version")
    if len(claim["claims"]) != 3:
        fail("CV-19-A claim count changed")

    # Shape, enum, bound and unknown-field negative arms.
    missing = copy.deepcopy(claim)
    del missing["idempotency_key"]
    expect_invalid(validator, missing, "missing required idempotency_key")

    unknown = copy.deepcopy(claim)
    unknown["unexpected"] = True
    expect_invalid(validator, unknown, "unknown root field")

    wrong_enum = copy.deepcopy(claim)
    wrong_enum["transition"] = "claim-now"
    expect_invalid(validator, wrong_enum, "unknown transition enum")

    bad_oid = copy.deepcopy(claim)
    bad_oid["board_revision"] = "1111111"
    expect_invalid(validator, bad_oid, "abbreviated board revision")

    over_bound = copy.deepcopy(claim)
    over_bound["claims"] = [copy.deepcopy(claim["claims"][0]) for _ in range(257)]
    expect_invalid(validator, over_bound, "257 claims")

    # JSON Schema cannot express uniqueness/order over a member property; these are
    # normative semantic rules and remain independently executable here.
    duplicate = copy.deepcopy(claim)
    duplicate["claims"][1]["task_id"] = duplicate["claims"][0]["task_id"]
    expect_semantic_invalid(duplicate, "duplicate task ids")

    reversed_claim = copy.deepcopy(claim)
    reversed_claim["claims"] = list(reversed(reversed_claim["claims"]))
    expect_semantic_invalid(reversed_claim, "reversed claim ordering")

    # The vector and the prose must agree on the one version and the named flows.
    register = REGISTER_PATH.read_text(encoding="utf-8")
    m4 = M4_PATH.read_text(encoding="utf-8")
    model = MODEL_PATH.read_text(encoding="utf-8")
    for path, text in ((REGISTER_PATH, register), (M4_PATH, m4), (MODEL_PATH, model)):
        if "cf.board-group-claim.v1" not in text:
            fail(f"{path} omits cf.board-group-claim.v1")
        if re.search(r"schema_version.{0,40}cf\\.(?:group|board)-claim\\.v1", text):
            fail(f"{path} carries a retired claim version as a target schema")
    if "F16" not in register or "F5" not in m4:
        fail("claim contract does not name its F16/F5 flow ownership")
    if "P5G-15" not in register:
        fail("contract register does not identify P5G-15")
    if not re.search(
        r"additionalProperties.{0,80}false",
        SCHEMA_PATH.read_text(encoding="utf-8"),
        re.S,
    ):
        fail("claim schema is not closed")

    print("P5G-15 schema rules: PASS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, KeyError, json.JSONDecodeError, StopIteration) as error:
        print(f"P5G-15 schema rules: FAIL — {error}", file=sys.stderr)
        raise SystemExit(1)
