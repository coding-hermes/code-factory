# Verdict: CF-197-DOC3

**Task:** docs: the public-bind auth gate is a parsed credential check, not text presence (CF-197)
**Evaluated:** 2026-11-04T10:16:15.170830
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ The docs correction for CF-197 is in the COMMITTED tree and its evidence is verifiable. Evaluate ONLY the documentation change and the board filing; do NOT evaluate or re-run the install-hermes.sh auth parser itself (that code landed under CF-071 and is out of scope here).

1. The text-presence wording is gone from the committed documents: `git show HEAD:docs/OPERATIONS.md | grep -c 'substring check for'` prints 0, and `git show HEAD:docs/THREAT-MODEL.md | grep -c 'text occurs in config'` prints 0.
2. The replacement cites the code path that proves it: `git show HEAD:docs/OPERATIONS.md` contains `install-hermes.sh:66–186` and `install-hermes.sh:258`, and `git show HEAD:scripts/harness/install-hermes.sh | sed -n '186p'` prints `refuse("empty value (username and password must both be non-empty)")`.
3. The evidence file `docs/audits/code-factory-docs-2026-11-04-cf071-auth-prose.md` exists in the committed tree and carries a before/after table with file:line, the literal arm output for the published adapter and the pre-fix adapter, and a "Claims I could not verify" section.
4. The board row CF-197 exists in the committed `.coding-hermes/board/tasks.jsonl` with a non-empty `probe` field and non-empty `acceptance_criteria`.
5. The repository gate passed at the correction commit: `bash tests/selftest.sh` prints `SELFTEST: PASS` and `bash scripts/boardctl validate` prints `RESULT: OK`.: All five sub-checks verified against the committed tree at HEAD=76d30e9 (working tree clean). (1) `git show HEAD:docs/OPERATIONS.md | grep -c 'substring check for'` -> 0; `git show HEAD:docs/THREAT-MODEL.md | grep -c 'text occurs in config'` -> 0. (2) `git show HEAD:docs/OPERATIONS.md` line 80 contains both `scripts/harness/install-hermes.sh:66–186` and `scripts/harness/install-hermes.sh:258`; `git show HEAD:scripts/harness/install-hermes.sh | sed -n '186p'` -> `    refuse("empty value (username and password must both be non-empty)")`. (3) `git cat-file -e HEAD:docs/audits/code-factory-docs-2026-11-04-cf071-auth-prose.md` -> EXISTS; file has a `## Before / after` table with a `File:line` column (rows 1–8, e.g. `docs/OPERATIONS.md:80`, `docs/OPERATIONS.md:82`, `docs/THREAT-MODEL.md:46`, `specs/NODE.md:28`), a `## Literal arm output` section quoting the published adapter (`4295860`: new_absent/new_commented/new_empty/new_textonly/new_valid) and the pre-fix adapter (`3e6ac40^`: old_commented/old_valid), and a `## Claims I could not verify` section. (4) `git show HEAD:.coding-hermes/board/tasks.jsonl | grep -c CF-197` -> 1; parsed row id=CF-197 has a non-empty `probe` (mktemp HOME fixture + stub hermes + `install-hermes.sh --apply | grep -m1 gateway_start`) and non-empty `acceptance_criteria` (AC0–ACn). (5) `bash tests/selftest.sh` -> `SELFTEST: PASS`, exit 0; `bash scripts/boardctl validate` -> `RESULT: OK (4 warning(s))`, exit 0 (warnings are pre-existing: CF-034 free-form fields, legacy duplicate event id, headerless board). The install-hermes.sh parser itself was not re-evaluated, per scope.
The CF-197 docs correction, its audit evidence file, and the CF-197 board row are all present in the committed tree with the required wording removed, code-path citations, before/after table, arm outputs, unverified-claims section, and both repository gates passing.

## Summary

Judge Result: CF-197-DOC3

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ The docs correction for CF-197 is in the COMMITTED tree and its evidence is verifiable. Evaluate ONLY the documentation change and the board filing; do NOT evaluate or re-run the install-hermes.sh auth parser itself (that code landed under CF-071 and is out of scope here).

1. The text-presence wording is gone from the committed documents: `git show HEAD:docs/OPERATIONS.md | grep -c 'substring check for'` prints 0, and `git show HEAD:docs/THREAT-MODEL.md | grep -c 'text occurs in config'` prints 0.
2. The replacement cites the code path that proves it: `git show HEAD:docs/OPERATIONS.md` contains `install-hermes.sh:66–186` and `install-hermes.sh:258`, and `git show HEAD:scripts/harness/install-hermes.sh | sed -n '186p'` prints `refuse("empty value (username and password must both be non-empty)")`.
3. The evidence file `docs/audits/code-factory-docs-2026-11-04-cf071-auth-prose.md` exists in the committed tree and carries a before/after table with file:line, the literal arm output for the published adapter and the pre-fix adapter, and a "Claims I could not verify" section.
4. The board row CF-197 exists in the committed `.coding-hermes/board/tasks.jsonl` with a non-empty `probe` field and non-empty `acceptance_criteria`.
5. The repository gate passed at the correction commit: `bash tests/selftest.sh` prints `SELFTEST: PASS` and `bash scripts/boardctl validate` prints `RESULT: OK`.: All five sub-checks verified against the committed tree at HEAD=76d30e9 (working tree clean). (1) `git show HEAD:docs/OPERATIONS.md | grep -c 'substring check for'` -> 0; `git show HEAD:docs/THREAT-MODEL.md | grep -c 'text occurs in config'` -> 0. (2) `git show HEAD:docs/OPERATIONS.md` line 80 contains both `scripts/harness/install-hermes.sh:66–186` and `scripts/harness/install-hermes.sh:258`; `git show HEAD:scripts/harness/install-hermes.sh | sed -n '186p'` -> `    refuse("empty value (username and password must both be non-empty)")`. (3) `git cat-file -e HEAD:docs/audits/code-factory-docs-2026-11-04-cf071-auth-prose.md` -> EXISTS; file has a `## Before / after` table with a `File:line` column (rows 1–8, e.g. `docs/OPERATIONS.md:80`, `docs/OPERATIONS.md:82`, `docs/THREAT-MODEL.md:46`, `specs/NODE.md:28`), a `## Literal arm output` section quoting the published adapter (`4295860`: new_absent/new_commented/new_empty/new_textonly/new_valid) and the pre-fix adapter (`3e6ac40^`: old_commented/old_valid), and a `## Claims I could not verify` section. (4) `git show HEAD:.coding-hermes/board/tasks.jsonl | grep -c CF-197` -> 1; parsed row id=CF-197 has a non-empty `probe` (mktemp HOME fixture + stub hermes + `install-hermes.sh --apply | grep -m1 gateway_start`) and non-empty `acceptance_criteria` (AC0–ACn). (5) `bash tests/selftest.sh` -> `SELFTEST: PASS`, exit 0; `bash scripts/boardctl validate` -> `RESULT: OK (4 warning(s))`, exit 0 (warnings are pre-existing: CF-034 free-form fields, legacy duplicate event id, headerless board). The install-hermes.sh parser itself was not re-evaluated, per scope.
The CF-197 docs correction, its audit evidence file, and the CF-197 board row are all present in the committed tree with the required wording removed, code-path citations, before/after table, arm outputs, unverified-claims section, and both repository gates passing.

Overall: PASS ✓
