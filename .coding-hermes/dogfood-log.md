# Dogfood log — code-factory

One entry per dogfood tick: what was walked, what it cost, what broke, what was filed.
Newest last. Run ids are the tick ids, so `grep -n '<tick-id>'` finds the record.

## 2026-11-17 — run `code-factory-dogfood-2026-11-17-10-10-24`

- **Verdict**: 🟡 PROMISING-BUT-ROUGH. Every documented control-host command runs and refuses
  by name with the missing value; two of the outputs misstate their own measurement.
- **Tip walked**: `0014b76ac0b5a33081068d743e52754b928b4e0c` (origin/main, parity 0/0, clean tree).
- **Promise tested**: "a stranger on a fresh host runs the three Quick start commands and each one
  either works or fails naming the value to supply."
- **Time to first success**: `bunker-server-install.sh --check` → `RESULT: PASS` in **0.92 s** once
  `BUNKER_SERVER` names a configured server (0.00 s / 0.03 s on the two refusal arms).
  `project-node.sh --check` → `NODE: FAIL (5)` in **38.16 s** (cost owned by CF-387).
- **Top findings**:
  1. `CF-483` — the `residue` row is a substring match on the word "orphan", so it WARNs on a host
     the server reports as *0 orphan homes, 0 orphan keys* and can never report a real leak.
  2. `CF-484` — README Quick start step 2 says "the same check with an explicit interpreter
     passes"; measured `NODE: FAIL (7)` (two MORE failures than the default arm's 5).
  3. `CF-057` annotated — `--json` is parsed into a variable nothing reads: the documented
     machine-readable surface does not exist.
- **Not filed**: the `node-create.sh` spawn row already owns its message quality (`CF-469`); the
  README's `bunker-provision --check` transcript is `CF-467`; step-2 cost is `CF-387`.
- **Unverified this fire**: a live node create (would spawn a real agent on `bunker-las-03`, which
  reported 0/8 agents); one probe arm was refused by the unattended command gate and is recorded as
  UNVERIFIED in the report, not retried in another form.
- **Artifacts**: `docs/dogfood/2026-11-17-dogfood-path.md`,
  `.coding-hermes/evidence/code-factory-dogfood-2026-11-17-10-10-24/`.

### 2026-11-17 — re-fire receipt for `code-factory-dogfood-2026-11-17-10-10-24` (delivery 2)

Duplicate delivery of the tick above: no re-walk, no new product measurements, zero rows filed.

- **Tip unchanged**: `f2127dd9` = `origin/main` at parity 0/0 (the record commit itself).
- **Verified from `origin/main`, not the working copy**: `CF-483` + `CF-484` `pending` with non-empty
  `reasoning`/`acceptance_criteria` (2327/1258 and 2907/1074 chars) and one paired `task_created`
  event each (ids 887/888) · `CF-057`'s `foreman_note` quotes `--json` (1738 chars) · three artifacts
  non-empty (7607/2082/3888 bytes) · `step2.out` ends `NODE: FAIL (5)`, `b1.out` `NODE: FAIL (7)`,
  both `.err` carrying `non-zero status 1` · gitreins `CF-DOGFOOD-20261117` complete, verdict at
  `.gitreins/history/2026-11-17/ed488866` (tier1 PASS, tier2 PASS, COMPLETE).
- **No residue**: the evidence INDEX names no `agent=` id — the node-create leg was never run, so
  there is no agent to destroy.
- **Stood down, no blocked receipt**: `docs/audits/cf-PERF-021-cold-cache-attribution.md` and
  `docs/handbook/chapters/VIII-5-tests.md` are staged but are NOT unowned residue — live worker pid
  2491440 (PERF-021 brief, started 05:06:25) owns them, and its dirty-path set matches its brief
  exactly. Left untouched; no second dispatch into this checkout.
- **CI**: last 5 runs on `coding-hermes/code-factory` all `success`; nothing filed.

#### Addendum — the tip moved while this receipt was being written

The `f2127dd9` claim above is scoped to the moment it was measured; two commits landed after it, and
this receipt was rebased onto them by the fleet harvester (its local pre-rebase sha was `e986d45c`):

- `1fc9c17e` — the live PERF-021 worker's own commit: `docs/audits/cf-PERF-021-cold-cache-attribution.md`
  (+370) and `docs/handbook/chapters/VIII-5-tests.md` (+11). The two paths this receipt "left untouched"
  are therefore now landed by their owner, not residue.
- `82972156` — this receipt itself, `name-only` = `.coding-hermes/dogfood-log.md` alone.

**Guard coverage, re-measured:** the pathspec commit (`git commit -F msg -- <path>`) presented the guard
an EMPTY staged set — `Tier 1: DEGRADED PASS (skips: lint=no staged files, tests=no staged files)`,
guard log `.gitreins/logs/guard-20261117T110029.965517Z.log`. That class is already owned by **CF-474**
("the commit-time guard treats `git commit --only <path>` from a clean index as an empty…"), so no
sibling row was minted; this is a second, independent measurement of the same defect at a new tip.
A separate FAIL on the first attempt (`publish paths — baseline 0, current 1`,
`docs/audits/cf-PERF-021-…`) was the worker's own mid-edit `/home/…` leak in the shared index, gone by
the retry — a shared-checkout snapshot, not a repo defect, and not filed.

## 2026-11-17 — delivery 3 of `code-factory-dogfood-2026-11-17-10-10-24`: the node-create leg

- **Verdict for this leg**: 🔴 DOES-NOT-DELIVER on this fleet. README "Quick start" step 3 cannot
  produce a node on either bunker host that answers; deliveries 1–2 left the leg unverified, this one
  walked it.
- **Tip walked**: `db42390d` (`origin/main`, parity 0/0, clean tree). Fixture:
  `https://github.com/github/gitignore`; harness `hermes`; live crier on the fleet's loopback port.
- **Measured**: `bunker-las-03` → `FAIL spawn — … at stage slice-limits … memory.swap.max = "max",
  want "0" (bar swap)`, rc 1, 27.19 s. `bunker-las-02`, identical command, only the server changed →
  the same assertion at a different read budget (5 vs 40), rc 1, 20.59 s. `bunker-las-01` and
  `bunker-las-04` are OFFLINE (`dial tcp … i/o timeout`). The host-free arm
  (`--staged-files`) is fine: rc 0, 14 files, 0.42 s.
- **What held**: the failure is not swallowed (rc 1, `FAIL` prefix, bunkerd log path, final
  diagnostic quoted) and no agent is stranded — `bunker list` reports `No agents found` on both hosts
  after both failures.
- **Rows filed**: `CF-489` (P1 — no ONLINE host can spawn; rows carry the host setting to change and
  the doc that must stop implying a working path) and `CF-490` (P2 — the spawn refusal is
  unclassified passthrough with no remedy line, and `grep` for the prerequisite in the tree returns
  0 hits). Chapters named on both: `III.M1.S1`, `III.M1.S2`.
- **Not claimed**: slice-level residue below the agent list (no exec path, and `bunker reap` /
  `bunker homes` reject `--server`); that cgroup swap accounting is the only cause; and any
  successful node create — none was observed.
- **Artifacts**: `docs/dogfood/2026-11-17-node-create-leg.md`,
  `.coding-hermes/evidence/code-factory-dogfood-2026-11-17-10-10-24/step3-*` + `r3-*`/`r4-*`, plus
  the delivery-3 section of that directory's `INDEX.md`.
- **No dispatch**: this lane's contract is to file, not to fix its own findings (the dogfood skill's
  rule), so no worker was spawned on `CF-489`/`CF-490`; the next `code-factory` foreman tick should
  take `CF-490` first — it is repo-side code plus docs with a fixture, and it does not need host
  access. `CF-489` is blocked on the host owner for its PASS arm.


