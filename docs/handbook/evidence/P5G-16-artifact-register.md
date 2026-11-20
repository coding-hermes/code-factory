# P5G-16 canonical digest and signature bytes evidence

This artifact records the consolidation and the checker for the row's question. It adds no
cryptography: every value it names is owned by a section that already governs it, and the register
is a projection over those sections. It does not claim a live signature was produced or verified
against any running service.

STATUS: complete
TIER: T1
EVIDENCE: docs/handbook/parts/IV-contract-register.md#iv29-the-artifact-register-canonical-bytes-and-signature-transcripts; docs/audits/p5g16-artifact-register-probe.sh; tests/selftest.sh

## The question the row asks

> What canonical byte sequence and signature transcript is used for each brief, report, payload,
> manifest, tree and webhook, including key id, audience, timestamp, replay and rotation rules?

At `6f6b1c04` the answer existed but was scattered: RFC 8785 byte rules and three worked digests in
§IV.2.3, fifteen digest rows in §IV.2.6, the Ed25519 profile and five-line transcript in M10 §16,
first trust and signed configuration in M1 §17, the commit and landing path in M3 §17.3, provider
rotation in M7 §16, and webhook delivery in V §V.0.3. No single place answered it for all six
classes, and no command could decide whether the answer was complete.

## What the register now answers, per class

New subsection `§IV.2.9 The artifact register: canonical bytes and signature transcripts` in
`docs/handbook/parts/IV-contract-register.md`, numbered after §IV.2.6 in a free slot (649-731 at the
working tree this evidence was measured in). One table, six rows, six value columns — canonical byte
sequence, signature profile and transcript, key-id source, audience, timestamp and replay window,
rotation rule. Every one of the 36 value cells carries the citation of the section that owns it; the
probe enforces that mechanically, so a cell cannot be filled by assertion.

- **brief** — JCS of the whole `cf.brief-input.v1` object, `input_digest` over exactly those bytes,
  `brief_ref` addressing the same bytes (§IV.2, §IV.2.3, M3 §17.4). No signature covers the object;
  a carrying Crier request is `CF2A-CRIER-1` (M10 §16).
- **report** — `report_digest` over the `round-report.v1` body excluding itself, its `signature` and
  `closure_ref` (§IV.2.3, §IV.2.6, §IV.5.5). The `signature` member has no profile, key id or
  audience anywhere at this revision.
- **payload** — the unsigned `cf.crier.response-payload.v1` result; `response_body_digest` over the
  bare tag plus those bytes and `receipt_digest` over the bare receipt tag plus the receipt body
  minus itself and `signature` (§IV.2.6, §IV.2.8); the `CF2A-CRIER-1` five-line transcript with
  `crier.factory` / requester audiences and the `request_id`+`idempotency_key` nonce (M10 §16).
- **manifest** — JCS minus an explicitly self-named digest and signature (§IV.2.3), the
  `CF2A-RELEASE-1` / `CF2A-SEED-1` / `CF2A-BACKUP-1` / `CF2A-EVIDENCE-1` constructions with their
  owning sections, and the key-id sources each of those surfaces names.
- **tree** — the path-byte-sorted JCS array definition of `tree_digest` and the explicit statement
  that no native SHA-1 tree or commit may be labelled a SHA-256 `tree_digest` (§IV.2.3). It is
  unsigned; certification is commit ancestry plus the closure validator (M3 §17.3).
- **webhook** — RFC 8785 `event.v1` body, HMAC-SHA256 over `factory-event-v1`, key id, delivery
  time, event id and the exact body bytes (V §V.0.3); `active_key_id` resolution, ±60 s skew, the
  409-on-changed-digest rule, the 604800 s retention and the 300 s verification-key overlap (V §V.4).

