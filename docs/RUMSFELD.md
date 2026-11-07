# RUMSFELD REGISTER — what we know, what we don't, and what we never asked

**Status: WORKING DOCUMENT — HISTORICAL SNAPSHOT, not VERIFIED, and not a current measurement.** It
records a four-quadrant audit run on 2026-11-05 **measured at tip `b446562`**
(`b446562e6717dab2ab91712ff188db9727649f79`; the census index it cites was corrected at `572e11b`), and
every entry names the evidence it rests on. The audit was **not re-run at the current HEAD**: unless a row
names a later tip in its own cell — the `tests/selftest.sh` census row does, at `388c7cb` — read every
figure here as a statement about `b446562` alone. The drift is large and cheap to check, which is why the
date stamp is not pedantry: `docs/master/`, the module set most of this register indexes, **does not exist
at `c068e87`** — the delivered documents are the `docs/handbook/` chapters plus the per-unit pages under
`docs/handbook/appendices/units/`, which is the fallback root `scripts/master_doc_check.py` resolves when
`docs/master` is absent; the census row's 56 arms read **61** at `c068e87`
(`bash docs/audits/cf198-section-mapping.sh` → `arms_plan=61 arms_tree=61`); `git ls-files '*.py' | wc -l`
returns 33 at `b446562` and **56** at `c068e87`; and `bash scripts/boardctl validate` reports **359 task
rows / 531 events** at `c068e87` against the 338 rows recorded in Q1(iii) below. Re-measuring this register
at HEAD is a separate piece of work, not a property this page claims.

The gate that would grade a document of this kind is **M6.S3** (`scripts/master_doc_check.py`, which selects
`[0-9][0-9]-*.md` under its resolved module root and so selects nothing here — this register sits outside
it); its subject, which repository gate ran and what that gate graded, is **M3.S3**.

It is not a module in the `docs/master` sense: it does not describe one file, and it is *supposed* to
contain open questions. When an item closes, it moves into a module with a measurement, and this file keeps
the line saying where it went.

The purpose is to shrink the list. A quadrant that does not say **what would settle this** is a note, not
a register entry.

---

## Why this exists

The 44 modules answer *what is this component and is the sentence true*. They do not answer three
questions the operator actually asks:

1. **What do we know for certain** (and what is that certainty resting on)?
2. **What do we not know, and can we settle it now, or only after we build something?**
3. **What have we never asked at all** — including things comparable systems settled years ago?

The third is the dangerous one: an unknown unknown is not a gap in the docs, it is a gap in the
*questions*. The only defence found so far is comparison — against the standards that govern this class
of system, and against systems that solve the same shape of problem.

---

## Q1 — KNOWN KNOWNS (40)

Every entry carries either a measurement run on the day of the audit or a module whose own §3 records the
command. **27 of the 40 were measured fresh**; the rest are carried from a VERIFIED module that names its
own measurement. The distinction matters: a carried fact is only as fresh as its module's date.

### (i) What the components are

