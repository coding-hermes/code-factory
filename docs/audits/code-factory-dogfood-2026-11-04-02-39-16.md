# code-factory dogfood walk — 2026-11-04 (tick code-factory-dogfood-2026-11-04-02-39-16)

Lane: `code-factory-dogfood`. Job: walk the documented path as a user would, from a clean state,
and report where the docs and the behaviour disagree.

Published tip walked: **c29c024**. The first arms ran at f26a608;
`git diff --name-only f26a608 c29c024 -- scripts/ README.md` returns **0 files**, so every
measurement below holds at c29c024 too. Only board, docs and verdict files moved between the two.
A sibling then landed `23c1c6d fix(node-create): forward CRIER_URL into the node and refuse an
unset bus before spawn` (CF-126) while this row was being filed; the row was rebound onto that tip
and **both arms were re-run at 23c1c6d, unchanged** (`unknown arg: --ref`, rc=2; `NODE: FAIL (1)`
with `ref 'main' was not found`). This commit's diff touches only the board and this audit file —
no script — so the CF-126 fix is not part of it and its own claim is unaffected.

Result this tick: **one new row filed, CF-153**; no defect found in the other legs walked.

## 0. Identity and policy position

- Locator `/home/kara/code-factory`: `realpath` = `git rev-parse --show-toplevel` = the locator.
  Root equality PASS. Branch `main` attached; no `MERGE_HEAD`/`REBASE_HEAD`/`CHERRY_PICK_HEAD`/
  `REVERT_HEAD`/sequencer. `.git/AUTO_MERGE` (41 bytes, tree d2834400…, 2026-11-03 21:49:57) is
  residue from the merge that produced f26a608, recorded and left in place.
- `.coding-hermes/board/.lock`: 0 bytes, mtime 2026-11-03 07:40, `fuser` → **no holder**,
  `grep -rn 'flock\|fcntl' scripts/boardctl*` → **no consumer**. By this repo's own test that is
  residue, not an ownership barrier.
- Porcelain `--untracked-files=all`: 51 paths, every one `??` — `.coding-hermes/board/.lock` plus
  50 `.gitreins/history/**` bundles. **Zero tracked edits.**
- **Family barrier:** sibling lane `code-factory` is `status=running` in this same checkout
  (`latest_tick.id=code-factory-2026-11-04-02-39-16`) and landed four commits on origin/main
  during this walk; `code-factory-docs` was also `running` at close. Nothing in this tick read
  project state from the dirty candidate: the walk ran from `git archive origin/main` plus one
  clean `git clone`, and the board row was filed in that clone and pushed to the published remote.

## 1. Quick start, verbatim, with the two exported values the README tells you to set

README.md:17-30, run under `env -i` with a fresh empty HOME and the README's own example values.

| Step | Command | Result | Names the missing value? |
|---|---|---|---|
| 1 | `scripts/bunker-server-install.sh --check` | rc=1, `RESULT: FAIL (2)` | Yes — `FAIL bunker_config — missing (…/config.yaml)`, `FAIL server_reachable — your-bunker-server did not answer` |
| 2 | `./scripts/project-node.sh --check --project myproject` | rc=1, `NODE: FAIL (4)` | Yes — `reach:http://crier.example:8767/health -> 000`, `python`, `crier_identity`, `repo absent (pass --repo to clone)` |
| 3 | `scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` | rc=1 | Yes — `FAIL spawn — bunker: server "your-bunker-server" not found in config` |

With the variables set as README.md:19-20 instructs, all three reach a checker and name the value
they lack. CF-145 owns the other env state (variables unset → `${VAR:?}` aborts at
`bunker-server-install.sh:14` and `node-create.sh:70`); that abort does not reproduce when the
operator does what the README says, so this walk does not re-file it.

Step 2 output ordering, not filed: `PASS disk_floor — 5 GiB from role-default` prints before the
`node provisioning — project=…` header.

## 2. Filed: CF-153 — the create path cannot honour the remedy its own error prints

```
$ BUNKER_SERVER=no-such-server bash scripts/node-create.sh --project p \
      --repo https://github.com/git/git --harness hermes --ref master
unknown arg: --ref
rc=2
```

```
$ HOME=$(mktemp -d) bash scripts/project-node.sh --apply --layers 40 --project refproof \
      --repo https://github.com/git/git
[40] repo
  ..    cloning https://github.com/git/git @ main
  FAIL  repo_clone — ref 'main' was not found; pass --ref <branch-or-tag>
NODE: FAIL (1)
```

The node names `--ref` as the remedy; the control-host command the README gives for creating a node
rejects that flag. From the tree: `project-node.sh:33` reads `NODE_REF` (default `main`) and `:53`
accepts `--ref`; `node-create.sh:56-67` parses no ref at all, and `:103` forwards only
`NODE_PROJECT` and `NODE_GATEWAY_PORT` into the node, so neither the flag nor the variable can
cross. `README.md:80-81` tells the reader `--ref <branch>` is what a non-`main` default branch
needs.

Both arms above are the row's own probe, run from the repo root; it prints
`unknown arg: --ref`, `arm_create_rc=2`, and `NODE: FAIL (1)` on the current tree.

## 3. Node-creation leg — host answered, leg not driven

`bunker info dogfood-reachability-probe-nonexistent --server bunker-las-03` →
`bunker: get agent: not_found` ⇒ the server is reachable. The real-node create was still not
driven: CF-126 already carries a full real-node transcript for the `CRIER_URL` handoff (2026-11-03,
01eb0cf), and a second create here would spend a remote agent to re-measure a row that is already
pending. CF-075 (disk_floor.py not staged) is **verified fixed** without a host:
`scripts/node-create.sh --staged-files` prints exactly `project-node.sh`, `lib.sh`,
`disk_floor.py`, `reclaim_disk.py`, `harness/install-hermes.sh`, rc=0.

## 4. Gate

- `bash tests/selftest.sh` at c29c024 in the `git clone`: **`SELFTEST: PASS`**, rc=0. The 19
  `  FAIL` lines in the output are the named negative-fixture rows, which is the point of the gate.
- The same gate in the `git archive` copy: `SELFTEST: FAIL (1)` — §17's pre-fix detector control
  needs history and prints `fatal: not a git repository` → `FAIL pre-fix source unavailable`.
  That is a property of the archive transport, **not** a product defect; it is why this audit's
  gate reading comes from the clone.
- `scripts/boardctl validate` with no fleet `boardctl` on PATH: rc=127,
  `FAIL boardctl: coding-hermes boardctl executable not found on PATH` plus a pointer to
  `docs/BOARD.md`. Matches the layout table's "fails closed" claim — no finding.
- `scripts/boardctl validate` after the filing: `RESULT: OK (56 warning(s))`, the `probe`-key
  warnings being this board's documented shape.

## 5. Filing invariants (quoted from the appender)

`append_board_rows.py` against the clean clone reported:

```
delta=0 width=3 assigning ['CF-153']
rows 126 -> 127 (+1)
prefix_bytes_identical=True unique_ids=127 duplicates=0
readback CF-153 status=pending probe_len=537 ac_len=1598
events=191 last=task_created task=CF-153
```

Next free id was re-verified against the published board immediately before the append
(max `CF-` id = 152, no duplicate ids).

## 6. What a new user would have done next

Nothing on this path is silent — that is the repo's real strength. The trap is narrower and worse:
the messages are right, but the next command does not exist. Step 3 cannot take `--ref`, and the
node's own failure hands the operator a flag only the in-node script understands. A stranger with a
`master`-default repo would try `--ref` on step 3, read `unknown arg`, and conclude the factory
cannot host their repository.
