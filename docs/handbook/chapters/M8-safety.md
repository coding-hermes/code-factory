# M8 — SAFETY

## 1. Identity

| Field | Value |
|---|---|
| Module name | SAFETY |
| Path | `~/code-factory/scripts/` — `reclaim_disk.py`, `check_scan_scope.py` |
| Revision | `0e01a6faa9947594ddfe791681de737fe9ec0872` (code-factory HEAD measured; **CF-307 rewrote `check_scan_scope.py` in this chapter's commit — S2 is 196 lines now**; `reclaim_disk.py` is **no longer byte-identical since `47d68b4`** — CF-290 rewrote it to 224 lines with a cache TTL and a bounded containment walk; `project-node.sh` now rehearses the reap at `:222` and reaps at `:230`) |
| Language / runtime | Python 3.14.9 + bash 5.3.9 (measured) |
| Owner lane | code-factory (control host) |
| Status | **VERIFIED** — `reclaim_disk.py` (224 lines) and `check_scan_scope.py` (196 lines) both read in full |

## 2. Purpose, authority and position

Keeps the checks able to fail and the disk able to serve. **M8's implemented scope is narrow and
must stay honestly narrow**: `reclaim_disk.py` reaps fixed user-space caches and expired node
job/clone directories, and `check_scan_scope.py` exists so a gitleaks claim cannot be stated
without naming its `--log-opts` scope. **Cache/job cleanup plus scan-scope text checking is not
system-wide safety** — it is not a package uninstaller, a secret scanner or a factory-wide safety
layer. **Package uninstall belongs to the harness lifecycle (M5)**, not to this module's cleanup
classes. M8 defines the cleanup policy and triggers, and coordinates the protection of active
work, shared infrastructure, credentials, retained evidence and archives with the modules that own
them (M1 disk admission, M3 commit gates, M5 harness lifecycle, M7 credentials). It may not decide
what counts as evidence to retain — a TTL is not an evidence-reference exclusion rule.

**What breaks if this module is absent.** The checks that must be able to fail stop failing, and
the disk the fleet must not fill gets filled.

**What breaks if it lies.** A reaper that deletes a directory a module cites as evidence silently
destroys the evidence of record. The TTL governs *age*, not *citation*; CF-290 age-gates the build
caches by newest subtree mtime and makes the containment check answerable, but age and citation are
still conflated for job/clone dirs (CF-368). And a scan-scope check that passes on a surface it never
read proves nothing was policed — CF-307 makes that branch unreachable, and a surface that *was* read
and is empty now says so in its own words (see F8-3).

**Required behavior (normative).** Approved target behavior governs; the two-tool audit in §3–§13
is implementation coverage, not the safety requirement.

- **Safe candidate selection.** Cleanup eligibility is an allowlisted-class decision: cache versus
  package/image/volume versus job data; root and mount boundaries; **ownership, active-run/lease
  and reference checks** before any target is eligible. The TTL is one condition, never the whole
  eligibility decision — directory mtime alone does not prove a run inactive, a cache unused or a
  directory unreferenced by completion evidence. Protected paths, retained evidence, unpushed/
  uncommitted work and shared/read-only caches are excluded by rule.
- **Dry-run versus actual deletion; logical versus measured bytes.** Dry-run mutates nothing and
  reports **projected** totals distinctly labeled; apply reports **logical** file bytes reclaimed,
  which is not a measured free-space delta — the caller's post-cleanup free-space recheck is the
  physical measurement and is preserved as a distinct fact.
- **Partial failure and recovery.** Bounded deletion work with defined behavior for disappearing,
  unreadable or open targets, low disk mid-run, cancellation and **partial completion** in the
  result contract; skipped/refused/protected/active/unknown targets carry reason codes. When safe
  cleanup cannot restore the resource floor, admission stops and escalates — the policy never
  solves pressure by deleting valid evidence or live workloads.
- **Safety metrics.** Pre/post free bytes and inode headroom, planned versus actual reclaimed
  logical bytes and measured capacity gain, cleanup attempts/outcomes/durations, skipped/refused
  targets by reason, partial errors and admission failures — with owners, units and readout.
  Absence of counters in the current scripts is coverage evidence, not the metric design.
- **Bunker baseline protection with Terminal Jail disabled.** The Bunker must satisfy baseline
  protection **on its own**, documented from its actual deployment mode — not asserted from
  security prose: host-provisioning prerequisites, effective capabilities, **egress/network policy
  (defaults open/shared until configured)**, **per-file versus aggregate disk behavior (the disk
  limit is per-file, not a usage quota)**, and the limits of each execution path (image-backed
  fresh exec, persistent container, detached unit). Deployment conformance is measured on the
  deployed host; source review alone does not establish it.
- **Optional Terminal Jail — disabled by default, enforcing when enabled.** Terminal Jail is
  optional and off until an operator enables and configures it. When enabled, covered Hermes
  terminal/tool paths run through the enforcing wrapper with **no unguarded fallback**: required
  enforcement refuses when the wrapper, policy or required capability is unavailable, and
  unavailable-backend behavior is explicit policy, not a silent degrade. **The observer plugin's
  presence proves no enforcement** — it logs, it does not wrap or block; enforcement requires the
  standalone guarded executor path. **The workload cannot control the policy**: prevention of
  unauthorized disablement or weakening by the workload is required, while authorized operator
  configuration stays available. Terminal Jail does not replace retained-evidence policy,
  credential scoping, acceptance judgment or publication proof — those owners keep their
  obligations.

## 3. Submodule inventory

| Submodule | Unit | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 disk | `reclaim_disk.py` | **active** | invoked by `project-node.sh:222` (`python3 "$HERE/reclaim_disk.py" run --root "$HOME" --dry-run --json`, the rehearsal) and `:230` (`… run --root "$HOME" --json`, the reap) during provisioning |
| S2 scan scope | `check_scan_scope.py` | **operator-invoked (optional)** | no production caller (`grep -rn check_scan_scope scripts/` → no caller; run manually) |

**Finding (carried):** `verify-patch.sh` is **not** an M8 unit — OUTLINE assigns it to M6.S8
(`OUTLINE.md:170`). M8 has two submodules (S1, S2).

## 4. Dependencies

**4a. Runtime dependencies**

| Dependency | Version constraint | Where | How absence is detected |
|---|---|---|---|
| python3 | 3.x | control host | import failure |

**4b. Library contracts**

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| source-root enumeration | this repo | `reclaim_disk.py` derives `BUILD_CACHES`/`AGED_PARENTS`/`PROTECTED` from constants (`:15-23`) | a moved evidence dir becomes a reap target |

**4c. Service contracts** — see §6.

## 5. Settings register

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `--job-ttl-hours` | 24 (`DEFAULT_TTL_HOURS`, `:24`, `:89`) | finite, nonnegative (`:96-98`) | how old a `AGED_PARENTS` child (`.node/jobs/<dir>`, `.node/clones/<dir>`) must be before reaping — **boundary is inclusive** (`age <= TTL` is `kept`, `:143-144`) | a non-finite or negative value → `ValueError` (`:98`) |
| `--cache-ttl-hours` | 24 (`DEFAULT_TTL_HOURS`, `:24`, `:91`) | finite, nonnegative (`:96-98`) | how old a `BUILD_CACHES` root must be before reaping; age is the **newest mtime in the subtree** (`newest_mtime`, `:66-84`), and a cache with any file newer than the TTL is `kept` with the measured age and the TTL in its reason (`:142-145`) | a non-finite or negative value → `ValueError` (`:98`); `0` reaps every cache regardless of age (the selftest uses that to prove the flag is wired, not a constant) |
| `--root` | required (`:186`) | a directory other than `/` (`:93-95`) | the reap boundary | `/` or a non-directory → `ValueError` (`:95`) |
| `--dry-run` | false | boolean | whether anything is deleted | true → nothing unlinked (`:125-130`); **byte totals are still printed as projected (`would free`), not actually reclaimed** (`:202-215`) |

**Exact targets (B15).** `reclaim_disk.py:15-23` fixes three constant sets:

- `BUILD_CACHES` (`:15-21`): `.cache/pip`, `.cache/uv`, `.cache/pre-commit`, `.cache/go-build`, `.npm/_cacache` — processed **`aged=True` with `--cache-ttl-hours`** (CF-290): the gate is the newest mtime anywhere in the subtree, not the directory's own `st_mtime`, because a directory stamp does not move when a file deep inside it is rewritten (`newest_mtime`, `:66-84`). A cache with a file newer than the TTL is `kept`; an expired one is removed and reported as `build cache expired (<age>h > TTL <n>h)`.
- `AGED_PARENTS` (`:22`, `:155-169`): `.node/jobs`, `.node/clones` — children processed **`aged=True` with `--job-ttl-hours`**; a child whose newest subtree mtime age is `<= job_ttl_hours` is `kept` (`:143-144`), so the TTL is a **<= boundary (inclusive)**.
- `PROTECTED` (`:23`): `repo`, `.node/node.json`, `.node/crier.json`, `.node/floor.toml` — refused via `safety_reason` (`:36-63`) before inspection.

## 6. Contracts in and out

M8 has no separate cleanup entry in Part IV (CT-01 through CT-30 plus CT-06R): the filesystem reap
boundary is a local host operation (`reclaim_disk.py` → the directory tree it enumerates), not a
cross-system contract with a peer chapter describing the same interface from the opposite end. It
is listed below as a local edge.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| (local) | filesystem | in | `reclaim_disk.py:87` `reclaim()` | **external** — the target roots it enumerates, no function | **UNVERIFIED (boundary)** — containment + symlink + protected checks at `:36-63` are in-repo and verified (bounded since CF-290); the filesystem itself is an external peer with no function to name, so no "works" verdict is attached |

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| python compile | `python3 -m py_compile scripts/reclaim_disk.py scripts/check_scan_scope.py` | exit 0 | 2026-11-08 | PASS |
| reclaim unit | `python3 tests/test_reclaim.py` | pass | 2026-11-08 | **PASS** (11 tests, rc 0; the two CF-290 arms are `test_fresh_build_cache_survives_ttl` and `test_outside_root_returns_skipped`) |
| reclaim age gate + containment | `bash tests/selftest.sh` (§20) | PASS, CF-290 arms green | 2026-11-08 | **PASS** — a fresh cache is `kept` while an aged sibling is reaped, and an outside-root path returns `skipped:outside-root`; both pre-fix controls are red on `c32b53c` (fresh cache reaped; outside-root probe exits 124 under a 5 s deadline) |
| scan scope | `python3 scripts/check_scan_scope.py` | RESULT OK, claims named | 2026-11-07 | **PASS** — `15 gitleaks claim(s) name their --log-opts`, rc 0 |
| scan scope surface | `python3 -B tests/test_scan_scope.py` | pass | 2026-11-07 | **PASS** (7 arms, rc 0; 5 of them red against the pre-CF-307 tool) |

## 8. Metrics

**RED — none (absence-proved).** No counters or gauges —
`grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics' scripts/reclaim_disk.py
scripts/check_scan_scope.py` → 0 matches. Bytes reclaimed and files scanned are derived from the run
output (`reclaimed_bytes`/`reclaimed_mib` at `:171-178`, plus both TTLs at `:175-176`), not emitted.

## 9. Log lines (verbatim)

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| — | `  %s  %s — %s` (action ∈ `reap/keep/skip`, `:215`) | one row per target | evidentiary |
| — | `  note reclaim — nothing to reclaim` (`:217`) | no bytes freed | descriptive |
| — | `  note reclaim — rehearsal projects: %s (nothing deleted yet)` (`project-node.sh:229`) | after the dry-run rehearsal, before any deletion | evidentiary — the projected set |
| — | `  note reclaim — removed: %s` (`project-node.sh:239`) | after the reap, from the reclaimer's `--json` `reaped` entries | evidentiary — the deleted set |
| — | `reclaim: %s` (stderr, `:200`) | ValueError/OSError | evidentiary |
| — | `  OK  audit-scope: %d gitleaks claim(s) name their --log-opts` (`check_scan_scope.py:187-190`) | all claims name a scope | evidentiary |
| — | `  OK  audit-scope: audit surface read, 0 posture docs` (`:180`) | `docs/audits` was read and holds no matching document | **descriptive** — the surface was read and is empty (F8-3); shares no wording with the failure branch |
| — | `  FAIL  audit-scope: <path> missing / unreadable / is not a directory / is a dangling symlink` + `RESULT: FAIL (unreadable path)` (`:159-168`, raised at `:61-112`) | a path the gate must read is absent or unreadable | evidentiary — exit 2, never a green |

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Evidence dir reaped | a job dir cited as evidence disappears | a cache-only reap (build caches are now age-gated by newest subtree mtime, CF-290) | **OPEN** — CF-368: the TTL exists but no evidence-reference exclusion rule does |
| Dispatcher jobs never reaped | `reclaim_disk.py:21` `AGED_PARENTS` lists only `.node/jobs` and `.node/clones`; dispatcher jobs under `/home/bunker-<agent>/.cf-jobs` (`dispatcher.py:200-201`) are **not** a reap target | a uniform job-dir reaper | **OPEN** — F8-3: the dispatcher-job retention path has no reaper |
| Scanner proves nothing | the gate exits 2 with `FAIL audit-scope: <path> …` — it never prints a green it did not measure | a real clean scan (claims named, exit 0), or a surface READ and empty (`audit surface read, 0 posture docs`, exit 0) | CF-307: `audit_docs` (`check_scan_scope.py:61-92`) stats and `os.scandir`s `docs/audits` instead of globbing it, and a dangling or unreadable optional file is `FAIL` exit 2 (`:96-112`); the old `no posture docs found` branch is gone (F8-3) |

## 11. Limits and margins

- `safety_reason` (`:36-63`) refuses symlinks, paths outside the root, and protected paths
  (`repo`, `.node/node.json`, `.node/crier.json`, `.node/floor.toml`) before any inspection, and
  the component walk is **bounded** (CF-290): it steps from the target up to, never past, the root
  and needs no containment to terminate, so `skipped:outside-root` is reachable instead of dead
  code. The pre-fix `while current != root` never returned for a non-contained path
  (`Path("/").parent == Path("/")`), which hung the provisioner rather than refusing.
- The TTL's mtime basis is the **newest mtime in the target's subtree** (`newest_mtime`, `:66-84`),
  not the directory's own `st_mtime`: a directory stamp does not move when a file deep inside it is
  rewritten, so a pip/go-build cache in active use would otherwise look arbitrarily old. This is
  why a freshly written `.cache/pip` is `kept` and one with nothing newer than the TTL is reaped.
- `check_scan_scope.py` scans only `docs/audits/code-factory-releng-*.md` and
  `docs/SECURITY-TRIAGE.md` (`:46-48`); the rule is a **case-sensitive, same-physical-line**
  substring check (`:131-135`: `"gitleaks" in line` and `"--log-opts" in line`), exit 0/1/2.
- `docs/audits` must exist and be listable: `os.stat` + `os.scandir` (`:61-92`) replaced the
  pre-CF-307 `Path.glob`, which answered an empty selection for a directory it could not read.
  Absent, non-directory or permission-denied is `FAIL` exit 2, as is an optional fixed file that
  is a dangling symlink or unreadable (`:96-112`); plain absence of the optional file is not
  fatal but is named in the OK line.

## 12. Cross-references

- **Package uninstall is M5's, not M8's** — installed harnesses/toolchains are harness-lifecycle
  operations (M5), and the reaper's cache/job classes must never silently extend to them.
- M6 DOCUMENTATION owns `verify-patch.sh` (M6.S8), not M8.
- M11 DISPATCHER's `.cf-jobs` dirs are outside this reaper's targets (F8-3). It is M11 — not M3 — that
  cites job/clone dirs as landing evidence; M3's `clone_lane.py` clones a *lane row*, not a git
  checkout (M3 F3-2). M8's reaper must not delete M11's `.cf-jobs` or M1's node job dirs.
- M1 PROVISIONING invokes `reclaim_disk.py run` via `project-node.sh:222` (the `--dry-run`
  rehearsal) and `:230` (the reap), and prints the projected set, then the removed set, from the
  reclaimer's own `--json` entries.

## 13. Evidence of record

- Code read: `reclaim_disk.py` (224 lines) and `check_scan_scope.py` (196 lines), both in full.
- Commands run: `python3 tests/test_reclaim.py` (11 pass, rc 0); `bash tests/selftest.sh`
  (`SELFTEST: PASS`, including the three CF-290 §20 arms and both pre-fix controls);
  `python3 scripts/check_scan_scope.py`
  (RESULT OK, 15 claims); `python3 -B tests/test_scan_scope.py` (7 arms pass, rc 0 — the same
  battery is red on 5 of 7 arms against the pre-CF-307 tool extracted with `git show`);
  `grep -rn check_scan_scope scripts/` (no caller).
- `docs/UNIT-MAP.yaml:222-236` (M8 S1–S2).
- Board rows: CF-290, CF-341, CF-368.
- **Findings:**
  - **F8-1** (carried, narrowed by CF-290) — the TTL exists for **both** classes now
    (`--job-ttl-hours` 24, `:89`; `--cache-ttl-hours` 24, `:91`); the open question is evidence
    retention, not the absence of a TTL. CF-290 removed the "build caches are reaped regardless of
    mtime" hole and made containment answerable; it did **not** add an evidence-reference exclusion
    rule, so a job dir cited as evidence is still reapable once it is old.
  - **F8-2** (carried) — `verify-patch.sh` is M6.S8, not M8.
  - **F8-3** — `check_scan_scope.py`'s exact surface (two path patterns, case-sensitive same-line
    rule) documented. **CF-307:** "empty-selection = OK" is gone — a surface that cannot be read is
    `FAIL` exit 2, and a surface that was read and is empty says so (`audit surface read, 0 posture
    docs`, exit 0), so the two are distinguishable. Dispatcher `.cf-jobs` dirs are not a reap target.
  - **F8-4** — `reclaim_disk.py` is invoked by `project-node.sh:222` (rehearsal) and `:230` (reap);
    `check_scan_scope.py` has no production caller (operator-invoked, optional).

