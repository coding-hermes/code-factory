# CF-129 — `docs/BOARD.md` misstated which flag each `board_drift.py` leg reads

Tick: `code-factory-docs-2026-11-04-02-39-16` (docs lane)
Measured at: `origin/main` = `c29c024bdbd46182de3b57340d1a0661bff5bab9`, 2026-11-04T02:4x Z
Row: CF-129 (`P4`) — filed by `qa-lane-docs-qa-2026-11-03-20-47-54-cf129`

## 1. The claim that was false

`docs/BOARD.md`, Publish-drift census section, before this change:

> `--repo <path>` selects the repository resolving the ref; `--no-head` skips ancestry.

That sentence was a single statement about two different legs of the check. `--repo` does not
select the repository that resolves the ref for the HEAD/ancestry leg, so a reader who followed
it — a workdir on one checkout, `--repo` naming a repository that carries `origin/main` — got
`FAIL HEAD ancestry` and `RESULT: DRIFT` with the ref demonstrably resolvable.

## 2. The code path that disproves it

`scripts/board_drift.py` reads Git from two flags:

```
 97|    workdir = Path(args.workdir).expanduser().resolve()
 98|    repo = Path(args.repo).expanduser().resolve() if args.repo else workdir
...
111|                published[name] = git(repo, "show", f"{args.ref}:{BOARD / name}")
```

`repo` is used only for the published side. The ancestry leg never sees it:

```
165|    if not args.no_head and not args.published_dir:
166|        try:
167|            head = git(workdir, "rev-parse", "HEAD").decode().strip()
168|            report.row(True, "HEAD", f"git rev-parse HEAD: {head}")
169|            ref_sha = git(workdir, "rev-parse", "--verify", f"{args.ref}^{{commit}}")
170|            ref_sha = ref_sha.decode().strip()
171|            try:
172|                git(workdir, "merge-base", "--is-ancestor", "HEAD", args.ref)
```

All three ancestry probes run with `-C <workdir>`. `--no-head` (`:201-203`) and
`--published-dir` (`:103`, `:165`) are the only ways to skip that leg.

## 3. Measurement

Fixture: a fresh Git repository holding byte-identical copies of the published board files
(126 task rows / 190 event rows at `c29c024`) and **no** `origin/main` ref. `--repo` was the
real checkout, whose `origin/main` resolves.

Reproduction script (the exact file run for the transcript below):

```bash
#!/usr/bin/env bash
set -uo pipefail
REPO=/home/kara/code-factory
S=$(mktemp -d /home/kara/.hermes/cache/scratch/cf129.XXXXXX) || exit 1
A="$S/workdir"
mkdir -p "$A/.coding-hermes/board" || exit 1
git -C "$REPO" show origin/main:.coding-hermes/board/tasks.jsonl > "$A/.coding-hermes/board/tasks.jsonl" || exit 1
git -C "$REPO" show origin/main:.coding-hermes/board/events.jsonl > "$A/.coding-hermes/board/events.jsonl" || exit 1
git init -q "$A" || exit 1
git -C "$A" add .coding-hermes/board/tasks.jsonl .coding-hermes/board/events.jsonl || exit 1
git -C "$A" -c user.name=cf129 -c user.email=cf129@example.invalid \
  commit -qm "fixture: board bytes at origin/main, no origin/main ref" || exit 1
git -C "$A" branch -m main || exit 1
python3 -B "$REPO/scripts/board_drift.py" check --workdir "$A" --repo "$REPO" --ref origin/main; echo "ARM1_RC=$?"
python3 -B "$REPO/scripts/board_drift.py" check --workdir "$A" --repo "$REPO" --ref origin/main --no-head; echo "ARM2_RC=$?"
python3 -B "$REPO/scripts/board_drift.py" check --workdir "$A" --ref origin/main; echo "ARM3_RC=$?"
```

Transcript (`bash /home/kara/.hermes/cache/scratch/cf129-repro.sh`, 2026-11-04):