A short normative paragraph names the four things AC1 asks for: the authoritative actor per layer
(§IV.2.5 rule 2), the ordering (content → record → envelope, tree → commit → readback, persist →
sign → deliver), the failure behavior (`DIGEST_MISMATCH`, `CONTRACT_INVALID`, `REPLAY_CONFLICT`,
`UNAUTHORIZED`, `ENDPOINT_UNAUTHORIZED`, all refusing before effects) and the recovery rule
(recompute and read back; replay the same receipt or commit; never re-derive or pick a new
generation).

## Cells that are NOT SPECIFIED, and who owns them

These are the honest finding. Each was verified by reading the owning section, not by assuming
silence, and each is reproduced in the register's second table so a stranger sees the gap next to
the rule rather than in a review thread.

| Artifact class | Cell with no normative answer | Owning board row |
|---|---|---|
| brief | audience at the object level — `cf.brief-input.v1` and `worker-brief.v1` declare none; only a carrying Crier request has one (M10 §16) | none — digest-pinned delivery is the completed P5G-08 decision |
| brief, payload, report | rotation of the enrolled Crier signing key — M10 §16 resolves a key id to the enrolled principal and registration generation and refuses an expired or revoked identity, but states no rotation procedure, overlap window or re-key transcript | P5G-09 |
| report | profile, key-id source and audience of the report `signature` member — §IV.2.6 and §IV.5.5 exclude a `signature` member from `report_digest`, and the closed `round-report.v1` body carries no signature field (CT-06R) | none |
| payload (memory-record variant) | profile over the `cf.memory-record.v1` `signature` member — the §IV.2.6 `payload_digest` row excludes `signature` but no section names the profile that produces it | P5G-22 |
| manifest | audience, timestamp, replay window, signer rotation — the lock declares no audience and no timestamp (M1 §18.1), deduplication is generation and operation based (M1 §18.2), and the only trust statement is the trust-bundle pin (M1 §17.3) | none |
| tree | signature, key-id, audience — `tree_digest` is unsigned, and certification is commit ancestry plus the closure validator (M3 §17.3) | none |
| webhook | audience — the receiver is the subscription `endpoint_ref` and the transcript carries no audience field (V §V.0.3, V §V.4) | none |

Two rows were read from the canonical board in this worktree (read-only) to confirm the owner ids
rather than guessing; at `6f6b1c04` plus this worktree's uncommitted change it reports:

```
$ jq -c 'select(.id=="P5G-09" or .id=="P5G-16" or .id=="P5G-22") | {id, status, title: (.title // "" | .[0:80])}' .coding-hermes/board/tasks.jsonl
{"id":"P5G-09","status":"blocked","title":"Enrollment identity and trust bootstrap"}
{"id":"P5G-16","status":"pending","title":"Canonical digest and signature bytes"}
{"id":"P5G-22","status":"pending","title":"Memory topology, merge and durability"}
```

P5G-09 owns enrollment identity and trust bootstrap, so Crier key rotation belongs there rather than
in this row. P5G-22 owns the memory record, so the missing `cf.memory-record.v1` signature profile
belongs there. Where no row exists the register says `none` instead of inventing an owner, and the
cell stays NOT SPECIFIED.

## AC2: no competing target contract remains

One conflict was already live at `6f6b1c04` and is now resolved in one direction. §IV.2.6 registers
`response_body_digest` and `receipt_digest` as the bare tag concatenated with the bytes, while
M10 §16 prints the equivalent shell commands with a trailing `\n` inside the tag. Both cannot be
true: inserting a separator changes the digest. The published bytes decide it — `CV-18-A` and the
same digests in `docs/handbook/conformance/fixtures/custody-request-response.json` recompute only
under the bare tag. The register therefore records M10 §16's spelling as **superseded by §IV.2.6**
for those two registers, keeps M10 §16's profile, header set, audience rule and five-line transcript
authoritative, and leaves `response_envelope_digest` alone because §IV.2.6 has no row for it — naming
that as open work rather than accepting an alternate contract.

The probe's arm D negative control proves the separator question is decided by the bytes and not by
assertion: the newline-separated spelling reproduces neither published digest.

## The probe

