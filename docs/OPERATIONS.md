# code-factory operations runbook

**Status: design/runbook, not an installation receipt.** This document distinguishes repository evidence from proposed operator work. No bunker, gateway, crier, scheduler, or remote node was provisioned or changed while writing it. Re-check all prerequisites at execution time; do not infer live readiness from this file.

## Operating model and ownership

One isolated bunker agent is one project node: one repo, one harness, one crier identity. The control host's Hermes foreman defines work and verifies results; task-router selects model/provider; scheduler selects the lane and dispatch time; crier transports durable messages; the node runs the harness in its repo. The node reports evidence but does not grade itself. See [DESIGN](DESIGN.md), [NODE](../specs/NODE.md), and [ENVELOPE](../specs/ENVELOPE.md).

The intended lifecycle is: qualify control host → create and provision a node → establish gateway and bus identity → attach repo/harness → arm scheduler target only after checks → dispatch one bounded task → independently verify artifacts → recover or rebuild from evidence → revoke and remove all state on teardown.

**Current implementation boundary:** the checked-in scripts do not yet implement that complete lifecycle. In particular, `scripts/node-create.sh` stages scripts and calls node provisioning, but does not stage the required crier identity bundle; `project-node.sh` therefore fails its bus layer on a fresh node. README also records node inference credentials missing, crier identity missing, scheduler→crier dispatch built but disarmed, and a round trip through the node's own gateway not yet proven. Treat creation, dispatch, rebuild, and end-to-end operations as **BLOCKED / NOT YET** until the gates below have been implemented and observed. Do not call them live operations.

## Readiness labels

- **MEASURED (repository evidence):** the spec or script records a measurement. This is not proof of the current host's health.
- **CHECK LOCALLY:** an exact read-only command exists; run it in the intended environment and preserve its output.
- **BLOCKED:** a required capability or prerequisite is absent or not verified. Do not proceed past that gate.
- **NOT YET:** designed behavior that has not been exercised through the production path.

## 1. Prerequisites and preflight

### Control host

1. Set `BUNKER_SERVER` to the operator's configured bunker server name; configure the bunker client and credentials out of band. These values are environment-specific and must not be committed or pasted into tickets.
2. Run the repository's actual control-host check:

   ```bash
   BUNKER_SERVER="$BUNKER_SERVER" scripts/bunker-server-install.sh --check
   ```

   It checks for the `bunker` client, the configured server entry in `${BUNKER_CONFIG:-$HOME/.config/bunker/config.yaml}`, `bunker list --server`, `bunker status --server`, control tools (`python3`, `git`, `curl`, `jq`) and 5 GB free under `$HOME`. `WARN` on an optional control tool is not the same as a complete operational proof. A non-zero result or failed server reachability blocks provisioning.
3. The script accepts `--json`, but has no `--help` interface. Its source is `scripts/bunker-server-install.sh`. Do not run `--apply`: there is no `--apply` implementation in this script; it is a qualification check, not a server installer.

### Node

The node contract requires architecture, disk at or above the configured floor, at least 1024 MB available memory, crier and PyPI reachability, `python3` with `venv`, `git`, `curl`, `tar`, and `sha256sum`. Optional tools checked with warnings are `jq`, `rg`, and `node`. The default script floor is 5 GB; the design's measured example footprint is about 1.5 GB per repo node and the floor is intended to retain working room. Use measured values, not those planning estimates, for a decision.

`project-node.sh --check` is **not a pure read-only check**: it creates `$HOME/.node` before checking. Run only on a designated test node, and account for that directory as a side effect. It requires `CRIER_URL`, and tests `CRIER_URL/health` and `https://pypi.org/simple/` for HTTP 200. The script also executes the harness adapter's `--check`.

**BLOCKED on a fresh node:** `project-node.sh` requires `$HOME/.node/crier.json` with mode `600`; there is no checked-in secure identity-provisioning command or bundle transfer path. Do not hand-create a fake identity or copy credentials via command arguments. The documented secure bundle workflow (one mode-600 bundle, deleted after provisioning) is a requirement, not a currently supplied operation.

## 2. Provisioning and node identity

### Exact available entry points

