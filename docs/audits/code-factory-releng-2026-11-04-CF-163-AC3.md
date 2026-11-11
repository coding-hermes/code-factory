# Releng lane — CF-163 AC3 landing and tree state (tick 2026-11-04-06-11-13)

Lane: `code-factory-duckbrain-releng` · tick `code-factory-duckbrain-releng-2026-11-04-06-11-13`
Host clock: 2026-11-04 01:11–01:35 -0500 · lane workdir locator `~/code-factory`

## Transport (why this tick ran from a clone)

The registered candidate `~/code-factory` is a valid, attached, marker-free `main` on
`git@github.com:coding-hermes/code-factory.git` (root/operation gate: `gate_violations=0`), but it
carries an unresolved family ownership surface:

- 53 untracked `.gitreins/history/**` verdict bundles (unpublished writer residue).
- Four sibling lanes of the same repo were live at `01:11:13` (`code-factory-docs`,
  `code-factory-duckbrain`, `code-factory-duckbrain-sync`, `code-factory-pm`) — a family-wide
  stand-down barrier.
- `.coding-hermes/board/.lock` is a 0-byte file from 2026-11-03 07:40 with **no consumer**
  (`grep -rn 'flock|fcntl' scripts/boardctl*` → no hits) and no holder (`fuser -v` → empty):
  residue (CF-119), not an ownership barrier.

Per the lane's escape hatch, the read, the gate, the posture probes and the board write ran in a
fresh clone of `origin/main` in the tick scratch dir. The candidate was never read for project
evidence, never written, never cleaned. A writer census at the candidate reported only the census
pipeline stage itself (`comm=tail`), i.e. no foreign writer inside the checkout.

## Gate (CI-equivalent — this repo has no GitHub Actions)

| head | command | result |
|---|---|---|
| `1aeb0c7` (published tip at tick start) | `bash tests/selftest.sh` | `SELFTEST: PASS`, rc=0, 103 `PASS` rows, 19 intentional-fixture `FAIL` rows |
| `5794a49` (worker commit, judged) | `bash tests/selftest.sh` | `SELFTEST: PASS`, rc=0, 106 `PASS` rows |
| `f121ed3` (merged tip, pushed) | `bash tests/selftest.sh` | `SELFTEST: PASS`, rc=0, 106 `PASS` rows |

Host loadavg during the runs: 10.2 → 28.4 → 48.6 (1-min). The gate's spawn-bound cost was not
re-measured this tick; no perf claim is made here.

`gh run list --repo coding-hermes/code-factory --limit 3` → `[]` — the documented healthy
no-Actions state, not a finding.

## Landed: CF-163 AC3 (one gitleaks claim must name its `--log-opts` scan scope)

Commit `5794a4927f60d35e35d51bf4cc54377e6902da1f`, merged forward as `f121ed3`
(`--no-ff` so the judged commit stays an ancestor and its verdict stays commit-bound).

Four files:

| file | change |
|---|---|
| `scripts/check_scan_scope.py` | new stdlib gate: every line in `docs/audits/code-factory-releng-*.md` and `docs/SECURITY-TRIAGE.md` that mentions `gitleaks` must carry `--log-opts` on the same line; exit 1 with a named `FAIL audit-scope: <path>:<line>` row per violation, 0 clean, 2 unreadable path |
| `tests/selftest.sh` | new section 34 with three arms: green on the real tree, named red on an unscoped fixture, green once the fixture names its scope |
| `docs/audits/code-factory-releng-2026-11-04-CF-161.md` | `Secrets in history` row now records the all-refs arm (`--log-opts="--all"` → 547 findings in 64 commits, 64/64 not ancestors of `main`) beside the main-only arm (0 findings), plus a disclosed correction note |
| `docs/audits/code-factory-releng-2026-11-04-CF-163.md` | the scope-correction sentence now names that the historical arm carried no `--log-opts` |

Evidence, all re-run by the foreman at the landed tree:

| check | command | result |
|---|---|---|
| red on the pre-fix tree | `python3 scripts/check_scan_scope.py <pre-fix copies at 1aeb0c7>` | `RESULT: FAIL (2 violation(s))`, rc=1, naming `CF-161.md:25` and `CF-163.md:66` |
| green on the fixed tree | `python3 scripts/check_scan_scope.py .` | `OK  audit-scope: 3 gitleaks claim(s) name their --log-opts` / `RESULT: OK`, rc=0 |
| unreadable path | `python3 scripts/check_scan_scope.py /nonexistent` | `RESULT: FAIL (unreadable path)`, rc=2 |
| shell syntax | `bash -n tests/selftest.sh` | rc=0 |

