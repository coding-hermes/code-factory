# 19. scripts/install-gitreins.sh

| Field | Value |
|---|---|
| Path | `~/code-factory/scripts/install-gitreins.sh` — 180 lines, two modes in one file [scripts/install-gitreins.sh:1] |
| Repository | `code-factory` [scripts/install-gitreins.sh:2] |
| Revision | `e7cf075` — the `origin/main` tip every locator below was measured against (worktree `~/proj-wt-md-19b`, 2026-11-05); the file's own last-touching commit is `d4d3fb7` (2026-11-04, "the commit gate and the bus credentials belong on the bunker …") |
| Status | **VERIFIED — 218 locators, all resolve; facts cited** |

## 1. Purpose and why it matters

- What it is: the **node-side** half of the commit gate. `--check` is the default mode [scripts/install-gitreins.sh:26] and prints one named row per piece — `python3`, `pip`, `gitreins`, `config`, `hook`, `identity` — returning non-zero if any row failed [scripts/install-gitreins.sh:36-80]. `--apply` installs the binary at an exact pin into a `$HOME` venv, links it onto `PATH`, writes the pre-commit hook and sets the git identity, then re-runs `check` as its own acceptance proof [scripts/install-gitreins.sh:82-163] [scripts/install-gitreins.sh:161-162].
- Why the gate lives on the node at all: the foreman commits on the project's bunker, never on the control host [docs/master/_facts.md:12] (fact: FACT-01). The file's own header states the consequence — "without it the node writes commits nothing graded, and the control host only finds out when it pulls" [scripts/install-gitreins.sh:8-10].
- Why a venv and not `pip install --user`: Debian marks the system interpreter externally managed (PEP 668) [scripts/install-gitreins.sh:20-22]. **Measured on this host**: `/usr/lib/python3.14/EXTERNALLY-MANAGED` exists and `/usr/bin/python3 -m pip install --user …` answers `error: externally-managed-environment`. A dedicated venv under `$HOME` is the root-free route [scripts/install-gitreins.sh:23].
- Why pinned and not `curl | sh`: the version comes from the index at an exact pin, and the installed version is read back before it is trusted — "a version string is not evidence until it is measured" [scripts/install-gitreins.sh:12-13] [scripts/install-gitreins.sh:101-106].
- What breaks if it is ABSENT: node commits are ungraded, and the provisioning peer says so in its own rows — `FAIL  gitreins — absent on the node — commits from this host are ungraded` [scripts/bunker-provision.sh:245] and `FAIL  commit_hook — no pre-commit hook — the gate is not armed` [scripts/bunker-provision.sh:248]. The repo's suite also gates on the identity refusal, not on the install [tests/selftest.sh:2047-2052].
- What breaks if it LIES: the `hook` row is `test -x` plus `grep -q gitreins` — a text match, not an execution test [scripts/install-gitreins.sh:59-63]. That gap is **measured** (§6, defect D-1): `--apply` skipped installation because the pin was already on `PATH` [scripts/install-gitreins.sh:89-92], still wrote a hook pinned to a venv path that does not exist [scripts/install-gitreins.sh:134], and `--check` then printed `PASS  hook — pre-commit runs gitreins` [scripts/install-gitreins.sh:61] followed by `GITREINS: PASS — the gate is present on this node` [scripts/install-gitreins.sh:78] — while every commit in that repo died `No such file or directory`, exit 1.
- Second lie surface: the script never invokes `gitreins install` or `gitreins init`; the heredoc at [scripts/install-gitreins.sh:124-136] is the only hook producer in the file. A repo that has a hook but no `.gitreins/config.yaml` therefore takes the hook's own early exit [scripts/install-gitreins.sh:130-132]: commits succeed, ungraded, while `--check` separately reports `FAIL  config` [scripts/install-gitreins.sh:58]. The gate's presence and the gate's arming are two different conditions and only the first is checked.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `bash` | 5.3.9 measured here; the script needs `set -uo pipefail`, `local` and unquoted-heredoc expansion [scripts/install-gitreins.sh:15] [scripts/install-gitreins.sh:124] | the interpreter on the shebang line [scripts/install-gitreins.sh:1] | **not detected** — the shell is already running by then; a `sh` without `pipefail` fails at line 15 before any row is printed |
| `python3` | 3.14.9 (harness venv) and 3.14.4 (`/usr/bin`) both measured here; nothing in the file pins a minimum | on `PATH` on the node | `command -v python3` — `FAIL  python3 — absent — gitreins is a python package`, then `return 1`, which hides the other five rows [scripts/install-gitreins.sh:40-41]; in `--apply` the same probe returns 1 with `absent — cannot install gitreins` [scripts/install-gitreins.sh:84] |
| `pip`, as `python3 -m pip` | 26.2.2 (venv interpreter) and 25.1.1 (`/usr/bin`) measured here | inside the interpreter that `python3` resolves to | `"$py" -m pip --version` captured on stdout — prints `FAIL  pip — python3 -m pip is unavailable — run 'python3 -m ensurepip --user'` **without returning**, so the run continues and fails later at the install [scripts/install-gitreins.sh:43-45] |
| `gitreins` at the pin | 0.17.1 (the pin) — measured as `gitreins 0.17.1` from `~/.local/bin/gitreins` | `$VENV/bin/gitreins` first, else `PATH` | `installed()` tries `$VENV/bin/gitreins --version` and falls back to `command -v gitreins`; the version is field 2 of `--version` [scripts/install-gitreins.sh:33-34]. Empty → `absent (no …/bin/gitreins and none on PATH) — run --apply`; different → `version <v> != pin <PIN>` [scripts/install-gitreins.sh:47-54] |
| `venv` module of that interpreter | stdlib | same interpreter | `"$py" -m venv "$VENV"` failing produces `FAIL  venv — python3 -m venv failed (python3-venv missing?)` and `return 1` [scripts/install-gitreins.sh:95] |
| `git` | 2.53.0 measured here | on `PATH`; it also supplies the repo state the hook runs in | **implicit and silent in `--check`**: `git config --global user.name|user.email` is read with `2>/dev/null || true` [scripts/install-gitreins.sh:69-70], so a missing git binary and an unset identity are the same row: `FAIL  identity — git user.name/user.email unset` [scripts/install-gitreins.sh:74]. In `--apply` the write is graded: `could not set user.name` [scripts/install-gitreins.sh:144-147] |
| `awk` | POSIX awk, unpinned | on `PATH` | **not detected** — used only to take field 2 of `--version` [scripts/install-gitreins.sh:33-34]; its absence makes the version empty, i.e. it presents as `gitreins absent` (§6) |
| `scripts/lib.sh` | the repo's own file, 65 lines [scripts/lib.sh:1] | `$HERE/lib.sh`, resolved from the script's own directory [scripts/install-gitreins.sh:16-17] | **not detected**: sourced without a guard [scripts/install-gitreins.sh:17]. Measured by copying the script alone into an empty directory — `lib.sh: No such file or directory`, then `say: command not found`, `ok: command not found`, `bad: command not found`, exit **1**. That is a bootstrap crash, not named rows |
| No network, socket, database or container | — | — | Verified by reading the whole file: the only outbound call is pip reaching the index through its own configuration [scripts/install-gitreins.sh:100]; the script opens no socket, reads no environment store and touches no service |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `. "$HERE/lib.sh"` [scripts/install-gitreins.sh:17] | `scripts/lib.sh` | Four helpers and one shared counter: `say` = `printf '%s\n'` [scripts/lib.sh:5], `ok` = `  PASS  %s — %s` [scripts/lib.sh:6], `bad` = `  FAIL  %s — %s` **and** `FAILED=$((FAILED+1))` [scripts/lib.sh:7], `note` = `  ..    %s` [scripts/lib.sh:9], and `FAILED=${FAILED:-0}` [scripts/lib.sh:11] | The script's only exit gate is `[ "$FAILED" -eq 0 ]` [scripts/install-gitreins.sh:79] and its only tally is `bad`'s side effect, so renaming `bad` or dropping the increment turns `GITREINS: FAIL (n)` into `GITREINS: PASS` with the FAIL rows still printed. A missing `lib.sh` is a crash (§2a) |
| `say` call sites | `lib.sh` | One line, no format arguments beyond `%s` | The header row [scripts/install-gitreins.sh:38] and the verdict row [scripts/install-gitreins.sh:77-78] are what an operator greps for |
| `ok` / `bad` call sites | `lib.sh` | Two-argument rows only: `<key>` and `<message>`; the em dash and spacing belong to `lib.sh`, not to this file | Any consumer that parses `  FAIL  ` [tests/selftest.sh:2049] or `identity — ` [tests/selftest.sh:2050] breaks |
| `gitreins --version` [scripts/install-gitreins.sh:33] | the gitreins CLI, 0.17.1 | Output is `<name> <version>`; the version is whitespace field 2 | Measured today: `gitreins 0.17.1`. A build that prints a bare `0.17.1`, or a decorated string, makes the pin comparison fail even at the right version [scripts/install-gitreins.sh:50-53] |
| `gitreins guard --quality-async` [scripts/install-gitreins.sh:134] | the gitreins CLI, 0.17.1 | The flag exists and means "run the repo-owned quality producer in the background instead of waiting for it" — verified from `gitreins guard --help` on this host | Removing or renaming the flag makes every commit in the repo fail closed at the hook; the hook has no version negotiation |
| `python3 -m pip install --upgrade --no-input "gitreins==$PIN"` [scripts/install-gitreins.sh:100] | pip | Exit status is the whole verdict; all output goes to `$HOME/.gitreins-install-$PIN.log` [scripts/install-gitreins.sh:98] so stdout of the installer stays clean | On failure the operator sees only `FAIL  install — pip exited <n> — log <path>` [scripts/install-gitreins.sh:108]; the reason is in the log, never on screen |