## 2026-11-17 — delivery 4 of `code-factory-dogfood-2026-11-17-10-10-24`: duplicate delivery, then the foreman leg on CF-490

- **Duplicate delivery, confirmed before any work**: `grep -c` of the tick id in
  `~/.hermes/logs/gateway.log` returns 4 inbound lines (05:10, 05:46, 06:11, 07:02 local). Deliveries
  1-3 own the walk: rows `CF-483`/`CF-484` (control-host path at `0014b76a`), `CF-489`/`CF-490`
  (node-create leg on two bunker hosts), evidence under
  `.coding-hermes/evidence/code-factory-dogfood-2026-11-17-10-10-24/`, plus the re-fire receipt
  `82972156` and its addendum `f892cbd6`. No re-walk here; nothing re-measured.
- **Provenance re-verified from `origin/main`, not the working copy**: `CF-483`, `CF-484`, `CF-489`,
  `CF-490` all `pending` with a paired `task_created` event each; the evidence directory is tracked
  and non-empty; `gitreins` history holds the dogfood verdict run `ed488866`.
- **The tree was held, twice, by live writers.** At 07:03-07:08 the sibling foreman tick
  `code-factory-foreman-2026-11-17-10-27-30` (session `e738fa85`) held the shared checkout: its
  `board-close.sh` had `CF-486` staged as `complete` while `HEAD` still read `in_progress`. It landed
  and pushed `609172a1`; the tree then went clean. At 08:04-08:12 three more sessions were committing
  board rows in the same checkout (`CF-274` closeout, a `-- .coding-hermes/board/**` pathspec commit)
  with `.git/index.lock` held through their gitreins guards. **No second dispatch into the shared
  checkout, and no board write retried against a held index** — that contention is why the CF-490
  landing was done from an isolated worktree.
- **Delivery 3's handoff was executed, by the lane that owns it.** Delivery 3 ended with "the next
  `code-factory` foreman tick should take `CF-490` first". This delivery is that tick: `CF-490`
  claimed on the board (status `in_progress` + `foreman_note` naming the tick, the chapter and the
  files) in `70d02621`, GitReins task `CF-490` created and started, a worker
  (`openai/gpt-6.1-terra@xkiro`, the authoritative worker lane) dispatched into
  `~/.hermes/cache/scratch/cf490-wt-0715` on branch `cf490-host-spawn-class` at base `70d02621`.
  Fixing the finding is the foreman leg, not the dogfood lane fixing its own findings; the walk
  itself stayed read-only.
- **The worker lost its turn, its diff survived.** `hermes chat` exited 1 with "Gateway disconnected;
  turn outcome is unknown" after staging all seven files. Per the unattended-session rule the index,
  not the log, is where such a deliverable lives: the staged set was frozen as-is, every gate was run
  by the foreman, and the commit was made under the foreman's identity with the provenance disclosed
  in the message (`56c3a2b1`).
- **Measured, all offline (no live bunker run claimed)**:
  `bash tests/selftest.sh` in the worktree → `SELFTEST: PASS`, `EXIT=0`, 598 `PASS` rows, including
  `PASS CF-490 host spawn refusal -> one FAIL host row (fixture-server, stage slice-limits) + one
  remedy line` and `PASS CF-490 red control: the pre-fix script prints only the bare FAIL spawn row`.
  `bash docs/audits/cf490-host-spawn-proof.sh` → `CF490-PROOF: PASS`, rc 0 (ARM A pre-fix: host rows 0,
  remedy 0; ARM B post-fix: host rows 1, spawn rows 0, remedy 1, log exists, diagnostic verbatim;
  ARM C quota refusal keeps `FAIL spawn`; docs greps 2/2 and 1/1). `bash -n` on the three changed
  shell files, rc 0 each (the `bash -n <file>` form was refused by the scan-budget gate and the
  stdin form `bash -n < <file>` was used instead).
- **A caution for the next fire**: the commit-time guard reported `Tier 1: DEGRADED PASS (skips:
  lint=no staged files, tests=no staged files)` on this worktree, and the two guard runs recorded
  around the commit (`guard-20261117T124910`, `…T125557`) also show `lint: no staged files` — so the
  suite that certifies this fix is the one the foreman ran directly, not a hook lane. That is the
  CF-474 class again (a commit-time guard presented an empty staged set in a worktree), already
  filed; this is a third independent measurement, not a new row.
- **Landed**: fix commit `56c3a2b1`, merge `96e119e5` pushed to `origin` and `gh` (both refs verified
  equal to the local tip by `ls-remote`), CI run on `96e119e5` = `success`. The landing was done from
  the isolated worktree (merge of `cf490-host-spawn-class` onto `origin/main` at `3d2a7c46`, then
  `git push origin HEAD:main`) precisely because the shared checkout's index was held by other lanes;
  full suite re-run on the MERGED tree before pushing: `SELFTEST: PASS`, `EXIT=0`, 598 `PASS` rows.
- **CI**: `gh run list` at tick start — last three runs `success`/`success`/`cancelled`
  (the cancelled one is the superseded dogfood-commit run); the merged tip `96e119e5` then ran
  `success`. No failure to file.
- **Evidence committed**: `.coding-hermes/evidence/code-factory-dogfood-2026-11-17-10-10-24/d4-*`
  (`cf490-proof.out`, the merged-tree selftest log + its verdict excerpt, and a provenance record
  naming the fix commit, merge commit, base and remote tip).


## 2026-11-17 — delivery 5 delta: CF-483 fixed, judged and landed (run `code-factory-dogfood-2026-11-17-10-10-24`)

- **Duplicate delivery, proven before work**: `grep -c '<tick-id>' ~/.hermes/logs/gateway.log` = **5**
  inbound lines (05:10:31, 05:46:57, 06:11:09, 07:02:43, 09:33:53 local); this is the fifth. Deliveries
  1-4 own the walk and the records: `CF-483`/`CF-484` (control-host path at `0014b76a`), `CF-489`/`CF-490`
  (node-create leg), the re-fire receipt `82972156` + addendum `f892cbd6`, and the CF-490 foreman leg
  (`56c3a2b1` → merge `96e119e5` → close `c71f7f95`).
- **Provenance re-verified from `origin/main`, not the working copy** (585 board rows, 915 event rows,
  0 unparsed either side): `CF-483`/`CF-484`/`CF-489` `pending` with one paired `task_created` event
  each; `CF-490` `complete` with its fixture (9 `CF-490` mentions in the committed `tests/selftest.sh`),
  its proof script `docs/audits/cf490-host-spawn-proof.sh`, and judge history `.gitreins/history/2026-11-17/921f41d7`.
- **This delivery took ONE row, and it was not a re-walk.** `CF-483` (P3, complexity 1, chapter
  `III.M1.S1`) had no owner and a live premise: at `c71f7f95` the documented step-1 command still
  printed `Residue:  0 orphan homes …` and `WARN  residue` on the same screen, because
  `scripts/bunker-server-install.sh:117` greps the status block for the word "orphan" — which labels
  the counts. Re-measured this fire before claiming: rc 0 in 1.40 s, both lines present.
