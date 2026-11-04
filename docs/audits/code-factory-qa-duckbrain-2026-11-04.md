# QA lane — tick `code-factory-duckbrain-qa-2026-11-04-02-20-15`

Lane: `code-factory-duckbrain` / qa. Workdir `~/code-factory` — the registered workdir and the
repo's own Git root, `main` attached, parity `0 0` against `origin/main`.
All measurements below are read-only against the shared checkout; the one gate run executed was
CF-123's own recorded probe, which clones `HEAD` into `mktemp` directories.

## 1. Ownership gate

| Probe | Result |
|---|---|
| locator / realpath / `git rev-parse --show-toplevel` | `~/code-factory` — all three equal |
| registered project row `code-factory-duckbrain-qa` | `repo_url=local:~/code-factory`, `workdir=~/code-factory` |
| remotes | `origin`, `worker` — both `git@github.com:coding-hermes/code-factory.git` |
| branch / markers | `main` attached; no `rebase-merge`, `rebase-apply`, `MERGE_HEAD`, `CHERRY_PICK_HEAD` |
| tracked porcelain | 0 paths |
| start tip | `bafdb41` = `origin/main`, parity `0 0`; final tip `1da7f24` |
| `board/.lock` | 0 bytes, mtime 2026-11-03 07:40, no `fuser` holder, no `flock`/`fcntl` consumer in `scripts/boardctl*` → residue, recorded, not deleted |
| sibling lanes at start | three `running` (`readme`, `review`, `duckbrain-dogfood`) → all QA legs read-only until they exited; filing began only after `HEAD == origin/main` and a clean porcelain |

## 2. CF-053 re-verified — AC1-AC3 hold, AC4 is false

CF-053 was closed at `80fca8bf` ("18 satellite lanes now resolve to the project checkout").

| AC | command | result |
|---|---|---|
| 1 — every enabled code-factory lane scans `bad: 0` | `sqlite3 -json ~/.hermes/coding-hermes/scheduler.db "select name, workdir, repo_url, enabled from projects where name like 'code-factory%'" > rows.json && jq -c '.[]' rows.json > lanes.jsonl && python3 scripts/lane_target.py scan lanes.jsonl` | `"bad": 0`, `"ok": true`, rc 0 (19 rows) — **reproduces** |
| 2 — every workdir is a real checkout, none resolves to `$HOME` | same scan: `target.resolved=~/code-factory`, `remotes.origin=git@github.com:coding-hermes/code-factory.git`, `branch=main` | **reproduces** |
| 3 — applied to scheduler row *and* fleet config | `select count(*), count(distinct workdir) …` → `19 1`; the family block in `~/.hermes/fleet.toml` names `workdir = "~/code-factory"` for every lane | **reproduces** (both surfaces agree) |
| 4 — "Concurrent lanes do not share one mutable checkout: two lanes must not write the same board from the same working tree" | 19 enabled lanes, **1 distinct workdir**; the closure evidence is the repoint of all 18 satellites onto that one checkout | **does not reproduce — the criterion is false in the fleet the row shipped** |

The consequence is not hypothetical. A sibling lane of this same family recorded it mid-tick:

> `docs/audits/code-factory-pm-2026-11-04-02-20-15.md`: "A sibling lane committed `51efb66`
> ("board: file CF-144 …") onto `main` in this shared checkout while this tick's judge ran, and a
> second `gitreins` process was live at that moment."

`git log --since='2026-11-03 18:00'` shows `pm`, `sync`, `duckbrain`, `dogfood` and `qa` interleaving
commits into that one tree within minutes (`2404d60` 21:33, `d1c83a6` 21:32, `bafdb41` 21:30,
`0957094` 21:29, `51efb66` 21:27), and three sibling lanes were `running` on it simultaneously at
this tick's start.

**Nothing can catch it.** The instrument that closed the row has no uniqueness leg: two lanes
pointed at the same checkout scan `bad: 0 / ok: true / rc=0` (CF-148's probe). `tests/selftest.sh`
§11 covers target parsing and home-repo rejection only, and `lane_target.py` carries no
`distinct`/duplicate-workdir check.

Disposition: CF-053 re-opened to `in_progress` with a note naming AC4. The remedy is an owner
decision (per-lane worktrees, documented remote targets, or an amended AC that records the accepted
risk) — not a worker's default and not a side effect of the gate fix filed as CF-148.

## 3. CF-123 re-verified — the port fix holds, the probe's discriminator does not

CF-123's recorded `probe` was extracted from the committed board, `bash -n`-checked and run from
the repo root:

```
a_rc=0 a_summary=SELFTEST: PASS unique_red_rows=1
    disk_floor — resolver missing or unreadable: /var/tmp/hermes-scratch/tmp.oDsqG9MUYE/scripts/disk_floor.py
b_rc=0 b_summary=SELFTEST: PASS unique_red_rows=1
    disk_floor — resolver missing or unreadable: /var/tmp/hermes-scratch/tmp.fqHgrJzWL0/scripts/disk_floor.py
port_red_lines=0
```

AC1's operative claims hold: `a_rc=0`, `b_rc=0`, both `SELFTEST: PASS`, `port_red_lines=0`
(no `Address already in use`, no `Failed to connect to 127.0.0.1 port 190…`). The probe's own
documented post-fix expectation — `unique_red_rows=0 in both arms` — does not hold: each arm
prints 1, and the "unique" row is the same `disk_floor` negative-fixture message with a different
`mktemp` path (`tests/selftest.sh:509` asserts that fixture and its text embeds `$HERE`). The
discriminator is path-sensitive, so it cannot separate a real cross-arm race from a negative arm.
Filed as CF-149.

## 4. Rows

| id | priority | subject |
|---|---|---|
| CF-148 | P2 | CF-053 isolation criterion false in the live fleet; `lane_target.py scan` certifies a shared checkout |
| CF-149 | P4 | CF-123's concurrency probe counts a negative-fixture row as a cross-arm red |
| CF-053 | — | re-opened: acceptance criterion 4 unmet |

Id note: this filing drafted CF-147/CF-148 against the published tip `bafdb41`; a sibling lane appended
its own `CF-147` to the shared board minutes later (uncommitted at `1da7f24`), so the append helper
renumbered these rows to `CF-148`/`CF-149` (`delta=1`). The sibling's row stays its own commit — this
one was built through a temp index that carries only these two rows, the CF-053 transition and this
document.

Dedup: the class census (`shared workdir|same checkout|one mutable checkout|workdir uniqueness|distinct workdir`)
over the landed board returns only CF-053 itself and CF-097 (repo-url guard leg — a different
subject). No sibling row covers either finding.

## 5. Marks

```
ch:trace row=CF-148 spec=specs/NODE.md#lane-workdir wave=code-factory-duckbrain-qa-2026-11-04-02-20-15#qa test=tests/selftest.sh::11 doc=docs/audits/code-factory-qa-duckbrain-2026-11-04.md prompt=prompts/qa.md evidence=docs/audits/code-factory-qa-duckbrain-2026-11-04.md witness=live:scheduler.db/projects?name=like-code-factory%+scripts/lane_target.py-scan verdict=none:open-finding commit=none:this-commit-carries-the-doc memory=none:namespace-receipt-recorded-in-lane-evidence
```

The same evidence, with local paths and the prunable scratch listing, is in the lane's staging
file `~/stand-in/qa/code-factory/qa-2026-11-03-21-20-15-evidence.md`.