### 2c. Service contracts (both sides named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| Python package index | `pip` → index | HTTPS, pip's own auth/config; no URL in this file | `gitreins==0.17.1` pinned [scripts/install-gitreins.sh:19] [scripts/install-gitreins.sh:100] | The index resolver inside the venv's `pip`; on this host the venv interpreter is the only one that may install anything (PEP 668) [scripts/install-gitreins.sh:20-22] |
| `git commit` → repository hook | git → the hook file the script writes | `exec` of `.git/hooks/pre-commit`, cwd = repo root, exit status gates the commit [scripts/install-gitreins.sh:124-136] | Staged index is implicit; the hook reads `$REPO_ROOT/.gitreins/config.yaml` and exits 0 when it is absent [scripts/install-gitreins.sh:130-132] | `gitreins guard --quality-async` at the absolute venv path [scripts/install-gitreins.sh:134]. The other side of the *contract* is git's hook protocol itself; a live example with the same absolute-path pinning is the control-host hook `~/code-factory/.git/hooks/pre-commit` |
| `~/.gitconfig` | script → git config store | `git config --global` writes [scripts/install-gitreins.sh:144-147]; reads with `2>/dev/null \|\| true` [scripts/install-gitreins.sh:69-70] | `user.name`, `user.email`; optionally `CODING_HERMES_CO_AUTHOR` in a different store (below) | Consumer is git's commit path at commit time, and this script's own `check` on the next run — the only two readers |
| `$HOME/.hermes/.env` | script → file | append, created mode 600 [scripts/install-gitreins.sh:150-152] [scripts/install-gitreins.sh:156] | `CODING_HERMES_CO_AUTHOR=<Name <mail>>`, written once, guarded by `grep -q '^CODING_HERMES_CO_AUTHOR='` [scripts/install-gitreins.sh:153-157] | **No reader in this repository** — `grep -rn CODING_HERMES_CO_AUTHOR` over the tree returns exactly the four writer lines [scripts/install-gitreins.sh:153-157]. The consumer is outside this repo; nothing here proves it exists |
| `scripts/bunker-provision.sh` probe | control host → node, and control host → its own rows | `bunker exec -- bash -lc` running a heredoc that echoes `gitreins=` and `precommit=` [scripts/bunker-provision.sh:220-221] | Two of the same artifacts this installer produces | Graded at [scripts/bunker-provision.sh:245-248] as `gitreins` and `commit_hook`. This is a **duplicate** of rows 3 and 5 of `check` [scripts/install-gitreins.sh:47-64] — including a copy of `installed()`'s venv-then-PATH logic [scripts/bunker-provision.sh:220] — not a caller of this script |
| `tests/selftest.sh` | suite → script | `bash -n`, then `/bin/bash … --apply` with empty identity [tests/selftest.sh:2046-2047] | `--apply --repo <repo> --author-name "" --author-email ""` | Asserts non-zero exit and the substring `identity — --author-name and --author-email are required` [tests/selftest.sh:2048-2052] |