GitReins `CF-163-L1`: tier1 `PASS` (lint/secrets/tests), tier2 `PASS` `COMPLETE`, verdict
`.gitreins/history/2026-11-04/b482884a/verdict.json`, envelope
`{task_id: CF-163-L1, commit: 5794a49…, passed: true}` — the graded commit is exactly the
implementation commit.

CF-163 itself stays **pending**: AC1/AC4/AC5 (retire the published `master` branch and disclose
what remains reachable by SHA) need the owner's decision, and no lane can take that unilaterally.

## Public posture at `f121ed3`

| item | measured | verdict |
|---|---|---|
| visibility / license | `public`, `license=MIT`, `LICENSE` present | ok |
| secret scanning | `state=open` alerts: `[]` (1 historical alert on the `master` lineage path `.hermes/scripts/test_secret_scrub.py`, resolved 2026-11-04 as a scrubber fixture) | ok |
| branch protection on `main` | `gh api …/branches/main/protection` → `Branch not protected` (404); `gh api …/rulesets` → `[]` | **defect, already filed as CF-120 (pending)** |
| published ref surface | `refs/heads/master` still at `4ead64f`: 772 commits, not an ancestor of `main`; `gitleaks detect --redact --log-opts="--all"` (1152 commits, 57.39 MB) → 547 findings in 64 commits, all 64 on `master` | **defect, CF-163 (P1, owner-gated)** |
| internal endpoints | `git grep -E '100\.[0-9]+\.[0-9]+\.[0-9]+'` at `HEAD` → 0 files | ok |
| absolute host paths | `git grep -l '/home/kara'` at `HEAD` excluding `.gitreins/` → 35 tracked files (CF-050 measured 27 when filed) | drift on a pending row, noted not re-filed |
| internal host names | `git grep -liE 'karahermes|bunker-mvp|bunker-las|cube-agent'` excluding `.gitreins/` → 5 tracked files | same class as CF-050/CF-086 |

## Release

**No tag cut.** The repository has no release contract: `git tag -l` and
`ls-remote --tags` are both empty, there is no `VERSION`/`CHANGELOG`, and no version scheme in
`specs/`. That gap is already filed as **CF-161 (P3, pending)**. Tagging today would invent a
version scheme the repo has not adopted, so the releng verdict is "not due, blocked on CF-161".
`master` at `4ead64f` still has to be retired (CF-163) before any tag from `main` means what a
consumer would read it to mean.

## Not done, and why

- Candidate checkout not repaired (untracked verdict bundles left in place): publishing them is a
  sibling's `chore(gitreins)` commit, and a foreman does not adopt another lane's residue without
  an owner disposition.
- CF-161/CF-120 not implemented: both need an owner decision (adopt a version scheme; enable
  branch protection/ruleset policy) that a lane cannot take.
- The `master` branch was not deleted: CF-163 AC1 is explicitly an owner call.

## Verification addendum — third execution of tick `code-factory-duckbrain-releng-2026-11-04-06-11-13`

`2026-11-04T01:52-05:00` (`date -Is`), loadavg `34.0 22.0 15.0` (host load, shared box).
A prior execution of this tick id landed CF-163 AC3 (`5794a49`/`f121ed3`); a second execution found
the published tip red on this doc's own gate and repaired it (`8995064`, verdict `CF-163-L3`, receipt
`8c6ef7e7`). This pass **verified those claims instead of re-executing them**, then produced two new
findings of its own. Nothing was re-judged, re-filed or cleaned on the strength of a prior note.

### Prior claims re-verified against artifacts

| Claim | Command (this pass) | Result |
|---|---|---|
| Verdict bundle published | `git show HEAD:.gitreins/history/2026-11-04/f09c06d5/verdict.json` | `task_id=CF-163-L3`, `commit=8995064…`, `passed=true`, `evaluated_at=06:39:39` ✓ |
| Close-out events committed | `git show HEAD:.coding-hermes/board/events.jsonl \| jq 'select(.id==246 or .id==247)'` | 246 `task_evidence`, 247 `audit` (memory binding) ✓ |
| Receipt readable | `GET /api/memories/key//code-factory/lanes/releng/2026-11-04-06-11-13?namespace=code-factory` | HTTP 200, record `8c6ef7e7`, body names this tick and names `2ceeb95b` as superseded ✓ |
| Candidate at parity at pass start | `git rev-list --left-right --count origin/main...HEAD` | `0 0` at `a6911d1` ✓ |
| Gate at the pass-start tip | fresh clone at `a6911d1`, `bash tests/selftest.sh` | `SELFTEST: PASS`, 106 PASS rows ✓ |

