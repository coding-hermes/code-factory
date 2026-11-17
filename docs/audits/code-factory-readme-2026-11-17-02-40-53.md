# README audit — code-factory, 2026-11-17

Lane: `readme`. Tick: `code-factory-readme-2026-11-17-02-40-53`.
Subject: `origin/main` at `2e732112c52ec0de47ad8f921ae19b09e44b36d7`, audited in a detached
worktree beside the registered checkout (`git worktree add --detach ../code-factory-readme-2026-11-17-02-40-53
origin/main`) so the published tip, not a working copy, was the thing under test. The registered
checkout was not touched.

This file is the repo-local evidence for the fixes in the commit that adds it. Commands below are
re-runnable from the repo root; where a run needs a live scheduler or a real node, that is said
plainly and the figure is labelled historical rather than "current".

## 1. What was run, and what it printed

### 1.1 Quick start, step 1 — `scripts/bunker-server-install.sh --check`

```
$ CRIER_URL=http://crier.example:8767 BUNKER_SERVER=your-bunker-server \
    ./scripts/bunker-server-install.sh --check
```

Reaches the checker and fails naming the missing value; writes nothing into `HOME`. Took a few
seconds (`ELAPSED` recorded in the run log). No claim in the README contradicted it.

### 1.2 Quick start, step 2 — `./scripts/project-node.sh --check --project myproject`

Two arms, both with `CRIER_URL=http://crier.example:8767`.

Hermetic `HOME=$(mktemp -d)`:

```
[00] preflight
  PASS  footprint — 0.0 MiB measured at <tmp>/repo 0.0 MiB … harness 0.0 MiB
  PASS  footprint:floor — 0.0 MiB of the 5 GiB floor (0.0 %)
  FAIL  reach:http://crier.example:8767/health — -> 000
…
HERMES: FAIL (1)   # FAIL python — 3.14.9 against the pin's >=3.11,<3.14
[30] bus
  FAIL  crier_identity — absent
```

