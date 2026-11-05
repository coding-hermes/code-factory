# 20. scripts/land-node-branch.sh

| Field | Value |
|---|---|
| Path | `/home/kara/proj-wt-md-20e/scripts/land-node-branch.sh` — 260 lines; five local helpers (`usage`, `first_line`, `last_reason`, `refuse`, `cleanup`) and no other code [scripts/land-node-branch.sh:33] [scripts/land-node-branch.sh:35] [scripts/land-node-branch.sh:38] [scripts/land-node-branch.sh:46] [scripts/land-node-branch.sh:54] |
| Repository | `code-factory` |
| Revision | `b9f56e6` — the `origin/main` tip every locator was read against, and the revision the scratch landings ran from (2026-11-05); the previous text of this file named `3c4c639` |
| Status | **VERIFIED — the landing contract was executed on a scratch bare origin: 20/20 checks in the §3 recipe (exit 0), 13/13 legs of the repo's own CF-213 arm (`fails=0`), and every refusal row in §6 was captured from a real run** |

## 1. Purpose and why it matters

- What it is: the control-host step that takes the two git fields of a node's result envelope — `branch` and `commit` [specs/ENVELOPE.md:39-40] — and puts the commit on `origin/<main>`. The header states the gap it closes in its own words: `no step in this repo merges them, so a finished node task has no path into origin/main. This is that path.` [scripts/land-node-branch.sh:8-9]. Both fields are written by the node worker out of its own worktree, from `git rev-parse --abbrev-ref HEAD` and `git rev-parse HEAD` [scripts/node-bus-worker.py:786-787] [scripts/node-bus-worker.py:930-931].
- Why it is load-bearing here: the foreman runs on the project's bunker node and never on the control host (fact: FACT-01), so no node is the place where shared `main` moves. This script is the return half of that contract — the node builds and pushes a branch, the control host decides whether the commit may enter `origin/main`, and only then does it prove the entry happened. Nothing else in the repository performs that role: a grep for a push of `refs/heads/node/…` over `scripts/`, `specs/` and `tests/` matches only the selftest fixture [tests/selftest.sh:2265], and the design note records the step as `Shipped as a script, run by hand. … Nothing calls it yet and no automation consumes its result` [docs/DESIGN.md:57]. The documented invocation is manual and single [AGENTS.md:71].
- What lands, precisely, because the handbook records the node return path as deficiency D-8 (`nothing defines what comes back from a node` [docs/LOOP-CODEX.md:54]): a **git commit**, and only that. The merge target is `$commit_sha`, not the branch tip [scripts/land-node-branch.sh:213] [scripts/land-node-branch.sh:220]; the only ref this script writes on the remote is `refs/heads/<main>`, pushed as `HEAD:refs/heads/<main>` [scripts/land-node-branch.sh:230]. The node's branch ref is read, never pushed [scripts/land-node-branch.sh:113] [scripts/land-node-branch.sh:130-136]. Measured: a branch whose tip was one commit past the envelope commit landed the envelope commit and left the later commit outside `origin/main` — `origin main tip: 847c07d … C2 is in origin main: NO` — and the landed tree carried the envelope commit's file content (`artifact/result.txt on landed main: result-1`), not the tip's `result-2`. A branch that exists only in the control clone still lands its commit, and the remote keeps one head only: `origin heads after landing: main`.
- What does **not** land: the envelope's `artifacts[]` [specs/ENVELOPE.md:41]. This script never reads that field — the string `artifact` does not occur in the source — and the node worker emits it empty [scripts/node-bus-worker.py:788] [scripts/node-bus-worker.py:932]. A file the node wrote but did not commit is invisible to every check here: measured, a gate that tested for an uncommitted file in the node worktree refused the landing (`  FAIL  gate — 'test -f artifact/extra.txt' exited 1 at f7e6035d0d6e — no output`), because the gate runs in a detached worktree at the commit, i.e. against the *committed* tree [scripts/land-node-branch.sh:170].
- What breaks if this module is absent: the envelope still names a branch and a commit and no step merges them [scripts/land-node-branch.sh:8-9]; a node task completes, reports `status: completed`, names a commit, and the project's `main` never moves. The measured scratch pair shows the other half of the same coin: before the control clone had fetched the node branch, the script refused rather than guessed — `LAND: REFUSED — 0b447fa… is not a commit in …/control — fetch the node branch before landing it`.
- What breaks if it lies: it would print a success row for a commit the remote does not have. The file's rule is that the push is a claim and the ancestry test against the re-fetched remote is the evidence [scripts/land-node-branch.sh:18-20] [scripts/land-node-branch.sh:239]. The final `PASS landed` row comes only from `git merge-base --is-ancestor "$commit_sha" "$MAIN_REF"` after a post-push fetch [scripts/land-node-branch.sh:240-245], the terminal line is chosen by `$FAILED` [scripts/land-node-branch.sh:255-259], and the exit status follows it. Measured against a remote whose `post-receive` hook put `main` back where it was: `  FAIL  landed — e1760fb… is NOT an ancestor of origin/main (f77c2c7cdc91) — the push did not land this commit`, then `LAND: FAIL (1)`, exit 1 — the merge and the push both printed PASS and the run still failed. That is the whole point of the module, and it is the behaviour the scratch evidence exercises three ways (§3 and §6).
- Where the power actually sits: three decisions, none of them the merge. (a) What lands is the commit [scripts/land-node-branch.sh:213], so a branch can be ahead of the envelope and its later commits stay out (measured above). (b) The push publishes the control clone's `HEAD` [scripts/land-node-branch.sh:230], so under `--no-ff` any local commit already sitting on that clone's `main` rides along — measured: the landed history contained `1860e3a control: gate.sh`, a commit that was never on the node branch. (c) The gate is optional: with no `--gate-cmd` the whole gate block is skipped [scripts/land-node-branch.sh:164], and the measured gateless landing printed no `gate` row at all.
- Who consumes the output: nobody in the repository. The only machine-readable contract is textual — `LANDED: …` on success and `LAND: FAIL (…)` on failure [scripts/land-node-branch.sh:254-259] — and the documented caller is a human or a foreman running it by hand [AGENTS.md:71]. A row that closes on this module must therefore quote a re-runnable command, not a commit message (fact: FACT-10), which is what §3 supplies.
- Blast radius: one control clone and the shared remote's `<main>` ref. No other ref is written, no tag, no branch deletion, and nothing under `scripts/` changes at run time. The one failure that outlives the run is the local `main` left one merge ahead of the remote after a rejected push (§6).

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

