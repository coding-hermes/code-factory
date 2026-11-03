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
7. Check the primary and every satellite's `repo_url` with the repo-side guard below before arming.

## Repo URL guard and primary-family reconciliation (CF-085)

Repo-side, read-only guard (stdlib, no network or writes):

```bash
python3 -B scripts/lane_target.py repo-url 'local:~/work/project'
python3 -B scripts/lane_target.py repo-url --row projects.json
# projects.json is a JSON project object or array, not JSONL; stdin is --row -.
```

Each row must have a string `repo_url`. `local:`, `file:`/`file://`, absolute and `~` paths
reuse the lane target parser and checkout probe. The resolved path must exist and equal
`git -C <path> rev-parse --show-toplevel`: a missing path, plain directory, or checkout
subdirectory is rejected. PASS names the resolved root and observed HEAD; no remote or
attached branch is required. Exit codes are 0 accepted, 2 invalid input, 3 remote verification
not permitted, and 4 local verification failed. Recognized remote targets require
`--allow-remote` and are only `remote-structural-only`, never proof of reachability. For mixed
rows, exit 2 takes precedence over 3, then 4. The summary counts rejected and accepted rows.

Operator-side reconciliation is mandatory whenever a primary's `repo_url` changes. Satellites
inherit the value when minted, not dynamically: changing the primary alone does not fan it out.
The guard does not write the scheduler or edit `fleet.toml`.

1. Read fresh scheduler project rows and inventory the primary plus every `<primary>-<family>`
   satellite, across all families in the table above. Include disabled lanes and nested primaries
   with their own satellites; do not select only the currently failing family. Compare each
   satellite's `repo_url` with its primary's value to detect divergence. Run the guard over that
   JSON array (`repo-url --row projects.json`) to identify phantom roots by named lane. Root
   validity alone does not detect divergence between two different valid git roots: both the
   value comparison and the root check are required. Do not confuse stand-in `workdir` with
   `repo_url`; keep valid stand-in workdirs unchanged.
2. Validate the proposed primary root with `repo-url` first. Then, using the supported scheduler
   API and its operator authentication (never credentials in arguments), issue a partial PUT
   containing only `{"repo_url":"<validated-primary-repo_url>"}` for the primary and update its
   matching `repo_url` line in the loaded `fleet.toml` project stanza immediately afterward.
   Repeat that exact partial PUT, then matching `fleet.toml` line update, for every satellite.
   Do not replace whole project rows or change their other admission fields. Repeating these
   assignments is idempotent. These are operator-side writes, not actions performed by this repo.
3. Read every affected scheduler row back, verify equality with the new primary value and the
   matching `fleet.toml` stanza, and export a fresh JSON array. Re-run
   `python3 -B scripts/lane_target.py repo-url --row projects.json` over the entire affected family.
   Verification must be re-run and must print `0 rejected` (exit 0); a successful PUT alone is
   not evidence. Resolve any partial update before re-arming the lanes.

## Provenance and open caveat

The family roots and pins above come from scheduler commit `7d5b8d25` and its parity test, not from
a guess or a generic stand-in convention. The code-factory foreman's current six-hour fallback was
verified in the live scheduler DB/API, but a matching durable project pin in the loaded
`~/.hermes/fleet.toml` was not found during the audit. Restart persistence therefore remains
unverified until the supported fleet policy generator reconciles that project and the parity check
passes.
