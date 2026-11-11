#!/usr/bin/env python3
"""Report or apply the code-factory scheduler lane configuration.

The default and all diagnostic modes are read-only.  ``--apply`` is required to
write the six configured project rows, and ``--dry-run`` always takes precedence.
"""

import argparse
import os
import pathlib
import sqlite3
from urllib.parse import quote

HERE = pathlib.Path(__file__).resolve().parents[1]
ROOT = pathlib.Path(os.environ.get("CODE_FACTORY_ROOT", HERE))

CFG = {
    "code-factory": ("coding-hermes", "tasks", "foreman"),
    "code-factory-qa": ("qa", "cooldown", "qa"),
    "code-factory-pm": ("coding-hermes", "cooldown", "pm"),
    "code-factory-dogfood": ("dogfood", "cooldown", "dogfood"),
    "code-factory-sync": ("coding-hermes", "cooldown", "sync"),
    "code-factory-duckbrain": ("duckbrain-sync", "cooldown", "duckbrain"),
}


class LaneConfigError(Exception):
    """A named operator-facing configuration error."""


def apply_updates(con, prompt_texts):
    for name, (ns, mode, prompt_name) in CFG.items():
        text = prompt_texts[name]
        con.execute(
            "UPDATE projects SET namespace_id=?, admission_mode=?, prompt=?, prompt_mode='append' WHERE name=?",
            (ns, mode, text, name),
        )
    con.commit()


def parser():
    p = argparse.ArgumentParser(
        description="Report the six code-factory lane updates; --apply writes them."
    )
    p.add_argument(
        "--apply",
        action="store_true",
        help="write the six UPDATE statements and print the readback",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="print the UPDATE set without writing (overrides --apply)",
    )
    p.add_argument(
        "--check",
        action="store_true",
        help="read-only alias for the default report mode",
    )
    p.add_argument(
        "--db",
        type=pathlib.Path,
        default=None,
        help="scheduler SQLite database (default: $SCHEDULER_DB or ~/.hermes/coding-hermes/scheduler.db)",
    )
    p.epilog = "Exit codes: 0 success/help; 1 named database, schema, or prompt refusal; 2 invalid arguments."
    return p


def database_path(value):
    if value is not None:
        return value.expanduser()
    return pathlib.Path(
        os.environ.get(
            "SCHEDULER_DB", pathlib.Path.home() / ".hermes/coding-hermes/scheduler.db"
        )
    ).expanduser()


def open_database(path, read_only):
    if not path.is_file():
        raise LaneConfigError(f"database missing: {path}")
    if read_only:
        uri = f"file:{quote(str(path.resolve()), safe='/')}?mode=ro"
        con = sqlite3.connect(uri, uri=True, timeout=60)
    else:
        con = sqlite3.connect(path, timeout=60)
    con.execute("PRAGMA busy_timeout=60000")
    return con


def load_prompts(root):
    texts = {}
    for name, (_, _, prompt_name) in CFG.items():
        path = root / "prompts" / f"{prompt_name}.md"
        try:
            texts[name] = path.read_text(encoding="utf-8")
        except FileNotFoundError as exc:
            raise LaneConfigError(f"prompt file missing: {path}") from exc
        except OSError as exc:
            raise LaneConfigError(f"prompt file unreadable: {path}: {exc}") from exc
    return texts


def read_rows(con):
    try:
        rows = con.execute(
            "SELECT name, namespace_id, admission_mode, prompt, prompt_mode "
            "FROM projects WHERE name LIKE 'code-factory%' ORDER BY name"
        ).fetchall()
    except sqlite3.OperationalError as exc:
        if "no such table" in str(exc):
            raise LaneConfigError("projects table missing") from exc
        raise LaneConfigError(f"cannot read projects table: {exc}") from exc
    by_name = {row[0]: row for row in rows}
    missing = [name for name in CFG if name not in by_name]
    if missing:
        raise LaneConfigError("project rows missing: " + ", ".join(missing))
    return by_name


def display(value):
    return "<NULL>" if value is None else repr(value)


def report(rows, prompt_texts):
    print("UPDATE set (current -> target; source is the prompt text copied):")
    for name, (namespace, mode, prompt_name) in CFG.items():
        row = rows[name]
        current_prompt = row[3]
        print(
            f"{name}: namespace_id {display(row[1])} -> {namespace}; "
            f"admission_mode {display(row[2])} -> {mode}; "
            f"prompt length {len(current_prompt) if current_prompt is not None else '<NULL>'} -> "
            f"{len(prompt_texts[name])} (prompts/{prompt_name}.md); "
            f"prompt_mode {display(row[4])} -> 'append'"
        )


def readback(con):
    for row in con.execute(
        "SELECT name, namespace_id, admission_mode, length(prompt) FROM projects "
        "WHERE name LIKE 'code-factory%' ORDER BY name"
    ):
        print(
            f"{row[0]:24s} ns={row[1] or '-':14s} mode={row[2] or '-':9s} prompt={row[3]}"
        )


def main(argv=None):
    args = parser().parse_args(argv)
    path = database_path(args.db)
    read_only = not args.apply or args.dry_run or args.check
    try:
        prompt_texts = load_prompts(ROOT)
        con = open_database(path, read_only)
        try:
            rows = read_rows(con)
            report(rows, prompt_texts)
            if not read_only:
                apply_updates(con, prompt_texts)
            readback(con)
        finally:
            con.close()
    except LaneConfigError as exc:
        print(f"ERROR: {exc}", file=os.sys.stderr)
        return 1
    except sqlite3.Error as exc:
        print(f"ERROR: database operation failed: {exc}", file=os.sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
