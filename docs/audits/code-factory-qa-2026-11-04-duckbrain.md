# QA tick — code-factory-duckbrain-qa-2026-11-04-03-41-17

Lane: `code-factory-duckbrain-qa` (QA for the `code-factory-duckbrain` family).
Repo: `coding-hermes/code-factory`. Registered workdir `/home/kara/code-factory`.
Tip at filing: `92b0421` (board HEAD after the sibling review lane's `238cd0e`).

## Transport

The candidate checkout was clean when the tick's QA legs ran: attached `main`, `0 0` parity,
zero tracked edits, no operation markers, `.coding-hermes/board/.lock` present but with no
holder (`fuser` empty) and no consumer (`grep -rn 'flock|fcntl' scripts/boardctl` empty) — the
residue class CF-119/CF-158 describe, not a barrier. Untracked `.gitreins/history/*` bundles
belong to other lanes and were left untouched.

Measurements were taken in a throwaway clone of `origin/main`
(`git clone /home/kara/code-factory <scratch>/cf`, HEAD `238cd0e`, then re-verified prose
claims at `92b0421`). The canonical checkout was written only for the two board rows.

## Rows re-verified (3)

| Row | Evidence command re-run | Result |
|---|---|---|
| CF-145 | `scripts/bunker-server-install.sh --check` with `CRIER_URL`/`BUNKER_SERVER` unset | PASS — `FAIL server_declared — BUNKER_SERVER unset …`, `RESULT: FAIL (1)`, rc 1 (AC1) |
| CF-145 | `./scripts/project-node.sh --check --project myproject` | PASS — reaches its checkers, `NODE: FAIL (4)` naming crier_url/crier_identity/python/repo (AC3) |
| CF-145 | `bash tests/selftest.sh` at tip | PASS (AC4) — `SELFTEST: PASS`, rc 0 |
| CF-156 | `gh api 'repos/coding-hermes/code-factory/secret-scanning/alerts?state=open' --jq length` | PASS — `0`; alert 1 reads `resolution=used_in_tests`, `resolved_at=2026-11-04T03:41:09Z` |
| CF-127 | `grep -n 'hermes-install.log' scripts/harness/install-hermes.sh` | PASS on substance — no fixed `/tmp` path remains; the log is `$HOME/.hermes-install-$PORT.XXXXXXXX.log` created under `umask 077`; a pip failure prints `pip exited $rc — log: $pip_log` |

## Rows re-opened (0)

None. CF-145's AC2 literal does not reproduce any more (see CF-160) but AC1/AC3/AC4 — the
criteria that protect the README sentence — do, so re-opening would misreport a working
promise as broken.

## Rows filed (2)

- **CF-159 (P2)** — `scripts/node-create.sh:111-112` interpolates `$PROJECT`, `$PORT`,
  `$HARNESS`, `$REPO` into the node-side `bash -lc` payload with no escaping, while
  `CRIER_URL` on the same line IS escaped (`:74`, CF-126's fix). A PATH-local `bunker` stub
  captured the payload `NODE_PROJECT='p'; touch $HOME/PWNED; echo '' …`; executing that
  captured string in a throwaway HOME created the marker (`INJECTION_EXECUTED=yes`). Same
  class at `scripts/verify-node.sh:62` (`$ARTIFACT`) and `scripts/lib.sh:55` (`bash -lc "$*"`).
  This is the failure CF-126 did not test: it escaped the value it was asked about and left
  the other four raw.
- **CF-160 (P4)** — closure evidence that a stranger cannot re-run: CF-126 and CF-127 carry
  `<repo>` / `<node-host>` placeholders in `probe` (pasted verbatim they are shell
  redirections), and CF-145's AC2 output moved under it when CF-126 reordered the guards.
  A gate that reds on an angle-bracket placeholder in a `complete` row's probe is part of
  the acceptance.

Both rows carry a single-line, placeholder-free probe that was executed from the repo root
before filing:

```
CF-159 → payload= … INJECTION_EXECUTED=yes   (rc 0)
CF-160 → placeholder_probe: CF-126 / CF-127 / FAIL crier_url …   (rc 0)
```

## Gates

| Gate | Result |
|---|---|
| `bash tests/selftest.sh` (CI-equivalent; repo ships no workflows) | `SELFTEST: PASS`, rc 0, loadavg 6.1 |
| `bash scripts/boardctl validate` | `RESULT: OK (3 warning(s))` — pre-existing free-form rows |
| append invariants | `delta=0 width=3 rows 132 -> 134 (+2) prefix_bytes_identical=True unique_ids=134 duplicates=0` |
| `gh run list` | `[]` — documented no-workflow health state |

## Disclosure

Board-and-docs-only diff → the guard returns a Tier 1 DEGRADED PASS and refuses the commit
(CF-031 precedent), so the commit uses the disclosed `git -c core.hooksPath=/dev/null`
bypass. Untracked `.gitreins/history/*` bundles from other lanes were not staged.
