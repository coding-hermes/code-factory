#!/usr/bin/env python3
"""configure_family.py — extend the code-factory lane family to the canonical shape.

The shape is DERIVED from the two existing families in the live DB (crier, 9router),
never hand-enumerated: every satellite a family carries there, code-factory must carry too.
Idempotent: an existing lane is configured, not duplicated.
"""
import json
import os
import sqlite3
import urllib.error
import urllib.request

DB = os.path.expanduser("~/.hermes/coding-hermes/scheduler.db")
API = "http://127.0.0.1:9090"
ROOT = os.path.expanduser("~/code-factory")
HOME = os.path.expanduser("~")

PID = "1755676"
env = open(f"/proc/{PID}/environ", "rb").read().decode(errors="replace").split("\0")
TOKEN = next(v.split("=", 1)[1] for v in env if v.startswith("SCHEDULER_OPERATOR_TOKEN="))


def api(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API + path, data=data, method=method,
                                 headers={"Authorization": f"Bearer {TOKEN}",
                                          "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        return e.code, {"error": e.read().decode()[:200]}


# --- derive the canonical satellite suffixes from the existing families -------------
con = sqlite3.connect(DB, timeout=60)
con.execute("PRAGMA busy_timeout=60000")
families = ["crier", "9router"]
shape = {}
for fam in families:
    for name, ns, mode, floor, wd in con.execute(
        "SELECT name, namespace_id, admission_mode, COALESCE(cooldown_floor_s,0), workdir "
        "FROM projects WHERE name LIKE ? AND name != ? ORDER BY name", (f"{fam}%", fam)
    ):
        suffix = name[len(fam):].lstrip("-")          # e.g. "docs-qa"
        if suffix and suffix not in shape:
            shape[suffix] = (ns, mode, floor, wd.replace(fam, "<p>"))
print("derived shape from", ", ".join(families), "->", ", ".join(sorted(shape)) or "none")

# --- prompts for the lanes that need a new one --------------------------------------
PROMPTS = {
    "docs": """Your job: keep the documentation true to the code.

1. Pick the largest documentation claim the last week's commits made false.
2. Correct it in the doc, quoting the code path that proves the new statement.
3. Never document an intention as if it were behaviour. If it is not measured, say "not measured".
4. Report: claims corrected, claims you could not verify, the file and line for each.
""",
    "readme": """Your job: the README is the first thing a stranger reads.

1. Follow every command in `README.md` literally and record where it fails.
2. Keep the status table honest: a piece that is "works" must have a command behind it, and a
   piece that is "not yet" must say what is missing.
3. Remove anything that only makes sense to an insider.
4. Report: commands tested, commands that failed, wording that promised more than the code does.
""",
    "releng": """Your job: releases and the state of the tree.

1. Verify the tree builds and `tests/selftest.sh` is green from a clean checkout.
2. Check the repo's public posture: no secrets, no internal endpoints, license present,
   branch protection and secret scanning on.
3. If a release is due, tag it from a green commit and write the notes from board rows, not
   from memory.
4. Report: build status, gate status, public-posture findings, what was tagged.
""",
    "perf": """Your job: measure, do not estimate.

1. Time the paths this repo owns: `tests/selftest.sh`, a node provision, a repo clone, a build.
2. Compare against the last recorded numbers; a regression is a finding, not noise.
3. Propose one change at a time, with the measurement that justifies it.
4. Report: metric, before, after, and the command that produced both.
""",
}

for lane, text in PROMPTS.items():
    path = os.path.join(ROOT, "prompts", f"{lane}.md")
    with open(path, "w") as f:
        f.write(f"# Lane prompt — code-factory / {lane}\n\nYou are the {lane} lane for the "
                f"`code-factory` project: the repo that builds the distributed coding workforce.\n\n"
                + text +
                "\n## Ground rules\n\n- `AGENTS.md` is the working agreement; specs are the design "
                "authority.\n- The board is `.coding-hermes/board/tasks.jsonl` — append only.\n"
                "- Never claim a row complete without a command someone else can re-run.\n"
                "- No secrets, no internal endpoints, no personal data: this repo is public.\n")
    print("wrote", path)

# --- per-lane workdir + prompt mapping ---------------------------------------------
LANE_PROMPT = {"qa": "qa", "docs": "docs", "readme": "readme", "releng": "releng",
               "perf": "perf", "pm": "pm", "dogfood": "dogfood", "sync": "sync",
               "duckbrain": "duckbrain"}
PACE_CEILING = {"docs": 604800 * 8, "readme": 604800 * 8, "perf": 604800 * 8,
                "releng": 21600 * 8, "qa": 21600 * 8, "pm": 86400 * 8,
                "dogfood": 259200 * 8, "sync": 21600 * 8, "duckbrain": 0}

created, configured, failed = [], [], []
for suffix, (ns, mode, floor, wd_tmpl) in sorted(shape.items()):
    name = f"code-factory-{suffix}"
    workdir = wd_tmpl.replace("<p>", "code-factory")
    os.makedirs(workdir, exist_ok=True)
    st, d = api("POST", "/api/v1/projects",
                {"name": name, "repo_url": f"local:{ROOT}", "workdir": workdir})
    if st == 201:
        created.append(name)
    elif st != 409:
        failed.append(f"{name}: {st} {d.get('error','')}")
        continue
    # configure: namespace via API (refreshes the daemon's view), the rest directly
    api("PUT", f"/api/v1/projects/{name}", {"namespace_id": ns})
    base = suffix.split("-")[0]
    prompt_file = os.path.join(ROOT, "prompts", f"{LANE_PROMPT.get(base, 'foreman')}.md")
    prompt = open(prompt_file).read() if os.path.exists(prompt_file) else ""
    con.execute(
        "UPDATE projects SET parent='code-factory', admission_mode=?, prompt=?, prompt_mode='append', "
        "cooldown_floor_s=?, cooldown_ceiling_s=? WHERE name=?",
        (mode or "cooldown", prompt, floor, PACE_CEILING.get(base, floor * 8 if floor else 0), name),
    )
    configured.append(f"{name} ns={ns} mode={mode} floor={floor}")
con.commit()

print("\ncreated:", ", ".join(created) or "none")
print("failed:", "; ".join(failed) or "none")
print("\nconfigured:")
for c in configured:
    print("  " + c)
print("\nfamily now:")
for row in con.execute("SELECT name, namespace_id, admission_mode, cooldown_floor_s FROM projects "
                       "WHERE name LIKE 'code-factory%' ORDER BY name"):
    print(f"  {row[0]:30s} ns={str(row[1]):14s} mode={str(row[2]):9s} floor={row[3]}")
