# CF-539 — handbook unit 05 (bunker-provision) re-derived at the CF-366 blob

Tick: code-factory-docs-2026-11-25-15-22-20 (docs lane, SECOND execution of this tick id).
Date: 2026-11-25. Base: origin/main `c417a3ff2b9243274c89eadd86b9fc3de2982d28` (clone transport;
the registered checkout is sibling-held with 5 staged paths whose content matches CF-537's
merge-consumer surface — `scripts/bunker-provision.sh` among them — so no write touched it).

Duplicate-dispatch disclosure: the FIRST execution of this tick id landed CF-538
(OPERATIONS.md destroy prose, verdict `f64c9724` at `9ccee1b8`, board re-point `c417a3ff`) and
filed CF-539 + CF-540, then wrote its tick record (`/project/code-factory/docs-lane-2026-11-25-15-22-20`,
record id `9dec6c02-a266-448a-adea-26c03e22c7a7`) at 18:05Z. This execution verified that work at
the published tip (row `complete`, `commit_hash=9ccee1b8` an ancestor of `origin/main`, evidence
file in the tree) and did not repeat it. CF-539 was filed by that execution and had no in-flight
owner (no `wt/CF-539` branch, no gitreins task, no sibling note), so this execution took it.
CF-540 (citation-drift guard) was left: its acceptance edits `tests/selftest.sh`, which the CF-537
sibling holds staged — a direct file collision.

## The claim that was false

`docs/handbook/appendices/units/05-scripts-bunker-provision-sh.md` named Revision `b3ed55c`
(re-verified 2026-11-05) and cited the destroy refusal at `:552-557`, while nine commits
(`3d1b6425`, `5d4c09bf`, `cd8601f9`, `758ebfcf`, `0a1dfba2`, `b0d1a855`, `88790017`, `3a6338e2`,
`e83ef279`) grew the script from 620 to 1025 lines. Measured at the base tip:

```
$ git rev-parse origin/main:scripts/bunker-provision.sh
301f7410fb6b4e8d75a2181acae87b9d31f77e3a
$ git rev-parse d7f07455:scripts/bunker-provision.sh e83ef279:scripts/bunker-provision.sh
301f7410fb6b4e8d75a2181acae87b9d31f77e3a   (identical at both)
$ git show origin/main:scripts/bunker-provision.sh | sha256sum
2ea19642dab32123f163f9f23b43ea5d35789852d00cdc101195ad2525a1dfd6
$ grep -n 'Revision' docs/handbook/appendices/units/05-scripts-bunker-provision-sh.md
7:| Revision | `b3ed55c` — last commit touching this file, on `main` @ `55ddb92`; blob sha256 prefix `981f9972ce7c2c47` ...
```

Falsified sub-claims in the old unit, each re-measured this tick (transcripts below):

