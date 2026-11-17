#!/usr/bin/env python3
"""Recompute the F15 backup/restore vector (CV-06-B) instead of trusting its digests.

The default input is this checkout's docs/handbook/contract-vectors.json. Pass a
path as argv[1] to point the checker at a different copy: tests/selftest.sh uses
that override to prove this checker fails when a vector's digest claim stops
matching the bytes the claim covers, so a future edit to contract-vectors.json
cannot silently break the published F15 vector while handbook_lint stays green.
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VECTORS = ROOT / "docs" / "handbook" / "contract-vectors.json"
FLOWS = ROOT / "docs" / "handbook" / "parts" / "II-flows.md"

VECTOR_ID = "CV-06-B"
F15_HEADING = "## 2.15 F15 — Backup and restore"
F15_NEXT_HEADING = "## 2.16"

REQUIRED_F15_CASES = (
    "Pending Crier message",
    "Acknowledged Crier message",
    "Pending memory entry",
    "Stale owner/credential",
    "Known-row readback",
)

REQUIRED_F15_LITERALS = (
    "cf.backup.v1",
    "consistency_marker",
    "STALE_OWNER",
    "AUTHORITY_UNAVAILABLE",
    "CAPTURE_FAILED",
    "ABORTED",
    "INCOMPLETE",
)


def check(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)
    print(f"PASS {message}")


def section(text: str, heading: str, next_heading: str) -> str:
    start = text.index(heading)
    end = text.index(next_heading, start)
    return text[start:end]


def jcs(value: object) -> str:
    """RFC 8785 shape: sorted keys, compact separators, raw UTF-8."""
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def digest(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def excluded_fields(digest_rule: str) -> set[str]:
    """Read which fields the digest rule removes, so the allowance is derived, not asserted."""
    match = re.search(r"with (.+?) absent", digest_rule)
    if match is None:
        raise ValueError(
            f"{VECTOR_ID} digest_rule does not name its excluded fields: {digest_rule!r}"
        )
    return {
        name.strip() for name in re.split(r",| and ", match.group(1)) if name.strip()
    }


def main() -> int:
    vectors_path = Path(sys.argv[1]) if len(sys.argv) > 1 else VECTORS
    check(vectors_path.is_file(), f"contract vectors readable at {vectors_path}")
    document = json.loads(vectors_path.read_text(encoding="utf-8"))
    vector = next(
        (item for item in document["vectors"] if item.get("id") == VECTOR_ID), None
    )
    check(
        vector is not None,
        f"contract vectors carry {VECTOR_ID} (backup manifest digest and raw store bytes)",
    )
    if vector is None:
        raise ValueError(f"{VECTOR_ID} is absent from {vectors_path}")

    # The raw store bytes and their digest, recomputed from the literal the vector ships.
    store_text = vector["store_bytes_utf8"]
    store_bytes = store_text.encode("utf-8")
    check(
        vector["store_bytes_length"] == len(store_bytes),
        f"{VECTOR_ID} store_bytes_length is {len(store_bytes)}",
    )
    check(
        len(store_bytes) == 20,
        f"{VECTOR_ID} store bytes are 20 UTF-8 bytes, measured {len(store_bytes)}",
    )
    store_digest = digest(store_text)
    check(
        vector["store_sha256"] == store_digest,
        f"{VECTOR_ID} store_sha256 recomputes to {store_digest} (vector claims {vector['store_sha256']})",
    )

    # The manifest digest covers the canonical form with the excluded fields absent,
    # and both shipped strings must really be in that canonical shape.
    manifest_base_text = vector["manifest_without_digest_canonical_json"]
    manifest_base = json.loads(manifest_base_text)
    check(
        jcs(manifest_base) == manifest_base_text,
        f"{VECTOR_ID} manifest_without_digest_canonical_json is canonical JCS ({len(manifest_base_text)} bytes)",
    )
    manifest = json.loads(vector["manifest_canonical_json"])
    check(
        jcs(manifest) == vector["manifest_canonical_json"],
        f"{VECTOR_ID} manifest_canonical_json is canonical JCS ({len(vector['manifest_canonical_json'])} bytes)",
    )
    manifest_digest = digest(manifest_base_text)
    check(
        vector["manifest_sha256"] == manifest_digest,
        f"{VECTOR_ID} manifest_sha256 recomputes to {manifest_digest} (vector claims {vector['manifest_sha256']})",
    )
    check(
        manifest.get("manifest_digest") == manifest_digest,
        f"{VECTOR_ID} embedded manifest_digest is {manifest_digest} (canonical manifest carries {manifest.get('manifest_digest')!r})",
    )

    # The digest must not smuggle other changed fields: the two forms differ by exactly
    # the fields its own digest_rule removes, and by nothing else.
    rule_excluded = excluded_fields(vector["digest_rule"])
    added = set(manifest) - set(manifest_base)
    check(
        added == rule_excluded,
        f"{VECTOR_ID} canonical manifest adds exactly {sorted(rule_excluded)}, measured {sorted(added)}",
    )
    check(
        set(manifest_base) <= set(manifest),
        f"{VECTOR_ID} canonical manifest drops no base field, measured missing {sorted(set(manifest_base) - set(manifest))}",
    )
    stripped = {
        key: value for key, value in manifest.items() if key not in rule_excluded
    }
    check(
        stripped == manifest_base,
        f"{VECTOR_ID} canonical manifest equals the digest input once {sorted(rule_excluded)} are removed",
    )

    # The published-backup shape the F15 vector pins.
    check(
        manifest.get("schema_version") == "cf.backup.v1",
        f"{VECTOR_ID} schema_version is 'cf.backup.v1' (manifest carries {manifest.get('schema_version')!r})",
    )
    check(
        manifest.get("backup_id") == "backup-1",
        f"{VECTOR_ID} backup_id is 'backup-1' (manifest carries {manifest.get('backup_id')!r})",
    )
    check(
        manifest.get("barrier_seq") == 9,
        f"{VECTOR_ID} barrier_seq is 9 (manifest carries {manifest.get('barrier_seq')!r})",
    )
    marker_seq = manifest.get("consistency_marker", {}).get("authority_seq")
    check(
        marker_seq == 9,
        f"{VECTOR_ID} consistency_marker.authority_seq is 9 (manifest carries {marker_seq!r})",
    )
    check(
        manifest.get("state") == "PUBLISHED",
        f"{VECTOR_ID} state is 'PUBLISHED' (manifest carries {manifest.get('state')!r})",
    )
    check(
        manifest.get("published_at") is not None,
        f"{VECTOR_ID} published_at is set (manifest carries {manifest.get('published_at')!r})",
    )
    check(
        manifest.get("release_receipts") == [],
        f"{VECTOR_ID} release_receipts is [] because PUBLISHED is not RELEASED (manifest carries {manifest.get('release_receipts')!r})",
    )
    revocation_ref = manifest.get("revocation_snapshot_ref")
    check(
        isinstance(revocation_ref, str) and bool(revocation_ref),
        f"{VECTOR_ID} revocation_snapshot_ref is non-empty (manifest carries {revocation_ref!r})",
    )
    inventory_digests = [
        entry.get("sha256")
        for entry in manifest.get("inventory", [])
        if isinstance(entry, dict)
    ]
    check(
        store_digest in inventory_digests,
        f"{VECTOR_ID} inventory carries the store digest {store_digest} (inventory entries {inventory_digests})",
    )

    # The handbook prose is the vector's other half: name the five cases inside F15 only.
    flows = FLOWS.read_text(encoding="utf-8")
    f15 = section(flows, F15_HEADING, F15_NEXT_HEADING)
    for case in REQUIRED_F15_CASES:
        check(
            case in f15,
            f"F15 section names vector case {case!r} ({len(f15)} chars in section)",
        )
    for literal in REQUIRED_F15_LITERALS:
        check(literal in f15, f"F15 section contains required literal {literal!r}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, ValueError) as error:
        print(f"FAIL {error}")
        raise SystemExit(1)
