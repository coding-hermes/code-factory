# Docs lane — the admission gate does not validate an 8 × floor ceiling (CF-169)

- **Tick:** `code-factory-docs-2026-11-04-06-11-13` (third execution of this tick id; see "Duplicate dispatch")
- **Tip measured:** `ef222d1460639cfc5421b6ce5b4714de0be06552`
- **Lane:** docs · **Row:** CF-169 · **GitReins task:** `CF-169-DOC1`

## 1. Claims corrected

| # | File:line (before) | Claim as written | What is true | Proof |
|---|---|---|---|---|
| 1 | `docs/SCHEDULER-ADMISSION.md:44-46` | "An enabled satellite **must** have an explicit family floor and ceiling (`8 × floor`) … **The scheduler/API validates the row before it is written or enabled.**" | The API refuses exactly one shape — an enabled satellite whose `adaptive_cooldown`, floor **and** ceiling are all zero — and fills the pair only on a disable→enable transition of that unarmed row. Any row already carrying a non-zero bound is written as given and never refused for its ratio. | `internal/api/lane_onboarding.go:269-271,303-310,389-403`; `internal/database/models.go:39,47-52`; live ratios below |
| 2 | `docs/SCHEDULER-ADMISSION.md:142-146` | "The code-factory foreman's current **six-hour fallback** was verified in the live scheduler DB/API, but a matching durable project pin in the loaded `~/.hermes/fleet.toml` **was not found**." | The foreman's fallback is `cooldown_s=1800`, and `~/.hermes/fleet.toml` **does** carry the `code-factory` stanza (`cooldown_s = 1800`, `namespace_id = "code-factory"`, `enabled = true`). | `scheduler.db` read below; `fleet.toml:1987-1997` |

Claim 1 is the larger of the two: it tells an operator that a carried-over pacing pair cannot be
wrong, which is the one thing the shipped gate does not check.

## 2. The code path that proves the new statement

Scheduler checkout `coding-hermes/scheduler` at `bf7427c8`:

```go
// internal/api/lane_onboarding.go:269
func laneIsUnarmed(adaptive bool, floor, ceiling int) bool {
        return !adaptive && floor <= 0 && ceiling <= 0
}

// internal/api/lane_onboarding.go:303
func validateLaneArming(name string, enabled, adaptive bool, floor, ceiling int) error {
        family := laneSatelliteFamily(name)
        if family == "" || !enabled || !laneIsUnarmed(adaptive, floor, ceiling) {
                return nil
        }
        return unarmedLaneError(name, family)
}

// internal/api/lane_onboarding.go:389
func laneAutoArm(cur *database.Project, updates database.ProjectUpdates, name string) (database.ProjectUpdates, bool) {
        family := laneSatelliteFamily(name)
        if family == "" || updates.Enabled == nil || !*updates.Enabled || cur.Enabled {
                return updates, false
        }
        adaptive, floor, ceiling := laneUpdateArming(cur, updates)
        if !laneIsUnarmed(adaptive, floor, ceiling) {
                return updates, false
        }
        pin := satelliteFamilyPins[family]
        ceilingPin := database.DefaultAdaptiveCooldownCeiling(pin)
        updates.CooldownFloorS = &pin
        updates.CooldownCeilingS = &ceilingPin
        return updates, true
}
```

`DefaultAdaptiveCooldownCeiling` is the only place the 8× relationship lives
(`internal/database/models.go:39,47-52`), and `laneAutoArm` is the only caller that applies it to a
lane row. Neither function compares an existing ceiling to an existing floor.

## 3. Literal command output

Live family pacing state, ceiling/floor ratio:

```
$ sqlite3 -header -column ~/.hermes/coding-hermes/scheduler.db \
   "select name, cooldown_floor_s floor, cooldown_ceiling_s ceil,
      case when cooldown_floor_s>0 then cooldown_ceiling_s/cooldown_floor_s else 0 end ratio
    from projects where name like 'code-factory%' and cooldown_ceiling_s>0 order by name;"

name               floor    ceil    ratio
-----------------  ------  ------  -----
code-factory-docs               604800  4838400      8
code-factory-docs-qa             21600  4838400    224
code-factory-dogfood              3600  2073600    576
code-factory-duckbrain-dogfood   21600   345600     16
code-factory-duckbrain-pm        21600   345600     16
code-factory-duckbrain-qa        21600   345600     16
code-factory-duckbrain-releng    21600   345600     16
code-factory-duckbrain-sync      21600   345600     16
code-factory-perf               604800  4838400      8
code-factory-pm                   3600   691200    192
code-factory-qa                  21600   172800      8
code-factory-readme             604800  4838400      8
code-factory-readme-qa           21600   345600     16
code-factory-releng               3600   691200    192
code-factory-releng-qa           21600   345600     16
code-factory-review             604800  4838400      8
code-factory-sync                 3600   172800     48
```

Every one of those rows is `enabled=1`, and none of the non-8× rows is refused — which is the whole
correction: 12 of 17 rows carry 16×, 48×, 192×, 224× or 576×.

