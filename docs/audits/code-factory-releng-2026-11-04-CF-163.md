# Releng audit — the public repo publishes an unrelated `master` lineage

Tick: `code-factory-duckbrain-releng-2026-11-04-04-04-40` (releng lane, code-factory-duckbrain).
Row filed: **CF-163**.
Measured: 2026-11-04T04:19Z–04:35Z (host clock 2026-11-03T23:19–23:35 -05:00) from a fresh clone of the
public remote `git@github.com:coding-hermes/code-factory.git` at published `main` = `c4fe94f`.
Transport: throwaway clone (`.coding-hermes/board` in the registered checkout was under a sibling lane's
hand at gate time), so the registered checkout was not read for state and not written.

## What was measured

| Fact | Command | Result |
|---|---|---|
| Published branches | `git for-each-ref --format='%(refname)' 'refs/heads/*'` in a fresh `--mirror` clone | **28 branches**, including `master` and 23 `readme-audit-*` branches |
| `master` shares history with main | `git merge-base --is-ancestor refs/heads/master refs/heads/main` | **exits 1** — no shared ancestry |
| `master` size | `git rev-list --count origin/master` | **772 commits** (main: 321) |
| `master` tip | `git log -1 --format='%h %s' refs/heads/master` | `4ead64f qa-cron: 2026-11-03 findings (1 new, 0 deduped)` |
| `master` tip tree | `git ls-tree --name-only refs/heads/master` | `.gitreins .hermes crier-fleet crier-interface docs get-h3 gitreins-poc h3-sdk-go-foreman h3-sdk-python-foreman monitoring pytest.ini sdk-typescript tmp worktrees` |
| `master` is live | `git log --format='%cd' --date=short origin/master \| sort \| uniq -c` | 10-29..11-02 → 19/17/15/18; **2026-11-03 → 5 commits** |

## Secret-scan arms (scope is the finding)

| Arm | Command | Commits | Findings |
|---|---|---|---|
| main only | `gitleaks detect -c .gitleaks.toml --redact --log-opts="origin/main"` | 300 | **0 — `no leaks found`** |
| all published refs | same, `--log-opts="--all"` | **1152** (57.39 MB) | **547** |
| ancestry of finding commits | `git merge-base --is-ancestor <c> HEAD` over the distinct finding commits | — | **0 on main / 64 on `master`** |

All 7 flagged files still exist at `master`'s tip, so a stranger cloning the repo today can read them:

| File at `master` tip | Hits |
|---|---|
| `monitoring/.coding-hermes/board/tasks.jsonl` | 524 |
| `.hermes/scripts/scan-git-secrets.py` (+ 2 `.bak` copies) | 15 |
| `.hermes/scripts/test_secret_scrub.py` | 3 |
| `.hermes/scripts/scan-git-secrets.py.bak-*` (2 files) | 6 / 3 |
| `monitoring/.coding-hermes/evidence/monitoring-foreman-2026-11-02-05-53-13-diskfull.json` | 1 |
| `gitreins-poc/sandbox/test_review_sample.py` | 1 |

Characterisation without printing secrets (each flagged line read from git, token-shaped runs masked):
the bulk are the secret scanner's own detection patterns and fixtures carrying `[REDACTED]` / fake
markers, i.e. false positives of its own rules. The substantive class is the two `monitoring/` files —
internal FLEET OPERATIONAL RECORDS (tick summaries, host names, alert/incident detail), not this
project's code.

GitHub posture re-measured live: `private=false`, `visibility=public`, `license=MIT`,
`secret_scanning=enabled`, `secret_scanning_push_protection=enabled`,
`secret_scanning_non_provider_patterns=disabled`, `secret_scanning_validity_checks=disabled`,
`dependabot_security_updates=disabled`, **0 open secret-scanning alerts**,
`branches/main/protection` → 404 "Branch not protected", `rulesets` → 0.

## Reproduce

The row carries the command in its `probe` field; it prints:

```
branches=refs/heads/code-factory-published refs/heads/main refs/heads/master ... (28 total)
master_refs=1
master_tip=4ead64f qa-cron: 2026-11-03 findings (1 new, 0 deduped)
master_ancestor_of_main=no
master_top_tree=.gitreins .hermes crier-fleet crier-interface docs get-h3 gitreins-poc h3-sdk-go-foreman h3-sdk-python-foreman monitoring pytest.ini sdk-typescript tmp worktrees
```

## Scope correction to the previous arm of this tick

The earlier execution of this tick recorded the arm `gitleaks detect -c .gitleaks.toml --redact` — no `--log-opts`, so no scope — as "418 commits, 8.73 MB, no leaks found"; that reading is not a scope claim, and the scoped arms in the table above follow.
That reading is reproducible only for a main-scoped scan (`--log-opts="origin/main"` → 300 commits,
0 findings at `c4fe94f`); the whole-ref scan is 1152 commits / 57.39 MB / 547 findings. A clean posture
claim therefore has to name its `--log-opts`. Recorded as acceptance criterion 3 on CF-163, and in an
append-only `audit` event — the earlier event is not rewritten.

## Not filed (reported only)

- 23 `readme-audit-*` branches are still published (one per readme-lane run). Branch hygiene, not a
  data class; folded into CF-163's branch-surface acceptance rather than a second row.
- Local-only safety tags `safety-cf-main-strand-20261103`, `safety-code-factory-align-20261101` remain
  unpublished (`git ls-remote --tags origin` = 0 refs); owned by CF-161.

## Row id

Filed as **CF-163**: the id drafted for this finding (CF-162) was consumed by a sibling lane at
`origin/main` while this tick was open (`CF-162 — P2 verify-node.sh certifies a node that cannot be
dispatched`). The row and both events were renumbered past the published maximum; a draft id is
not a reservation.