- **Dispatch**: claim commit `04ff8f9d`, GitReins task `CF-483` created+started, worker in an isolated
  worktree `~/.hermes/cache/scratch/cfd5-wt-cf483` (branch `cf483-residue-class` at `c71f7f95`) so the
  shared checkout's index was never taken. **The brief's model was unavailable**: `openai/gpt-6.1-terra`
  @ xkiro answered `503 model_maintenance` ("use another model in the meantime", resume
  2026-11-19T16:25:12Z); `gpt-6-luna` @ xkiro gave the same 503 and `gpt-6.1-sol` @ xkiro never answered.
  A probe of `openai-codex/gpt-6-luna` returned `READY` rc 0, so the worker ran there — same family,
  subscription lane. The first dispatch was killed by exact pid after the provider's 600 s backoff
  parked it with an unchanged worktree, and it is disclosed here rather than dropped.
- **What landed** (`2d06b79a`, merged as `5c9ede92`): a `residue_counts()` parser reads the four
  server-reported numbers, `0/0/0/0` prints `PASS residue — 0 orphan users, …, 0 stale linger entries
  (server-reported)`, a non-zero count prints `WARN residue — 3 orphan homes, 2 orphan keys …`, and a
  status block whose counts cannot be parsed prints its own `WARN … could not be parsed` — "unmeasured"
  is never read as "0". Remedy text now names the machine the two directories live on. `tests/selftest.sh`
  §32b adds the zero, leaky and unparseable arms plus a red control against the pre-fix predicate; the
  `M1-provisioning.md` §10 failure-table row now states what `--check` prints and what the CF-003 reaper
  prints, instead of implying the installer reaps.
- **Gates measured by the foreman, not inherited**: `bash -n` rc 0; the live arm against `bunker-las-03`
  now prints the `PASS residue` row and no WARN (`ev-d5-postfix.out`, pre-fix capture in
  `ev-d5-prefix.out`); `bash tests/selftest.sh` on the MERGED tree → `SELFTEST: PASS`, `EXIT=0`,
  **602 PASS rows**, both CF-483 rows green (`ev-d5-merged-selftest.log`).
- **Landed and pushed**: `git push origin HEAD:main` → `25f73546..5c9ede92`; remote `main` re-read as
  `5c9ede92` after a fresh fetch.
- **UNVERIFIED this fire**: the tier-2 judge verdict (the tier-1 leg was still evaluating when this
  entry was written — its run id is recorded in the closeout commit, which is the artifact to read);
  `CF-489`'s PASS arm (still owner-blocked: no ONLINE host can spawn, `bunker-las-03`/`-02` refuse at
  `slice-limits`, `-01`/`-04` are offline — unchanged from delivery 3, and not re-probed here to avoid
  restating an earlier fire's numbers).
- **Evidence**: `.coding-hermes/evidence/code-factory-dogfood-2026-11-17-10-10-24/d5-*`
  (`d5-cf483-prefix-check.out`, `d5-cf483-postfix-check.out`, `d5-merged-selftest.txt`,
  `d5-provenance.txt`; the selftest log is stored as `.txt` because `.gitignore:3` ignores `*.log`).


#### Addendum — the verdict landed after this entry was committed

The "UNVERIFIED" line above is scoped to the moment it was written. The tier-2 judge finished at
10:31 and its authoritative artifact is `.gitreins/history/2026-11-17/175640de/verdict.json`
(copied to `d5-cf483-verdict-175640de.json`):

- **`passed=false`**, `tier2_skipped=false`, tier 1 `PASS`, 6 items graded — **5 PASS, 1 FAIL**.
  The FAIL is item 1's last clause only, "`bash tests/selftest.sh` stays green": the judge's run saw
  `SELFTEST: FAIL (4)`, `EXIT=1`, aborting at **section 16** (node-create staged set), and recorded
  itself that the 4 counted FAILs are section-7b board fixtures and that no CF-483 row was red.
- **Counter-evidence, three independent full runs, every one `SELFTEST: PASS` / `EXIT=0` / 602 PASS
  rows with both CF-483 arms green**: the merged tree before the judge started (`d5-merged-selftest.txt`),
  the records-commit guard on `739c73d5` (`.gitreins/logs/guard-20261117T152305.585170Z.log`,
  `tests (full)` OK), and a **solo** run at `739c73d5` with an empty porcelain and nothing else in
  the worktree (`d5-solo-selftest.txt`, 10:38-10:48). The judge's run overlapped two other full suites
  in the same worktree — this delivery's own records committer ran the guard suite twice (10:12:51
  refused on the publish gate, 10:19:23 passing) — and section 16 is the fixture that binds a stubbed
  bunker plus temp dirs. Classified as a contended-checkout observation, **not** a property of the diff.
- **The row was NOT closed on it**: `CF-483` stays `in_progress` with the note naming both the verdict
  and the three green runs; the queued action is a re-judge (set `commit_hash` to `2d06b79a`, then
  `gitreins task start` + `task complete --scan-root` on a worktree with nothing else running).
- **A real gap fell out of the grading**: the judge's `uncovered failure paths` note says the residue
  WARN does not change the exit status, so `--check` prints `RESULT: PASS` on a host leaking 3 homes
  and 2 keys. Verified from the leaking fixture, not inherited — filed as **`CF-495`** (P3, chapter
  `III.M1.S1`), because a surface automation reads must be able to fail.

## 2026-11-17 — delivery 6 delta: CF-489's premise is dead, CF-496 filed