`docs/audits/p5g16-artifact-register-probe.sh` — shell only, `bash -n` clean, any cwd, optional
`P5G16_ROOT` to point it at a fixture tree. Exit 0 holds, 1 fails with the failing arms named, 2 on a
bad root. Arms:

- **A** — the §IV.2.9 subsection exists, titles itself an artifact register, has one table row per
  artifact class, and every value cell of those rows names its owner (`§` citation or a `CV-` vector
  id); a six-cell row count is asserted so a shortened row cannot pass.
- **B** — every section id cited by the register resolves to a real heading in the tree being read
  (chapter files by number, parts by file).
- **C** — the register introduces no `CF2A-*` profile id and no `cf.*` domain tag that is not
  already present elsewhere in the corpus. Both are extracted from the register section and looked
  up in a scratch copy of `docs/` with the register section and this evidence file removed, so the
  register cannot vouch for itself.
- **D** — recomputation from published bytes: the three §IV.2.3 rows (`sha256("")`, `sha256("abc")`,
  `sha256("[]")`), the `CV-01-B` brief canonical JSON to its published digest **and** its `brief_ref`
  suffix, the `CV-18-A` `response_body_digest` and `receipt_digest`, plus the negative control above.

Self-match guard: the script lives under `docs/audits` and its pattern lines quote the strings it
searches for, so every corpus grep runs against the scratch copy with `docs/audits/p5g16-artifact-register-probe.sh`
and this evidence file deleted. This is the P5G-36 bug (its own pattern line counted as a hit) not
repeated.

## Commands and observed output

1. `bash -n docs/audits/p5g16-artifact-register-probe.sh` — exit 0.

2. `bash docs/audits/p5g16-artifact-register-probe.sh` — exit 0.