### New finding 1 — the releng format leg was red (fixed at `5fc2cbd`)

`ruff format --check .` answered **“1 file would be reformatted”**: `scripts/check_scan_scope.py`,
introduced by `5794a49` (CF-163 AC3), carried one `print(f"  FAIL  audit-scope: …")` line over the
default 88-column budget. Fixed as a whitespace-only reflow (`5fc2cbd`, AST-identical; the graded
judge re-checked this with an AST comparison). Verdict `CF-163-FMT`, run `8f9396cb`, `passed=true`,
`commit=5fc2cbd…`; bundle published in the bookkeeping commit that carries this addendum.

**Disclosure:** ruff is *not* a declared gate in this repo — there is no `pyproject.toml`/`ruff.toml`,
no `selftest.sh` arm and no `AGENTS.md` line for it. The format leg belongs to the releng checklist,
so this is lane hygiene, not a repo gate failure, and a green format leg must not be read as evidence
that the repo ships a formatter check.

### New finding 2 — `selftest.sh` section 7b can report a FALSE red (filed `CF-168`)

One suite run at the fix tree graded the 7b `number` arm FAIL — `FAIL  number fixture escaped the
board gate (exit 1)` — while printing output that satisfies every condition the arm tests (rc=1, the
expected `board line 2: expected JSON object, got 42` row, the `2 of 3 rows parse` row, no `PASS`
line). Two further runs at the same tree answered `SELFTEST: PASS` / 106 rows, and 20 isolated
iterations of the same fixture never reproduced it.

Mechanism: `tests/selftest.sh:3` sets `set -uo pipefail`, and the arm asserts with
`printf '%s\n' "$out" | grep -Fq …` (`tests/selftest.sh:242-244`). When `grep -q` exits after its
match, `printf`'s remaining write takes SIGPIPE; `pipefail` propagates 141 and the `&&` chain grades
the arm FAIL. Deterministic demonstration — the row's probe prints `assert_rc=141` on three
consecutive runs:

```
t=$(mktemp -d); printf '%s\n' 'set -uo pipefail' 'w() { printf "%s\n" "MATCH-LINE"; seq 1 200000; }' 'out=$(w)' 'printf "%s\n" "$out" | grep -Fq "MATCH-LINE"; echo "assert_rc=$?"' > "$t/a.sh"; bash "$t/a.sh"; rm -r -- "$t"
```

Filed as `CF-168` (P3) with that probe as acceptance criterion 0; deliberately **not** fixed in this
tick, whose scope is the format leg.

### Gate battery at the published tip `5fc2cbd` (fresh clone, not the candidate)

| Leg | Command | Result |
|---|---|---|
| CI-equivalent | `bash tests/selftest.sh` | `SELFTEST: PASS`, rc 0, 106 `PASS` rows, 19 `FAIL` rows — all negative fixtures (board-parser malformed rows, `disk_floor` resolver-removal arm) |
| Board | `bash scripts/boardctl validate` | `RESULT: OK (3 warning(s))` — pre-existing free-form vocabulary ×2 + headerless-board note |
| Python syntax | `python3 -m py_compile $(git ls-files '*.py')` | rc 0, silent |
| Lint | `ruff check .` | `All checks passed!` |
| Format | `ruff format --check .` | `15 files already formatted` |
| Shell parse | `for f in $(git ls-files '*.sh') scripts/boardctl; do bash -n "$f"; done` | 0 failures |
| Secret scan (working tree) | `gitleaks detect -c .gitleaks.toml --redact --no-git` — files-only mode, so no `--log-opts` range applies | `no leaks found`, 1.07 MB scanned |
| Actions | `gh run list --repo coding-hermes/code-factory --limit 3` | `[]` — the documented no-Actions state, not a failure |

### Public posture, re-measured at review time

| item | measured | verdict |
|---|---|---|
| visibility / licence | `public`, `license=MIT`, `archived=false` | ok |
| secret scanning | `secret_scanning=enabled`, `push_protection=enabled`; alerts: **0 open**, 1 resolved | ok — the earlier open alert is now triaged; CF-156 is `complete` |
| branch protection on `main` | `gh api …/branches/main/protection` → 404 `Branch not protected`; `gh api …/rulesets` → 0 | defect, already filed as CF-120 (pending, owner setting) |
| absolute host paths | `git grep -Il '/home/kara' -- . ':!.gitreins'` → **38** tracked files (CF-050 measured 27 when filed) | drift on a pending row, reported not re-filed |
| published ref surface | `refs/heads/master` unchanged (CF-163 AC1, owner-gated) | defect, CF-163 (P1, owner-gated) |