| Fact | Weight |
|---|---|
| `board_lock.py` adjudicates `.coding-hermes/board/.lock`, not the board; one verdict line, exit 0 | mod 03, 89 locators |
| `.lock` is 0 bytes, mtime `2026-11-03 07:40:02`, ignored at `.gitignore:20`, no consumer opens it by that name | mod 03; `stat` reproduced byte-for-byte |
| crier verifies the per-agent ed25519 signature **before** it resolves the agent, so an unsigned read is 401 by design | FACT-03; ladder 401/401/401/200 on cf-node |
| the crier on `*:8767` here **is** the bus cf-node talks to (`/health -> 200`) | measured (`ss -ltnp`) |
| `disk_floor.py roles` → builder 10 / full 20 / worker 5 GiB; `resolve --explain` names its source | measured |
| `lane_target.py parse 'bunker://cf-node/home/x/repo'` → `{"kind":"remote","scheme":"bunker",…}` | measured |
| the conformance battery has **exactly three** legs (`leg_apply leg_check leg_smoke`) against a spec demanding five | measured; mod 38 FAILING for this reason |
| `specs/ENVELOPE.md`: 23 of 24 defined fields disagree with at least one implementation | mod 37 |
| `specs/TRACE.md`: five unacked replies carried `in_reply_to`, none carried `corr_id` — 4 of 7 hops broken | mod 42 |
| `node-bus-worker.py --check` on cf-node: 9/9 PASS, `BUS WORKER: READY`, identity at 0o600, signed `inbox/stats -> 200` | measured on the node |
| `tick_dispatch`: 86 rows — 3 replied, 82 failed, 1 expired; 95 % failure, last activity 2026-11-04T23:38Z | measured |
| `master_doc_check.py` → 44 modules, 37 VERIFIED, 0 errors, PASS | measured today |
| `install-opencode.sh` is check-only by design: no download, pin or digest | mod 18 RED / CF-240 |
| `github-app-token.py`: 24 checks against a stub; **no live credential has ever been minted** | mod 14 |
| `land-node-branch.sh` 20/20 on a scratch bare origin; `clone_lane.py` 22 cases; `reclaim_disk.py` roots enumerated from source | mods 20 / 09 / 34 |

### (ii) Environment

| Fact | Weight |
|---|---|
| host: 16 CPU, 59 GiB RAM, `/` 1.8 T with **294 G free (84 % used)** | measured |
| control host Python **3.14.9**; cf-node **3.13.5** — and the hermes adapter FAILs here on `>=3.11,<3.14` | measured; constraint violated on the control host, satisfied on the node |
| listening: `schedulerd` 127.0.0.1:9090, `crier` *:8767, `hermes` :8642/:8643, `chimera` :8765, `off-by-one` :8766 | measured |
| `scripts/` 42 files / 13,944 lines; `docs/` 165 / 27,835; `specs/` 7 / 949; `tests/` 7 / 5,507; `docs/master` 44 modules | measured at `b446562`; **not re-derived** — at `c068e87` the same tracked-file method (`git ls-files <dir> \| xargs wc -l`) returns scripts 63 / 20,409, docs 215 / 40,656, specs 7 / 1,177, tests 15 / 10,696, and `docs/master` no longer exists (see the header note) |
| `tests/selftest.sh` 4,687 lines, **53 numbered sections + 3 lettered (§4b §7b §31b) = 56 arms**, 380 `PASS` rows (`grep -c '^  PASS'` over a clean-worktree run at `388c7cb`) | measured 2026-11-06; see "Rejected findings" |
| cf-node running, 835 MB used, no public URL; the network boundary is explicitly **not verified** | measured |
| GitReins armed: `config.yaml`, `tasks.yaml`, `worktrees.json`, `usage.jsonl`, `logs` all present | measured |

### (iii) Fleet behaviour

| Fact | Weight |
|---|---|
| board 338 rows (68 complete / 14 in_progress / 254 pending, +CF-363/364 filed this audit); 68/68 complete rows carry a commit hash | measured |
| **12 rows carry a `PREMISE DISPROVED` note** (CF-001, 049, 131, 132, 136, 137, 138, 139, 204, 248, 334, 344) | measured — the board has falsified itself twelve times |
| 8 of 254 pending rows carry `capability_tags`; 188 acceptance criteria contain a measurement verb | measured |
| `scheduler.db`: 101,574 ticks lifetime, 772 with `unservable-rating`; code-factory family 1,964 ticks (1,361 completed / 593 failed) | measured |
| today: 24 code-factory failures — 19 `unservable-rating`, 3 gateway 429, 1 gateway 502, 1 `hook_failed` | measured |
| conformance battery: 21 rows — 5 PASS / 7 FAIL / 9 SKIP | mod 38 §8 |
| `docs/master` carries 16 lines / 25 `UNKNOWN` tokens (mods 25 and 40); `specs/` carries **zero** — the specs' holes are unmarked | measured |
| `scripts/harness_resolve.py` **does not exist**; matrix invariant I2 has no implementation | measured (`ls` fails) |
| five scripts have no module (`master_doc_fill/panel/check.py`, `install-go.sh`, `extract_owner_decisions.py`); `docs/` holds 118 non-master files with 0 modules | measured |

