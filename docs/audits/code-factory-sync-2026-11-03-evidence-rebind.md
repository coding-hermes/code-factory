# Sync lane 2026-11-03 — completion evidence rebound to committed, re-runnable artifacts

Tick: `code-factory-sync-2026-11-03-14-58-43`
Measured at commit `d4eec41` (tree `e0e7d250bcf9661cd924ab82fa586e419866081d`).

## Drift found

Two `complete` rows carried the only entry in `detail.evidence[].artifacts` as an
**absolute path outside the repository**:

```
~/.hermes/cache/scratch/code-factory-pm-20261031-114422-final-selftest.log
```

- The file no longer exists (scratch entries are pruned), so the path cannot be re-read.
- It was never in the git tree, so nobody cloning this public repo can reach it.
- A `complete` row whose evidence is unreachable is indistinguishable from an unproven row.

Rows affected: `CF-011` (AGENTS.md credential citation), `CF-013` (README status-table
re-runnability). No other row on the board references an out-of-repo artifact path:

```
$ jq -r 'select(.detail.evidence)|.id+"\t"+(.detail.evidence|map(.artifacts//[])|add|join(","))' \
    .coding-hermes/board/tasks.jsonl | grep -E '/(home|tmp)/'
CF-011	~/.hermes/cache/scratch/code-factory-pm-20261031-114422-final-selftest.log
CF-013	~/.hermes/cache/scratch/code-factory-pm-20261031-114422-final-selftest.log
```

## Evidence as re-run on 2026-11-03

### CF-011 — AGENTS.md cites a live row, not the dead CF-108

```
$ grep -n 'CF-002' AGENTS.md
41:   test. A node gets one bundle file, mode 600, deleted after provisioning (`CF-002`).
$ grep -c 'CF-108' AGENTS.md
0
```

CF-002 is a live board row (`pending`, credential boundary), CF-108 does not appear in
AGENTS.md at all.

### CF-013 — every README status row still carries a command that can contradict it

```
$ grep -c 'historical measurement' README.md
1
```

```
$ awk -F'|' '/^\| Piece/{f=1;next} f&&/^\|---/{next} \
    f&&/^\|/{c=$4; gsub(/^[ \t]+|[ \t]+$/,"",c); n++; \
    if(c==""){print "MISSING COMMAND: "$2}} f&&!/^\|/{f=0} END{print "table rows:",n}' README.md
table rows: 6
```

Six status rows, zero missing command column: the works rows are labelled
`works (historical measurement)` and each names the check that can contradict it.

## Repo-level gates at the same tip

```
$ boardctl validate
rows: 61 tasks, 66 events, 0 fixtures
RESULT: OK (17 warning(s))

$ bash tests/selftest.sh
  PASS  61/61 rows parse
SELFTEST: PASS
```

The 17 validate warnings are the documented pre-existing set (free-form `probe` keys on
14 rows, two free-form `guard_result`/`ci_result` values on CF-034, headerless board);
this tick introduced none and repaired none — they are tracked, not silent.

## Fix applied

Both rows gained a second `detail.evidence` run through `boardctl update` (the canonical
lock-aware writer), whose artifact is this committed file:

- run `sync-20261103-cf011`, `CF-011`
- run `sync-20261103-cf013`, `CF-013`

The historical run is preserved — the board is append-only in spirit and a superseded
evidence entry is a record of what was believed, not something to erase.

## Related drift (outside the board file)

The stand-in sync workdir `~/.hermes/sync-workdirs/code-factory-sync` carried a
**36-row** copy of the board taken from the `feat/code-factory-bankai-20261030` worktree,
while canonical `origin/main` carried **61 rows**. That mirror is refreshed from the
canonical file by this tick; it is a read-only convenience copy, never a write target.
