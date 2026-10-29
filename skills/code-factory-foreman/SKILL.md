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

## Public-repository boundary

Do not commit secrets, private hosts/URLs, personal data, or temporary credentials. The repo-owned `scripts/boardctl` is an entrypoint to the canonical external `boardctl` engine, not a bundled or independent implementation. Keep that dependency explicit.