### (iv) Owner decisions (each `told-by-operator`, not measured)

| Decision | Where |
|---|---|
| the foreman runs on the project's bunker; **some projects still run on the control host** | FACT-01 |
| one bunker serves one project; every lane of that project enters it | FACT-02 |
| credentials travel as **file paths at mode 600**, never argv | FACT-05; enforced after a seat found a token in curl argv (`69f2168`) |
| this project's lanes are **xkiro and DeepSeek PAYG only** — no Ollama spend | FACT-06 |
| **deepseek-v4-flash over v4-pro** for this project's writing | FACT-07; consistent with the live `fleet.toml` pin |

---

## Q2 — KNOWN UNKNOWNS (18), bucketed by **when** they can be answered

The bucket is the whole point: an unknown that needs a build is not a reason to stop, and an unknown
answerable by one command is not a reason to plan.

### Bucket 1 — answerable NOW with a command (7)

| # | Question | Probe | Falsifier |
|---|---|---|---|
| K1 | does the **deployed** bus consume a real dispatch through `--once`? | compose one dispatch for `code-factory`, `bunker exec cf-node … --once`, re-read `inbox/stats` | `--once` exits 0 with queue depth unchanged, or the reply 401s → the local round trip does not transfer |
| K2 | do the 12 premise-disproved rows still need work? | run each row's own acceptance command against HEAD | any acceptance criterion passes unmodified → the row is board debt, not engineering work |
| K3 | is `selftest.sh` green on this tree **right now**? | `bash tests/selftest.sh` | any FAIL arm → "gates every commit" is false today |
| K4 | which census number is authoritative? | run the census emitter and diff against `master_doc_check.py` | it reproduces the stale figure → the modules are the stale side, not the index |
| K5 | are the 188 measurement-shaped acceptance criteria runnable **as written**? | extract each command, dry-run `--help`/parse only | >20 % name a missing binary or path → the board is not dispatchable in the form the dispatcher reads |
| K6 | is the disk floor enforced at admission or only reported? | compare `disk_floor.py resolve` with scheduler admission strings; hunt a tick admitted below floor | one admitted tick on a host below its floor → the floor is advisory, and this 84 %-full host is unguarded |
| K7 | does anything actually **invoke** the doc gate? | `grep -rn master_doc_check` over `tests/`, `scripts/`, `.coding-hermes/`, `AGENTS.md` | zero hits outside its own module → it passes because nobody runs it (this is exactly how the index drifted) |

### Bucket 2 — answerable only AFTER something is built or deployed (7)

| # | Question | Needs | Falsifier |
|---|---|---|---|
| K8 | does harness resolution exist and record **why** it chose? | `scripts/harness_resolve.py` (absent today) | it resolves a foreman lane to a non-hermes harness, or emits a fallback with no reason |
| K9 | is "supported" five green legs or three? | the `memory` and `harness_unsupported` legs | five green legs while DuckBrain records written stay 0 → I3 still unproven |
| K10 | does a run become **searchable** fleet memory? | R1/R2 writers (none exist) | recall returns 0 records after a completed run |
| K11 | does `run_id` survive all seven hops? | scheduler + crier emitting it | two attempts share one `run_id`, or any hop drops it |
| K12 | can any harness export the I3 provenance set? | adapters (zero exist; six harnesses researched) | an adapter reports `model_served` it cannot observe — dsh structurally cannot |
| K13 | does the opencode `non_interactive` row go RED when the capability disappears? | the `2>&1` fix | the row stays GREEN when the flag is gone |
| K14 | do the smoke legs prove a turn happened, or only that a binary exists? | claude-code + codex installed on a node | a smoke row PASSes with no artifact digest (`codex:smoke` already: exit 124, no `smoke.txt`) |