Versions are the ones on the host where the scratch landings ran (2026-11-05): `GNU bash, version 5.3.9(1)-release`, `git version 2.53.0`, coreutils under `/usr/bin`.

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `bash` | any bash with `local`, `${v:0:12}` slicing and `set -uo pipefail` [scripts/land-node-branch.sh:25] [scripts/land-node-branch.sh:39] [scripts/land-node-branch.sh:136] | the interpreter named by `#!/usr/bin/env bash` [scripts/land-node-branch.sh:1] | nothing — a `sh` that cannot parse the file dies at the shebang with a syntax error and no row |
| `git` | a git with `worktree add --detach`, `merge-base --is-ancestor`, `ls-remote --heads` [scripts/land-node-branch.sh:170] [scripts/land-node-branch.sh:138] [scripts/land-node-branch.sh:249] | `PATH`, by bare name; every call is `git -C` on a resolved path [scripts/land-node-branch.sh:84] | the first guarded call, `if ! TOP=$(git -C … rev-parse --show-toplevel)`, turns a missing binary into `LAND: REFUSED — not a git worktree: $WORKDIR` [scripts/land-node-branch.sh:84-86] — fail-closed, misattributed |
| `lib.sh` | same directory as the script, derived from `$0` [scripts/land-node-branch.sh:26] | `$HERE/lib.sh`, sourced [scripts/land-node-branch.sh:27] | measured with an empty `PATH`: `dirname` fails, `HERE` becomes `/`, and the run prints `/lib.sh: No such file or directory` then `say: command not found` — every row is lost, the status survives at 1 |
| `awk`, `head`, `cut`, `sed`, `grep`, `tail`, `wc`, `tr`, `mktemp`, `rm`, `dirname` | coreutils / awk on the control host (measured at `/usr/bin/…`) | `PATH` | `awk` only inside `usage()` [scripts/land-node-branch.sh:33] — measured with an empty `PATH`, `--help` printed nothing and **exited 0**; `mktemp` only for the gate worktree [scripts/land-node-branch.sh:168] — measured, an unusable `TMPDIR` produced `mktemp: failed to create directory …` on stderr and then `LAND: REFUSED — cannot create a detached worktree …` (§6) |
| the project under landing | n/a | the workdir passed as `--workdir`; the gate is run after `cd` into the detached worktree [scripts/land-node-branch.sh:175] | not detected: a gate needing a tool the control host lacks exits nonzero and is reported as the gate's failure [scripts/land-node-branch.sh:183] |

Nothing in this file is pinned or version-probed; the only thing it sanity-checks is whether the *target* is a git worktree.

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `. "$HERE/lib.sh"` [scripts/land-node-branch.sh:27] | `scripts/lib.sh` [scripts/lib.sh:3] | five row helpers and one counter: `say` [scripts/lib.sh:5], `ok` [scripts/lib.sh:6], `bad` [scripts/lib.sh:7], `warn` [scripts/lib.sh:8], `note` [scripts/lib.sh:9], and `FAILED` defaulted to 0 [scripts/lib.sh:11] | the rows change shape but the exit status does not: every refusal ends in an explicit `exit 1` [scripts/land-node-branch.sh:50], and the success path reads `$FAILED` only at the end [scripts/land-node-branch.sh:255]. Only `bad` moves the counter [scripts/lib.sh:7], so a renamed row helper silently disarms the final gate while the refusals keep working |

Call sites in this module: `say` at the banner and in every terminal line [scripts/land-node-branch.sh:81]; `ok` for the fourteen PASS rows; `bad` inside `refuse` and for the two landing failures [scripts/land-node-branch.sh:47] [scripts/land-node-branch.sh:231] [scripts/land-node-branch.sh:247]; `note` for the three context lines [scripts/land-node-branch.sh:105] [scripts/land-node-branch.sh:116] [scripts/land-node-branch.sh:166]; `warn` once for the moved-branch race [scripts/land-node-branch.sh:251]. `warn` does not move `FAILED` [scripts/lib.sh:8], so that condition cannot fail a run.

### 2c. Service contracts (both sides named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| the node's result branch | script **pulls** | `git fetch <remote> +refs/heads/<branch>:refs/remotes/<remote>/<branch>` [scripts/land-node-branch.sh:113] | the branch ref and the objects reachable from it | the node itself, outside this repository: no file under `scripts/` pushes `refs/heads/node/…`; the only in-repo push of such a ref is the test fixture [tests/selftest.sh:2265]. The script states the assumption — `The node pushes its own branch; without this the envelope's commit can be present on the remote and still be judged unreachable from a stale tracking ref.` [scripts/land-node-branch.sh:111-112] |
| the result envelope | script **consumes two argv values** | `--branch`, `--commit` [scripts/land-node-branch.sh:65-66] | the branch name and the commit sha, nothing else | `scripts/node-bus-worker.py`, which builds `branch` and `commit` from the node's `HEAD` [scripts/node-bus-worker.py:786-787] [scripts/node-bus-worker.py:930-931] and fills `artifacts` with `[]` [scripts/node-bus-worker.py:788] [scripts/node-bus-worker.py:932]; the wire contract is [specs/ENVELOPE.md:39-41] |
| the remote's `<main>` ref | script **pushes, then re-reads** | `git push <remote> HEAD:refs/heads/<main>` [scripts/land-node-branch.sh:230], then the same refspec through `git fetch` [scripts/land-node-branch.sh:240] and `git ls-remote --heads` [scripts/land-node-branch.sh:249] | the control clone's `HEAD` | the receive side of `<remote>` — a bare repo or a forge; it may reject (measured: `pre-receive` hook → row `push`) or accept and then move the ref away (measured: `post-receive` hook → row `landed`) |
| the project's gate | script **executes** | `( cd "$gate_wt" && bash -c "$GATE" )`, both streams to a log file [scripts/land-node-branch.sh:175] | a shell command string from `--gate-cmd` [scripts/land-node-branch.sh:69] | the project's own test runner, run against a detached worktree at `$commit_sha` [scripts/land-node-branch.sh:170]; the contract is its exit code, `0` passes [scripts/land-node-branch.sh:177] |
| the console a foreman reads | script **writes** | stdout only | `LANDED: …` / `LAND: FAIL (…)` / `LAND: REFUSED — …` [scripts/land-node-branch.sh:254-259] | no consumer in the repository [docs/DESIGN.md:57]; the documented use is a manual invocation [AGENTS.md:71] and the acceptance arm greps these rows [tests/selftest.sh:2245] |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| syntax | `bash -n scripts/land-node-branch.sh` | exit 0, no output | 2026-11-05 | **PASS** (exit 0) |
| the landing contract, end to end | the recipe below, run from a scratch file with `L=<repo>/scripts/land-node-branch.sh` | `20 ok, 0 failed`, exit 0 | 2026-11-05 | **PASS** (20 ok, 0 failed, exit 0) |
| the repo's own arm | source lines 2230-2390 of [tests/selftest.sh:2230] with `HERE=<repo>`, `fails=0`, `say()` defined | every leg `  PASS`, final `CF213 fails=0` | 2026-11-05 | **PASS** (13 `PASS` legs, `fails=0`, exit 0) |
| usage is not a landing | `--help`; no arguments; `--nope`; `--workdir` alone | header block and exit 0 on `--help`; the other three exit 2 | 2026-11-05 | **PASS** (measured exit 0, 2, 2, 2) |
| this document | `python3 scripts/master_doc_check.py docs/master --only 20- --strict` | `MASTER-DOC: PASS` | 2026-11-05 | **PASS** |

