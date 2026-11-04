# Verdict: CF-153

**Task:** node-create: accept and forward a ref so README step 3 can create a node for a non-main default branch
**Evaluated:** 2026-11-04T07:31:36.839082
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ node-create.sh parses a ref selection (--ref branch-or-tag, or documented NODE_REF) and forwards it to the node-side project-node.sh --ref; README.md step 3 and its --ref paragraph name the reachable remedy; tests/selftest.sh gains a numbered arm that fails on the pre-fix tree; bash tests/selftest.sh prints SELFTEST: PASS and scripts/boardctl validate prints RESULT: OK: Parsing: scripts/node-create.sh:18 `REF="${NODE_REF:-main}"` (documented NODE_REF default, header comment line 9), :63 `--ref) REF="$2"; shift 2 ;;` with the `*)` arm still exiting 2, usage string :86 carries `[--ref R]`. Forwarding: :80 `REF_QUOTED="${REF//\'/\'\\\'\'}"` and :118 payload ends `--ref '$REF_QUOTED'` into `~/node-scripts/project-node.sh`, which parses it at scripts/project-node.sh:53 and clones with `git clone --depth 1 --branch "$REF"` at :265. README: step 3 at README.md:29-31 says 'a repo whose default branch is not main: add --ref <branch-or-tag> here — node-create.sh forwards it'; the --ref paragraph at README.md:82-86 now says '`--ref <branch>` on the step 3 create command; `scripts/node-create.sh` forwards it'. Numbered arm: tests/selftest.sh:1357 `say "35. node-create accepts and forwards --ref (CF-153)"` with three assertions (staged-files --ref master rc 0 + unchanged five-file set; payload contains `--ref 'master'`; payload contains `--ref 're'\''lease'`). Pre-fix red proven: running HEAD~1 (20f93ad) node-create.sh with `--staged-files --ref master` prints `unknown arg: --ref` and exits 2, so arm 35 fails on the pre-fix tree. Test run: `bash tests/selftest.sh` exit_code 0, tail shows 'PASS  --staged-files --ref master -> exit 0, same five-file staged set', 'PASS  ref 'master' crosses the transport as --ref 'master'', 'PASS  ref 're'lease' crosses the transport as --ref 're'\''lease'', and 'SELFTEST: PASS'. Board: `bash scripts/boardctl validate` prints 'RESULT: OK (3 warning(s))' (warnings are pre-existing free-form CF-034 guard_result/ci_result rows and a headerless-board note, not failures). `bash -n scripts/node-create.sh` -> LINT_OK.
node-create.sh parses --ref/NODE_REF and forwards it escaped to project-node.sh --ref, README step 3 and the --ref paragraph name the remedy, selftest arm 35 is red on the pre-fix tree, and both `bash tests/selftest.sh` (SELFTEST: PASS, exit 0) and `scripts/boardctl validate` (RESULT: OK) pass.

## Summary

Judge Result: CF-153

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ node-create.sh parses a ref selection (--ref branch-or-tag, or documented NODE_REF) and forwards it to the node-side project-node.sh --ref; README.md step 3 and its --ref paragraph name the reachable remedy; tests/selftest.sh gains a numbered arm that fails on the pre-fix tree; bash tests/selftest.sh prints SELFTEST: PASS and scripts/boardctl validate prints RESULT: OK: Parsing: scripts/node-create.sh:18 `REF="${NODE_REF:-main}"` (documented NODE_REF default, header comment line 9), :63 `--ref) REF="$2"; shift 2 ;;` with the `*)` arm still exiting 2, usage string :86 carries `[--ref R]`. Forwarding: :80 `REF_QUOTED="${REF//\'/\'\\\'\'}"` and :118 payload ends `--ref '$REF_QUOTED'` into `~/node-scripts/project-node.sh`, which parses it at scripts/project-node.sh:53 and clones with `git clone --depth 1 --branch "$REF"` at :265. README: step 3 at README.md:29-31 says 'a repo whose default branch is not main: add --ref <branch-or-tag> here — node-create.sh forwards it'; the --ref paragraph at README.md:82-86 now says '`--ref <branch>` on the step 3 create command; `scripts/node-create.sh` forwards it'. Numbered arm: tests/selftest.sh:1357 `say "35. node-create accepts and forwards --ref (CF-153)"` with three assertions (staged-files --ref master rc 0 + unchanged five-file set; payload contains `--ref 'master'`; payload contains `--ref 're'\''lease'`). Pre-fix red proven: running HEAD~1 (20f93ad) node-create.sh with `--staged-files --ref master` prints `unknown arg: --ref` and exits 2, so arm 35 fails on the pre-fix tree. Test run: `bash tests/selftest.sh` exit_code 0, tail shows 'PASS  --staged-files --ref master -> exit 0, same five-file staged set', 'PASS  ref 'master' crosses the transport as --ref 'master'', 'PASS  ref 're'lease' crosses the transport as --ref 're'\''lease'', and 'SELFTEST: PASS'. Board: `bash scripts/boardctl validate` prints 'RESULT: OK (3 warning(s))' (warnings are pre-existing free-form CF-034 guard_result/ci_result rows and a headerless-board note, not failures). `bash -n scripts/node-create.sh` -> LINT_OK.
node-create.sh parses --ref/NODE_REF and forwards it escaped to project-node.sh --ref, README step 3 and the --ref paragraph name the remedy, selftest arm 35 is red on the pre-fix tree, and both `bash tests/selftest.sh` (SELFTEST: PASS, exit 0) and `scripts/boardctl validate` (RESULT: OK) pass.

Overall: PASS ✓
