#!/usr/bin/env python3
"""Read-only CF-022 census. See docs/SCHEDULER-LANE-VERIFICATION.md."""

import argparse
import ast
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import sys
import tomllib

FIELDS = (
    "name",
    "namespace_id",
    "parent",
    "workdir",
    "enabled",
    "cooldown_s",
    "cooldown_floor_s",
    "cooldown_ceiling_s",
    "cooldown_pin_s",
    "adaptive_cooldown",
    "admission_mode",
    "board_ownership",
    "prompt_mode",
)
PACING = ("cooldown_s", "cooldown_floor_s", "cooldown_ceiling_s", "cooldown_pin_s")
ENUMS = {
    "admission_mode": {"", "tasks", "cooldown"},
    "board_ownership": {"", "owner", "shared"},
    "prompt_mode": {"append", "replace"},
}


def policy_constants(path):
    """Read literals, not imports: no duplicate canonical family matrix."""
    wanted = {"SATELLITE_FAMILY_PINS", "SATELLITE_FAMILY_NAMESPACES"}
    found = {}
    for node in ast.parse(path.read_text()).body:
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name) and target.id in wanted:
                    found[target.id] = ast.literal_eval(node.value)
    pins = found["SATELLITE_FAMILY_PINS"]
    namespaces = found["SATELLITE_FAMILY_NAMESPACES"]
    if not isinstance(pins, dict) or not isinstance(namespaces, dict):
        raise ValueError("invalid policy maps")
    if not pins or pins.keys() != namespaces.keys():
        raise ValueError("unsupported policy")
    if any(
        not re.fullmatch(r"[a-z]+", key) or type(val) is not int or val <= 0
        for key, val in pins.items()
    ):
        raise ValueError("invalid pins")
    if any(not re.fullmatch(r"[a-z][a-z-]*", val) for val in namespaces.values()):
        raise ValueError("invalid namespaces")
    return pins, namespaces


def normalized(path, hh, root):
    """Allow only known roots; never serialize an arbitrary absolute path."""
    p = Path(path).absolute()
    for base, label in ((root, "$PROJECT_ROOT"), (hh, "$HERMES_HOME")):
        try:
            rel = p.relative_to(base)
        except ValueError:
            continue
        # Do not publish arbitrary outside traversal or unusual filename text.
        if all(
            re.fullmatch(r"[a-zA-Z0-9_.-]+", part) and part != ".."
            for part in rel.parts
        ):
            return label + ("/" + rel.as_posix() if rel.parts else "")
    return "<outside-known-roots>"


def board_valid(path):
    try:
        rows = [
            json.loads(line) for line in path.read_text().splitlines() if line.strip()
        ]
        return bool(rows) and all(
            isinstance(row, dict)
            and isinstance(row.get("id"), str)
            and bool(row["id"])
            and isinstance(row.get("status"), str)
            for row in rows
        )
    except (OSError, ValueError):
        return False