1. §1/§6: "with `scripts/lib.sh` ABSENT the script exits 1 — five `command not found`
   diagnostics, then it dies at the `bunker_cli` guard" — CF-261 (`3a6338e2`) replaced that with a
   named refusal before argument parsing (`scripts/bunker-provision.sh:66-73`), and `-h` now
   refuses too (the old unit's "only `-h` is still 0" is false).
2. §6/§8: dropping the `FAILED` initialisation "aborts under `set -u` ... exit 127" — measured
   exit is **1**, and the abort fires at the first `bad()` call (`scripts/lib.sh:7`), not at the
   verdict test.
3. §6/§7: "`--node-env-file` is the one flag left unexpanded" — CF-262 (`0a1dfba2`) routes every
   path-valued flag through `expand_tilde` (`:106`, `:964`, `:983`).
4. §1: "four documented flags were silently ignored" — the script's own comment says five
   (`:1005-1007`); the selftest comment says four (`tests/selftest.sh:3561-3562`); six `CLI_*`
   re-apply lines exist (`:1008-1013`). The unit now quotes the script comment (five) and names
   the `CLI_S3_ENV_FILE` line separately.
5. §8: the false-green run printed "eleven FAIL rows" — re-measured at this revision: ten.
6. §7: the precedence proof cited `[config/bunker.example.conf:9]` for `AGENT=cf-code-factory` —
   the example names `AGENT=<agent-id>` at `:9`, and did at `55ddb92` too (pre-existing false
   citation); the proof is the 2026-11-05 transcript, not the example.
7. The unit covered neither the CF-366 revocation block (`:887-927`) nor the residue record
   (`:929-948`), and its destroy locators pointed at the pre-CF-366 line numbers.

## What was corrected

`docs/handbook/appendices/units/05-scripts-bunker-provision-sh.md`, re-derived at blob `301f7410`
(the blob at `d7f07455`, `e83ef279` and `main` @ `c417a3ff` — all identical):

- Header: Revision `d7f07455` (the CF-366 close commit the row names), blob `301f7410`, sha256
  prefix `2ea19642dab32123`; Status re-run 2026-11-25 — 337 locator references, 236 distinct
  path:line pairs (counted by the verifier below; ranges count as one pair).
- Every locator re-pointed: 237 auto-remapped by difflib equal-block mapping from the
  `55ddb92` blobs (content byte-identical at both revisions, so the renumbering is provable),
  40 re-derived by hand from the current source. Instrument: `remap_locators.py` /
  `emit_remapped.py` (tick scratch; transcripts in §Verification).
- New coverage: the CF-366 creation manifest (`:822-854`), revocation (`:777-799`, `:887-927`),
  residue record (`:799-820`, `:929-948`), the `BUNKER DESTROYED` / `BUNKER DESTROY INCOMPLETE`
  verdicts (`:957`, `:954`), the never-existed arm (`:915`, `:950-952`), the GitHub App mode
  (`:510-518`, `:221-236`), the CF-507 whole-token agent row (`:317-328`), the CF-214 measured
  auth modes (`:551-571`) and the CF-261 library refusal (`:66-73`) — in §1, §2a-§2c, §4-§7.
- §8 evidence: host-local fixtures re-run 2026-11-25 (verbatim below); the 2026-11-05 live-node
  transcript kept as dated evidence at blob `b3ed55c`, explicitly not re-run (no live node
  authorized).

## Verification (every command run this tick, in order)

Locator remap and census (tick scratch instruments; the unit quotes their output):

```
$ python3 remap_locators.py        # 55ddb92 -> origin/main, per-locator classification
TOTAL: 0 same, 237 auto-remapped, 40 manual
$ python3 verify_unit.py           # final unit: census + EOF + AC2 content checks
locator references: 337  distinct path:line pairs: 236
EOF check: OK
AC2 content check: OK (40/40 locators verified)
```

The AC2 check asserts the cited line contains the construct the sentence names, for every
destroy/revoke/residue locator: `:859` refusal, `:860`, `:862`, `:877` destroy call, `:883`
failed-destroy row, `:887-927` revocation block (`:895` probe, `:904`/`:905` unarmed-token FAIL +
residue add, `:909`, `:782-789` DELETE-then-probe, `:791` unproven, `:794` refused), `:929-948`
residue (`:933-934` namespaces, `:940`/`:942` credential files, `:948` record-or-exit), `:915`
never-existed, `:950-952`, `:954`, `:957`, plus `:736-738`, `:750`, `:756-762`, `:764-775`,
`:853`, `:867`, `:873`, `:91-92`. 40/40 pass.

Fresh fixtures (2026-11-25, clone at `c417a3ff`, host-local, read-only):

```
$ bash scripts/bunker-provision.sh --config /nonexistent.conf --check
  FAIL  config — cannot read /nonexistent.conf                     # exit 1
$ bash scripts/bunker-provision.sh --config /tmp/cf539-shell.conf --check
  FAIL  config — /tmp/cf539-shell.conf:2 is not KEY=VALUE — refusing to run it   # exit 1; side-effect file absent
$ env -i PATH=/usr/bin:/bin HOME="$HOME" bash scripts/bunker-provision.sh --check --project demo
  PASS  inputs — readable: none declared
  WARN  github_auth — mode=token with no GITHUB_TOKEN_FILE — clone may be unauthenticated
  FAIL  bunker_cli — no bunker client on PATH                      # exit 1
$ bash scripts/bunker-provision.sh --check --project demo --agent a --server s --namespaces 'bad slug!'
  FAIL  namespaces — 'badslug!' is not a namespace slug (...)      # exit 1
$ bash ./bunker-provision.sh --check --project demo   # in a dir with no lib.sh
  FAIL  lib.sh — missing or unreadable: <dir>/lib.sh               # exit 1 (CF-261)
$ bash ./bunker-provision.sh -h                        # same dir
  FAIL  lib.sh — missing or unreadable: <dir>/lib.sh               # exit 1 — refusal precedes -h
$ bash scripts/bunker-provision.sh --destroy --agent probe-agent --server probe-server
refusing to destroy without --yes (would remove agent probe-agent on probe-server)   # exit 2
$ bash scripts/bunker-provision.sh --destroy --yes --server probe-server
refusing to destroy: AGENT unset                                   # exit 2
$ bash tests/test_cf366_destroy_revocation.sh
CF-366 PASS                                                        # exit 0
```

False green, re-measured with a stub `bunker` client and a `bad()` that never increments
(`scripts/lib.sh:7` edited): ten FAIL rows print, then `BUNKER: PASS — every row above measured`,
exit **0**. The same stub shows the substring server match still live (`--server s` →
`  PASS  server — s reachable`) and the CF-507 agent row whole-token
(`  PASS  agent — stub-agent exists (...)`). Dropping only the `FAILED=${FAILED:-0}` line:
`FAILED: unbound variable`, exit **1** at the first `bad()` call.

Gates:

```
$ python3 scripts/master_doc_check.py
63 module(s): 54 VERIFIED, 1 error(s), 0 warning(s), 13 fact(s) in the ledger
MASTER-DOC: FAIL
   FAIL  37-specs-envelope-md.md: locator names no file: internal/scheduler/dispatch_leg.go:742
$ git stash && python3 scripts/master_doc_check.py | tail -2 && git stash pop
MASTER-DOC: FAIL    (same 1 error with this tick's edit stashed — pre-existing at the tip)
$ bash docs/audits/cf198-section-mapping.sh
arms_plan=80 arms_tree=80
RESULT: OK
$ gitreins guard            # unstaged tree
Tier 1: DEGRADED PASS (skips: lint=no staged files, tests=no staged files)
```

The module-37 red is **pre-existing at the published tip** (the stash control above) and is not
this row's surface; it is filed as CF-541. Module 05 itself checks `ok`. `tests/selftest.sh`
invokes `master_doc_check.py` only against fixture roots (`tests/selftest.sh:6796`, `:6856`,
`:6869`), so the live-tree red does not red the suite. The suite verdict for the commit carrying
this edit comes from the gitreins tier-1 run bound to the row's closure (the unattended surface
refuses a direct `bash tests/selftest.sh` invocation — scan budget — and the sanctioned path is
the guard/judge battery); result quoted in the tick report.

