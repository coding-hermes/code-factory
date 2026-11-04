# docs lane — the runbook's "unless `--server`" branch does not exist (CF-167)

- **Lane:** `code-factory-docs`, tick `code-factory-docs-2026-11-04-06-11-13` (scheduler workdir `/home/kara/code-factory`)
- **Transport:** fresh clone of the published ref `gh/main` = `9b7fb6f`, because sibling lanes held the registered checkout (see "Transport" below). The registered checkout was not written to.
- **Claim class:** a documented command line that fails as written — the same class CF-009, CF-041 and CF-145 closed for the quick start and `node-create.sh`, left behind in the runbook's dispatch-verification step.
- **Owner of the code-side fix:** CF-063 (pending) owns relaxing `verify-node.sh`'s pre-parse guard. This row owns the prose that currently promises a branch the script does not have.

## 1. The claim, before and after

| # | File:line | Before (shipped claim) | After (measured statement) |
|---|---|---|---|
| 1 | `docs/OPERATIONS.md:127` (§6 step 3) | "Required environment: `BUNKER_SERVER` unless `--server` is supplied." | `BUNKER_SERVER` must be set even with `--server`; `scripts/verify-node.sh:17` expands `${BUNKER_SERVER:?…}` before the argument loop at `:18-26` parses `--server` (`:21`), so the flag cannot satisfy the guard; the unset case dies at `:17` with the named message and exit 1. |
| 2 | `docs/OPERATIONS.md:195` (§11 tracked-command inventory) | boundary cell: "Does not verify crier, scheduler, inference, or task completion." — the invocation is listed with `--server NAME` and no environment precondition | boundary cell now names the requirement: `BUNKER_SERVER` must be set even when `--server` is passed (`scripts/verify-node.sh:17`, guarded before the argument loop). |

Both surfaces carry the same false implication, so both were corrected in one commit: §6 is the operator recipe and §11 is the inventory an operator greps when the recipe is not at hand.

## 2. The code path that proves the new statement

`scripts/verify-node.sh` at `9b7fb6f`:

```
17:AGENT="" SERVER="${BUNKER_SERVER:?set BUNKER_SERVER to your bunker server name}" PORT=10800 ARTIFACT=""
18:while [ $# -gt 0 ]; do
19:  case "$1" in
20:    --agent) AGENT="$2"; shift 2 ;;
21:    --server) SERVER="$2"; shift 2 ;;
22:    --port) PORT="$2"; shift 2 ;;
23:    --artifact) ARTIFACT="$2"; shift 2 ;;
24:    *) echo "unknown arg: $1" >&2; exit 2 ;;
25:  esac
26:done
```

Line 17 is a plain assignment, so the shell performs the `${BUNKER_SERVER:?…}` expansion while executing that line — before line 18's loop reads `argv`. `--server` is therefore parsed only on a run that already had `BUNKER_SERVER` in the environment, and it can only *overwrite* a server name the environment already supplied. There is no code path in which the flag substitutes for the variable.

## 3. Literal output (two arms, opposite structures)

Arm A — the documented branch, run with the variable absent:

```
$ env -u BUNKER_SERVER ./scripts/verify-node.sh --agent probe-agent --server some-server --port 10800
./scripts/verify-node.sh: line 17: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name
RC=1
```

Note the *structural* difference, not just the exit code: the script never prints its `verify node probe-agent` banner, i.e. it never reaches its own body. The run costs one shell line.

Arm B — control, same command with the variable present:

```
$ BUNKER_SERVER=some-server ./scripts/verify-node.sh --agent probe-agent --server some-server --port 10800
verify node probe-agent
  FAIL  agent_alive — bunker: server "some-server" not found in config

RESULT: FAIL
RC=1
```

Arm B proves the only thing this claim needs: with the variable set the script runs, reaching the `agent_alive` probe (which fails here because the server name is a placeholder). The two arms differ in *where* they stop — line 17 versus the first probe — so the correction describes the shipped control flow rather than restating `--help`.

## 4. Selection notes (why this claim, and what it is not)

