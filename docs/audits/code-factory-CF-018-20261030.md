# CF-018 — build/cache/runner contract audit

Date: 2026-10-30. Base: `28df3aaf8453e104cedd6b60cbbc93b5b6db51e4`.
Branch: `wt/CF-018`. Scope is specification plus executable hermetic policy
acceptance, not deployment. Tier: T3 for invoked/observed local tests only.
No foreman judge verdict, node admission, runner registration, or remote build
execution is claimed by this audit. No board row is closed here.

## Read boundary and design decision

Read `AGENTS.md` first, then `skills/code-factory-foreman/SKILL.md`,
`specs/NODE.md`, `specs/NODE-LIFECYCLE.md`, `specs/ENVELOPE.md`,
`specs/HARNESS.md`, `docs/DESIGN.md`, `docs/DEPLOYMENT-OPTIONS.md`,
`tests/selftest.sh`, and `scripts/lib.sh`. Read guard configuration without
modifying it. Confirmed base and branch using `git rev-parse HEAD` and
`git branch --show-current`; the initial working tree was clean.

Wrote `specs/BUILD.md` before test/helper implementation. It makes per-node,
project/repository/trust/ref/runtime-scoped reconstructable caches the v1
default; heavy work is admitted only to known remote identities. Public untrusted
PRs use GitHub-hosted VM isolation without factory cache access. Self-hosted
runners are specified as ephemeral/JIT but remain BLOCKED on approved credential
transport and a qualified no-root host profile. Dedicated cache/build services,
registry caches and ARC are compared and deferred. CF-019 remains the owner of
durable storage and evidence backends.

A small real kernel, `scripts/build-policy.py`, is necessary to make the key,
trust-write, integrity and placement contract executable instead of checking a
mock's canned responses. It computes keys, validates policy, reads/writes and
rehashes real small bytes in private temporary directories, and admits or denies
placement. It does not execute build commands, install packages, register
runners, contact infrastructure, or constitute an authenticated cache service.

## Authoritative source retrieval

External sources were fetched during this task, not inferred from historical
line numbers. The numbered source links and their architectural uses are in
`specs/BUILD.md#sources`:

- GitHub-hosted runner concepts: fresh VM per job with the single-CPU shared-VM
  exception; changing images and available OS modes.
- GitHub self-hosted runner reference and secure-use reference: ephemeral/JIT
  single-job behavior, remaining hardware-wipe responsibility, groups/routing,
  least privilege and hazards of privileged untrusted checkout.
- GitHub REST self-hosted runner documentation: repository JIT creation and
  inventory/deletion surfaces. The initial extracted article window omitted the
  repository JIT section, so a full official article-body fetch confirmed it:

  ```sh
  curl -fsSL --max-time 20 \
    'https://docs.github.com/api/article/body?pathname=/en/rest/actions/self-hosted-runners' \
    -o /tmp/cf018-github-runners-source.json
  ```

  Exit 0; 42,914 bytes. Despite the local suffix, the response was Markdown,
  not JSON. The section headed “Create configuration for a just-in-time runner
  for a repository” states `POST /repos/{owner}/{repo}/actions/runners/generate-jitconfig`,
  repository admin access, required name/group/labels and 201/404/409/422 statuses.
  No authenticated API request or real registration was made.
- GitHub dependency-cache reference and Actions limits: immutable keys,
  prefix/default-branch search, fork/base-branch visibility, account-dependent
  quotas/eviction. Factory limits in BUILD are explicitly proposed policy rather
  than copied GitHub platform limits.
- npm cache, pip caching, Go build/test cache and module verification, Docker
  BuildKit backend documentation: native integrity behavior, wheel/runtime
  caveats, explicit scoped paths and external import/export limitations.

Pre-solve discovery for `ephemeral-build-runner-cache-isolation` returned
`not_found`; no cached answer was substituted for the source review. The only
guard correction was a formatter request on the new file, not nontrivial
infrastructure debugging. `python-format-guard-failure` discovery also returned
`not_found`; no post-debug solution submission was needed for that mechanical
format-only correction.

## Acceptance matrix

