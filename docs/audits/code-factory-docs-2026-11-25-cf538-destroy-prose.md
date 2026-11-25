# CF-538 — OPERATIONS.md destroy/teardown prose re-anchored to the post-CF-366 script

Tick: code-factory-docs-2026-11-25-15-22-20 (docs lane). Date: 2026-11-25.
Base: origin/main `a3b5f9ab83e0cd0a16ef1eea4098dd7dda03bcde` (clone transport; the registered
checkout was sibling-held by code-factory-foreman-2026-11-25-15-22-20, so no write touched it).

## The claim that was false

CF-366 (`d7f07455`, merge of `e83ef279`, landed 2026-11-25) taught
`scripts/bunker-provision.sh --destroy --yes` to revoke the crier bus identity with a
probe-proven DELETE and to record residue. `docs/OPERATIONS.md` still taught the pre-CF-366
law in nine lines. Pre-fix state, measured at the base tip:

```
$ grep -c 'does \*\*not\*\* revoke external credentials' docs/OPERATIONS.md
1
$ grep -n 'Still BLOCKED / NOT YET — renewal, rebuild, credential revocation' docs/OPERATIONS.md
206:**Still BLOCKED / NOT YET — renewal, rebuild, credential revocation.** There is no checked-in command or measured procedure for renewing a bunker agent TTL, preserving or revoking credentials, or rebuilding from a manifest. ...
$ grep -c 'revoke a crier or inference identity' docs/OPERATIONS.md
1
$ grep -c 'parsed and \*\*not forwarded\*\*' docs/OPERATIONS.md
1
$ grep -c ':230-239\|:172-239\|:160-167\|:172-201\|:203-214\|:216-223\|:264-273\|:39-62\|:70-87' docs/OPERATIONS.md
6
```

The contradicting code at the same tip (`scripts/bunker-provision.sh`, 1025 lines):

- `attempt_revoke()` `:777-799` — DELETE then a follow-up GET expecting 404; rc 0 only when the
  probe proves the registration gone (`204` revoked, `404` already-gone idempotent).
- `destroy()` `:856-959` — refusal without `--yes` at `:859`; bus-identity block `:887-927`;
  residue record `:929-948`; verdict `:950-958`.
- `write_creation_manifest()` `:822-854` — paths only, written only after a fully green apply.
- TTL forwarded to the spawn at `:690` (`[ -n "$TTL" ] && create_args+=(--ttl "$TTL")`);
  `grep -c WORKDIR scripts/bunker-provision.sh` prints `0` — WORKDIR is not a config key.
- Fixture proof: `tests/test_cf366_destroy_revocation.sh`, wired into the suite at
  `tests/selftest.sh:163`. Stubbed bunker + curl; no live bus is contacted, so the revocation is
  fixture-tested, **not measured** against a live bus.

## What was corrected (docs/OPERATIONS.md, 9 lines)

| Line (pre-fix) | Claim as written | Correction |
|---|---|---|
| 40 | auth-bundle cite `:172-201`, crier.json cite `:70-87` | `:524-570`, `:126-127` |
| 49 | config parse `:39-62`, CLI-wins `:264-273`, staging `:160-167`, bundle `:172-201`, node.json `:203-214`, crier `:216-223`, destroy refusal `:230-239`; "TTL and WORKDIR are parsed and **not forwarded**" | `:143-170`, `:993-1013`, `:687-700`, `:524-570`, `:701-718` (merge, not write), `:588`, `:859`; TTL forwarded `:690`, WORKDIR not a config key |
| 204 | "Destroy does **not** revoke external credentials (crier identity, inference key)" | raw `bunker destroy` verb leaves credentials untouched; the tracked `--destroy --yes` path revokes the crier bus identity with a probe-proven DELETE (`:777-799`, `:887-927`); inference key and scheduler target still untouched |
| 206 | "Still BLOCKED / NOT YET — renewal, rebuild, credential revocation" | rescoped to renewal, rebuild, inference-key revocation; only the tracked destroy path revokes anything, and only the crier bus identity |
| 208 | "the credential-revocation step ... **not measured**" | implemented and fixture-tested (`tests/test_cf366_destroy_revocation.sh`, `tests/selftest.sh:163`), **not measured** against a live bus; rebuild and round trip still not measured |
| 212 | destroy "does not disarm a scheduler target, revoke a crier or inference identity, or archive anything"; cite `:230-239` | names the probe-proven revocation and the residue record (`:929-948`); still no scheduler disarm, no inference-key revocation, no archive; cite `:859` |
| 217 | "rotation and revocation are not implemented" | rotation not implemented; revocation exists only for the crier bus identity in the destroy path; inference key has none |
| 231 | "TTL/WORKDIR are parsed but not forwarded" | TTL parsed and forwarded; WORKDIR not a config key |
| 244 | apply/destroy cite `:172-239` | apply `:474-741`, destroy `:856-959` |

Falsifying commits: the destroy/revoke drift traces to CF-366 (`d7f07455`/`e83ef279`, 2026-11-25);
the TTL/WORKDIR and stale-cite rot predates it (`2ce12d98`, 2026-11-04, forwarded `--ttl`) and was
found in the same sweep. The dated 2026-11-04 dogfood transcript quoted in §8 stays as history;
the audit file `docs/audits/code-factory-docs-2026-11-04-cf189-destroy-prose.md` is a dated
artifact and is deliberately not rewritten.

## Post-fix verification (run in the clone at the fix commit)

```
$ grep -c 'does \*\*not\*\* revoke external credentials' docs/OPERATIONS.md
0
$ grep -c 'revoke a crier or inference identity' docs/OPERATIONS.md
0
$ grep -c 'renewal, rebuild, credential revocation' docs/OPERATIONS.md
0
$ grep -c 'parsed and \*\*not forwarded\*\*' docs/OPERATIONS.md
0
$ grep -c ':230-239\|:172-239\|:160-167\|:172-201\|:203-214\|:216-223\|:264-273\|:39-62\|:70-87' docs/OPERATIONS.md
0
```

Every new citation was resolved against the blob at the fix commit (`sed -n '<line>p'
scripts/bunker-provision.sh` for each of `:143`, `:474`, `:524`, `:588`, `:687`, `:690`, `:701`,
`:777`, `:856`, `:859`, `:887`, `:929`, `:993`; `tests/selftest.sh:163`). The greps above are
scoped to the shipped prose file; this audit keeps the retired sentences quoted on purpose, so a
recursive grep over `docs/` still finds them here and nowhere else in shipped prose.

Gate: `bash tests/selftest.sh` in the clone — result quoted in the tick report (the suite is the
repo's own; a docs-only diff cannot red it, and the run proves the tree the row closes on).

## Not measured

- The live-bus revocation: no `DELETE <bus>/agents/<id>` was issued against a real crier from
  this tick (the fixture stubs the bus; the script's own trace comment records
  `witness=none:live-bus-revoke-not-authorized`).
- `--apply` and `--destroy` end to end: still not run in this runbook's evidence.
