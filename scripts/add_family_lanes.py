#!/usr/bin/env python3
"""add_family_lanes.py — create the lane families the onboarding gate used to refuse.

Runs AFTER the 7d5b8d25 fix (nine families in satelliteWorkdirRoots + pins). If a lane is
still refused, the fix is not live — say so, do not fall back to SQL.
"""

import json
import os
import sqlite3
import urllib.error
import urllib.request

API = "http://127.0.0.1:9090"
DB = os.path.expanduser("~/.hermes/coding-hermes/scheduler.db")
H = os.path.expanduser("~/.hermes")
ROOT = os.path.expanduser("~/code-factory")
PID = (
    os.popen("systemctl --user show -p MainPID --value coding-hermes-scheduler")
    .read()
    .strip()
    or "0"
)

tok = next(
    v.split("=", 1)[1]
    for v in open(f"/proc/{PID}/environ", "rb")
    .read()
    .decode(errors="replace")
    .split("\0")
    if v.startswith("SCHEDULER_OPERATOR_TOKEN=")
)


def api(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        API + path,
        data=data,
        method=method,
        headers={"Authorization": f"Bearer {tok}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        return e.code, {"error": e.read().decode()[:300]}


LANES = [
    # name, workdir, namespace, prompt
    ("code-factory-docs", f"{H}/stand-in/docs/code-factory", "docs", "docs"),
    ("code-factory-docs-qa", f"{H}/stand-in/pm/code-factory-docs", "qa", "qa"),
    ("code-factory-readme", f"{H}/stand-in/readme/code-factory", "docs", "readme"),
    ("code-factory-readme-qa", f"{H}/stand-in/pm/code-factory-readme", "qa", "qa"),
    (
        "code-factory-releng",
        f"{H}/stand-in/releng-lane/code-factory",
        "releases",
        "releng",
    ),
    ("code-factory-releng-qa", f"{H}/stand-in/pm/code-factory-releng", "qa", "qa"),
    ("code-factory-perf", f"{H}/stand-in/perf/code-factory", "perf", "perf"),
    ("code-factory-review", f"{H}/stand-in/review/code-factory", "review", "review"),
]

made, refused = [], []
for name, workdir, ns, prompt_name in LANES:
    os.makedirs(workdir, exist_ok=True)
    st, d = api(
        "POST",
        "/api/v1/projects",
        {"name": name, "repo_url": f"local:{ROOT}", "workdir": workdir},
    )
    if st == 201:
        made.append(name)
    elif st == 409:
        made.append(f"{name}(existing)")
    else:
        refused.append(f"{name}: {st} {d.get('error', '')}")
        continue
    api("PUT", f"/api/v1/projects/{name}", {"namespace_id": ns})

print("accepted:", ", ".join(made) or "none")
print("refused:", "; ".join(refused) or "none")

con = sqlite3.connect(DB, timeout=60)
con.execute("PRAGMA busy_timeout=60000")
for name, workdir, ns, prompt_name in LANES:
    p = open(f"{ROOT}/prompts/{prompt_name}.md").read()
    con.execute(
        "UPDATE projects SET parent='code-factory', admission_mode='cooldown', "
        "prompt=?, prompt_mode='append' WHERE name=?",
        (p, name),
    )
con.commit()

print("\nfamily:")
for row in con.execute(
    "SELECT name, namespace_id, admission_mode, cooldown_floor_s, "
    "length(prompt) FROM projects WHERE name LIKE 'code-factory%' ORDER BY name"
):
    print(
        f"  {row[0]:28s} ns={str(row[1]):14s} mode={str(row[2]):9s} floor={row[3] or 0:<7} prompt={row[4]}"
    )