def census(args):
    for path in (args.db, args.toml, args.checker):
        if not path.is_file():
            raise ValueError("required file absent")
    root, hh = (
        args.project_root.resolve(strict=True),
        args.hermes_home.resolve(strict=True),
    )
    if not root.is_dir() or not hh.is_dir():
        raise ValueError("invalid roots")
    pins, family_namespaces = policy_constants(args.checker)
    with args.toml.open("rb") as handle:
        config = tomllib.load(handle)
    blocks = config["projects"]
    if not isinstance(blocks, list) or not blocks:
        raise ValueError("empty TOML project census")
    toml_rows = {p["name"]: p for p in blocks}
    if len(toml_rows) != len(blocks):
        raise ValueError("duplicate TOML project")
    with sqlite3.connect(args.db.resolve().as_uri() + "?mode=ro", uri=True) as con:
        con.execute("PRAGMA query_only=ON")
        con.row_factory = sqlite3.Row
        query = "SELECT " + ",".join("p." + key for key in FIELDS)
        query += ", length(trim(p.prompt)) AS prompt_chars, "
        query += "length(trim(n.default_prompt)) AS namespace_prompt_chars, "
        query += "n.admission_mode AS namespace_admission FROM projects p "
        query += "LEFT JOIN namespaces n ON n.id=p.namespace_id "
        query += "WHERE p.name LIKE 'code-factory%' ORDER BY p.name"
        rows = [dict(row) for row in con.execute(query)]
    names = {row["name"] for row in rows}
    if "code-factory" not in names or len(names) < 2:
        raise ValueError("empty or incomplete census")
    if any(not re.fullmatch(r"code-factory(?:-[a-z0-9]+)*", name) for name in names):
        raise ValueError("unsafe lane identifier")
    primary = next(row for row in rows if row["name"] == "code-factory")
    if Path(primary["workdir"]).resolve() != root:
        raise ValueError("project root differs from registered primary")
    primary_board = root / ".coding-hermes/board/tasks.jsonl"
    if not board_valid(primary_board):
        raise ValueError("invalid primary board")
    proc = subprocess.run(
        [
            sys.executable,
            "-B",
            str(args.checker.resolve()),
            "--db",
            str(args.db.resolve()),
            "--toml",
            str(args.toml.resolve()),
            "--board",
            str(primary_board),
            "--skills-root",
            str(hh / "skills"),
            "--json",
        ],
        capture_output=True,
        text=True,
        timeout=180,
        env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
    )
    result = json.loads(proc.stdout)
    if not isinstance(result, dict):
        raise ValueError("invalid checker result")
    if proc.returncode not in (0, 1) or not isinstance(result.get("violations"), list):
        raise ValueError("checker failed")
    if type(result.get("ok")) is not bool or result["ok"] != (not result["violations"]):
        raise ValueError("inconsistent checker result")
    if proc.returncode != (0 if result["ok"] else 1):
        raise ValueError("inconsistent checker exit")
    scoped = []
    unrelated = 0
    for finding in result["violations"]:
        if not isinstance(finding, dict):
            raise ValueError("invalid finding")
        subject, cls = finding["subject"], finding["class"]
        if not isinstance(subject, str) or not isinstance(cls, str):
            raise ValueError("invalid finding")
        board_finding = cls.startswith("board-") or cls == "event-id-ascending"
        if subject in names or board_finding:
            scoped.append(
                {
                    "class": cls if re.fullmatch(r"[a-z-]+", cls) else "<redacted>",
                    "subject": subject if subject in names else "<primary-board>",
                }
            )
        else:
            unrelated += 1
    output = []
    for row in rows:
        name = row["name"]
        family = next((key for key in pins if name.endswith("-" + key)), None)
        target = name[: -(len(family) + 1)] if family else row["parent"]
        wd = Path(row["workdir"])
        board = wd / ".coding-hermes/board/tasks.jsonl"
        same_board = board.is_file() and board.resolve() == primary_board.resolve()
        issues = []
        if row["enabled"]:
            if not wd.is_dir():
                issues.append("workdir-missing")
            if not board_valid(board):
                issues.append("board-invalid-or-missing")
            if not same_board:
                issues.append("board-not-primary")
            if name != "code-factory" and row["board_ownership"] == "owner":
                issues.append("satellite-board-owner-override")
            if name != "code-factory" and not family:
                issues.append("family-policy-unmapped")
            if name != "code-factory" and target not in names:
                issues.append("target-missing")
            if name != "code-factory" and not row["parent"]:
                issues.append("parent-missing")
            if name != "code-factory" and row["parent"] and row["parent"] not in names:
                issues.append("parent-unresolved")
            if name != "code-factory" and row["adaptive_cooldown"]:
                issues.append("satellite-adaptive-armed")
            mode = row["admission_mode"] or row["namespace_admission"]
            if name != "code-factory" and mode != "cooldown":
                issues.append("satellite-admission")
            if name not in toml_rows:
                issues.append("toml-project-absent")
        block = toml_rows.get(name, {})
        mismatches = [key for key in FIELDS if key in block and block[key] != row[key]]
        if row["enabled"] and mismatches:
            issues.append("toml-field-drift")
        item = {key: row[key] for key in PACING}
        if any(value is not None and type(value) is not int for value in item.values()):
            raise ValueError("invalid pacing field")
        item.update(
            {
                "name": name,
                "enabled": bool(row["enabled"]),
                "namespace_id": row["namespace_id"]
                if row["namespace_id"]
                in set(family_namespaces.values()) | {"coding-hermes"}
                else "<unrecognized>",
                "parent": row["parent"]
                if row["parent"] in names | {""}
                else "<external>",
                "family": family,
                "family_reason": "checker-matrix" if family else "no-role-suffix",
                "expected_namespace": family_namespaces.get(family, "unmapped"),
                "canonical_cooldown_s": pins.get(family),
                "pin_reason": "unset" if row["cooldown_pin_s"] is None else "stored",
                "target": target if target in names else "<unresolved>",
                "workdir": normalized(wd, hh, root),
                "workdir_exists": wd.is_dir(),
                "board": normalized(board.resolve(), hh, root),
                "board_valid": board_valid(board),
                "board_is_primary": same_board,
                "adaptive_cooldown": bool(row["adaptive_cooldown"]),
                "prompt_chars": row["prompt_chars"] or 0,
                "namespace_prompt_chars": row["namespace_prompt_chars"] or 0,
                "toml_present": name in toml_rows,
                "toml_mismatched_fields": mismatches,
                "issues": issues,
            }
        )
        for key, allowed in ENUMS.items():
            item[key] = row[key] if row[key] in allowed else "<unrecognized>"
        output.append(item)
    drift = bool(scoped) or any(lane["issues"] for lane in output)
    return {
        "schema_version": 1,
        "observed_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "checker_sha256": hashlib.sha256(args.checker.read_bytes()).hexdigest(),
        "result": "DRIFT" if drift else "PASS",
        "lane_count": len(output),
        "enabled_count": sum(lane["enabled"] for lane in output),
        "lanes": output,
        "checker_exit": proc.returncode,
        "scoped_findings": scoped,
        "unrelated_finding_count": unrelated,
        "dispatch_readiness": "not-verified",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for flag in ("db", "toml", "checker", "hermes-home", "project-root"):
        parser.add_argument("--" + flag, type=Path, required=True)
    args = parser.parse_args()
    try:
        result = census(args)
    except (
        OSError,
        ValueError,
        KeyError,
        TypeError,
        RuntimeError,
        SyntaxError,
        sqlite3.Error,
        subprocess.SubprocessError,
    ):
        # Exceptions may contain paths, raw checker output or private DB data.
        print(
            json.dumps(
                {"result": "ERROR", "reason": "missing-bad-or-unsupported-input"}
            )
        )
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 1 if result["result"] == "DRIFT" else 0


if __name__ == "__main__":
    sys.exit(main())