Foreman fallback and its durable pin:

```
$ sqlite3 ~/.hermes/coding-hermes/scheduler.db \
   "select name, cooldown_s, admission_mode from projects where name='code-factory';"
code-factory|1800|tasks

$ sed -n '1987,1997p' ~/.hermes/fleet.toml
name = "code-factory"
repo_url = "local:<workdir>"
workdir = "<workdir>"
weight = 10
priority = 8
cooldown_s = 1800
model = "…"
provider = "…"
namespace_id = "code-factory"
deliver = "…"
enabled = true
```

## 4. Claims that came back TRUE (re-run, not re-asserted)

| Claim | Command | Result |
|---|---|---|
| `specs/NODE.md` layer table names only what the shipped script measures | `sed -n '20,50p' specs/NODE.md` + `bash scripts/project-node.sh --check --layers 00,30 --project probe` | TRUE — the scoped run prints `SCOPE: layers 00,30 (fixture mode — no node certification)`, `SKIP layer 10/20/40 (out of scope)`, `SKIP layer 90 (fixture mode: no manifest)` exactly as the spec says |
| `--layers` is a comma list over `00,10,20,30,40`; unknown/empty/stray comma exits 2 with usage | `--layers 90`, `00,`, `00,,30`, `abc` | TRUE — all four print the usage line, `rc=2` |
| `node-create.sh --staged-files` prints five files and no `config.yaml` | `bash scripts/node-create.sh --staged-files` | TRUE — `project-node.sh`, `lib.sh`, `disk_floor.py`, `reclaim_disk.py`, `harness/install-hermes.sh` |
| Family cooldown pins in the table match the scheduler source | `grep -n 'satelliteFamilyPins' -A 14 internal/api/lane_onboarding.go` | TRUE — `qa: 43200, pm: 86400, sync: 21600, dogfood: 259200, releng: 86400`, weekly families `7*24*60*60` |
| `bunker-server-install.sh` has no `--help` interface | `bash scripts/bunker-server-install.sh --help` | TRUE — it runs the qualification check instead (`FAIL server_declared`, `RESULT: FAIL (1)`, rc 1) |
| Repository gate | `bash tests/selftest.sh` | `SELFTEST: PASS`, rc 0, 106 `PASS` rows at the measured tip |

## 5. Claims I could not verify — not measured

- Whether a **restart** of `schedulerd` re-derives satellite floors/ceilings from
  `satelliteFamilyPins`. Not measured: this tick read the DB and the source, it did not restart the
  daemon, and the reconciler that writes `FAM_CD` lives outside the repo.
- Whether the **scheduler dashboard/API** shows the same ratio a second instrument would compute.
  Not measured: only `sqlite3` against the live DB was read; no API-side census was taken.
- Whether any lane's non-8× ceiling was **deliberate** operator policy or loader residue. Not
  measured: the floors trace to `scripts/configure_family.py:128-137` (`PACE_CEILING`) and to the
  derived crier/9router shape, but no commit message or board row states the intent, so the prose
  names the divergence and leaves the intent to CF-134.

## 6. State changed outside this repo (disclosed)

While testing whether `scripts/load_lane_config.py` had a help interface, running
`python3 scripts/load_lane_config.py --help` **executed the loader** — it ignores argv and rewrites
six live scheduler rows (namespace, admission mode, prompt) on every invocation.

- It rewrote `namespace_id` on `code-factory`, `code-factory-pm`, `code-factory-sync`,
  `code-factory-qa`, `code-factory-dogfood` and `code-factory-duckbrain` to
  `coding-hermes` / `coding-hermes` / `coding-hermes` / `qa` / `dogfood` / `duckbrain-sync`.
- Restored in the same tick to `code-factory`, the value `~/.hermes/fleet.toml:1995` declares for the
  primary and every code-factory lane carries in the DB (19/19 after the restore; see
  `restore-ns.txt` in the tick scratch).
- The prompts were **not** changed by the incident: each row's `prompt` is byte-identical to
  `prompts/<lane>.md` at this tip, so the loader's prompt write was a no-op.
- No product code in this repository was touched by the incident. The loader having no read-only mode
  is filed as CF-170.

## 7. Verification (re-runnable)

```bash
bash tests/selftest.sh                                    # SELFTEST: PASS, rc 0
sed -n '44,56p' docs/SCHEDULER-ADMISSION.md               # corrected paragraph
sqlite3 -header -column ~/.hermes/coding-hermes/scheduler.db \
  "select name, cooldown_floor_s, cooldown_ceiling_s from projects where name like 'code-factory%';"
```

ch:trace row=CF-169 spec=docs/SCHEDULER-ADMISSION.md test=tests/selftest.sh evidence=docs/audits/code-factory-docs-2026-11-04-cf169-validator-claim.md verdict=.gitreins/history

STATUS: done
TIER: T3 (correction written, gate run, evidence committed, verdict bound)
EVIDENCE: this file + `bash tests/selftest.sh` at the correction commit
