# Verdict: QA-CODE-FACTORY-2

**Task:** CF: one source for the strict-seed wording so the selftest arm cannot flake
**Evaluated:** 2026-11-07T12:00:29.808689
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ 1. grep -rn 'an unknown seed is not a pass' scripts/ prints exactly ONE hit (the single owning source); scripts/verify-node.sh carries no private copy of the sentence and obtains it from the checker. 2. tests/selftest.sh has an arm that drives the REAL verifier over its existing vn fixture with a corrupt/0-byte seed record under --strict-seed and asserts exit 1, VERIFY: FAIL (1) and the canonical phrase in the FAIL row. 3. A seeded negative proves that arm can fail: mutating the single source in a scratch copy reds the same arm. 4. bash tests/selftest.sh prints SELFTEST: PASS (0 fails) and no assertion, bound or count was loosened. Verify legs 1-3 by inspection and targeted commands, not by running the whole suite inside the evaluation.: Leg 1: `grep -rn 'an unknown seed is not a pass' scripts/ | wc -l` = 1, the only hit being scripts/node_seed_drift.py:88 `STRICT_NOTE = "(--strict-seed: an unknown seed is not a pass)"`. verify-node.sh:216 obtains it via `strict_seed_note=$(python3 -B "$SEEDCHK" --strict-note 2>/dev/null)` and appends it at :228 (`${detail:-unmeasurable}${strict_seed_note:+ $strict_seed_note}`); the old private copy `(--strict-seed: unknown is not a pass)` is deleted (git show HEAD -- scripts/verify-node.sh shows it as a `-` line). `python3 -B scripts/node_seed_drift.py --strict-note` prints `(--strict-seed: an unknown seed is not a pass)` exit 0 (node_seed_drift.py:541-543). Leg 2: tests/selftest.sh:4152-4166 — `: > "$vn_rec"` (0-byte) then `out=$(vn_run "$vn/tree" --strict-seed)` (real verifier over the vn fixture, stub bunker/curl) asserting `rc -eq 1`, `grep -Fxq 'VERIFY: FAIL (1)'`, `'  FAIL  seed_drift — '`, `'does not parse'` (proves the exit-3 branch) and `'an unknown seed is not a pass'`. Leg 3: tests/selftest.sh:4168-4186 — copies scripts to $vn/mutant, `sed 's/an unknown seed is not a pass/an unknown is not a pass/'` on node_seed_drift.py, a `cmp -s` guard that fails if the mutation was a no-op, then re-runs the 0-byte strict-seed case and requires rc 1 + FAIL row + the canonical phrase ABSENT. Leg 4: full `bash tests/selftest.sh` run (setsid, output /tmp/st2.txt) ends line 544 `SELFTEST: PASS`, 404 PASS rows, no genuine FAIL rows (the 63 '  FAIL  ' matches are text inside PASS rows / fixture output); the new arms print PASS at lines 478-480. No loosening: `git show HEAD -- tests/selftest.sh` has 0 removed lines (pure addition), and node_seed_drift.py's row output is byte-identical (STRICT_NOTE interpolated into the same `"  FAIL  seed_drift — no seed record at %s %s"` format).
The strict-seed sentence now has exactly one owning source (node_seed_drift.py:88) that verify-node.sh queries via --strict-note, with a real-verifier 0-byte/--strict-seed arm, a seeded-negative mutation arm, and a full suite run printing SELFTEST: PASS with no assertions loosened.

## Summary

Judge Result: QA-CODE-FACTORY-2

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ 1. grep -rn 'an unknown seed is not a pass' scripts/ prints exactly ONE hit (the single owning source); scripts/verify-node.sh carries no private copy of the sentence and obtains it from the checker. 2. tests/selftest.sh has an arm that drives the REAL verifier over its existing vn fixture with a corrupt/0-byte seed record under --strict-seed and asserts exit 1, VERIFY: FAIL (1) and the canonical phrase in the FAIL row. 3. A seeded negative proves that arm can fail: mutating the single source in a scratch copy reds the same arm. 4. bash tests/selftest.sh prints SELFTEST: PASS (0 fails) and no assertion, bound or count was loosened. Verify legs 1-3 by inspection and targeted commands, not by running the whole suite inside the evaluation.: Leg 1: `grep -rn 'an unknown seed is not a pass' scripts/ | wc -l` = 1, the only hit being scripts/node_seed_drift.py:88 `STRICT_NOTE = "(--strict-seed: an unknown seed is not a pass)"`. verify-node.sh:216 obtains it via `strict_seed_note=$(python3 -B "$SEEDCHK" --strict-note 2>/dev/null)` and appends it at :228 (`${detail:-unmeasurable}${strict_seed_note:+ $strict_seed_note}`); the old private copy `(--strict-seed: unknown is not a pass)` is deleted (git show HEAD -- scripts/verify-node.sh shows it as a `-` line). `python3 -B scripts/node_seed_drift.py --strict-note` prints `(--strict-seed: an unknown seed is not a pass)` exit 0 (node_seed_drift.py:541-543). Leg 2: tests/selftest.sh:4152-4166 — `: > "$vn_rec"` (0-byte) then `out=$(vn_run "$vn/tree" --strict-seed)` (real verifier over the vn fixture, stub bunker/curl) asserting `rc -eq 1`, `grep -Fxq 'VERIFY: FAIL (1)'`, `'  FAIL  seed_drift — '`, `'does not parse'` (proves the exit-3 branch) and `'an unknown seed is not a pass'`. Leg 3: tests/selftest.sh:4168-4186 — copies scripts to $vn/mutant, `sed 's/an unknown seed is not a pass/an unknown is not a pass/'` on node_seed_drift.py, a `cmp -s` guard that fails if the mutation was a no-op, then re-runs the 0-byte strict-seed case and requires rc 1 + FAIL row + the canonical phrase ABSENT. Leg 4: full `bash tests/selftest.sh` run (setsid, output /tmp/st2.txt) ends line 544 `SELFTEST: PASS`, 404 PASS rows, no genuine FAIL rows (the 63 '  FAIL  ' matches are text inside PASS rows / fixture output); the new arms print PASS at lines 478-480. No loosening: `git show HEAD -- tests/selftest.sh` has 0 removed lines (pure addition), and node_seed_drift.py's row output is byte-identical (STRICT_NOTE interpolated into the same `"  FAIL  seed_drift — no seed record at %s %s"` format).
The strict-seed sentence now has exactly one owning source (node_seed_drift.py:88) that verify-node.sh queries via --strict-note, with a real-verifier 0-byte/--strict-seed arm, a seeded-negative mutation arm, and a full suite run printing SELFTEST: PASS with no assertions loosened.

Overall: PASS ✓
