#!/usr/bin/env python3
"""Shared I3 harness memory record writer and hermetic readback backend.

The conformance battery uses the same writer for every supported harness.  The backend
is deliberately a file so the battery proves the record contract without claiming live
DuckBrain/network evidence; a node adapter can replace the backend while retaining the
canonical bytes and validation.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
from pathlib import Path
from typing import Mapping


I3_FIELDS = (
    "namespace",
    "run_id",
    "lane",
    "harness",
    "harness_version",
    "model_requested",
    "model_served",
    "provider_binding",
    "commit",
    "tick",
)


class MemoryRecordError(ValueError):
    """A record cannot be written without violating the I3 contract."""


def canonical_bytes(record: Mapping[str, object]) -> bytes:
    """Return the one byte representation used for writes and readback comparison."""
    return json.dumps(
        dict(record),
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def validate_record(
    record: Mapping[str, object], expected_namespace: str
) -> dict[str, str]:
    """Validate and copy one I3 record; never substitute a default namespace."""
    if not expected_namespace or expected_namespace == "default":
        raise MemoryRecordError("expected namespace is required and may not be default")
    if not isinstance(record, Mapping):
        raise MemoryRecordError("record must be an object")
    missing = [field for field in I3_FIELDS if field not in record]
    if missing:
        raise MemoryRecordError(f"missing I3 field(s): {', '.join(missing)}")
    values: dict[str, str] = {}
    for field in I3_FIELDS:
        value = record[field]
        if not isinstance(value, str) or not value:
            raise MemoryRecordError(f"{field} must be a non-empty string")
        values[field] = value
    if values["namespace"] != expected_namespace:
        raise MemoryRecordError(
            f"namespace mismatch: record={values['namespace']!r}, expected={expected_namespace!r}"
        )
    if values["namespace"] == "default":
        raise MemoryRecordError("default namespace is refused")
    return values


class MemoryWriter:
    """Write one canonical record to an explicit backend and verify exact bytes."""

    def __init__(self, backend: os.PathLike[str] | str):
        self.backend = Path(backend)

    def write(self, record: Mapping[str, object], expected_namespace: str) -> bytes:
        values = validate_record(record, expected_namespace)
        payload = canonical_bytes(values)
        self.backend.parent.mkdir(parents=True, exist_ok=True)
        fd, name = tempfile.mkstemp(
            prefix=f".{self.backend.name}.", dir=self.backend.parent
        )
        temporary = Path(name)
        try:
            with os.fdopen(fd, "wb") as stream:
                stream.write(payload)
            os.replace(temporary, self.backend)
        finally:
            if temporary.exists():
                temporary.unlink()
        readback = self.backend.read_bytes()
        if readback != payload:
            raise MemoryRecordError("readback bytes differ from written bytes")
        return readback

    def read(self, expected_namespace: str) -> bytes:
        if not expected_namespace or expected_namespace == "default":
            raise MemoryRecordError(
                "expected namespace is required and may not be default"
            )
        payload = self.backend.read_bytes()
        try:
            record = json.loads(payload.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise MemoryRecordError(
                f"backend does not contain canonical JSON: {exc}"
            ) from exc
        validate_record(record, expected_namespace)
        if canonical_bytes(record) != payload:
            raise MemoryRecordError("backend bytes are not canonical I3 bytes")
        return payload


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="write/read the shared I3 harness memory record"
    )
    parser.add_argument("action", choices=("write", "read"))
    parser.add_argument(
        "--backend", required=True, help="explicit hermetic backend file"
    )
    parser.add_argument("--namespace", required=True)
    parser.add_argument("--expected-namespace", required=True)
    for field in I3_FIELDS:
        if field != "namespace":
            parser.add_argument(f"--{field.replace('_', '-')}", required=False)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    writer = MemoryWriter(args.backend)
    try:
        if args.action == "write":
            record = {field: getattr(args, field) for field in I3_FIELDS}
            payload = writer.write(record, args.expected_namespace)
            print(
                f"PASS memory.write — {len(payload)} canonical bytes; namespace {args.namespace}"
            )
        else:
            if args.namespace != args.expected_namespace:
                raise MemoryRecordError("namespace does not match expected namespace")
            payload = writer.read(args.expected_namespace)
            sys.stdout.buffer.write(payload)
    except (MemoryRecordError, OSError) as exc:
        print(f"FAIL memory.{args.action} — {exc}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
