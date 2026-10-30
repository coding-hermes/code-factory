# SPEC — NODE

A node is one Bunker agent bound to one project, repository and harness. This is the
provisioning contract, not evidence of a deployed worker.

## Manifest (`$HOME/.node/node.json`)

```json
{
  "node_id": "node-example",
  "project": "example",
  "repo": {"origin": "https://example.invalid/team/repo.git", "ref": "main", "path": "/home/example/repo"},
  "harness": {"name": "hermes", "version": "measured-adapter-version", "port": 10800},
  "bus": {"agent_id": "node-example", "base": "http://crier.invalid"},
  "created_by": "project-node.sh v1",
  "created_at": "2026-10-30T00:00:00Z"
}
```

## Script boundary and manifest mapping

`scripts/project-node.sh --check|--apply` measures the following layers:

| Layer | Tracked behavior | Not implemented |
|---|---|---|
| 00 preflight | architecture, disk floor, available memory, Crier health and PyPI reachability | Go proxy probe; per-job resource admission |
| 10 base | python3/venv, git, curl, tar, sha256sum; optional jq/rg/node warnings | generic base-tool installation |
| 20 harness | calls selected adapter; requires its measured `PASS  version` | inference integration; unattended dispatch execution |
| 30 bus | existing `.node/crier.json` file mode 600; bus base supplied | identity issuance/validation, secure bundle intake/deletion, Crier pull worker |
| 40 repo | existing Git directory or shallow clone at requested branch/ref | dirty-repo warnings, cache provisioning, existing checkout remote/ref attestation |
| 90 manifest | identity-checked atomic JSON write after layers pass | scheduler target registration, quarantine |

`--check` can create `.node`, but does not write a manifest. `--apply` refuses an
existing manifest with mismatched project/repo origin/harness (also node id, ref,
port, bus identity/base or repo path), malformed JSON or unsafe filesystem type.
Reuse validation precedes adapter apply and clone operations. Identical re-apply
preserves manifest bytes and `created_at`. New publication is atomic and failure
increments `manifest_write`; no manifest PASS follows a failed write. This does
not prove an existing repo is clean or at the requested revision.

The harness version comes from the adapter's measured `PASS  version` row.
`--node-id`/`NODE_ID` supplies the node id; `CRIER_AGENT_ID` defaults to that id;
`CRIER_BASE` defaults to `CRIER_URL`. Existing bus identity is an operator-supplied
precondition, not a credential-transfer mechanism in these scripts.

`scripts/node-create.sh --project P --repo URL --harness H` validates all required
inputs before any Bunker operation, then spawns/reuses, stages scripts (including
`node-contract.py`), invokes provisioning with shell-quoted validated values and
verifies the manifest. All transfers and provision failures stop creation.

### Supported inputs

Project/agent/server identifiers: 1–64 ASCII letters, digits, `_` or `-`, starting
with a letter/digit. Harness: explicit `hermes` only for node creation; other
adapters are unverified and must not trigger a spawn. Repo origins deliberately
support only `https://HOST/OWNER/REPO[.git]` and `git@HOST:OWNER/REPO[.git]`.
HOST is a DNS-style name (ASCII alphanumeric labels separated by dots, internal
hyphens allowed, no ports); OWNER/REPO use ASCII letters, digits, `_`, `-` and
start with a letter/digit. No credentials, query, fragment, local paths, extra
path components, shell characters or dot segments. This narrow contract is not
a general Git URL parser. SSH requires separately authorized existing access;
these scripts neither transfer nor inspect keys. Ref is an ASCII branch-like
name with nonempty alphanumeric/underscore/hyphen segments separated by `/`;
TTL is a positive integer plus `m`, `h` or `d`; port is 1–65535.

### Artifact boundary

`scripts/verify-node.sh --agent ID --artifact PATH` requires one of:

- exact `~/.node/node.json` (bootstrap manifest verification used by node-create);
- `~/.node/jobs/ID/artifacts/NAME`, with matching explicit `--dispatch-id ID`.

ID follows the identifier grammar; NAME is a single non-hidden filename beginning
with an alphanumeric character and otherwise using alphanumeric/`_`/`-`/`.`.
Names containing `config`, `secret`, `credential`, `token`, `key` or `env`
(case-insensitive) are denied. Absolute paths, traversal, arbitrary config and
secret paths and shell syntax are denied locally before any Bunker operation.
A non-shell remote Python read walks from HOME via `dir_fd` and `O_NOFOLLOW`,
rejects symlinks in every relative component and rejects non-regular files,
hardlinks and files over 16 MiB. Only after that successful read may the verifier
run remote shell health probes. It recomputes the transferred snapshot's SHA-256
on the control host. HOME itself is a trusted account root; a malicious node can
still forge bytes. Scope does not prove dispatch authenticity or content safety.

The verifier also requires agent exec, HTTP status 200, `auth_required:true`, and
401/302/403 on unauthenticated stats. Unknown outcomes, missing auth, transfer
errors and digest mismatches are FAIL, not WARN. It does not submit a directive
to a gateway or validate a result envelope.

## Laws and failure semantics

Storage classification, retained immutable commits and host-loss reconciliation
are defined by [STORAGE](STORAGE.md). Its local fixture is not an installer
recovery feature and does not widen the supported origin/ref grammar above.

- No root or provider keys on nodes. CF-002 supplies a host-local loopback proxy
  and scoped service-token enforcement (HARNESS.md#host-only-inference-custody).
  Deployment, node adapter, token issuance/delivery and transport integration are
  UNIMPLEMENTED / BLOCKED; the local proxy is not a provisioned node capability.
  Hermes adapter apply/check currently refuses before installation or gateway start.
- Every check names its measured value and can fail. Local fake adapters test
  provisioning mechanics, not a working Hermes/inference node.
- Manifest publication requires all implemented layers to pass; identical apply
  is byte-idempotent. This is not a guarantee that mutable network installs can
  reproduce a node exactly.
- Provisioning measures disk in GiB (default floor 5); refusal includes the free
  space. Historical footprint estimates (~1.5 GB per repo node) are not capacity
  measurements of this revision or enforceable runtime quotas.
- Harness/bus/repo/check failure returns nonzero. No work-acceptance loop exists.
- Dirty-repo handling, quarantine, lease/retry/ack and scheduler exclusion are
  planned external integration, not effects of these scripts.
- No live Bunker/Crier/gateway/inference/artifact work round trip is established
  by repository tests. See ENVELOPE.md, HARNESS.md and ../docs/DESIGN.md.