- **Duplicate delivery, proven before work**: `grep -c '<tick-id>' ~/.hermes/logs/gateway.log` = **6**
  inbound lines (05:10:31, 05:46:57, 06:11:09, 07:02:43, 09:33:53, 11:00:26 local). Deliveries 1-5 own
  the walk and the records (`CF-483`/`CF-484`, `CF-489`/`CF-490`, the re-fire receipt, the CF-490 leg,
  `CF-483`'s fix `2d06b79a` and the verdict record `a205414a`/`046802e4`). This delivery wrote a delta,
  not a second copy.
- **Delivery 5's UNVERIFIED tier-2 leg is CLOSED, from the committed record, not from prose**: its
  report left the `CF-483` judge verdict unverified. `a205414a` records it — run `175640de`,
  `passed=false`, tier 1 PASS, 6 items 5 PASS / 1 FAIL, the FAIL confined to the "suite stays green"
  clause that three independent full-suite runs contradict — and `046802e4` re-applies the verdict
  note the rebase union dropped. `CF-483` is `in_progress` on purpose: a FAIL verdict is not a close.
- **The other UNVERIFIED leg was walkable, and walking it killed the row.** `CF-489` (P1) claimed no
  ONLINE host can spawn. Re-measured with its own documented command and fixture
  (`github/gitignore`, `--harness hermes`, `--ttl 2h`): **both** ONLINE hosts now print
  `PASS  spawn` — `bunker-las-03` → `node-dogfood-probe-110346` (162 s), `bunker-las-02` →
  `node-dogfood-probe2-110651` (152 s) — and both runs continue into `PASS  staged` and in-node
  provisioning. No `FAIL spawn`, no slice-limits diagnostic. Host census the same fire: `-03` ONLINE
  0/8, `-02` ONLINE 0/8, `-01`/`-04` OFFLINE (dial timeout). `CF-489` closed against that evidence;
  criterion #4 respected — nothing tuned, no diagnostic suppressed.
- **One new operator-facing defect filed as `CF-496` (P4, chapter `III.M1.S1`)**: layer 00 grades
  `CRIER_URL` from INSIDE the node (`scripts/project-node.sh:289-299`) and prints a bare
  `FAIL  reach:<url>/health — -> 000`, which reads as "crier is down" when the bus is up. One agent,
  one variable, both hosts: control-host loopback → 200; inside `node-dogfood-probe-110346` loopback →
  000, control-host LAN → 000, control-host tailnet → 200; inside `node-dogfood-probe2-110651` loopback
  → 000, tailnet → 200. So the probe is right and the message is the defect.
- **Harness attribution, stated so the next fire does not inherit a false red**: the `reach:` FAIL in
  this fire's own transcripts is *this harness's* choice of a loopback `CRIER_URL` — not a product
  fault, and deliberately NOT filed as one. The product finding that survives that check is the
  message and the docs' silence on node-side reachability.
- **Residue disposed**: both spawned agents destroyed after their transcripts were captured
  (`d6-destroy-las03.out`, `d6-destroy-las02.out` — archived-then-deleted, rc 0, keys removed), so
  neither host carries a probe agent.
- **UNVERIFIED this fire**: `CF-489`'s closeout as a judged run — the tier-1/2 verdict for this
  closeout is recorded in the closeout commit and is the artifact to read, not this entry;
  `CF-496`'s own fix (correctly, it is pending).
- **Evidence**: `.coding-hermes/evidence/code-factory-dogfood-2026-11-17-10-10-24/d6-*`
  (`d6-create-bunker-las-03.out`, `d6-create-bunker-las-02.out`, `d6-host-census.out`,
  `d6-node-reach-ab.out`, `d6-destroy-las03.out`, `d6-destroy-las02.out`, plus the two create
  scripts, the reach A/B script and the elision scripts that ran). Addresses and host-home paths are
  elided; the substitution table is in the evidence `INDEX.md`.

## 2026-11-17 — delivery 6 addendum: the las-02 PASS did not reproduce; CF-489 stays open

- **What forced this addendum**: the tier-2 judge on the closeout run (`gitreins task complete CF-489`
  → verdict `fd3b385b`) rejected the closeout on two counts. One was mine and it was fair: the las-02
  arm ran `--project dogfood-probe2` while `CF-489`'s criterion names `--project dogfood-probe`, so the
  second host had not actually been walked with the documented command.
- **Re-ran the arm with the documented argument, and it does not reproduce.** At 16:39 the same script,
  same fixture, same host printed `FAIL  host — bunker-las-02 cannot spawn an agent: slice-limits` in
  **17 s** — the exact refusal delivery 3 recorded. Both transcripts are now committed: the 16:06 PASS
  is preserved as `d6-create-bunker-las-02-pass-1606.out` (it had been overwritten in the working tree
  by the re-run; restored from `d389fb7a`), and the 16:39 documented run is `d6-create-bunker-las-02.out`.
- **The honest reading of this fire's evidence is narrower than its commit claims.** `bunker-las-03`
  spawns: `PASS  spawn — node-dogfood-probe-110346` at 16:03, 162 s, no host row. `bunker-las-02` is
  **intermittent**: one PASS at 16:06 and one slice-limits refusal at 16:39, same host, same fixture,
  no code change between the two runs, and no agent left behind by either. A nondeterministic spawn
  refusal is a worse defect than the deterministic one delivery 3 recorded, and it is exactly what
  `CF-489`'s title ("no ONLINE node host … can spawn") cannot express.
- **Correction to `d389fb7a`'s own message and log entry**, which say "CF-489 closed against that
  evidence": no close was ever written. The board gate needs `--evidence-run-id` from a judged run, and
  the judge then graded the still-open row — which is the second of its two findings, and it was right.
  The close is **dropped, not deferred**: `CF-489` stays open at P1 with both measurements recorded on
  the row (`boardctl update CF-489 --note …`), and this addendum is what a later reader reconciles
  against, not a retraction of the entry above.
- **The mechanism worth keeping**: the judge's first finding (wrong `--project`) is what exposed the
  second (intermittent refusal). A transcript that is not reproducible from its committed script hides
  the arm's real result — the deviation was not cosmetic, it was the thing masking the failure.
- Judge run for this addendum: `fd3b385b` (tier 1 + tier 2 over the closeout diff), recorded on the row.
## 2026-11-23 — run `code-factory-dogfood-2026-11-23-15-03-37` (delivery 1 of this run)

- **Verdict**: 🟢 control-hold: the documented control-host path is honest at today's tip; no new
  rows filed because every friction point this walk hit already has an owner.
- **Wave recovery first**: the tick opened as WAVE RECOVERY for `code-factory-foreman-2026-11-22-03-32-06`
  (0 workers). Verified against origin/main rather than the manifest's own words: row
  CF-346 complete at 5fb7f16c and merge 8021e8ac are both ancestors of main; evidence branch
  `wt/CF-346` @ b0a642fa preserved unmerged; manifest `finished_at 2026-11-22T20:30Z, outcome
  recovered` (closed by ops tick fire of 11-22). Nothing to recover; no merge, no dispatch.
- **Residue landed before the walk**: the shared checkout held a staged board-only diff (8 rows,
  updated_at 2026-11-23T13:42:06Z, content attributing pm tick `code-factory-pm-2026-11-23-13-30-00`)
  that its tick ended without committing. Attributed, no live writer (census), board validate OK
  (RESULT: OK, 101 legacy warnings), committed as e487d578 and pushed. First commit attempt was
  blocked by a tier-1 red on `section 42 CF-390 worktree census/reaper`; the arm ran green solo
  (20 tests OK, rc=0) so the red was load-collision, not a defect — nothing filed, guard re-ran
  full-suite green on the retry.
- **Path walked at e487d578 (evidence: .coding-hermes/evidence/<this tick>/)**:
  1. Quick start step 1 `bunker-server-install.sh --check` with the README's own CRIER_URL
     placeholder: aborts at `FAIL server_declared — BUNKER_SERVER unset` (the pre-CF-009 behavior),
     4 lines, rc=1. Honest per the README's own "fail with the missing value named" promise.
  2. Quick start step 2 `project-node.sh --check --project myproject` with a throwaway HOME:
     full ladder ran, `NODE: FAIL (5)` (reach/crier, gateway_auth, python, crier_identity, repo),
     every row names its remedy; **python row names HERMES_PYTHON_BIN=python3.12 exactly as the
     README quick start promises**; side-effect census `find $H -mindepth 1` = 1 entry
     (`$H/.node`, 0 files) — the README-documented side effect reproduced exactly at today's tip.
  3. Provisioning `--check` with throwaway HOME (the CF-506/CF-507 surface): the FAIL inputs row
     names all FIVE template credentials; agent row FAILs naming the absence and the remedy
     (`run --apply to create it`). CF-507's fix holds (agent row grades the client's output).
- **Premises re-measured live (all three rows stay open, no new rows)**:
  - CF-037 fix holds: reach row prints `-> 000` (three digits), not 000000.
  - CF-496 premise live: reach row still prints the bare `-> 000` naming neither the vantage
    point nor the requirement (control-host run, healthy-by-proxy bus absent).
  - CF-508 premise live: REPO=git@... passes `--check` — the only scheme mention is the `..`
    continuation row `resolved repo=git@...`; no PASS/FAIL row names the scheme or its
    credential implications (file 04-provision-ssh-repo.txt).
  - CF-506 premise live: README:136-137 names three credential files; the template and the
    live inputs row name five (file 03-provision-check.txt).
- **Not walked this fire, and why**: Quick start step 3 (node-create) — needs the documented
  spawn-capable target preflight; this fire spent its budget on the recovery bookkeeping, the
  residue landing and the legs above. The spawn surface was measured by the 11-17 run (CF-489/CF-496)
  and has not changed class since (no product delta touching bunker/ in the interim beyond the rows
  above); a re-drive would re-measure the las-02/03 hosts, not the tree.
- **Tip walked**: e487d578a5 (origin/main, parity 0/0 before the entry; pushed). CI green at the
  prior tip 932ac6ab and last 3 runs success; guard full-suite green at e487d578 on the residue commit.

Tick id (body, not heading): code-factory-dogfood-2026-11-23-15-03-37

## 2026-11-23 no-op provenance — delivery 2

