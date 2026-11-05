# 10. scripts/configure_family.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/configure_family.py` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **RED — no verification recorded** |

## 1. Purpose and why it matters

- What breaks if this module is absent: the `code-factory` lane family is not extended to the canonical shape derived from the two existing families `crier` and `9router` (`file:2`, `file:4-6`). No `code-factory-*` project rows are created via the HTTP API or configured in the scheduler SQLite database (`file:141-188`).
- What breaks if it lies: the final `family now` report can show rows that do not match the intended canonical shape because the script both configures project rows in SQLite (`file:177-188`) and then reads them back for the report (`file:196-201`).

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `json` | UNKNOWN | Python import must resolve (`file:9`) | `import json` at `file:9` fails |
| `os` | UNKNOWN | Python import must resolve (`file:10`) | `import os` at `file:10` fails |
| `sqlite3` | UN