- Control-host qualification: `scripts/bunker-server-install.sh --check`.
- Node creation orchestrator: `scripts/node-create.sh --project P --repo URL [--harness H] [--agent ID] [--ttl 6h] [--port 10800]`; requires `BUNKER_SERVER` in the environment. Defaults are harness `hermes`, TTL `6h`, port `10800`; if no agent ID is given, its code generates `node-P-<time>` and attempts to spawn/reuse it.
- In-node provisioning/check: `project-node.sh --apply|--check --project P [--harness H] [--repo URL] [--ref main] [--port 10800]`. `scripts/node-create.sh` stages and calls this command remotely. `project-node.sh` defaults to ref `main`, port `10800`, disk floor 5 GB, and repo path `$HOME/repo`.
- From the repository root, the script is also invoked as `scripts/project-node.sh --check --project P` (or `--apply` with the required arguments). The README's quick start's `--agent` argument is not accepted by `project-node.sh`; `--agent` belongs to `node-create.sh`.

Do not put a literal private URL, host, key, or ID into this public runbook. Substitute operator-owned values at execution time. Never put secrets into arguments, shell history, logs, task rows, manifest, or source control. The repository scripts quote some values into a remote shell command; only pass values that have been validated for safe syntax and never credentials. The current scripts have not demonstrated a hardened quoting/validation contract for arbitrary input.

### BLOCKED provisioning path

`node-create.sh` is not a complete safe production provisioner yet:

- It does not transfer the required `$HOME/.node/crier.json` identity bundle or configure crier's pull worker.
- It does not establish an inference credential. The Hermes installer only checks for a provider-key assignment in `~/.hermes/.env` and intentionally does not read the value; a Hermes turn without one fails with `No inference provider configured`.
- `project-node.sh` writes a manifest only when all its layers pass, but its manifest generation currently embeds `repo` and `ref` inputs; `node-create.sh` invokes it without passing `--ref`, while the clone uses the default `main`. Review before relying on manifest provenance.
- `node-create.sh` continues to verification after provisioning failure, and only logs spawn output to `/tmp/spawn.log`; a failed/incomplete node must be treated as quarantined, not scheduled.
- It creates a node using a default `--ttl 6h`; no measured renewal/lease procedure is provided here.

Accordingly, **do not use `scripts/node-create.sh` to create a production node until the secure bus identity and inference setup path is completed and the whole round trip is verified.** There is no separate checked-in renew, destroy, or rebuild command. Those lifecycle actions are **BLOCKED / NOT YET**; see §8.

### Private repositories

`project-node.sh` clones `--depth 1 --branch "$REF"` into `$HOME/repo`. Public HTTPS cloning is the only repository case marked working in README. A private repo needs a deploy key per the script's own error message; no key installation or rotation procedure is provided. Do not forward an operator's personal key. Provision a narrowly scoped read/write credential by an approved external secret-delivery process, then verify revocation and non-disclosure. Until that process exists and has been tested, private-repo node provisioning is **BLOCKED**.

## 3. Harness, gateway, and authentication

### Hermes (only adapter with a measured install ladder)

`specs/HARNESS.md` records a test-node measurement: Hermes Agent 0.19.0 installed in about 32 seconds, 248 MB venv; a gateway on the configured port answered `/api/status` with 200 over tailnet, and exposed 133 JSON-RPC methods. That historical measurement does not prove this node is working now. Use the exact adapter check/apply from inside the node:

```bash
scripts/harness/install-hermes.sh --check
scripts/harness/install-hermes.sh --apply
```

The script defaults to pin `0.19.0`, overridable with `HERMES_PIN`, uses `$HOME/hermes-venv`, and port `10800`, overridable with `NODE_GATEWAY_PORT`. It runs `hermes serve --host 0.0.0.0 --port PORT --skip-build` under `nohup`, logging to `$HOME/.node-serve-PORT.log`. It refuses to start a public bind unless `$HOME/.hermes/config.yaml` contains `basic_auth`. An inference provider key must be configured out of band in `$HOME/.hermes/.env`; never print or transmit its value. `--check` verifies presence but does not prove the provider can complete an inference request.

After apply, check again and require `/api/status -> 200`. The current implementation uses a substring check for `basic_auth`; it does not independently validate the strength or correctness of the configured secret. `verify-node.sh` checks status and tests that unauthenticated `/api/system/stats` is refused with 401, 302, or 403. Require this test to pass before admitting work. A `WARN` is not approval to expose the gateway.

