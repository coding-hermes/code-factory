# CF-544 verification-only closeout — 2026-11-26

Tick: code-factory-foreman-2026-11-26-06-37-45
Implementation commit (already landed): `4c192f78cd050021ce66672a3c12171e02d0697d`
  ("fix(handbook): single-source the claim ordering rule — chapter §15.2 wins,
  CV-04 vectors re-literal'd and re-digested. Addresses CF-544.")
Verified against: origin/main == 4c192f78 (fast-forward parity 0 at tick start).
Battery run in detached worktrees `~/.hermes/cache/scratch/cf544-closeout`
(4c192f78) and `.../cf544-parent` (4c192f78^). This artifact is the witness; the
canonical checkout stayed byte-clean.

## AC1 — one ordering rule chosen, recorded in the commit message
- `grep -c 'priority DESC, created_seq ASC, id ASC' docs/handbook/chapters/M4-board.md docs/handbook/contract-vectors.json`
  → both `0` (SAME rule on both surfaces: the priority-first literal is gone from both).
- `grep -n 'The ordering does not include priority' docs/handbook/chapters/M4-board.md`
  → `664:` present, agreeing with the chosen chapter rule.
- Ruling recorded in commit 4c192f78's message with implementation citations
  (schema const `cf2a.board-claim.schema.json:34`, CV-19-A, claim broker has zero
  priority ranking, `board_read.py:100` is presentation-only).
- EXIT 0.

## AC2 — changed vectors' digests recompute
- `PYTHONDONTWRITEBYTECODE=1 python3 -B tests/test_claim_ordering_consistency.py`
  → `PASS claim ordering is single-sourced: schema const, CV-04/CV-19 vectors,
  digests and M4 §15.2 all state the chosen rule (created_seq ASC, id ASC;
  priority excluded)`, rc=0. The checker recomputes the CV-04-A `claim_request_sha256`
  (`e343027f6bae…`) and CV-04-D `canonical_sha256` (`73327df68f96…`) from the
  canonical JSON per the file's canonicalization header.
- EXIT 0.

## AC3 — consistency arm is red-provable and wired into selftest
- Red control (checker pointed at a fixture chapter with §15.2 reverted to the
  priority-first rule): `FAIL claim-ordering surfaces disagree: M4-board.md §15.2 vs
  cf2a.board-claim.schema.json const / CV-04 vectors: the priority-exclusion
  sentence is gone or reworded`, rc=1 — names BOTH surfaces.
- `tests/selftest.sh` carries the arm UNNUMBERED (CF-198 census ignores unnumbered
  blocks) at selftest.sh:9400–9426, green arm + reverted-chapter red control.
- `bash tests/selftest.sh` at 4c192f78: `SELFTEST: PASS`, `EXIT=0`; CF-544 arms:
  `PASS schema const, CV-04-A/CV-04-D canonical digests and M4 §15.2 all state …`
  and `PASS reverted-chapter control: …`.
- FAIL-ARM parity vs parent: sorted `FAIL` arm sets at 4c192f78 and 4c192f78^ are
  IDENTICAL after normalizing run-specific SHAs/tmpdir names (diff empty).
  All FAIL lines are the selftest's own fixture negative-controls (validator
  refusal arms) plus the KNOWN host-condition red present at BOTH commits:
  `gateway_start — refused: a public bind needs dashboard.basic_auth in
  ~/.hermes/config.yaml — block absent` — disclosed, not asserted green, exactly
  as AC3 anticipates ("a host-condition red at both is disclosed").
- Parent selftest: `SELFTEST: PASS`, `EXIT=0`, zero CF-544 lines (arms absent pre-fix).

## AC4 — single-sourced rule
- `grep -rn -E 'priority DESC|created_seq, task_id|ordering does not include priority' docs/handbook specs`
  (dated quorum transcripts under docs/handbook/_quorum-*/ excluded by name):
  only `docs/handbook/chapters/M4-board.md:663,664,686` — all the chosen rule.
  No other normative surface states a different claim ordering. EXIT 0.

## AC5 — CF-426 handoff (external leg, not this row's worker)
AC5 states it is "a handoff condition for the CF-426 lane, not work for this row's
worker." Classified external/handoff: the P5G-10 re-judge belongs to the CF-426 lane.
This close does not claim it.

## Judge round 1 (run 01c3485d, graded b68d5c1e): real finding — fixed this tick
The tier-2 judge graded all four registered criteria PASS with quoted replays, but
derived a REAL defect beyond the literal ACs: the checker reconciled only top-level
`ordering` and the embedded canonical bodies, while CV-19-A carries the normative
literal nested at `group_claim.ordering` (contract-vectors.json:2412). Judge's
mutation probe: reintroducing priority-first there still printed PASS (blind spot).
Fix (this tick): tests/test_claim_ordering_consistency.py now also refuses any
`group_claim.ordering` != schema const, and the selftest CF-544 arm gained a nested
red control. Probe results: green rc=0; nested control rc=1 naming
`contract-vectors.json CV-19-A.group_claim.ordering vs cf2a.board-claim.schema.json
const`; reverted-chapter control still rc=1. The judge's tier1 `tests` red in its
own run (selftest FAIL (52)) was environmental — the same tree printed
`SELFTEST: PASS / EXIT=0` in this tick's two clean full runs (see AC3), and the
judge itself called those 52 arms "unrelated pre-existing host/environment".

## Verdict binding (gitreins lifecycle)
- gitreins task create/start CF-544 with the row's acceptance registered as criteria.
- Verdict artifact: .gitreins/history/<date>/<run>/verdict.json (path + graded commit
  recorded on the board row via --evidence-run-id / --commit-hash).
- Note: .gitreins/history/ is git-untracked in this repo by convention; the verdict
  fields are quoted on the board row and the run dir is resolvable by
  scripts/board_evidence_check.py, which is this repo's sanctioned resolver.