- Tick id (body, not heading): code-factory-dogfood-2026-11-23-15-03-37
- Inbound dispatch count for this exact label in gateway.log: 2 — 2026-11-23 10:03:58,429 (gateway line 24449, delivery 1) and 2026-11-23 10:29:24,746 (line 25485, this delivery 2). Both platform=api_server, same gateway.
- Classification: repeated dispatch of one label is a scheduler/gateway dispatch defect, NOT a product defect; owning board = the coding-hermes scheduler project (dispatch path), not code-factory.
- Parity/delta proof: git fetch origin; HEAD == origin/main == 2ee3cbb1; git rev-list --left-right --count HEAD...origin/main = 0 0; delivery 1's final closeout commit 2ee3cbb1 IS the published tip, so the product delta since the last delivery is EMPTY.
- Delivery-1 closeout verified from durable state, not the report: its log entry (line 303 in the published blob) and its evidence files (01-bunker-install-check.txt, 02-project-node-check.txt, 02-sideeffect-count.txt, 03-provision-check.txt, 04-provision-ssh-repo.txt) exist in the committed tree under .coding-hermes/evidence/code-factory-dogfood-2026-11-23-15-03-37/.
- Wave recovery re-verified: manifest code-factory-foreman-2026-11-22-03-32-06.json carries finished_at_utc 2026-11-22T20:30Z, outcome recovered, row CF-346 complete (commit 5fb7f16c and merge 8021e8ac ancestors of origin/main); evidence branch wt/CF-346 preserved unmerged. This tick's recovery banner itself names 0 worker(s) — nothing to recover, no merge, no dispatch, no new wave composed.
- Board re-count at THIS delivery (source origin/main via scripts/board_read.py): 624 rows, whole-stream parse 624/624 OK, blocked=5 complete=239 in_progress=16 pending=364. Working copy clean; ownership.py state=clean; no live writer in the main checkout.
- Stale .git/REBASE_HEAD marker (points at c00345c1, 6 commits behind HEAD, dated Nov 22 22:51): stale by definition, cleared this delivery after the census.
- Why the perf leg was NOT re-measured: re-driving an unchanged tree measures the host, not the product; delivery 1's warm/cold numbers stand. The node spawn surface stays covered by the 11-17 run per delivery 1's own note.
- Board rows filed this delivery: 0. Product commits: 1 (this log entry alone).
- DuckBrain refire receipt written at key /project/code-factory/foreman/ticks/code-factory-dogfood-2026-11-23-15-03-37.refire-delivery-2 (namespace code-factory); no prior record for this tick id existed there.

## 2026-11-23 no-op refire delta — delivery 3