## 15. Normative safety profile and cleanup contract (P3-12, P3-19)

The required Bunker baseline is independent of Terminal Jail. Each supported profile records effective capabilities, user identity, mount boundaries, network/egress policy, per-file and aggregate storage behavior, process/resource limits and the readback command that proves them. Open/shared egress and a per-file disk limit are not containment claims. A profile lacking a measured baseline is `UNVERIFIED` and cannot be presented as universally supported.

Terminal Jail is optional and disabled by default. When enabled, Hermes covered terminal/tool calls select the guarded executor explicitly; missing wrapper, policy or capability returns `ENFORCEMENT_UNAVAILABLE` and does not fall back to unguarded execution. The workload cannot disable or weaken the policy. Observer-plugin presence is telemetry only and is never enforcement evidence. Enable, rollback and effective-policy readback are recorded by generation.

Cleanup uses `schema: cf.cleanup.v1` with `operation_id`, `bunker_id`, `root`, `policy_generation`, candidate class, owner/lease snapshot, evidence-reference snapshot, pending-memory snapshot and dry-run flag. Selection checks ownership, active lease, fence, evidence references, protected paths and synchronization custody before age. `cache`, `job`, package/image/volume and evidence classes are distinct; no class is added by convention. Dry-run reports projected logical bytes; apply reports logical bytes removed and a separate post-run physical free-space measurement. Disappearing, unreadable, open, cancelled and partially deleted targets carry reason codes; pressure that remains after safe cleanup stops admission and escalates.