### Bucket 3 — blocked on a ruling or an external change (4)

| # | Question | Blocked on | Falsifier |
|---|---|---|---|
| K15 | which projects still run on the control host? | the owner naming the exception set, or an authorised fleet census | every enabled project resolves to a bunker → FACT-01 is historical, not current |
| K16 | DuckBrain for nodes: central-over-Tailscale with a roster, or per-project instance? | CF-208 **and** a DuckBrain change (a token scoped to ns A currently reads ns B) | token scoped to A reads B → central mode is unsafe until scoping is enforced |
| K17 | is the harness contract five legs or three? | the owner: fund two legs, or amend I4 | a ruling that three is the contract → mod 38 flips to VERIFIED and no code is owed |
| K18 | are the 254 pending rows real work or board inflation? | a dedupe policy ruling (CF-363) | >30 % of a 10-row P1 sample already passes on HEAD → dispatching them is the fleet's dominant waste |

---

## Q3 — UNKNOWN KNOWNS (24): practices we already have and never wrote down

Each was learned by doing, verified against a transcript, and has a document that *should* hold it. The
cost column is a measured failure, not a hypothetical. 20 of the 24 have one.

### The commit gate — the highest-cost cluster

| # | Practice | Should live in | Cost when missed |
|---|---|---|---|
| 1 | a passing guard can still discard the commit: it exits **2** and git creates nothing — read the exit code, never the green print | `docs/QUALITY-GATE.md` (does not exist) | CF-031: every docs/board-only commit refused while printing green |
| 2 | the lint lane's scope comes from **staged extensions**, not `lint_command`; `allow_skips: false` refuses every non-Python commit | `docs/master/19-…` §7 (names no `allow_skips`) | CF-031; fix is `allow_skips: true` + disclosure in the body |
| 3 | budgets must nest: `hook_timeout` > `test_timeout` > suite runtime, and the tool's timeout above both | `docs/ACCEPTANCE-PLAN.md` (gives the command, never the budget) | CF-217: a cut-off hook reports a fail-open PASS; a cut-off tool leaves no commit |
| 4 | when bypassing, bypass **by mechanism** (`--no-verify` or `core.hooksPath=/dev/null`) and paste the verdict into the body | `docs/QUALITY-GATE.md`; `LOOP-CODEX.md:79` names one mechanism only | 11 logs carry `--no-verify`; silent bypass is indistinguishable from green |
| 5 | prove the commit exists after every commit: `git rev-parse HEAD` + `git show --name-only`, always `-m`/`-F` | `AGENTS.md` §Conventions | one lost commit and a rewritten SHA in a single task |
| 6 | never run two gate runs on one host — fixtures bind literal ports and fixed `/tmp` paths | `docs/ACCEPTANCE-PLAN.md` | CF-123: an all-red run with no code defect, and 7 false passes in the same batch |

### Where to measure

