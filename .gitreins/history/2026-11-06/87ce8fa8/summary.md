# Verdict: CF-320

**Task:** github-app-refresh.sh: a FAIL row after minting an insecure token must abort the credential write, and 'refreshed' must come from a re-read
**Evaluated:** 2026-11-06T18:02:24.631051
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ scripts/github-app-refresh.sh aborts a credential write when the minted token file is not mode 600, and reports 'refreshed' from a re-read of the file rather than from the minter's stdout. Proven by: bash tests/selftest.sh exits 0 at the judged commit and its github-app-refresh section asserts (a) a minter that writes mode 644 yields a FAIL row, no rewrite of the git-credential store, and a non-zero exit; (b) a token file whose mtime is 2 hours old is re-minted, proven by a changed mtime and content re-read; (c) a fresh token file (mtime now) reports a no-op without rewriting either file.: scripts/github-app-refresh.sh:127-133 — `if [ "$mode" != "600" ]; then bad "mode" ...; note "refusing to rewrite $GIT_CREDENTIALS ..."; exit 1; fi` runs BEFORE the credential-store rewrite block at :135, so a FAIL row aborts the write. 'refreshed' comes from file_state() (:88-96, stat -c %Y + sha256) read as `before`/`after` around the mint (:109-124); MINT_SKIPPED is documented as informational only (:78-86) and a stdout/re-read disagreement is named via note(). tests/selftest.sh:258-346 block 'github-app-refresh-gate': (a) :287-303 asserts rc!=0, exactly one '^  FAIL  mode' row, zero '^  PASS  refresh' rows, and `cmp -s git-credentials.pre git-credentials`; (b) :304-322 touches the token '2 hours ago' and asserts post_mtime>pre_mtime, post_digest!=pre_digest, one '^  PASS  refresh' row; (c) :323-345 asserts exit 0, token AND credential store byte-identical, and a 'no-op' row. TEST RUN: `bash tests/selftest.sh` -> exit 0, final line 'SELFTEST: PASS' (/tmp/st3.out:510, 'EXIT=0'); arms at /tmp/st3.out:45-47 all PASS ('insecure mint (mode 644) -> exit 1, one ^  FAIL  mode row, no ^  PASS  refresh row, credential store byte-identical'; 'token mtime 2h old -> re-minted: mtime 1793980869 -> 1793988069, digest changed'; 'fresh token + minter skip -> exit 0, token and credential store byte-identical, the row says no-op'). RED PROOF: the same block run against the pre-fix script (git show HEAD~1:scripts/github-app-refresh.sh) turns arm (a) FAIL ('insecure mint still rewrote the credential store (exit 0, 1 mode row(s), 1 refresh row(s))'), FAILS=1 — the arm genuinely detects the bug.
The mode gate now exits non-zero before the credential store is touched, 'refreshed' is decided by a before/after mtime+digest re-read, and bash tests/selftest.sh exits 0 with all three github-app-refresh arms passing (and arm (a) provably red against the pre-fix script).

## Summary

Judge Result: CF-320

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ scripts/github-app-refresh.sh aborts a credential write when the minted token file is not mode 600, and reports 'refreshed' from a re-read of the file rather than from the minter's stdout. Proven by: bash tests/selftest.sh exits 0 at the judged commit and its github-app-refresh section asserts (a) a minter that writes mode 644 yields a FAIL row, no rewrite of the git-credential store, and a non-zero exit; (b) a token file whose mtime is 2 hours old is re-minted, proven by a changed mtime and content re-read; (c) a fresh token file (mtime now) reports a no-op without rewriting either file.: scripts/github-app-refresh.sh:127-133 — `if [ "$mode" != "600" ]; then bad "mode" ...; note "refusing to rewrite $GIT_CREDENTIALS ..."; exit 1; fi` runs BEFORE the credential-store rewrite block at :135, so a FAIL row aborts the write. 'refreshed' comes from file_state() (:88-96, stat -c %Y + sha256) read as `before`/`after` around the mint (:109-124); MINT_SKIPPED is documented as informational only (:78-86) and a stdout/re-read disagreement is named via note(). tests/selftest.sh:258-346 block 'github-app-refresh-gate': (a) :287-303 asserts rc!=0, exactly one '^  FAIL  mode' row, zero '^  PASS  refresh' rows, and `cmp -s git-credentials.pre git-credentials`; (b) :304-322 touches the token '2 hours ago' and asserts post_mtime>pre_mtime, post_digest!=pre_digest, one '^  PASS  refresh' row; (c) :323-345 asserts exit 0, token AND credential store byte-identical, and a 'no-op' row. TEST RUN: `bash tests/selftest.sh` -> exit 0, final line 'SELFTEST: PASS' (/tmp/st3.out:510, 'EXIT=0'); arms at /tmp/st3.out:45-47 all PASS ('insecure mint (mode 644) -> exit 1, one ^  FAIL  mode row, no ^  PASS  refresh row, credential store byte-identical'; 'token mtime 2h old -> re-minted: mtime 1793980869 -> 1793988069, digest changed'; 'fresh token + minter skip -> exit 0, token and credential store byte-identical, the row says no-op'). RED PROOF: the same block run against the pre-fix script (git show HEAD~1:scripts/github-app-refresh.sh) turns arm (a) FAIL ('insecure mint still rewrote the credential store (exit 0, 1 mode row(s), 1 refresh row(s))'), FAILS=1 — the arm genuinely detects the bug.
The mode gate now exits non-zero before the credential store is touched, 'refreshed' is decided by a before/after mtime+digest re-read, and bash tests/selftest.sh exits 0 with all three github-app-refresh arms passing (and arm (a) provably red against the pre-fix script).

Overall: PASS ✓
