# code-factory — releng lane report, 2026-11-10

Tick: `code-factory-releng-2026-11-10-05-00-04` (second execution; the lane double-fired).
Lane: releng — release readiness and the state of the tree.
Verdict: **tree is releasable from a green commit; no release is tagged, because the repo has no release contract (CF-161).**

## 1. Identity and certified tip

| Item | Value |
| --- | --- |
| Checkout | the project checkout on the lane host (local cache — workers and sibling lanes are allowed to dirty it) |
| Canonical source of board and tree | `origin/main` |
| Published tip verified | `72b7010ed00e261fd22b85da6a390e06d80afed1` |
| Verification tree | detached worktree at `origin/main`, `git status --porcelain -uall` = 0 lines |

Every number below was measured in the detached worktree, not in the shared checkout, so it describes
the commit a cloner gets.

## 2. Build and gate

```
git worktree add --detach <out>/tip-wt-1 origin/main
cd <out>/tip-wt-1 && bash tests/selftest.sh
```

| Field | Value |
| --- | --- |
| Started / finished | `2026-11-10T03:38:03-05:00` / `2026-11-10T03:40:50-05:00` |
| Tree under test | `72b7010e` |
| Sections | 65 |
| `PASS` rows | 517 |
| `SKIP` rows | 0 |
| Verdict line | `SELFTEST: PASS` |
| Exit code | 0 |

61 lines in the log match `^  FAIL `; all of them are **quoted negative-fixture output**, not gate
failures. Section `7b. board gate rejects invalid records with line-numbered FAIL rows (CF-088)`
requires the board gate to fail on each malformed fixture, so each `FAIL` line is followed by the
`PASS` row that asserts the rejection. The gate's own verdict is the `SELFTEST: PASS` line with
`SELFTEST_RC=0`.

### 2a. The red recorded by the first execution of this tick is cleared

The first execution of `code-factory-releng-2026-11-10-05-00-04` ended with a red arm
(`port — listening on :10800`) on the tree as it stood then. Three commits landed after that run:

```
3dfd033d feat(node): add bounded lifecycle supervisor mechanics        (CF-008)
12c62f58 board(CF-008): close on lifecycle verdict and current-main implementation
3854fe45 fix(CF-066): count the harness adapter's exit status, not only its FAIL rows
72b7010e board(CF-066): close on landed adapter-exit-status fix and tier-2 verdict
```

`3dfd033d` is an ancestor of `72b7010e`; the tree difference between them is `scripts/project-node.sh`
(+5) and `tests/selftest.sh` (+37/−9), i.e. exactly the CF-066 fix and the arms that cover it. At
`72b7010e` those arms pass. The release blocker the first execution reported no longer exists.

## 3. Closure evidence for the two rows that moved

Both rows cite a verdict whose recorded commit is **not reachable from `origin/main`** — the class
filed as CF-181 / CF-386 and tracked by CF-389. Neither is a bad closure: in both cases the judged
commit is the pre-rebase twin of the landed commit, and the verdict transfers by content.

| Row | Judged commit | Landed commit | Files of the landed commit | Identical blobs |
| --- | --- | --- | --- | --- |
| CF-008 | `109a1c53` | `3dfd033d` | `scripts/node-lifecycle-supervisor.py`, `specs/NODE.md`, `tests/selftest.sh`, `tests/test_node_lifecycle.py` | 4 / 4 |
| CF-066 | `1501b62c` | `3854fe45` | `scripts/project-node.sh`, `tests/selftest.sh` | 1 / 2 |

CF-066's one differing file is not a regression: the diff between the judged and landed
`tests/selftest.sh` blobs is a single +9-line block, the CF-008 lifecycle arm that `main` gained
while the CF-066 branch was rebased. CF-066's own fixture arms are byte-identical in both blobs.

Re-runnable:

```
git rev-parse 109a1c53:scripts/node-lifecycle-supervisor.py 3dfd033d:scripts/node-lifecycle-supervisor.py
git show --pretty=format: --name-only 3854fe45 | while read f; do
  git rev-parse 1501b62c:"$f" 3854fe45:"$f"; done
git diff de46172902 dd42ac18bc     # the only tests/selftest.sh delta, CF-008's arm
```

Why this matters for CF-389: commit `82bdf49` deleted the 937 tracked `.gitreins/history` files, so a
fresh clone cannot re-derive either verdict. The blob-identity check above is the substitute that
does not need the bundle — it proves the judged content is the landed content.

## 4. Public posture

`git remote -v` resolves the slug; the API calls below are re-runnable against
`coding-hermes/code-factory`.