## 3. Verification

Run from a clean worktree of `e7cf075`, 2026-11-05. The commands below are the literal ones executed; the transcripts are the literal output.

| # | Check | Command | Expected | Last run | Result |
|---|---|---|---|---|---|
| 1 | The module's own gate, as a stranger runs it | `bash scripts/install-gitreins.sh --check` [scripts/install-gitreins.sh:177-178] | one row per piece, `GITREINS: PASS — the gate is present on this node` and exit 0 only if all six pass [scripts/install-gitreins.sh:77-79] | 2026-11-05 | **exit 1** — `FAIL  repo`, because `$HOME/repo` does not exist on this host; the other four rows passed |
| 2 | Same gate against a repo that has no gate | `NODE_REPO=<plain-git-repo> bash scripts/install-gitreins.sh --check` [scripts/install-gitreins.sh:25] | `FAIL  config` + `FAIL  hook`, `GITREINS: FAIL (2)`, exit 1 | 2026-11-05 | **PASS** as specified — 2 named FAILs, exit 1 |
| 3 | A node with no gitreins at all | `PATH=/usr/bin:/bin HOME=$(mktemp -d) NODE_REPO=<repo> bash scripts/install-gitreins.sh --check` | `FAIL  gitreins … absent`, `GITREINS: FAIL (4)`, exit 1 | 2026-11-05 | **PASS** as specified — 4 named FAILs, exit 1 |
| 4 | The suite's own leg: parse + refuse anonymous | `bash -n scripts/install-gitreins.sh` then `/bin/bash scripts/install-gitreins.sh --apply --repo "$PWD" --author-name "" --author-email ""` [tests/selftest.sh:2046-2047] | syntax 0; refusal exit non-zero with the identity substring [tests/selftest.sh:2048-2052] | 2026-11-05 | **PASS** — `syntax_exit=0`, `refuse_exit=1`, row printed verbatim |
| 5 | Help path | `bash scripts/install-gitreins.sh --help` [scripts/install-gitreins.sh:172] | the usage block, exit 0 | 2026-11-05 | **exit 0**, but the block is contaminated — see defect D-3 |
| 6 | PEP 668 premise | `ls /usr/lib/python3.14/EXTERNALLY-MANAGED` and `/usr/bin/python3 -m pip install --user --dry-run --no-index x` | marker present, `--user` refused | 2026-11-05 | **PASS** — marker present; `error: externally-managed-environment` |
| 7 | Hook flag contract | `gitreins guard --help` | `--quality-async` listed | 2026-11-05 | **PASS** — flag present with the documented meaning |
| 8 | Honest or not: does a skipped install still gate? | §6 D-1 probe (hermetic `HOME`, `NODE_REPO` in scratch) [scripts/install-gitreins.sh:89-92] [scripts/install-gitreins.sh:134] | hook runs the pinned binary | 2026-11-05 | **FAIL — defect D-1**, reproduced end to end |

Transcript 1 — the primary measurement, on this host, as delivered (`$HOME/repo` genuinely absent):

