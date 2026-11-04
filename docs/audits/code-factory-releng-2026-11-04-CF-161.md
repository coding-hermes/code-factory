# code-factory — releng audit (CF-161): the release surface has no contract

Measured by the releng lane (tick `code-factory-duckbrain-releng-2026-11-04-04-04-40`) from a
throwaway clone of the published ref, not from the registered checkout. Re-measure every number
with the command beside it before quoting it in a later tick.

## Why the clone

The registered checkout `/home/kara/code-factory` passed the root/remote/operation gate (realpath ==
`git rev-parse --show-toplevel`, remote `git@github.com:coding-hermes/code-factory.git`, attached
`main`, no rebase/merge markers), but carried three ownership surfaces at gate time (2026-11-03
23:06 local): one unstaged tracked edit (`docs/ACCEPTANCE-PLAN.md`, +7, the sync lane's in-flight
delta), 53 untracked `.gitreins/history/**` bundle files, and a co-running family lane. Per the
lane's clone transport the canonical checkout was **not** read for state beyond the gate, not
written, and not cleaned.

## Gate

| Check | Command | Result |
|---|---|---|
| Selftest (CI-equivalent; repo has no GitHub Actions) | `bash tests/selftest.sh` | `SELFTEST: PASS`, rc=0, 103 `PASS` rows, 19 `FAIL` rows — every `FAIL` is an intentional negative fixture (board-parser malformed/stale rows ×18, `disk_floor` resolver-removal arm ×1) |
| Board validity | `bash scripts/boardctl validate` | `RESULT: OK (3 warning(s))` — CF-034's two free-form fields + the headerless board, both pre-existing |
| Board census | `wc -l`, `jq -r .id \| sort \| uniq -d` | 134 rows before this row, 0 duplicate ids, 45 `complete` / 6 `in_progress` / 83 `pending` |
| GitHub Actions | `gh run list --repo coding-hermes/code-factory --limit 3` | `[]` — documented healthy no-Actions state, nothing to flag |
| Secrets in history | `gitleaks detect -c .gitleaks.toml --redact --log-opts="--all"` | 547 findings in 64 commits, all 64 not ancestors of main; the `--log-opts="origin/main"` arm reports 0 findings |

> Correction (CF-163 AC3): the original arm above recorded no `--log-opts`, so the number it
> printed (418 commits, 8.73 MB) is not reproducible as a scope. Re-measured by the releng tick at
> `main` = `1aeb0c7` (2026-11-04) with the two arms above (`--log-opts="--all"` → the 547 findings
> cell above; `--log-opts="origin/main"` → 0 findings). The row that owns the rule is **CF-163** (AC3).

## Public posture

| Item | Measured | Verdict |
|---|---|---|
| Visibility / license | `private=false`, `visibility=public`, `license=MIT`, `LICENSE` present | ok |
| Secret scanning / push protection | both `enabled` | ok |
| Non-provider patterns / validity checks / dependabot security updates | `disabled` ×3 | recorded, unchanged, no row |
| Open secret-scanning alerts | **0** (`state=open` → length 0); alert #1 `resolved` at 2026-11-04T03:41:09Z, resolution `used_in_tests` | CF-156 verified closed live |
| Branch protection | `branches/main/protection` → 404 "Branch not protected"; `rulesets` → `[]` | unchanged, owned by CF-120 |
| Absolute host paths in tracked files | 954 hits / 230 files at this tip (was 654/179 one tick earlier, 27/102 at filing) | drift, owned by CF-050 / CF-086 — re-measured, not re-filed |
| Internal endpoints | one private-IP hit, a test fixture (`tests/test_lane_target.py:148`, `192.168.1.20`) | ok |

## Release surface (the finding)

| Item | Command | Result |
|---|---|---|
| Published tags | `git ls-remote --tags git@github.com:coding-hermes/code-factory.git` | **0 refs** |
| Tags visible to a stranger | `git clone --bare <github url> /tmp/ghbare.git; git -C /tmp/ghbare.git tag -l` | **0** |
| Tags visible locally | `git tag -l` in the checkout | 2: `safety-cf-main-strand-20261103` → `6598ec3`, `safety-code-factory-align-20261101` → `e270fb3`; **neither is an ancestor of `main`** |
| Version files | `ls VERSION CHANGELOG*` | absent |
| Version scheme | `git grep -In -i 'release\|version' -- specs` | no scheme; hits are `env_version` (a wire field) and prose |
| Open work at this tip | board census | 5 open P0 (1 `in_progress`), 9 open P1 (3 `in_progress`) |

Nothing was tagged: a tree carrying in-flight P0 rows and no release contract cannot source a first
release. Row **CF-161** (filed, P3) asks for the contract and the coherent tag surface, with an
owner decision on the scheme.

## Rows

Filed: **CF-161** — P3, the repo has no release contract. Not re-filed, re-measured instead:
CF-050 / CF-086 (absolute host paths, now 954/230), CF-120 (no branch protection), CF-156 (already
closed; alert verified resolved).

## Environment

Load average `9.07 8.84 8.23` during the gate run; clone at `origin/main`, parity `0 0` before the
row was appended. The published tip moved under this tick (`79e9b59` → `103464d`, three sync-lane
commits), so the row was re-created against the new tip and the gate re-run there.
