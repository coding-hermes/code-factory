# Verdict: CF-091-QA2

**Task:** QA filing: CF-091 and CF-092 exist on the published board with measured evidence and falsifiable criteria
**Evaluated:** 2026-11-03T17:30:53.018630
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ At origin/main, .coding-hermes/board/tasks.jsonl contains CF-091 (P2, pending) and CF-092 (P4, pending); CF-091's reasoning states the measured 383-of-866 rejection census by class and the diverged-family probe result, its acceptance criteria require a committed census, per-lane waivers with owners, and a selftest arm that fails on two different valid roots; CF-092's reasoning states the measured one-gate-row output of the documented command in README Status row 1. boardctl validate reports RESULT: OK and every board line parses.: HEAD == origin/main == a2cc8b83d4e97491d68618fdfd693b8dc7f9d9dc (git rev-parse HEAD and origin/main identical; `git diff HEAD -- .coding-hermes/board/` empty, so the committed tree is what was validated). CF-091 at tasks.jsonl:78 — status=pending, priority=P2; reasoning states the census verbatim: "866 project rows", "exits 2 and prints '383 rejected, 483 accepted'", classes 253 not-a-git-root / 76 unsupported scheme https / 38 path does not exist / 15 not a git repository / 1 relative path (classes sum to 383; 383+483=866, arithmetic verified); diverged-family probe stated: "a two-row fixture with the primary on local:/home/kara/code-factory and its satellite on local:/home/kara/duckbrain (two different VALID git roots) prints two PASS lines and exits 0, byte-identical in shape and status to the aligned control". CF-091 acceptance_criteria contains all three required arms: committed census artifact under docs/audits/ with totals by class + reproduction commands; waiver file with "a named owner and a re-check date"; and "One selftest arm fails when two rows of the same family carry two different VALID repo_url roots: a primary+satellite fixture on two real git roots exits nonzero and names both lanes, while the aligned fixture exits 0. Reverting the check makes that arm fail." CF-092 — status=pending, priority=P4; reasoning states "prints exactly ONE gate row ('FAIL python - hermes-agent 0.19.0 requires python >=3.11,<3.14; found 3.14.4') and exits 1" for the command offered by README Status row 1; premise corroborated at README.md:73 (row 1 state cell claims "binary and port gates" while its re-run cell offers the unqualified `scripts/harness/install-hermes.sh --check`) versus README.md:75 (row 3 carries the `HERMES_PYTHON_BIN=python3.12` qualified form). `./scripts/boardctl validate` output: "RESULT: OK (25 warning(s))", EXIT=0. Every board line parses: 79/79 tasks.jsonl lines JSON-parse (both working tree and `git show HEAD:.coding-hermes/board/tasks.jsonl`) and 99/99 events.jsonl lines parse, with zero parse failures.


## Summary

Judge Result: CF-091-QA2

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ At origin/main, .coding-hermes/board/tasks.jsonl contains CF-091 (P2, pending) and CF-092 (P4, pending); CF-091's reasoning states the measured 383-of-866 rejection census by class and the diverged-family probe result, its acceptance criteria require a committed census, per-lane waivers with owners, and a selftest arm that fails on two different valid roots; CF-092's reasoning states the measured one-gate-row output of the documented command in README Status row 1. boardctl validate reports RESULT: OK and every board line parses.: HEAD == origin/main == a2cc8b83d4e97491d68618fdfd693b8dc7f9d9dc (git rev-parse HEAD and origin/main identical; `git diff HEAD -- .coding-hermes/board/` empty, so the committed tree is what was validated). CF-091 at tasks.jsonl:78 — status=pending, priority=P2; reasoning states the census verbatim: "866 project rows", "exits 2 and prints '383 rejected, 483 accepted'", classes 253 not-a-git-root / 76 unsupported scheme https / 38 path does not exist / 15 not a git repository / 1 relative path (classes sum to 383; 383+483=866, arithmetic verified); diverged-family probe stated: "a two-row fixture with the primary on local:/home/kara/code-factory and its satellite on local:/home/kara/duckbrain (two different VALID git roots) prints two PASS lines and exits 0, byte-identical in shape and status to the aligned control". CF-091 acceptance_criteria contains all three required arms: committed census artifact under docs/audits/ with totals by class + reproduction commands; waiver file with "a named owner and a re-check date"; and "One selftest arm fails when two rows of the same family carry two different VALID repo_url roots: a primary+satellite fixture on two real git roots exits nonzero and names both lanes, while the aligned fixture exits 0. Reverting the check makes that arm fail." CF-092 — status=pending, priority=P4; reasoning states "prints exactly ONE gate row ('FAIL python - hermes-agent 0.19.0 requires python >=3.11,<3.14; found 3.14.4') and exits 1" for the command offered by README Status row 1; premise corroborated at README.md:73 (row 1 state cell claims "binary and port gates" while its re-run cell offers the unqualified `scripts/harness/install-hermes.sh --check`) versus README.md:75 (row 3 carries the `HERMES_PYTHON_BIN=python3.12` qualified form). `./scripts/boardctl validate` output: "RESULT: OK (25 warning(s))", EXIT=0. Every board line parses: 79/79 tasks.jsonl lines JSON-parse (both working tree and `git show HEAD:.coding-hermes/board/tasks.jsonl`) and 99/99 events.jsonl lines parse, with zero parse failures.


Overall: PASS ✓
