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
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
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

R1_PREFIX = "/runs/"
R2_PREFIX = "/factory/"


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
    if not str(record.get("namespace") or ""):
        raise MemoryRecordError("record namespace is required")
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


def _iso_now() -> str:
    return (
        datetime.now(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


def memory_records(
    record: Mapping[str, object], outcome: str, ended_at: str | None = None
) -> tuple[dict[str, object], dict[str, object]]:
    """Build R1 detail and the R2 pointer without copying sensitive run content."""
    values = validate_record(record, str(record.get("namespace") or ""))
    if outcome not in {"PASS", "FAIL", "UNVERIFIED"}:
        raise MemoryRecordError(f"invalid outcome: {outcome}")
    project = values["namespace"]
    week = values["tick"] if values["tick"].startswith("20") else "unknown-week"
    started_at = str(record.get("started_at") or _iso_now())
    ended = ended_at or str(record.get("ended_at") or _iso_now())
    r1 = {
        **values,
        "project": project,
        "week": week,
        "board_row": str(record.get("board_row") or "-"),
        "outcome": outcome,
        "artifact_digests": list(record.get("artifact_digests") or []),
        "started_at": started_at,
        "ended_at": ended,
        "node": str(record.get("node") or "-"),
    }
    r2 = {
        "run_id": values["run_id"],
        "project": project,
        "lane": values["lane"],
        "week": week,
        "harness": values["harness"],
        "harness_version": values["harness_version"],
        "model_requested": values["model_requested"],
        "model_served": values["model_served"],
        "provider_binding": values["provider_binding"],
        "commit": values["commit"],
        "tick": values["tick"],
        "board_row": r1["board_row"],
        "outcome": outcome,
        "artifact_digests": r1["artifact_digests"],
        "started_at": started_at,
        "ended_at": ended,
        "node": r1["node"],
    }
    return r1, r2


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


class DuckBrainClient:
    """Minimal x-api-key HTTP client; a transport error is never reported as a write."""

    def __init__(
        self, base_url: str, token_file: os.PathLike[str] | str, timeout: float = 8.0
    ):
        self.base_url = base_url.rstrip("/")
        self.token_file = Path(token_file)
        self.timeout = timeout
        if not self.base_url:
            raise MemoryRecordError("DuckBrain URL is required")
        if not self.token_file.is_file() or (self.token_file.stat().st_mode & 0o077):
            raise MemoryRecordError("DuckBrain token file must exist with mode 600")
        self.token = self.token_file.read_text(encoding="utf-8").strip()
        if not self.token:
            raise MemoryRecordError("DuckBrain token file is empty")

    def _request(
        self, method: str, path: str, payload: Mapping[str, object] | None = None
    ) -> object:
        data = (
            json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode()
            if payload is not None
            else None
        )
        headers = {"x-api-key": self.token, "content-type": "application/json"}
        request = urllib.request.Request(
            self.base_url + path, data=data, headers=headers, method=method
        )
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                raw = response.read()
            return json.loads(raw.decode("utf-8")) if raw else {}
        except (
            urllib.error.URLError,
            urllib.error.HTTPError,
            OSError,
            json.JSONDecodeError,
        ) as exc:
            raise MemoryRecordError(
                f"DuckBrain transport {method} {path}: {exc}"
            ) from exc

    def remember(
        self,
        namespace: str,
        key: str,
        content: Mapping[str, object],
        domain: str = "event",
    ) -> None:
        if not namespace or not key or not content:
            raise MemoryRecordError(
                "DuckBrain write requires namespace, key and content"
            )
        self._request(
            "POST",
            "/api/memories",
            {
                "key": key,
                "namespace": namespace,
                "domain": domain,
                "content": json.dumps(dict(content), sort_keys=True),
            },
        )

    def read_exact(self, namespace: str, key: str) -> object:
        if not namespace or not key:
            raise MemoryRecordError("DuckBrain read requires namespace and key")
        encoded = urllib.parse.quote(key, safe="")
        return self._request(
            "GET",
            f"/api/memories/key/{encoded}?namespace={urllib.parse.quote(namespace, safe='')}",
        )


def export_records(
    client: DuckBrainClient, record: Mapping[str, object], outcome: str
) -> tuple[str, str]:
    """Write/read R1 then R2; return exact keys. R2 never precedes R1."""
    r1, r2 = memory_records(record, outcome)
    namespace = str(r1["namespace"])
    r1_key = f"{R1_PREFIX}{r1['lane']}/{r1['week']}/{r1['run_id']}"
    r2_key = f"{R2_PREFIX}{r2['project']}/{r2['week']}/{r2['lane']}/{r2['run_id']}"
    client.remember(namespace, r1_key, r1)
    client.read_exact(namespace, r1_key)
    client.remember("factory", r2_key, r2)
    client.read_exact("factory", r2_key)
    return r1_key, r2_key


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="write/read the shared I3 harness memory record"
    )
    parser.add_argument("action", choices=("write", "read", "records"))
    parser.add_argument(
        "--backend", required=False, help="explicit hermetic backend file"
    )
    parser.add_argument("--r1-backend", required=False)
    parser.add_argument("--r2-backend", required=False)
    parser.add_argument("--namespace", required=True)
    parser.add_argument("--expected-namespace", required=True)
    parser.add_argument("--outcome", default="PASS")
    parser.add_argument("--board-row", default="-")
    parser.add_argument("--node", default="fixture-node")
    parser.add_argument("--started-at", default="2026-11-14T00:00:00Z")
    parser.add_argument("--ended-at", default="2026-11-14T00:01:00Z")
    for field in I3_FIELDS:
        if field != "namespace":
            parser.add_argument(f"--{field.replace('_', '-')}", required=False)
    return parser


def _record_from_args(args: argparse.Namespace) -> dict[str, object]:
    record = {field: getattr(args, field) for field in I3_FIELDS}
    record.update(
        board_row=args.board_row,
        node=args.node,
        started_at=args.started_at,
        ended_at=args.ended_at,
    )
    return record


def _write_json(path: str, record: Mapping[str, object]) -> bytes:
    payload = canonical_bytes(record)
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(payload)
    if target.read_bytes() != payload:
        raise MemoryRecordError(f"readback bytes differ for {target}")
    return payload


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        if args.action == "records":
            if not args.r1_backend or not args.r2_backend:
                raise MemoryRecordError(
                    "records requires --r1-backend and --r2-backend"
                )
            record = _record_from_args(args)
            r1, r2 = memory_records(record, args.outcome)
            _write_json(args.r1_backend, r1)
            _write_json(args.r2_backend, r2)
            if Path(args.r1_backend).read_bytes() != canonical_bytes(r1):
                raise MemoryRecordError("R1 readback bytes differ")
            if Path(args.r2_backend).read_bytes() != canonical_bytes(r2):
                raise MemoryRecordError("R2 readback bytes differ")
            print(
                f"PASS memory.records — R1 then R2 written/read back; outcome {args.outcome}"
            )
        else:
            if not args.backend:
                raise MemoryRecordError(f"{args.action} requires --backend")
            writer = MemoryWriter(args.backend)
            if args.action == "write":
                record = {field: getattr(args, field) for field in I3_FIELDS}
                payload = writer.write(record, args.expected_namespace)
                print(
                    f"PASS memory.write — {len(payload)} canonical bytes; namespace {args.namespace}"
                )
            else:
                if args.namespace != args.expected_namespace:
                    raise MemoryRecordError(
                        "namespace does not match expected namespace"
                    )
                payload = writer.read(args.expected_namespace)
                sys.stdout.buffer.write(payload)
    except (MemoryRecordError, OSError) as exc:
        print(f"FAIL memory.{args.action} — {exc}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