```text
SCRATCH=/home/kara/.hermes/cache/scratch/cf129.7vvgx4
WORKDIR_HEAD=a8503e3c46c125db2c1420c7a98cb200b315d482
WORKDIR_REF_ORIGIN_MAIN=<absent>
REPO_REF_ORIGIN_MAIN=c29c024bdbd46182de3b57340d1a0661bff5bab9

=== ARM 1: the form docs/BOARD.md:47 documents, --repo naming the repo that has the ref ===
PASS  workdir files — tasks.jsonl: 407824 bytes
PASS  workdir files — events.jsonl: 142024 bytes
PASS  published ref — origin/main:.coding-hermes/board/tasks.jsonl resolved
PASS  published ref — origin/main:.coding-hermes/board/events.jsonl resolved
PASS  sha256 workdir tasks.jsonl — 33d53c808d0c6780fce78c339760c154e3a3238860672949e4dd62c07450471c
PASS  sha256 published tasks.jsonl — 33d53c808d0c6780fce78c339760c154e3a3238860672949e4dd62c07450471c
PASS  byte parity tasks.jsonl — identical
PASS  sha256 workdir events.jsonl — 0d7988f4d09584364527cdff34b4835d7a3a308501eaf2fa519ca16caf299bf1
PASS  sha256 published events.jsonl — 0d7988f4d09584364527cdff34b4835d7a3a308501eaf2fa519ca16caf299bf1
PASS  byte parity events.jsonl — identical
PASS  board missing ids — none
PASS  board extra ids — none
PASS  board rows — 126 vs 126 rows; 0 divergent ids: none
PASS  HEAD — git rev-parse HEAD: a8503e3c46c125db2c1420c7a98cb200b315d482
FAIL  HEAD ancestry — git rev-parse --verify origin/main^{commit}: exit 128; fatal: Needed a single revision
RESULT: DRIFT (1 failed)
ARM1_RC=1

=== ARM 2: same workdir, --no-head (the ref is never resolved in the workdir) ===
PASS  workdir files — tasks.jsonl: 407824 bytes
PASS  workdir files — events.jsonl: 142024 bytes
PASS  published ref — origin/main:.coding-hermes/board/tasks.jsonl resolved
PASS  published ref — origin/main:.coding-hermes/board/events.jsonl resolved
PASS  sha256 workdir tasks.jsonl — 33d53c808d0c6780fce78c339760c154e3a3238860672949e4dd62c07450471c
PASS  sha256 published tasks.jsonl — 33d53c808d0c6780fce78c339760c154e3a3238860672949e4dd62c07450471c
PASS  byte parity tasks.jsonl — identical
PASS  sha256 workdir events.jsonl — 0d7988f4d09584364527cdff34b4835d7a3a308501eaf2fa519ca16caf299bf1
PASS  sha256 published events.jsonl — 0d7988f4d09584364527cdff34b4835d7a3a308501eaf2fa519ca16caf299bf1
PASS  byte parity events.jsonl — identical
PASS  board missing ids — none
PASS  board extra ids — none
PASS  board rows — 126 vs 126 rows; 0 divergent ids: none
RESULT: OK
ARM2_RC=0

=== ARM 3: --repo absent, workdir names a repo without the ref ===
PASS  workdir files — tasks.jsonl: 407824 bytes
PASS  workdir files — events.jsonl: 142024 bytes
FAIL  published ref — git show origin/main:.coding-hermes/board/tasks.jsonl: exit 128; fatal: invalid object name 'origin/main'.
FAIL  published ref — git show origin/main:.coding-hermes/board/events.jsonl: exit 128; fatal: invalid object name 'origin/main'.
PASS  sha256 workdir tasks.jsonl — 33d53c808d0c6780fce78c339760c154e3a3238860672949e4dd62c07450471c
FAIL  byte parity tasks.jsonl — unavailable board file
PASS  sha256 workdir events.jsonl — 0d7988f4d09584364527cdff34b4835d7a3a308501eaf2fa519ca16caf299bf1
FAIL  byte parity events.jsonl — unavailable board file
FAIL  board rows — census unavailable: missing tasks.jsonl
PASS  HEAD — git rev-parse HEAD: a8503e3c46c125db2c1420c7a98cb200b315d482
FAIL  HEAD ancestry — git rev-parse --verify origin/main^{commit}: exit 128; fatal: Needed a single revision
RESULT: DRIFT (6 failed)
ARM3_RC=1
```

ARM 1 is the false-documentation arm: every published-side and parity row passes, and the only
failure is the ancestry leg resolving `origin/main` in the workdir. ARM 2 is the same run with
`--no-head` and returns `RESULT: OK` — proof that the ref, not the board bytes, was the blocker.

## 4. What the document now says

`docs/BOARD.md` (Publish-drift census) now states the split explicitly, with the two code
locations, and adds the measured consequence: a workdir without `<ref>` prints
`FAIL HEAD ancestry` + `RESULT: DRIFT (1 failed)` even when `--repo` carries the ref, and
`--no-head` is the flag to use when the ref lives only in `--repo`.

## 5. Observations this tick did not act on

- ARM 3 prints `board rows — census unavailable: missing tasks.jsonl` while `tasks.jsonl` is
  present in the workdir and only the **published** side is missing. The message names the wrong
  file; the failure verdict is correct. Not covered by CF-129's criterion, so not changed here.
- The census block below the section (`Current measured state`) was measured at 116 rows / 168
  events / `RESULT: OK (47 warning(s))`; at this tip the same commands print 126 rows / 190
  events / `RESULT: OK (55 warning(s))`. The block self-qualifies ("measure it instead of quoting
  an older snapshot") and is owned by the sync lane's census reconciliation (CF-121/CF-122
  family), so this tick did not restate it.

ch:trace row=CF-129 spec=docs/BOARD.md#publish-drift-census test=scripts/board_drift.py::check doc=docs/BOARD.md prompt=prompts/docs.md evidence=docs/audits/code-factory-docs-2026-11-04-CF-129.md witness=cmd:arm1-DRIFT-arm2-OK verdict=none:judged-after-commit commit=none:self-referential-hash memory=none:written-after-push
