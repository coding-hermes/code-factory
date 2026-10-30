# CF-002 host-local credential boundary

Task: Host-side inference credential boundary: provider keys stay on host.

Status: partial (local tranche; live acceptance blocked).
Tier: T3 local only. Measured execution results are recorded below.

ch:trace row=CF-002 spec=specs/HARNESS.md#host-only-inference-custody wave=none:serial-manifest-in-control-checkout test=tests/inference-contract.py::InferenceContract.test_http_success_and_evidence doc=docs/THREAT-MODEL.md prompt=none:transient-worker-brief evidence=docs/audits/code-factory-CF-002-local-0937.md witness=none:hermetic-local-only verdict=none:foreman-judge-pending commit=none:self-referential-hash memory=/project/code-factory/status

## Scope

Implement only the host-local proxy and safety contract. Installer refusal remains
unchanged. No node provisioning/reuse, live credentials, upstream inference,
service deployment, Crier transport or remote acceptance is authorized or claimed.
Runtime policy, keys and evidence are outside this repository. Examples/tests use
synthetic credentials and loopback fake upstreams only.

## Discovery

Before design, lab discovery for `authenticated-host-inference-fail-closed-attestation`
returned `not_found`. Corpus mechanism search found unrelated tombstone-auth and
verification entries, no reusable host inference/attestation implementation.
Python's official urllib.request documentation was consulted for explicit proxy
and redirect handlers. Cached material is not a test oracle.

## Verification

All commands ran from the isolated worker branch; only synthetic temporary state
and loopback fake upstreams were used. No provider service or real node was called.

| Command | Observed result |
|---|---|
| `PYTHONDONTWRITEBYTECODE=1 python3 -B tests/inference-contract.py` | Exit 0; 16 tests, 13.193 seconds in the recorded focused run. Real HTTP Server/Handler and subprocess CLI startup, not success-string mocks. |
| `PYTHONDONTWRITEBYTECODE=1 python3 -B tests/inference-mutations.py` | Exit 0; unchanged 16-test control green, 16 semantic mutants rejected, selftest propagated injected inference exit 23. |
| `bash tests/selftest.sh` | Exit 0; SELFTEST: PASS. Named check, 11 node tests, 7 node mutations, 10 build policy tests and 16 inference tests passed. Inference section ran 16 tests in 15.351 seconds. |
| `scripts/boardctl validate` | Exit 0; 24 tasks, 43 events, zero fixtures; 24/24 canon keys. Existing headerless-board warning, no new board write. |
| `PYTHONPYCACHEPREFIX=/tmp/CF-002-0937-bytecode python3 -m py_compile scripts/inference-proxy.py tests/inference-contract.py tests/inference-mutations.py` | Exit 0; bytecode cache outside repository. |
| `bash -n tests/selftest.sh` | Exit 0. |
| `ruff check scripts/inference-proxy.py tests/inference-contract.py tests/inference-mutations.py` | Exit 0; All checks passed. |
| `git diff --check` | Exit 0. |
| `git diff -- scripts/harness/install-hermes.sh AGENTS.md .coding-hermes .gitreins` | Empty before guard; installer, agent guidance and foreman state unchanged. |

Worker-local raw logs (not committed, no credentials):
`/tmp/CF-002-0937-focused.log`, `/tmp/CF-002-0937-mutations.log`,
`/tmp/CF-002-0937-selftest.log`. The executable tests and this result table are the
portable evidence; temporary logs are not assumed available to other hosts.

## Final source guard and review

`timeout 180 gitreins guard --full --scope working-tree` returned exit 0:
Tier 1 Guards: PASS (test mode: full, scope: working-tree, whole tree), secrets
clean (builtin cross-check; gitleaks explicitly not run for this scope), lint ok,
tests (full) passed. Worker-local output: `/tmp/CF-002-0937-guard.log`.
The first attempt returned exit 1 solely because three Python files needed Ruff
formatting; tests were already green. Ran `ruff format` on exactly those three
new files, refreshed the strict mutation anchors to the formatted protection
statements, then reran all semantic controls and the exact guard successfully.
No source-guard bypass or gate-config change was used.

`ruff format --check scripts/inference-proxy.py tests/inference-contract.py
tests/inference-mutations.py` returned exit 0 (3 files already formatted).
The final mutation rerun again rejected all 16 behavioral mutants and propagated
inference exit 23. `git diff --cached --check` returned exit 0. The staged set
contains only the 10 allowed paths, with no installer/AGENTS/board/GitReins edits.

### Exact safety anchors

- `specs/HARNESS.md#host-only-inference-custody` and
  `#host-local-inference-protocol-cf-002-local-tranche`: custody and transport.
- `InferenceContract.test_denials_before_key_resolution`: absent/malformed/unknown
  bearer, expiry/revocation and wrong service/node/project/repository/provider/model
  deny before spy resolver. `test_existing_route_disallowed_before_keys` proves
  a configured-but-unauthorized pair also refuses, then reaches attestation only
  after explicit authorization.
- `test_schema_and_override_denials` and `test_duplicate_and_oversize_http`:
  unknown body fields, streaming, endpoint/header/key overrides, compression,
  unsupported paths/methods, duplicate headers/JSON and size boundary.