The reaper is idempotent by operation id and rechecks protection immediately before each deletion. A concurrent lease or new evidence reference changes the candidate to `PROTECTED` and leaves it intact. Required metrics cover pre/post bytes and inodes, projected versus actual logical bytes, physical gain, outcomes, refusals, partial errors and admission failures. Acceptance cases cover Terminal Jail disabled, missing enforcement when enabled, a live lease, retained evidence, a pending memory record, a symlink/outside-root target and low disk during partial cleanup.

## 16. Serialized retention and qualified isolation (P5-C-18/33)

The retention owner uses the manager's retention rows (Part I §1.9.2) as the sole
admission authority for leases, evidence references and cleanup. Each target has
`resource_id`, canonical root-relative path, device/inode identity, version,
state `live`, `deleting`, `deleted` or `quarantined`, and a set of typed holds
`lease`, `evidence`, `pending_sync`, `backup`. Hold creation and transition
`live → deleting` use the same serializable transaction/CAS. Cleanup commits that
transition only with zero holds, matching inode, expired TTL and safe containment.
A concurrent holder either commits first (cleanup returns PROTECTED) or loses to
the tombstone (holder returns RESOURCE_DELETING and cannot launch/use/cite the target).
Thus the safety guarantee is serialization, not a recheck followed by an unsafe unlink.

