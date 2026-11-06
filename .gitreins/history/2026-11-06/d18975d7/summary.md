# Verdict: CF-354

**Task:** Node bus worker must consume the scheduler's text_b64 directive encoding
**Evaluated:** 2026-11-06T23:40:16.496655
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ The in-repo node executes a dispatch that carries text_b64. Re-runnable at the graded commit from the repo root: (1) python3 tests/test_bus_dispatch_encoding.py exits 0 and prints arm rows proving a text_b64 dispatch is decoded and handed to the harness verbatim, a legacy text dispatch still runs, a corrupt text_b64 is refused by name (status refused), and a dispatch with no instruction is still refused as brief; (2) grep -c text_b64 scripts/node-bus-worker.py is at least 2 and grep -c text_b64 specs/ENVELOPE.md is at least 3, so the spec states the encoding rule instead of leaving text undefined; (3) bash tests/selftest.sh prints SELFTEST: PASS and includes a numbered section that runs that fixture and a pre-fix red control against the worker source at revision 5b11bdc; (4) bash scripts/boardctl validate prints RESULT: OK. The live bus round trip is NOT part of this criterion (tracked by CF-365).: (1) `python3 tests/test_bus_dispatch_encoding.py` -> EXIT=0, printed arm rows: 'PASS A1 text_b64-only dispatch runs; the harness receives exactly the decoded bytes', 'PASS A2 a dispatch carrying only the legacy `text` still runs (no regression)', 'PASS A3 corrupt text_b64 -> named `text_b64` refusal, no fallback, harness never started', 'PASS A4 no instruction member -> the existing named `brief` refusal, unchanged', 'PASS A5 brief.digest over the base64 (not the decoded text) is refused by `brief_digest`'. (2) `grep -c text_b64 scripts/node-bus-worker.py` = 14 (>=2); `grep -c text_b64 specs/ENVELOPE.md` = 8 (>=3). (3) `bash tests/selftest.sh` -> final line 'SELFTEST: PASS' (output line 113); numbered section '54. the bus worker decodes the wire directive member, and the pre-fix revision cannot (CF-354)' with rows 'PASS text_b64 decoded to the harness bytes, legacy text still runs, corrupt text_b64 / absent instruction / base64 digest each refused' and 'PASS pre-fix 5b11bdc refuses the text_b64 dispatch with the brief row (fixture detects CF-354)'; tests/selftest.sh:4720 runs `git show 5b11bdc:scripts/node-bus-worker.py` for the red control. (4) `bash scripts/boardctl validate` -> EXIT=0, 'RESULT: OK (7 warning(s))'.
All four re-runnable checks pass at commit 1f1c0fe: the encoding fixture exits 0 with A1-A5 arm rows, text_b64 appears 14x in the worker and 8x in the spec, selftest prints SELFTEST: PASS including section 54 with the 5b11bdc pre-fix red control, and boardctl validate prints RESULT: OK.

## Summary

Judge Result: CF-354

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ The in-repo node executes a dispatch that carries text_b64. Re-runnable at the graded commit from the repo root: (1) python3 tests/test_bus_dispatch_encoding.py exits 0 and prints arm rows proving a text_b64 dispatch is decoded and handed to the harness verbatim, a legacy text dispatch still runs, a corrupt text_b64 is refused by name (status refused), and a dispatch with no instruction is still refused as brief; (2) grep -c text_b64 scripts/node-bus-worker.py is at least 2 and grep -c text_b64 specs/ENVELOPE.md is at least 3, so the spec states the encoding rule instead of leaving text undefined; (3) bash tests/selftest.sh prints SELFTEST: PASS and includes a numbered section that runs that fixture and a pre-fix red control against the worker source at revision 5b11bdc; (4) bash scripts/boardctl validate prints RESULT: OK. The live bus round trip is NOT part of this criterion (tracked by CF-365).: (1) `python3 tests/test_bus_dispatch_encoding.py` -> EXIT=0, printed arm rows: 'PASS A1 text_b64-only dispatch runs; the harness receives exactly the decoded bytes', 'PASS A2 a dispatch carrying only the legacy `text` still runs (no regression)', 'PASS A3 corrupt text_b64 -> named `text_b64` refusal, no fallback, harness never started', 'PASS A4 no instruction member -> the existing named `brief` refusal, unchanged', 'PASS A5 brief.digest over the base64 (not the decoded text) is refused by `brief_digest`'. (2) `grep -c text_b64 scripts/node-bus-worker.py` = 14 (>=2); `grep -c text_b64 specs/ENVELOPE.md` = 8 (>=3). (3) `bash tests/selftest.sh` -> final line 'SELFTEST: PASS' (output line 113); numbered section '54. the bus worker decodes the wire directive member, and the pre-fix revision cannot (CF-354)' with rows 'PASS text_b64 decoded to the harness bytes, legacy text still runs, corrupt text_b64 / absent instruction / base64 digest each refused' and 'PASS pre-fix 5b11bdc refuses the text_b64 dispatch with the brief row (fixture detects CF-354)'; tests/selftest.sh:4720 runs `git show 5b11bdc:scripts/node-bus-worker.py` for the red control. (4) `bash scripts/boardctl validate` -> EXIT=0, 'RESULT: OK (7 warning(s))'.
All four re-runnable checks pass at commit 1f1c0fe: the encoding fixture exits 0 with A1-A5 arm rows, text_b64 appears 14x in the worker and 8x in the spec, selftest prints SELFTEST: PASS including section 54 with the 5b11bdc pre-fix red control, and boardctl validate prints RESULT: OK.

Overall: PASS ✓
