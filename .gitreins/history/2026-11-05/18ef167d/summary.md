# Verdict: CF-206-OPS3

**Task:** CF-206 implementation verification: shell-toolkit classification + committed patch + 10-arm harness + gates (closure is not graded)
**Evaluated:** 2026-11-05T00:32:26.119105
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Implement CF-206: the fleet ops census must stop classifying a manifest-less shell toolkit as `docs`. Grade the IMPLEMENTATION only — the board row's closure is recorded by the foreman AFTER this verdict and is explicitly NOT part of this task (it cannot be: the board refuses a completion without a verdict run id, so grading closure here is circular).

(a) LIVE CLASSIFIER. From /home/kara/code-factory run `python3 ~/.hermes/scripts/fleet_ops_check.py --project code-factory --json | jq -r '.[0].kind'` — it must print `cli` (it printed `docs` before this change), and `... | jq -r '.[0].evidence.kind_basis'` must start with `shell-toolkit:`.

(b) COMMITTED PATCH. `patches/fleet-ops-shell-toolkit.patch` exists at HEAD (dc9e0ea) with sha256 f7f1dfc36b15f7ba18d28cfc0c549d16b28145df56b5dcf0a4fba8413042cf93. It is a diff against the PRISTINE pre-fix script, so it is re-verified in reverse against the now-patched live file: `cd ~/.hermes/scripts && git apply --check --reverse /home/kara/code-factory/patches/fleet-ops-shell-toolkit.patch` succeeds, and forward-applying it to a copy of the pristine script (`git apply --check`) also succeeds.