The recipe builds one bare origin, one control clone and one node clone under `$TMPDIR`, then drives the real script through the arms that matter: an unfetched commit, a dry run that moves nothing, a landing, an idempotent re-run, a red gate, a non-fast-forward, a rejected push, and a push the remote undoes. It asserts on row text, not on commit shas, so it re-runs against any revision.

```bash
#!/usr/bin/env bash
# md20e-verify.sh — the landing contract on scratch repos. No network, no real repo.
set -uo pipefail
S=${S:-/tmp/md20e-verify}
L=${L:-/home/kara/proj-wt-md-20e/scripts/land-node-branch.sh}
rm -rf "$S"; mkdir -p "$S/tmp"; export TMPDIR="$S/tmp"
export GIT_AUTHOR_NAME=v GIT_AUTHOR_EMAIL=v@example.invalid
export GIT_COMMITTER_NAME=v GIT_COMMITTER_EMAIL=v@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
pass=0 fail=0
chk() {  # chk <name> <expected> <log>
  if grep -qF -- "$2" "$3"; then printf 'ok   %s\n' "$1"; pass=$((pass+1));
  else printf 'FAIL %s — wanted: %s\n' "$1" "$2"; fail=$((fail+1)); fi
}
pair() {
  rm -rf "$S/o.git" "$S/seed" "$S/control" "$S/node"
  git init -q --bare "$S/o.git"; git clone -q "$S/o.git" "$S/seed" 2>/dev/null
  git -C "$S/seed" checkout -q -b main; printf 'l1\n' > "$S/seed/README.md"
  git -C "$S/seed" add -A; git -C "$S/seed" commit -qm seed; git -C "$S/seed" push -q origin main
  git -C "$S/o.git" symbolic-ref HEAD refs/heads/main
  git clone -q "$S/o.git" "$S/control"; git clone -q "$S/o.git" "$S/node"
  git -C "$S/node" checkout -q -b node/t1; mkdir -p "$S/node/artifact"
  printf 'result-1\n' > "$S/node/artifact/result.txt"
  git -C "$S/node" add -A; git -C "$S/node" commit -qm "node: artifact"
  C1=$(git -C "$S/node" rev-parse HEAD); git -C "$S/node" push -q origin node/t1
}
land() { bash "$L" --workdir "$S/control" --branch node/t1 --commit "$C1" "$@" >"$S/last.log" 2>&1; printf '%d' $?; }

pair
rc=$(land --dry-run)
chk "dry-run before any fetch refuses on the commit row" "LAND: REFUSED — $C1 is not a commit in" "$S/last.log"
[ "$rc" = 1 ] && { echo "ok   dry-run exit 1"; pass=$((pass+1)); } || { echo "FAIL dry-run exit $rc"; fail=$((fail+1)); }

git -C "$S/control" fetch -q origin
before=$(git -C "$S/o.git" rev-parse refs/heads/main)
rc=$(land --gate-cmd true --dry-run)
chk "dry-run prints the zero-command line" "LAND: DRY-RUN — 0 commands run, nothing merged or pushed, no ref moved" "$S/last.log"
chk "dry-run names the gate it would run" "dry-run: would run gate 'true' in a detached worktree" "$S/last.log"
[ "$before" = "$(git -C "$S/o.git" rev-parse refs/heads/main)" ] \
  && { echo "ok   dry-run moved no ref"; pass=$((pass+1)); } \
  || { echo "FAIL dry-run moved origin/main"; fail=$((fail+1)); }

rc=$(land --gate-cmd 'test -f artifact/result.txt')
chk "landing prints the proof row" "  PASS  landed — $C1 is an ancestor of origin/main" "$S/last.log"
chk "landing prints LANDED" "LANDED: node/t1 @ $C1 in origin/main" "$S/last.log"
[ "$rc" = 0 ] && { echo "ok   landing exit 0"; pass=$((pass+1)); } || { echo "FAIL landing exit $rc"; fail=$((fail+1)); }
chk "origin/main is the commit" "$C1" <(git -C "$S/o.git" rev-parse refs/heads/main)
chk "the artifact tree landed" "artifact/result.txt" <(git -C "$S/o.git" ls-tree -r --name-only refs/heads/main)

rc=$(land)
chk "second run is idempotent" "LANDED (already): node/t1 @ $C1 in origin/main" "$S/last.log"
[ "$rc" = 0 ] && { echo "ok   idempotent exit 0"; pass=$((pass+1)); } || { echo "FAIL idempotent exit $rc"; fail=$((fail+1)); }

pair
rc=$(land --gate-cmd 'exit 3')
chk "gate failure refuses" "  FAIL  gate — 'exit 3' exited 3" "$S/last.log"
[ "$rc" = 1 ] && { echo "ok   gate refusal exit 1"; pass=$((pass+1)); } || { echo "FAIL gate refusal exit $rc"; fail=$((fail+1)); }
chk "gate failure merged nothing" "$(git -C "$S/seed" rev-parse refs/heads/main)" <(git -C "$S/control" rev-parse main)

pair
git -C "$S/control" commit -q --allow-empty -m "control: local commit"
rc=$(land)
chk "ff-only refuses a non-fast-forward" "  FAIL  ff_only — main at" "$S/last.log"

pair
printf '#!/bin/sh\nexit 1\n' > "$S/o.git/hooks/pre-receive"; chmod +x "$S/o.git/hooks/pre-receive"
rc=$(land)
chk "rejected push fails loudly" "LAND: FAIL (1) — merged locally, NOT landed" "$S/last.log"
[ "$rc" = 1 ] && { echo "ok   rejected push exit 1"; pass=$((pass+1)); } || { echo "FAIL rejected push exit $rc"; fail=$((fail+1)); }

pair
before=$(git -C "$S/o.git" rev-parse refs/heads/main)
printf '#!/bin/sh\ngit update-ref refs/heads/main %s\n' "$before" > "$S/o.git/hooks/post-receive"
chmod +x "$S/o.git/hooks/post-receive"
rc=$(land)
chk "a push that did not land the commit fails the proof" "  FAIL  landed — $C1 is NOT an ancestor of origin/main" "$S/last.log"
chk "and the run reports FAIL" "LAND: FAIL (1)" "$S/last.log"

printf '\n%d ok, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

Verbatim output of that run (2026-11-05, exit 0):

```text
ok   dry-run before any fetch refuses on the commit row
ok   dry-run exit 1
ok   dry-run prints the zero-command line
ok   dry-run names the gate it would run
ok   dry-run moved no ref
ok   landing prints the proof row
ok   landing prints LANDED
ok   landing exit 0
ok   origin/main is the commit
ok   the artifact tree landed
ok   second run is idempotent
ok   idempotent exit 0
ok   gate failure refuses
ok   gate refusal exit 1
ok   gate failure merged nothing
ok   ff-only refuses a non-fast-forward
ok   rejected push fails loudly
ok   rejected push exit 1
ok   a push that did not land the commit fails the proof
ok   and the run reports FAIL