```
$ bash scripts/install-gitreins.sh --check; echo "EXIT=$?"
gitreins on the node — repo=~/repo pin=0.17.1
  PASS  python3 — Python 3.14.9
  PASS  pip — pip 26.2.2 from ~/.hermes/installs/b0e47ae07995f891/environments/24f1df2ad984420181cb6be1707f6a03/venv/lib/python3.14/site-packages/pip (python 3.14)
  PASS  gitreins — version 0.17.1 at pin 0.17.1
  FAIL  repo — ~/repo is not a directory — the gate has nothing to protect
  PASS  identity — totalwindupflightsystems <totalwindupflightsystems@gmail.com>

GITREINS: FAIL (1)
EXIT=1
```

Note what this run does **not** prove: `gitreins` passed from `PATH` (`~/.local/bin/gitreins`, a pipx venv), not from `$HOME/gitreins-venv`, which does not exist here. The row cannot tell those two apart — that ambiguity is defect D-1.

Transcript 2 — checks 2 and 3 (scratch repos, isolated `HOME`):

```
$ NODE_REPO=~/.hermes/cache/scratch/g19/bare bash scripts/install-gitreins.sh --check; echo "EXIT=$?"
  FAIL  config — ~/.hermes/cache/scratch/g19/bare/.gitreins/config.yaml absent — the gate has no policy
  FAIL  hook — no gitreins pre-commit in ~/.hermes/cache/scratch/g19/bare/.git/hooks — run 'gitreins install' there
GITREINS: FAIL (2)
EXIT=1

$ PATH=/usr/bin:/bin HOME=~/.hermes/cache/scratch/g19/home3 NODE_REPO=~/.hermes/cache/scratch/g19/bare bash scripts/install-gitreins.sh --check; echo "EXIT=$?"
  PASS  python3 — Python 3.14.4
  PASS  pip — pip 25.1.1 from /usr/lib/python3/dist-packages/pip (python 3.14)
  FAIL  gitreins — absent (no ~/.hermes/cache/scratch/g19/home3/gitreins-venv/bin/gitreins and none on PATH) — run --apply
  FAIL  config — ~/.hermes/cache/scratch/g19/bare/.gitreins/config.yaml absent — the gate has no policy
  FAIL  hook — no gitreins pre-commit in ~/.hermes/cache/scratch/g19/bare/.git/hooks — run 'gitreins install' there
  FAIL  identity — git user.name/user.email unset — a commit from this node is unattributed

GITREINS: FAIL (4)
EXIT=1
```

Transcript 3 — check 4, the suite's leg:

```
$ bash -n scripts/install-gitreins.sh; echo "syntax_exit=$?"
syntax_exit=0
$ out=$(/bin/bash scripts/install-gitreins.sh --apply --repo "$PWD" --author-name "" --author-email "" 2>&1); echo "refuse_exit=$?"
refuse_exit=1
  FAIL  identity — --author-name and --author-email are required on --apply (a node that commits anonymously is worse than one that refuses)
```

## 4. Metrics emitted

**NONE.** No counter, histogram, gauge, span or timing is emitted anywhere: the file has no `date`, no duration measurement, no machine-readable output, and its entire vocabulary is `say`/`ok`/`bad`/`note` text [scripts/install-gitreins.sh:38-78] over `printf` [scripts/lib.sh:5-9]. The one countable quantity is `FAILED`, a shell variable incremented by `bad` [scripts/lib.sh:7] and consumed exactly twice — the verdict text `GITREINS: FAIL ($FAILED)` [scripts/install-gitreins.sh:78] and the exit status `[ "$FAILED" -eq 0 ]` [scripts/install-gitreins.sh:79]. Why none is appropriate: this is a one-shot installer/checker invoked by hand or by a provisioning step, with no rate, queue or latency to instrument; its durable record is the operator's terminal plus `$HOME/.gitreins-install-$PIN.log` for the pip leg [scripts/install-gitreins.sh:98]. Whether the gate is armed on a node is answerable only by re-running `--check` or by the peer's probe row [scripts/bunker-provision.sh:245-248]; nothing aggregates it.

## 5. Log lines it can generate

All rows are `printf` output; the format strings and spacing live in `lib.sh` [scripts/lib.sh:5-9]. Tag = **evidentiary** when the line was observed in the runs recorded in §3/§6, **descriptive** when it is a literal string in the file that no recorded run reached.