| # | Practice | Should live in | Cost when missed |
|---|---|---|---|
| 7 | a stub HTTP layer cannot show SQLite locking — configure lanes against a real `schedulerd` on a **copied** DB | `docs/master/10-…` §8 | CF-356: a wrong "16 configured" reading was written down before the real run |
| 8 | a stub crier cannot prove a reply path — start a private crier, register both agents | `docs/master/25-…` §8 | the audience header and ed25519 transcript are server-enforced; a stub can only echo |
| 9 | measure the auth ladder as five rows before claiming a bus path | `docs/master/25-…` §4 | procedure (no failure recorded) |
| 10 | delete `crier*.db` + `-wal` + `-shm` between arms, or the next arm answers `409` | `docs/master/25-…` §8 | a 409 and a stale-policy reading |
| 11 | two crier binaries exist on this host — probes must call the repo-built one, not PATH | `docs/master/25/49` §7 | the `bunker` twin is already recorded as an example in `MASTER-DOC-SCHEMA.md:123` |
| 12 | a worktree's `tasks.jsonl` is frozen at its base — never count it | `docs/BOARD.md` | a ≥42-row undercount at one moment |
| 13 | measure the repo from a **fresh clone**; the `proj-wt-code-factory-*` family shares one git dir | `docs/ACCEPTANCE-PLAN.md` (narrative only today) | CF-049: four consecutive blocked releng ticks, no dispatch, no gate run |
| 14 | `install-hermes.sh --apply` silently skips its own auth gate when anything already listens on `:10800` | `docs/master/17-…` §7 | CF-192: a green adapter verdict on a gateway it never auth-checked |
| 15 | drive `--apply` arms with a PATH-local shim plus one throwaway HOME per arm | `docs/master/17-…` §8, `docs/HARNESS-CONFORMANCE.md` | CF-071: the unshimmed path launches `hermes serve --host 0.0.0.0` |
| 16 | redirect `HOME` to `$(mktemp -d)` before running anything that reads a config path | `docs/master/27-…` §7 | module 27's own table was derived by writing into the operator's real `~/.hermes` |
| 17 | prove `--check` is side-effect-free by hashing an empty HOME before and after, under `env -i` | `docs/MASTER-DOC-SCHEMA.md` §4 | the P1 that `project-node.sh --check` creates `$HOME/.node` |
| 18 | capture an exit code directly — in a `for` loop or a pipe the status is lost and a FAIL reads as a pass | `docs/HARNESS-CONFORMANCE.md` | one wrong reading inside a single task |

### Board mechanics and fixtures

| # | Practice | Should live in | Cost when missed |
|---|---|---|---|
| 19 | allocate the id with `boardctl next-id --family CF` immediately before `create`; a lost race is a retry, not a second row | `docs/BOARD.md` (no `next-id` today) | one row renumbered post-hoc; a duplicate event id already sits on the live board |
| 20 | `boardctl`'s flag surface is narrower than the docs imply (`--json` on `list`, not `show`); a shell without the fleet bin gets 127 | `docs/BOARD.md` §Write rules | a failed `show --json` batch and a hard 127 stop |
| 21 | after a hand edit, assert the board ends in a newline **and** the line count matches — a board truncated mid-record passes selftest | `docs/BOARD.md`, `AGENTS.md` | CF-048: a lost row invisible to the only board gate |
| 22 | read the scheduler DB only as `file:…?mode=ro&immutable=1` — a plain connect creates a 0-byte file; a held lock costs 60 s then `database is locked` | `docs/master/23-…` §7 | both failure modes reproduced |
| 23 | one stub process per failure mode on its own port with a per-arm log; kill with a bracket-escaped pattern (`pkill -f` matches itself) | `docs/ACCEPTANCE-PLAN.md` | cleanup killed its own shell (exit −15) |
| 24 | a harness stub must pin the exact argv and `exit 99` otherwise, or the arm scores green on the behaviour it exists to catch | `docs/HARNESS-CONFORMANCE.md`, `docs/master/17-…` §8 | a permissive stub makes the arm vacuous rather than red |
| 25 | test node-side scripts by copying them to the node under `bunker exec … bash -lc` — the node's HOME is not the worktree | `docs/master/36-…` §4, `docs/OPERATIONS.md` §6 | local `--check` PASSed while the node's identity set was incomplete |
| 26 | exercise each `--check` refusal under `env -i HOME=/tmp/…` — a missing identity file crashes with a traceback instead of naming the path | `AGENTS.md` rule 2 (the rule exists, the adversarial HOME does not) | a raw traceback where a named refusal was required |

**Structural gaps these point at, stated plainly:** the repo has **no document for the commit gate it runs on
every commit** (the four lessons live as comments in `.gitreins/config.yaml`), and `docs/MASTER-DOC-SCHEMA.md`
§4 demands a re-runnable command without saying how commands must be isolated (HOME, clone-vs-worktree,
one gate per host).

---

