# CF-005 foreman verification — tick 08:47

Scheduler tick: code-factory-2026-10-30-08-47-08. Exactly one row advanced, CF-005. The project one-row contract overrode generic multi-row wave dispatch; no dependency edges on CF-005. A fresh worktree/lifecycle was used for reopened criteria, not the historical completed CF-005 verdict.

## Published implementation and independent verification

Worker implementation: c1a51ae08b97be61ab15491836cdb0fce65c8407 on wt/CF-005-REWORK-0847. Fast-forward merged to feat/code-factory-bankai-20261030; worker and target remote parity independently verified 0 ahead / 0 behind. Main was not changed by this tick. Pre-judge board/manifest evidence commit: 8fac34384a818b538fcc9bb9d11c301b26388895.

Worker session 20261030_034911_a5a859 returned exit 0. Immutable session_model_usage contained gpt-6.1-sol/openai-codex for the implementation calls and an auxiliary custom GLM-4.7-Flash entry; the latter is not claimed as a second review seat. The worker used the required model/provider. No remote node, live service, or real credential was changed.

The foreman independently ran these commands in the clean implementation worktree, then the full working-tree guard again on the merged control tree:

```bash
python3 tests/node-contract.py
python3 tests/node-mutations.py
python3 tests/node-mutations.py --baseline b2c315e
bash tests/selftest.sh
scripts/boardctl validate
git diff --check
gitreins guard --full --scope working-tree
```

Observed: 11 node tests PASS; seven semantic mutation controls PASS; four historical assertion failures and the bootstrap false-green reproduced at b2c315e; SELFTEST: PASS including the 10 existing build-policy tests. Board validation OK, 24 task rows, no canonical-key drift, one inherited headerless warning. The full guard ran secrets/lint/full tests and passed. Its working-tree secret scan used the builtin cross-check, not gitleaks; subsequent Tier-1 evaluator secret scans used both scanners and passed. Source implementation did not bypass its guard. The foreman used the repository-native hooks path only for bookkeeping after an explicit full working-tree guard, avoiding the host-global board-only degraded hook behavior.

## GitReins lifecycle and split merits evidence

Created and started CF-005-REWORK-0847 before implementation. Ran task complete after merged/publication evidence existed. Two unchanged monolithic evaluations were Tier-1 PASS but Tier-2 INCOMPLETE: 7e3cd68c (history ac359841), iteration cap 30 / used 30.1; a6185692, cap 30 / used 30.2. These remain capped history, not source merits failures and not PASS. The per-process iteration override was 30; repository policy/config was unchanged.

Following pre-solve discovery and the cap-sizing two-starvations rule, split the same six acceptance criteria into six bounded sequential ephemeral judges. No source, configuration, acceptance substance, or HEAD changed during these runs. All six returned exit 0, passed=true, criterion PASS, Tier-1 PASS, Tier-2 COMPLETE/PASS. The exact CLI output is preserved in code-factory-CF-005-split-judges-0847.json, with individual task IDs ephemeral:cf-005-rework-0847-ac1 through ac6. Evidence strings were already truncated by the CLI evidence schema; each metadata object discloses that. This is six passing per-criterion judges, not a monolithic lifecycle Tier-2 PASS.

The ephemeral evidence schema has no commit field; the enclosing artifact explicitly binds the batch to the identical published HEAD read before dispatch and after exit, 8fac34384a818b538fcc9bb9d11c301b26388895. Implementation c1a51ae is its ancestor. This is externally captured commit binding, not an invented native verdict field.

Coverage: AC1 five-spec/source agreement and explicit unimplemented boundaries; AC2 named failure/bootstrap decoy/mutation controls; AC3 pre-spawn validation and exact triple; AC4 scoped artifacts/no-follow reads/auth/digest failures; AC5 writer errors/identity/idempotence; AC6 full selftest/board/trace/source ancestry and local-only claims. Each result contains its bounded criterion and command/file evidence.

Then ran `gitreins task complete CF-005-REWORK-0847 --force --skip-tier2`: Tier-1 PASS, lifecycle complete, bookkeeping verdict c5336ce8. This is explicitly Tier-1-only bookkeeping, not the merit verdict. Completed lifecycle retained for audit.

## CI and evidence limits

Fresh `gh run list --repo coding-hermes/code-factory --limit 3 --json status,conclusion,displayTitle,headBranch,createdAt` returned []. GitHub workflows API returned total_count=0; exact pre-judge SHA check-runs total_count=0. CI is absent/unavailable, not green. No unrelated failed run existed to file. Closeout SHA CI must be queried separately after push; previous absence is not a fabricated successful run.

Hermes install/check now intentionally refuses inference_integration until CF-002 implements the authorized host-only proxy/service-identity boundary. Crier identity provisioning, pull/reply worker, gateway/result flow, authorized remote node proof, real Bunker direct-Python compatibility and actual execution placement remain open on their existing rows. Local artifacts do not prove honest remote work or secret-safe contents. No live integration or provider-key transfer is claimed.

Post-debug contribution sub_dfa46c was independently read back with matching shell-dispatch-artifact-manifest-boundary class and status complete. Skill maintenance strengthened the general debugging skill with named diagnostics, intact bootstrap dependencies, and mutation/decoy rejection; this did not alter any project source or scheduler configuration.

STATUS: complete for revised local CF-005 contract only.
TIER: T3 local invocation and observed output; six split Tier-2 merits checks passed.
EVIDENCE: code-factory-CF-005-rework-0847.md and code-factory-CF-005-split-judges-0847.json, with commands above.
