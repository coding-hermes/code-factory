# README lane — command transcript, tick `code-factory-readme-2026-11-04-07-18-14`

**Lane:** code-factory / readme. **Repo:** `coding-hermes/code-factory`.
**Measured on:** the registered checkout, branch `main`, at the published tip `20f93ad`
(parity `origin/main...HEAD` = 0 0 at tick start; `git ls-remote origin refs/heads/main` agreed).
**Gate at that tip before this tick's work:** `bash tests/selftest.sh` → `SELFTEST: PASS`, rc 0,
34 numbered sections, 107 `PASS` rows, 19 intentional negative-fixture `FAIL` rows, 16 s.

The lane's job is the stranger-facing path: run what the README tells a reader to run, and report
where it fails or promises more than the code does.

## 1. Quick start — every command, run literally

`CRIER_URL` and `BUNKER_SERVER` were set to the README's own example values. Commands are quoted
exactly as the README gives them.

| # | Command (README Quick start) | Observed | Verdict |
|---|---|---|---|
| 1 | `scripts/bunker-server-install.sh --check` | `FAIL server_reachable — your-bunker-server did not answer: bunker: reading server "your-bunker-server"`, `RESULT: FAIL (2)`, rc 1 | **honest** — fails with the missing value named, as the README's fresh-host paragraph promises |
| 2 | `./scripts/project-node.sh --check --project myproject` | `FAIL crier_identity — absent …`, `FAIL repo — … absent (pass --repo to clone)`, `NODE: FAIL (4)`, rc 1 | **honest** — four named FAIL rows, no bootstrap crash |
| 3 | `scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` | with the two example exports in place: `node-create — project=myrepo harness=hermes server=your-bunker-server`, `..    spawning node-myrepo-… (ttl 6h)`, `FAIL spawn — bunker: server "your-bunker-server" not found in config`, rc 1. Without `CRIER_URL` it stops earlier at `FAIL crier_url`. | **honest** — fails with the missing value named and spawns nothing |

