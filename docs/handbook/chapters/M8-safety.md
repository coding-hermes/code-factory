# M8 — SAFETY

## 1. Identity

| Field | Value |
|---|---|
| Module name | SAFETY |
| Path | `/home/kara/code-factory/scripts/` — `reclaim_disk.py`, `check_scan_scope.py` |
| Revision | `0e01a6faa9947594ddfe791681de737fe9ec0872` (code-factory HEAD measured; **CF-307 rewrote `check_scan_scope.py` in this chapter's commit — S2 is 196 lines now**, `reclaim_disk.py` byte-identical since `47d68b4`; `project-node.sh:212` re-verified — the reclaim invocation line is unchanged) |
| Language / runtime | Python 3.14.9 + bash 5.3.9 (measured) |
| Owner lane | code-factory (control host) |
| Status | **VERIFIED** — `reclaim_disk.py` (169 lines) and `check_scan_scope.py` (196 lines) both read in full |

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
destroys the evidence of record. The TTL governs *age*, not *citation*; the two are currently
conflated (CF-290, CF-368). And a scan-scope check that passes on a surface it never read proves
nothing was policed — CF-307 makes that branch unreachable, and a surface that *was* read and is
empty now says so in its own words (see F8-3).

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
| S1 disk | `reclaim_disk.py` | **active** | invoked by `project-node.sh:212` (`python3 "$HERE/reclaim_disk.py" run --root "$HOME" --json`) during provisioning |
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
| source-root enumeration | this repo | `reclaim_disk.py` derives `BUILD_CACHES`/`AGED_PARENTS`/`PROTECTED` from constants (`:14-22`) | a moved evidence dir becomes a reap target |

**4c. Service contracts** — see §6.

## 5. Settings register

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `--job-ttl-hours` | 24 (`:42`, `:135`) | finite, nonnegative (`:46-47`) | how old a job/clone dir must be before reaping — **the TTL applies only to `AGED_PARENTS` children (`.node/jobs`, `.node/clones`); build caches are reaped without any age condition** (`:102-103` vs `:104-111`, B15) | a non-finite or negative value → `ValueError` (`:47`) |
| `--root` | required (`:134`) | a directory other than `/` (`:44-45`) | the reap boundary | `/` or a non-directory → `ValueError` (`:45`) |
| `--dry-run` | false | boolean | whether anything is deleted | true → nothing unlinked (`:78-79`); **byte totals are still printed as projected (`would free`), not actually reclaimed** (`:119-123`, B15) |

**Exact targets (B15).** `reclaim_disk.py:14-22` fixes three constant sets:

- `BUILD_CACHES` (`:14-19`): `.cache/pip`, `.cache/uv`, `.cache/pre-commit`, `.cache/go-build`, `.npm/_cacache` — processed **with `aged=False`**, so they are removed on TTL-irrespective grounds (the `else` branch's `"build cache"` reason).
- `AGED_PARENTS` (`:21`): `.node/jobs`, `.node/clones` — children processed **with `aged=True`**; a child whose `st_mtime` age is `<= job_ttl_hours` is `kept` (`:90`), so the TTL is a **<= boundary (inclusive)** and governs only these two parents.
- `PROTECTED` (`:22`): `repo`, `.node/node.json`, `.node/crier.json`, `.node/floor.toml` — refused via `safety_reason` (`:25-39`) before inspection.

## 6. Contracts in and out

M8 has **no entry in the canonical register** (CT-01..CT-18, OUTLINE Part IV): the filesystem reap
boundary is a local host operation (`reclaim_disk.py` → the directory tree it enumerates), not a
cross-system contract with a peer chapter describing the same interface from the opposite end. It
is listed below as a local edge.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| (local) | filesystem | in | `reclaim_disk.py:42` `reclaim()` | **external** — the target roots it enumerates, no function | **UNVERIFIED (boundary)** — containment + symlink + protected checks at `:25-39` are in-repo and verified; the filesystem itself is an external peer with no function to name, so no "works" verdict is attached |

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| python compile | `python3 -m py_compile scripts/reclaim_disk.py scripts/check_scan_scope.py` | exit 0 | 2026-11-06 | PASS |
| reclaim unit | `python3 tests/test_reclaim.py` | pass | 2026-11-06 | **PASS** (9 tests, rc 0) |
| scan scope | `python3 scripts/check_scan_scope.py` | RESULT OK, claims named | 2026-11-07 | **PASS** — `15 gitleaks claim(s) name their --log-opts`, rc 0 |
| scan scope surface | `python3 -B tests/test_scan_scope.py` | pass | 2026-11-07 | **PASS** (7 arms, rc 0; 5 of them red against the pre-CF-307 tool) |

## 8. Metrics

**RED — none (absence-proved).** No counters or gauges —
`grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics' scripts/reclaim_disk.py
scripts/check_scan_scope.py` → 0 matches. Bytes reclaimed and files scanned are derived from the run
output (`reclaimed_bytes`/`reclaimed_mib` at `:121-123`), not emitted.

## 9. Log lines (verbatim)

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| — | `  %s  %s — %s` (action ∈ `reap/keep/skip`, `:160`) | one row per target | evidentiary |
| — | `  note reclaim — nothing to reclaim` (`:162`) | no bytes freed | descriptive |
| — | `reclaim: %s` (stderr, `:145`) | ValueError/OSError | evidentiary |
| — | `  OK  audit-scope: %d gitleaks claim(s) name their --log-opts` (`check_scan_scope.py:187-190`) | all claims name a scope | evidentiary |
| — | `  OK  audit-scope: audit surface read, 0 posture docs` (`:180`) | `docs/audits` was read and holds no matching document | **descriptive** — the surface was read and is empty (F8-3); shares no wording with the failure branch |
| — | `  FAIL  audit-scope: <path> missing / unreadable / is not a directory / is a dangling symlink` + `RESULT: FAIL (unreadable path)` (`:159-168`, raised at `:61-112`) | a path the gate must read is absent or unreadable | evidentiary — exit 2, never a green |

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Evidence dir reaped | a job dir cited as evidence disappears | a cache-only reap | **OPEN** — CF-290, CF-368: the TTL exists but no evidence-reference exclusion rule does |
| Dispatcher jobs never reaped | `reclaim_disk.py:21` `AGED_PARENTS` lists only `.node/jobs` and `.node/clones`; dispatcher jobs under `/home/bunker-<agent>/.cf-jobs` (`dispatcher.py:200-201`) are **not** a reap target | a uniform job-dir reaper | **OPEN** — F8-3: the dispatcher-job retention path has no reaper |
| Scanner proves nothing | the gate exits 2 with `FAIL audit-scope: <path> …` — it never prints a green it did not measure | a real clean scan (claims named, exit 0), or a surface READ and empty (`audit surface read, 0 posture docs`, exit 0) | CF-307: `audit_docs` (`check_scan_scope.py:61-92`) stats and `os.scandir`s `docs/audits` instead of globbing it, and a dangling or unreadable optional file is `FAIL` exit 2 (`:96-112`); the old `no posture docs found` branch is gone (F8-3) |

## 11. Limits and margins

- `safety_reason` (`:25-39`) refuses symlinks, paths outside the root, and protected paths
  (`repo`, `.node/node.json`, `.node/crier.json`, `.node/floor.toml`) before any inspection.
- The TTL's mtime basis is the target's `st_mtime` (`:90`).
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
- M1 PROVISIONING invokes `reclaim_disk.py run` via `project-node.sh:212`.

## 13. Evidence of record

- Code read: `reclaim_disk.py` (169 lines) and `check_scan_scope.py` (196 lines), both in full.
- Commands run: `python3 tests/test_reclaim.py` (9 pass); `python3 scripts/check_scan_scope.py`
  (RESULT OK, 15 claims); `python3 -B tests/test_scan_scope.py` (7 arms pass, rc 0 — the same
  battery is red on 5 of 7 arms against the pre-CF-307 tool extracted with `git show`);
  `grep -rn check_scan_scope scripts/` (no caller).
- `docs/UNIT-MAP.yaml:222-236` (M8 S1–S2).
- Board rows: CF-290, CF-341, CF-368.
- **Findings:**
  - **F8-1** (carried) — the TTL exists (`--job-ttl-hours` 24, `:42`); the open question is
    evidence retention, not the absence of a TTL.
  - **F8-2** (carried) — `verify-patch.sh` is M6.S8, not M8.
  - **F8-3** — `check_scan_scope.py`'s exact surface (two path patterns, case-sensitive same-line
    rule) documented. **CF-307:** "empty-selection = OK" is gone — a surface that cannot be read is
    `FAIL` exit 2, and a surface that was read and is empty says so (`audit surface read, 0 posture
    docs`, exit 0), so the two are distinguishable. Dispatcher `.cf-jobs` dirs are not a reap target.
  - **F8-4** (new) — `reclaim_disk.py` is invoked by `project-node.sh:212` (active);
    `check_scan_scope.py` has no production caller (operator-invoked, optional).

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