20 ok, 0 failed
```

The repository's own arm covers the same ground from the other end — it also executes the remedy the refusal names (rebase the branch onto `origin/main`, force-with-lease, relaunch) and re-clones the remote to prove the push, not the merge, moved it [tests/selftest.sh:2305-2310] [tests/selftest.sh:2349-2352]. Its 13 legs printed `PASS` with `CF213 fails=0` on 2026-11-05; the `FAIL …` lines inside its transcript are the refusal rows it asserts on, not leg failures.

## 4. Metrics emitted

**NONE — and there is no second artifact to scrape.** The script counts nothing, times nothing and writes no file that survives the run. The only counter in the process is lib.sh's `FAILED` [scripts/lib.sh:11], which `bad` increments [scripts/land-node-branch.sh:47] [scripts/land-node-branch.sh:231] [scripts/land-node-branch.sh:247] and which is read exactly once, to choose between `LANDED:` and `LAND: FAIL` [scripts/land-node-branch.sh:255-259]; it is never printed as a number and dies with the process. The merge log is deleted at the end of the merge block [scripts/land-node-branch.sh:227], the gate log and its worktree are deleted on success and by the EXIT trap on every exit [scripts/land-node-branch.sh:54-60] [scripts/land-node-branch.sh:179], and a post-run listing of the control clone's worktrees and of `$TMPDIR` found no residue. The run's **only** durable output is therefore stdout: the row vocabulary of §5. That is why the module's contract is text plus exit status, and why an operator who pipes the run through `grep PASS` gets a claim with no measurement attached — PASS rows are printed for pre-conditions and for the push long before the proof row exists [scripts/land-node-branch.sh:236] [scripts/land-node-branch.sh:245].

## 5. Log lines it can generate

Rows are written by lib.sh's helpers; the shape is two spaces, a word, two spaces, a name, space, em dash, space, detail [scripts/lib.sh:5-9]. `Class` is `descriptive` for context and `evidentiary` when the line's presence is part of the run's claim.

| Class | Level | Line (verbatim, source form) | Emitted when |
|---|---|---|---|
| evidentiary | banner | `land-node-branch — workdir=$WORKDIR branch=$BRANCH commit=$COMMIT $REMOTE/$MAIN` [scripts/land-node-branch.sh:81] | after argument validation, before any measurement |
| evidentiary | PASS | `  PASS  workdir_clean — clean worktree at $TOP` [scripts/land-node-branch.sh:94] | `git status --porcelain` is empty |
| evidentiary | PASS | `  PASS  on_main — $MAIN is checked out in $TOP` [scripts/land-node-branch.sh:100] | `symbolic-ref --short HEAD` equals `$MAIN` |
| descriptive | note | `  ..    dry-run: no fetch — every verdict below uses the refs as they stand now` [scripts/land-node-branch.sh:105] | `--dry-run`, in place of both fetches |
| evidentiary | PASS | `  PASS  fetch — refs/remotes/$REMOTE/$MAIN refreshed from $REMOTE` [scripts/land-node-branch.sh:110] | the `<main>` refspec fetch succeeded |
| evidentiary | PASS | `  PASS  fetch_branch — refs/remotes/$REMOTE/$BRANCH refreshed from $REMOTE` [scripts/land-node-branch.sh:114] | the `<branch>` refspec fetch succeeded |
| descriptive | note | `  ..    no refs/heads/$BRANCH on $REMOTE — falling back to a local branch` [scripts/land-node-branch.sh:116] | the branch fetch failed; see D-2 — the fallback is not what the loop then does |
| evidentiary | PASS | `  PASS  commit — resolved $COMMIT to $commit_sha` [scripts/land-node-branch.sh:126] | `rev-parse --verify "$COMMIT^{commit}"` resolved |
| evidentiary | FAIL | `  FAIL  commit — $COMMIT is not a commit in $TOP — fetch the node branch before landing it` [scripts/land-node-branch.sh:124] | the same command failed |
| evidentiary | PASS | `  PASS  branch — $branch_ref at ${branch_sha:0:12}` [scripts/land-node-branch.sh:136] | a branch ref resolved |
| evidentiary | FAIL | `  FAIL  branch — no branch $BRANCH in $TOP or on $REMOTE` [scripts/land-node-branch.sh:135] | neither the tracking ref nor the local branch exists |
| evidentiary | PASS | `  PASS  commit_on_branch — $commit_sha is reachable from $branch_ref (tip ${branch_sha:0:12})` [scripts/land-node-branch.sh:139] | `merge-base --is-ancestor "$commit_sha" "$branch_sha"` |
| evidentiary | FAIL | `  FAIL  commit_on_branch — $commit_sha is not reachable from $branch_ref (tip ${branch_sha:0:12})` [scripts/land-node-branch.sh:141] | the same test failed |
| evidentiary | PASS + terminal | `  PASS  landed — $commit_sha is an ancestor of $REMOTE/$MAIN (${main_sha:0:12}) — already landed` [scripts/land-node-branch.sh:146], then `LANDED (already): $BRANCH @ $commit_sha in $REMOTE/$MAIN` [scripts/land-node-branch.sh:151] or, under `--dry-run`, `LAND: DRY-RUN — nothing to do, $commit_sha is already in $REMOTE/$MAIN` [scripts/land-node-branch.sh:149] | the commit is already an ancestor of the remote main — no merge, no push, no gate, exit 0 |
| evidentiary | PASS | `  PASS  descendant — $branch_ref is a descendant of $REMOTE/$MAIN (${main_sha:0:12})` [scripts/land-node-branch.sh:157] | `$main_sha` is an ancestor of `$branch_sha` |
| evidentiary | FAIL | `  FAIL  descendant — $branch_ref ${branch_sha:0:12} is not a descendant of $REMOTE/$MAIN ${main_sha:0:12} — $behind commit(s) on $REMOTE/$MAIN are not in the branch; rebase the branch onto $REMOTE/$MAIN` [scripts/land-node-branch.sh:160] | the same test failed |
| descriptive | note | `  ..    dry-run: would run gate '$GATE' in a detached worktree at ${commit_sha:0:12}` [scripts/land-node-branch.sh:166] | `--dry-run` with a gate configured |
| evidentiary | PASS | `  PASS  gate — '$GATE' exited 0 at ${commit_sha:0:12} (detached worktree)` [scripts/land-node-branch.sh:178] | the gate returned 0 |
| evidentiary | FAIL | `  FAIL  gate — '$GATE' exited $gate_rc at ${commit_sha:0:12} — ${gate_last:-no output}` [scripts/land-node-branch.sh:183] | the gate returned nonzero; preceded by up to five log lines, each prefixed `  ..    ` [scripts/land-node-branch.sh:182] |
| evidentiary | FAIL | `  FAIL  ff_only — $MAIN at ${head_sha:0:12} is not an ancestor of $commit_sha ($ahead local commit(s) on $MAIN are not in the branch) — not fast-forwardable; push or reset $MAIN, or pass --no-ff` [scripts/land-node-branch.sh:191] | `--ff-only` (the default) and the local `main` carries commits the landing does not |
| evidentiary | PASS | `  PASS  merge — fast-forwarded $MAIN to $(git -C "$TOP" rev-parse --short HEAD)` [scripts/land-node-branch.sh:214] | `git merge --ff-only` succeeded |
| evidentiary | PASS | `  PASS  merge — merge commit $(git -C "$TOP" rev-parse --short HEAD) records $BRANCH` [scripts/land-node-branch.sh:221] | `git merge --no-ff` succeeded |
| evidentiary | FAIL | `  FAIL  merge — git merge --ff-only $commit_sha failed — $(last_reason …)` [scripts/land-node-branch.sh:217] | the ff-only merge failed; it is aborted first [scripts/land-node-branch.sh:216] |
| evidentiary | FAIL | `  FAIL  merge — git merge --no-ff $commit_sha failed — $(last_reason …)` [scripts/land-node-branch.sh:224] | the no-ff merge failed; aborted first [scripts/land-node-branch.sh:223] |
| evidentiary | PASS | `  PASS  push — $REMOTE refs/heads/$MAIN accepted $(git -C "$TOP" rev-parse --short HEAD)` [scripts/land-node-branch.sh:236] | the push was accepted — a claim, not the proof |
| evidentiary | FAIL | `  FAIL  push — git push $REMOTE HEAD:refs/heads/$MAIN failed — $(first_line "$push_out"); local $MAIN is now $(git -C "$TOP" rev-parse --short HEAD) and $REMOTE/$MAIN was not updated` [scripts/land-node-branch.sh:231] | the remote refused the push |
| evidentiary | terminal | `LAND: FAIL ($FAILED) — merged locally, NOT landed` [scripts/land-node-branch.sh:233] | directly after the `push` FAIL — exit 1 |
| evidentiary | PASS | `  PASS  landed — $commit_sha is an ancestor of $REMOTE/$MAIN (${remote_tip:0:12})` [scripts/land-node-branch.sh:245] | the re-fetched remote main contains the commit — the only row the success claim may rest on |
| evidentiary | FAIL | `  FAIL  landed — $commit_sha is NOT an ancestor of $REMOTE/$MAIN (${remote_tip:0:12}) — the push did not land this commit` [scripts/land-node-branch.sh:247] | the push reported success and the re-fetched remote does not contain the commit |
| descriptive | WARN | `  WARN  landed_remote — $REMOTE reports ${wire:0:12}, the tracking ref is ${remote_tip:0:12} — the branch moved during this run` [scripts/land-node-branch.sh:251] | `ls-remote` disagrees with the tracking ref; does not move `FAILED`, so the run can still print `LANDED` |
| evidentiary | terminal | `LANDED: $BRANCH @ $commit_sha in $REMOTE/$MAIN (tip $(git -C "$TOP" rev-parse --short "$MAIN_REF"))` [scripts/land-node-branch.sh:256] | `$FAILED` is 0 |
| evidentiary | terminal | `LAND: FAIL ($FAILED)` [scripts/land-node-branch.sh:259] | `$FAILED` is not 0 — exit 1 |
| evidentiary | terminal | `LAND: REFUSED — $2` [scripts/land-node-branch.sh:49] | every `refuse` — exit 1 |
| evidentiary | terminal | `LAND: DRY-RUN — 0 commands run, nothing merged or pushed, no ref moved` [scripts/land-node-branch.sh:206] | `--dry-run` reached the end of the read-only checks |
| descriptive | terminal | `dry-run: would run:` [scripts/land-node-branch.sh:196], followed by the four `  git -C $TOP …` lines [scripts/land-node-branch.sh:198] [scripts/land-node-branch.sh:202] [scripts/land-node-branch.sh:203] [scripts/land-node-branch.sh:204] | `--dry-run`, before its terminal line |
| descriptive | terminal | `usage: $0 --workdir DIR --branch BRANCH --commit SHA [--remote R] [--main M] [--gate-cmd CMD] [--no-ff] [--dry-run]` [scripts/land-node-branch.sh:79] | a required flag is missing — exit 2 |
| descriptive | terminal | `refusing: --workdir needs a value` [scripts/land-node-branch.sh:64] (one per flag, same shape) | a flag was last on the command line — exit 2 |
| descriptive | terminal | `unknown argument: $1` [scripts/land-node-branch.sh:74], then the header block | an unrecognised argument — exit 2 |

Measured instances, copied from the runs rather than paraphrased:

```text
  PASS  branch — refs/remotes/origin/node/t1 at 0b447fa5b585
  PASS  descendant — refs/remotes/origin/node/t1 is a descendant of origin/main (8a44918b3b45)
  PASS  gate — 'test -f artifact/result.txt && echo gate-ok' exited 0 at 0b447fa5b585 (detached worktree)
  PASS  merge — fast-forwarded main to 0b447fa
  PASS  push — origin refs/heads/main accepted 0b447fa
  PASS  landed — 0b447fa5b58579042ecf2dbd1a96de62cfcd1e47 is an ancestor of origin/main (0b447fa5b585)

