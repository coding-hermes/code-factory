# P5G-20 — Provisioning generations and retry lifecycle: verification transcript (2026-11-26)

Design authority: `docs/handbook/OUTLINE.md` (PART III, module M1). Board row P5G-20,
source findings P5-B-14, P5-C-21, P5-C-22. Deliverable: `docs/handbook/chapters/M1-provisioning.md`
subsection **III.M1.S6 — Provisioning generations and retry lifecycle (P5G-20)**.

Source revision every shipped-code claim is pinned to: code-factory commit
`fe3d2ee08d04e7bc046638ba1290e1732e51bd12` (published tip: origin/main == gh/main == worker/main
at measurement time). The commit token inside the section pins the shipped scripts read for the
Actor/Data shape/Ordering/Failure behavior/Recovery rule facets and the probe's imports
(`scripts/configure_family.py`, `scripts/node_identity.py`, `scripts/node_seed.py`).

## Provenance disclosure (duplicate dispatch adopted)

Two workers were dispatched against the same row into this shared checkout:

- sibling session `local-7b37b943f612b68ee401b798d539416e6ef220982ec9dcb8f2993d62b8927258`
  (glm-5.3-flash, started 2026-11-26 09:55:18Z, ended 10:10Z, no commit): wrote the section
  first as a trailing `## 19.` block, the acceptance test `tests/test_p5g20_provisioning_lifecycle.py`,
  and the whole-chapter cited-path repairs (the `install-*.sh` / `bunker-*.sh` / `node_*.py`
  glob shorthand at chapter lines ~266, ~556, ~588). Uncommitted.
- this session: independent probe `docs/audits/p5g20-probe-provisioning-lifecycle.py`, then the
  integration: adopted the sibling's section and test verbatim, renamed the section to the
  submodule form the row requires (`### III.M1.S6` with anchor), moved it to the submodule
  region (immediately before `## 6. Contracts in and out`, the M2/P5G-19 precedent position),
  added the `| S6 ... |` row to the §3 submodule inventory table, appended the executed
  shipped-code probe vector to the section, and completed the `ch:trace` marker
  (`spec=` anchor `#node-side-modules`, `doc=` chapter path, added `prompt=`, `evidence=` this
  artifact). Every specification claim the sibling made was re-verified against the chapter and
  tree before adoption (see "Adoption verification" below).

## Acceptance arms

### Arm 1 — row id citation and five labelled lines

```
$ grep -c 'P5G-20' docs/handbook/chapters/M1-provisioning.md
4
$ grep -cE '^(Actor|Data shape|Ordering|Failure behavior|Recovery rule):' docs/handbook/chapters/M1-provisioning.md
5
```

All five labels are inside III.M1.S6 (column 0), exactly once each
(`tests/test_p5g20_provisioning_lifecycle.py::test_five_labelled_lines_present_exactly_once`).

### Arm 2 — deterministic artifact and its validating commands

Two vectors, both executed at this tree:

1. Specification-side: the operation state table (7 rows: create, resume, upgrade, replace,
   remove, rotate, revoke) + the numbered four-class conflict procedure, validated by

```
$ python3 tests/test_p5g20_provisioning_lifecycle.py; echo rc=$?
...
Ran 5 tests in 0.004s

OK
rc=0
```

2. Shipped-code side: `docs/audits/p5g20-probe-provisioning-lifecycle.py` (imports the shipped
   modules; no network, no bunker call, writes only inside a temporary directory):

```
$ python3 docs/audits/p5g20-probe-provisioning-lifecycle.py; echo rc=$?
retry_attempts 5
retry_backoff [0.25, 0.5, 1.0, 2.0, 4.0]
retry_classify busy_locked=True busy_busy=True not_busy=False
retry_outcomes configured/already/failed reason='no project row to configure' sleeps=0
identity_merge rc=0/0 mode=600 merged=True idempotent=True
identity_keeps_schema ['bus', 'namespace']
identity_refused_unreadable rc=1 untouched=True named=True
seed_build rc=0 files=1 digest=3f4425820c31
seed_apply rc=0 mode_ok=True applied_record=True
seed_drift rc=1 named=True
seed_preserve rc=0 content=node-local edit named=True
seed_force rc=0 content=seed-v1
P5G20 PROBE: PASS
rc=0
```

(Quoted byte-exact from the run, abbreviated nowhere.) Repeated runs print
byte-identical output (`diff` of two runs empty).

### Arm 3 — every cited repository path resolves (whole chapter)

```
$ grep -oE '(scripts|tests|specs|docs)/[A-Za-z0-9_./-]+' docs/handbook/chapters/M1-provisioning.md | sort -u | while read -r p; do test -e "$p" || echo "MISSING $p"; done
(no output)
rc=0
```