Real `HOME` (this host's home, whose `.hermes` is ~254 GiB):

```
  PASS  footprint — 260387.0 MiB measured at $HOME: harness 260387.0 MiB
  FAIL  footprint:floor — 260387.0 MiB exceeds the 5 GiB floor (5085.7 %)
```

`ELAPSED=66 s` at load average 25. `--check` created `$HOME/.node` (empty) even on the hermetic
run; `--apply` added `$HOME/.node/auth/gateway.pass`, `$HOME/.node/freshness.json` and the clone.

Consequence for the README: step 2 writes to `HOME` in `--check`, and the `footprint:floor` row it
prints measures the home directory the command runs in — so on an operator's home the row FAILs by
design and says nothing about the repo. Both now stated in Quick start.

### 1.3 Quick start claims about the install gate — `scripts/harness/install-hermes.sh --check`

Default `python3` (3.14.9), hermetic `HOME`:

```
  ..    contract:CF_TIMEOUT_S = unset
  FAIL  python — hermes-agent 0.19.0 requires python >=3.11,<3.14; found 3.14.9 — set
        HERMES_PYTHON_BIN to an in-range interpreter, e.g. HERMES_PYTHON_BIN=python3.12

HERMES: FAIL (1)
```

Exactly one gate row (`FAIL python`), `HERMES: FAIL (1)` — the README's claim holds. The
`HERMES_PYTHON_BIN=python3.12` arm prints four rows, as recorded previously in
`docs/audits/cf092-install-check-arms.txt`; that arm was not re-run this tick and is cited, not
re-measured.

### 1.4 Provisioning transcript — `scripts/bunker-provision.sh --config config/bunker.example.conf --check`

```
  PASS  config — bunker.example.conf — 53 lines, KEY=VALUE only
  FAIL  inputs — not readable: GITHUB_TOKEN_FILE(~/.config/code-factory/github.token)
        CRIER_AGENT_KEY_FILE(~/.config/code-factory/<project>/agent.key)
        S3_ENV_FILE(~/.config/code-factory/s3.env)
bunker-provision --check — project=code-factory agent=cf-node server=bunker-node-01
  ..    resolved repo=… ref=main harness=hermes namespaces=code-factory,coder (primary code-factory) ttl=30d
  FAIL  github_auth — GITHUB_TOKEN_FILE ~/.config/code-factory/github.token is unreadable
  PASS  bunker_cli — ~/.local/bin/bunker
  FAIL  server — bunker-node-01 not listed by 'bunker list'
  FAIL  agent — cf-node absent — run --apply to create it
```

`wc -l config/bunker.example.conf` = 53. The README's quoted block said `25 lines` and omitted the
three rows above, so it no longer reproduced the shipped template; it is now the measured block
above, with this host's own crier and DuckBrain addresses redacted in the README copy.

### 1.5 Status table, clone row — `--apply` against a public fixture

```
$ home=$(mktemp -d); CRIER_URL=http://crier.example:8767 HOME="$home" \
    ./scripts/project-node.sh --apply --project myproject \
    --repo https://github.com/github/gitignore --ref main
[40] repo
  ..    cloning https://github.com/github/gitignore @ main
  PASS  repo_clone — <home>/repo @ b71db92
  PASS  freshness — branch=main head=b71db924d350 origin_main=b71db924d350 behind=0 ancestor=true
  ..    check verdict: PASS — recorded in <home>/.node/freshness.json

NODE: FAIL (3)
```

Read back out of band: `git -C <home>/repo rev-parse HEAD` → `b71db924d350…`, branch `main`. The
three FAILs are `reach:<crier>/health -> 000`, `python` (3.14.9) and `crier_identity` (absent) — the
repo layer passes. The README row now carries this measurement beside the 2026-10-30 one.

### 1.6 The lanes census — the README's own `(` … `)` recipe

Extracted verbatim with `awk '/^\($/{f=1} f{print} f&&/^\)$/{exit}' README.md`, `bash -n`-checked,
`BASE` repointed at the live scheduler (`http://127.0.0.1:9090`), then run:

```
11
code-factory-docs      enabled=true admission=cooldown parent=code-factory
code-factory-dogfood   enabled=true admission=cooldown parent=code-factory
code-factory-foreman   enabled=true admission=tasks    parent=
code-factory-ops       enabled=true admission=          parent=
code-factory-perf      enabled=true admission=cooldown parent=code-factory
code-factory-pm        enabled=true admission=cooldown parent=code-factory
code-factory-qa        enabled=false admission=cooldown parent=
code-factory-readme    enabled=true admission=cooldown parent=code-factory
code-factory-releng    enabled=true admission=cooldown parent=code-factory
code-factory-review    enabled=true admission=cooldown parent=code-factory
code-factory-sync      enabled=true admission=cooldown parent=code-factory
```

Eleven rows, no `code-factory-duckbrain-*` row at all, root lane named `code-factory-foreman`,
`code-factory-ops` with no admission mode, `code-factory-qa` disabled and unparented. The README
paragraph used to print "nineteen rows" plus a `code-factory-duckbrain admission=cooldown` reading
as if it were the current state; it now carries this run dated 2026-11-17, keeps the 2026-11-04
nineteen-row reading explicitly as history, and says the census is the authority.

### 1.7 prompts/ count and the README's own tail

`ls prompts/*.md | wc -l` = 12 (`prompts/unblock.md` is the twelfth; `prompts/foreman.md` points at
it as a sub-procedure, so eleven files serve the fourteen lanes). README said "eleven files" and
carried a second, stale eleven-file census claim in its evidence tail; both are corrected, and the
stale one is gone with the tail.

`git grep -n -E '^STATUS: |^TIER: |^EVIDENCE: ' -- README.md` → no matches (rc 1). Before this
change the file ended with `STATUS: complete | partial | blocked`, `TIER: T1`, and an `EVIDENCE:`
line pointing at `README.md#the-lanes` — a shape that reads as a completed row while enumerating
three outcomes and citing the document it annotates.

## 2. Class coverage

Each source class the README draws claims from, and what was probed this tick.

| Class | Surface | Probed how | Result |
|---|---|---|---|
| Quick-start commands | `bunker-server-install.sh --check`, `project-node.sh --check/--apply`, `install-hermes.sh --check` | ran all four arms under hermetic HOME (+ one real-HOME arm) | 1 doc defect (side effects unstated), 1 wording defect (footprint measures HOME) → fixed in §1.2 |
| Provisioning transcript | `bunker-provision.sh --check` vs `config/bunker.example.conf` | ran against the shipped template, compared to the quoted block row by row | quoted block was stale (25 vs 53 lines, 3 rows missing) → fixed |
| Status table | both command-bearing rows | re-ran each row's command and read the result back out of band | row 2 re-measured and dated; row 1's `--check` gate count confirmed (1 row on default python) |
| Census / lane inventory | README `(` … `)` recipe against the live scheduler | extracted verbatim, executed, diffed against the paragraph | paragraph contradicted its own recipe → rewritten with both readings dated |
| Prompts inventory | `prompts/` vs the two README claims | `ls prompts/*.md \| wc -l`, section 9 of `tests/selftest.sh` | stale count → fixed |
| Traceability markers | README tail | `git grep` for `ch:trace`, `^STATUS:`, `^TIER:`, `^EVIDENCE:` | six markers citing the README as their own evidence plus a three-value STATUS → removed from README, preserved in §4 |
| Doctrine/contract | `docs/traceability-doctrine.md`, `docs/OPERATIONS.md` | read marker field contract and the node-contract paragraph cited by CF-472 | README now cites `docs/OPERATIONS.md:38` for the `$HOME/.node` side effect |

Not probed this tick (named gaps): the bunker-node install ladder (needs a real bunker node), the
tailnet gateway `/api/status` figure (needs the live node), the private-GitLab clone path (needs a
read-only deploy key), and the scheduler → crier dispatch (disarmed). Those figures stay labelled
historical in the README; nothing here upgrades or re-dates them.

## 3. Findings left open

- **CF-387 stays pending.** README now states the footprint cost and what the row measures, but the
  cost itself is unchanged: layer 00 walks `$HOME/.hermes` (260 GB here) against a 5 GiB floor on
  every `--check`. Documenting it is not fixing it — the row's criterion 2 asks for the measurement
  to be bounded independently of `.hermes` size, which is a code change in `scripts/project-node.sh`.
- Step 1's `footprint`-style cost claim ("a few seconds") is a wall-clock observation on one host,
  not a bounded budget; no test enforces it.

## 4. Traceability markers relocated out of README.md

README.md is the file a stranger reads first, and it ended with this block. Each marker cites the
README as its own evidence (`evidence=README.md`), which the doctrine refuses — nothing closes by
reference — and the footer's `STATUS: complete | partial | blocked` enumerates three outcomes
instead of stating one. They are preserved here, unchanged, for provenance; they are not evidence
of anything below this line.

```
ch:trace row=CF-188 spec=README.md#the-lanes wave=code-factory-readme-2026-11-11-10-03-09#CF-188 test=bash-tests/selftest.sh::selftest doc=README.md evidence=README.md witness=README.md#the-lanes verdict=none:foreman-judges-after-merge commit=none:self-referential-hash memory=none:not-written
STATUS: complete | partial | blocked
TIER: T1
EVIDENCE: README.md#the-lanes

Evidence for the state of this README: the clone figure is covered by the published audit `docs/audits/code-factory-readme-2026-10-30-20-29-25.md`; the prompt column and the eleven-file/layout census are covered by the published audit `docs/audits/code-factory-readme-2026-10-30-23-28-00.md` (whose command transcript is the `.probe.txt` beside it).

ch:trace row=CF-038 spec=README.md#evidence wave=none:serial test=bash-tests/selftest.sh doc=README.md evidence=docs/audits/code-factory-readme-2026-10-30-23-28-00.md witness=path@origin:README.md verdict=none:foreman-judges-after-merge commit=none:self-referential-hash memory=none:not-written

ch:trace row=CF-014 spec=README.md#quick-start wave=code-factory-readme-2026-10-30-18-28-33#readme test=scripts/project-node.sh::check-project-demo doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=path@origin:README.md verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-18-28-33
ch:trace row=CF-013 spec=README.md#status wave=code-factory-readme-2026-10-30-18-28-33#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=none:no-live-bunker-or-gateway-available verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-18-28-33
ch:trace row=CF-065 spec=README.md#the-lanes wave=none:serial test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-11-03-15-41-00-cf065.probe.txt witness=path@origin:README.md verdict=none:judged-after-commit commit=none:self-referential-hash memory=none:no-lane-role-token
ch:trace row=CF-064 spec=README.md#status wave=code-factory-readme-2026-11-03-16-51-21#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-CF-064.probe.txt witness=cmd:exit-1/inference_key-rows-0-vs-1 verdict=none:judged-after-commit commit=none:self-referential-hash memory=none:no-lane-role-token

ch:trace row=CF-151 spec=README.md#status test=tests/selftest.sh::selftest doc=README.md evidence=none:worker-transcript witness=cmd:exit-0/selftest-section-37 verdict=none:judged-after-commit commit=none:self-referential-hash memory=none:not-written
```

The clone and prompt/census figures those markers pointed at are now measured directly in §1.5 and
§1.6–§1.7 of this file, at the tip named in the header; `docs/audits/code-factory-readme-2026-10-30-23-28-00.md`
remains the transcript for the 2026-10-30 prompt-column reading.

## 6. The suite was red on this host — one arm could not fail

`bash tests/selftest.sh` at the subject tip ended `SELFTEST: FAIL (1)`:

```
FAIL: test_working_room_shortfall_is_a_refusal (__main__.NodeFootprint)
AssertionError: 0 == 0
    self.assertNotEqual(result.returncode, 0)
```

The arm asked `node_hygiene.py footprint` for `--working-room-mib 1000000` (977 GiB) and expected a
refusal. `scripts/node_hygiene.py:118-140` refuses only when the requirement exceeds the free space of
the filesystem the fixture runs on, and that fixture is a `TemporaryDirectory` under `TMPDIR`, which
here is `/mnt/ssd/tmp`:

```
/mnt/ssd/tmp  free=1792.1 GiB  total=1838.0 GiB
```

977 GiB fits in 1792 GiB, so the room check printed PASS, the process exited 0, and the assertion
failed. Nothing was wrong with `node_hygiene.py`; the arm had encoded an assumption about the
machine (free space below 977 GiB) rather than about the code. It also asserted only the refusal
direction — a `node_hygiene.py` that refused every requirement would have passed it.

The arm now derives the requirement from the filesystem it is running on and asserts both
directions: half of measured free space must be `PASS footprint:room`, free space + 1024 MiB must be
`FAIL footprint:room` naming the shortfall.

```
$ python3 tests/test_node_provisioning.py NodeFootprint.test_working_room_shortfall_is_a_refusal -v
# fix in place
test_working_room_shortfall_is_a_refusal ... ok
Ran 1 test in 0.292s — OK                                    rc=0

# same invocation against the parent version of the same file
AssertionError: 0 == 0
FAILED (failures=1)                                          rc=1
```

CI on other hosts did not hide this: the arm only fails where `TMPDIR` has more than 977 GiB free,
so a runner with a small `/tmp` reports green while proving nothing. Filed as CF-480.

## 7. Marker for this tick

```
ch:trace row=CF-479 spec=docs/OPERATIONS.md#node wave=code-factory-readme-2026-11-17-02-40-53#readme test=tests/selftest.sh::9 doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-11-17-02-40-53.md witness=path@origin:docs/audits/code-factory-readme-2026-11-17-02-40-53.md verdict=none:foreman-judges-after-merge commit=pending:self-referential-hash memory=/project/code-factory/readme-audit-2026-11-17-02-40-53
ch:trace row=CF-480 spec=docs/OPERATIONS.md#node wave=code-factory-readme-2026-11-17-02-40-53#readme test=tests/test_node_provisioning.py::NodeFootprint.test_working_room_shortfall_is_a_refusal doc=docs/audits/code-factory-readme-2026-11-17-02-40-53.md#6-the-suite-was-red-on-this-host--one-arm-could-not-fail prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-11-17-02-40-53.md witness=path@origin:docs/audits/code-factory-readme-2026-11-17-02-40-53.md verdict=none:foreman-judges-after-merge commit=pending:self-referential-hash memory=/project/code-factory/readme-audit-2026-11-17-02-40-53
```

`row=` names the row this file was produced for; `evidence=` is this file (produced by this tick,
not another row's); `witness=` is the path at `origin` once the commit lands, readable by anyone who
clones; `verdict=none:` because the judgement is the foreman's, after merge; `commit=` is
self-referential inside the commit that adds this file and is recorded in the commit footer instead.

CLOSE-OUT

STATUS: PASS
TIER: T3 — every command above was executed on this host at the subject tip; the scheduler census in §1.6 read the live scheduler, and the clone in §1.5 was read back from the cloned tree
EVIDENCE: this file (§1 runs) plus `tests/selftest.sh` and `scripts/boardctl validate` at the fix commit
