# Code-factory acceptance and test plan

**Scope:** CF-101–CF-112 in [`PRD-code-factory.md`](PRD-code-factory.md), with contract details in `specs/NODE.md`, `specs/HARNESS.md`, and `specs/ENVELOPE.md`. This plan distinguishes source-level evidence from tests actually run. A passing repository self-test is not proof that every requirement is accepted.

**Current state (re-measured 2026-11-04T08:36Z at tip `8b81369`):** `tests/selftest.sh` carries 36 sections — numbered 1 through 36 — plus three lettered sub-arms, §4b, §7b and §7c, which the section regex `^say "[0-9]+\.` does not count, so the tree carries 39 arms — and exits 0 (`SELFTEST: PASS`, 121 `PASS` rows, 19 `FAIL` rows, every one an intentional negative fixture) at loadavg 8.01 (1 min), which measures the sibling lanes and judges sharing this host, not a suite property. The board at tip `8b81369` carries 154 task rows and 291 events. §34 landed at `5794a49` (CF-163 AC3) five minutes after the 33-section snapshot at `1aeb0c7`; §35 (CF-153 — node-create accepts and forwards `--ref`) landed at `a112726` and is governed by board row CF-153; §36 (CF-159 — node-create escapes every value it interpolates into a remote `bash -lc`) landed at `8b81369` and is governed by board row CF-159. Sections, rows and events on this line are measured at ONE tip and quoted for that tip only: the `20f93ad` snapshot this line used to carry paired 35 working-tree sections with a tip that carries 34 (`git show 20f93ad:tests/selftest.sh | grep -cE '^say "[0-9]+\.'` = 34; 144 task rows and 264 events), so it named a measurement no reader could reproduce from the tip printed beside it. The census in `docs/audits/cf099-prd-drift-probe.sh` compares this number against the WORKING TREE rather than the tip it names, so any lane that adds a section turns this line red until the count is re-measured — which is exactly how the stale 33 was found. As of CF-155 (2026-11-04) that census is a gate rather than a diagnostic: `bash docs/audits/cf099-prd-drift-probe.sh --sections-only` checks this line's count against the working tree, and `tests/selftest.sh` §7c runs it green on this tree and red on a fixture carrying exactly one extra numbered section, so the next added section fails a committed arm instead of waiting for the next lane to notice. Every snapshot total that follows is pinned to the tip it names and is historical, not current. The stamp this line used to carry (`2026-11-04 22:43` at `7989ba3`) mixed the 2026-11-03 local clock with the next day's UTC date, so it named a measurement ~18 h in the tick's future; stamps in this file are UTC, written `T…Z`, and name the tip they were measured at.