LANDED: node/t1 @ 0b447fa5b58579042ecf2dbd1a96de62cfcd1e47 in origin/main (tip 0b447fa)
```

```text
  ..    check-5 ok
  ..    check-6 ok
  ..    check-7 ok
  ..    check-8 ok
  ..    assert: expected 9 stages, got 8
  FAIL  gate — './gate.sh' exited 4 at c8273a7d25cf — assert: expected 9 stages, got 8

LAND: REFUSED — './gate.sh' exited 4 at c8273a7d25cf — assert: expected 9 stages, got 8
```

```text
  FAIL  push — git push origin HEAD:refs/heads/main failed — remote: policy: main is protected; local main is now 52b9f11 and origin/main was not updated

LAND: FAIL (1) — merged locally, NOT landed
```

```text
  PASS  merge — fast-forwarded main to e1760fb
  PASS  push — origin refs/heads/main accepted e1760fb
  FAIL  landed — e1760fb7148e4062567b169bbc3259b631b89b94 is NOT an ancestor of origin/main (f77c2c7cdc91) — the push did not land this commit

LAND: FAIL (1)
```

The last block is the module earning its keep: two PASS rows and then the refusal, because the PASS that matters is the ancestry test, not the push [scripts/land-node-branch.sh:18-20].

## 6. Failure modes

`DIRECTION` is the thing an operator needs: does the failure stop the landing, let something through, or leave one side changed.

| Failure | Presents as (verbatim) | DIRECTION | Recovery |
|---|---|---|---|
| workdir is not a git worktree | `  FAIL  workdir — not a git worktree: $WORKDIR` → `LAND: REFUSED — not a git worktree: $WORKDIR` [scripts/land-node-branch.sh:84-86], exit 1 | **fail-closed**; nothing measured, nothing merged | pass a real worktree. Also the row produced when `git` is missing or when the caller's environment carries a `GIT_DIR` — measured: `GIT_DIR=/nonexistent/x.git` on a valid clone printed exactly this pair (D-6) |
| dirty worktree | `  FAIL  workdir_clean — 1 uncommitted path(s) in …/control (first: ?? scratch.tmp) — commit or stash them first` → `LAND: REFUSED — …` [scripts/land-node-branch.sh:88-93], exit 1 | **fail-closed**, before any fetch or gate | commit or stash; the row names the first path so the operator need not guess |
| checked out on another branch | `  FAIL  on_main — workdir is on 'node/t1', not 'main' — a landing merges into main` [scripts/land-node-branch.sh:99], exit 1 | **fail-closed** | check out `$MAIN`; the lander will not move a branch it was not told about |
| detached HEAD | `  FAIL  on_main — detached HEAD in …/control — check out main before landing` [scripts/land-node-branch.sh:97], exit 1 | **fail-closed** | check out `$MAIN` |
| `<main>` cannot be fetched | `  FAIL  fetch — git fetch $REMOTE $MAIN failed — <first line of git's stderr>` → `LAND: REFUSED — …` [scripts/land-node-branch.sh:107-108] | **fail-closed**: with no tracking ref there is no ancestor test, so nothing is merged | fix the remote or credential; the row carries git's first stderr line |
| `<main>` unresolvable | refuse row `main_tip`: `LAND: REFUSED — cannot resolve $MAIN_REF in $TOP` [scripts/land-node-branch.sh:120-121] | **fail-closed** | fetch the remote, or name the right `--main` |
| the envelope's commit is absent from the clone | `  FAIL  commit — $COMMIT is not a commit in $TOP — fetch the node branch before landing it` [scripts/land-node-branch.sh:123-124], exit 1 | **fail-closed**, and it is the row a `--dry-run` hits first on a fresh control host (D-1) | fetch the branch, or drop `--dry-run`, which skips the fetch by design [scripts/land-node-branch.sh:104-105] |
| the named branch exists nowhere | `  FAIL  branch — no branch $BRANCH in $TOP or on $REMOTE` [scripts/land-node-branch.sh:135] | **fail-closed**; the resolution order is the remote-tracking ref first (D-2) | push the branch from the node, or create the local branch the fallback expects |
| the commit is not reachable from the branch | `  FAIL  commit_on_branch — $commit_sha is not reachable from $branch_ref (tip ${branch_sha:0:12})` [scripts/land-node-branch.sh:141] | **fail-closed** — the pair-integrity check that stops an envelope naming one task's commit with another task's branch | use the branch the commit is actually on |
| the branch is behind `<main>` | `  FAIL  descendant — refs/remotes/origin/node/t1 847c07d310d8 is not a descendant of origin/main 060b8e4b8a82 — 1 commit(s) on origin/main are not in the branch; rebase the branch onto origin/main` [scripts/land-node-branch.sh:156-160] | **fail-closed**, with the count of missing commits inside the row | rebase the branch onto `origin/<main>`; the repo's own arm runs that remedy for real [tests/selftest.sh:2305-2312] |
| the gate worktree cannot be created | `  FAIL  gate — cannot create a detached worktree at $commit_sha in $TOP to run '$GATE'` [scripts/land-node-branch.sh:170-172]; with an unusable `TMPDIR` a bare `mktemp: failed to create directory …` line precedes it | **fail-closed** on the landing, **misattributed** on the cause (D-5) | fix disk/`TMPDIR`/permissions; the row blames the gate |
| the gate exits nonzero | `  FAIL  gate — '$GATE' exited 3 at c3e556290ffb — assert: artifact missing` [scripts/land-node-branch.sh:177-183], exit 1 | **fail-closed**: measured, `control main after gate refusal: 6abde06` — unchanged, and no worktree left behind | fix the project; the last five log lines are echoed, so the failure is visible without a re-run |
| `--ff-only` and the local `main` is ahead | `  FAIL  ff_only — main at 9c1f382d4349 is not an ancestor of $commit_sha (1 local commit(s) on main are not in the branch) — not fast-forwardable; push or reset main, or pass --no-ff` [scripts/land-node-branch.sh:188-191] | **fail-closed**; the alternative (`--no-ff`) is named in the row and widens what lands (D-3) | push or reset the local `main`, or accept `--no-ff` knowingly |
| the merge conflicts | `  FAIL  merge — git merge --no-ff d3719db73b18… failed — CONFLICT (content): Merge conflict in README.md` [scripts/land-node-branch.sh:220-224], exit 1 | **fail-closed and self-cleaning**: measured `control status: []` and `control MERGE_HEAD present: NO` — the abort ran [scripts/land-node-branch.sh:223] | resolve the conflict on the branch, then rerun |
| the remote rejects the push | `  FAIL  push — git push origin HEAD:refs/heads/main failed — remote: policy: main is protected; local main is now 52b9f11 and origin/main was not updated`, then `LAND: FAIL (1) — merged locally, NOT landed` [scripts/land-node-branch.sh:230-234], exit 1 | **fail-closed on the landing and leaves the control clone diverged**: measured `origin main after rejected push: f77c2c7`, `control main after rejected push: 52b9f11`. Nothing rolls the local merge back | repair the local `main` (`reset --hard` to `origin/<main>`, or push once policy allows); rerunning the same command hits `ff_only` until one of those happens |
| the push landed nothing | `  FAIL  landed — $commit_sha is NOT an ancestor of $REMOTE/$MAIN (…) — the push did not land this commit` then `LAND: FAIL (1)` [scripts/land-node-branch.sh:244-248] [scripts/land-node-branch.sh:259], exit 1 | **fail-closed and honest**: merge and push both printed PASS; only the proof row fails — measured with a `post-receive` hook that reset `main` back | investigate what moved `main`; the commit is on the local clone and on neither remote ref |
| the remote moved during the run | `  WARN  landed_remote — $REMOTE reports …, the tracking ref is … — the branch moved during this run` [scripts/land-node-branch.sh:249-252] | **fail-open by construction**: `warn` does not move `FAILED` [scripts/lib.sh:8], so the run still prints `LANDED` and exits 0. Not exercised — the window is between the post-push fetch and the `ls-remote` | re-read the remote by hand; the row prints both shas |
| no gate was configured | no `gate` row at all; the measured gateless landing went from `PASS descendant` straight to `PASS merge` | **fail-open by configuration** [scripts/land-node-branch.sh:164]; also on the already-landed path, where even a failing gate is never run (D-4) | always pass `--gate-cmd`; it is the only thing between a node's tree and `origin/<main>` |