- `gitreins on the node — repo=<path> pin=<version>` — **evidentiary**: the header, naming the two values every later row is judged against [scripts/install-gitreins.sh:38].
- `  PASS  python3 — Python 3.14.9` — **evidentiary**: the interpreter found, printed with its own `--version` [scripts/install-gitreins.sh:40].
- `  FAIL  python3 — absent — gitreins is a python package` — **descriptive**: the fatal first row; `return 1` immediately after [scripts/install-gitreins.sh:41].
- `  PASS  pip — pip 26.2.2 from …/site-packages/pip (python 3.14)` — **evidentiary**: pip's own `--version` first line [scripts/install-gitreins.sh:43-44].
- `  FAIL  pip — python3 -m pip is unavailable — run 'python3 -m ensurepip --user'` — **descriptive**: the non-fatal pip row; it names the remedy [scripts/install-gitreins.sh:45].
- `  FAIL  gitreins — absent (no ~/.hermes/cache/scratch/g19/home3/gitreins-venv/bin/gitreins and none on PATH) — run --apply` — **evidentiary**: absence, naming both places that were searched [scripts/install-gitreins.sh:49].
- `  PASS  gitreins — version 0.17.1 at pin 0.17.1` — **evidentiary**: the read-back found the pin [scripts/install-gitreins.sh:51].
- `  FAIL  gitreins — version <v> != pin <PIN>` — **descriptive**: drift at an exact pin [scripts/install-gitreins.sh:53].
- `  PASS  config — <repo>/.gitreins/config.yaml` — **evidentiary**: the policy file exists [scripts/install-gitreins.sh:58].
- `  FAIL  config — <repo>/.gitreins/config.yaml absent — the gate has no policy` — **evidentiary**: [scripts/install-gitreins.sh:58].
- `  PASS  hook — pre-commit runs gitreins` — **evidentiary, and the row that can lie**: it matches the word in the hook text, it does not execute the hook [scripts/install-gitreins.sh:60-61].
- `  FAIL  hook — no gitreins pre-commit in <repo>/.git/hooks — run 'gitreins install' there` — **evidentiary**: [scripts/install-gitreins.sh:63].
- `  FAIL  repo — ~/repo is not a directory — the gate has nothing to protect` — **evidentiary**: the row that fired on this host [scripts/install-gitreins.sh:66].
- `  PASS  identity — totalwindupflightsystems <totalwindupflightsystems@gmail.com>` — **evidentiary**: the global identity read back [scripts/install-gitreins.sh:72].
- `  FAIL  identity — git user.name/user.email unset — a commit from this node is unattributed` — **evidentiary**: both keys empty [scripts/install-gitreins.sh:74].
- `GITREINS: PASS — the gate is present on this node` — **evidentiary**: the success verdict [scripts/install-gitreins.sh:78].
- `GITREINS: FAIL (4)` — **evidentiary**: the verdict carries the count, which is the only aggregate the script produces [scripts/install-gitreins.sh:78].
- `  FAIL  identity — --author-name and --author-email are required on --apply (a node that commits anonymously is worse than one that refuses)` — **evidentiary**: the refusal the suite gates on [scripts/install-gitreins.sh:87] [tests/selftest.sh:2048-2052].
- `  PASS  gitreins — already at pin 0.17.1 (no install)` — **evidentiary**: the branch that skips the venv and causes D-1 [scripts/install-gitreins.sh:91].
- `  ..    creating <venv>` — **descriptive**: `note`-formatted progress before the venv is made [scripts/install-gitreins.sh:94].
- `  PASS  venv — <venv>` — **descriptive**: [scripts/install-gitreins.sh:96].
- `  FAIL  venv — python3 -m venv failed (python3-venv missing?)` — **descriptive**: the only place the `venv` dependency is named [scripts/install-gitreins.sh:95].
- `  ..    installing gitreins==0.17.1 into the venv` — **descriptive**: progress; the pip output itself goes to the log, not the terminal [scripts/install-gitreins.sh:99-100].
- `  PASS  install — gitreins 0.17.1 (log ~/.gitreins-install-0.17.1.log)` — **descriptive**: install plus the path of the swallowed pip log [scripts/install-gitreins.sh:103].
- `  FAIL  install — installed <v> but the pin is <PIN> (log <path>)` — **descriptive**: pip succeeded and the read-back still disagreed — the row that catches a lying index [scripts/install-gitreins.sh:105].
- `  FAIL  install — pip exited <n> — log <path>` — **descriptive**: pip's status, with the log path as the only route to the reason [scripts/install-gitreins.sh:108].
- `  PASS  path — ~/.local/bin/gitreins -> <venv>/bin/gitreins` — **descriptive**: the symlink that puts the pinned binary on `PATH` [scripts/install-gitreins.sh:112].
- `  FAIL  path — could not link ~/.local/bin/gitreins` — **descriptive**: non-fatal; the run continues to the hook [scripts/install-gitreins.sh:113].
- `  PASS  hook — already present in <repo> (left untouched)` — **descriptive**: an existing hook is never inspected or replaced [scripts/install-gitreins.sh:122].
- `  PASS  hook — written, pinned to <venv>/bin/gitreins` — **descriptive, and misleading by construction**: it asserts the *text* it just wrote, not that the target executes — the exact wording that made D-1 invisible [scripts/install-gitreins.sh:137].
- `  FAIL  hook — could not write <repo>/.git/hooks/pre-commit` — **descriptive**: [scripts/install-gitreins.sh:138].
- `  PASS  identity — user.name set to <name>` / `  FAIL  identity — could not set user.name` — **descriptive**: the write and its failure, one pair per key [scripts/install-gitreins.sh:144-147].
- `  PASS  co_author — CODING_HERMES_CO_AUTHOR appended to <env> (not printed)` — **descriptive**: the value is deliberately absent from the row [scripts/install-gitreins.sh:157].
- `  PASS  co_author — CODING_HERMES_CO_AUTHOR already present (not printed)` — **descriptive**: the idempotent arm [scripts/install-gitreins.sh:154].
- `unknown argument: --bogus` — **evidentiary**: printed before the usage block, exit 2 [scripts/install-gitreins.sh:173].

No level, logger, timestamp or destination exists: every line above is stdout from `printf`, and the only file either mode writes for diagnosis is the pip log [scripts/install-gitreins.sh:98].

## 6. Failure modes

Direction is the module's measured behaviour. `fail closed` = the run stops or exits non-zero; `fail open` = the artifact is still produced from a weaker source; `degraded` = the run continues with a missing row.