## Q4 — UNKNOWN UNKNOWNS (50)

Two lists, because they fail differently. The first is what **the standards governing this class of system**
require and we never asked for. The second is what **systems with our shape** document and we never copied.
Each item was checked against the repo by grep before being called absent.

### (a) Standards — artifacts we never considered (25 of 17 standards)

| # | Standard | Requirement | State |
|---|---|---|---|
| 1 | IEEE 828 | **Configuration index** — every item under control, with version and change history | ABSENT: a node's behaviour is eight separately-versioned inputs and no doc lists them |
| 2 | IEEE 828 | Configuration status accounting across the fleet | ABSENT: the manifest carries harness version + ref only |
| 3 | IEEE 828 | Change control over baselined specs | ABSENT: CF-164 — `b8a7e24` edited `specs/NODE.md` with no row |
| 4 | MIL-STD-498 SVD | Version description per release | ABSENT: no VERSION/CHANGELOG/tags (CF-161), so "rebuild exactly" is unfalsifiable |
| 5 | MIL-STD-498 SIP | Installation plan **incl. backout** | PARTIAL: prerequisites exist, no backout of a half-provisioned node |
| 6 | MIL-STD-498 SPS | As-built inventory | ABSENT |
| 7 | MIL-STD-498 STD/STR | Case→expected-result catalogue + per-run report bound to a commit | PARTIAL: 56 arms, no expected-result catalogue |
| 8 | IEEE 1012 | **Integrity levels** setting minimum V&V per item | ABSENT: a docs typo and the digest gate get identical scrutiny |
| 9 | IEEE 1012 | IV&V independence statement | PARTIAL: three models is technical diversity — same host, corpus, operator, incentive |
| 10 | IEEE 730 | Software quality assurance plan with nonconformance authority | ABSENT: a `-qa` lane with a cooldown floor and no charter |
| 11 | IEEE 1016 | Design viewpoints (state dynamics, algorithms) | PARTIAL: `DESIGN.md` is 103 lines, no dynamics view |
| 12 | ISO 15288 | Disposal record | PARTIAL: `--destroy --yes` guards the action, nothing records disposition |
| 13 | ISO 15288 | Information management / retention | ABSENT: `reclaim_disk.py` reaps job dirs at a 24 h default — the same dirs cited as evidence |
| 14 | NASA SWE-015 | Life-cycle cost model | ABSENT: 174 dead ticks burned spend invisibly |
| 15 | Google SRE | SLI/SLO + error-budget policy | ABSENT: the 174-tick outage was found by a human reading a log |
| 16 | Google SRE | Blameless postmortem | ABSENT: 86 phantom successes, no postmortem artifact |
| 17 | Google SRE | Alert→runbook→owner, on-call | PARTIAL: a good runbook with no alert pointing at it |
| 18 | Google SRE | Capacity plan | ABSENT (self-admitted: "5 GB is header room, not a capacity plan") |
| 19 | NIST SSDF RV.1/RV.2 | Vulnerability response + POA&M | ABSENT: five pinned third-party binaries per node, nothing would notice a CVE |
| 20 | NIST SSDF PS.3 | SBOM per node build | ABSENT: pins say what you asked for, not what got installed |
| 21 | SLSA | Provenance attestation + stated target level | PARTIAL: sha256 of a value that arrived over the same channel; the pip path bypasses `fetch_verified` |
| 22 | ADR practice | Architecture decision records | ABSENT: CF-343 — `max_concurrent` and the inference proxy are unrecorded, so both will be re-litigated |
| 23 | NASA SWE-125 | Requirements mapping matrix + tailoring | PARTIAL: 79 stated requirements have no classification/verification/evidence row |
| 24 | NASA 8739.8B / MIL-STD-882E | Hazard analysis with severity + safety-critical determination | PARTIAL: nine fail-closed rules, no hazard IDs for destroy, TTL-0 reaping, force-merge, identity re-pointing |
| 25 | STRIDE | Per-element sweep + attack trees | PARTIAL: abuse cases are a list, not an enumeration; module 25:343 — anything that can deliver to the inbox runs shell as the node user, and the brief digest covers `text` only |

