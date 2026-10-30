
### quickstart-bunker-check
$ env -u BUNKER_SERVER HOME=/var/tmp/code-factory-readme-20261030-110314.G1KJIP bash scripts/bunker-server-install.sh --check
scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name
RC=1

### quickstart-project-node
$ env -u BUNKER_SERVER -u CRIER_URL HOME=/var/tmp/code-factory-readme-20261030-110314.G1KJIP bash scripts/project-node.sh --check --project \<project\>
node provisioning — project=<project> harness=hermes host=karaHermes-mde-7840hs
[00] preflight
  PASS  arch — x86_64 (Linux 7.0.0-38-generic)
  PASS  disk — 117.8 GB free (floor 5 GB)
  PASS  mem — 46226 MB
  FAIL  crier_url — CRIER_URL unset — the node has nothing to connect to (export CRIER_URL=http://crier.example:8767)
[10] base
  PASS  tool:python3 — /home/kara/.hermes/hermes-agent/venv/bin/python3
  PASS  tool:git — /usr/bin/git
  PASS  tool:curl — /usr/bin/curl
  PASS  tool:tar — /usr/bin/tar
  PASS  tool:sha256sum — /usr/bin/sha256sum
  PASS  python:venv — importable
  PASS  tool:jq — /usr/bin/jq
  PASS  tool:rg — /usr/bin/rg
  PASS  tool:node — /home/kara/.local/bin/node
[20] harness
  FAIL  inference_integration — UNIMPLEMENTED / BLOCKED: CF-002 host inference proxy and node-scoped identity required; node provider keys unsupported
HERMES: FAIL (1)
  FAIL  harness_check — hermes adapter exited 1
[30] bus
  FAIL  crier_identity — absent — stage a bundle and re-run; a node without an identity is invisible
  FAIL  crier_base — unset — manifest cannot identify the bus
[40] repo
  FAIL  repo — /var/tmp/code-factory-readme-20261030-110314.G1KJIP/repo absent (pass --repo to clone)
[90] manifest
  ..    manifest is written only when every layer passes

NODE: FAIL (5)
RC=1

### selftest
$ env HOME=/var/tmp/code-factory-readme-20261030-110314.G1KJIP bash tests/selftest.sh
1. every script parses
  PASS  bash -n bunker-server-install.sh
  PASS  bash -n lib.sh
  PASS  bash -n node-create.sh
  PASS  bash -n project-node.sh
  PASS  bash -n readme-audit-20261030-110314.sh
  PASS  bash -n verify-node.sh
  PASS  bash -n install-claude-code.sh
  PASS  bash -n install-hermes.sh
  PASS  bash -n install-opencode.sh
  PASS  bash -n build-contract.sh
  PASS  bash -n selftest.sh
2. node --check has exactly the controlled named failure (local fixtures)
test_named_check (__main__.NodeContract.test_named_check) ... ok

----------------------------------------------------------------------
Ran 1 test in 0.080s

OK
  PASS  nonzero exit and anchored exact FAIL crier_url; no bootstrap decoy
3. specs and scripts expose the same node contract
  PASS  required contract NODE.md exists
  PASS  required contract ENVELOPE.md exists
  PASS  required contract HARNESS.md exists
  PASS  required contract DESIGN.md exists
  PASS  required contract THREAT-MODEL.md exists
  PASS  DESIGN names project-node.sh --check|--apply
  PASS  DESIGN names node-create.sh --project P --repo URL --harness H
  PASS  DESIGN names verify-node.sh --agent ID --artifact PATH
  PASS  envelope declares idempotency_key
4. focused node contracts and executable mutation controls (local, not live)
test_artifact_denials_before_remote_shell (__main__.NodeContract.test_artifact_denials_before_remote_shell) ... ok
test_artifact_symlink_hardlink_and_positive (__main__.NodeContract.test_artifact_symlink_hardlink_and_positive) ... ok
test_creator_preconditions_and_exact_triple (__main__.NodeContract.test_creator_preconditions_and_exact_triple) ... ok
test_creator_stops_on_provision_failure (__main__.NodeContract.test_creator_stops_on_provision_failure) ... ok
test_forbidden_manifest_paths_without_dispatch_option (__main__.NodeContract.test_forbidden_manifest_paths_without_dispatch_option) ... ok
test_hermes_inference_blocked_without_reading_keys (__main__.NodeContract.test_hermes_inference_blocked_without_reading_keys) ... ok
test_manifest_identity_and_byte_idempotence (__main__.NodeContract.test_manifest_identity_and_byte_idempotence) ... ok
test_manifest_write_failure (__main__.NodeContract.test_manifest_write_failure) ... ok
test_manifest_writer_error_is_not_pass (__main__.NodeContract.test_manifest_writer_error_is_not_pass) ... ok
test_named_check (__main__.NodeContract.test_named_check) ... ok
test_verifier_auth_and_digest_fail_closed (__main__.NodeContract.test_verifier_auth_and_digest_fail_closed) ... ok

----------------------------------------------------------------------
Ran 11 tests in 3.870s

OK
PASS local mutation named-failure-removed: control=0 mutant=1 assertion=test_named_check
PASS local mutation bootstrap-error-decoy: control=0 mutant=1 assertion=test_named_check
PASS local mutation repo-precondition-removed: control=0 mutant=1 assertion=test_creator_preconditions_and_exact_triple
PASS local mutation artifact-local-scope-removed: control=0 mutant=1 assertion=test_artifact_denials_before_remote_shell
PASS local mutation artifact-nofollow-removed: control=0 mutant=1 assertion=test_artifact_symlink_hardlink_and_positive
PASS local mutation manifest-write-status-ignored: control=0 mutant=1 assertion=test_manifest_writer_error_is_not_pass
PASS local mutation manifest-identity-ignored: control=0 mutant=1 assertion=test_manifest_identity_and_byte_idempotence
MUTATIONS: PASS (7 local executable controls; no live proof)
  PASS  node contracts and mutation controls
5. fetch_verified refuses a wrong digest
  PASS  correct digest accepted
digest mismatch for file:///var/tmp/hermes-scratch/tmp.XuuMX8yMyZ/src: want 0000000000000000000000000000000000000000000000000000000000000000 got 5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03
  PASS  wrong digest refused
6. no literal credential assignments
  PASS  none found
7. the board is valid JSONL
  PASS  26/26 rows parse
8. board entrypoint fails closed without dependency
  PASS  bash -n scripts/boardctl
  PASS  local help
  PASS  missing boardctl -> explicit FAIL, exit 127
9. build/cache policy contract (local, not live infrastructure)
test_all_key_dimensions_isolate_bytes (__main__.Contract.test_all_key_dimensions_isolate_bytes) ... ok
test_cache_reuse (__main__.Contract.test_cache_reuse) ... ok
test_canonical_key_and_ambiguous_inputs (__main__.Contract.test_canonical_key_and_ambiguous_inputs) ... ok
test_cli_failures_and_real_bytes (__main__.Contract.test_cli_failures_and_real_bytes) ... ok
test_failed_integrity_not_reused (__main__.Contract.test_failed_integrity_not_reused) ... ok
test_heavy_remote_admission (__main__.Contract.test_heavy_remote_admission) ... ok
test_host_loss_cold_recovery (__main__.Contract.test_host_loss_cold_recovery) ... ok
test_input_validation (__main__.Contract.test_input_validation) ... ok
test_private_root_and_symlinks (__main__.Contract.test_private_root_and_symlinks) ... ok
test_untrusted_writes_denied (__main__.Contract.test_untrusted_writes_denied) ... ok

----------------------------------------------------------------------
Ran 10 tests in 0.200s

OK
BUILD CONTRACT: PASS (10 tests; hermetic policy only)
  PASS  build contract
10. host-local inference boundary (no deployment or remote acceptance)
test_attestation_failures_and_error_sentinel (__main__.InferenceContract.test_attestation_failures_and_error_sentinel) ... ok
test_denials_before_key_resolution (__main__.InferenceContract.test_denials_before_key_resolution) ... ok
test_duplicate_and_oversize_http (__main__.InferenceContract.test_duplicate_and_oversize_http) ... ok
test_evidence_replacement_and_partial_write (__main__.InferenceContract.test_evidence_replacement_and_partial_write) ... ok
test_evidence_write_failure_before_key_and_success (__main__.InferenceContract.test_evidence_write_failure_before_key_and_success) ... ok
test_existing_route_disallowed_before_keys (__main__.InferenceContract.test_existing_route_disallowed_before_keys) ... ok
test_fallback_authorized_and_disallowed (__main__.InferenceContract.test_fallback_authorized_and_disallowed) ... ok
test_host_files_and_policy_fail_closed (__main__.InferenceContract.test_host_files_and_policy_fail_closed) ... ok
test_http_success_and_evidence (__main__.InferenceContract.test_http_success_and_evidence) ... ok
test_installer_sentinel_and_no_transport_copy (__main__.InferenceContract.test_installer_sentinel_and_no_transport_copy) ... ok
test_no_fallback_on_attestation_or_auth_error (__main__.InferenceContract.test_no_fallback_on_attestation_or_auth_error) ... ok
test_real_cli_invocation_and_redacted_logs (__main__.InferenceContract.test_real_cli_invocation_and_redacted_logs) ... ok
test_redirect_and_environment_proxy_not_forwarded (__main__.InferenceContract.test_redirect_and_environment_proxy_not_forwarded) ... ok
test_request_and_upstream_socket_timeouts (__main__.InferenceContract.test_request_and_upstream_socket_timeouts) ... ok
test_restart_revocation_rotation_and_corruption (__main__.InferenceContract.test_restart_revocation_rotation_and_corruption) ... ok
test_schema_and_override_denials (__main__.InferenceContract.test_schema_and_override_denials) ... ok

----------------------------------------------------------------------
Ran 16 tests in 13.823s

OK
  PASS  inference contract
SELFTEST: PASS
RC=0

### configured-bunker-check
$ env HOME=/var/tmp/code-factory-readme-20261030-110314.G1KJIP BUNKER_SERVER=your-bunker-server bash scripts/bunker-server-install.sh --check
bunker server: your-bunker-server
  PASS  bunker_client — /home/kara/.local/bin/bunker bunker 0.2.0
  FAIL  bunker_config — missing (/var/tmp/code-factory-readme-20261030-110314.G1KJIP/.config/bunker/config.yaml) — the client has no server to talk to
  FAIL  server_reachable — your-bunker-server did not answer: bunker: reading server "your-bunker-server"
  PASS  tool:python3 — /home/kara/.hermes/hermes-agent/venv/bin/python3
  PASS  tool:git — /usr/bin/git
  PASS  tool:curl — /usr/bin/curl
  PASS  tool:jq — /usr/bin/jq
  PASS  disk — 117.8 GB free (floor 5 GB)

RESULT: FAIL (2)
RC=1

### node-create-refusal
$ env HOME=/var/tmp/code-factory-readme-20261030-110314.G1KJIP BUNKER_SERVER=your-bunker-server CRIER_URL=http://crier.example:8767 bash scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes
node-create — project=myrepo harness=hermes server=your-bunker-server
  ..    spawning node-myrepo-064312 (ttl 6h)
  FAIL  spawn — bunker: server "your-bunker-server" not found in config
RC=1

### hermes-check
$ env HOME=/var/tmp/code-factory-readme-20261030-110314.G1KJIP bash scripts/harness/install-hermes.sh --check
  FAIL  inference_integration — UNIMPLEMENTED / BLOCKED: CF-002 host inference proxy and node-scoped identity required; node provider keys unsupported
HERMES: FAIL (1)
RC=1

### opencode-check
$ env HOME=/var/tmp/code-factory-readme-20261030-110314.G1KJIP bash scripts/harness/install-opencode.sh --check
harness: opencode (UNVERIFIED adapter)
  PASS  binary — /home/kara/.opencode/bin/opencode
  PASS  version — 1.18.29
  WARN  user_space_binary — not installed under $HOME
  WARN  non_interactive — could not confirm a non-interactive mode

OPENCODE: PASS
RC=0

### claude-check
$ env HOME=/var/tmp/code-factory-readme-20261030-110314.G1KJIP bash scripts/harness/install-claude-code.sh --check
harness: claude-code (UNVERIFIED adapter)
  FAIL  binary — absent
  PASS  node — /home/kara/.local/bin/node (v22.22.3)
  PASS  npm — /home/kara/.local/bin/npm
  WARN  auth — no ANTHROPIC_API_KEY and no ~/.claude/.credentials.json — unattended runs will fail

CLAUDE-CODE: FAIL (1)
RC=1

### tracked-harness-files
scripts/harness/install-claude-code.sh
scripts/harness/install-hermes.sh
scripts/harness/install-opencode.sh

### readme-fences
17:```bash
26:```
30:```
39:```
76:```bash
82:```

### env-read-sites
$AGENT
${ANTHROPIC_API_KEY
$ARTIFACT
${BUNKER_CONFIG
${BUNKER_SERVER
$BUS_AGENT_ID
$BUS_BASE
$CRIER
${CRIER_AGENT_ID
${CRIER_BASE
${CRIER_URL
$DISPATCH
$FAILED
$FLOOR
$HARNESS
$HERE
$HOME
$MODE
${NODE_DISK_FLOOR
${NODE_GATEWAY_PORT
${NODE_HARNESS
${NODE_ID
${NODE_PROJECT
${NODE_REF
$PORT
$PROJECT
$REF
$REPO
$SERVER
$STATE
${TMPDIR
$TTL

### scratch-home
/var/tmp/code-factory-readme-20261030-110314.G1KJIP
