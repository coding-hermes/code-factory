# Appendix: code-factory lane inventory

<!-- GENERATED FILE — do not edit by hand. Regenerate with:
     python3 scripts/gen_lane_inventory.py
     The only line that changes between runs is the Generated stamp. -->

| Field | Value |
|---|---|
| Source | `~/.hermes/coding-hermes/scheduler.db`, table `projects` |
| Generated | 2026-11-25T04:47:03Z (UTC) |
| Generator | `scripts/gen_lane_inventory.py` |

This page is the canonical lane set of the code-factory family, derived
from the scheduler database at generation time. Handbook modules must
cite this page instead of typing their own lane counts (CF-335); the
counts below are re-derived from the database on every run, never
hard-coded.

## Canonical lane table

| Lane | Parent | Enabled | Workdir |
|---|---|---|---|
| `code-factory-docs` | `code-factory` | 1 | `~/code-factory` |
| `code-factory-dogfood` | `code-factory` | 1 | `~/code-factory` |
| `code-factory-foreman` | `` | 1 | `~/code-factory` |
| `code-factory-ops` | `` | 1 | `~/code-factory` |
| `code-factory-perf` | `code-factory` | 1 | `~/code-factory` |
| `code-factory-pm` | `code-factory` | 1 | `~/code-factory` |
| `code-factory-qa` | `` | 0 | `~/code-factory` |
| `code-factory-readme` | `code-factory` | 1 | `~/code-factory` |
| `code-factory-releng` | `code-factory` | 1 | `~/code-factory` |
| `code-factory-review` | `code-factory` | 1 | `~/code-factory` |
| `code-factory-sync` | `code-factory` | 1 | `~/code-factory` |

## Counts

| Metric | Value |
|---|---|
| Family rows | 11 |
| Enabled lanes | 10 |
| Disabled lanes | 1 |

## Resolution: `code-factory` vs `code-factory-duckbrain`

`code-factory` and `code-factory-duckbrain` are one project: the
duckbrain spelling was an earlier name of the same lane, not a sibling.
The registry snapshot that handbook modules 07 and 35 measured on
2026-11-05 still listed `code-factory-duckbrain` and five
sibling spellings (`code-factory-duckbrain-dogfood`, `code-factory-duckbrain-pm`, `code-factory-duckbrain-qa`, `code-factory-duckbrain-releng`, `code-factory-duckbrain-sync`) among its rows.

Measured against the live database on 2026-11-25: zero rows
match `code-factory-duckbrain%`. The residual names in older docs are stale
typed references, not live lanes; the table above is the only
authoritative lane set.
