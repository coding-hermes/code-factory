#!/usr/bin/env python3
"""Independent checks for the P5G-12 release-lock fixture."""

from __future__ import annotations

import hashlib
import json
import os


VECTOR_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    os.pardir,
    "docs",
    "handbook",
    "contract-vectors.json",
)


def check(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)
    print(f"  PASS  {message}")


def main() -> int:
    with open(VECTOR_PATH, encoding="utf-8") as handle:
        document = json.load(handle)
    vector = document["release_manifest_vector"]
    canonical = vector["canonical_jcs"].encode("utf-8")
    digest = hashlib.sha256(canonical).hexdigest()
    fixture = {
        key: vector[key]
        for key in ("schema_version", "release_id", "protocol_versions", "artifacts")
    }
    encoded = json.dumps(
        fixture, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")

    check(vector["release_id"], "fixture has release_id")
    check(canonical == encoded, "canonical bytes match the fixture")
    check(
        digest == vector["expected"]["manifest_digest"],
        "canonical JCS sha256 matches expected manifest_digest",
    )
    check(
        vector["protocol_versions"] == vector["expected"]["protocol_versions"],
        "protocol_versions match expected set",
    )
    artifacts = vector["artifacts"]
    order = [
        f"{item['kind']}|{item['name']}|{item['version']}|{item['architecture']}"
        for item in artifacts
    ]
    check(
        order == vector["expected"]["artifact_order"],
        "artifact entries are in the declared bytewise order",
    )
    check(order == sorted(set(order)), "artifact order is sorted and unique")
    for index, artifact in enumerate(artifacts, start=1):
        check(artifact["url"].startswith("https://"), f"artifact {index} has HTTPS url")
        check(len(artifact["digest"]) == 64, f"artifact {index} has SHA-256 digest")
        check(
            isinstance(artifact["size"], int) and artifact["size"] > 0,
            f"artifact {index} has positive size",
        )
        check(
            artifact["protocol_versions"] == vector["protocol_versions"],
            f"artifact {index} carries protocol_versions",
        )
    check(
        vector["verification_procedure"]
        == "python3 tests/test_release_manifest_vector.py",
        "vector names executable verification procedure",
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, KeyError, json.JSONDecodeError) as error:
        print(f"  FAIL  {error}")
        raise SystemExit(1)