Empty: no missing cited path in the whole chapter. The three pre-existing glob-shorthand
tokens (`scripts/harness/install-`, `scripts/bunker-`, `scripts/node_`) from the row's baseline
measurement were repaired by the adopted sibling edit (concrete installer example,
explicitly enumerated `for f in ...` set with a parenthetical naming the glob it replaces,
explicitly enumerated python script list); this session verified the repair by re-running the
row's own grep above and re-grepping for `install-\*` / `node_\*` / `bunker-\*` (the one
remaining `bunker-*.sh` occurrence is inside the parenthetical prose, which the row's grep
pattern cannot read as a path because no `scripts|tests|specs|docs/` prefix precedes it).

### Arm 4 — version/commit named inside the section

```
$ grep -nE '\b[0-9a-f]{7,40}\b|v[0-9]+\.[0-9]+' docs/handbook/chapters/M1-provisioning.md
585: code-factory commit `fe3d2ee08d04e7bc046638ba1290e1732e51bd12` (short `fe3d2ee0`, ...)
586: (short `fe3d2ee0`, the source revision of this change)
...
```

Hits inside III.M1.S6 (line numbers at the measured tree): the full 40-hex source revision
and its short form pin the shipped surfaces the facets cite; the sibling facet also names
`0.19.0`/`4.0.5`-class version tokens only where the chapter's own §17.3 does. Each hex hit
pins the same surface: the shipped `scripts/` tree read for this section, at the published
tip named above.

## Adoption verification (claims re-checked before adopting the sibling's section)

- `docs/handbook/parts/IV-contract-register.md:791` — the P5-B-14 register row exists verbatim.
- `scripts/node-lifecycle-supervisor.py` exists; its docstring line 2 names "CF-008" and
  "destroy/create replay helper"; `tests/test_node_lifecycle.py` exists.
- Chapter §17.4 carries `cf.node.v1` `revision (PosInt)` under the `.node/node.lock` exclusive
  flock with `expected_revision` compare, `IDENTITY_CONFLICT`, malformed-input-preserved;
  `cf.seed-applied.v1` with `generation, manifest_digest`; the atomic `current` symlink and
  crash-before/after-switch rule (:1020-1042 region).
- Chapter §15/§16 carry the CAS-miss → `ENROLLMENT_FAILED` (:710), state sequence and
  restart-resumes-by-generation (:717), replace fences old Bunker / replacement never inherits
  revoked credentials (:713, :769-771), removal verifies no active lease, revokes all five
  credential classes, archives records, deletes only owned mounts (:772-773).
- §17.1 carries `REGISTRATION_CONFLICT` (:832), `REPLAY_CONFLICT` (:820), revocation by
  `POST /v1/revocations` + readback + negative probe with `401 CAPABILITY_REVOKED` as proof
  and file deletion not proof (:875-877), half-lifetime renewal and the exact 60-second
  overlap (:877-881), CredentialRef `generation:PosInt` (:847-848).
- §17.2 carries the `operation` enum, `generation (PosInt)` / `expected_generation (UInt)`,
  `IDEMPOTENCY_KEY_REUSED`, resume-with-same-operation_id (:898-910), the durable state enum
  (:936-943); §18.2/§18.3 carry the generation journal and the interrupted-phase table.
- `scripts/deploy_key.py:286-294` — the `pass --replace to rotate it` refusal and the WARNed
  replacement (verified by reading the file; the gate is also exercised by
  `tests/test_node_provisioning.py`'s "rotation gated" arm).
- Absence measurements (repository root): `grep -rn expected_generation scripts/` → no match;
  `grep -rniE 'IDEMPOTENCY_KEY_REUSED|REGISTRATION_CONFLICT|REPLAY_CONFLICT|CAPABILITY_REVOKED|ENROLLMENT_FAILED|REPLACEMENT_REQUIRED' scripts/`
  → no match; the only `--resume`-family token is pip's `--upgrade` flag inside
  `scripts/install-gitreins.sh:163`; the only `--generation` flag is the opencode harness
  adapter's v1/v2 conformance generation (`scripts/harness/install-opencode.sh:24-72`,
  v2 refused, CRIER-HARNESS-10) — a harness-adapter generation, not a provisioning CAS.

## Gates

```
$ python3 scripts/handbook_lint.py
handbook_lint: clean        (rc 0)
$ python3 scripts/handbook_spine.py
chapters=14  canonical contracts=18
findings=0                  (rc 0)
```

`scripts/master_doc_check.py` still exits 1 on the pre-existing
`37-specs-envelope-md.md` baseline error — unchanged by this row, not touched.

## What this row does NOT close

`cf.provision.v1` operations, the generation CAS, the credential authorities and the F13
release-manager journal remain specification-only (UNVERIFIED / TARGET-UNIMPLEMENTED), as the
section states with their absence measurements. No live node, no live bus and no live release
artifact were used or claimed.
