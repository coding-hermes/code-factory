# CF-524 acceptance arm re-measurement at the published tip

Tick: code-factory-ops-2026-11-25-15-43-57 (ops lane, isolated worktree at
a3b5f9ab, no shared-checkout reads).
Command and output, measured 2026-11-25T15:50:35Z in a detached worktree at
the published tip a3b5f9ab83e0cd0a16ef1eea4098dd7dda03bcde:

    ruff --version
    ruff 0.15.22                (rc=0 — the version tests/selftest.sh section 51 pins)

    ruff format --check .
    114 files already formatted
    rc=0                        (arm 1: N=114 >= 105 — met)

    ruff check .
    All checks passed!
    rc=0                        (arm 2: formatter-only repair added no E/F finding — met)

    git merge-base --is-ancestor eea18527af166a1cb8defb393a0267022bee74ac HEAD
    eea18527 is an ancestor of a3b5f9ab: yes
                                (the CF-524 one-file repair landed 2026-11-22 17:47 -05)

Tier-1 lint leg at the same tip (arm 4): gitreins run id 60367bb4 (task CF-531,
graded commit a3b5f9ab, evaluated 2026-11-25T15:48:45, verdict at
.gitreins/history/2026-11-25/60367bb4/verdict.json): tier1 lint step PASS
(exit 0), secrets clean (gitleaks + builtin cross-check). The run's overall is
FAIL on the full selftest solely on the section-39 cf099 DRIFT arm — owned by
CF-525, not this row.

Secret scan of this artifact: builtin cross-check — no token-shaped literals
(grep -rEo '[0-9]{8,10}:[A-Za-z0-9_-]{35}' over this file: no matches).