Deletion is supervisor-owned: workloads cannot rename protected roots or edit
retention state. After the tombstone is durable, the reaper atomically renames the
object under a private same-filesystem trash directory, fsyncs both directories,
then unlinks with descriptor-relative no-follow traversal. Device changes or inode
mismatch quarantine without deletion. The operation records an immutable sorted
child inventory, per-child cursor, logical bytes removed, errors and result digest;
each cursor advance is durable. Crash between unlink and cursor commit observes
ENOENT as already removed under the same tombstone, not a new eligible object.
Cancellation before tombstone is no effect; afterward leaves `deleting` with cursor
for the same operation to resume. New holds cannot resurrect trash. Dry-run writes
no tombstone and labels all byte counts projected. Physical free-byte/inode deltas
are separately measured. An unavailable hold ledger refuses cleanup. [VI.33; F6]

The minimum qualified Linux profile uses a distinct unprivileged UID per Bunker,
user/mount/PID/network namespaces, cgroup v2 memory/pids/CPU limits, no host socket,
no device pass-through, no added capabilities, no-new-privileges and read-only runtime
and policy mounts. Workspace and pending-memory/evidence are separate durable mounts;
shared caches are read-only. Defaults are 8 GiB memory, 256 processes, 2000 CPU millis
and 40 GiB aggregate disk quota, with 4 GiB free-space admission floor. A host lacking
aggregate quota or delegated cgroup enforcement refuses PROFILE_UNSUPPORTED; a
per-file limit does not qualify. Network permits only configured Crier, proxy,
repository-read and broker endpoints over TLS; arbitrary egress and host networking
are denied. These are target defaults, not claims about the historical Bunker binary.