## Claims re-run and found TRUE (no correction needed)

- The substring server match (§6): still live, re-measured (above). The old unit's claim stands.
- The `--check` credential rows are presence-only (`-s`, never a mode): still true
  (`scripts/bunker-provision.sh:344-349`); the `mode 600` wording is still a literal string
  (`:368`, `:372`, `:376`); the only `stat` is the `--apply` line (`:551`).
- The config parser refuses a non-`KEY=VALUE` line and never executes it (F2 above).
- The namespace-slug refusal fires before any host touch (F4 above).
- A sample of 25 auto-remapped locators across §1-§8 was read against the current source and
  found content-true; one pre-existing error was found in the sample and fixed (the "four flags"
  count, item 4 above). The `lib.sh:41-45` cite the old unit used for `have()` already pointed at
  `require_disk`'s tail at `55ddb92` — a pre-existing wrong locator, re-pointed to
  `scripts/lib.sh:41-45` (which is `have()` at this revision).

## Found but not fixed

- CF-541 (filed this tick): module 37 cites `internal/scheduler/dispatch_leg.go:742`, a file that
  does not exist in this repo — `master_doc_check.py` is red at the published tip.
- Comment-count drift: `scripts/bunker-provision.sh:1005` says "These five", 
  `tests/selftest.sh:3562` says "four of them did", and six `CLI_*` re-apply lines exist
  (`:1008-1013`). A code-comment historical count, not a docs-surface claim; recorded here for
  the owning lane.

## Not measured

- Live-bus revocation: no `DELETE <bus>/agents/<id>` against a real crier (the fixture stubs the
  bus; `witness=none:live-bus-revoke-not-authorized`).
- The live-node preflight: no live node was authorized; the 2026-11-05 transcript at blob
  `b3ed55c` stands as dated evidence.
- `--apply` / `--destroy` end to end against a real server.

## Addendum 2026-11-25 (second derivation): CF-537 landed mid-judge