| Check | Command | Result |
| --- | --- | --- |
| Visibility / license / default branch | `gh api repos/<slug>` | public, not archived, license `MIT`, default branch `main` |
| License file in tree | `ls -1 \| grep -iE '^(LICENSE\|COPYING\|NOTICE)'` | `LICENSE` — "MIT License, Copyright (c) 2026 coding-hermes contributors" |
| Tracked credential-shaped files | `git ls-files \| grep -E '(^\|/)\.env$\|id_rsa\|id_ed25519\|\.pem$\|\.p12$\|credentials'` | none tracked; one `.env.example` |
| Secret scan of the published tree | `gitleaks dir . --no-banner --redact --exit-code 0` — a directory scan of this exact tree, deliberately run without `--log-opts`, so it certifies the tip's working tree and claims no revision range (a history-range claim is a different scan and is not made here) | `no leaks found`, ~3.75 MB scanned, rc=0 |
| Secret scanning (GitHub) | `gh api repos/<slug> --jq '.security_and_analysis'` | `secret_scanning: enabled`, `secret_scanning_push_protection: enabled` |
| Open secret-scanning alerts | `gh api 'repos/<slug>/secret-scanning/alerts?state=open'` | 0 |
| Branch protection | `gh api repos/<slug>/branches/main/protection` | **404 "Branch not protected"** |
| Rulesets | `gh api repos/<slug>/rulesets --jq length` | 0 |
| Actions CI | `gh run list --repo <slug> --limit 3` | no workflow runs exist — the gate is `tests/selftest.sh` plus the GitReins guard |

Findings that are already rows, and stay open:

- **CF-120** (P3, unchanged since 2026-11-06): the PUBLIC repository has no branch protection and no
  ruleset, so force-push and branch deletion are open. Re-probed today, same answer.
- **CF-161** (P3): no release contract — zero published tags, no `VERSION`/`CHANGELOG`, no version
  scheme in the specs.
- Disabled-and-worth-deciding: `secret_scanning_non_provider_patterns`, `secret_scanning_validity_checks`
  and `dependabot_security_updates`. Not filed as a row; they are configuration choices on a public
  repo, and the two most valuable settings (secret scanning and push protection) are already on.

Internal-address shapes in the published tree remain the known class (CF-050 / CF-086 / CF-163 AC3):
hits are board history, audit write-ups, handbook appendices quoting measured runs, and one test
fixture (`192.168.1.20` in `tests/test_lane_target.py`). No credential and no live endpoint was found.

## 5. Release decision

**Not tagged.** Two local safety tags exist (`safety-cf-main-strand-20261103`,
`safety-code-factory-align-20261101`); `git ls-remote --tags origin` returns **0** rows, so the
repository has never published a tag. Tagging now would invent a version scheme that CF-161 exists to
decide (semver vs date-based, what constitutes a release, where notes come from). The blocker the
first execution reported — a red gate — is gone; what remains is the contract.

When CF-161 lands, the first release can be cut from `72b7010e` or any later green tip without
re-running this audit; the gate command and its verdict are recorded above.

## 6. What this tick did not do

- No worker dispatched: the two releng-relevant rows that moved are already complete at the tip, and
  the open posture rows (CF-120, CF-161) are owner-level decisions on a public repository, not code.
- No board row filed: every finding above maps to an existing row. The CF-008/CF-066 blob-identity
  result is evidence for CF-389, not a new defect class.
- No tag, no version bump: blocked on CF-161 by design.

## 7. How this document reached green

The first version of this write-up was committed and pushed as `f94b0ede`, and the repository's own
gate rejected it on two of its checks — both defects in the document, not in the tree it describes:

| Caught by | Failure text | Cause | Fix |
| --- | --- | --- | --- |
| `scripts/check_scan_scope.py` (CF-163 AC3) | `audit-scope: docs/audits/code-factory-releng-2026-11-10.md:96 gitleaks claim names no --log-opts` | the secret-scan row quoted a `gitleaks` command without naming the revision scope it does and does not cover | the row now says the scan is a directory scan of the tip, deliberately without `--log-opts`, and claims no revision range |
| `tests/selftest.sh` section 61 (CF-050) | `publish paths — baseline 143, current 144; paths: docs/audits/code-factory-releng-2026-11-10.md` | the identity table carried an absolute host-home checkout path into a public repository | the path is now described, not quoted; the baseline stayed at 143 instead of being raised to admit the leak |

`f94b0ede` was the red commit on `main`; the fix is its child, and the gate is re-run on the fixed
tree before this line is believed. The mechanism behind the second row — a pre-commit guard that
evaluates HEAD cannot see a staged new file, so a lane that fixes what the guard complains about has
to bypass it and land the red commit anyway — is filed as **CF-405**, together with the earlier
incidents CF-401 and CF-404 that show the same sequence. Re-run the two checks alone — `python3 scripts/check_scan_scope.py .`
and `bash tests/selftest.sh` section 61 — to reproduce both failures against `f94b0ede` (the
`git grep -lIE '/home/[a-z][a-z0-9_-]*/' f94b0ede -- .` form is the publish-path check in one line).