| Failure | Presents as | Direction | Distinguished from | Recovery |
|---|---|---|---|---|
| `python3` absent | `  FAIL  python3 — absent — gitreins is a python package` then `return 1` [scripts/install-gitreins.sh:40-41] | **fail closed**, and diagnostics-degraded: the other five rows are never printed, so the operator sees one FAIL for a node that is missing everything | The `--apply` arm prints `absent — cannot install gitreins` and returns before touching the venv [scripts/install-gitreins.sh:84] | install python3, rerun `--check` |
| `pip` missing but python3 present | `  FAIL  pip — python3 -m pip is unavailable …` and the run **continues** [scripts/install-gitreins.sh:43-45] | **degraded in `--check`** (row fails, exit still non-zero at the end [scripts/install-gitreins.sh:79]); **fail closed in `--apply`** at the install [scripts/install-gitreins.sh:100-108] | A pip that exists but cannot reach the index fails later, at `FAIL  install — pip exited <n>` [scripts/install-gitreins.sh:108] | `python3 -m ensurepip --user`, or install pip for that interpreter |
| `gitreins` absent or below/above the pin | `  FAIL  gitreins — absent …` or `version <v> != pin <PIN>` [scripts/install-gitreins.sh:49-53] | **fail closed** at the end of `check`; `--apply` treats any non-pin as installable and repairs it [scripts/install-gitreins.sh:89-106] | Absent and wrong-version have different wording, but both are one FAIL | `--apply` |
| `awk` absent while `gitreins` is present | the version collapses to empty, so the row reads `absent` [scripts/install-gitreins.sh:33-34] [scripts/install-gitreins.sh:49] | **fail closed, misdiagnosed** — the operator is told the binary is missing when the parser is | A real absence also names the two searched paths; here the path text is `$VENV/bin/gitreins and none on PATH`, which is true, so the lie is in the word "absent" | install awk, or read `gitreins --version` by hand |
| Repo directory missing | `  FAIL  repo — <path> is not a directory — the gate has nothing to protect` [scripts/install-gitreins.sh:66] | **fail closed**, but the `config` and `hook` rows are skipped entirely [scripts/install-gitreins.sh:56-67], so one FAIL stands for three unknowns | A repo that exists but is unarmed produces the `config`/`hook` FAILs instead [scripts/install-gitreins.sh:58-63] | pass `--repo` / set `NODE_REPO` [scripts/install-gitreins.sh:25] [scripts/install-gitreins.sh:168] |
| `.gitreins/config.yaml` absent while a hook exists | `  FAIL  config — … absent — the gate has no policy` [scripts/install-gitreins.sh:58]; the hook itself exits 0 [scripts/install-gitreins.sh:130-132] | **fail OPEN at commit time** — commits land ungraded — even though `--check` exits non-zero, because the two conditions are graded separately and nothing enforces `config` before a commit | `FAIL  hook` means there is no hook at all; this case has a hook that declines to act | `gitreins install` in that repo (measured: it writes the hook and skips an existing config [scripts/install-gitreins.sh:117-119] — see defect D-2) |
| Hook absent or not executable | `  FAIL  hook — no gitreins pre-commit in <repo>/.git/hooks — run 'gitreins install' there` [scripts/install-gitreins.sh:63] | **fail closed** in the check; at commit time git simply runs nothing, i.e. **fail open** | A hook that exists but does not mention gitreins lands in the same row [scripts/install-gitreins.sh:60] | `--apply` writes one [scripts/install-gitreins.sh:124-136], or `gitreins install` |
| Identity unset | `  FAIL  identity — git user.name/user.email unset — a commit from this node is unattributed` [scripts/install-gitreins.sh:74] | **fail closed in `--apply`** — it refuses before installing anything [scripts/install-gitreins.sh:86-87] | An identity that is set globally but wrong is indistinguishable here; the row only prints what it found [scripts/install-gitreins.sh:72] | pass `--author-name` and `--author-email`, or set `GIT_AUTHOR_NAME`/`GIT_AUTHOR_EMAIL` [scripts/install-gitreins.sh:27-28] |
| `python3 -m venv` fails | `  FAIL  venv — python3 -m venv failed (python3-venv missing?)` then `return 1` [scripts/install-gitreins.sh:95] | **fail closed** — no hook is written, so the repo stays unarmed rather than half-armed | A pip failure happens later and names pip [scripts/install-gitreins.sh:108] | install the distro's `python3-venv`, rerun |
| pip install fails or the read-back disagrees | `  FAIL  install — pip exited <n> — log <path>` or `installed <v> but the pin is <PIN>` [scripts/install-gitreins.sh:105-108] | **fail closed** — `return 1` before the symlink and the hook, so nothing is left pointing at a wrong binary | A version mismatch on a pre-existing install is caught earlier, before any pip run [scripts/install-gitreins.sh:90-92] | read the log at `$HOME/.gitreins-install-$PIN.log` [scripts/install-gitreins.sh:98] |
| Symlink fails | `  FAIL  path — could not link ~/.local/bin/gitreins` [scripts/install-gitreins.sh:113] | **degraded** — no `return`, the hook is still written and still pins the absolute venv path, so the gate works for that repo and `gitreins` is simply not on `PATH` | A wrong pin fails earlier, at the install row [scripts/install-gitreins.sh:105] | create the link by hand, or fix `$HOME/.local/bin` permissions |
| An existing hook is present | `  PASS  hook — already present in <repo> (left untouched)` [scripts/install-gitreins.sh:122] | **fail open to the incumbent** — whatever that hook does, including nothing, is reported as a pass | A hook without the word gitreins is rewritten instead [scripts/install-gitreins.sh:121] | inspect `.git/hooks/pre-commit` yourself; the script deliberately will not |
| **D-1** Install skipped, hook still written with the venv path | `  PASS  gitreins — already at pin 0.17.1 (no install)` [scripts/install-gitreins.sh:91] + `  PASS  hook — written, pinned to <venv>/bin/gitreins` [scripts/install-gitreins.sh:137], then every commit dies `/…/gitreins-venv/bin/gitreins: No such file or directory`, exit 1 | **fail closed at commit, LYING at check**: the check's PASS rows are text assertions, so the run exits 0 and reports `GITREINS: PASS` [scripts/install-gitreins.sh:78] while the gate is broken | A correct install prints `PASS  install` and links a binary that exists [scripts/install-gitreins.sh:103-112] | create `$VENV` and install the pin, or re-run `--apply` with the venv removed so the install branch is taken |
| `--repo` supplied with no value | `scripts/install-gitreins.sh: line 168: $2: unbound variable`, exit 1, no usage block [scripts/install-gitreins.sh:168] | **fail closed**, abrupt: `set -u` kills the shell mid-parse | An unknown flag prints `unknown argument:` plus usage and exits 2 [scripts/install-gitreins.sh:173] | pass a value |
| `lib.sh` missing beside the script | `lib.sh: No such file or directory` then `say: command not found` ×3, exit 1 [scripts/install-gitreins.sh:17] | **fail closed as a crash**, not as rows — the report is unreadable and the failure is not attributable from its text | Every other failure in this table is a named `  FAIL  <key> —` row [scripts/lib.sh:7] | restage the script with the repo's `scripts/lib.sh` |

