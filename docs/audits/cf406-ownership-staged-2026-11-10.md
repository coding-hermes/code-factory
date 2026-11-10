# CF-406 evidence — ownership.py classified a staged checkout as clean

Row: CF-406 (P1). Chapter: `III.documentation.panel` (OUTLINE M6 DOCUMENTATION, S4 panel).
Implementation commit: `fe0931c1`. Tick: `code-factory-2026-11-10-16-33-02`.

## Defect

`scripts/ownership.py status` derived ownership state from untracked paths only, so a checkout
holding another writer's **staged** (or unstaged) tracked modification reported
`state: clean` and exited 0. Every lane is instructed to run this probe before taking board
work, so a foreman was waved through onto a tree that already carried someone else's edits.

Reproduction on the pre-fix script (`git show 9906b741:scripts/ownership.py`), fixture
`git init` + one commit + `echo two >> tracked.txt` + `git add tracked.txt`:

```text
$ git -C <fixture> status --porcelain
M  tracked.txt
$ python3 <pre-fix>/ownership.py status --workdir <fixture>
{ "workdir": "<fixture>", "untracked": 0, "lock": null, "state": "clean" }
rc=0
```

The same fixture after `git restore --staged tracked.txt` produced the identical verdict, i.e.
a dirty tree and a clean tree were indistinguishable.

## Change

- `scripts/ownership.py` — one `git status --porcelain=v1 -z` parser returns untracked and
  dirty paths separately (rename/copy records consume both NUL fields and report the new path).
  New JSON keys `dirty` and `dirty_paths`; `untracked` keeps its old meaning. A live lock now
  covers dirty paths as well as untracked ones. State order: clean → held-by-live-worker →
  unowned-changes (any tracked modification) → residue (`.gitreins/rescued-`) → unowned-changes.
  Invariant stated in the module docstring: *a tree whose `git status --porcelain` is non-empty
  is never "clean"*.
- `tests/selftest.sh` — one arm inside section 12, wrapped in `# BEGIN ownership-staged` /
  `# END ownership-staged`; no new numbered section, no arm-census change.
- `docs/handbook/chapters/M6-documentation.md` — M6.S4 now records the four states, the added
  fields and the invariant, with a re-runnable command. The row's own `chapter` field said
  `III.memory.ownership`; no memory module exists (modules are M0–M12), so M6.S4 is the owner.

## Verification (foreman re-run, post-fix script)

| Fixture | porcelain | state | rc |
|---|---|---|---|
| staged modification | `M  tracked.txt` | `unowned-changes`, `dirty_paths: ["tracked.txt"]` | 3 |
| unstaged modification | ` M tracked.txt` | `unowned-changes`, names the path | 3 |
| staged + renamed | `R  tracked.txt -> renamed.txt` | `unowned-changes`, `["renamed.txt"]` only | 3 |
| clean tree | empty | `clean`, `dirty: 0` | 0 |
| `.gitreins/rescued-1.patch` | `?? .gitreins/` | `unowned-changes` (pre-existing: the directory-level record does not match the `.gitreins/rescued-` substring) | 3 |

Arm, run standalone:

```text
post-fix :   PASS  CF-406 ownership status distinguishes staged tracked changes and clean state
pre-fix  :   FAIL  CF-406 ownership status staged/clean distinction (staged rc=0, clean rc=0)
```

The pre-fix FAIL is the negative control: an arm that passes against the buggy script cannot
discriminate and would not be a regression test.

Gates:

```text
python3 -m py_compile scripts/ownership.py   -> rc 0
bash -n tests/selftest.sh                    -> rc 0
ruff format --check scripts/ownership.py     -> 1 file already formatted
bash tests/selftest.sh                       -> SELFTEST: PASS (exit 0, 532 PASS rows)
```

## GitReins record

Verdict run `0789d0af` (`.gitreins/history/2026-11-10/0789d0af/verdict.json`): stage tier1 PASS
(lint / secrets gitleaks+builtin / tests), stage tier2 PASS — COMPLETE on all four criteria,
overall PASS. The judge re-measured the staged fixture, the rename record, the exit codes, the
arm's negative control and the handbook text against the code.

## Residuals filed, not fixed here

- The residue classifier matches the literal `.gitreins/rescued-` string, so a directory-level
  `?? .gitreins/` record reports `unowned-changes` rather than `residue`. Pre-existing and
  unchanged by this row; a lane following the unblock doctrine would attribute instead of
  disposing. Candidate follow-up.
- `claim` writes `.coding-hermes/panel.lock` inside the checked tree, which itself appears as an
  untracked path outside the claim, so a live holder still reads `unowned-changes` with
  `outside_claim: [".coding-hermes/"]`. Pre-existing; the lock should be exempt from its own
  pollution. Candidate follow-up.
- The new arm inherits ambient git config; it does not pin `GIT_CONFIG_GLOBAL=/dev/null` the way
  the cf266 arm does. Harmless on this host (no global `core.hooksPath`), false-red risk elsewhere.

## CI

`gh run list --repo coding-hermes/code-factory` returns no runs: this project's gate is
`tests/selftest.sh` plus the GitReins guard, not GitHub Actions.