| Owning acceptance criterion | Specification | Invoked local proof | Remaining live boundary |
|---|---|---|---|
| 1. Hosted/self-hosted registration, ephemeral lifecycle, repository/job isolation, quotas, cleanup | BUILD: Runner modes and support boundaries; Registration and credential boundary; Ephemeral lifecycle, quotas, and cleanup | Contract placement rejection; full selftest and guard. Runner lifecycle itself is prospective, not simulated as deployment proof. | No registration, group restrictions, single-job teardown, quota enforcement or credential deletion observed on GitHub/Bunker. |
| 2. Package/module/build ownership, keys, trust, eviction and host-loss recovery | BUILD: Package and build-cache ownership; Cache identity and trust policy; Eviction and host-loss recovery | `test_cache_reuse`, `test_all_key_dimensions_isolate_bytes`, `test_untrusted_writes_denied`, `test_failed_integrity_not_reused`, `test_host_loss_cold_recovery`, input/private-root/CLI tests | No native package-manager integration, production broker authorization, streaming, quota/LRU/lease implementation or live host recovery. |
| 3. Dedicated service versus per-Bunker, v1 and deferred alternatives | BUILD: Authority and v1 decision; Dedicated service versus per-node caches | Source-cited architectural comparison and explicit decision, read against completed CF-016 constraints | No dedicated service deployed or selected; no backend selected for CF-019. |
| 4. Falsifiable reuse, cross-project isolation and heavyweight remote placement | BUILD: Placement contract and executable acceptance | 10 real local tests; seven deliberate helper mutations rejected; selftest failure propagated; clean positive rerun | Remote identity attestation, actual remote builds and control-host process/transport evidence are prospective. Local admission checks do not prove live placement. |

## Commands and observed results

Commands run from this repository root. Output excerpts below intentionally omit
machine-specific paths and nondeterministic temporary names, not failures.

### Red before helper implementation

```sh
bash tests/build-contract.sh
```

Observed exit 1:

```text
FAIL build-contract: missing executable policy kernel scripts/build-policy.py
```

This is an absence check, not by itself behavioral regression evidence. The
semantic mutation controls below supply the behavioral red proof.

### Positive contract and full existing selftest

```sh
bash tests/build-contract.sh
bash tests/selftest.sh
scripts/boardctl validate
git diff --check
```

Observed exits: 0, 0, 0, 0. Contract output:

```text
Ran 10 tests in 0.310s
OK
BUILD CONTRACT: PASS (10 tests; hermetic policy only)
```

The first complete selftest rerun reported the existing parser, node checker,
creator/verifier success/failure, verified-fetch digest refusal and missing
boardctl checks PASS; `23/23 rows parse`; the new build contract ran all 10 tests
and printed `SELFTEST: PASS`. The wrong-digest message in the verified-fetch
negative fixture is expected and was followed by `PASS wrong digest refused`.

Board validator:

```text
rows: 23 tasks, 30 events, 0 fixtures
key uniformity: 23/23 rows carry only canon keys (0 drift)
RESULT: OK (1 warning(s))
```

The warning is the pre-existing headerless board: no `board.jsonl`, so header
counter checks were skipped. This is not an unqualified all-checks-passed claim.
No board contents were modified.

### Semantic mutation and propagation controls

```sh
bash tests/build-contract.sh --mutation-controls
```

Observed exit 0; actual normal-test failures were required for each temporary
mutant. First run output:

```text
PASS mutation rejected: project-key (normal tests exit 1)
PASS mutation rejected: trust-key (normal tests exit 1)
PASS mutation rejected: ref-key (normal tests exit 1)
PASS mutation rejected: runtime-key (normal tests exit 1)
PASS mutation rejected: trusted-write (normal tests exit 1)
PASS mutation rejected: integrity (normal tests exit 1)
PASS mutation rejected: control-placement (normal tests exit 1)
PASS selftest propagated build-contract exit 23 (selftest exit 1)
Ran 10 tests in 0.270s
OK
BUILD CONTRACT: PASS (10 tests; hermetic policy only)
```