### Release decision — re-measured, unchanged: NOT DUE

No published tags (`git ls-remote --tags` empty), no `VERSION`/`CHANGELOG` in the tree, no version
scheme in `specs/` (CF-161 pending), and open work still includes **5 P0** and 11 P1 rows. Nothing
was tagged, and no version scheme was invented.

### Candidate state at close (`~/code-factory`, untouched by this pass)

`HEAD=0b34155`, attached `refs/heads/main`, **3 behind** / 0 ahead of `origin/main`, 0 tracked edits,
53 untracked paths (`.gitreins/history/**` bundles), `NO_ACTIVE_OP_DIRS` (no `rebase-merge` /
`rebase-apply` / `MERGE_HEAD` / `CHERRY_PICK_HEAD`), 0-byte `.coding-hermes/board/.lock`.

- The bare `.git/REBASE_HEAD` seen at the gate is **STALE**: the reflog records `rebase (finish)` at
  `01:24:43` returning to `refs/heads/main`, the operation directories are absent, and a cwd census
  (`checkout-writer-census.sh`) finds no writer. Left in place, not deleted.
- **CF-049 premise re-check:** its AC2 is met (no rebase dirs, HEAD attached), but AC4 still fails on
  the 0-byte `board/.lock` (adjudicated RESIDUE by `scripts/board_lock.py`, CF-119), untracked
  GitReins bundles remain, and the candidate lags the tip — so the row stays **pending**.
- The behind-count is the sibling lanes' landing pace, not a repair performed on a shared checkout.

### Lifecycle, memory, and what this pass did not do

- GitReins: `CF-163-FMT` created → started → `task complete`; Tier 1 + Tier 2 `PASS`
  (`8f9396cb`) bound to `5fc2cbd`. The prior execution's `CF-163-L3` remains the closure for its own
  work; no second judge was fired on an unchanged tree.
- Memory: **no new record written** — `8c6ef7e7` already covers this tick id and was read back here.
  This addendum is the third pass's durable record.
- Not done: CF-161/CF-120 (owner decisions), `master` retirement (CF-163 AC1, owner), the 7b pipefail
  fix (`CF-168`, filed), and any cleanup of the candidate's untracked residue (another lane's
  unpublished bundles).

### Post-closeout observation — the candidate holds a foreign STAGED event that collides with this tick's `255`

At `2026-11-04T02:03-05:00`, the registered candidate `~/code-factory` (HEAD `7400036`,
the tip this tick published before its memory appendix) carried exactly **one** dirty path, staged in
the index and not in the worktree:

```
M  .coding-hermes/board/events.jsonl   (+1 line)
+ {"id":255,"timestamp":"2026-11-04T06:57:46+00:00","event_type":"audit","task_id":"CF-167",
+  "actor":"docs-lane", … "tick":"code-factory-docs-2026-11-04-06-11-13" …}
```

Two consequences, neither repaired here:

1. **It blocks a fast-forward.** The index is dirty, so the candidate stays behind the published tip
   (1 behind at observation time). A lane does not fast-forward a checkout that holds another lane's
   staged bytes, and it does not adopt or clean them either.
2. **The id collides.** This tick published **event 255** (`audit`, CF-163, the DuckBrain record
   binding) in `a0abbfe`. Committing the docs lane's staged line would mint a second `255` on the
   published board, which `scripts/boardctl`'s duplicate-id gate and the suite's board arm both
   reject — the next lane to write the board would inherit a red gate it did not cause.

Disposition: **left untouched.** The docs lane's scheduler record for `code-factory-docs-2026-11-04-06-11-13`
reads `failed`, so the staged line is likely orphaned. The actionable next step is for that lane — or
the next lane that owns a board write — to renumber the line past `origin/main`'s maximum event id
and run `bash scripts/boardctl validate` before committing. Untracked residue is unchanged
(53 `.gitreins/history/**` paths). Writer census at this time: `CENSUS_EMPTY=1`.

### Resolution at final close — and a timestamp correction