Defects measured while filling this section (documented, **not** fixed — `scripts/` is out of scope for this task; they are the concrete content of the handbook's D-8 entry [docs/LOOP-CODEX.md:54]):

1. **LAND-D1 — `--dry-run` cannot preview the one landing it is for.** The dry-run path skips both fetches [scripts/land-node-branch.sh:104-105] and then requires the commit to exist locally [scripts/land-node-branch.sh:123]. On a control clone that has not yet fetched the node branch — the normal first landing — every dry run refuses: measured `  FAIL  commit — f7e6035d0d6e… is not a commit in …/control — fetch the node branch before landing it`, exit 1, with `commit object present after dry-run: NO`. The read-only preview is unavailable exactly when an operator wants it, and available only after someone else's fetch.
2. **LAND-D2 — "falling back to a local branch" is not what the code does, and a stale tracking ref wins.** The note claims a fallback [scripts/land-node-branch.sh:116], but the resolution loop tries `refs/remotes/$REMOTE/$BRANCH` before `refs/heads/$BRANCH` [scripts/land-node-branch.sh:130-134], and a *failed* fetch leaves the previous tracking ref in place. Measured with the remote branch deleted, the tracking ref at `c8273a7` and `refs/heads/node/g` at `d2c0ce7`: the run printed the fallback note, then `  PASS  branch — refs/remotes/origin/node/g at c8273a7d25cf` and `  FAIL  commit_on_branch — d2c0ce7072e3… is not reachable from refs/remotes/origin/node/g` — refusing a commit that is on the branch it named. The note and the row contradict each other on one screen.
3. **LAND-D3 — `--no-ff` publishes whatever else sits on the control clone's `main`.** The ff-only guard is skipped [scripts/land-node-branch.sh:189] and the push is `HEAD:refs/heads/<main>` [scripts/land-node-branch.sh:230], so local commits that are in neither the branch nor the envelope ride along. Measured: the landed history was `99c453c merge: land node/t9 … | 1860e3a control: gate.sh | b772029 node: three | …`, where `1860e3a` never existed on the node branch. Under the default `--ff-only` that cannot happen; the flag that exists for convenience is the one that widens the artifact return.
4. **LAND-D4 — the already-landed path returns 0 without running the gate.** The idempotence check sits above the gate block and exits [scripts/land-node-branch.sh:145-154] before the gate is reached [scripts/land-node-branch.sh:164]. Measured: a second run of an already-landed commit with `--gate-cmd 'exit 99'` printed `LANDED (already): …` and exited 0 with no `gate` row. A commit that entered `main` through an earlier gateless run can never be gated by re-running the landing.
5. **LAND-D5 — an unusable `TMPDIR` is reported as a gate failure.** `mktemp -d` [scripts/land-node-branch.sh:168] is unguarded; with `TMPDIR=/nonexistent/md20e` the run leaked a bare `mktemp: failed to create directory via template …` to stderr and then refused with `  FAIL  gate — cannot create a detached worktree at … in … to run 'true'`. The refusal is correct and the attribution is wrong: the gate never ran, and the operator is pointed at the project instead of the host.
6. **LAND-D6 — an inherited `GIT_DIR` turns a valid worktree into "not a git worktree".** Every call is `git -C` with no environment cleanup [scripts/land-node-branch.sh:84]; measured, `GIT_DIR=/nonexistent/x.git` on a clean clone printed `  FAIL  workdir — not a git worktree: …/control` and refused. Fail-closed, but the row names the wrong object, and the same shape covers `GIT_WORK_TREE` and `GIT_INDEX_FILE`.
7. **LAND-D7 — nothing transports the branch, and the envelope's `branch` can name a branch that exists nowhere.** The script assumes the node pushed it [scripts/land-node-branch.sh:111-112], and no file under `scripts/` pushes `refs/heads/node/…` (only the fixture [tests/selftest.sh:2265]). The envelope's `branch` is `git rev-parse --abbrev-ref HEAD` on the node [scripts/node-bus-worker.py:786] [scripts/node-bus-worker.py:930], which returns `HEAD` on a detached node checkout and `main` on a node that never left main. The fallback then needs a local branch in the control clone, which nothing creates. This is the D-8 gap in concrete form: the return path is a ref on a remote that no step is responsible for publishing.
8. **LAND-D8 — the evidence row names a wider object than the one that lands.** `ok descendant` prints `$branch_ref is a descendant of $REMOTE/$MAIN` [scripts/land-node-branch.sh:157] while the merge target is `$commit_sha` [scripts/land-node-branch.sh:213] [scripts/land-node-branch.sh:220]. With a branch tip one commit past the envelope's commit every row reads as if the tip lands; measured, only the commit did (`C2 is in origin main: NO`, and the landed tree carried `result-1`, not the tip's `result-2`).
9. **LAND-D9 — a push failure is summarized into a line that omits the reason.** `first_line` keeps line 1 only [scripts/land-node-branch.sh:35] [scripts/land-node-branch.sh:231]; measured, the row read `remote: policy: main is protected` and dropped git's `! [remote rejected] …` line and its hint. The operator gets the remote's remark, not the rejection.
10. **LAND-D10 — the loop document claims a tree check this module does not perform.** [docs/LOOP-CODEX.md:21] says the step proves the commit is an ancestor **and** `the file is in that tree`; the script checks ancestry only [scripts/land-node-branch.sh:244-248], and the only tree check anywhere is a caller-supplied `--gate-cmd` [scripts/land-node-branch.sh:175], which is optional. A `PASS landed` row is an ancestry claim; reading it as an artifact claim is a documentation artefact, not a code one.

