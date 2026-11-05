# Verdict: CF-254

**Task:** Clear the python lint red (F401) that refuses every python-staging commit in this family
**Evaluated:** 2026-11-05T15:31:26.767305
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ 1. The guard lint lane is green on the tip: the exact command and its output are quoted, and no F401 finding remains for scripts/master_doc_fill.py or scripts/master_doc_skeleton.py.: Fresh run at tip 0978d58: `ruff check $(git ls-files '*.py')` -> "All checks passed!" rc=0; `ruff check scripts/master_doc_fill.py scripts/master_doc_skeleton.py` -> "All checks passed!" rc=0. Imports now: master_doc_fill.py:15-21 = argparse,json,re,time,urllib.request,ThreadPoolExecutor,Path; master_doc_skeleton.py:10-13 = json,re,subprocess,Path. Control: the same files at 52e1c4d produce 4 F401 (fill:16 os, :18 subprocess, :19 sys; skeleton:10 os), so the red is genuinely cleared. Commit 0978d58 message quotes the command and output: "ruff check over `git ls-files '*.py'` -> All checks passed." and "bash tests/selftest.sh -> SELFTEST: PASS, rc=0 (51 sections)".
  ✓ 2. A selftest arm fails when a python file carries one unused import and passes once it is removed, so the fix is re-measured rather than hand-edited.: tests/selftest.sh:3493-3533 adds §51 ("the python lint lane can go red on one unused import, and green once it is removed (CF-254)") which writes a fixture with `import os`, asserts ruff exits nonzero naming F401, rewrites the same file without the import and asserts exit 0, then grades the tracked surface. Fresh run of `bash tests/selftest.sh` output: "51. the python lint lane can go red on one unused import, and green once it is removed (CF-254)" / "  PASS  one unused import -> exit 1 naming F401" / "  PASS  same file once the import is removed -> exit 0" / "  PASS  tracked python surface clean: 29 files graded" / "SELFTEST: PASS".
  ✓ 3. The row records in one sentence why 52e1c4d reached the branch with failing python lint, naming the file:line of the scope rule it cites.: Commit 0978d58 body states in one sentence: "52e1c4d added scripts/master_doc_fill.py and scripts/master_doc_skeleton.py with unused imports (subprocess, sys; os), and the Tier-1 lint lane reds on them because it scopes on staged file EXTENSIONS and grades only *.py (.gitreins/config.yaml:9-16, CF-031)." The cited locator is verified: .gitreins/config.yaml:8-16 is exactly the CF-031 comment block explaining that the lint lane picks scope from staged file extensions and grades only *.py (engine/guard_manager.py:2823). The same mapping row is recorded at docs/ACCEPTANCE-PLAN.md:158.
All three criteria verified with fresh command output: ruff is clean on the tip (and demonstrably red at 52e1c4d), selftest §51 pins both the red and green states and passes, and the commit row names the scope rule at .gitreins/config.yaml:9-16.

## Summary

Judge Result: CF-254

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ 1. The guard lint lane is green on the tip: the exact command and its output are quoted, and no F401 finding remains for scripts/master_doc_fill.py or scripts/master_doc_skeleton.py.: Fresh run at tip 0978d58: `ruff check $(git ls-files '*.py')` -> "All checks passed!" rc=0; `ruff check scripts/master_doc_fill.py scripts/master_doc_skeleton.py` -> "All checks passed!" rc=0. Imports now: master_doc_fill.py:15-21 = argparse,json,re,time,urllib.request,ThreadPoolExecutor,Path; master_doc_skeleton.py:10-13 = json,re,subprocess,Path. Control: the same files at 52e1c4d produce 4 F401 (fill:16 os, :18 subprocess, :19 sys; skeleton:10 os), so the red is genuinely cleared. Commit 0978d58 message quotes the command and output: "ruff check over `git ls-files '*.py'` -> All checks passed." and "bash tests/selftest.sh -> SELFTEST: PASS, rc=0 (51 sections)".
  ✓ 2. A selftest arm fails when a python file carries one unused import and passes once it is removed, so the fix is re-measured rather than hand-edited.: tests/selftest.sh:3493-3533 adds §51 ("the python lint lane can go red on one unused import, and green once it is removed (CF-254)") which writes a fixture with `import os`, asserts ruff exits nonzero naming F401, rewrites the same file without the import and asserts exit 0, then grades the tracked surface. Fresh run of `bash tests/selftest.sh` output: "51. the python lint lane can go red on one unused import, and green once it is removed (CF-254)" / "  PASS  one unused import -> exit 1 naming F401" / "  PASS  same file once the import is removed -> exit 0" / "  PASS  tracked python surface clean: 29 files graded" / "SELFTEST: PASS".
  ✓ 3. The row records in one sentence why 52e1c4d reached the branch with failing python lint, naming the file:line of the scope rule it cites.: Commit 0978d58 body states in one sentence: "52e1c4d added scripts/master_doc_fill.py and scripts/master_doc_skeleton.py with unused imports (subprocess, sys; os), and the Tier-1 lint lane reds on them because it scopes on staged file EXTENSIONS and grades only *.py (.gitreins/config.yaml:9-16, CF-031)." The cited locator is verified: .gitreins/config.yaml:8-16 is exactly the CF-031 comment block explaining that the lint lane picks scope from staged file extensions and grades only *.py (engine/guard_manager.py:2823). The same mapping row is recorded at docs/ACCEPTANCE-PLAN.md:158.
All three criteria verified with fresh command output: ruff is clean on the tip (and demonstrably red at 52e1c4d), selftest §51 pins both the red and green states and passes, and the commit row names the scope rule at .gitreins/config.yaml:9-16.

Overall: PASS ✓