The fresh-host paragraph at README:32-34 ("all three commands reach their checkers and fail with the
missing value named") reproduces. Two of the three commands were also re-verified in this tick under
`env -i`-style conditions by earlier lanes (CF-145, CF-126); nothing in this run contradicts them.

## 2. The defect this tick closed (CF-153)

**The README offered a remedy no shipped command accepted.**

Reproduction at `20f93ad`, before the fix:

```
$ bash scripts/node-create.sh --staged-files --ref master
unknown arg: --ref
rc=2

$ BUNKER_SERVER=no-such-server bash scripts/node-create.sh --project p \
    --repo https://github.com/git/git --harness hermes --ref master
unknown arg: --ref
rc=2

$ HOME=$(mktemp -d) bash scripts/project-node.sh --apply --layers 40 \
    --project p --repo https://github.com/git/git
[40] repo
  ..    cloning https://github.com/git/git @ main
  FAIL  repo_clone — ref 'main' was not found; pass --ref <branch-or-tag>
NODE: FAIL (1)
```

The node-side checker told the operator to pass `--ref`; the documented control-host create command
(Quick start step 3) rejected that exact flag, and README:80-81 told the reader the same thing the
flag parser refused. `scripts/project-node.sh` supported the flag all along
(`REF="${NODE_REF:-main}"`, `--ref) REF="$2"`, `git clone --depth 1 --branch "$REF"`);
`scripts/node-create.sh` simply never parsed it and never forwarded it into the node's payload.

After the fix (implementation commit `a112726`):

```
$ bash scripts/node-create.sh --staged-files --ref master
project-node.sh
lib.sh
disk_floor.py
reclaim_disk.py
harness/install-hermes.sh
rc=0                                   # unchanged five-file staged set

$ BUNKER_SERVER=no-such-server bash scripts/node-create.sh --project p \
    --repo https://github.com/git/git --harness hermes --ref master
FAIL  crier_url — CRIER_URL unset or empty — export CRIER_URL=http://crier.example:8767
rc=1                                   # reaches the create path; no 'unknown arg'

$ HOME=$(mktemp -d) bash scripts/project-node.sh --apply --layers 40 \
    --project p --repo https://github.com/git/git --ref master
[40] repo
  ..    cloning https://github.com/git/git @ master
  PASS  repo_clone — …/repo @ 750f5de
NODE: PASS
rc=0
```

Red-before-green, both arms, on artefacts that survive:

- **Pre-fix copy of the script** (preserved from `20f93ad:scripts/node-create.sh`): the same
  `--staged-files --ref master` invocation prints `unknown arg: --ref`, **rc 2**. The no-flag
  invocation still exits 0, so the arm measures the ref and not the script's health.
- **New gate arm** `tests/selftest.sh` §35 asserts the post-fix behaviour; it therefore fails on
  the pre-fix tree.
- **Forwarding** is asserted on recorded bytes with a stub `bunker` transport (no network, no agent,
  no install): the node-side payload carries `--ref 'master'`, and a ref containing a quote crosses
  as `--ref 're'\''lease'` — the same single-quote escaping the file already applied to `CRIER_URL`.

README now points at the reachable remedy: step 3 shows where `--ref` goes, and the paragraph at
README:82-86 says the step 3 command forwards it.

## 3. Status table — what can still contradict a row

Row 3 (*Node inference credential* → `**missing**`) cites
`HERMES_PYTHON_BIN=python3.12 scripts/harness/install-hermes.sh --check`. Run on this control host:

```
$ HERMES_PYTHON_BIN=python3.12 scripts/harness/install-hermes.sh --check
  PASS  python — 3.12.13 (hermes-agent 0.19.0 requires >=3.11,<3.14)
  PASS  binary — ~/.local/bin/hermes
  PASS  version — Hermes Agent v0.22.5+3030.g770a952 …
  FAIL  port — nothing on :10800
  PASS  inference_key — a provider key is present in ~/.hermes/.env (value not read)
```

The row's cited command reports **PASS** for the exact gate the row calls missing, because it
inspects the **control host's** `~/.hermes/.env`, not a node's credential. Row 3's state cell and
its re-run cell therefore describe different machines: on a keyed host the row can never be
contradicted by the command it prints, and it can never be confirmed either. Filed and still open as
**CF-151** (this lane did not reword it — one row per tick, and CF-153 was the higher-priority
P3). Row 1 already carries the same interpreter caveat honestly and names both arms.

## 4. Wording that promised more than the code does

| Text | Claim | Measured |
|---|---|---|
| README:80-81, before this tick | `--ref <branch>` is the remedy for a non-`main` default branch | The only documented create command rejected `--ref`. **Fixed** (CF-153, `a112726`). |
| README:73, Status row 1 | `works (historical measurement)` for the Hermes adapter | Honest: it labels the audit as historical, states the command cannot reproduce it from this repo alone, and records both interpreter arms. The default `python3` here (3.14) still prints only `FAIL python` — the row says so. |
| README:75, Status row 3 | `**missing**` node inference credential | Contradicted by the row's own command on a keyed control host (§3). Open as CF-151. |
| README:122-126, lanes | "Fourteen scheduler projects" | Honest: it defers the count to the census recipe and states that the recipe, not the paragraph, is the authority. |
| README:205-212, census reading | 19 rows, 13 of 14 `enabled=true`, `code-factory-duckbrain admission=tasks` | Dated (`2026-11-04`) and attributed to the command beside it; an observation about a live scheduler, not a repo property. |

## 5. Gates at the closing tree

| Gate | Command | Result |
|---|---|---|
| Shell syntax | `bash -n scripts/node-create.sh` | rc 0 |
| Suite | `bash tests/selftest.sh` | `SELFTEST: PASS`, rc 0, 35 numbered sections / 37 arms, 109 `PASS` rows, 19 intentional negative-fixture `FAIL` rows |
| Board | `bash scripts/boardctl validate` | `RESULT: OK (3 warning(s))`, rc 0 — warnings pre-existing (CF-034 free-form field, headerless board) |
| Staged set | `bash scripts/node-create.sh --staged-files` | rc 0, five files, unchanged by `--ref` |
| CI | `gh run list --repo coding-hermes/code-factory` | `[]` — this repo ships no `.github/workflows`; CI is **SKIP by design**, not green |
| GitReins | `gitreins task complete CF-153` | PASS, run `a516e16f`, bound to `a112726696b1c8afc34c012b2eed260db1ba42ee` = HEAD |

## 6. Board state at measurement

144 task rows / 264 events at `20f93ad` (88 pending, 48 complete, 8 in_progress before this tick's
close). Board bytes were identical to `git show origin/main:.coding-hermes/board/tasks.jsonl`
(`sha256 6444f8bd…`), so this lane read the published board, not a stale copy.

Re-runnable: every command above is copy-paste except `mktemp -d` paths and the example values the
README itself supplies.