The mutants drop real identity dimensions, disable the trust-write condition,
disable digest comparison, or permit heavy control-host placement. The test
runner rejects a mutant unless normal unittest assertions fail, rather than
merely treating import/startup failure as proof. All mutant files live in a
private temporary directory and are removed. The propagation control copies the
actual repository selftest and supporting fixtures into scratch, replaces only
that copy's build contract with exit 23, and requires both the injected failure
and `SELFTEST: FAIL`. The final clean helper suite reruns after these controls.

The isolation test changes all 12 context dimensions individually and checks
both distinct keys and actual cache MISS for each; the baseline remains HIT.
Warm reuse asserts bytes/digest plus unchanged blob inode and modification time.
Integrity tests poison source and stored bytes and require rejection without
rewriting the corrupt entry. Heavy placement refuses control even when its
identity is erroneously present in inventory, as well as blank/unknown and
non-admitted identities. The positive remote identity is synthetic admission
input, not evidence that a remote job ran.

### Guard failure, correction, and clean rerun

```sh
timeout 180 gitreins guard --full --scope working-tree
```

First invocation: exit 1, `Tier 1 Guards: FAIL`; secrets clean, tests (full) PASS,
lint failed with `ruff format --check: 1 file(s) would be reformatted` naming only
`scripts/build-policy.py`. No config or gate was weakened. Applied the requested
formatter to that new file only:

```sh
ruff format scripts/build-policy.py
bash tests/build-contract.sh --mutation-controls
ruff check scripts/build-policy.py
```

Observed exits 0, 0, 0; `1 file reformatted`; all seven mutations rejected again,
selftest failure propagated again, and the clean 10 tests passed again (1.413s).
`ruff check` reported `All checks passed!`.

Re-staged the intended helper and reran the same timeout-bounded guard. Observed
exit 0, not timeout, degraded pass or skipped tests:

```text
Tier 1 Guards: PASS  (test mode: full, scope: working-tree, whole tree)
  ✓ secrets — clean (builtin cross-check; gitleaks not run (working-tree scope))
  ✓ lint — ok; scanners: nice=nice -n 10
  ✓ tests (full)
```

The working-tree secrets lane explicitly used its built-in cross-check rather
than gitleaks. Do not describe it as a full-history gitleaks scan. The guard's
full log confirmed actual `bash tests/selftest.sh` output, including the 10 new
policy tests; it was not a no-source short-circuit. Local guard log basenames:
`guard-20261030T075758.185317Z.log` (format failure) and
`guard-20261030T075848.965044Z.log` (PASS), under `.gitreins/logs/`; they are runtime
logs, not committed audit dependencies. `git diff --check` and
`git diff --cached --check` both emitted no errors after formatting.

## Limitations and foreman follow-ups

- No heavy build or install was performed. No disposable Code Factory node was
  authorized or used; no unrelated lab host was treated as one.
- The helper is not wired into an existing remote dispatcher or package-manager
  adapter. Its trusted-caller inputs are policy data, not identity attestation.
  A caller that can lie about trust/root/digest or host inventory is outside
  this kernel's protection. Qualify the authenticated enforcement boundary before
  reuse across jobs. Root filesystem privacy is not hostile multi-tenant isolation.
- Tests exercise real cache bytes but not npm/pip/Go/Cargo/BuildKit cache formats,
  network fetches, build performance, runner registration, host loss, container
  cleanup or physical remote placement. Those infrastructure cells are explicitly
  prospective in BUILD, not invented receipts.
- Per-root serialized writers, small opaque blobs, no archive extraction; native
  adapter concurrency, streaming, quotas, eviction/leases and janitor work remain.
- Self-hosted registration and job credential delivery remain BLOCKED until
  approved separately under NODE-LIFECYCLE's no-provider/operator-keys rule.
  Implement negative repository/job/group routing and teardown/revocation read-back
  tests on an authorized disposable node before certifying the platform.
- CF-019 must supply durable evidence interfaces/backend acceptance; this row
  selects neither shared storage nor a production cache service.
- Foreman owns GitReins task/judge lifecycle, board state and merge. No future
  verdict or self-referential implementation hash is recorded here.