**Correction first:** the section above stamps its observation `2026-11-04T02:03-05:00`. That was
written from a mis-read clock; the observation actually happened at **`01:58–01:59-05:00`**, in the
minute before the docs lane committed at `01:59:14`. The observation content is unchanged — one staged
`events.jsonl` line, event id 255, actor `docs-lane`, task CF-167 — only the time was wrong, and the
audit event that carries this is corrected in the same commit that appends this section.

**Resolution:** the hazard is historical, not live. The docs lane committed and pushed
`664a446` — *board(docs): verify the tick 06-11-13 docs receipt at 17dc63c (event 257)* — which
renumbered its staged line to event **257** instead of colliding with this tick's 255. Measured at
close (`2026-11-04T02:00:32-05:00`):

| probe | result |
|---|---|
| `git rev-parse HEAD` vs `origin/main` in `~/code-factory` | `664a446` = `664a446`, `rev-list --left-right --count` → `0 0` |
| tracked edits in the candidate | 0 (index and worktree) |
| published board | 257 events, **0 duplicate ids**, 142 rows |
| untracked residue | 53 `.gitreins/history/**` paths, unchanged |
| writer census | `CENSUS_EMPTY=1` |

So no second `255` was minted, the fast-forward that the staged index had blocked is no longer needed
(the candidate is at parity by that lane's own push), and this lane changed nothing in the candidate.

### Fourth execution of tick `code-factory-duckbrain-releng-2026-11-04-06-11-13` — resumed verification

Written 2026-11-04T02:06-05:00 (host clock), `loadavg` `9.6 10.4 9.7`.

The scheduler row for this tick reads `failed` (`gateway HTTP 502` at `2026-11-04T01:51:39-05:00`) while the
work above had already landed — the third execution committed through `ef222d1` and pushed. This pass
therefore **verified the durable claims from artifacts instead of re-executing them**, then re-ran the
lane's own gate at the published tip. Nothing was repaired and nothing was re-filed.

| Claim | Command | Result |
|---|---|---|
| Candidate at parity | `git -C ~/code-factory rev-parse HEAD`, `git rev-list --left-right --count origin/main...HEAD` | `ef222d1` = `origin/main`; **`0 0`**; 0 tracked edits |
| Board integrity | `git show origin/main:.coding-hermes/board/events.jsonl \| jq -s` | **258 events, 0 duplicate ids**, 142 task rows |
| Rows filed by this tick | `jq -r 'select(.id=="CF-163" or .id=="CF-168")\|.status'` | both **`pending`** on the published ref (correct — the fix work is not this tick's) |
| Format-leg verdict | `git show origin/main:.gitreins/history/2026-11-04/8f9396cb/verdict.json` | `task_id=CF-163-FMT`, `passed=true`, `commit=5fc2cbd…`, `evaluated_at=2026-11-04T06:50:41` |
| Memory leg | `GET /api/memories/key/%2Fcode-factory%2Flanes%2Freleng%2F2026-11-04-06-11-13?namespace=code-factory` | HTTP **200**, record **`48fb5fe9`**, 2336 chars, names this tick — read back, **no parallel receipt minted** |
| Gate at `ef222d1` | `bash tests/selftest.sh` | **`SELFTEST: PASS`**, rc=0, **106 PASS rows**, 19 `FAIL` rows (all documented negative fixtures) |
| Board validity | `bash scripts/boardctl validate` | `RESULT: OK (3 warning(s))` — CF-034 free-form fields + headerless board, pre-existing |
| Actions | `gh run list --repo coding-hermes/code-factory --limit 3` | `[]` — documented no-workflow state (this repo's CI-equivalent gate is `tests/selftest.sh`) |
| Public posture | `gh api repos/coding-hermes/code-factory` | public, `license=MIT`, `archived=false`, secret scanning **enabled**, push protection **enabled**, **0 open alerts**, branch protection still `404` (CF-120, owner setting) |
| Release | `git ls-remote --tags` | **0 published tags**; 2 local safety tags (neither an ancestor of `main`); no `VERSION`/`CHANGELOG`/version scheme → **no tag cut, release not due** (CF-161 pending) |
| Writer census | `/proc/*/cwd` scan of the checkout | empty apart from this tick's own probe; no live `gitreins` judge in the checkout |

**Resolution of the previous pass's open hazard:** the foreign staged `events.jsonl` line recorded as
event 256 was committed by the docs lane as event **257** (`664a446`), so no duplicate `255` exists on the
published board — confirmed above (0 duplicate ids across 259 events after this pass's own append).

This pass appended exactly one audit event (**259**, insert-only: prefix `cmp`-identical, 259 lines,
0 duplicate ids) and this section; the row set is unchanged (142 rows, no new ids).
