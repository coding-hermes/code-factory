# Verdict: CF-277

**Task:** install-codex.sh: validate CF_RUN_ID and confine the isolated turn-home delete to a mktemp dir
**Evaluated:** 2026-11-06T01:49:25.262310
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ install-codex.sh refuses any CF_RUN_ID that is not a bare identifier, exiting 2 and naming run_id, so a crafted value such as dot-dot-slash cannot reach any delete path; the isolated CODEX_HOME turn dir is a fresh mktemp directory under the cache root and every removal is proven to stay inside that root; and the hermetic installer battery executes a crafted-run-id fixture that shows the refusal and shows a sentinel file outside the temp tree surviving the run.: Admission: scripts/harness/install-codex.sh:205-211 — validate_vars() rejects CF_RUN_ID unless it matches ^[A-Za-z0-9][A-Za-z0-9._-]*$ and is <=128 chars, calling `refuse run_id` with the value echoed truncated to 64 chars; refuse() at :75-79 prints 'FAIL run_id — refused: ...' plus 'CODEX: REFUSED (run_id)' and `exit 2`. Containment: :518-527 — cache_root=$(turn_cache_root) (${XDG_CACHE_HOME:-$HOME/.cache}/cf-codex), turn_home=$(umask 077; mktemp -d "$cache_root/run.XXXXXXXX"), never derived from CF_RUN_ID; the old pre-create `rm -rf` is gone. cleanup() trap at :519-523 calls inside_turn_cache before `rm -rf --`; inside_turn_cache at :251-259 requires the "$root"/run.?* prefix and a leaf containing no '/'. Independent repro: HOME=$T/home, --turn --run-id '../../victim' -> RC=2, output 'FAIL run_id — refused: CF_RUN_ID must be a bare identifier (^[A-Za-z0-9][A-Za-z0-9._-]*$, max 128 chars); got '../../victim' (12 chars)' + 'CODEX: REFUSED (run_id)'; $T/home/victim/keep.txt SENTINEL_SURVIVED; NO_CACHE_ROOT created. Battery: `bash tests/harness/codex-install-test.sh` EXIT=0, 'codex installer test: 51 passed, 0 failed, 0 skipped' / 'RESULT: PASS'. Section D (tests/harness/codex-install-test.sh:300-419) is hermetic (fresh $FAKEHOME, stub codex, no network): D1a --check refuses '../../victim' with exit 2 naming run_id and quoting the value, and both $SB/victim and $RUNID_HOME/victim sentinels survive; D1b --turn refuses the same id, neither sentinel removed, nothing created under $HOME/.cache; D1c refuses ../victim, .hidden, a/b, a;b, 'a b', $x and a 129-char id; D2 admits r-lane and keeps the contract:CF_RUN_ID line; D3a the reported turn_home is $HOME/.cache/cf-codex/run.F6il9m7Y with no run-id part, D3b that exact dir is gone after the run, D3c the sentinel.keep beside the turn home still exists.
CF_RUN_ID is validated fail-closed with exit 2 naming run_id, the turn home is a fresh mktemp leaf under the cache root guarded by inside_turn_cache before any rm -rf, and the hermetic section-D fixture passes (51/0/0, RESULT: PASS) showing the refusal plus surviving sentinels outside the temp tree.

## Summary

Judge Result: CF-277

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ install-codex.sh refuses any CF_RUN_ID that is not a bare identifier, exiting 2 and naming run_id, so a crafted value such as dot-dot-slash cannot reach any delete path; the isolated CODEX_HOME turn dir is a fresh mktemp directory under the cache root and every removal is proven to stay inside that root; and the hermetic installer battery executes a crafted-run-id fixture that shows the refusal and shows a sentinel file outside the temp tree surviving the run.: Admission: scripts/harness/install-codex.sh:205-211 — validate_vars() rejects CF_RUN_ID unless it matches ^[A-Za-z0-9][A-Za-z0-9._-]*$ and is <=128 chars, calling `refuse run_id` with the value echoed truncated to 64 chars; refuse() at :75-79 prints 'FAIL run_id — refused: ...' plus 'CODEX: REFUSED (run_id)' and `exit 2`. Containment: :518-527 — cache_root=$(turn_cache_root) (${XDG_CACHE_HOME:-$HOME/.cache}/cf-codex), turn_home=$(umask 077; mktemp -d "$cache_root/run.XXXXXXXX"), never derived from CF_RUN_ID; the old pre-create `rm -rf` is gone. cleanup() trap at :519-523 calls inside_turn_cache before `rm -rf --`; inside_turn_cache at :251-259 requires the "$root"/run.?* prefix and a leaf containing no '/'. Independent repro: HOME=$T/home, --turn --run-id '../../victim' -> RC=2, output 'FAIL run_id — refused: CF_RUN_ID must be a bare identifier (^[A-Za-z0-9][A-Za-z0-9._-]*$, max 128 chars); got '../../victim' (12 chars)' + 'CODEX: REFUSED (run_id)'; $T/home/victim/keep.txt SENTINEL_SURVIVED; NO_CACHE_ROOT created. Battery: `bash tests/harness/codex-install-test.sh` EXIT=0, 'codex installer test: 51 passed, 0 failed, 0 skipped' / 'RESULT: PASS'. Section D (tests/harness/codex-install-test.sh:300-419) is hermetic (fresh $FAKEHOME, stub codex, no network): D1a --check refuses '../../victim' with exit 2 naming run_id and quoting the value, and both $SB/victim and $RUNID_HOME/victim sentinels survive; D1b --turn refuses the same id, neither sentinel removed, nothing created under $HOME/.cache; D1c refuses ../victim, .hidden, a/b, a;b, 'a b', $x and a 129-char id; D2 admits r-lane and keeps the contract:CF_RUN_ID line; D3a the reported turn_home is $HOME/.cache/cf-codex/run.F6il9m7Y with no run-id part, D3b that exact dir is gone after the run, D3c the sentinel.keep beside the turn home still exists.
CF_RUN_ID is validated fail-closed with exit 2 naming run_id, the turn home is a fresh mktemp leaf under the cache root guarded by inside_turn_cache before any rm -rf, and the hermetic section-D fixture passes (51/0/0, RESULT: PASS) showing the refusal plus surviving sentinels outside the temp tree.

Overall: PASS ✓