**Network boundary:** the gateway binds `0.0.0.0`; restrict access at the network/firewall layer to the approved private overlay and intended control host. Do not expose it to the public internet. Tailnet reachability is not authentication. Keep basic-auth credentials and inference keys distinct, scoped, rotated, and out of argv/logs. If unauthenticated stats returns 200, quarantine the node immediately and close access before further testing.

### Other adapters

`install-opencode.sh` and `install-claude-code.sh` expose real checks but explicitly mark their install ladders unverified; their `--apply` paths refuse. `specs/HARNESS.md` identifies Codex, aider, goose, and pi-agent as not measured, and no corresponding installer is tracked for those names. Do not use them for production work or imply support. A passing adapter `--check` alone does not override an unmeasured/refused `--apply`.

## 4. Repo and workspace

The node repo lives at `$HOME/repo`; the manifest is `$HOME/.node/node.json`. Confirm the origin/ref/commit against the intended project and verify the branch/worktree is safe for the task before dispatch. Node checks currently validate only that `.git` exists and report a short HEAD; they do not verify remote identity, pinned commit provenance, branch protection, or a clean tree. Those are operator gates, not currently automated proofs.

For public HTTPS, clone is implemented by `project-node.sh --apply --project P --repo URL --ref REF`. A repo already present is accepted without update or reset. The script warns are absent for dirty-at-provision handling; do not reset/delete a repo with uncollected work. Private clone is blocked until a deploy-key procedure is tested. The node contract requires isolated workspace per project and a fresh branch or worktree per dispatch attempt for idempotent retry; the current scripts do not create per-dispatch worktrees or enforce this rule.

## 5. Crier and scheduler wiring

The architectural sequence is bus before workspace: install a node identity with mode `600`, start its pull worker, verify it can receive and reply through crier, then configure a scheduler target that names the node. A dispatched job must carry the required `text`, `dispatch_id`, correlation/idempotency data, brief digest and limits as specified in [ENVELOPE](../specs/ENVELOPE.md). Do not invent reserved JSON keys: crier rejects keys matching `system`, `instructions`, `prompt`, `tools`, or `schema` with `403 GUARD_BLOCKED`. Change the envelope spec first if vocabulary must change.

**Current state: BLOCKED / NOT YET.** README says crier identity is missing and scheduler→crier dispatch is built but disarmed, requiring two environment variables, one target row, and `payload.text`. The node's bus worker and identity staging are not provided in the tracked script inventory; no Crier registration/target-enablement command is documented here. Scheduler lane setup scripts are present (`scripts/load_lane_config.py`, `scripts/add_family_lanes.py`), but are environment-specific, not node target wiring: they hard-code local scheduler DB/API paths, control-host directories and service token lookup. They must not be run as general setup commands or copied into this public runbook as a portable procedure. Inspect them and use only under the owning control-plane operator's reviewed procedure.

Before arming any target, verify all of: correct node identity and crier base; mode-600 identity file; worker alive; scheduler target points to exactly that node; enabled lane has the intended workdir/prompt/admission mode; `payload.text` is present; the node can return the result envelope; and no other project shares the node. No live Crier or scheduler integration test was performed for this runbook; do not enable dispatch based on source/config alone.

## 6. Dispatch and round-trip verification

**NOT YET:** no checked-in command dispatches a production job through crier into the node's own gateway and returns a verified result. The design flow is: foreman briefs → scheduler chooses a turn → crier delivers an inbox message → node verifies digest and runs harness → node replies and acknowledges only after delivery → control host pulls artifact bytes and recomputes every digest. The intended result includes node host identity, harness/model, exit codes, branch/commit, artifact path/sha256/bytes and finish time.

Until the end-to-end path exists:

1. Keep the scheduler target disarmed; do not dispatch real work through a bespoke poller and report it as proof of the intended system.
2. On a designated test node only, verify node/harness state with `scripts/project-node.sh --check --project P` and the selected adapter's `--check`.
3. Use `scripts/verify-node.sh --agent ID --server NAME --port PORT [--artifact PATH]` from the control host to check agent exec, gateway `/api/status`, unauthenticated stats rejection and (if supplied) a downloaded artifact's SHA-256 equality. Required environment: `BUNKER_SERVER` unless `--server` is supplied. This does **not** prove crier delivery, inference, task execution, result envelope, or scheduler admission.
4. Mark a node **verified for work** only after a real dispatch/result round trip has completed, the control host has recomputed each digest from received bytes, and the foreman independently accepts the work. No current repository command demonstrates that full criterion.