- Every other public claim I executed first came back **true**, and is recorded here so the next tick does not re-test them:
  - `README.md:73` / `:75` re-run commands (`scripts/harness/install-hermes.sh --check` on default `python3` → exactly one row, `FAIL python`, rc 1; with `HERMES_PYTHON_BIN=python3.12` → `python`, `binary`, `version`, `port`, `inference_key`, `HERMES: FAIL (1)`, rc 1 — five rows, matching the README's "five on a host where `~/.local/bin/hermes` exists").
  - README quick start on a bare control host: `scripts/bunker-server-install.sh --check` → `RESULT: FAIL (2)` with `FAIL bunker_config` and `FAIL server_reachable` named, and `./scripts/project-node.sh --check --project myproject` → `NODE: FAIL (4)` with `FAIL reach:…/health`, `FAIL crier_identity`, `FAIL repo`, `FAIL python` named. "all three commands reach their checkers and fail with the missing value named" holds for the two that can run here.
  - `docs/BOARD.md` §"Board lock adjudication" against `scripts/board_lock.py`: `ABSENT` (rc 0), `RESIDUE consumers=0 commits_after_mtime=unknown` (one line, rc 0), `HELD holder=<pid>` for a live exclusive `flock`, and `HELD` for a mere read-only open (which is what CF-158 tracks as the adjudicator's remaining false positive, not a doc error). The registered checkout's own `.coding-hermes/board/.lock` reads `RESIDUE consumers=0 commits_after_mtime=147` — 147 board commits after its mtime, i.e. residue, not a held lock.
- This is **not** a re-filing of CF-063. CF-063 says the script cannot print its usage before `BUNKER_SERVER` is set and rejects `--help`; it says nothing about the runbook sentence that offers `--server` as a substitute. If CF-063 lands, the corrected prose becomes stale in the safe direction (it will over-promise less, not more), and the row that closes CF-063 should re-open this sentence.

## 5. Claims I could not verify

- **`--server` behaviour after CF-063 lands:** not measured. The corrected sentence describes the tree at `9b7fb6f`; whether the flag becomes self-sufficient is the outcome of a pending row, so it is not written here as behaviour.
- **Whether any operator has actually used the `--server`-without-env form:** not measured — no telemetry exists for this script in the repo.
- **Effective gateway auth correctness and any live dispatch round trip:** not measured by this tick and not touched by this claim (`docs/OPERATIONS.md` §6 already says so).

## 6. Gate — red at the selection tip, repaired mid-tick, green at this commit

At the tip this claim was selected from (`9b7fb6f`), the suite was RED, and not for anything in this diff:

```
$ bash tests/selftest.sh     # detached worktree of gh/main 9b7fb6f, porcelain 0
  FAIL  audit-scope: docs/audits/code-factory-releng-2026-11-04-CF-163-AC3.md:39 gitleaks claim names no --log-opts
  FAIL  audit-scope: docs/audits/code-factory-releng-2026-11-04-CF-163-AC3.md:77 gitleaks claim names no --log-opts
SELFTEST: FAIL (1)           # rc 1
```

That gate was repaired while this tick ran, by a sibling landing that is not mine: `8995064 docs(releng): restore the audit-scope gate on the published tip (CF-163 AC3)`. This commit was then rebased onto the new tip (`92cfee9`), and the gate re-run at the rebased head:

```
$ bash tests/selftest.sh     # this clone, at the commit that carries this file
PASS  141/141 rows parse
SELFTEST: PASS               # rc 0
$ bash scripts/boardctl validate
RESULT: OK (3 warning(s))    # CF-034 free-form guard/ci prose + headerless board, both pre-existing
```

The `FAIL  2 of 3 rows parse` lines the suite also prints are inside its own negative fixtures, which assert the failing arm — the suite's documented convention is to read `SELFTEST:` and the section verdicts, never a raw count of `FAIL` lines.

Two things this section deliberately does not claim: that the suite was green at `9b7fb6f` (it was not), and that any pre-commit hook graded this commit (this clone has none — see the commit message).


ch:trace row=CF-167 spec=none:claim-lives-in-runbook wave=none:single-lane-tick test=tests/selftest.sh::full-suite doc=docs/OPERATIONS.md prompt=prompts/docs.md evidence=docs/audits/code-factory-docs-2026-11-04-verify-env.md witness=env -u BUNKER_SERVER ./scripts/verify-node.sh --agent probe-agent --server some-server --port 10800 verdict=CF-167-DOC2 commit=none:this-commit-carries-the-fix memory=/code-factory/tick/docs/2026-11-04-0611

STATUS: T3 — the claim was executed, corrected in the shipped doc, and the corrected sentence's command was run against the tree that carries it
TIER: T3 — witness command run in this tick with both arms quoted in §3; `scripts/boardctl validate` OK; `tests/selftest.sh` is RED at the base tip for a sibling-owned file and unchanged by this commit (§6) — **not** a green gate
EVIDENCE: §2–§3 (code path and both arm transcripts) and §6 (gate, with the base-tip proof); row CF-167 carries the same probe