### (b) Comparables — practices we never copied (25 items, 16 systems studied)

The pattern, stated up front: **we document steady state well and transitions almost not at all.** Delete,
drain, roll back, upgrade, expire — every lifecycle edge is thinner than the happy path.

| # | Model | Practice | Nearest thing we have |
|---|---|---|---|
| 1 | Kubernetes | **finalizers** — an object cannot disappear until its owners finish cleanup | `destroy()` is one `bunker destroy` call: no revocation of crier identity, namespace, tokens or keys |
| 2 | Kubernetes / Nomad | **cordon** — unschedulable without destruction | NONE; `docs/DESIGN.md` §5 says "no quarantine path exists — not measured" |
| 3 | Nomad | **drain with deadline** — new work refused, running work finishes | NONE; a killed client leaves the remote harness running (CF-204) and the row `in_progress` (CF-136) |
| 4 | Kubernetes | **status.conditions[] + observedGeneration** — machine-readable reason, and which revision was processed | row status + free-form detail; no reason enum, no generation, no record of which row revision a worker read |
| 5 | Kubernetes | **API deprecation policy** — removal only by version bump; supported windows stated | `env_version: 1` hard-coded in replies, no reader validates it, no refusal of an unknown version |
| 6 | Terraform | **saved plan** — `plan -out` is the artifact `apply` executes | `--check` writes nothing; check and apply can see different trees |
| 7 | Terraform | **import / state adoption** | reuse-by-name: nothing verifies the existing agent's repo/harness/identity before writing a manifest about it |
| 8 | Terraform | **dependency lock file** — one artifact pins every input and its checksum | scattered pins; no control-host artifact names a node's input set |
| 9 | Ansible | **idempotence proof (`changed=0`, `--check --diff`)** | the claim in prose; `grep -rn 'changed=' scripts/` → nothing |
| 10 | Nomad / ArgoCD | **job versions, golden tag, revert** | git history; no "which prompt version produced tick N", no unland path |
| 11 | Argo Rollouts | **canary with analysis before promotion** | NONE: a prompt change applies to every lane on its next tick — the fleet is the canary |
| 12 | Release eng | **change freeze window** | per-lane cooldowns only; nothing stops a merge to `tests/selftest.sh` or `lib.sh` mid-wave |
| 13 | Release eng | **rollback drill**, dated | prose recovery steps labelled BLOCKED / NOT YET; no dated rehearsal |
| 14 | Kubernetes / Terraform | **version compatibility matrix** | harness×platform only, plus an unenforced `env_version`; no N-2 window |
| 15 | GitHub Actions | **concurrency groups with declared cancel-vs-queue** | per-lane `max_concurrent` plus a queued tick that blocks its own project (CF-146); the loser is recorded nowhere |
| 16 | CI generally | **artifact retention / expiry** | none: `docs/audits/` grows monotonically while `reclaim_disk` deletes caches with no age gate (CF-290) |
| 17 | Google testing | **flaky-test quarantine** with owner and expiry | prose only ("count `SELFTEST:`, never `grep -c FAIL`"); no register |
| 18 | Buildkite / K8s | **agent lifecycle + heartbeat, NotReady detection** | liveness is operator-invoked; a dead node and a busy node look identical to the board |
| 19 | Bazel | **cache keyed by input digest** | a "shared cache" intent and a cache `reclaim_disk` deletes; no key contract — a stale hit is a silent false pass |
| 20 | Airflow / Dagster | **SLA / freshness policy** — deadlines as first-class events | cooldowns and weights only; a lane parked 42 h is noticed when a human reads the board |
| 21 | Airflow | **backfill + `run_type`** — missed periods recoverable, run kind recorded | ticks are "next row forward"; `backfill` appears zero times |
| 22 | Airflow | **retry rules by exception class** — transient retried, permanent fail-fast | transient 502/429 and permanent 401/403 count identically, which is backwards |
| 23 | Google SRE | **blameless postmortem with owners, dues, recurrence links** | rows with `reasoning`, no owner, no due, no recurrence: a chronic failure is permanently "new" |
| 24 | Incident practice | **severity taxonomy with response obligations** | P0–P5 with no service-level meaning: 14 P0s are indistinguishable from one |
| 25 | Kubernetes | **resource quotas / controller backpressure** | a disk floor and per-lane concurrency; no per-project ceiling, no load shedding — the gate is free, so nothing pushes back |