## 7. Environment and settings it reads

| Setting | Where read | Default | Effect of missing |
|---|---|---|---|
| `--check` / `--apply` | first positional parsed in the loop [scripts/install-gitreins.sh:167] | `--check` [scripts/install-gitreins.sh:26] | bare invocation is a check; nothing is installed |
| `--repo <path>` | arg parser [scripts/install-gitreins.sh:168] | `$NODE_REPO`, else `$HOME/repo` [scripts/install-gitreins.sh:25] | with no `--repo` and no variable, the gate is graded against `$HOME/repo` — the path a provisioned node actually uses [scripts/bunker-provision.sh:208] |
| `--author-name <name>` | [scripts/install-gitreins.sh:169] | `$GIT_AUTHOR_NAME`, else empty [scripts/install-gitreins.sh:27] | empty on `--apply` is a refusal, exit 1 [scripts/install-gitreins.sh:86-87] |
| `--author-email <mail>` | [scripts/install-gitreins.sh:170] | `$GIT_AUTHOR_EMAIL`, else empty [scripts/install-gitreins.sh:28] | same refusal |
| `--co-author <Name <mail>>` | [scripts/install-gitreins.sh:171] | `$GIT_CO_AUTHOR`, else empty [scripts/install-gitreins.sh:29] | empty → the whole `.env` block is skipped silently [scripts/install-gitreins.sh:149] |
| `GITREINS_PIN` | `PIN="${GITREINS_PIN:-0.17.1}"` [scripts/install-gitreins.sh:19] | `0.17.1` | the default pin is used, and the log path changes with it [scripts/install-gitreins.sh:98] |
| `GITREINS_VENV` | `VENV="${GITREINS_VENV:-$HOME/gitreins-venv}"` [scripts/install-gitreins.sh:23] | `$HOME/gitreins-venv` | the default venv is used; the hook's absolute path is whatever this resolves to at write time [scripts/install-gitreins.sh:134] |
| `NODE_REPO` | `REPO="${NODE_REPO:-$HOME/repo}"` [scripts/install-gitreins.sh:25] | `$HOME/repo` | see `--repo` |
| `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, `GIT_CO_AUTHOR` | [scripts/install-gitreins.sh:27-29] | empty | see the three flags above; note these are the *git* variable names, so an operator who already exports them gets them silently adopted |
| `$HOME/.local/bin` | `BINDIR="$HOME/.local/bin"` [scripts/install-gitreins.sh:24] | hard-coded | **no override**: the symlink target cannot be redirected without editing the file |
| `$HOME/.gitreins-install-$PIN.log` | [scripts/install-gitreins.sh:98] | `$HOME` | created by the redirect on the pip call [scripts/install-gitreins.sh:100]; the only record of a failed install |
| `$HOME/.hermes/.env` | [scripts/install-gitreins.sh:150] | created if absent, `chmod 600` [scripts/install-gitreins.sh:151-152] | only touched when `--co-author`/`GIT_CO_AUTHOR` is set; the value is written once and never printed [scripts/install-gitreins.sh:153-157] |
| The repo's `.gitreins/config.yaml` | `$REPO/.gitreins/config.yaml` [scripts/install-gitreins.sh:57] | must already exist; this script never creates it | `FAIL  config`, and the hook it writes exits 0 without it [scripts/install-gitreins.sh:130-132] |
| `PATH` | `command -v python3` [scripts/install-gitreins.sh:40], `command -v gitreins` [scripts/install-gitreins.sh:34] | inherited | an isolated `PATH` changes both rows at once — measured in §3 check 3 |

The only secret-adjacent value in this file is the co-author string, and its handling matches the fleet rule's file half: created mode 600, written once, never echoed [scripts/install-gitreins.sh:150-157] (fact: FACT-05). It does arrive on argv (`--co-author`) [scripts/install-gitreins.sh:171], which that rule forbids for credentials; the value is a display name, not a credential, so the argv half is not exercised here.

## 8. Evidence of record

- **Measured 2026-11-05**, in a clean worktree of `e7cf075` (`~/proj-wt-md-19b`), bash 5.3.9, git 2.53.0, python3 3.14.9 (harness venv) / 3.14.4 (`/usr/bin`), gitreins 0.17.1 from a pipx venv: every transcript in §3 is literal terminal output, and every command in §3 was executed in the order listed. The primary run exits **1** on this host because `$HOME/repo` does not exist — that measurement is the evidence, not a defect.
- **The premise that it cannot be measured here**: `$HOME/gitreins-venv` does not exist on this host, so `installed()` resolved through its `PATH` fallback [scripts/install-gitreins.sh:33-34]. That is exactly the configuration defect D-1 needs, and it is why the apply path was probed hermetically rather than assumed.
- **Suites that gate on this file**: `bash -n` plus the anonymous-identity refusal, asserted by substring [tests/selftest.sh:2046-2052] — the only automated coverage in the tree. Nothing tests the venv branch, the version read-back, the hook heredoc or the symlink.
- **Peer duplication**: the provisioning probe re-implements `installed()` and grades the same two artifacts [scripts/bunker-provision.sh:220-221] [scripts/bunker-provision.sh:245-248], so the node's gate is asserted twice per provisioning run; the peer's copy inherits the same venv-then-`PATH` ambiguity.
- **The evidence discipline this document follows** — a claim is only worth a re-runnable command, not a summary — is the project's own rule [docs/master/_facts.md:21] (fact: FACT-10). Per that rule, §3's commands are re-runnable as written; §5's descriptive rows are string literals, not measurements, and are tagged as such.

Defects measured while filling this section (documented, **not** fixed — `scripts/` is out of scope for this task):

1. **D-1 — `--check` cannot distinguish "installed" from "on `PATH`", and `--apply` then writes a hook to a path that does not exist.** `installed()` falls back to `PATH` [scripts/install-gitreins.sh:33-34]; if the pin is found there, `apply` prints `already at pin … (no install)` and skips venv creation entirely [scripts/install-gitreins.sh:89-97]; the hook heredoc then pins the *venv* path unconditionally [scripts/install-gitreins.sh:134]. Reproduced end to end with an isolated `HOME` and a scratch repo: hook written pinning `/…/g19~/bin/gitreins`, `PASS  hook — written, pinned to …` and `GITREINS: PASS`, then `git commit` printed `.git/hooks/pre-commit: line 10: …/gitreins-venv/bin/gitreins: No such file or directory` and exited 1. On a node where gitreins was pipx-installed — the shape of this very host — every commit would be blocked with a message that names a path the installer never created. The check that should catch it (`grep -q gitreins` [scripts/install-gitreins.sh:60]) passes by construction.
2. **D-2 — the header's stated premise about `gitreins install` is stale for the pinned version.** The comment claims `gitreins install` "skips a repo that already has .gitreins/config.yaml and writes no hook" [scripts/install-gitreins.sh:117-119]. Measured with 0.17.1 on a scratch repo that already had `.gitreins/config.yaml`: `gitreins install` printed `Skipped: …/.gitreins/config.yaml` and still wrote both `.git/hooks/pre-commit` and `.git/hooks/pre-push` (672 and 263 bytes, exit 0). The script's own hook-writing block is therefore redundant when `gitreins install` has run — harmless, but the justification recorded in the file is not the behaviour the pinned binary has.
3. **D-3 — `usage()` leaks shell code into the help output.** `sed -n '2,16p'` [scripts/install-gitreins.sh:31] runs two lines past the comment block, which ends at line 14, so `--help` prints `set -uo pipefail` and `HERE="$(cd "$(dirname "$0")" && pwd)"` after the prose (measured, exit 0). Cosmetic, but it makes the documented usage block untrustworthy as a spec.
4. **D-4 — a flag with no value kills the shell instead of refusing.** `--repo` with no argument hits `REPO="$2"` under `set -u` [scripts/install-gitreins.sh:168], producing `scripts/install-gitreins.sh: line 168: $2: unbound variable`, exit 1, and no usage block — while an unknown flag gets a proper `unknown argument:` + usage + exit 2 [scripts/install-gitreins.sh:173]. Two different refusal qualities for two adjacent operator mistakes.
5. **D-5 — the co-author consumer is not in this repository.** `CODING_HERMES_CO_AUTHOR` is written to `$HOME/.hermes/.env` [scripts/install-gitreins.sh:156] and no file in this tree reads it (grep returns only those writer lines). Whether the trailer is actually applied therefore cannot be verified from this repo, and the installer's `not printed` success row [scripts/install-gitreins.sh:157] is the only evidence an operator ever sees.
6. **D-6 — `--apply` never runs `gitreins install` or `gitreins init`, so it cannot arm a repo that has no `.gitreins/config.yaml`.** It reports `FAIL  config` afterwards [scripts/install-gitreins.sh:58] and writes a hook that exits 0 in that state [scripts/install-gitreins.sh:130-132] — the operator ends with a "FAIL" run and an inert hook.
