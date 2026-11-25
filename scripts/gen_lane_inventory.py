#!/usr/bin/env python3
"""gen_lane_inventory.py — generate the canonical code-factory lane inventory.

CF-335: the handbook modules that used to type their own lane counts cite
``docs/handbook/appendices/lane-inventory.md`` instead; this script is the
only writer of that page. It reads the scheduler sqlite database
(``projects`` table), selects the code-factory family — every row whose
``name`` or ``parent`` starts with ``code-factory`` — and renders a
deterministic page: the only line that changes between runs is the
``| Generated |`` stamp in the banner.

Failure contract (exit 2, message on stderr, nothing written):

* the database file is missing, unreadable, or has no ``projects`` table;
* the family query selects zero rows (a broken filter must not silently
  publish an empty inventory);
* a ``code-factory-duckbrain%`` row exists — the resolution section would
  be false, so the run refuses rather than writing a lying page.

Paths are rendered with the ``~`` spelling of the invoking user's home: the
handbook's template boundary forbids absolute ``/home/<user>/`` spellings in
tracked docs.
"""

from __future__ import annotations

import argparse
import datetime
import os
import sqlite3
import sys
from pathlib import Path

FAMILY_PREFIX = "code-factory"
STALE_PREFIX = "code-factory-duckbrain"
# The registry snapshot that handbook modules 07 and 35 measured on this date
# still carried the duckbrain spellings; they are retired (one project, two
# names) and survive only as stale typed references in older docs.
STALE_RECORDED_ON = "2026-11-05"
STALE_HISTORICAL_NAMES = (
    "code-factory-duckbrain",
    "code-factory-duckbrain-dogfood",
    "code-factory-duckbrain-pm",
    "code-factory-duckbrain-qa",
    "code-factory-duckbrain-releng",
    "code-factory-duckbrain-sync",
)

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DB = Path.home() / ".hermes" / "coding-hermes" / "scheduler.db"
DEFAULT_OUTPUT = ROOT / "docs" / "handbook" / "appendices" / "lane-inventory.md"

FAMILY_SQL = (
    "SELECT name, parent, enabled, workdir FROM projects "
    "WHERE name LIKE 'code-factory%' OR parent LIKE 'code-factory%' "
    "ORDER BY name"
)


class InventoryError(Exception):
    """A precondition failed: nothing is written, the process exits 2."""


def tildefy(path: str) -> str:
    """Render ``path`` with the ``~`` spelling of the invoking user's home."""
    home = os.path.expanduser("~")
    if path == home:
        return "~"
    if path.startswith(home + os.sep):
        return "~" + path[len(home) :]
    return path


def load_family(db_path: Path) -> list[tuple[str, str, int, str]]:
    """Select the family rows; every failure raises InventoryError."""
    if not db_path.is_file():
        raise InventoryError(f"scheduler database not found: {db_path}")
    uri = f"file:{db_path}?mode=ro"
    try:
        con = sqlite3.connect(uri, uri=True)
    except sqlite3.Error as exc:
        raise InventoryError(
            f"scheduler database unreadable: {db_path}: {exc}"
        ) from exc
    try:
        rows = con.execute(FAMILY_SQL).fetchall()
    except sqlite3.Error as exc:
        raise InventoryError(
            f"scheduler database query failed on {db_path}: {exc}"
        ) from exc
    finally:
        con.close()
    if not rows:
        raise InventoryError(
            f"no code-factory family rows matched in {db_path} — refusing to "
            "publish an empty inventory"
        )
    return [
        (name, parent, int(enabled), workdir) for name, parent, enabled, workdir in rows
    ]


def check_stale_absent(rows: list[tuple[str, str, int, str]]) -> None:
    """Refuse when a retired duckbrain spelling is live in the DB."""
    live = [
        name
        for name, _parent, _enabled, _workdir in rows
        if name.startswith(STALE_PREFIX)
    ]
    if live:
        raise InventoryError(
            f"{STALE_PREFIX}% rows are live in the database ({', '.join(live)}) — "
            "the resolution section would be false; reconcile the registry first"
        )


def render(
    rows: list[tuple[str, str, int, str]], db_path: Path, generated_at: str
) -> str:
    """Render the deterministic page; only the Generated stamp varies."""
    enabled = sum(1 for _n, _p, e, _w in rows if e == 1)
    disabled = len(rows) - enabled
    lines = [
        "# Appendix: code-factory lane inventory",
        "",
        "<!-- GENERATED FILE — do not edit by hand. Regenerate with:",
        "     python3 scripts/gen_lane_inventory.py",
        "     The only line that changes between runs is the Generated stamp. -->",
        "",
        "| Field | Value |",
        "|---|---|",
        f"| Source | `{tildefy(str(db_path))}`, table `projects` |",
        f"| Generated | {generated_at} (UTC) |",
        "| Generator | `scripts/gen_lane_inventory.py` |",
        "",
        "This page is the canonical lane set of the code-factory family, derived",
        "from the scheduler database at generation time. Handbook modules must",
        "cite this page instead of typing their own lane counts (CF-335); the",
        "counts below are re-derived from the database on every run, never",
        "hard-coded.",
        "",
        "## Canonical lane table",
        "",
        "| Lane | Parent | Enabled | Workdir |",
        "|---|---|---|---|",
    ]
    for name, parent, enabled_flag, workdir in rows:
        lines.append(
            f"| `{name}` | `{parent}` | {enabled_flag} | `{tildefy(workdir)}` |"
        )
    lines += [
        "",
        "## Counts",
        "",
        "| Metric | Value |",
        "|---|---|",
        f"| Family rows | {len(rows)} |",
        f"| Enabled lanes | {enabled} |",
        f"| Disabled lanes | {disabled} |",
        "",
        "## Resolution: `code-factory` vs `code-factory-duckbrain`",
        "",
        "`code-factory` and `code-factory-duckbrain` are one project: the",
        "duckbrain spelling was an earlier name of the same lane, not a sibling.",
        "The registry snapshot that handbook modules 07 and 35 measured on",
        f"{STALE_RECORDED_ON} still listed `{STALE_HISTORICAL_NAMES[0]}` and five",
        "sibling spellings (`"
        + "`, `".join(STALE_HISTORICAL_NAMES[1:])
        + "`) among its rows.",
        "",
        f"Measured against the live database on {generated_at[:10]}: zero rows",
        f"match `{STALE_PREFIX}%`. The residual names in older docs are stale",
        "typed references, not live lanes; the table above is the only",
        "authoritative lane set.",
        "",
    ]
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Generate docs/handbook/appendices/lane-inventory.md "
        "from the scheduler DB (CF-335)."
    )
    parser.add_argument(
        "--db", type=Path, default=DEFAULT_DB, help="scheduler sqlite path"
    )
    parser.add_argument(
        "--output", type=Path, default=DEFAULT_OUTPUT, help="page to write"
    )
    args = parser.parse_args(argv)
    generated_at = datetime.datetime.now(datetime.timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )
    try:
        rows = load_family(args.db)
        check_stale_absent(rows)
    except InventoryError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(render(rows, args.db, generated_at), encoding="utf-8")
    print(f"lane-inventory: wrote {args.output} ({len(rows)} family rows)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
