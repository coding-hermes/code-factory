# VIII.5 — TESTS/

## 1. Identity

| Field | Value |
|---|---|
| Mechanism | The repository's `tests/` delivery and falsification surface |
| Path | `tests/selftest.sh`, `tests/test_*.py`, `tests/harness/` |
| Revision | `812a380dfdfc09214b15148df1ffdf576696e1e8` at the time of the recorded run |
| Language / runtime | Bash and Python 3.14.9, measured by the commands below |
| Owner lane | code-factory |
| Status | **VERIFIED** for the smoke entry point and control-environment contract; **FAILING** for the recorded selftest run (one non-zero arm) |

## 2. Purpose, authority and position

`tests/` is a shipped delivery mechanism, not an informal developer scratch area. It is the
executable evidence layer below the handbook and beside the implementation: `tests/selftest.sh`
is the repository gate, while the Python tests and per-unit control arms make selected contracts
falsifiable. The code and test output are the authority for what ran; this chapter records the
measured shape rather than converting a green-looking subset into a release claim.

If this mechanism is absent, a change can appear correct without the refusal, negative, restart,
or boundary arm that distinguishes it from the defect it claims to fix. If it lies, the main
failure is a false green: a test can print a `FAIL` row as an intentional negative fixture while
the overall command succeeds, or a control arm can silently run the fixed source and prove nothing.
A red suite does not by itself identify a product regression: load-sensitive flakes and inherited
fixture failures must be separated from a failure introduced by the current change.

## 3. Submodule inventory

| Unit | Responsibility | Classification | Evidence |
|---|---|---|---|
| `tests/selftest.sh` | Full repository gate and negative-control battery | active | Direct entry point: `bash tests/selftest.sh` |
| `tests/test_*.py` | Python smoke and contract tests | active | `python3 -m unittest discover -s tests -p 'test_*.py'` |
| `tests/harness/` | Harness adapter and conformance checks | active/optional by adapter | `tests/harness-conformance.sh` and adapter-specific tests |
| `CF_BUS_*_PREFIX_CONTROL` arms | Run a pre-fix control source against a fixture | optional, when the relevant falsifier is invoked | `tests/test_bus_dispatch_encoding.py` and `tests/test_bus_result_delivery.py` |

The control arms are deliberately not part of the ordinary bare discover result. They need both
a control selector and a source override so they cannot accidentally certify the current fixed
implementation.

## 4. Dependencies and contracts

### 4a. Runtime dependencies

| Dependency | Version constraint | Where it must exist | How absence is detected |
|---|---|---|---|
| `bash` | repository shell runtime | control host | `bash tests/selftest.sh` exits non-zero |
| `python3` | 3.x; the recorded run used 3.14.9 | control host | unittest discovery or a test compile fails |
| repository scripts and fixtures | current checkout | paths resolved from `tests/` | named test row or import failure |

### 4b. Control-source contract

A falsifier that compares a corrected implementation with its predecessor must resolve both inputs
explicitly. `CF_BUS_WORKER_SOURCE` points the test at the worker source under test. The matching
`CF_BUS_*_PREFIX_CONTROL=1` variable enables the pre-fix assertions. Current examples are:

```text
CF_BUS_WORKER_SOURCE=/tmp/.../node-bus-worker.py
CF_BUS_DISPATCH_PREFIX_CONTROL=1
python3 tests/test_bus_dispatch_encoding.py

CF_BUS_WORKER_SOURCE=/tmp/.../node-bus-worker.py
CF_BUS_RESULT_PREFIX_CONTROL=1
python3 tests/test_bus_result_delivery.py
```

The exact selector is owned by the test: dispatch encoding uses
`CF_BUS_DISPATCH_PREFIX_CONTROL`; result delivery uses `CF_BUS_RESULT_PREFIX_CONTROL`. The
selector without a pre-fix source is not a valid control experiment, and the source override
without its selector is an ordinary test of the current implementation.

## 5. Verification

| Check | Command | Expected | Recorded result |
|---|---|---|---|
| Python smoke | `python3 -m unittest discover -s tests -p 'test_*.py'` | `Ran 177 tests` followed by `OK`; skips have named reasons | `Ran 177 tests in 21.195s`; `OK (skipped=5)`; exit 0 |
| Repository gate | `bash tests/selftest.sh` | terminal `SELFTEST: PASS`, exit 0 | `SELFTEST: FAIL (1)`, exit 1 in `docs/audits/CF-397-selftest.txt` |
| Dispatch control | `CF_BUS_WORKER_SOURCE=<pre-fix> CF_BUS_DISPATCH_PREFIX_CONTROL=1 python3 tests/test_bus_dispatch_encoding.py` | the pre-fix defect is reproduced by the control arm | available as the documented control procedure; run only with a pre-fix source |
| Result control | `CF_BUS_WORKER_SOURCE=<pre-fix> CF_BUS_RESULT_PREFIX_CONTROL=1 python3 tests/test_bus_result_delivery.py` | the pre-fix defect is reproduced by the control arm | available as the documented control procedure; run only with a pre-fix source |

