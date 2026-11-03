# Verdict: CF-119-QA1

**Task:** QA re-verification: file the tautological-snapshot and behind-workdir census gaps
**Evaluated:** 2026-11-03T20:46:11.399125
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ The board gains two rows filed from re-run evidence at origin/main 9109975: the CF-099 drift probe's snapshot leg compares the plan's counts to the frozen tip it names so it PASSes a 7-row/16-event stale plan, and the publish-drift census grades an ancestor-HEAD workdir that is merely behind as lossy DRIFT with no repair path. Both rows carry falsifiable numbered acceptance criteria and the exact commands that demonstrated the gap.: HEAD d15fb54 adds exactly two task rows (CF-121, CF-122) plus 3 audit events (ids 134-136, actor qa) to .coding-hermes/board/{tasks,events}.jsonl. (a) CF-121 tautology reproduced: docs/audits/cf099-prd-drift-probe.sh:13-24 extracts tip/rows/events from docs/ACCEPTANCE-PLAN.md and compares them to `git show "$tip:..."` — the same frozen commit the plan names. Running `bash docs/audits/cf099-prd-drift-probe.sh` prints 'DRIFT: plan says 28 sections, tests/selftest.sh has 29' and 'measured: tip=80fca8b rows=85 events=115 sections=29', rc=1. docs/ACCEPTANCE-PLAN.md:5-8 states 85 task rows / 115 events; `git show 9109975:.coding-hermes/board/tasks.jsonl | wc -l` = 92 and events = 131 — exactly the 7-row/16-event staleness the row claims, while the snapshot legs PASS. (b) CF-122 behind-workdir census reproduced: `python3 scripts/board_drift.py check --workdir /home/kara/proj-wt-code-factory-bankai-20261030 --ref origin/main` prints 'PASS HEAD ancestry — git merge-base --is-ancestor HEAD origin/main: exit 0' yet 'RESULT: DRIFT (4 failed)', rc=1. Workdir HEAD 25d1e718 on branch code-factory-published with `git status --porcelain --untracked-files=no` empty (clean); workdir 90 rows vs 92 at 9109975, missing ids CF-117,CF-118 = exactly the rows added by the 3 commits 25d1e718..9109975 (c7dce7d, c842d0b, 9109975). `python3 scripts/board_drift.py --help` lists only the `check` subcommand — no repair path. (c) Both rows are status=pending with 6 numbered, falsifiable acceptance criteria each (each naming a concrete command and asserted output, e.g. CF-121 AC2 'prints a named DRIFT: plan says N task rows, <ref> carries M line'; CF-122 AC3 'sync ... REFUSES with a named reason and a nonzero exit') and a `probe` field carrying the exact commands that demonstrated the gap (CF-121: `bash docs/audits/cf099-prd-drift-probe.sh; echo rc=$?; git show origin/main:...|wc -l; grep -cE '^say "[0-9]+\.' tests/selftest.sh`; CF-122: `python3 scripts/board_drift.py check --workdir ... --ref origin/main; echo rc=$?; python3 scripts/board_drift.py --help`). Test evidence: `bash tests/selftest.sh` -> 'SELFTEST: PASS', rc=0; `bash scripts/boardctl validate` -> 'RESULT: OK (37 warning(s))'.
Both CF-121 and CF-122 are filed on the board with independently reproduced re-run evidence at origin/main 9109975, six falsifiable numbered acceptance criteria each, and the exact probe commands that demonstrated each gap.

## Summary

Judge Result: CF-119-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ The board gains two rows filed from re-run evidence at origin/main 9109975: the CF-099 drift probe's snapshot leg compares the plan's counts to the frozen tip it names so it PASSes a 7-row/16-event stale plan, and the publish-drift census grades an ancestor-HEAD workdir that is merely behind as lossy DRIFT with no repair path. Both rows carry falsifiable numbered acceptance criteria and the exact commands that demonstrated the gap.: HEAD d15fb54 adds exactly two task rows (CF-121, CF-122) plus 3 audit events (ids 134-136, actor qa) to .coding-hermes/board/{tasks,events}.jsonl. (a) CF-121 tautology reproduced: docs/audits/cf099-prd-drift-probe.sh:13-24 extracts tip/rows/events from docs/ACCEPTANCE-PLAN.md and compares them to `git show "$tip:..."` — the same frozen commit the plan names. Running `bash docs/audits/cf099-prd-drift-probe.sh` prints 'DRIFT: plan says 28 sections, tests/selftest.sh has 29' and 'measured: tip=80fca8b rows=85 events=115 sections=29', rc=1. docs/ACCEPTANCE-PLAN.md:5-8 states 85 task rows / 115 events; `git show 9109975:.coding-hermes/board/tasks.jsonl | wc -l` = 92 and events = 131 — exactly the 7-row/16-event staleness the row claims, while the snapshot legs PASS. (b) CF-122 behind-workdir census reproduced: `python3 scripts/board_drift.py check --workdir /home/kara/proj-wt-code-factory-bankai-20261030 --ref origin/main` prints 'PASS HEAD ancestry — git merge-base --is-ancestor HEAD origin/main: exit 0' yet 'RESULT: DRIFT (4 failed)', rc=1. Workdir HEAD 25d1e718 on branch code-factory-published with `git status --porcelain --untracked-files=no` empty (clean); workdir 90 rows vs 92 at 9109975, missing ids CF-117,CF-118 = exactly the rows added by the 3 commits 25d1e718..9109975 (c7dce7d, c842d0b, 9109975). `python3 scripts/board_drift.py --help` lists only the `check` subcommand — no repair path. (c) Both rows are status=pending with 6 numbered, falsifiable acceptance criteria each (each naming a concrete command and asserted output, e.g. CF-121 AC2 'prints a named DRIFT: plan says N task rows, <ref> carries M line'; CF-122 AC3 'sync ... REFUSES with a named reason and a nonzero exit') and a `probe` field carrying the exact commands that demonstrated the gap (CF-121: `bash docs/audits/cf099-prd-drift-probe.sh; echo rc=$?; git show origin/main:...|wc -l; grep -cE '^say "[0-9]+\.' tests/selftest.sh`; CF-122: `python3 scripts/board_drift.py check --workdir ... --ref origin/main; echo rc=$?; python3 scripts/board_drift.py --help`). Test evidence: `bash tests/selftest.sh` -> 'SELFTEST: PASS', rc=0; `bash scripts/boardctl validate` -> 'RESULT: OK (37 warning(s))'.
Both CF-121 and CF-122 are filed on the board with independently reproduced re-run evidence at origin/main 9109975, six falsifiable numbered acceptance criteria each, and the exact probe commands that demonstrated each gap.

Overall: PASS ✓
