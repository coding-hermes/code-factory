# RELENG — clean-checkout gate is green; two public-posture findings; no release due

Tick: `code-factory-releng-2026-11-03-11-39-44`. Lane: code-factory / releng.
Measured on a fresh clone: `git clone git@github.com:coding-hermes/code-factory.git`,
checked out at `e1e4bed274f8654324a6779ae6d131aad4db0339` (origin/main), working tree clean
(`git status --porcelain` = 0 lines). The canonical checkout `~/code-factory` is still detached
at `cc0a1e4` behind an interrupted rebase (`.git/rebase-merge` since 2026-10-30 14:03) and was
not touched by this tick, so the lane did its work from the clone.

## Gate

| Check | Command | Result |
|---|---|---|
| Tree identity | `git rev-parse HEAD` | `e1e4bed274f8654324a6779ae6d131aad4db0339` |
| Clean tree | `git status --porcelain \| wc -l` | `0` |
| Selftest | `bash tests/selftest.sh` | exit **0**, `SELFTEST: PASS` |
| Runtime | same, wall clock | **0.686 s** (host: 15 s warm) |
| Board parse | selftest section 7 | `PASS 32/32 rows parse` |
| Build | — | the repo ships no build target; selftest is the gate |

## Not verified (stated, not implied green)

- **No release was tagged.** The repository has zero tags (`git tag` empty) and no version file or
  CHANGELOG, the default-branch board still has P0 row `CF-005` in progress (node specs + installer
  scripts), and 15 rows are `pending`. A first tag would name a half-built factory, so releng did
  not create one. When the project wants versioning, the tag has to come from a green commit plus a
  version source; neither exists yet.
- **No CI to report.** `gh run list --repo coding-hermes/code-factory --limit 3` returns `[]` and
  `.github/workflows` is absent. That is the documented state for this repo: the gate is
  `tests/selftest.sh` plus the local GitReins guard, not Actions.

## Public posture

| Item | State | Command |
|---|---|---|
| Visibility | public, not archived | `gh api repos/coding-hermes/code-factory --jq .visibility` |
| License | MIT, `LICENSE` at root | `gh api … --jq .license.spdx_id` |
| Secret scanning | enabled | `gh api … --jq .security_and_analysis` |
| Push protection | enabled | same |
| Non-provider patterns | **disabled** | same |
| Validity checks | **disabled** | same |
| Dependabot security updates | **disabled** | same |
| Branch protection on `main` | **absent** (`Branch not protected`, 404) | `gh api repos/…/branches/main/protection` |
| Credential shapes in tree | 0 hits | `git grep -IE '(ghp_\|github_pat_\|sk-\|AKIA\|xoxb-\|BEGIN [A-Z ]*PRIVATE KEY)' HEAD` |

Unprotected `main` is recorded, not filed as a row: the owner's standing practice for these
repositories is direct fast-forward pushes from lanes, and this very tick lands board rows that
way. If that practice changes, protection plus a required status check becomes a decision, not a
mechanical fix. Non-provider-pattern scanning and Dependabot are off; both are cheap to enable and
neither was changed here (owner-scoped repository settings).

## Finding filed as CF-050 — the published tree carries absolute host paths

Measured at `e1e4bed2`, clean tree:

```sh
git grep -lIE '/home/[a-z][a-z0-9_-]*/' HEAD            # 27 files
git grep -nIE '/home/[a-z][a-z0-9_-]*/' HEAD | wc -l    # 102 hits
git grep -nIE '/home/[a-z][a-z0-9_-]*/' HEAD -- . ':(exclude).gitreins' | wc -l   # 45
```

Distribution of the 27 files: 17 under `.gitreins/history/` (`verdict.json`, `commit.patch`,
`summary.md` from judge runs, which record absolute `guard_log` worktree paths), 8 under
`docs/audits/` (committed audit logs and `.probe.txt` transcripts), 2 board files.
`.gitignore` excludes `.gitreins/logs/`, `verdicts/`, `tasks.yaml`, `usage.jsonl` — but not
`.gitreins/history/`, so the `chore(gitreins)` commits publish a growing corpus of host layout to a
public repository. No gate notices: `tests/selftest.sh` item 6 checks literal credential
assignments, and the string `absolute` does not appear in that file.

This is layout exposure, not a secret leak: credential-shaped scan is 0 hits and push protection is
on. Neither this document nor the filed rows add a new absolute path — they use `~/` and
`/home/<user>/` placeholders.

## Finding filed as CF-049 — the canonical checkout blocks every lane that resolves to it

`.git/rebase-merge` at `~/code-factory`: `head-name=refs/heads/main`, `onto=3ebf9f06`,
`stopped-sha=f69f5b6f`, `msgnum=1` of `end=29`, mtime 2026-10-30T14:03:34-05:00; HEAD detached at
`cc0a1e47`; 10 porcelain paths (`M` board `tasks.jsonl`/`events.jsonl`, untracked
`.coding-hermes/board/.lock`, `.gitreins/history/`, 5 `docs/audits/*readme*` files,
`scripts/__pycache__/`). The `~/proj-wt-code-factory-*` worktree family shares the same common git
dir, so no sibling checkout substitutes.

Remote work is not blocked — origin/main advanced today and the gate is green from a clone — so the
cost is confined to lanes whose registered workdir resolves to that root, and it is paid every
tick: this lane alone has produced blocked receipts for the same barrier on 2026-11-02 and again at
09:56, 10:25 and 11:39 today. The row asks for one of two decisions: owner-authorized
abort/continue, or explicit retirement of the root with a named replacement.

## Reproduction

Run in any clean clone; no host state required beyond `git`, `bash`, `jq`, `gh`:

```sh
git clone git@github.com:coding-hermes/code-factory.git cf && cd cf
git rev-parse HEAD                     # e1e4bed274f8654324a6779ae6d131aad4db0339 at time of writing
bash tests/selftest.sh                 # exit 0, SELFTEST: PASS
git grep -lIE '/home/[a-z][a-z0-9_-]*/' HEAD | wc -l
gh api repos/coding-hermes/code-factory/branches/main/protection   # 404 Branch not protected
gh run list --repo coding-hermes/code-factory --limit 3 --json status,conclusion   # []
```