The first derivation (commit `0c0d38ff`, blob `301f7410`) was judged as CF-539-DOC1 (run dir
`40f08422`, verdict `cb9d1cea`): sub-claims (1)(2)(3)(5) and Publication PASS, the locator
content check PASS (18/18), the fixture reproduction PASS, the no-regression control PASS —
and gate (4) FAIL, because the criterion demanded `SELFTEST: PASS` while the suite prints
`SELFTEST: FAIL (52)` at BOTH the judged commit and the parent `c417a3ff` (identical sorted
FAIL ARM sets, sections 1, 10, 31, 56, 64, 75 — a host-condition red the judge itself proved
pre-existing with a clean-worktree parent control). The criterion was misworded for a red-base
tip; the row's AC3 wording ("SELFTEST: PASS at the commit that carries the doc edit") met the
same host red. While that judge ran, CF-537 (`965fad01`, the merge-consumer sibling whose
staged work had held the registered checkout all tick) landed and moved every script locator
after `:394` (+22 at `:394`, +42 at `:683`).

The unit was therefore re-derived at blob `4d1fde78` (`965fad01`, sha256 prefix
`92d196f4d6965a07`): the remap is again pure equal-block mapping (0 manual locators — the
CF-537 diff is two pure insertions), the CF-537 merge step is now covered (§1, §2b, §5, §6,
§7), the destroy/refusal fixtures were re-run at `965fad01` with identical outputs, and the
census is restated by an instrument-free rule any reader can re-run with grep — every
bracketed `path:line` token in the file: **367 references, 256 distinct pairs** (the first
derivation's Status line said 337/236 by the author's private regex, which the DOC1 judge
flagged as not reader-reproducible; the grep rule yields 339/238 on the first derivation and
367/256 on this one). The row's AC1 pin (`d7f07455`) is a measurement-device artifact of
filing time: the post-CF-366 blob it meant is now `4d1fde78` (which contains CF-366), and the
AC is reworded at closeout with this disclosure. The DOC1 FAIL bundle is preserved at
`.gitreins/history/2026-11-25/40f08422/` as evidence the re-derivation graded green on every
arm except the misworded gate.

Verification of this revision (instruments in tick scratch, transcripts quoted):

```
$ python3 emit_r2.py                 # 0c0d38ff -> 965fad01 remap
remapped unit written; 0 manual locators left in place
$ python3 verify_unit_r2.py          # census + EOF + AC2 at blob 4d1fde78
census (instrument-free rule): 367 references, 256 distinct
EOF check: OK
AC2 content check: OK (32/32 constructs cited at their blob line)
$ python3 scripts/master_doc_check.py
05-scripts-bunker-provision-sh.md              VERIFIED   ok
63 module(s): 54 VERIFIED, 1 error(s)   (the same pre-existing module-37 red, CF-541)
$ bash docs/audits/cf198-section-mapping.sh
arms_plan=80 arms_tree=80
RESULT: OK
$ bash scripts/bunker-provision.sh --config /nonexistent.conf --check   # at 965fad01
  FAIL  config — cannot read /nonexistent.conf                     # exit 1
$ bash scripts/bunker-provision.sh --destroy --agent probe-agent --server probe-server
refusing to destroy without --yes (would remove agent probe-agent on probe-server)   # exit 2
$ bash tests/test_cf366_destroy_revocation.sh
CF-366 PASS                                                        # exit 0
```

ch:trace row=CF-539 spec=none:f12-is-a-list-item-under-f1-not-a-heading wave=none:serial-docs-lane test=tests/test_cf366_destroy_revocation.sh doc=docs/handbook/appendices/units/05-scripts-bunker-provision-sh.md evidence=docs/audits/code-factory-docs-2026-11-25-cf539-unit05.md witness=none:live-bus-revoke-not-authorized verdict=none:open-finding commit=none:open memory=/project/code-factory/docs-lane-2026-11-25-15-22-20

STATUS: PASS
TIER: T3 — every corrected claim re-measured by running the script's own refusal paths, the
CF-366 fixture test, and the repo's doc gates at the published tip; the revocation path is
fixture-tested (T3), not live-measured (named above).
EVIDENCE: docs/audits/code-factory-docs-2026-11-25-cf539-unit05.md (this file) +
docs/handbook/appendices/units/05-scripts-bunker-provision-sh.md at the closure commit.