Do not accept the node's self-reported digest as proof. A digest mismatch is FAIL and the node stays quarantined until investigation and a fresh passing `--check` plus round trip.

## 7. Verification checklist and evidence

Before admission, retain non-secret evidence with timestamps and exact measured values:

- Control host: `scripts/bunker-server-install.sh --check` output and exit status.
- Node: `project-node.sh --check --project P` output; disk and memory values; crier reachability; harness check output; manifest metadata (exclude secrets).
- Gateway: `/api/status` HTTP 200 from control host, correct node/port, plus unauthenticated stats rejected. `scripts/verify-node.sh` implements these probes.
- Repo: intended origin/ref and HEAD; worktree/branch isolation; no unexpected changes.
- Bus: node identity mode 600 and worker status, plus a received-and-returned dispatch correlation id. **No supported script currently produces this proof.**
- Artifact: preserve received bytes; recompute `sha256sum` at the control host and compare to envelope digest and byte count.
- Quality: run the task's declared gate and retain its exit code/log; foreman reviews content independently.

For this repository itself, the available local test is:

```bash
tests/selftest.sh
```

It checks shell syntax, a node-checker failure path, `fetch_verified` digest mismatch handling, literal credential assignments, and board JSONL parseability. It passed during runbook authoring. It is not a live node, gateway, crier, scheduler or end-to-end test.

## 8. Failure recovery, renew, destroy, rebuild

### Triage and quarantine

- **Control host/server unavailable:** stop provisioning; preserve output from the failed check. Do not create orphan agents or bypass the client/config check.
- **Node unreachable or gateway check fails:** stop admission, disable the scheduler target using the approved scheduler operator procedure (no such command is supplied here), retain the message for redelivery, and inspect the node/gateway logs without exposing credentials. Repair access/auth and rerun checks before re-admission.
- **Inference provider missing/invalid:** no task turn is valid evidence. Configure a node-specific credential via an approved secret channel, restart only under an approved procedure, and prove inference without printing the key. Rotation/revocation automation is NOT YET documented.
- **Crier identity missing, mode not 600, or worker unavailable:** node is invisible; do not dispatch. Restore through the approved secure identity-bundle process. That process is BLOCKED / NOT YET in this repository.
- **Envelope rejected:** inspect the crier response. If `403 GUARD_BLOCKED`, correct the envelope field per `specs/ENVELOPE.md`; do not weaken or evade the guard.
- **Node dies mid-job:** assume message may redeliver. Before retry, use `dispatch_id`/idempotency key and a fresh branch/worktree so the work is not duplicated. The repo scripts do not currently automate this recovery.
- **Digest mismatch, missing commit, gate failure, or unverifiable result:** mark run FAIL, quarantine node, preserve received evidence, recompute digest, inspect exact commit/artifact, and do not let the node grade itself.
- **Disk below floor:** node must refuse new work. Reclaim only known disposable build/job caches; measure free space afterward. Do not delete repo data or unverified artifacts.

### Renew / destroy / rebuild

There is no checked-in command or measured procedure for renewing a bunker agent TTL, destroying an agent, preserving/revoking credentials, or rebuilding from a manifest. The default node-create TTL is `6h`; that is not a renewal workflow. These steps are **BLOCKED / NOT YET**. Do not guess bunker CLI flags, manually delete homes, or assume deleting the agent revokes external keys.

A future approved lifecycle procedure must: disarm scheduler target first; drain or preserve inbox/result state; stop the node worker/gateway; record required repo branch/commit and evidence; revoke node-only crier/inference/deploy credentials; destroy only that node; verify the old identity cannot authenticate; provision a fresh isolated node; re-issue a new identity; run all checks and a fresh round trip; then re-arm the scheduler target. Destruction/rebuild was not performed or tested here.

## 9. Teardown