Terminal Jail configuration is `{mode: disabled or required, policy_ref, policy_digest,
executor_digest, covered_paths}`. Disabled omits the other fields; required needs all
of them and covered_paths exactly `[terminal, subprocess, tool_exec, hook_exec]`.
The supervisor, not the model, constructs argv as `[pinned_executor, --policy-file,
read_only_policy_path, --, pinned_command, ...]`; the adapter proves that those exact
flags are supported before qualification. Shell, Python subprocesses, MCP/tool
subprocess launches and hooks have no alternate workload-visible launcher. Policy
is administrator-owned and read-only to both harness and child processes; enabling
without that separation returns ENFORCEMENT_UNAVAILABLE. Policy contains allowed
executable digests, read/write roots, endpoint allowlist and numeric resource limits;
unknown fields, writable policy, missing digest/capability or bypass entrypoint deny
readiness. Readback reports UID, effective capabilities, mount modes, cgroup limits,
network-denial probe and guarded/unguarded execution probes with policy digest.
DECISION SLOT C-SAFETY selects another profile only with equivalent measured probes;
default is this fail-closed profile with Terminal Jail disabled, not open host exec.
The policy is a closed object `{schema_version:jail-policy.v1, executable_digests,
read_roots,write_roots,endpoints,memory_bytes,pids,cpu_millis}`. Digest sets contain
1..1024 SHA-256 values; roots are normalized absolute paths, endpoint entries resolve
to V.9 deployment endpoints, collection bounds are 0..1024. memory_bytes is positive
integer <= host capacity, pids is 16..1048576, cpu_millis is 100..1024000. policy_ref
resolves to an administrator-signed immutable artifact; executor_digest and
policy_digest are SHA-256. Unknown keys and overlapping forbidden host roots refuse.
[Part V profiles; CT-17/23; VII.16]

