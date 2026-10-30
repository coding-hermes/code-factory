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

`--check` does not create `.node`, reclaim space or write a manifest. `--apply` refuses an
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
`node-contract.py` and `disk-policy.py`), invokes provisioning with shell-quoted validated values and
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
- Provisioning disk admission runs before state-directory creation, adapter
  install, clone or manifest publication. `NODE_DISK_FLOOR` defaults to a
  PROVISIONAL 5 GiB, not a freshly measured role floor. Its grammar is 1–9 ASCII
  decimal digits, optionally followed by `.` and 1–9 digits; no sign, exponent,
  whitespace or empty value. Zero is an explicit fixture/operator capacity-floor
  override, NOT a measurement/parsing bypass. Exact integer byte/rational
  comparison accepts equality; display rounding never decides admission.
  `df -Pk -- HOME` under the C locale must exit zero within 10 seconds and return
  exactly one valid POSIX data row with nonnegative integer KiB fields and
  consistent totals. Malformed, failed or unknown observations refuse even at
  floor zero. Output names exact available KiB, free GiB and configured floor GiB.
  The observation is a point-in-time admission check, not a reservation or quota.
- Only `--apply --reclaim-disposable` opts into reclamation, and only after a
  valid below-floor observation. `--check` never reclaims, even with that flag.
  Measure again after eligible reclamation (including an absent/empty namespace)
  before admitting. Invalid floor/measurement never authorizes deletion.
  Unsafe namespace or deletion failure refuses, even if space later increases.
- Following STORAGE's reconstructable cache / ephemeral scratch classification,
  the ONLY eligible namespace is `$HOME/.node/disposable-cache-v1`. It is an
  explicitly enrolled, node-owned flat store of disposable opaque cache blobs,
  not an existing general cache/job directory. A trusted producer/operator must
  create it and `.node` as uid-owned mode 700 directories; this command never
  creates/enrolls it or copies data into it. HOME must be uid-owned and not
  group/world writable. All absolute HOME components are opened without following
  symlinks; namespace directories must remain on HOME's device. Entries must be
  single-link uid-owned mode 600 regular files named `cache-[A-Za-z0-9_-]{1,64}.bin`,
  on the same device. At most 1024 entries; anything else refuses the entire
  prevalidation with no deletion. No subdirectories, Git repos, links, special
  files, credentials, manifests, job evidence or durable records are eligible.
  Never put any of those in this namespace, even under an eligible blob name.
  `.node/jobs`, repo clones, build trees and stale user homes remain untouched.
  Reclamation uses descriptor-relative unlink, no recursive deletion, validates
  every entry before deleting any and rechecks identity before each unlink.
  Producers must take an exclusive flock on this directory too; lock contention
  refuses. The account/code is trusted: this is not protection against a hostile
  same-uid process that ignores the lock or mislabels valuable bytes. Partial
  deletion after an I/O/race failure is possible; failure still denies admission.
  Repeated reclamation of an unchanged empty namespace changes nothing.
- Historical footprint estimates (~1.5 GB per repo node) remain historical, not
  current measurements. Measured role sizing, broad build/job/clone reclamation,
  live Bunker orphan homes/keys/users reporting and authorized reaping are still
  UNVERIFIED / BLOCKED. This bounded local tranche does not complete CF-007.
- Harness/bus/repo/check failure returns nonzero. No work-acceptance loop exists.
- Dirty-repo handling, quarantine, lease/retry/ack and scheduler exclusion are
  planned external integration, not effects of these scripts.
- No live Bunker/Crier/gateway/inference/artifact work round trip is established
  by repository tests. See ENVELOPE.md, HARNESS.md and ../docs/DESIGN.md.