## 7. Environment and settings it reads

- **Arguments**, parsed in the `while [ $# -gt 0 ]` block [scripts/land-node-branch.sh:62-76]:
  - required: `--workdir DIR` [scripts/land-node-branch.sh:64], `--branch NAME` [scripts/land-node-branch.sh:65], `--commit SHA` [scripts/land-node-branch.sh:66]; any missing one prints the usage line and exits 2 [scripts/land-node-branch.sh:78-79];
  - optional: `--remote R` [scripts/land-node-branch.sh:67], `--main M` [scripts/land-node-branch.sh:68], `--gate-cmd CMD` [scripts/land-node-branch.sh:69], `--ff-only` [scripts/land-node-branch.sh:70], `--no-ff` [scripts/land-node-branch.sh:71], `--dry-run` [scripts/land-node-branch.sh:72], `-h|--help` [scripts/land-node-branch.sh:73];
  - `--help` prints the leading comment block, extracted by `awk` up to the first non-comment line [scripts/land-node-branch.sh:33], so it cannot drift from the header.
- **Defaults**, assigned before parsing and overwritten only by a flag [scripts/land-node-branch.sh:29]: `WORKDIR="" BRANCH="" COMMIT="" REMOTE=origin MAIN=main GATE="" FF_ONLY=1 DRY=0`. Default remote `origin`, default target `main`, default gate *none*, default merge `--ff-only`. Measured: `--main trunk` on a repo whose default branch is `trunk` landed `27fd2cd` and printed `PASS on_main — trunk is checked out` with `origin refs: node/trunkwork=27fd2cd trunk=27fd2cd`; `--remote upstream` after renaming the remote printed `PASS fetch — refs/remotes/upstream/trunk refreshed from upstream` and `in upstream/trunk`.
- **No environment variable is read by name.** The variables referenced are the ones the script sets — `HERE TOP WORKDIR BRANCH COMMIT REMOTE MAIN GATE FF_ONLY DRY GATE_WT MAIN_REF BRANCH_REF` [scripts/land-node-branch.sh:26-30] — plus lib.sh's `FAILED` [scripts/lib.sh:11]. `PATH` decides which `git`, `awk`, `sed`, `grep` and `mktemp` run (§2a).
- **`TMPDIR` is read implicitly**, by `mktemp -d` for the gate worktree [scripts/land-node-branch.sh:168]. Measured: unset or unusable is not fatal until a gate is configured, and then the refusal blames the gate (D-5). The directory is removed on success [scripts/land-node-branch.sh:179] and by the EXIT trap otherwise [scripts/land-node-branch.sh:54-60]; a post-run listing of the control clone's worktrees and of `$TMPDIR` showed no residue.
- **`GIT_*` in the caller's environment is inherited** — no `env -i`, no `unset`, no `--git-dir` handling; measured, a stray `GIT_DIR` refuses a valid clone (D-6). Conversely, `git -C "$TOP"` is used everywhere, so the script does not depend on the caller's working directory [scripts/land-node-branch.sh:84].
- **Credentials**: none are named. The source contains no `token`, `credential`, `SSH` or `GIT_ASKPASS` string, so no secret reaches argv or the log through it; the push authenticates with whatever git already holds — an ssh key or a credential-helper file — which is the file-path discipline the project requires (fact: FACT-05). A missing credential surfaces as the remote's rejection in the `push` row [scripts/land-node-branch.sh:231], never as a printed credential.
- **State the host must have**: the workdir is a git worktree and clean [scripts/land-node-branch.sh:88-94], with `<main>` checked out rather than detached [scripts/land-node-branch.sh:96-100]; the remote is reachable for `fetch` [scripts/land-node-branch.sh:107] and `push` [scripts/land-node-branch.sh:230]; `git worktree` must be usable if a gate is given [scripts/land-node-branch.sh:170]. There is no lock, no sentinel and no re-entrancy guard, so two landers on one clone serialise only through git's own locking — what a second run sees is the clean-worktree check.
- **Exit codes**: `0` for a landing, an already-landed commit, and a completed dry run [scripts/land-node-branch.sh:153] [scripts/land-node-branch.sh:207] [scripts/land-node-branch.sh:257]; `1` for every `refuse` [scripts/land-node-branch.sh:50] and both failure terminals [scripts/land-node-branch.sh:234] [scripts/land-node-branch.sh:260]; `2` for usage and argument errors [scripts/land-node-branch.sh:74] [scripts/land-node-branch.sh:79]. Measured: `--help` 0; no arguments 2; `--workdir` alone 2; `--nope` 2; every refusal 1; landing 0.

