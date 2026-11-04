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
- An enabled satellite is expected to carry an explicit family floor and a ceiling of eight times
  that floor, and to remain disarmed from adaptive cooldown. That is a provisioning expectation, not
  a gate: the shipped API refuses only the fully unarmed state. `laneIsUnarmed` is true when
  `adaptive_cooldown=0` **and** `floor<=0` **and** `ceiling<=0`
  (`coding-hermes/scheduler` `internal/api/lane_onboarding.go:269-271`), and `validateLaneArming`
  refuses exactly that state and nothing else (`:303-310`). The arming writer fills the pair only on
  a disable→enable transition of an unarmed row (`laneAutoArm`, `:389-403`), taking the floor from
  `satelliteFamilyPins` and the ceiling from `DefaultAdaptiveCooldownCeiling`
  (`internal/database/models.go:39,47-52`, multiplier 8). A row that already carries any non-zero
  bound is written as given and is never refused for its ratio. Measured 2026-11-04: the live family
  carried ceiling/floor ratios of 8× (`docs`, `perf`, `qa`, `readme`, `review`), 16×, 48×, 192×, 224×
  and 576×, across 17 ceiling-bearing rows of which 16 were enabled: `code-factory-qa` read
  `enabled=0`, set by `auto-disable` on `failure rate 91.3% (84/92 ticks, window 100, threshold
  0.90)`. Arm state is a per-row fact, not a family property — an auto-disable can land minutes
  before or after a census, so read the flags back alongside the pair and report the disabled rows
  instead of summarising the family as armed: `sqlite3 ~/.hermes/coding-hermes/scheduler.db "select
  name, enabled, cooldown_floor_s, cooldown_ceiling_s, disabled_by from projects where name like
  '<family>%' and cooldown_ceiling_s>0;"`. The API will not check the ratio for you.
  The cadence numbers themselves are owned by CF-134, not by this gate.
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

Since CF-091, `repo-url --row` also enforces step 1's value comparison itself: rows supplied
by `--row` are grouped into families using the suffix table above (for a non-sync lane the
primary is the lane name with its recognized suffix removed; for `-sync` the leaf is the full
lane name, so sync lanes are never grouped with siblings), and every family with at least two
rows is compared on a normalized `repo_url` (local targets by realpath, remote targets by the
parser's display form, trailing slash stripped). A row whose normalized value differs from the
family's reference (the row named exactly `<primary>`, else the lexicographically first name
in the family) is rejected with exit 4 and a line naming both lanes:
`FAIL repo_url '<raw>' — repo_url diverges from primary '<primary>': '<observed>' != '<reference>' [name]`.
Rows in different families are never compared, and the single-target call is byte-identical to
before.

The live rejection classes and totals are measured and recorded in
`docs/audits/cf091-repo-url-census.md` / `.json` (public-safe: class totals only), and the
operator-owned remainder is tracked with owners and re-check dates in
`docs/audits/cf091-repo-url-waiver.json`. Measured 2026-11-03 at tip `d107ac4` over 866 rows:
384 rejected / 482 accepted (exit 2), by class — 253 stand-in top level (home meta-repo),
76 unsupported `https` scheme, 38 missing path, 15 non-git directory, 1 relative path,
1 diverges-from-primary (a live finding of this check). The repository's own lane family
passed 19/19.

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
a guess or a generic stand-in convention. The earlier note here — that the code-factory foreman ran
a six-hour fallback with no matching durable project pin — no longer holds. Measured 2026-11-04: the
live scheduler DB/API carries `code-factory` at `cooldown_s=1800` with `admission_mode=tasks`, and
the loaded `~/.hermes/fleet.toml` carries a `code-factory` stanza with `cooldown_s = 1800`,
`namespace_id = "code-factory"` and `enabled = true`, so the DB value has a durable pin behind it.
The live satellite rows still do not carry the family pins from the table above; that divergence is
CF-134's subject, and it is not evidence about restart persistence.
