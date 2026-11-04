# Releng lane — CF-163 AC3 landing and tree state (tick 2026-11-04-06-11-13)

Lane: `code-factory-duckbrain-releng` · tick `code-factory-duckbrain-releng-2026-11-04-06-11-13`
Host clock: 2026-11-04 01:11–01:35 -0500 · lane workdir locator `/home/kara/code-factory`

## Transport (why this tick ran from a clone)

The registered candidate `/home/kara/code-factory` is a valid, attached, marker-free `main` on
`git@github.com:coding-hermes/code-factory.git` (root/operation gate: `gate_violations=0`), but it
carries an unresolved family ownership surface:

- 53 untracked `.gitreins/history/**` verdict bundles (unpublished writer residue).
- Four sibling lanes of the same repo were live at `01:11:13` (`code-factory-docs`,
  `code-factory-duckbrain`, `code-factory-duckbrain-sync`, `code-factory-pm`) — a family-wide
  stand-down barrier.
- `.coding-hermes/board/.lock` is a 0-byte file from 2026-11-03 07:40 with **no consumer**
  (`grep -rn 'flock|fcntl' scripts/boardctl*` → no hits) and no holder (`fuser -v` → empty):
  residue (CF-119), not an ownership barrier.

Per the lane's escape hatch, the read, the gate, the posture probes and the board write ran in a
fresh clone of `origin/main` in the tick scratch dir. The candidate was never read for project
evidence, never written, never cleaned. A writer census at the candidate reported only the census
pipeline stage itself (`comm=tail`), i.e. no foreign writer inside the checkout.

## Gate (CI-equivalent — this repo has no GitHub Actions)

| head | command | result |
|---|---|---|
| `1aeb0c7` (published tip at tick start) | `bash tests/selftest.sh` | `SELFTEST: PASS`, rc=0, 103 `PASS` rows, 19 intentional-fixture `FAIL` rows |
| `5794a49` (worker commit, judged) | `bash tests/selftest.sh` | `SELFTEST: PASS`, rc=0, 106 `PASS` rows |
| `f121ed3` (merged tip, pushed) | `bash tests/selftest.sh` | `SELFTEST: PASS`, rc=0, 106 `PASS` rows |

Host loadavg during the runs: 10.2 → 28.4 → 48.6 (1-min). The gate's spawn-bound cost was not
re-measured this tick; no perf claim is made here.

`gh run list --repo coding-hermes/code-factory --limit 3` → `[]` — the documented healthy
no-Actions state, not a finding.

## Landed: CF-163 AC3 (one gitleaks claim must name its scan scope)

Commit `5794a4927f60d35e35d51bf4cc54377e6902da1f`, merged forward as `f121ed3`
(`--no-ff` so the judged commit stays an ancestor and its verdict stays commit-bound).

Four files:

| file | change |
|---|---|
| `scripts/check_scan_scope.py` | new stdlib gate: every line in `docs/audits/code-factory-releng-*.md` and `docs/SECURITY-TRIAGE.md` that mentions `gitleaks` must carry `--log-opts` on the same line; exit 1 with a named `FAIL audit-scope: <path>:<line>` row per violation, 0 clean, 2 unreadable path |
| `tests/selftest.sh` | new section 34 with three arms: green on the real tree, named red on an unscoped fixture, green once the fixture names its scope |
| `docs/audits/code-factory-releng-2026-11-04-CF-161.md` | `Secrets in history` row now records the all-refs arm (`--log-opts="--all"` → 547 findings in 64 commits, 64/64 not ancestors of `main`) beside the main-only arm (0 findings), plus a disclosed correction note |
| `docs/audits/code-factory-releng-2026-11-04-CF-163.md` | the scope-correction sentence now names that the historical arm carried no `--log-opts` |

Evidence, all re-run by the foreman at the landed tree:

| check | command | result |
|---|---|---|
| red on the pre-fix tree | `python3 scripts/check_scan_scope.py <pre-fix copies at 1aeb0c7>` | `RESULT: FAIL (2 violation(s))`, rc=1, naming `CF-161.md:25` and `CF-163.md:66` |
| green on the fixed tree | `python3 scripts/check_scan_scope.py .` | `OK  audit-scope: 3 gitleaks claim(s) name their --log-opts` / `RESULT: OK`, rc=0 |
| unreadable path | `python3 scripts/check_scan_scope.py /nonexistent` | `RESULT: FAIL (unreadable path)`, rc=2 |
| shell syntax | `bash -n tests/selftest.sh` | rc=0 |

GitReins `CF-163-L1`: tier1 `PASS` (lint/secrets/tests), tier2 `PASS` `COMPLETE`, verdict
`.gitreins/history/2026-11-04/b482884a/verdict.json`, envelope
`{task_id: CF-163-L1, commit: 5794a49…, passed: true}` — the graded commit is exactly the
implementation commit.

CF-163 itself stays **pending**: AC1/AC4/AC5 (retire the published `master` branch and disclose
what remains reachable by SHA) need the owner's decision, and no lane can take that unilaterally.

## Public posture at `f121ed3`

| item | measured | verdict |
|---|---|---|
| visibility / license | `public`, `license=MIT`, `LICENSE` present | ok |
| secret scanning | `state=open` alerts: `[]` (1 historical alert on the `master` lineage path `.hermes/scripts/test_secret_scrub.py`, resolved 2026-11-04 as a scrubber fixture) | ok |
| branch protection on `main` | `gh api …/branches/main/protection` → `Branch not protected` (404); `gh api …/rulesets` → `[]` | **defect, already filed as CF-120 (pending)** |
| published ref surface | `refs/heads/master` still at `4ead64f`: 772 commits, not an ancestor of `main`, 547 gitleaks findings on 64 commits | **defect, CF-163 (P1, owner-gated)** |
| internal endpoints | `git grep -E '100\.[0-9]+\.[0-9]+\.[0-9]+'` at `HEAD` → 0 files | ok |
| absolute host paths | `git grep -l '/home/kara'` at `HEAD` excluding `.gitreins/` → 35 tracked files (CF-050 measured 27 when filed) | drift on a pending row, noted not re-filed |
| internal host names | `git grep -liE 'karahermes|bunker-mvp|bunker-las|cube-agent'` excluding `.gitreins/` → 5 tracked files | same class as CF-050/CF-086 |

## Release

**No tag cut.** The repository has no release contract: `git tag -l` and
`ls-remote --tags` are both empty, there is no `VERSION`/`CHANGELOG`, and no version scheme in
`specs/`. That gap is already filed as **CF-161 (P3, pending)**. Tagging today would invent a
version scheme the repo has not adopted, so the releng verdict is "not due, blocked on CF-161".
`master` at `4ead64f` still has to be retired (CF-163) before any tag from `main` means what a
consumer would read it to mean.

## Not done, and why

- Candidate checkout not repaired (untracked verdict bundles left in place): publishing them is a
  sibling's `chore(gitreins)` commit, and a foreman does not adopt another lane's residue without
  an owner disposition.
- CF-161/CF-120 not implemented: both need an owner decision (adopt a version scheme; enable
  branch protection/ruleset policy) that a lane cannot take.
- The `master` branch was not deleted: CF-163 AC1 is explicitly an owner call.