## 17. Worker-unreachable enforcement records (P6-07/09/12)

The qualified baseline applies M1 §17.5's four-UID profile verbatim: `factory-control`
owns supervisor, launch, budget, retention and policy state; `factory-foreman` owns only
the fenced foreman HOME; `factory-worker` owns only its attempt HOME/worktree;
`factory-node-broker` owns secret transfer and sealed staging. They do not share a UID,
writable HOME, supplementary group or host privilege. Control and broker roots are not
mounted by the worker. This is a kernel and service boundary, not a promise that Hermes
will avoid protected files.

Retention records under `/var/lib/factory/control/retention` are accessible only to the
retention owner. A worker's `$HOME` maps to `/var/lib/factory/worker`; it contains no
`.node` control journal, shared auth database, retention index, peer worktree, supervisor
socket or policy mount. The local memory and evidence roots are separate volumes with
writer sockets, so retaining them does not make their Git refs or hold records writable.
Read-only release/policy mounts are owned by `factory-control`, and a mount readback must
prove the effective `ro` flag rather than relying on a file-mode claim.

The foreman's only execution interface is `/run/factory/<project>/submit.sock`, restricted
by SO_PEERCRED and the live fence to CT-02/CT-05 submit/status/output/cancel. It cannot
edit allowance, launch identity, retention, policy or credentials. The worker has no
submit socket and can use only its one-way result socket for the preassigned execution
key. Secret descriptors are delivered by the node broker directly to the authorized role,
with seals and close-on-exec rules; no secret is placed in a shared environment, process
argument, worker-readable staging directory or event.

