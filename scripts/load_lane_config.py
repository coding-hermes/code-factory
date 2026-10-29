#!/usr/bin/env python3
"""load_lane_config.py — one-time lane configuration for the code-factory family.

Sets, per lane: namespace, admission mode, and the prompt file that is its job.
Prompts live in prompts/ and are the source of truth; this script copies them in.
"""

import os
import pathlib
import sqlite3

HERE = pathlib.Path(__file__).resolve().parents[1]
DB = pathlib.Path(
    os.environ.get(
        "SCHEDULER_DB", pathlib.Path.home() / ".hermes/coding-hermes/scheduler.db"
    )
)
ROOT = pathlib.Path(os.environ.get("CODE_FACTORY_ROOT", HERE))

CFG = {
    "code-factory": ("coding-hermes", "tasks", "foreman"),
    "code-factory-qa": ("qa", "cooldown", "qa"),
    "code-factory-pm": ("coding-hermes", "cooldown", "pm"),
    "code-factory-dogfood": ("dogfood", "cooldown", "dogfood"),
    "code-factory-sync": ("coding-hermes", "cooldown", "sync"),
    "code-factory-duckbrain": ("duckbrain-sync", "cooldown", "duckbrain"),
}

con = sqlite3.connect(DB, timeout=60)
con.execute("PRAGMA busy_timeout=60000")
for name, (ns, mode, prompt_name) in CFG.items():
    text = (ROOT / "prompts" / f"{prompt_name}.md").read_text()
    con.execute(
        "UPDATE projects SET namespace_id=?, admission_mode=?, prompt=?, prompt_mode='append' WHERE name=?",
        (ns, mode, text, name),
    )
con.commit()

for row in con.execute(
    "SELECT name, namespace_id, admission_mode, length(prompt) FROM projects "
    "WHERE name LIKE 'code-factory%' ORDER BY name"
):
    print(
        f"{row[0]:24s} ns={row[1] or '-':14s} mode={row[2] or '-':9s} prompt={row[3]}"
    )