**Evidence snapshot (re-measured 2026-11-04T02:35Z at tip `d02916e`; the stamp read as a bare
`2026-11-04 02:35` until this correction, and the tip, not the clock, is what reproduces these
numbers):** `tests/selftest.sh` was run from
the repository root and exited 0 (`SELFTEST: PASS`, 88 `PASS` rows, suite counter `fails=0`) over
29 sections — plus two lettered sub-arms, §4b and §7b, which the section regex `^say "[0-9]+\.` does
not count, so the tree carries 31 arms; `scripts/boardctl validate` prints `RESULT: OK (48 warning(s))`;
the board at that tip carries 117 task rows and 171 events (38 complete, 75 pending, 4 in_progress).
**Delta measured 2026-11-04T08:17Z at tip `1fea92d` (sync lane):** the board carries 153 task rows and 283 events (49 `complete`, 96 `pending`, 8 `in_progress`) — `jq -s 'length'` over each file at that tip; `scripts/boardctl validate` prints `RESULT: OK (3 warning(s))` (CF-034's two free-form fields plus the headerless board); `tests/selftest.sh` prints `SELFTEST: PASS` with 109 `PASS` rows and 19 fixture `FAIL` rows over 35 numbered sections plus §4b/§7b, so the suite reading is unchanged from the `bc68e59` line above while the board itself gained 5 rows and 10 events; loadavg 25.93 (1 min), which measures the four lane ticks and judges sharing this host, not a suite property. Evidence census at this tip reports 49 `complete` rows and zero findings across all seven defect classes, and the instrument's red arm was run rather than assumed: a fixture board with `CF-009`'s newest evidence stripped reports exactly `NO_EVIDENCE CF-009` and leaves the other 48 complete rows clean. No row is filed for the `29 sections` text at `:9`/`:92` — CF-155 (pending) owns that class, and the numbers here are a delta, not a restatement of it.
**Delta measured 2026-11-04T08:29Z at tip `a5be9c9` (sync lane):** 154 task rows and 286 events (49 `complete`, 97 `pending`, 8 `in_progress`); `bash scripts/boardctl validate` prints `RESULT: OK (3 warning(s))` (CF-034's two free-form fields plus the headerless board, unchanged); `tests/selftest.sh` prints `SELFTEST: PASS` with 109 `PASS` rows and 19 fixture `FAIL` rows over 35 numbered sections plus §4b/§7b (37 arms) at loadavg 7.36 (1 min); the seven-class evidence census reports 49 complete rows and zero findings, and `docs/audits/cf099-prd-drift-probe.sh` prints `OK: milestone, plan snapshot and layer arms agree at a5be9c9`. This tick filed **CF-181** — the board carries 155 rows and 292 events at the first landing, and 156 rows / 294 events at the published tip `a5564a6`: 287 events at the first landing, 292 after the rebase over six sibling commits that moved the tip from `a5be9c9` to `a9453d9` (five events and the CF-176 closure), then the sibling PM row CF-182 with its event landed between this lane's two pushes. CF-181 came from an instrument this lane had not run before: every complete row's cited verdict artifact was parsed in the tree and its envelope `commit` tested for ancestry, measuring 21 verdict artifacts across the 49 complete rows and exactly one orphan (`CF-077`, whose verdict binds `1dfb58b8`, the pre-rewrite copy of the landed `1232f7a0`). The instrument's arms are committed beside it: `docs/audits/fixtures/cf181-board-clean.jsonl` prints `orphan_count=0`, `cf181-board-orphan.jsonl` prints `orphan_count=1` naming `CF-009`. Two residuals stay recorded and unfiled: `CF-034`/`CF-041` are `complete` without a `task_completed` event (CF-130 owns it), and the registered checkout `/home/kara/code-factory` is 8 commits behind the published tip with one sibling commit unpublished (`8f03159`, committed 03:24:20), so this pass ran from a scratch clone of `origin/main` and left that checkout untouched. The rebase over `8b81369` (CF-159's §36) turned the CF-099 probe red — plan says 35 sections, tree has 36 — so the current-state line above was re-measured at that tip rather than the tree edited back: 36 sections, 119 `PASS` rows, board 154 rows / 291 events, and §36 named with its row. That drift was the sibling commit's own landing, not this lane's diff.

**Delta measured 2026-11-04 04:03 at tip `79e9b59` (sync lane):** 134 task rows and 219 events
(45 `complete`, 83 `pending`, 6 `in_progress`); `scripts/boardctl validate` prints
`RESULT: OK (3 warning(s))` — CF-034's two free-form fields plus the headerless board;
`tests/selftest.sh` prints `SELFTEST: PASS` with 103 `PASS` rows over 33 numbered sections at that
head, loadavg 8.39. The published board bytes are identical to the checkout's
(`sha256 05e5b2f3…a820a1` on both sides) and the tip is in parity with `origin/main` (0/0). Every
number in this block was produced by the commands named in it at that tip; re-measure before quoting.
**Delta measured 2026-11-04 03:02 at tip `2c48149`:** 125 task rows and 185 events before this tick's
own audit event (186 at the landing commit) — 38 complete, 82 pending, 5 in_progress.
`scripts/boardctl validate` prints `RESULT: OK (54 warning(s))`;
`tests/selftest.sh` still prints `SELFTEST: PASS` (90 `PASS` rows) at loadavg 19.25. Two rows moved under
this snapshot without any closure being lost: **CF-053** was deliberately reopened to `in_progress` at
02:39 by the QA lane's isolation re-verification (event 181 records the transition; commit `6d801c7`
names it), and **CF-093** closed in the same window, which is why the `complete` count still reads 38.
Re-measure this block rather than trusting either snapshot.
**Delta measured 2026-11-04 03:01 at tip `dae4e7a`:** 127 task rows and 193 events (40 complete,
5 in_progress, 82 pending); `scripts/boardctl validate` prints `RESULT: OK (3 warning(s))` — CF-034's
two free-form fields plus the headerless board, down from 54 because CF-129 relanded canon keys;
`tests/selftest.sh` prints `SELFTEST: PASS` with 92 `PASS` rows and `PASS 127/127 rows parse` at
loadavg 15.60. CF-154 and CF-155 own the structural fix for this block.
Nineteen `  FAIL` lines are printed *inside* the suite by fixtures that assert a rejection (§16's
pre-fix manifest, the disk-floor refusal, the census fail-closed arms, …), so count `SELFTEST:` and
the suite's counter, never a raw `grep -c '^  FAIL'`. Timing is not a portable number: 9.32 s CPU
(`user 5.44` + `sys 3.88`) at loadavg 13.24, `real 10.86` — quote CPU and the load regime, not wall.
Previous snapshots (`f49d85b`: 29 sections, 88 `PASS`, 114/162, `OK (46 warning(s))`; `80fca8b`:
28 sections, 70 `PASS`, 85/115, `OK (28 warning(s))`; `400a5ab`: 15 sections, 68 task rows, 74 events)
still reproduce at the tips they name and are kept only as history: the count moved because §7b
(`CF-088`, the board gate rejects invalid records) and §29 (`CF-114`, a workdir board that is not the
published board) landed after the `80fca8b` measurement, and the board itself gained three rows and
nine events between `f49d85b` and `d02916e` (`CF-141` filed by the previous PM tick, `CF-142`,
`CF-143`) while no selftest arm changed (`git log --oneline f49d85b..d02916e -- tests/selftest.sh` is
empty).
No number in this file is carried forward without re-running the command that produced it.
The selftest checks shell syntax, one failing node-check path, `fetch_verified` digest
acceptance/rejection, a credential-assignment grep, JSONL parsing, lane-target parsing,
disk-floor resolution and refusal, the node-create staged set, auth fail-closed behaviour with a
pre-fix control, repo-url root/agreement guards, reclaim-before-refusal, and the README census
fail-closed arms. It does not exercise node creation, idempotence, the no-root rule, harness
parity, credentials lifecycle, the manifest schema, destruction/recreation, scheduler dispatch, or
the control-host artifact round trip — those cells say **no test** on purpose.

**Sections with no requirement (the reverse direction).** A section serves a requirement only if that
requirement's `Verified by` cell above names it. Twelve of the 39 arms are named: §2, §3, §4, §4b, §5,
§6, §12, §13, §14, §15, §16 and §20. The mechanical sweep over the whole document,
`grep -oE '§[0-9]+[a-z]?' docs/PRD-code-factory.md | sort -u`, returns **14** ids rather than 12: it
also catches §17 and §18, which are named only in the milestone block, where they certify `CF-077`
(a board row, not a `CF-101`–`CF-112` requirement) — so they count as unnamed for this total and
carry their own row below. The remaining 27 — §1, §7, §7b, §7c, §8,
§9, §10, §11, §17, §18, §19, §21, §22–§27, §28, §29, §30, §31, §32, §33, §34, §35 and §36 — test repository and
fleet tooling (board parsing and the board gate, prompt inventory, lane targets, repo-url guards, the
census and README arms), not a CF-101–CF-112 requirement, and each is governed by the board row it
names: §7b `CF-088`, §19 `CF-085`, §21 `CF-091`, §29 `CF-114`, §31 `CF-127`, §30 `CF-093`, §32
`CF-145`, §33 `CF-119`, §34 `CF-163` AC3, §35 `CF-153`, §36 `CF-159`, §7c `CF-155`, §17–§18 `CF-077`. Some of these overlap a requirement's subject without
deciding it (§10 exercises the Hermes adapter's Python refusal, which is CF-106 evidence but not the
two-adapter contract CF-106 demands); the cell stays the authority, so the overlap is recorded here
rather than promoted into it. A section that is neither named by a `Verified by` cell nor by a board
row is untracked test surface: give it one or delete it.

## Requirement-to-test matrix

Status definitions: **PASS** = requirement's acceptance behavior was exercised and evidence recorded; **PARTIAL** = relevant code or a narrower test exists, but required behavior is not fully demonstrated; **BLOCKED** = required dependency/environment or implementation prevents acceptance; **NOT RUN** = no relevant execution/evidence in this snapshot. Statuses are conservative and apply to acceptance, not presence of code.

| ID | Requirement (PRD) | State / current evidence | Falsifiable acceptance command and required evidence | Dependencies / gate |
|---|---|---|---|---|
| CF-101 | A node is created by one command from a project + repo + harness triple. | **NOT RUN.** `scripts/node-create.sh` implements a control-host flow, but no live creation was executed. | On a disposable authorized bunker: `CRIER_URL=http://crier.example:8767 BUNKER_SERVER="$BUNKER_SERVER" scripts/node-create.sh --project crier --repo <accessible-repo-url> --harness hermes --agent cf-accept-101`; require exit 0, `NODE CREATED`, and read back the node's `~/.node/node.json` via `bunker exec --server "$BUNKER_SERVER" cf-accept-101 -- cat ~/.node/node.json`. Record command output, exit code, and manifest. | bunker CLI/server, reachable repo and crier, credentials bundle, available user-space dependencies. No private URL or credential belongs in this tracked plan. |
| CF-102 | Every layer reports `PASS`/`FAIL` with the value it measured. | **PARTIAL.** `tests/selftest.sh` checks the empty-PATH `project-node.sh --check` failure and `FAIL` text; `lib.sh` supplies PASS/FAIL helpers. No full layer-by-layer measurement/failure matrix was run. | `tests/selftest.sh`; additionally `env -i PATH=/nonexistent HOME="$HOME" NODE_PROJECT=cf-accept-102 /bin/bash scripts/project-node.sh --check` (require nonzero and named `FAIL` rows). Capture successful and failed layer outputs and verify every PASS/FAIL includes a measured value. Add per-layer fail fixtures before claiming full PASS. | Selftest plus controlled fixtures for preflight, base, harness, bus, and repo layers. |
| CF-103 | Creation is idempotent; a second run changes nothing. | **NOT RUN — no test exists.** `project-node.sh` writes a timestamped manifest; there is no two-run comparison anywhere in `tests/`, and no script emits the `unchanged` per-layer line the PRD used to name (`grep -rn unchanged scripts/` returns two comments only). The PRD cell now requires the byte-identical `$HOME` comparison instead. | In an isolated test HOME with fixed inputs, run the apply command twice; compare `find "$HOME/.node" "$HOME/repo" -type f -exec sha256sum {} +` before/after second run, and assert second-run exit 0 with an identical digest set. Any content/timestamp change fails. | Disposable node/HOME, deterministic repo/ref, harness install and bus setup. Resolve whether timestamp rewrite violates the no-change criterion before acceptance. |
| CF-104 | No root, no apt: all artifacts user-space under `$HOME`. | **NOT RUN — and unfalsifiable as shipped.** No ladder execution as a node uid is recorded, and no gate can fail on a root/apt call: `grep -rniE 'sudo|apt-get' tests/selftest.sh` returns 0 hits. | Run the complete supported install ladder as the agent uid, then inspect the transcript and resulting paths: `id -u`; `scripts/project-node.sh --apply --project cf-accept-104 --harness hermes --repo <accessible-repo-url> --ref <pinned-ref>` inside the node. Fail on uid 0, any `sudo`/`apt` invocation, or artifacts installed outside permitted user-space locations. Record command trace and `find "$HOME"` evidence for installed artifacts. | Non-root agent account, installable target host, pinned ref and relevant dependencies. |
| CF-105 | Downloads are pinned and digest-checked before use. | **PARTIAL.** `tests/selftest.sh` exercised `fetch_verified` with a local file: correct digest accepted and wrong digest rejected; no production download/pin provenance was audited dynamically. | `tests/selftest.sh`; for the installation path, run its pinned-download fixture with a deliberately wrong SHA-256 and require nonzero, `digest mismatch`, and no destination file. For each real installer download, record URL/version, expected digest source, computed digest, and prove verification precedes execution/use. | Controlled local fixture plus audit of each installer download and its pin source. |
| CF-106 | The harness is a parameter, not an assumption; Hermes and opencode produce the same node contract. | **PARTIAL.** Both adapter scripts exist; `specs/HARNESS.md` marks opencode unverified and its `--apply` intentionally refuses. No equivalent node-contract comparison was run. | In separate disposable nodes, create via `--harness hermes` and `--harness opencode`; compare normalized manifests and required node contract fields, then run each adapter's unattended directive/invoke/report/failure/idempotence checks. Until opencode is measured and its `--apply` succeeds under the documented contract, CF-106 fails. Preserve both outputs and normalized comparison. | Hermes and opencode measured install ladders, provider/runtime configuration, compatible manifest contract. Current opencode refusal is a release blocker for the two-harness acceptance criterion. |
| CF-107 | A node proves itself with a round trip whose artifact digest is recomputed on the control host. | **NOT RUN.** `scripts/verify-node.sh` contains optional `--artifact` remote/local hash comparison, but no round trip or artifact was verified. | Produce an artifact on the node, then run `scripts/verify-node.sh --agent cf-accept-107 --server "$BUNKER_SERVER" --port "$PORT" --artifact <node-path>`; independently copy the pulled bytes and run `sha256sum` on control host. Require matching full digests and exit 0. Mutate one byte and require verification failure. Save node/control hashes, transfer output and command exit codes. | Live node reachable from control host; bunker transfer; running authenticated gateway; generated artifact. |
| CF-108 | Credentials arrive as one bundle, mode 600, never as an argument; deleted after use. | **NOT RUN.** Selftest's literal-assignment grep is not an argv/log leak test and does not validate bundle mode or deletion. | In a disposable node, stage a synthetic non-secret bundle and run provisioning with process-argument capture (`ps`/`/proc` while provisioning), then inspect logs and shell history. Assert exactly one bundle input, mode `600` (`stat -c '%a' <bundle>`), no credential value in argv/logs, and `test ! -e <bundle>` after provisioning. Store only redacted evidence and file metadata, never bundle contents. | Bundle staging/consumer path, isolated disposable identity, safe synthetic test credential. |
| CF-109 | A node refuses work below a measured disk floor, naming the number. | **PARTIAL.** `lib.sh:34-44` implements measured free-space comparison and refusal. Current selftest has no disk-floor boundary fixture. | Add/run deterministic boundary fixtures against `require_disk`: free space just below floor must return nonzero and print actual free and floor values; at/above floor must pass. Then `tests/selftest.sh`. Retain both outputs and exit codes. | Controllable `df` fixture or injectable free-space source; avoid filling a real disk. |
| CF-110 | Destroying a node and re-running creation reproduces it with no manual step. | **BLOCKED.** `node-create.sh` provisions/reuses an agent; no destroy-and-recreate path or evidence is present in the inspected flow. | After a defined destroy operation exists, run `destroy cf-accept-110`, then `CRIER_URL=http://crier.example:8767 scripts/node-create.sh --project crier --repo <accessible-repo-url> --harness hermes --agent cf-accept-110`, followed by `scripts/verify-node.sh --agent cf-accept-110 --server "$BUNKER_SERVER" --port "$PORT" --artifact <node-path>`. Require no manual intervention and compare required manifest/round-trip evidence. | Documented, authorized destroy operation and automatic reprovisioning lifecycle. Current scripts do not establish this acceptance gate. |
| CF-111 | Manifest records project, repo, ref, harness, gateway port, node id, created-by. | **PARTIAL — schema gap closed in the PRD, no test in the tree.** `project-node.sh` writes several fields, but no schema assertion was run. The PRD listed seven fields while `specs/NODE.md` requires ten (`repo.path`, `harness.version`, `bus.agent_id`, `bus.base`, `created_at` included); the spec is the design authority (`AGENTS.md` rule 1), so the PRD cell now names the same ten. Nothing asserts them: `grep -rln node.json tests/` = 0 hits, and the writer currently omits two (CF-078). | After successful apply, validate the manifest: parse `$HOME/.node/node.json` and assert `node_id`, `project`, `repo.origin`, `repo.ref`, `repo.path`, `harness.name`, `harness.version`, `harness.port`, `bus.agent_id`, `bus.base`, `created_by`, `created_at` exist with expected types; missing/incorrect fields fail. Record sanitized manifest and validator output. | Successfully provisioned node; PRD and NODE spec now agree on the field set. |
| CF-112 | Scheduler targets a node by lane; removing the target returns the lane to local path with no code change. | **BLOCKED — the named artifact does not ship.** PRD calls for `dispatch-targets.jsonl` plus two ticks, but `grep -rl dispatch-targets scripts tests` returns 0 hits: no script reads or writes that file, and no scheduler implementation or live tick evidence was found in this repo. | In an authorized integrated scheduler environment, add a lane target in `dispatch-targets.jsonl`, run one real tick and prove the directive reaches the named node; remove that target, run a second real tick, and prove the lane returns to local execution without code/config changes other than target removal. Preserve both tick IDs, routing evidence, and resulting artifacts; both paths must pass their gate. | Scheduler/target configuration, crier delivery, eligible node, local fallback, two observable real ticks. External integration gate; do not infer from config parsing alone. |

### The other direction: test sections with no PRD requirement

A green suite is not PRD coverage, and the reverse gap matters as much as the forward one. At
`d02916e`, `tests/selftest.sh` has 29 numbered sections plus two lettered sub-arms (§4b, §7b) —
31 arms, 88 `PASS` rows — and only three requirements have an arm that can fail on them (`CF-102` ←
§2 and §14, `CF-105` ← §5, `CF-109` ← §12 and §13 partially, plus `CF-127` ← §31 as of the CF-127
landing). Every other arm is governed by a spec, a
rule or a board row, and the mapping below names every numbered section in the current tree — 36, plus three lettered arms, so 39 arms, and 31 arms at the `d02916e` tip — so that a new arm cannot arrive without a
named authority. The mapping is a promise this table keeps, not one the tooling enforces: the
section census in `docs/audits/cf099-prd-drift-probe.sh` counts only numbered lines, so a lettered arm
lands uncounted (`CF-113`, pending, owns that fix).

| Selftest section | What governs it instead of a PRD requirement |
|---|---|
| §1 every script parses | `AGENTS.md` conventions (`bash -n` clean) |
| §2 the node checker fails on an empty PATH | `CF-102` (this one *is* a requirement arm) + board `CF-005` AC2 (a `FAILED: unbound variable` crash is not a `FAIL` row) |
| §3 unreachable crier, one status code | `specs/NODE.md` layer 00 row shape (`--layers 00`, exactly one `FAIL reach:` row) |
| §4 / §4b clone-error classification | `specs/NODE.md` layer 40 failure semantics (board `CF-034`, `CF-039`) |
| §5 `fetch_verified` refuses a wrong digest | `CF-105` (this one *is* a requirement arm) |
| §6 no literal credential assignments | `AGENTS.md` rule 8 — a tree-hygiene grep, **not** the `CF-108` bundle life cycle |
| §7 the board is valid JSONL | `docs/BOARD.md` write rules |
| §7b the board gate rejects invalid records with line-numbered FAIL rows | board `CF-088` (the gate must be able to fail on a non-object, duplicate id or bad status) |
| §8 boardctl fails closed without its dependency | `docs/BOARD.md` entrypoint contract |
| §9 every prompt the README names exists | README lane tables / the family loaders |
| §10 Hermes refuses an unsupported Python | `specs/HARNESS.md` install obligation (adapter contract, not harness parity) |
| §11 lane workdir targets parse and verify | `specs/NODE.md` workdir targets — parsing only, not `CF-112` dispatch |
| §12 node disk floor resolves from CLI/env/config | `CF-109` (requirement arm — resolution only) |
| §13 provisioning names its floor and refuses below it | `CF-109` (requirement arm — malformed-value refusal; the below-floor boundary is still untested) |
| §14 harness-adapter FAIL rows counted in the summary | board `CF-055` + `CF-102`'s `NODE: FAIL (n)` equality |
| §15 the README status re-run line carries the exit status | documentation honesty, board `CF-054` (`--layers 30,40`) |
| §16 node-create staged set covers the disk floor | board `CF-075` (staged entry point, disk admission, cleanup ownership) |
| §17 auth verification fails closed, pre-fix control | board `CF-077` AC1/AC2 |
| §18 node creation requires both auth legs | board `CF-077` AC3 (`NODE CREATED` only after every auth leg passes) |
| §19 project repo_url must name a real git root | board `CF-085` |
| §20 reclaim runs before disk refusal, check never reaps | board `CF-007` AC3 + `specs/NODE.md` disk floor |
| §21 satellite repo_urls must agree with their primary | board `CF-091` |
| §22–§28 census fail-closed arms and README/mirror parity | board `CF-089` (fetch/HTTP/schema/short-count/missing-total arms, healthy output, README↔mirror byte parity apart from `BASE`) |
| §29 a workdir board that is not the published board is named as drift | board `CF-114` (a stale workdir copy silently reopened five closures; the arm prints `DRIFT` naming both boards) |
| §30 README Status rows 1 and 3 cite the interpreter-qualified `--check` | board `CF-093` (a renamed Status row must be re-bound, not silently dropped; the unqualified command stops at `FAIL python`) |
| §31 Hermes pip logs are private per run and distinguish filesystem failures | board `CF-127` (a fixed `/tmp/hermes-install.log` blocked the second node on a shared-`/tmp` host and reported the redirection failure as `pip failed`) |
| §32 the Quick start control-host commands name `BUNKER_SERVER` in a check row | board `CF-145` (README's fresh-host promise was false for two of three commands; the arm pins the env name in the check row) |
| §33 the board-lock adjudicator proves a holder before calling a lock held | board `CF-119` (a 0-byte `.lock` with no consumer and no holder stood every lane down; the arm demands a proven holder) |
| §34 a posture doc's gitleaks claim names its scan scope | board `CF-163` AC3 + `scripts/check_scan_scope.py` (a main-scoped scan reads green while the published `master` lineage carried 547 findings in 64 commits, so the claim must name its `--log-opts`) |
| §35 node-create accepts and forwards `--ref` | board `CF-153` (README step 3 passes a ref; before `a112726` the flag reached no staged command — the arm runs `node-create.sh --staged-files --ref master` and requires exit 0, a byte-identical five-file staged set and no `unknown arg:` row) |

These sections are legitimate and must not be deleted to "clean up" the mapping: they serve
`AGENTS.md` rules, the specs and this board. They must not be counted as acceptance of
`CF-101`–`CF-112` either. Folding them into a requirement that does not exercise them (calling the
§6 grep "the CF-108 test", or §11 "the CF-112 test") is the same anti-gaming failure the
[anti-gaming criterion](#acceptance-gates-and-completion-bars) already forbids. `CF-083` tracks the
missing arms for `CF-101`, `CF-103`, `CF-104`, `CF-106`, `CF-107`, `CF-108`, `CF-110`, `CF-111`
and `CF-112`.

## Exact local checks and evidence commands

Run from the repository root. These commands are safe local checks; none provisions a remote node:

```bash
tests/selftest.sh
bash -n scripts/*.sh scripts/harness/*.sh tests/*.sh
```

The first command was executed for this snapshot and returned exit 0 with `SELFTEST: PASS`. The second is listed as a reproducible independent syntax check and was not run separately. `tests/selftest.sh` already performs shell parsing; retain its transcript as evidence. A useful evidence bundle for each execution is the exact command, UTC timestamp, exit code, stdout/stderr, relevant sanitized artifacts, and the commit/worktree revision. Do not attach secrets or private endpoints.

Remote acceptance commands in the matrix are templates: substitute only authorized, accessible test values in the operator's environment. Do not commit substituted values or evidence containing credentials. Remote/live checks are **NOT RUN** in this plan's snapshot.

## Dependencies and execution order

1. **Local baseline:** run `tests/selftest.sh` and preserve output. Repair any failures before interpreting higher-level results.
2. **Contract/schema alignment:** reconcile PRD's manifest fields with `specs/NODE.md`; specify harness version and bus identity fields and decide what “unchanged per layer” means for timestamps. Add deterministic fixtures for disk-floor boundaries and idempotence.
3. **Node prerequisites:** authorized bunker server/CLI, non-root agent account, reachable crier and package sources, pinned accessible repo/ref, adequate disk/memory, and a documented credential bundle workflow. Never put real secrets in test arguments/logs.
4. **Harness gate:** measure Hermes and opencode independently against `specs/HARNESS.md` before claiming CF-106. Unsupported/unmeasured adapters remain explicitly blocked rather than silently skipped.
5. **Round-trip gate:** a live node must execute a real directive, produce a real artifact, and have its bytes pulled and hashed independently by the control host (CF-107). A successful status endpoint or node-reported hash alone is insufficient.
6. **Lifecycle/integration gates:** prove destroy/recreate (CF-110), then prove target-on and target-removed fallback on two real scheduler ticks (CF-112). These require external components and cannot be replaced by unit tests or config inspection.

## Acceptance gates and completion bars

- **Local test gate:** `tests/selftest.sh` exits 0; required failure fixtures demonstrably reject bad inputs. Preserve the full transcript. A green command is necessary, not sufficient.
- **Per-requirement gate:** CF-101–CF-111 must each have a recorded acceptance result, exact command, exit status, and evidence described in the matrix. CF-112 additionally requires both live ticks. No “not applicable” or skipped row may be counted as PASS.
- **Node gate:** all required NODE layers pass with measured values; a manifest is emitted only after passing checks; no root/apt; credential bundle lifecycle is proven; disk-floor negative boundary is proven; repeated apply is unchanged.
- **End-to-end first-milestone gate:** one crier directive is observed arriving over crier at a Hermes gateway; a commit is produced; an artifact digest is recomputed from pulled bytes on control host and matches; deliberately failing the gate yields a recorded nonzero/FAIL result. This is the PRD's explicit first-milestone acceptance, not implied by per-script checks.
- **No self-certification:** node-reported status, version, manifest, and digest are claims to verify, not acceptance evidence by themselves. Control-host observations and recomputation decide.
- **Anti-gaming criterion:** acceptance must fail if any check is weakened to unconditional success, its negative fixture is removed/skipped, a failure is converted into a warning or text-only “success,” the artifact bytes are not independently pulled and hashed, a mocked/local-only round trip is presented as live, or a required external tick/harness/lifecycle test is substituted by source inspection. As a mutation check, force the relevant checker to return success on a known-bad fixture (wrong digest, below-floor disk, absent dependency, failed gate) and verify the test suite itself turns red. A test that still passes after this mutation does not count as evidence.

## Current acceptance summary

Measured at `d02916e` (2026-11-04 02:35): the local self-test passes (88 `PASS`, suite counter 0,
rc 0), and acceptance is **incomplete**. Split by what the tree can actually demonstrate:

- **Requirements with a test that can fail on them (3):** `CF-102` (§2, §14 — and the per-layer arms
  named in the PRD cell), `CF-105` (§5), `CF-109` (§12, §13 — resolution and malformed-value
  refusal only; the below-floor boundary arm is still missing).
- **Requirements with no test in the tree (9):** `CF-101`, `CF-103`, `CF-104`, `CF-106`, `CF-107`,
  `CF-108`, `CF-110`, `CF-111`, `CF-112`. Re-verified at `d02916e` by grep, not by argument:
  `grep -rniE 'sudo|apt-get' tests/` = 0 (CF-104), `grep -rln 'node\.json' tests/` = 0 (CF-111),
  `grep -rl 'dispatch-targets' scripts tests` = 0 (CF-112), no artifact-digest arm (CF-107), no
  two-run digest comparison (CF-103), and `chmod 600` appears only as fixture setup, never as a
  credential-bundle assertion (CF-108). `CF-083` tracks the arms to add.
- **Requirements that cannot pass until code that does not ship lands (3 of the nine):** `CF-110`
  (no destroy path exists), `CF-112` (no `dispatch-targets.jsonl` consumer exists), `CF-106`
  (`opencode` is unmeasured and its `--apply` refuses by design).
- **End-to-end first milestone:** not met. Of the defects the previous summary named, `CF-075` and
  `CF-077` are closed (`77caa02`, `1232f7a`, each with selftest arms §16–§18); the legs still blocked
  by an open defect are `CF-080` plus the never-exercised `CF-001`, `CF-004`, `CF-110` and `CF-112`,
  and since 2026-11-04 the PRD block also names `CF-002` (a node turn cannot start inference, so the
  commit leg is unreachable) and `CF-126` (a README-created node fails layer 00 on `CRIER_URL`, so the
  bus leg is unreachable) — both were open and absent from the milestone list before this tick.
  **Correction, 2026-11-04T04:14Z (sync lane, below `c2a6a45`):** the `CF-126` clause is stale as of
  the board. CF-126 reached `complete` at `2026-11-04T02:56:26Z` on commit `23c1c6d`
  (`85f852b` records the closure on verdict `dd7f64bc`; `git merge-base --is-ancestor 23c1c6d
  origin/main` exits 0), so that defect no longer blocks the bus leg. Whether the leg is now
  exercised end to end is not measured here. The `CF-002` clause still stands (`status: pending`).
  The snapshot above is left as measured at `d02916e` so the move is visible.
  One leg moved: a directive is now recorded arriving at a node and executing there (`CF-137`,
  `CF-138` live runs ending `exit 124` at a caller-derived 32.1 s kill; `CF-139` records the
  19:37:51 dispatch handing the node the envelope as its prompt). The milestone block in the PRD is
  the authority for that sentence — no commit produced on a node and no control-host artifact digest
  has been recorded, so the first-milestone gate stays open.
- **Correction, 2026-11-04T06:16Z (sync lane, below `1aeb0c7`; stamp corrected from `06:26Z` by the
  `06:11` PM tick, which measured the writing commit `55ef0ec` at `06:16:56Z` — the original stamp
  named a time nine minutes after the commit that carries it):** two statuses in the milestone
  bullet above have moved since its `04:14` correction. Both `CF-001` and `CF-002` read
  `status: in_progress` on the board at this tip — `CF-001` since `2026-11-04T05:54:41Z`, `CF-002`
  since `2026-11-04T05:35:55Z` — so the `pending` wording no longer holds for either. `CF-001` is
  therefore not "never-exercised" any more: `1aeb0c7` records the first scheduler-originated remote
  dispatch accepted by the relay at `00:53:34` (message `7f4bc40b`), after 82 consecutive `403`
  refusals, with AC6 and AC7 still open. `CF-002`'s parenthetical "a node turn cannot start
  inference, so the commit leg is unreachable" is superseded as a *blocker* by `3c78dd1`, which
  records a live probe on the node token (allowed model `200`, other model `403`, no model `400`,
  unknown token `401`, revoked sub-token `401` with no restart) and a completing turn (`hermes chat`
  -> `AC1-NODE-OK`). Neither row is `complete`, so the end-to-end commit leg is still **not**
  demonstrated here, and this correction claims no such thing.

No row above may be counted as PASS on the strength of the green self-test alone.
