# Foreman tick receipt — CF-097 (code-factory-2026-11-07-18-34-24)

Lane: `code-factory` (scheduler tick `code-factory-2026-11-07-18-34-24`, 2026-11-07T13:34:24-05:00).
Workdir / canonical root: `~/code-factory` (git top level matches the registered workdir; remote
`origin` = `git@github.com:coding-hermes/code-factory.git`).
Board source for selection: **origin/main (359 rows)** via `python3 scripts/board_read.py --next 10`.

## Identity, ownership and operation state (before any selection)

| Probe | Result |
|---|---|
| `git rev-parse --show-toplevel` | `~/code-factory` (not `$HOME`) |
| `python3 scripts/ownership.py status` | `state=clean`, untracked=0, lock owner `panel_supervisor` pid 3957150 |
| `python3 scripts/board_lock.py` | `RESIDUE consumers=0 commits_after_mtime=379` — a lock FILE only; no barrier, not deleted |
| `git status --porcelain -uall` | empty |
| operation markers | no `REBASE_HEAD`, `MERGE_HEAD`, `CHERRY_PICK_HEAD` |
| `git rev-list --left-right --count origin/main...HEAD` | `0 0` before the tick |
| sibling census (`GET /api/v1/projects/code-factory`, `/code-factory-ops`) | only this tick `running`; `code-factory-ops` `completed` 04:02 |

No live `gitreins`/worker writer was present in the checkout at selection time.

## Row selected

**CF-097** (P4, complexity 1) — "the CF-085 repo-url guard dropped the workdir arm's not_home_repo
check". Behaviour chapter: **III.2.2 (M2 DISPATCH, NODE SIDE — S2 resolve a target, `lane_target.py`)**.

Premise verified before dispatch (the row was live, not stale): `scripts/lane_target.py` applies
`not_home_repo` in `verify_local()` (lines 257-298) and never in `check_repo_url()` (lines 481-503).

## Reproduction, before the fix (foreman-run, hermetic `HOME`)

Fixture: `HOME` is a fresh directory that is itself an initialized git repo.

```
verify_rc=4
      "check": "not_home_repo",        # ok=false, "top level is the home directory"
repo_url_rc=0
PASS repo_url '<fixture>' — root '<fixture>' HEAD <sha>
repo_url: 0 rejected, 1 accepted
```

## The change (worker `deepseek-v4-flash` / provider `deepseek-foreman`, commit `66598c9`)

`check_repo_url()` now resolves the home exactly as `verify_local()` resolves its default
(`os.path.realpath(os.path.expanduser("~"))`) and raises `RuntimeError` when the realpath IS the home
directory; `repo_urls()` already maps `RuntimeError` to **exit 4**, so no new exit code was introduced.
Message: `not_home_repo: git top level is the home directory '<path>'`.

- `scripts/lane_target.py` +9
- `tests/test_lane_target.py` +60 — `RepoURLHomeRoot`: both arms driven with `HOME` inside the fixture,
  home-rooted repo rejected by both, non-home root still accepted, a subdirectory of the home repo still
  reported as the ordinary top-level mismatch (not the home condition).
- `tests/selftest.sh` +40 — §19 arm plus a red control that runs the pre-fix revision `a32f234`.

109 insertions, 0 deletions, 0 files outside `scripts/` + `tests/`.

## Reproduction, after the fix (same probe, and the row's own `probe` field)

```
verify_rc=4  [{"check": "not_home_repo", "ok": false, "value": "top level is the home directory"}]
repo_url_rc=4  FAIL repo_url 'local:<fixture>' — not_home_repo: git top level is the home directory '<fixture>'
```

The row's own `probe` (extracted from the committed board) prints the same pair; `probe_rc=0` is the
wrapper's status, the graded rc values are `verify_rc=4` and `repo_url_rc=4`.

## Gates at the landed commit `66598c9`

| Gate | Command | Result |
|---|---|---|
| unit | `python3 -B tests/test_lane_target.py` | `Ran 43 tests in 1.594s` / `OK`, rc 0 |
| CI-equivalent | `bash tests/selftest.sh` | `SELFTEST: PASS`, rc 0, 431 `  PASS` rows |
| new arms | §19 | `PASS  repo-url refuses the home-rooted repo verify refuses (exit 4, not_home_repo)` and `PASS  pre-fix a32f234 accepts the home-rooted repo — the repo-url arm is falsifiable` |
| board | `bash scripts/boardctl validate` | `RESULT: OK (7 warning(s))` (pre-existing legacy rows) |
| guard | pre-commit GitReins battery on the identical tree | `Tier 1 Guards: PASS (test mode: full)` |

`gh run list --repo coding-hermes/code-factory` → `[]` — this repo ships no GitHub Actions workflow; the
CI-equivalent gate is `tests/selftest.sh`, which is green.

## GitReins

| Field | Value |
|---|---|
| task | `CF-097` created + started before implementation, `task complete` after the commit |
| verdict | **PASS** |
| verdict artifact | `.gitreins/history/2026-11-07/b427397d/verdict.json` |
| envelope `task_id` | `CF-097` |
| envelope `commit` | `66598c9d33a1927cff06ad89f5c9f35418cebfdd` (exactly the implementation commit — no sibling landed mid-judge) |
| `evaluated_at` | `2026-11-07T19:31:40` |
| fingerprint | `sha256(verdict.json)` = `ad7bfdbf49f33063393378929e27df4ace8278762f451c893b6a545fa9d74df5` |

## Open items / boundaries

- **Not measured:** whether any live scheduler row currently carries a bare home `repo_url` — the row
  itself records 0 of 866 and that census was not re-run in this tick; the fix is fail-closed either way.
- **Not changed:** the `verify`/`scan` arms, the `scan --allow-remote` fail-open (CF-062) and the
  different-repository and mid-merge acceptances (CF-060, CF-061) remain separate pending rows.
- The `$HOME` meta-repo itself (`~/.git.quarantine-20261103`) was not touched.

## Trace

ch:trace row=CF-097 spec=docs/handbook/OUTLINE.md#M2-S2 wave=none:serial test=tests/selftest.sh::section-19 doc=docs/audits/code-factory-foreman-2026-11-07-CF-097.md evidence=docs/audits/code-factory-foreman-2026-11-07-CF-097.md witness=cmd:exit-4/not_home_repo verdict=PASS/b427397d commit=66598c9 memory=/project/code-factory/tick-2026-11-07-18-34-24

STATUS: complete
TIER: T3 (worker committed, gates re-run by the foreman at the landed commit, GitReins tier-2 PASS read back)
EVIDENCE: commit 66598c9, verdict b427397d (PASS), selftest 431 PASS rows, boardctl validate OK
