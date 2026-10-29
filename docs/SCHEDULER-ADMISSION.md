# Scheduler lane onboarding and admission

This document records the scheduler-side gate that must be satisfied before a code-factory lane is
created. It is separate from the repo's GitReins test gate in the README.

## Satellite family allowlist

The scheduler API recognizes a lane suffix, derives the family, and validates its workdir against
the canonical roots below. A primary lane (no recognized satellite suffix) is not constrained by
this satellite-workdir gate. The authoritative implementation is `coding-hermes/scheduler`
`internal/api/lane_onboarding.go` (`satelliteLaneSuffixes`, `satelliteWorkdirRoots`,
`satelliteFamilyPins`, `canonicalLaneWorkdirs`, and `validateLaneWorkdir`); key-set parity is
covered by `TestSCHEDGAP138_FamilyConstantsParity`. The nine-family correction is scheduler commit
`7d5b8d25`.

For a non-sync lane, `<primary>` is the lane name with its recognized `-<family>` suffix removed.
For sync, the leaf is the full lane name. Roots are relative to `$HERMES_HOME` (normally
`~/.hermes`); provisioning must not hard-code an operator's home path.

| Family suffix | Accepted workdir roots | Family cooldown floor |
|---|---|---:|
| `-qa` | `stand-in/pm/<primary>` or `stand-in/qa/<primary>` | 43,200 s (12 h) |
| `-pm` | `stand-in/pm/<primary>` or `stand-in/pm-lane/<primary>` | 86,400 s (24 h) |
| `-sync` | `sync-workdirs/<lane-name>` | 21,600 s (6 h) |
| `-dogfood` | `stand-in/dogfood/<primary>` | 259,200 s (72 h) |
| `-releng` | `stand-in/releng-lane/<primary>` | 86,400 s (24 h) |
| `-docs` | `stand-in/docs/<primary>` | 604,800 s (7 d) |
| `-readme` | `stand-in/readme/<primary>` | 604,800 s (7 d) |
| `-perf` | `stand-in/perf/<primary>` | 604,800 s (7 d) |
| `-review` | `stand-in/review/<primary>` | 604,800 s (7 d) |

A new family is not onboarded by naming it alone: the scheduler suffix vocabulary, workdir-root map,
family-pin map, fleet invariant matrix, and parity test must all agree. A recognized family with
no root would otherwise produce an empty allow-list and reject every candidate workdir; do not
reintroduce that state. The gate's error response should list the accepted paths.

## Admission and arming

- The code-factory primary uses `admission_mode=tasks`. Board-owned work can admit it before the
  fallback cooldown; when there is no admissible board work, it waits for its six-hour fallback
  cadence. `cooldown_s=21600` is the desired fallback value.
- A satellite uses the cooldown admission model, not tasks admission: its board path can resolve to
  the primary board, so it must not interpret the primary backlog as independently owned work.
- An enabled satellite must have an explicit family floor and ceiling (`8 × floor`) and remain
  disarmed from adaptive cooldown. The scheduler/API validates the row before it is written or
  enabled.
- Scheduler namespace/global concurrency and load gates are runtime admission controls, not
  workdir allowlist rules. A lane may be configured correctly and still remain queued for capacity.

## Verification checklist

For every new satellite lane:

1. Resolve the lane's family suffix and derive the accepted path from this table.
2. Create it disabled at an accepted path; reject an off-root path before any row is written.
3. Set its cooldown floor to the family pin and ceiling to eight times the floor; keep adaptive
   cooldown off.
4. Enable it only after prompt, namespace, board linkage, and delivery target are verified.
5. Read the scheduler API/DB row back; verify `enabled`, `workdir`, `namespace_id`, admission mode,
   cooldown bounds, prompt, and delivery target.
6. Run the scheduler's family-constant parity test and `ops/check-fleet-invariants.py`; do not
   infer success from a successful API response alone.

## Provenance and open caveat

The family roots and pins above come from scheduler commit `7d5b8d25` and its parity test, not from
a guess or a generic stand-in convention. The code-factory foreman's current six-hour fallback was
verified in the live scheduler DB/API, but a matching durable project pin in the loaded
`~/.hermes/fleet.toml` was not found during the audit. Restart persistence therefore remains
unverified until the supported fleet policy generator reconciles that project and the parity check
passes.
