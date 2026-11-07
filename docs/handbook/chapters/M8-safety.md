# M8 — SAFETY

## 1. Identity

| Field | Value |
|---|---|
| Module name | SAFETY |
| Path | `/home/kara/code-factory/scripts/` — `reclaim_disk.py`, `check_scan_scope.py` |
| Revision | `08a2c8a2ea3a44445da2f1013c545b568c7bf352` (code-factory HEAD at round-11 derivation; `reclaim_disk.py`/`check_scan_scope.py` byte-identical since `47d68b4`) |
| Language / runtime | Python 3.14.9 + bash 5.3.9 (measured) |
| Owner lane | code-factory (control host) |
| Status | **VERIFIED** — `reclaim_disk.py` (169 lines) and `check_scan_scope.py` (118 lines) both read in full this round |

## 2. Purpose, authority and position

Keeps the checks able to fail and the disk able to serve. `reclaim_disk.py` reaps fixed
user-space caches and expired node job/clone directories; `check_scan_scope.py` exists so a
gitleaks claim cannot be stated without naming its `--log-opts` scope. It may not decide what
counts as evidence to retain — a TTL is not an evidence-reference exclusion rule.

**What breaks if this module is absent.** The checks that must be able to fail stop failing, and
the disk the fleet must not fill gets filled.

**What breaks if it lies.** A reaper that deletes a directory a module cites as evidence silently
destroys the evidence of record. The TTL governs *age*, not *citation*; the two are currently
conflated (CF-290, CF-368). And a scan-scope check that passes on "no docs found" proves nothing
was policed (see F8-3).

## 3. Submodule inventory

| Submodule | Unit | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 disk | `reclaim_disk.py` | **active** | invoked by `project-node.sh:212` (`python3 "$HERE/reclaim_disk.py" run --root "$HOME" --json`) during provisioning |
| S2 scan scope | `check_scan_scope.py` | **operator-invoked (optional)** | no production caller (`grep -rn check_scan_scope scripts/` → no caller; run manually this round) |

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
| scan scope | `python3 scripts/check_scan_scope.py` | RESULT OK, claims named | 2026-11-06 | **PASS** — `15 gitleaks claim(s) name their --log-opts`, rc 0 |

## 8. Metrics

**RED — none (absence-proved this round).** No counters or gauges —
`grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics' scripts/reclaim_disk.py
scripts/check_scan_scope.py` → 0 matches. Bytes reclaimed and files scanned are derived from the run
output (`reclaimed_bytes`/`reclaimed_mib` at `:121-123`), not emitted.

## 9. Log lines (verbatim)

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| — | `  %s  %s — %s` (action ∈ `reap/keep/skip`, `:160`) | one row per target | evidentiary |
| — | `  note reclaim — nothing to reclaim` (`:162`) | no bytes freed | descriptive |
| — | `reclaim: %s` (stderr, `:145`) | ValueError/OSError | evidentiary |
| — | `  OK  audit-scope: %d gitleaks claim(s) name their --log-opts` (`check_scan_scope.py:112`) | all claims name a scope | evidentiary |
| — | `  OK  audit-scope: no posture docs found` (`:110`) | nothing matched | **descriptive** — proves nothing was policed (F8-3) |

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Evidence dir reaped | a job dir cited as evidence disappears | a cache-only reap | **OPEN** — CF-290, CF-368: the TTL exists but no evidence-reference exclusion rule does |
| Dispatcher jobs never reaped | `reclaim_disk.py:21` `AGED_PARENTS` lists only `.node/jobs` and `.node/clones`; dispatcher jobs under `/home/bunker-<agent>/.cf-jobs` (`dispatcher.py:200-201`) are **not** a reap target | a uniform job-dir reaper | **OPEN** — F8-3: the dispatcher-job retention path has no reaper |
| Scanner proves nothing | `no posture docs found` → RESULT OK | a real clean scan | the empty-selection branch (`check_scan_scope.py:109-114`) is OK by design (F8-3) |

## 11. Limits and margins

- `safety_reason` (`:25-39`) refuses symlinks, paths outside the root, and protected paths
  (`repo`, `.node/node.json`, `.node/crier.json`, `.node/floor.toml`) before any inspection.
- The TTL's mtime basis is the target's `st_mtime` (`:90`).
- `check_scan_scope.py` scans only `docs/audits/code-factory-releng-*.md` and
  `docs/SECURITY-TRIAGE.md` (`:31-32`); the rule is a **case-sensitive, same-physical-line**
  substring check (`:64-68`: `"gitleaks" in line` and `"--log-opts" in line`), exit 0/1/2.

## 12. Cross-references

- M6 DOCUMENTATION owns `verify-patch.sh` (M6.S8), not M8.
- M11 DISPATCHER's `.cf-jobs` dirs are outside this reaper's targets (F8-3). It is M11 — not M3 — that
  cites job/clone dirs as landing evidence; M3's `clone_lane.py` clones a *lane row*, not a git
  checkout (M3 F3-2). M8's reaper must not delete M11's `.cf-jobs` or M1's node job dirs.
- M1 PROVISIONING invokes `reclaim_disk.py run` via `project-node.sh:212`.

## 13. Evidence of record

- Code read: `reclaim_disk.py` (169 lines) and `check_scan_scope.py` (118 lines), both in full.
- Commands run: `python3 tests/test_reclaim.py` (9 pass); `python3 scripts/check_scan_scope.py`
  (RESULT OK, 15 claims); `grep -rn check_scan_scope scripts/` (no caller).
- `docs/UNIT-MAP.yaml:222-236` (M8 S1–S2).
- Board rows: CF-290, CF-341, CF-368.
- **Findings:**
  - **F8-1** (carried) — the TTL exists (`--job-ttl-hours` 24, `:42`); the open question is
    evidence retention, not the absence of a TTL.
  - **F8-2** (carried) — `verify-patch.sh` is M6.S8, not M8.
  - **F8-3** — `check_scan_scope.py`'s exact surface (two path patterns, case-sensitive same-line
    rule, empty-selection = OK) documented; dispatcher `.cf-jobs` dirs are not a reap target.
  - **F8-4** (new) — `reclaim_disk.py` is invoked by `project-node.sh:212` (active);
    `check_scan_scope.py` has no production caller (operator-invoked, optional).

## RED field count: 1 (Metrics §8)