```
=== ARM A: one register subsection names all six artifact classes, every cell cited ===
  section=### IV.2.9 (docs/handbook/parts/IV-contract-register.md:649-731)
  title names an artifact register
  artifact-class rows: 6
  ok: brief row present, 6 value cells, all cited
  ok: report row present, 6 value cells, all cited
  ok: payload row present, 6 value cells, all cited
  ok: manifest row present, 6 value cells, all cited
  ok: tree row present, 6 value cells, all cited
  ok: webhook row present, 6 value cells, all cited

=== ARM B: every cited section id resolves to a real heading ===
  distinct citations: 22
  ok: I §1.9.10     -> docs/handbook/parts/I-system-arrangement.md (heading 1.9.10)
  ok: §IV.1         -> docs/handbook/parts/IV-contract-register.md (heading IV.1)
  ok: §IV.2         -> docs/handbook/parts/IV-contract-register.md (heading IV.2)
  ok: §IV.2.3       -> docs/handbook/parts/IV-contract-register.md (heading IV.2.3)
  ok: §IV.2.5       -> docs/handbook/parts/IV-contract-register.md (heading IV.2.5)
  ok: §IV.2.6       -> docs/handbook/parts/IV-contract-register.md (heading IV.2.6)
  ok: §IV.2.7       -> docs/handbook/parts/IV-contract-register.md (heading IV.2.7)
  ok: §IV.2.8       -> docs/handbook/parts/IV-contract-register.md (heading IV.2.8)
  ok: §IV.5.5       -> docs/handbook/parts/IV-contract-register.md (heading IV.5.5)
  ok: M10 §16       -> docs/handbook/chapters/M10-crier.md (heading 16)
  ok: M1 §17.1      -> docs/handbook/chapters/M1-provisioning.md (heading 17.1)
  ok: M1 §17.3      -> docs/handbook/chapters/M1-provisioning.md (heading 17.3)
  ok: M1 §17.4      -> docs/handbook/chapters/M1-provisioning.md (heading 17.4)
  ok: M1 §18.1      -> docs/handbook/chapters/M1-provisioning.md (heading 18.1)
  ok: M1 §18.2      -> docs/handbook/chapters/M1-provisioning.md (heading 18.2)
  ok: M3 §17.2      -> docs/handbook/chapters/M3-repository.md (heading 17.2)
  ok: M3 §17.3      -> docs/handbook/chapters/M3-repository.md (heading 17.3)
  ok: M3 §17.4      -> docs/handbook/chapters/M3-repository.md (heading 17.4)
  ok: VI §35.1      -> docs/handbook/parts/VI-failure-risk.md (heading 35.1)
  ok: V §V.0.3      -> docs/handbook/parts/V-settings.md (heading V.0.3)
  ok: V §V.4        -> docs/handbook/parts/V-settings.md (heading V.4)
  ok: V §V.9        -> docs/handbook/parts/V-settings.md (heading V.9)

=== ARM C: no new CF2A-* profile id and no new cf.* domain tag ===
  ok: CF2A-BACKUP-1      present elsewhere in the corpus (2 files)
  ok: CF2A-CRIER-1       present elsewhere in the corpus (6 files)
  ok: CF2A-EVIDENCE-1    present elsewhere in the corpus (1 files)
  ok: CF2A-RELEASE-1     present elsewhere in the corpus (3 files)
  ok: CF2A-SEED-1        present elsewhere in the corpus (1 files)
  ok: cf.backup.v1                 present elsewhere in the corpus (12 files)
  ok: cf.brief-input.v1            present elsewhere in the corpus (12 files)
  ok: cf.crier.receipt.v1          present elsewhere in the corpus (7 files)
  ok: cf.crier.response-body.v1    present elsewhere in the corpus (7 files)
  ok: cf.crier.response-payload.v1 present elsewhere in the corpus (3 files)
  ok: cf.memory-record.v1          present elsewhere in the corpus (8 files)
  ok: cf.release-lock.v1           present elsewhere in the corpus (8 files)

=== ARM D: published bytes recompute to published digests ===
  ok: sha256("")                 e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
  ok: sha256("abc")              ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
  ok: sha256("[]")               4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945
  ok: CV-01-B brief digest       aa0776211ad78cfe469f9dc192e1cfebdadc863acb05e887fdcaa11a2712874a
  ok: CV-01-B brief_ref          cas+sha256://code-factory/aa0776211ad78cfe469f9dc192e1cfebdadc863acb05e887fdcaa11a2712874a
  ok: CV-18-A response_body_digest 5df30f1a177f1a97d690a3a8bcc134afda949b5c7893288231139d7748cf5de5
  ok: CV-18-A receipt_digest     6d58935d1a6b9ef1815cc59309e074778ab0f528b3780a57f63ba2f0e984cb08
  ok: the retired newline-separated tag spelling reproduces neither digest

P5G-16: PASS — one artifact register answers all six classes, cites resolvable owners, mints no profile or tag, and its published bytes recompute
```

3. Red control — the register blob from the pinned pre-fix revision, in a fixture tree:

```
FIX=$(mktemp -d "$HOME/.hermes/cache/scratch/p5g16-prefix-XXXXXX")
cp -a docs "$FIX/docs"
git show 6f6b1c04:docs/handbook/parts/IV-contract-register.md > "$FIX/docs/handbook/parts/IV-contract-register.md"
P5G16_ROOT="$FIX" bash docs/audits/p5g16-artifact-register-probe.sh
```

exit 1:

```
=== ARM A: one register subsection names all six artifact classes, every cell cited ===
  MISSING: no '### IV.2.9' heading in docs/handbook/parts/IV-contract-register.md

=== ARM B: every cited section id resolves to a real heading ===
  MISSING: the register cites no section id at all

=== ARM C: no new CF2A-* profile id and no new cf.* domain tag ===
  no CF2A-* id cited (allowed; the webhook profile has none)

=== ARM D: published bytes recompute to published digests ===
  ok: sha256("")                 e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
  ok: sha256("abc")              ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
  ok: sha256("[]")               4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945
  ok: CV-01-B brief digest       aa0776211ad78cfe469f9dc192e1cfebdadc863acb05e887fdcaa11a2712874a
  ok: CV-01-B brief_ref          cas+sha256://code-factory/aa0776211ad78cfe469f9dc192e1cfebdadc863acb05e887fdcaa11a2712874a
  ok: CV-18-A response_body_digest 5df30f1a177f1a97d690a3a8bcc134afda949b5c7893288231139d7748cf5de5
  ok: CV-18-A receipt_digest     6d58935d1a6b9ef1815cc59309e074778ab0f528b3780a57f63ba2f0e984cb08
  ok: the retired newline-separated tag spelling reproduces neither digest

P5G-16: FAIL — arms A,B do not hold at this tree
```

