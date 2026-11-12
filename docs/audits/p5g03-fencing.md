P5G-03 fencing evidence

Scope

The normative correction is specification-only. The target authority, broker and
resource participants remain TARGET-UNIMPLEMENTED; runtime fencing is UNVERIFIED.
No live service or production authority was exercised.

Commands and observed results

1. python3 docs/audits/p5g03_fencing_check.py
   PASS Git publication: blocked unknown, recovery, stale rejection, both orderings
   PASS Board: blocked unknown, recovery, stale rejection, both orderings
   PASS Memory: blocked unknown, recovery, stale rejection, both orderings
   PASS Crier: blocked unknown, recovery, stale rejection, both orderings
   PASS Scheduler: blocked unknown, recovery, stale rejection, both orderings
   PASS specification model only; runtime UNVERIFIED
   exit 0

2. python3 scripts/handbook_lint.py
   handbook_lint: clean
   exit 0

3. python3 -m json.tool docs/handbook/contract-vectors.json > /dev/null
   exit 0; the vector file was not changed.

4. ruff format --check docs/audits/p5g03_fencing_check.py
   1 file already formatted
   exit 0

5. ruff check docs/audits/p5g03_fencing_check.py
   All checks passed!
   exit 0

6. git diff --check
   exit 0

7. bash tests/selftest.sh
   SELFTEST: PASS
   SELFTEST_RC=0
   exit 0

8. gitreins guard (staged scope, full test mode)
   Tier 1 Guards: PASS (test mode: full)
   secrets clean; lint ok; tests (full); exit 0.
   Warning: guards.lint_command is an unknown configuration key.

Scoped consistency inventory

- Part I §1.9.3/§1.9.3a remains the sole authority for the full Fence,
  independent epoch issue/advance, begin-effect/finish-effect, lease timing,
  restart invalidation, and unknown-effect takeover block.
- Part II F8 now points to the same authority and M7 §17–17.1 resource oracle.
- M2, M3, M4, M9, IV and VII use the same Fence, STALE_OWNER,
  EFFECT_UNRESOLVED, AUTHORITY_UNAVAILABLE and EFFECT_CONFLICT terms. The
  scheduler is included as a protected resource; no competing broker enum or
  second Fence shape was introduced.
- VI stale dual ownership names the independent authority as issuer/advancer and
  links the deterministic procedure.
- M7 §17 adds the scheduler row and §17.1 supplies the ordered unknown-effect,
  recovery, advance-before-begin and begin-before-advance scenarios for Git,
  Board, Memory, Crier and Scheduler. Each row has before/old/new values and an
  atomic boundary/readback oracle.
- contract-vectors.json was parsed but not modified; CV-06-D remains the
  pre-existing static vector and is not represented as runtime evidence.

Changed source surfaces

- docs/handbook/chapters/M2-dispatch.md
- docs/handbook/chapters/M3-repository.md
- docs/handbook/chapters/M4-board.md
- docs/handbook/chapters/M7-github.md
- docs/handbook/chapters/M9-scheduler.md
- docs/handbook/parts/I-system-arrangement.md
- docs/handbook/parts/II-flows.md
- docs/handbook/parts/IV-contract-register.md
- docs/handbook/parts/VI-failure-risk.md
- docs/handbook/parts/VII-work-derivation.md
- docs/audits/p5g03_fencing_check.py

The procedure is deterministic specification-model evidence (T3), not live
fencing evidence. The required runtime limitation remains explicit.