(c) REGRESSION ARMS. `python3 patches/fleet-ops-shell-toolkit.test.py` prints RESULT: PASS (10/10 arms) and exits 0. The arms cover: a manifest-less tree with only docs/*.md and no scripts still classifies `docs`; go.mod plus cmd/ still classifies `cli`; package.json plus a Dockerfile still classifies `service`; a two-script toolkit classifies `cli` with basis `shell-toolkit:2`; a git repo whose scripts are untracked still classifies `docs`; one script with no tests/selftest.sh stays `docs`; and census exit semantics are unchanged (rc=0 when no family has a gap, rc=1 when one does).

(d) GATES at HEAD: `bash scripts/boardctl validate` answers RESULT: OK and `bash tests/selftest.sh` prints SELFTEST: PASS.

Do NOT require any fleet count to equal a literal value, and do NOT require CF-206 to already read status=complete — that closure is the foreman's next action, recorded with this verdict's run id as its evidence pointer.: (a) Ran from /home/kara/code-factory: `python3 ~/.hermes/scripts/fleet_ops_check.py --project code-factory --json | jq -r '.[0].kind'` printed `cli`, and the same pipeline for .evidence.kind_basis printed `shell-toolkit:8` (starts with `shell-toolkit:`); exit_code=0. (b) sha256sum patches/fleet-ops-shell-toolkit.patch = f7f1dfc36b15f7ba18d28cfc0c549d16b28145df56b5dcf0a4fba8413042cf93 (exact match); `git log -1 -- patches/fleet-ops-shell-toolkit.patch` shows it committed at HEAD dc9e0ea; `cd ~/.hermes/scripts && git apply --check --reverse <patch>` exit 0 (REVERSE_CHECK: OK); reconstructed the pristine script by reverse-applying in a temp git repo (/tmp/pristine_check), then `git apply --check <patch>` against that pristine copy exit 0 (FORWARD_CHECK_OK_ON_PRISTINE), and forward-applying reproduced a file byte-identical to the live patched script (diff clean). (c) `python3 patches/fleet-ops-shell-toolkit.test.py` exit_code=0, printed `RESULT: PASS (10/10 arms)`; arms confirm: A docs-tree→docs, B go.mod+cmd→cli, C package.json+Dockerfile→service, D two-script toolkit→cli with `kind_basis=shell-toolkit:2`, E untracked-scripts git repo→docs, F one script with no gate→docs, I uppercase docs/OPERATIONS.md→gap=[], G rc=0 when no family has a gap, H rc=1 with gaps=['deploy-doc']; the harness loads the live ~/.hermes/scripts/fleet_ops_check.py under test via importlib (test.py lines 40, 52). (d) `bash scripts/boardctl validate` printed `RESULT: OK (4 warning(s))` exit 0 (warnings advisory, legacy-duplicate/free-form notes on pre-existing rows); `bash tests/selftest.sh` (the guards.test_command in .gitreins/config.yaml) printed final line `SELFTEST: PASS` exit 0. Closure status of CF-206 intentionally not required per the task text.
All four legs verified with live command output: the census now reports kind=cli with basis shell-toolkit:8, the committed patch at dc9e0ea has the exact required sha256 and round-trips (reverse-check against the patched live script OK, forward-check against a reconstructed pristine copy OK), the 10-arm regression harness passes 10/10 with exit 0 covering every required arm, and both gates (boardctl validate RESULT: OK, selftest SELFTEST: PASS) pass at HEAD.

## Summary

Judge Result: CF-206-OPS3

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Implement CF-206: the fleet ops census must stop classifying a manifest-less shell toolkit as `docs`. Grade the IMPLEMENTATION only — the board row's closure is recorded by the foreman AFTER this verdict and is explicitly NOT part of this task (it cannot be: the board refuses a completion without a verdict run id, so grading closure here is circular).

(a) LIVE CLASSIFIER. From /home/kara/code-factory run `python3 ~/.hermes/scripts/fleet_ops_check.py --project code-factory --json | jq -r '.[0].kind'` — it must print `cli` (it printed `docs` before this change), and `... | jq -r '.[0].evidence.kind_basis'` must start with `shell-toolkit:`.

(b) COMMITTED PATCH. `patches/fleet-ops-shell-toolkit.patch` exists at HEAD (dc9e0ea) with sha256 f7f1dfc36b15f7ba18d28cfc0c549d16b28145df56b5dcf0a4fba8413042cf93. It is a diff against the PRISTINE pre-fix script, so it is re-verified in reverse against the now-patched live file: `cd ~/.hermes/scripts && git apply --check --reverse /home/kara/code-factory/patches/fleet-ops-shell-toolkit.patch` succeeds, and forward-applying it to a copy of the pristine script (`git apply --check`) also succeeds.

(c) REGRESSION ARMS. `python3 patches/fleet-ops-shell-toolkit.test.py` prints RESULT: PASS (10/10 arms) and exits 0. The arms cover: a manifest-less tree with only docs/*.md and no scripts still classifies `docs`; go.mod plus cmd/ still classifies `cli`; package.json plus a Dockerfile still classifies `service`; a two-script toolkit classifies `cli` with basis `shell-toolkit:2`; a git repo whose scripts are untracked still classifies `docs`; one script with no tests/selftest.sh stays `docs`; and census exit semantics are unchanged (rc=0 when no family has a gap, rc=1 when one does).

(d) GATES at HEAD: `bash scripts/boardctl validate` answers RESULT: OK and `bash tests/selftest.sh` prints SELFTEST: PASS.

Do NOT require any fleet count to equal a literal value, and do NOT require CF-206 to already read status=complete — that closure is the foreman's next action, recorded with this verdict's run id as its evidence pointer.: (a) Ran from /home/kara/code-factory: `python3 ~/.hermes/scripts/fleet_ops_check.py --project code-factory --json | jq -r '.[0].kind'` printed `cli`, and the same pipeline for .evidence.kind_basis printed `shell-toolkit:8` (starts with `shell-toolkit:`); exit_code=0. (b) sha256sum patches/fleet-ops-shell-toolkit.patch = f7f1dfc36b15f7ba18d28cfc0c549d16b28145df56b5dcf0a4fba8413042cf93 (exact match); `git log -1 -- patches/fleet-ops-shell-toolkit.patch` shows it committed at HEAD dc9e0ea; `cd ~/.hermes/scripts && git apply --check --reverse <patch>` exit 0 (REVERSE_CHECK: OK); reconstructed the pristine script by reverse-applying in a temp git repo (/tmp/pristine_check), then `git apply --check <patch>` against that pristine copy exit 0 (FORWARD_CHECK_OK_ON_PRISTINE), and forward-applying reproduced a file byte-identical to the live patched script (diff clean). (c) `python3 patches/fleet-ops-shell-toolkit.test.py` exit_code=0, printed `RESULT: PASS (10/10 arms)`; arms confirm: A docs-tree→docs, B go.mod+cmd→cli, C package.json+Dockerfile→service, D two-script toolkit→cli with `kind_basis=shell-toolkit:2`, E untracked-scripts git repo→docs, F one script with no gate→docs, I uppercase docs/OPERATIONS.md→gap=[], G rc=0 when no family has a gap, H rc=1 with gaps=['deploy-doc']; the harness loads the live ~/.hermes/scripts/fleet_ops_check.py under test via importlib (test.py lines 40, 52). (d) `bash scripts/boardctl validate` printed `RESULT: OK (4 warning(s))` exit 0 (warnings advisory, legacy-duplicate/free-form notes on pre-existing rows); `bash tests/selftest.sh` (the guards.test_command in .gitreins/config.yaml) printed final line `SELFTEST: PASS` exit 0. Closure status of CF-206 intentionally not required per the task text.
All four legs verified with live command output: the census now reports kind=cli with basis shell-toolkit:8, the committed patch at dc9e0ea has the exact required sha256 and round-trips (reverse-check against the patched live script OK, forward-check against a reconstructed pristine copy OK), the 10-arm regression harness passes 10/10 with exit 0 covering every required arm, and both gates (boardctl validate RESULT: OK, selftest SELFTEST: PASS) pass at HEAD.

Overall: PASS ✓