No teardown script is currently tracked. Until one is added and verified, teardown is a **manual, operator-owned, BLOCKED** change—not a guessed command. Required teardown outcomes are: scheduler target disarmed and read back; crier identity/permissions revoked; node pull worker and gateway stopped; bunker agent destroyed through the documented bunker control plane; node-specific credentials revoked; retained work/artifacts archived or explicitly discarded; and a final check that the old endpoint and identity no longer work. Verify each external state change by reading it back. Preserve the repo and evidence unless the operator explicitly authorizes deletion.

## 10. Security boundaries

- **Least privilege / no root:** the node contract forbids root, passwordless sudo and apt. Install only under `$HOME`; a step requiring root is a blocker.
- **Secrets:** credentials never travel in argv or appear in logs, board rows, manifests, specs, tests, or public docs. One node-specific bundle file, mode `600`, deleted after use is the documented design; transfer, deletion, rotation, and revocation are not yet implemented end to end. Never substitute an operator-wide credential.
- **Gateway:** public bind requires basic auth. Restrict the `0.0.0.0` listener to an approved private network; require a failing unauthenticated stats request. Never treat tailnet membership or `/api/status` as sufficient authentication.
- **Downloads:** use pinned, digest-checked downloads (`fetch_verified` in `scripts/lib.sh`) and never `curl | sh`. The Hermes package install is pinned by package version; do not claim it is artifact-digest verified unless the actual package artifact is checked.
- **Isolation:** one project/repo/harness/identity per node. The current scripts do not enforce all isolation properties or create per-dispatch worktrees; verify externally or block.
- **Transport guard:** preserve crier's reserved-key rejection. `payload.text` is mandatory; do not put arbitrary control directives or secrets in payload fields.
- **Public repo:** no private endpoint, host, username, token, key, project-internal path, or personal data. Existing environment-specific scripts are evidence of local wiring, not values to copy into public docs.
- **Independent verification:** node output is untrusted until artifacts and digests are read and recomputed on the control host and the foreman accepts the result.

## 11. Tracked command inventory and limitations

| Path | Exact available purpose / invocation | Boundary |
|---|---|---|
| `tests/selftest.sh` | Repository self-tests | Local tests only; not integration proof. |
| `scripts/bunker-server-install.sh --check` | Control host/client/server qualification; requires `BUNKER_SERVER` | Check-only; no server install operation. |
| `scripts/project-node.sh --check --project P` | In-node layer checks | Creates `$HOME/.node`; requires crier URL and identity; not pure read-only. |
| `scripts/project-node.sh --apply --project P --harness hermes --repo URL --ref REF` | In-node provisioning | Requires bus identity and provider/auth preconfiguration; do not use for production until secure path exists. |
| `scripts/node-create.sh --project P --repo URL --harness hermes [--agent ID] [--ttl 6h] [--port 10800]` | Control-host spawn/stage/provision/verify orchestrator | Incomplete: no secure bus bundle, no full lifecycle or round trip. |
| `scripts/verify-node.sh --agent ID --server NAME --port 10800 [--artifact PATH]` | Gateway/auth and optional artifact byte digest checks | Does not verify crier, scheduler, inference, or task completion. |
| `scripts/harness/install-hermes.sh --check\|--apply` | Hermes adapter check/install/start | Must configure basic auth and inference key out of band; current check may fail if gateway is not already running. |
| `scripts/harness/install-opencode.sh --check\|--apply` | OpenCode adapter check/refusal | `--apply` refuses until ladder is measured. |
| `scripts/harness/install-claude-code.sh --check\|--apply` | Claude Code prerequisite check/refusal | `--apply` refuses until ladder is measured. |
| `scripts/load_lane_config.py` | Configure six locally named scheduler lane prompts/admission modes | Hard-coded control-host DB/repo paths; NOT portable node setup. |
| `scripts/add_family_lanes.py` | Add eight locally named family scheduler lanes through local API/DB | Reads scheduler process token and mutates local API/DB; NOT a public provisioning command. Review before execution. |
| `scripts/clone_lane.py`, `scripts/configure_family.py` | Present in source inventory | Purpose/operational contract not verified in this runbook; do not infer CLI. |

Scripts without a documented/help-verified interface are intentionally not given guessed commands here. `--help` is not generally implemented; inspect source before invoking unfamiliar scripts. There is no tracked crier node-worker, credential-bundle delivery, scheduler target enable/disable, node renewal, destroy, rebuild, or teardown command.
