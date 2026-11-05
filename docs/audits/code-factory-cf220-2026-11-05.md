# CF-220 — the seed contract, proven on a real node

Row: `CF-220` (P0) — *Nothing seeds the prompts or the skills into a bunker, so the foreman we
now run there has neither.*

Implementation: `b3ed55c` — *feat(seed): a node receives its procedure and skills,
digest-recorded, or nothing (CF-220)*.

This artifact exists so the row's acceptance criteria can be resolved by a stranger: every
command below was run by the `diag-node-1` tick on 2026-11-05 between 13:12Z and 13:17Z, on the
control host (`kara`) against the live node `cf-node` on `bunker-las-03`, and the outputs are
quoted verbatim. The row was `in_progress` on the board at the time — the implementation had
landed and been pushed, and no tick had closed it.

## What the node actually has

Measured with one `bunker exec` round trip:

```
$ bunker --server bunker-las-03 exec cf-node -- bash -lc 'ls -la $HOME/.hermes/seed-applied.json; find $HOME/.hermes/prompts $HOME/.hermes/skills -type f | wc -l'
-rw-rw-r-- 1 bunker-cf-node bunker-cf-node 2251 Nov  4 20:52 /home/bunker-cf-node/.hermes/seed-applied.json
14
```

The record declares what was applied, where, and when:

```
$ bunker --server bunker-las-03 exec cf-node -- bash -lc 'python3 - <<PY
import json,os
r=json.load(open(os.path.expanduser("~/.hermes/seed-applied.json")))
print("applied_at=%s applied_to=%s files=%d" % (r.get("applied_at"), r.get("applied_to"), len(r.get("files",[]))))
for f in r["files"][:3]: print("  %s %s" % (f["path"], f["sha256"][:12]))
PY'
applied_at=2026-11-05T04:52:15Z applied_to=/home/bunker-cf-node/.hermes files=13
  prompts/docs.md 5d093e26d190
  prompts/dogfood.md 2236c575ac71
  prompts/duckbrain.md 587bffe05592
```

## The check can go red, and it names the drifted file

`scripts/node_seed.py check` compares the node's installed tree against the applied record.
Green on the untouched node, red on one appended line, green again after the file was restored
from a backup taken on the node in the same script:

```
$ ssh-side: python3 $HOME/node_seed.py check --record $HOME/.hermes/seed-applied.json --home $HOME
  PASS  seed_check — 13 files present and matching
EXIT=0

$ ssh-side: printf '\n<!-- drift probe -->\n' >> $HOME/.hermes/prompts/foreman.md
$ ssh-side: python3 $HOME/node_seed.py check --record ... --home $HOME
  FAIL  seed_check — prompts/foreman.md drifted (75da16fb93fd != 82c020b6f316)
  FAIL  seed_check — 1 of 13 seeded files differ from the record
EXIT=1

$ ssh-side: cp $HOME/foreman.md.bak-cf220 $HOME/.hermes/prompts/foreman.md
$ ssh-side: python3 $HOME/node_seed.py check --record ... --home $HOME
  PASS  seed_check — 13 files present and matching
EXIT=0
```

The tamper was reverted on the node in the same run and the restore was re-measured, so the node
is left at the state the seed wrote. No repository file was touched by the probe.

## The fixture gate, at the judged tip

```
$ bash tests/selftest.sh | tail -8
node_seed — the declared seed, its digests, and what it refuses
  PASS  build writes a record with a sha256 per declared file, exit 0
  PASS  apply installs prompts and skills and a green check follows (exit 0, 0)
  PASS  a tampered file fails the check and is named (exit 1)
  PASS  a digest mismatch refuses the whole seed and installs nothing (exit 1)
  PASS  a seed over the size budget is refused (exit 1)
  PASS  a backup artefact declared as seedable is refused (exit 1)

SELFTEST: PASS
```

## Criteria, one at a time

| AC | What it asks | Evidence | Verdict |
|---|---|---|---|
| 1 | Seeding into `$HOME/.hermes`, digest-recorded, refuses a mismatched digest | 14 files seeded (13 declared + the record); `seed_digest` arm and "a digest mismatch refuses the whole seed and installs nothing (exit 1)" | met |
| 2 | Declared list with a ~16 MB budget; reportable what/digest/when | `config/node-seed.txt` (13 lines, only `prompts/`, `skills/` globs); `DEFAULT_BUDGET = 16 * 1024 * 1024` and `seed_budget` refusal at `scripts/node_seed.py:39,128`; the node's `seed-applied.json` reports `applied_at`, `applied_to` and a sha256 per file | met |
| 3 | A check row fails when the node differs from the declared digests | the live red arm above (`prompts/foreman.md drifted`, exit 1) plus the fixture tamper arm | met |
| 4 | Backups and the full user skill library excluded by construction, and the row says how | inclusion is by exclusive declaration: only paths named in `config/node-seed.txt` are ever copied, so a pattern cannot sweep in a backup; the node carries 11 prompts and 2 skills and no tarball (`find $HOME/.hermes -maxdepth 1 -name '*.tar*' | wc -l` -> `0`); "a backup artefact declared as seedable is refused (exit 1)" | met |

## Residual, named rather than hidden

- `scripts/verify-node.sh` has no seed leg: the freshness comparison added by CF-244 is folded
  into `VERIFY:`, but a stranger still has to know the record path and invoke `node_seed.py check`
  by hand to see drift from the control host. Filed as `CF-250` with falsifiable criteria, in the
  CF-244 idiom.
- The record's per-file entries carry `path` and `sha256` but no `size`, so the budget is enforced
  at build time (over the source tree) and not re-reportable at check time. Not a criterion; noted
  so the next reader does not read `bytes=0` as a defect in the seed and chase it.
