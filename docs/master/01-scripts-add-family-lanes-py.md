# 01. scripts/add_family_lanes.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/add_family_lanes.py` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **RED — no verification recorded** |

## 1. Purpose and why it matters

- What breaks if this module is absent: The lane-family projects listed in `LANES` are not created via `POST /api/v1/projects`, not assigned namespaces via `PUT /api/v1/projects/{name}`, and not updated in `~/.hermes/coding-hermes/scheduler.db` with `parent='code-factory'`, `admission_mode='cooldown'`, `prompt`, and `prompt_mode='append'` (`add_family_lanes.py:50-95`); the workdirs in `LANES` are also not created (`add_family_lanes.py:69`).
- What breaks if it lies: Because `accepted:` and `refused:` are printed before the SQLite `UPDATE` block, a later database failure would leave a misleading status summary (`add_family_lanes.py:84-95`). The docstring also warns that if a lane is still refused, the fix is not live and the operator must say so rather than fall back to SQL (`add_family_lanes.py:4-5`).

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `coding-hermes-scheduler` user service MainPID | UNKNOWN | `systemctl --user show -p MainPID --value coding-hermes-scheduler` must produce a usable PID (`add_family_lanes.py:18-23`) | `PID` falls back to `"0"`, causing `open(f"/proc/0/environ", "rb")` to raise `FileNotFoundError` (`add_family_lanes.py:18-27`) |
| `SCHEDULER_OPERATOR_TOKEN` in scheduler process environment | UNKNOWN | Must appear as `SCHEDULER_OPERATOR_TOKEN=` in `/proc/{PID}/environ` (`add_family_lanes.py:25-32`) | `next(...)` raises `StopIteration` if no matching entry exists (`add_family_lanes.py:25-32`) |
| Scheduler HTTP API | UNKNOWN | Must serve `http://127.0.0.1:9090` and accept `POST /api/v1/projects` and `PUT /api/v1/projects/{name}` (`add_family_lanes.py:14,70-82`) | `api()` catches `urllib.error.HTTPError` and returns its code/body; other `urlopen` failures are unhandled (`add_family_lanes.py:43-47`) |
| SQLite database | UNKNOWN | Must be writable at `~/.hermes/coding-hermes/scheduler.db` and contain a `projects` table with the columns used in `UPDATE`/`SELECT` (`add_family_lanes.py:15,87-102`) | Unhandled `sqlite3` exception from `connect`, `execute`, or `commit` (`add_family_lanes.py:87-96,99-100`) |
| Prompt markdown files | UNKNOWN | Must exist under `~/code-factory/prompts/{prompt_name}.md` for each `prompt_name` in `LANES` (`add_family_lanes.py:50-65,89-90`) | Unhandled `FileNotFoundError` from `open(...).read()` (`add_family_lanes.py:90`) |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `json` | Python standard library (`import json`, `add_family_lanes.py:8`) | `json.dumps(body).encode()` for request bodies; `json.loads(r.read().decode() or "{}")` for success responses (`add_family_lanes.py:36,45`) | UNKNOWN |
| `os` | Python standard library (`import os`, `add_family_lanes.py:9`) | `os.path.expanduser` for `~/.hermes` and `~/code-factory` (`add_family_lanes.py:15-17`); `os.popen` for reading scheduler MainPID (`add_family_lanes.py:19`); `os.makedirs(workdir, exist_ok=True)` (`add_family_lanes.py:69`) | UNKNOWN |
| `sqlite3` | Python standard library (`import sqlite3`, `add_family_lanes.py:10`) | `sqlite3.connect(DB, timeout=60)` (`add_family_lanes.py:87`); `con.execute("PRAGMA busy_timeout=60000")` (`add_family_lanes.py:88`); parameterized `UPDATE projects SET parent='code-factory', admission_mode='cooldown', prompt=?, prompt_mode='append' WHERE name=?` (`add_family_lanes.py:91-94`); `SELECT name, namespace_id, admission_mode, cooldown_floor_s, length(prompt) FROM projects WHERE name LIKE 'code-factory%' ORDER BY name` (`add_family_lanes.py:99-101`); `con.commit()` (`add_family_lanes.py:96`) | UNKNOWN |
| `urllib.error` | Python standard library (`import urllib.error`, `add_family_lanes.py:11`) | `urllib.error.HTTPError` caught with `e.code` and `e.read().decode()[:300]` (`add_family_lanes.py:46-47`) | UNKNOWN |
| `urllib.request` | Python standard library (`import urllib.request`, `add_family_lanes.py:12`) | `urllib.request.Request(API + path, data=data, method=method, headers={"Authorization": f"Bearer {tok}", "Content-Type": "application/json"})` (`add_family_lanes.py:37-41`); `urllib.request.urlopen(req, timeout=30)` (`add_family_lanes.py:44`) | UNKNOWN |
