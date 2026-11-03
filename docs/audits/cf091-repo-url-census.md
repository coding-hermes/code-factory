# CF-091 repo_url census — live scheduler rows

Measured sweep of every scheduler project row's `repo_url` with the repo-side
guard, on the read-only export described below. This census records the
rejection classes and totals only; lane names and host paths are deliberately
omitted (this is a public repository). The operator-owned remainder is tracked
in `cf091-repo-url-waiver.json` next to this file.

## Totals

| Metric | Value |
|---|---:|
| Rows inspected | 866 |
| Rejected | 384 |
| Accepted | 482 |
| Exit code | 2 |

## Rejection classes

| Class | Count |
|---|---:|
| `not a git root (git: top level is <home meta-repo>)` — stand-in directory resolving to the operator's home meta-repo | 253 |
| `unsupported scheme https` — placeholder remote roots | 76 |
| `path does not exist or is not a directory` | 38 |
| `not a git root (git: fatal: not a git repository …)` — plain non-git directory | 15 |
| `local target must be absolute or ~-relative` — relative path | 1 |
| `repo_url diverges from primary '<primary>'` — intra-family disagreement (new check in this change) | 1 |
| **Total rejected** | **384** |

The single `diverges-from-primary` rejection is a live finding of the new
intra-family agreement check: two rows of one family carry two different but
individually valid git roots, which the per-row root check alone could not
detect. It is carried in the waiver with the other operator-owned classes.

## Control result: the repository's own lane family

The repository's own lane family (primary plus satellites) passes fully under
the new check: 19/19 rows accepted, `0 rejected`, exit 0.

## Reproduction

Read-only export (never writes the scheduler; `$HERMES_HOME` is the operator's
Hermes home):

```bash
sqlite3 -json "file:$HERMES_HOME/coding-hermes/scheduler.db?mode=ro&immutable=1" \
  "select name,repo_url from projects" > projects.json
python3 -B scripts/lane_target.py repo-url --row projects.json; echo "exit=$?"
```

## Measurement metadata

- Measured at: 2026-11-03T17:44:39Z
- Repository tip measured: `d107ac40965eabac139ed60f9f5b474f7df63ba2` (`d107ac4`)
- Tool: `scripts/lane_target.py repo-url --row` (stdlib-only, no network, no writes)
- Machine-readable totals: `docs/audits/cf091-repo-url-census.json`
