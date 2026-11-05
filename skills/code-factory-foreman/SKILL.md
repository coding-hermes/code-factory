---
name: code-factory-foreman
description: Use when running the code-factory foreman lane. Advance one board row while honoring the scheduler admission contract and evidence gates.
version: 1.0.0
---

# Code-factory foreman skill

## Run contract

1. Read `AGENTS.md`, the board, and the docs/specs that govern the selected row. Advance exactly one board row per tick.
2. Treat the design/PRD/specs as authority. When implementation and contract disagree, identify the mismatch and update the contract with the implementation in the same change.
3. Use `scripts/boardctl` for board reads/writes; validate before and after changes. Complete a row only with reproducible evidence bound to its acceptance criteria.
4. Run `tests/selftest.sh` and the applicable GitReins guard before claiming work complete. Distinguish source presence, a passing local test, live infrastructure proof, and owner authorization.
5. Report the row ID, change, exact proof command/result, and remaining blockers. Do not claim a queued tick executed.

## Scheduler admission gate

The scheduler API has a satellite-family workdir allowlist. Before creating or changing a satellite lane, consult [`docs/SCHEDULER-ADMISSION.md`](../../docs/SCHEDULER-ADMISSION.md), then derive the full accepted workdir from the lane's suffix and primary name. Never guess a root or bypass a refusal by moving the lane elsewhere.

Allowed satellite families are `qa`, `pm`, `sync`, `dogfood`, `releng`, `docs`, `readme`, `perf`, and `review`. Their canonical relative roots are, respectively:

- `qa`: `stand-in/pm/<primary>` or `stand-in/qa/<primary>`
- `pm`: `stand-in/pm/<primary>` or `stand-in/pm-lane/<primary>`
- `sync`: `sync-workdirs/<lane-name>`
- `dogfood`: `stand-in/dogfood/<primary>`
- `releng`: `stand-in/releng-lane/<primary>`
- `docs`: `stand-in/docs/<primary>`
- `readme`: `stand-in/readme/<primary>`
- `perf`: `stand-in/perf/<primary>`
- `review`: `stand-in/review/<primary>`

`<primary>` is the lane name without its `-<family>` suffix; `sync` keeps its full lane name. Paths are relative to the operator's `$HERMES_HOME` (normally `~/.hermes`). Pins are defined in the cited admission document; enabled satellites must be explicitly paced and must not be treated as task-admission foremen.

A recognized family with no canonical root is a scheduler defect: it must not turn into an empty allow-list that rejects every workdir. Do not weaken the gate. Record the refused lane, exact API error, and family, then fix the scheduler root/pin parity and tests.

## Primary foreman pacing

The `code-factory` primary uses `admission_mode=tasks`. It should run when its own board has admissible work. Once the board is drained, its timer fallback is six hours (`cooldown_s=21600`). This is not a blanket delay between ticks while work remains. Verify the live row and durable fleet configuration separately; do not report DB state alone as restart-safe.

## Duplicate execution in a shared checkout

The same lane prompt can be dispatched twice into one workdir. The twin commits the patch you
are holding — byte-identical, its own message — and pushes it while you are still measuring.
Symptoms: `git log` shows a commit you never made whose message quotes your own evidence, and
the files you edited no longer appear as modified.

- Re-read `git log --oneline -3` and `git status` after any long step (a fill, a judge, a suite
  run), before you commit. Compare `git rev-list --count <remote>/main..HEAD` on every remote
  (`gh`, `origin` and `worker` can point at one GitHub repo, so "Everything up-to-date" on the
  second push is normal, not a lost push).
- If the landed commit is content-identical to your patch, keep theirs: verify the committed
  tree against the row's criteria and discard your copy. Do not re-commit and do not open a
  second `gitreins task complete` for the same row in one checkout — two judges in one tree
  collide on the suite's shared paths and both verdicts become untrustworthy.
- The half left to you is the part they did not do: the board close (`boardctl update`/the
  row rewrite plus one appended event), the evidence bundle under `.gitreins/history/`, and a
  drift check (`scripts/board_drift.py check --workdir . --ref origin/main`).
- Say it plainly in the close commit: which commit you verified, that a twin produced it, and
  that the judge ran once.

## Dispatch on an unattended surface

Stage the brief with a file write and launch a wrapper script that runs `hermes chat --query-file
<brief> --oneshot -Q -m <model> --provider <provider> -s coding-hermes-worker --ignore-rules`,
invoked as `bash <wrapper>` in background+pty. The inline `bash -lic '… hermes chat …'` form and
`-q "$(cat brief)"` are gated or mangled when no user is present; `--query-file` is neither.

A worker can COMMIT and then hang on its final turn: no exit marker, ~0% CPU, log frozen, and a clean
porcelain tree because the work is committed. Classify from `git log --oneline -1` and
`git show --stat`, never from porcelain alone. The deliverable is already on disk — read the diff
against the row's criteria, run the gate yourself, terminate your own launcher, and say in the
closing event that the launcher hung after committing. Do not re-dispatch the brief on the
assumption nothing landed.

## Closeout readback (the writer accepts what it does not store)

`boardctl update <id> --status complete` can return exit 0 and still persist a row with
`commit_hash` set, `detail.evidence` empty and `completed_at` null — accepted payload, dropped
fields. Never trust the command's echo:

- After every close, read the stored row back (`jq 'select(.id=="<ID>")'` over
  `.coding-hermes/board/tasks.jsonl`) and compare status, commit_hash, `detail.evidence[].run_id`
  and `completed_at` against the payload. A complete row whose evidence list is empty claims a
  completion no stranger can resolve.
- Rebind with `boardctl update <ID> --status complete --evidence-run-id <run> --completed-at
  <verdict evaluated_at>` and append one `audit` event naming the correction, then commit that
  as a board-only bookkeeping commit. `--evidence-artifact` is refused without
  `--evidence-fingerprint`, and this board documents no fingerprint derivation, so keep the
  verdict path in the row note instead of inventing a value.
- Bind the run that judged the exact commit: `task_id` matches, `commit` equals the row's
  `commit_hash`, `passed` is true. A verdict directory name is the run id; the file carries no
  `id` field.

## Public-repository boundary

Do not commit secrets, private hosts/URLs, personal data, or temporary credentials. The repo-owned `scripts/boardctl` is an entrypoint to the canonical external `boardctl` engine, not a bundled or independent implementation. Keep that dependency explicit.