**12 of the 25 are adoptable in under a day each**: reason codes + generation, an input lock file, a
`changed=0` proof, a golden tag, a compat matrix, a concurrency policy flag, a retention rule, a flake
register, a heartbeat field, `run_type` on ticks, a retry classifier, and a postmortem template with
owner/due. The expensive five — finalizers, cordon, drain, import, canary — all need a second code path
that our provisioning model currently assumes never runs.

---

## The shrink plan

**Run now (one command each, no build):** K1 (deployed `--once`), K2 (re-run 12 disproved premises), K3
(selftest on HEAD), K4 (census authority), K6 (is the disk floor enforced?), K7 (does anything invoke the
doc gate?). K5 needs a static pass with `--help` dry-runs.

**Research before building (cheap, removes a decision):** K17 (five legs or three — an owner ruling, not a
measurement), K15 (which projects stay on the control host), K18 (dedupe policy for 254 pending rows).

**Only after a build:** K8, K9, K10, K11, K12, K13, K14 — the whole dispatch→memory spine. Every one of
them is currently blocked on code that does not exist, which is why the system view shows 8 of 18 contracts
broken rather than 8 bugs.

**Promote to facts, then to modules (Q3):** the 24 tacit practices are the cheapest quality gain in this
document — each is already proven by a measured failure, and each has a named home. Items 1–6 alone (the
commit gate cluster) explain CF-031, CF-217 and one lost commit.

**Never "fix" by writing more docs (Q4):** an ADR set, an SLO, a retention policy and a hazard register are
*decisions*, not documents. Each is a board row with a falsifier, not a page.

---

## Rejected findings (recorded so they are not re-filed)

- **"`selftest.sh` has 52 arms, so the docs' 55 is wrong."** Rejected: the numbered sections **plus §4b, §7b,
  §31b** are counted separately, and the count regex `^say "[0-9]+\.` cannot see lettered arms. The numbers
  move as sections land — at `388c7cb` the tree carries 53 numbered sections + 3 lettered = **56 arms**,
  derived by `docs/audits/cf198-section-mapping.sh` (`RESULT: OK`, `arms_plan=56 arms_tree=56`), and
  `docs/ACCEPTANCE-PLAN.md` states the same count. The docs are right; the audit's grep was not.
- **"The conformance battery must run in a worktree or it dirties the checkout."** Rejected: it writes to
  `$HOME/.harness-conformance/run-*/`, and `--install` uses a throwaway HOME; tested at `selftest §45`.
- **"A `.lock` file must be adjudicated with `board_lock.py`."** Rejected as already documented in
  `docs/BOARD.md`; the remaining tacit part is only that operators stand down on the 0-byte file.

---

## Where each quadrant goes next

| Quadrant | Destination |
|---|---|
| Q1 known knowns | already in the modules and `_facts.md`; this page is the index to them |
| Q2 bucket 1 | run as probes; each result becomes a module row or a closed board row |
| Q2 bucket 3 | board rows with the ruling named as the blocker (CF-208, K17, K18) |
| Q3 | a `docs/QUALITY-GATE.md` for 1–6, and a paragraph in each named module for 7–26 |
| Q4(a) | one row per artifact in the standards list — decisions, not pages |
| Q4(b) | lifecycle artifacts first: finalizer, cordon, drain, rollback drill |