## 8. Evidence of record

- **What was run, and from where.** All runs on 2026-11-05 against `scripts/land-node-branch.sh` at revision `b9f56e6` (`git -C /home/kara/code-factory rev-parse --short HEAD` = `b9f56e6` = `origin/main`), from a worktree at `/home/kara/proj-wt-md-20e` on branch `wt/md-20e`. Scratch repositories only: one bare origin, one seed clone, one control clone and one node clone per arm, all under `$TMPDIR` (`/home/kara/.hermes/cache/scratch/md20e*`). The real repository was never a landing target, and the worktree's `git status --short` stayed empty except for this file.
- **The recipe** in §3 ran to `20 ok, 0 failed`, exit 0, and is reproduced verbatim so a reviewer can re-run it without the scratch directory.
- **The repository's own arm** — [tests/selftest.sh:2230] to [tests/selftest.sh:2390] — ran against the same worktree and printed 13 `PASS` legs with `CF213 fails=0`, exit 0: syntax, usage exit 2, dirty workdir, commit off the branch, an unfetched commit, `ff_only`, a stale branch, a red gate that moved no ref, a dry run that named its commands and moved nothing, a landing whose gate ran on the node's tree, a fresh clone of the remote containing the landed commit, an idempotent re-run, and a refused push that printed no success row [tests/selftest.sh:2236] [tests/selftest.sh:2273] [tests/selftest.sh:2340] [tests/selftest.sh:2377].
- **The document gate**: `python3 scripts/master_doc_check.py docs/master --only 20- --strict` → `MASTER-DOC: PASS` (0 errors, 0 warnings). A full-tree run of the same checker reports `40 module(s): 20 VERIFIED, 0 error(s), 0 warning(s)`.
- **Facts this section stands on**: the node-not-control-host split (fact: FACT-01) is why landing is a control-host step; the file-path credential discipline (fact: FACT-05) is what §7's "no credential is named" claim is held to; and the rule that a row closes on a re-runnable command rather than a commit message (fact: FACT-10) is why §3 is a script and not a transcript.
- **What the evidence does not cover.** Three conditions were read from the source and never executed: the `landed_remote` warning window [scripts/land-node-branch.sh:249-252] (a race between the post-push fetch and `ls-remote`), a `last_reason` degraded by a missing `sed` [scripts/land-node-branch.sh:38-43], and a rejection from a real forge's protected-branch rule (emulated here with a `pre-receive` hook). Each is labelled read-from-code where it appears in §5 and §6.
- **Documentation drift this module exposes.** [docs/LOOP-CODEX.md:21] records the step as proving the file is in the tree (D-10 above); [docs/DESIGN.md:57] correctly records that nothing calls the script and that the control-host clone refresh (CF-212) and the landed-sha record (CF-213) were the open items; [docs/ACCEPTANCE-PLAN.md:149] claims the acceptance arm this document re-ran. The index row for this module [docs/master/00-INDEX.md:27] still reads `RED` and was left untouched — this task was scoped to one file.