Configuration precedence is accepted generation → signed project/lane profile → signed
deployment profile → global default. Global `safety.terminal_jail=required` requires the
guarded path even when a profile says disabled; that conflict is `PROFILE_CONFLICT` until
the profile also selects required. Global disabled with profile required is valid and
enables the guarded path for that profile. Both disabled leaves Terminal Jail off without
weakening the UID/mount/cgroup baseline. Any enabled mode lacking its signed policy,
executor or negative bypass proof returns `ENFORCEMENT_UNAVAILABLE`.

The mandatory readback executes the ordinary worker's attempts to open or rename the
retention index, launch/budget journal, supervisor administration socket, another role's
credential, signed policy and peer worktree. All must fail without mutation. Positive
readback proves the foreman's mediated submit, local pending-memory append, own result
return and worktree write. The receipt carries UID/gid, mount table, namespace IDs,
cgroup limits, socket visibility/modes, no-new-privileges and network-denial results.
Emission and scrape use Part V §V.10 with bounded `reclaim`/`verify` operations and the
FactoryIdentity of the affected attempt. A passing probe is version-bound to the signed
profile digest; an unobserved probe is `UNVERIFIED`, never inferred from documentation.

## RED field count: 1 (Metrics §8)

## FLIGHT DATA FILE - M8 SAFETY

```checklist
TITLE: M8 SAFETY
WHO: NODE OPERATOR
FAIL PATH - offer a change the gate must refuse
√ REFUSED - named reason, nonzero exit, nothing merged
DISK - run require_disk with the floor raised above free space
√ REFUSAL - named refusal before the host fills
SECRETS - run the secret scan on a staged token
√ CAUGHT - scan names the file and line; commit blocked
```