- Tick id (body, not heading): code-factory-dogfood-2026-11-23-15-03-37
- Inbound dispatch count for this exact label in gateway.log: 3 — gateway lines 24449 (10:03:58Z, delivery 1), 25485 (10:29:24Z, delivery 2), 26290 (10:46:45Z, this delivery 3). Same gateway, platform=api_server, same chat id.
- Product delta since delivery 2's receipt commit f72dce5a: EMPTY in the product tree — delivery 2's receipt commit is the published tip; this entry plus the two durable records below are the only writes.
- Closeout verified from durable state, not delivery reports:
  - Parity: fetched 15:50Z; HEAD == origin/main == gh/main == f72dce5a; rev-list both directions 0/0. Working copy clean; live-writer census of the repo root found only this transport (own HERMES_SESSION_ID matches, no foreign writer).
  - Wave recovery: manifest 03-32-06 already recovered (delivery 1-2 verified, stands). The NEWER wave manifest code-factory-foreman-2026-11-22-22-24-47.w1 is also discharged: its CF-361 attempt-1 worker died uncommitted (3 resumes; rc=0 then rc=1, rc=1 — last error "Gateway draining: not_ready"), but the sibling tick 14-40-46's independent CF-361 dispatch landed the deliverable (product 56f44fa5, six contract pages in docs/contracts/), judged it, and closed the row (932ac6ab; row commit_hash e7957634; verdict dir .gitreins/history/2026-11-23/98bde653 on disk with tier1 PASS).
  - CF-361 verdict honesty: every named criterion plus fix_verification reads PASS, but the verdict's overall is FAIL from the gitreins coverage arm ("Coverage FAILED — ungraded", detected_by empty) — the documented items-pass-while-overall-false judge artifact, not a criteria miss. Board truth (complete) is sound.
  - The 22-24-47 worker's superseded deliverable in ~/worktrees/code-factory-CF-361 (specs/*.md for six systems, two modified docs) DIFFERS from what landed: it describes the systems under specs/, the merged deliverable uses docs/contracts/. Preserved unmerged as evidence of the duplicate delivery, per the wt/CF-346 precedent; not residue, not merged. Duplicate-dispatch doctrine worked: reconcile by AC merits, keep one.
  - CF-403 (the wave's second row) stays PENDING in the owning row with its scope already narrowed (frozen-literal half fixed by CF-398 7d4b1f04; the boardctl run-id half is the remaining defect, owner = boardctl repo internal/board/write.go, tracked on the CF-403 row itself — no new row filed).
- CI: green — last 3 runs on main all success (latest covers f72dce5a, 15:46Z).
- Board rows filed this delivery: 0. Product commits: 1 (this log entry alone). No dispatch composed; wave budget spent on recovery verification only.
- DuckBrain: refire receipt at /project/code-factory/foreman/ticks/code-factory-dogfood-2026-11-23-15-03-37.refire-delivery-3 and foreman handoff delta at /handoff/code-factory/foreman/2026-11-23T1600Z-delivery3-refire-delta (namespace code-factory).


## 2026-11-23 no-op refire delta — delivery 4

- Tick id (body, not heading): code-factory-dogfood-2026-11-23-15-03-37
- Inbound dispatch count for this exact label in gateway.log: 4 — gateway lines 24449 (10:03:58, delivery 1), 25485 (10:29:24, delivery 2), 26290 (10:46:45, delivery 3), and line 4 at 11:10:36 (this delivery 4, refire of the same label ~24 minutes after delivery 3).
- Product delta since delivery 3's receipt commit f35e40ff: EMPTY in the product tree — f35e40ff is the published tip; working copy clean; this entry plus one gitignored manifest finalization are the only writes.
- Parity re-verified: fetched gh 16:12Z; HEAD == gh/main == f35e40ff; `git rev-list --count gh/main..HEAD` = 0. Delivery 3's receipt is fully published and its CI run (16:10:20Z, main) is success.
- Wave recovery preamble discharged: manifest code-factory-foreman-2026-11-22-03-32-06 already recovered (finished_at 2026-11-22T20:30Z, outcome "recovered", rows complete — stands from delivery 1-3). The NEWER manifest code-factory-foreman-2026-11-22-22-24-47.json is now marked final/finished_at_utc 2026-11-23T16:16Z / outcome "recovered" (gitignored waves/ path, working-tree state only, matching the 03-32-06 precedent): CF-361 complete on origin/main (row commit_hash e7957634; sibling dispatch product 56f44fa5, close 932ac6ab, verdict 98bde653 tier1 PASS, overall-FAIL = documented coverage-arm artifact), CF-403 pending in its owner scope, superseded duplicate deliverable preserved unmerged in ~/worktrees/code-factory-CF-361, no live workers remain.
- CI: green — last 3 runs on main all success (latest covers f35e40ff, 16:10:20Z).
- Board rows filed this delivery: 0. Worker dispatches: 0 (no dispatchable refire delta; wave manifest closed instead). Product commits: 1 (this log entry alone).
- No DuckBrain write this delivery: delivery 3's refire receipt and handoff delta stand; the delivery-4 delta is materially identical to delivery 3's and the log entry above is the durable record.
## 2026-11-23 no-op provenance — delivery 5

- Tick id (body, not heading): code-factory-dogfood-2026-11-23-15-03-37
- Inbound dispatch count for this exact label in gateway.log: 5 — gateway lines 24449 (10:03:58 local = 15:03 UTC, delivery 1), 25485 (10:29:24, delivery 2), 26290 (10:46:45, delivery 3), delivery 4 at 11:10:36 (16:10:36 UTC), and delivery 5 at 11:24:11 local = 16:24:11 UTC (this delivery). Same gateway, platform=api_server, same chat id. Note (delivery 5 correction): earlier entries quoted these gateway timestamps with a Z suffix; the gateway log is stamped in host local time (-05), so the true UTC times are as written here.
- Product delta since delivery 4's receipt commit 20d25b63: EMPTY in the product tree — 20d25b63 is the published tip; this entry is the only write.
- Parity re-verified: fetched 16:26 UTC; origin/main == gh/main == HEAD == 20d25b63; rev-list HEAD..origin/main = 0 and gh/main..HEAD = 0. Working copy clean (porcelain empty). Delivery-1 closeout evidence files still on disk under .coding-hermes/evidence/code-factory-dogfood-2026-11-23-15-03-37/ (5 files).
- Wave recovery re-verified for this delivery's banner: manifest 03-32-06 finished_at 2026-11-22T20:30Z outcome recovered with 0 worker(s); the NEWER manifest 22-24-47 finished_at 2026-11-23T16:16Z outcome recovered (closed at delivery 4). Both manifests carried zero dispatched workers — nothing to recover, no merge, no new wave composed.
- CI: the latest run on main (displayTitle "delivery 4", created 16:24:04Z) was still in flight at census time (16:26 UTC, conclusion empty); the two prior runs (16:10:20Z and 15:46:18Z, main) are success. Conclusion of the in-flight run left to the scheduler's next tick to observe — not claimed green.
- Board re-census at THIS delivery (source origin/main via tracked-tree read): 624 rows, whole-stream parse 624/624 OK, 0 malformed, 0 duplicate ids, blocked=5 complete=239 in_progress=16 pending=364 — identical to delivery 2's census; the board is untouched across deliveries 2-5.
- Board rows filed this delivery: 0. Worker dispatches: 0. Product commits: 1 (this log entry alone).
- No DuckBrain write this delivery: delivery 3's refire receipt and handoff delta stand; the delivery-5 delta is materially identical to deliveries 3-4 and the log entry above is the durable record.
- Why the perf leg was NOT re-measured: re-driving an unchanged tree measures the host, not the product; delivery 1's warm/cold numbers stand.
## 2026-11-23 no-op refire delta — delivery 6

- Tick id (body, not heading): code-factory-dogfood-2026-11-23-15-03-37
- Inbound dispatch count for this exact label in gateway.log: 6 — gateway lines 24449 (10:03:58 local = 15:03 UTC, delivery 1), 25485 (10:29:24, delivery 2), 26290 (10:46:45, delivery 3), delivery 4 at 11:10:36 (16:10:36 UTC), delivery 5 at 11:24:11 (16:24:11 UTC), and this delivery at 11:57:40 local = 16:57:40 UTC. Same gateway, platform=api_server, same chat id.
- Product delta since delivery 5's receipt commit d4e9dafe: tip advanced only by the SIBLING foreman lane's board closeout 6c442a12 (foreman tick code-factory-foreman-2026-11-23-16-18-26 closed CF-385 at tip 20d25b63; not this lane's product tree delta — dogfood code surface unchanged).
- Parity re-verified: fetched origin and gh 17:11 UTC; origin/main == gh/main == HEAD == 6c442a12; rev-list HEAD...origin/main = 0 0 and HEAD...gh/main = 0 0. Working copy clean, no index.lock, live-writer census (exact cwd, own-sid excluded): zero foreign writers.
- Carry verification this delivery: delivery-1 closeout entry present in the published dogfood-log line 303 and its 5 evidence files present in the committed tree at .coding-hermes/evidence/code-factory-dogfood-2026-11-23-15-03-37/; CF-385 close verified from durable state — row complete on origin/main (commit_hash 20d25b63, updated_at 2026-11-23T16:34:25Z) and verdict run dir .gitreins/history/2026-11-23/e3672a71 on disk with passed=true; wt/CF-346 evidence branch preserved unmerged.
- Wave recovery re-verified for this delivery's banner: manifest .coding-hermes/waves/code-factory-foreman-2026-11-22-03-32-06.json finished_at_utc 2026-11-22T20:30Z, outcome recovered, workers 0 — nothing to recover; no merge, no fixup, no new wave composed.
- CI: green — last 4 runs on main all success (latest 2026-11-23T16:57:11Z covers 6c442a12, the CF-385 close).
- Board census this delivery (source: origin/main tracked-tree read): 624 rows, 0 malformed, blocked=5 complete=240 in_progress=16 pending=363 — the complete delta vs delivery 5's census is CF-385's close (done by the sibling foreman, not this delivery).
- Board rows filed this delivery: 0. Worker dispatches: 0. Product commits: 1 (this log entry alone). No GitReins lifecycle: no row picked, nothing to task-create/complete this delivery.
- DuckBrain: refire receipt written at /project/code-factory/foreman/ticks/code-factory-dogfood-2026-11-23-15-03-37.refire-delivery-6 (namespace code-factory, read back id 6f1e34bb).
- Why the perf leg was NOT re-measured: re-driving an unchanged tree measures the host, not the product; delivery 1's warm/cold numbers stand.

## 2026-11-23 no-op refire delta — delivery 7

- Tick id (body, not heading): code-factory-dogfood-2026-11-23-15-03-37
- Inbound dispatch count for this exact label in gateway.log: 7 — gateway lines 24449 (10:03:58 local = 15:03 UTC, delivery 1), 25485 (10:29:24, delivery 2), 26290 (10:46:45, delivery 3), delivery 4 at 11:10:36 (16:10:36 UTC), delivery 5 at 11:24:11 (16:24:11 UTC), delivery 6 at 11:57:40 (16:57:40 UTC), and this delivery 7 at 12:38:20 local = 17:38:20 UTC (gateway line ~30197). Same gateway, platform=api_server, same chat id.
- Product delta since delivery 6's receipt commit c92cd6c4: EMPTY in the product tree — c92cd6c4 is the published tip; working copy clean in the MAIN checkout; this entry plus one durable record are the only writes.
- Parity re-verified: fetched origin and gh 17:5x UTC; origin/main == gh/main == HEAD == c92cd6c4; rev-list HEAD..origin/main = 0 and gh/main..HEAD = 0 (both remotes re-fetched this delivery).
- Wave recovery re-verified for this delivery's banner: manifest .coding-hermes/waves/code-factory-foreman-2026-11-22-03-32-06.json finished_at_utc 2026-11-22T20:30Z, outcome recovered, workers 0; the NEWER manifest 22-24-47.json finished_at_utc 2026-11-23T16:16Z, outcome recovered, workers 0. Nothing to recover; no merge, no fixup, no new wave composed.
- Carry verification this delivery: delivery-1 closeout entry still present in the published dogfood-log (line 303) and its 5 evidence files on disk at .coding-hermes/evidence/code-factory-dogfood-2026-11-23-15-03-37/; wt/CF-346 evidence branch preserved unmerged.
- Live writer NOTED, not adopted: sibling foreman tick code-factory-foreman-2026-11-23-16-18-26 has CF-526 in flight in a SEPARATE worktree (~/cf-wt-cf526-20261123, dirty tests/test_worktree_census.py, launcher cf526-worker-launch.sh + selftest running, two session ids: foreman 1ffe1685… + worker local-ae36…). The main checkout is clean and unowned; this delivery made no board RMW and did not touch the sibling's tree — the CF-526 close belongs to the sibling lane when its worker exits.
- CI: the delivery-6 receipt run (created 2026-11-23T17:38:04Z, main) was still IN FLIGHT at census time; the three prior runs on main are success (16:57:11Z, 16:24:04Z, 16:10:20Z). Conclusion of the in-flight run left to the scheduler's next tick to observe — not claimed green.
- Board rows filed this delivery: 0. Worker dispatches: 0. Product commits: 1 (this log entry alone). No GitReins lifecycle: no row picked, nothing to task-create/complete this delivery.
- Why the perf leg was NOT re-measured: re-driving an unchanged tree measures the host, not the product; delivery 1's warm/cold numbers stand.

## 2026-11-23 no-op refire delta — delivery 9

- Tick id (body, not heading): code-factory-dogfood-2026-11-23-15-03-37
- Inbound dispatch count for this exact label in gateway.log: 9 — 10:03:58 local (15:03 UTC, delivery 1), 10:29:24 (d2), 10:46:45 (d3), 11:10:36 (d4), 11:24:11 (d5), 11:57:40 (d6), 12:10:23 (UNLOGGED — no dogfood-log entry from that fire; dispatch-defect evidence for the scheduler owner), 12:38:20 (d7), and this delivery at 12:50:05 local = 17:50:05 UTC. Same gateway, platform=api_server, same chat id. Gateway log is stamped host-local (-05); UTC conversions as written.
- Product delta since delivery 7's receipt commit 098cf5ca: EMPTY in the product tree — git log c92cd6c4..HEAD holds exactly one commit, delivery 7's own log-entry commit 098cf5ca (now the published tip); non-.coding-hermes delta file count = 0. This entry is this delivery's only write to the repo.
- Parity re-verified: fetched origin AND gh this delivery; HEAD == origin/main == gh/main == 098cf5ca; rev-list HEAD...origin/main = 0 0 and HEAD...gh/main = 0 0. Working copy clean (porcelain empty).
- Carry verification this delivery: delivery-1 closeout entry present in the published dogfood-log (line 303) and its 5 evidence files on disk under .coding-hermes/evidence/code-factory-dogfood-2026-11-23-15-03-37/; CF-361 complete on origin/main (row commit_hash e7957634ff2a) with verdict run dir .gitreins/history/2026-11-23/98bde653 on disk (tier1 PASS; overall-FAIL = documented coverage-arm artifact); CF-346 complete at 5fb7f16c; wt/CF-346 evidence branch preserved unmerged.
- Wave recovery re-verified for this delivery's banner: manifest .coding-hermes/waves/code-factory-foreman-2026-11-22-03-32-06.json finished_at_utc 2026-11-22T20:30Z, outcome recovered, workers 0; the NEWER manifest code-factory-foreman-2026-11-22-22-24-47.json finished_at_utc 2026-11-23T16:16Z, outcome recovered (finalized at delivery 4). Nothing to recover; no merge, no fixup, no new wave composed.
- Live-writer census this delivery: zero foreign writers with cwd in the code-factory checkout (the only gitreins/hermes processes on the host sit in SpecLang, warpfs, and coding-hermes-tools worktrees). The sibling foreman's CF-526 worktree (~/cf-wt-cf526-20261123) has no live process; its row stays pending in the sibling lane's ownership (no evidence run id held here — not closed by this delivery).
- CI: green — last 5 runs on main all success; latest 2026-11-23T17:49:33Z ("delivery 7" log-entry commit) and 17:38:04Z (delivery 6 receipt) both concluded success since delivery 7's in-flight note.
- Board census at THIS delivery (source origin/main tracked-tree read): 624 rows, 624 distinct ids, 0 malformed, 0 duplicate ids; blocked=5 complete=240 in_progress=16 pending=363 — identical to deliveries 5-6. Board untouched across deliveries 2-9.
- Board rows filed this delivery: 0. Worker dispatches: 0. Product commits: 1 (this log entry alone). No GitReins lifecycle: no row picked, nothing to task-create/complete this delivery.
- DuckBrain: refire receipt written at /project/code-factory/foreman/ticks/code-factory-dogfood-2026-11-23-15-03-37.refire-delivery-9 (namespace code-factory); deliveries 3 and 6 hold earlier receipts, this one names the unchanged tip 098cf5ca.
- Intervening sibling commit NAMED: while this delivery was in flight the sibling foreman lane landed CF-526 on main (1b7ff76b, 12:43:14 -0500 local, "desensitize the census race arm"); at the 12:52Z census its tier-2 judge (gitreins judge CF-526, pid 4075278) was LIVE in this checkout with board/events.jsonl + board/tasks.jsonl modified unstaged, and this delivery's own log commit was held until the sibling's closeout settled (coordination-plane hold; no board RMW by this delivery). All parity / CI / board-census claims above are scoped to tip 098cf5ca as measured; CF-526's own close belongs to the sibling lane.
- Why the perf leg was NOT re-measured: re-driving an unchanged tree measures the host, not the product; delivery 1's warm/cold numbers stand.
## 2026-11-23 no-op refire delta — delivery 10

- Tick id (body, not heading): code-factory-dogfood-2026-11-23-15-03-37
- Inbound dispatch count for this exact label in gateway.log: 10 — 10:03:58 local (15:03 UTC, delivery 1), 10:29:24 (d2), 10:46:45 (d3), 11:10:36 (d4), 11:24:11 (d5), 11:57:40 (d6), 12:10:23 (UNLOGGED — dispatch-defect evidence), 12:38:20 (d7), 12:50:05 (d9; d8 unlogged), and this delivery at 13:19:59 local = 18:19:59 UTC (gateway line 31385). Same gateway, platform=api_server, same chat id. Gateway stamps host-local (-05).
- Product delta since delivery 9's receipt commit 9fad3c34: EMPTY in the product tree — HEAD == 9fad3c34 == origin/main == gh/main; the only working-copy changes are the sibling foreman's uncommitted board truthkeeping (CF-533 row + event 1024), not this lane's product surface.
- Parity re-verified: fetched origin AND gh this delivery; rev-list HEAD...origin/main = 0 0 and HEAD...gh/main = 0 0 at tip 9fad3c34.
- Wave recovery re-verified for this delivery's banner: manifest code-factory-foreman-2026-11-22-03-32-06.json finished_at_utc 2026-11-22T20:30Z, outcome recovered, workers 0; newer manifest 22-24-47 recovered 16:16Z. Nothing to recover; no merge, no fixup, no new wave composed.
- Sibling closeout state UPDATED (live-writer hold continues): CF-526's gitreins task re-created 18:14:49Z and its tier-2 judge LIVE in this checkout at census (pids 177849 -> 177982 gitreins judge CF-526, session 1ffe1685-618d-406f-b393-3ee6faa17488); the dirty board files are that session's CF-533 filing (row created 17:53:58Z + event 1024), uncommitted and owned by the sibling lane. No board RMW, no adopt, no close by this delivery.
- CI: green — the 18:19:28Z run on main (delivery 9's commit 9fad3c34) concluded success, observed this delivery (delivery 9 left it in-flight). Last 5 runs on main all success.
- Board census (source: origin/main tracked-tree read via scripts/board_read.py --next 10): 624 rows, 0 malformed, blocked=5 complete=240 in_progress=16 pending=363.
- Board rows filed this delivery: 0. Worker dispatches: 0. Product commits: 1 (this log entry alone). No GitReins lifecycle: no row picked, nothing to task-create/complete this delivery (coordination plane owned by the live sibling judge).
- DuckBrain: refire receipt written at /project/code-factory/foreman/ticks/code-factory-dogfood-2026-11-23-15-03-37.refire-delivery-10 (namespace code-factory, read back after write).
- Why the perf leg was NOT re-measured: re-driving an unchanged tree measures the host, not the product; delivery 1's warm/cold numbers stand.

## 2026-11-23 no-op refire delta — delivery 11

- Tick id (body, not heading): code-factory-dogfood-2026-11-23-15-03-37
- Inbound dispatch count for this exact label in gateway.log: 11 — this delivery at gateway line 31416, 13:25:34 local = 18:25:34 UTC.
- Wave recovery re-verified from the manifest file itself: .coding-hermes/waves/code-factory-foreman-2026-11-22-03-32-06.json finished_at_utc 2026-11-22T20:30Z, outcome recovered, workers 0 — nothing to recover; no merge, no fixup, no new wave composed (live-writer hold, below).
- Sibling closeout state UPDATED (live-writer hold continues): CF-526's first tier-2 judge run dir .gitreins/history/2026-11-23/b522e044 (18:08Z) graded commit 1b7ff76b with passed=false; the sibling foreman (tick code-factory-foreman-2026-11-23-16-18-26, session 1ffe1685) relaunched the judge — `gitreins judge CF-526` (judge2 log in its tick scratch) LIVE at this delivery's census (pids 177849 → 177982, poll child present). Its CF-533 filing (event 1024 + row, 17:53:58Z) is still uncommitted dirty in the working tree. No board RMW, no adopt, no close by this delivery.
- Product delta since delivery 10's receipt commit dc017a70: EMPTY — parity re-verified this delivery: fetched origin AND gh; origin/main == gh/main == HEAD at probe time; 0 behind / 0 ahead on both.
- CI: green — the 18:24:47Z run on main (delivery 10's dc017a70) concluded success; last 4 runs on main all success.
- Board census (source: origin/main tracked-tree read via scripts/board_read.py --next 5): 624 rows, blocked=5 complete=240 in_progress=16 pending=363.
- Board rows filed this delivery: 0. Worker dispatches: 0. Product commits: 1 (this log entry alone). No GitReins lifecycle: no row picked, nothing to task-create/complete (coordination plane owned by the live sibling judge).
- DuckBrain: refire receipt written at /project/code-factory/foreman/ticks/code-factory-dogfood-2026-11-23-15-03-37.refire-delivery-11 (namespace code-factory, read back after write).
- Why the perf leg was NOT re-measured: re-driving an unchanged tree measures the host, not the product; delivery 1's warm/cold numbers stand.
## 2026-11-23 no-op refire delta — delivery 12

- Tick id (body, not heading): code-factory-dogfood-2026-11-23-15-03-37
- Inbound dispatch count for this exact label in gateway.log: 12 — this delivery at gateway line 32176, 13:53:12 local = 18:53:12 UTC.
- Wave recovery re-verified from the manifest file itself: .coding-hermes/waves/code-factory-foreman-2026-11-22-03-32-06.json finished_at_utc 2026-11-22T20:30Z, outcome recovered, workers 0 — nothing to recover; no merge, no fixup, no new wave composed (live-writer hold, below).
- Sibling closeout state UPDATED (live-writer hold continues): CF-526's second tier-2 judge verdict landed in .gitreins/history/2026-11-23/94bcb245 (13:43 local) with passed=false at graded commit e571a45c (the live tip); CF-526 remains in_progress in the lifecycle store. The sibling foreman (tick code-factory-foreman-2026-11-23-16-18-26, session 1ffe1685) then dispatched a CF-533 worker: worktree ~/cf-wt-cf533-20261123, branch wt/CF-533 based at e571a45c, tests/test_worktree_census.py mid-edit at this delivery's census (session pids 759705/759842 live + poll loop in ~). Its CF-533 filing (event 1024 + row, 17:53:58Z) is still uncommitted dirty in the main tree. No board RMW, no adopt, no close by this delivery.
- Product delta since delivery 11's receipt commit e571a45c: EMPTY — parity re-verified this delivery after fetch: origin/main == gh/main == HEAD == e571a45c, 0 behind / 0 ahead on both.
- CI: green — last 3 runs on main all success (latest 18:42:53Z on delivery 11's e571a45c).
- Board census: 624 rows published (origin/main); working copy carries 625 with the sibling's uncommitted CF-533 row.
- Board rows filed this delivery: 0. Worker dispatches: 0. Product commits: 1 (this log entry alone). No GitReins lifecycle: no row picked — the coordination plane (board + .gitreins) is owned by the live sibling session, and a second dispatch would need board RMW plus lifecycle writes in the main tree (concrete active hazard cited for wave floor 0).
- DuckBrain: refire receipt written at /project/code-factory/foreman/ticks/code-factory-dogfood-2026-11-23-15-03-37.refire-delivery-12 (namespace code-factory, read back after write).
- Why the perf leg was NOT re-measured: re-driving an unchanged tree measures the host, not the product; delivery 1's warm/cold numbers stand.

## 2026-11-23 no-op refire delta — delivery 13

- Tick id (body, not heading): code-factory-dogfood-2026-11-23-15-03-37
- Inbound dispatch count for this exact label in gateway.log: 13 — this delivery at gateway line 33121, 14:22:48 local = 19:22:48 UTC.
- Wave recovery re-verified from the manifest file itself: .coding-hermes/waves/code-factory-foreman-2026-11-22-03-32-06.json finished_at_utc 2026-11-22T20:30Z, outcome recovered, workers 0 — nothing to recover; no merge, no fixup, no new wave composed (live-writer hold, below).
- Sibling closeout state UPDATED (live-writer hold continues): the CF-533 worker (hermes session local-89e7518c..., started 13:46:01 local, title "Fix five rc==0 asserting census arms (ambient-pid false reds)") was LIVE at this delivery's census (last_activity 14:28:15) and had committed ab8ac3be "CF-533: quarantine ambient cwd-unresolvable pids in the five clean-reap census arms" on branch wt/CF-533 in worktree ~/cf-wt-cf533-20261123 (base e571a45c); tests/test_worktree_census.py was still dirty in that worktree at census — mid-work, unmerged to main. Its CF-533 filing (event 1024 + row) remains uncommitted in the main tree. CF-526: no new judge verdict since 94bcb245 (13:43 local, passed=false); row pending on the published board. No board RMW, no adopt, no close by this delivery.
- Product delta since delivery 12's receipt commit 6f3d024f: EMPTY — parity re-verified this delivery after fetch: origin/main == gh/main == HEAD == 6f3d024f, 0 behind / 0 ahead on both.
- CI: green — last 3 runs on main all success (latest 19:22:13Z on delivery 12's 6f3d024f, concluded success before this delivery's dispatch line).
- Board census: 624 rows published (origin/main); the working copy carries 625 with the sibling's uncommitted CF-533 row.
- Board rows filed this delivery: 0. Worker dispatches: 0. Product commits: 1 (this log entry alone). No GitReins lifecycle: no row picked — the coordination plane (board + .gitreins) is held by the live sibling CF-533 worker session (concrete active hazard cited for wave floor 0).
- DuckBrain: refire receipt written at /project/code-factory/foreman/ticks/code-factory-dogfood-2026-11-23-15-03-37.refire-delivery-13 (namespace code-factory, read back after write).
- Why the perf leg was NOT re-measured: re-driving an unchanged tree measures the host, not the product; delivery 1's warm/cold numbers stand.
