# code-factory documentation correction evidence

Source commit window: `git log --since='7 days ago' --all --oneline` at local HEAD `bf7464c9ffec42756c78925aecab9fc8e03ab816`.

## Claim corrected

README.md:98 previously said: "Six lanes run this repo." The lane-family implementation added docs, README, release, performance, and review lanes plus their QA lanes in `bf7464c` (`scripts/add_family_lanes.py:36-46`). The live scheduler project inventory contains 14 matching projects, not six:

`sqlite3 ~/.hermes/coding-hermes/scheduler.db "select count(*) from projects where name='code-factory' or name like 'code-factory-%';"` → `14`

The matching names are:

`code-factory|code-factory-docs|code-factory-docs-qa|code-factory-dogfood|code-factory-duckbrain|code-factory-perf|code-factory-pm|code-factory-qa|code-factory-readme|code-factory-readme-qa|code-factory-releng|code-factory-releng-qa|code-factory-review|code-factory-sync`

The README now lists these 14 projects and identifies the live project inventory as the source for current namespace, admission-mode, and workdir values. The root `code-factory` row has no parent; the other 13 rows have `parent=code-factory`. The row's admission values are intentionally shown as `tasks` for the root foreman and `cooldown` for the satellites; the exact cooldown durations are not repeated because the current scheduler database is the measured source.

## Verification

Code path: `scripts/add_family_lanes.py:36-46` defines the eight newly-added family rows; `scripts/load_lane_config.py:13-20` defines the original six core rows. The database query above returned 14 matching project rows; the root `code-factory` row has an empty parent and is `tasks`, and the other 13 rows have `parent=code-factory` and are `cooldown`.

Source/runtime checks run:

- `bash tests/selftest.sh` → `SELFTEST: PASS` (all listed script parse checks, negative checker fixture, digest refusal fixture, credential scan, and 8/8 JSONL board rows).
- `python3 -m py_compile scripts/add_family_lanes.py scripts/clone_lane.py scripts/configure_family.py scripts/load_lane_config.py` → `python_compile=PASS`.
- `git diff --check` → no output, exit 0.
- SQLite scheduler inventory query → 14 rows, exit 0.

The selftest proves the repository's current shell and board checks; it does not prove a live remote dispatch, node provisioning, or crier round trip. Those claims remain not measured by this correction.

ch:trace row=CF-005 spec=docs/PRD-code-factory.md#requirements wave=code-factory-docs-2026-10-29-20-26-27#docs test=tests/selftest.sh::selftest doc=README.md prompt=prompts/docs.md evidence=docs/audits/code-factory-docs-2026-10-29-20-26-27.md witness=none:source-and-local-scheduler-db-only verdict=none:open-finding commit=f69f5b6fab098109c6d6d4869e3f21b9f7eda646 memory=none:unresolved-namespace

STATUS: PASS
TIER: T4 -- queried the real local scheduler SQLite project inventory and ran the repository selftest
EVIDENCE: sqlite3 /home/kara/.hermes/coding-hermes/scheduler.db inventory query; bash tests/selftest.sh