- `test_http_success_and_evidence`: scoped success, exact host-resolved upstream
  bearer, no node token forwarded, text projection, requested/served scope evidence.
- `test_attestation_failures_and_error_sentinel`: missing/duplicate/bad/replayed
  attestation, mismatched actual pair, conflicting response label, upstream key
  echo, tool output, oversize, auth error, 503 and redirect. Only fixed client
  errors; no credential in responses/evidence.
- `test_fallback_authorized_and_disallowed`: disallowed fallback refuses before
  keys; authorized fallback uses real HTTP/HMAC and records provider-a requested
  versus provider-b served. Wrong fallback actual provider still refuses.
- `test_no_fallback_on_attestation_or_auth_error`: only retryable failures fall back.
- `test_redirect_and_environment_proxy_not_forwarded`: fake sink receives no
  requests/credentials via redirect or environment proxy; removing each protection
  separately makes a behavioral assertion fail.
- `test_host_files_and_policy_fail_closed`: private mode, single-link regular
  type, symlink/FIFO/directory and malformed policy checks; runtime policy reload.
- `test_restart_revocation_rotation_and_corruption`: prefix-preserving journal
  restart, revocation/token rotation, torn/invalid/hash-corrupt/reordered evidence,
  and competing journal lock. No automatic repair.
- `test_evidence_write_failure_before_key_and_success` and
  `test_evidence_replacement_and_partial_write`: failed intent fsync prevents key
  reads, failed final append prevents 200, poison state, replacement and short-write
  corruption fail closed. Final append failure is injected at the journal method;
  the intent fsync/short write exercise real filesystem calls with fault injection.
- `test_real_cli_invocation_and_redacted_logs`: executable startup and HTTP
  success/auth-error calls; captured stdout/stderr contain only the measured
  loopback startup port, no runtime/access/exception logging or synthetic secrets.
- `test_request_and_upstream_socket_timeouts`: actual incomplete-body and delayed
  upstream sockets with a reduced test timeout; no key resolution on body timeout.
- `test_installer_sentinel_and_no_transport_copy`: real installer both modes refuse
  with a legacy .env FIFO (reading would block), then preserve a synthetic legacy
  env file without creating node manifest/bundle/artifact or emitting its sentinel.
  Host provider bearer goes ONLY to the host-selected fake upstream, never node
  configuration or the node-facing transport. This does not claim any installer
  proxy configuration, bus transport or node identity delivery implementation.

### Semantic negative controls

The mutation runner first executes unchanged real-boundary tests, then compiles
and runs private altered source copies. Every mutant must exit 1 with a named
AssertionError/FAILED(failures), no ERROR/import/bootstrap failure. Removed controls:
scope, expiry/revocation, bearer digest match, pair/fallback authorization, auth
before credential resolution, HMAC signature, exact served pair, known-credential
response guard, private file mode, single-link file, no-follow open, success
journal append, journal fsync, journal hash integrity, redirect denial and explicit
environment-proxy disabling. All 16 went red on their safety assertion. Mutant
copies are temporary and never modify the implementation under test in the tree.
A private selftest copy with inference exit 23 returned SELFTEST: FAIL.

## Debugging receipt

The initial focused run exposed a client/protocol mismatch: stdlib http.client
implicitly adds Accept-Encoding: identity. The strict allowlist refused valid
calls with 403. Added only identity encoding, retaining a gzip denial fixture;
real HTTP and CLI positive controls then passed. Before debugging, discovery for
`python-http-client-implicit-accept-encoding-strict-header-denial` returned not_found;
corpus search had only an unrelated HPACK answer. After reading the lab submit
schema, the post-debug submission returned receipt `sub_0bd6da`; exact queue-item
readback confirmed that class and pending/queued status. Receipt is not a solved
or verified lab answer. No credentials or private infrastructure identifiers were
included in the submission.

## Review and residual blockers

The implementation is wired only as `scripts/inference-proxy.py` and the actual
selftest inference section. All changes are confined to the allowed proxy/tests,
governing contracts and this audit; no dependencies, deployment, external project
changes or gate configuration. Installer refusal is byte-unchanged.

Trusted adapter HMAC verifies a request/body-bound assertion, not actual model
truth by itself. A generic provider without that attestor is rejected. Runtime
policy/keys/evidence remain operator-owned outside the repo. Token issuance,
node adapter/delivery/deletion, authenticated Crier transport and dispatch evidence
correlation remain unimplemented. No private endpoint, TLS ingress/topology or
owner-authorized disposable remote node was supplied/qualified for this tranche.
No live remote execution, production readiness or full CF-002 acceptance is claimed.

Application append-only evidence is not OS-immutable: host rollback/deletion/full
chain rewrite remains possible; no off-host witness. A crash may leave intent
without terminal result. Per-socket deadlines, serial HTTP and bounded bodies do
not supply total deadlines, rate limits, per-job quotas or a production sandbox.
Revocation is effective on the next authorization, not retroactively in flight.
The foreman owns board disposition, judging and merge; CF-002 stays partial.