The smoke evidence is frozen in `docs/audits/CF-397-unittest-discover.txt`. It records the
measured 177-test run, five skips, exit 0, and the test's own additional measurements. The
selftest evidence is retained separately because its result is red, not silently replaced by the
smoke result.

## 6. CF-050 publication gate and repair path

Section 61 of `tests/selftest.sh` grades the index as publication truth: the staged tree is what
will be published. A host-home path still carried by the index is refused; a path present in HEAD
but absent from the index is a staged repair and is reported as `REPAIR`. The falsifier arms cover a
fresh staged leak, an untouched committed leak (including a clean unrelated staged file), a committed
and removed fixture, and the repair direction where `git rm` is staged but not yet committed. The
repair direction is therefore allowed without opening a publishing hole.

Measured commands and output at this revision:

| Command | Measured output |
|---|---|
| `bash -n tests/selftest.sh` | exit 0 |
| `bash docs/audits/cf050-repair-path.sh` | `REPAIR: allowed`; `LEAK: refused` (fresh staged leak); `LEAK: refused` (untouched committed leak); `EXIT=0` |
| `python3 scripts/handbook_spine.py` | `findings=0`; exit 0 |
| targeted §61 extraction and arms 1–3 | committed leak: `FAIL ... paths: docs/fixture.md`; committed leak + clean staged file: `FAIL ... paths: docs/fixture.md`; removed and committed: `PASS ... baseline 0, current 0`; exit 0 |

The implementation and probe are anchored by `tests/selftest.sh:6966-7050`; the chapter is the
named documentation surface for `tests/selftest.sh::CF050_publish_gate` and
`docs/audits/cf050-repair-path.sh`.

## 7. What a red suite does and does not prove

A red suite proves that at least one asserted arm did not meet its expected result in that run.
It does not, by itself, prove that the current implementation introduced the failure. Before
assigning causality, rerun the named section against the parent revision and record the load
regime. `docs/BOARD.md` records that `tests/selftest.sh` has shown intermittent failures at an
unchanged tip under host load; the relevant distinction is:

1. a failure present at the parent revision is inherited or load-window evidence, not a new
   regression from the candidate;
2. a failure absent at the parent and reproducible at the candidate is a candidate regression;
3. a failure that changes between repeated runs at one unchanged revision is unproven until the
   load/window condition and a deterministic reproduction are recorded.

Intentional negative fixtures print `FAIL` rows while proving that a bad input is refused. The
terminal summary and exit code, not a raw count of the word `FAIL`, decide the suite result. A
skip is legitimate only when the output names the unavailable prerequisite or the control mode;
a skip with no reason is not a green proof.

## 7. Failure modes and recovery

| Failure | Indication | Recovery |
|---|---|---|
| Real assertion regression | named arm fails and parent control is green | inspect the cited source/test seam, fix it, rerun the focused arm and the gate |
| Load-window or inherited failure | same arm fails at parent or alternates across unchanged reruns | preserve both outputs, record load and revision, and do not call it a new regression |
| Vacuous control | control selector runs the current source or source path is absent | refuse the evidence; supply a real pre-fix source and rerun |
| Unnamed skip | test omits the prerequisite reason | treat the result as incomplete evidence and make the skip explicit |

## 8. Evidence of record

- `docs/audits/CF-397-unittest-discover.txt` — measured smoke run: 177 tests, five named
  skips, `OK`, exit 0.
- `docs/audits/CF-397-selftest.txt` — measured repository gate, `SELFTEST: FAIL (1)`, exit 1;
  the red arm and its surrounding negative fixtures remain visible.
- `tests/test_bus_dispatch_encoding.py` — dispatch control selector and source contract.
- `tests/test_bus_result_delivery.py` — result-delivery control selector and source contract.

ch:trace row=CF-397 spec=docs/handbook/OUTLINE.md#VIII.5 wave=none:serial-takeover-after-worker-timeout test=tests/test_bus_result_delivery.py::PreFixControlTest doc=docs/handbook/chapters/VIII-5-tests.md evidence=docs/audits/CF-397-unittest-discover.txt witness=none:no-external-witness verdict=none:foreman-runs-gitreins-after-commit commit=none:worker-does-not-know-final-sha memory=none:foreman-writes-after-publication