The red arm names the missing section and both dependent arms; arm D still passes on the pre-fix
blob because the three §IV.2.3 rows and the vectors already existed there. That is the intended
attribution: D tests the bytes, A/B test the consolidation.

4. `bash docs/audits/cf198-section-mapping.sh` — exit 0, ends
   `arms_plan=78 arms_tree=78` / `RESULT: OK`. The selftest block is unnumbered, so the arm census is
   unchanged (CF-198).

5. `bash scripts/boardctl validate` — `RESULT: OK (91 warning(s))`, exit 0. The warnings are the
   board's pre-existing legacy shapes (duplicate legacy event ids, one headerless board, one event
   without an id), identical at `6f6b1c04`.

6. `python3 scripts/handbook_spine.py` — `chapters=13  canonical contracts=18` / `findings=0`,
   exit 0.

7. `bash tests/selftest.sh` — `SELFTEST: PASS` / `EXIT=0` / `SELFTEST_RC=0` (933 lines, log kept
   at `/tmp/selftest-p5g16-tmpoutside.log`). The P5G-16 block ran both ways inside that suite:

```
the artifact register pins canonical bytes and signature transcripts for all six classes (P5G-16)
  PASS  arms A-D hold: register present, every citation resolves, no minted profile or tag, published bytes recompute
  PASS  red control: register section removed -> exit 1 naming arms A,B and the missing IV.2.9 heading
```

   This run used the default `TMPDIR` (`/tmp`). The same suite with `TMPDIR` pointed inside the repo
   (`TMPDIR=$PWD/.tmp-selftest`) reports `SELFTEST: FAIL (4)` — one arm of §11 `lane target
   contract` and three arms of §41 `repo_freshness` (`stale workdir…`, `tolerated-defect rows…`,
   `--json…`). Those four are environmental, not this change, and that is measured rather than
   assumed: the inputs they exercise are **byte-identical** to `6f6b1c04`
   (`git diff --stat 6f6b1c04 -- scripts/ tests/test_lane_target.py` is empty), and each one flips
   with only `TMPDIR` changed —

   * `python3 -B tests/test_lane_target.py` → rc 0 (`54 ok`) under `/tmp`, rc 1 under
     `$PWD/.tmp-selftest` (its `git rev-parse --show-toplevel` fixture resolves the enclosing
     worktree instead of failing "not a git root").
   * the pinned `git show 6f6b1c04:scripts/repo_freshness.py`, driven by the §41 block lifted out of
     `tests/selftest.sh` into a scratch harness → PASS under `/tmp`, `FAIL (exit 1, 2 FAIL rows)`
     under `$PWD/.tmp-selftest`.

   The P5G-16 block itself passed under both `TMPDIR` settings; it appears in the FAIL(4) log as a
   pass, not among the four.

## What is measured, and what is open

Measured at the working tree this evidence was written in, on top of `6f6b1c04`: four probe arms
green (61 lines of output quoted above), the red control red, CF-198 mapping OK with 78/78 arms, the
handbook spine at zero findings, the board validating, and the full selftest at `SELFTEST: PASS`
(exit 0) with the P5G-16 arms green inside it.

Open, and deliberately not closed here: the seven NOT SPECIFIED cells above (Crier key rotation is
P5G-09, the memory-record signature profile is P5G-22, and five cells have no owning row at all);
and `response_envelope_digest`, which M10 §16 names but §IV.2.6 does not register — registering it is
a change to §IV.2.6, not something this row should mint.
