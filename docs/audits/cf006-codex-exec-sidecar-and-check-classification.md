# CF-006 — foreign harness adapters: the codex exec sidecar, and `--check` that can certify a measured install

**Date:** 2026-11-08 · **Base:** `dc7641f` · **Control host:** `karaHermes-mde-7840hs` (Linux x86_64, node 22.22.3, python3 3.14.9)
**Frozen transcript of every command below:** `docs/audits/cf006-sidecar-and-classification-transcript.txt`

## What was already delivered (not rebuilt here)

The row's node slice landed earlier and is unchanged in substance: `0ec9634` (layer 20 reads the
adapter's own `PASS version` / `PASS binary` rows into `node.json`; `verify-node.sh` leg 7
`harness_identity` re-measures what the manifest claims) and `a32f234` (opencode's generation and
non-interactive rows). Criterion 2's measured ladder for a FOREIGN harness is codex (CF-227), and
criteria 3–5 are proven by `tests/harness-node-e2e.sh` plus the real turn recorded below.

## What this pass found, and fixed

### 1. The codex install ladder produced a harness that could answer but not write

`codex exec` performs file writes through a sibling binary it spawns from **its own directory**:
`<dir-of-codex>/codex-code-mode-host`. The release publishes that binary as a **separate asset**, so
the ladder — which fetched only `codex-<target>.tar.gz` — installed a pin whose every tool call failed
closed:

```
ERROR codex_core::tools::router: error=failed to spawn code-mode host …: No such file or directory
codex: I couldn't create `smoke.txt`: the command runner failed to start because its code-mode host is missing.
```

The turn still **exited 0**, which is exactly why the battery's artifact check (not the exit code) is
what caught it. A node provisioned from that adapter would have inherited the defect, and criterion 3
("returns a machine-readable result" — here, the artifact the machine-readable events describe) would
have been false on it.

**Fix (in `scripts/harness/install-codex.sh`, the ladder itself):**

- `--apply` installs BOTH artefacts of the pin: the CLI and `codex-code-mode-host`, each fetched
  through the same digest-or-refuse path (`fetch_verified`). The sidecar digest is recorded in the
  adapter and was cross-checked two ways: the release API's own asset digest and a local
  `sha256sum` of the downloaded bytes are identical
  (`7588334fd47bc4003d970b70dfd4d1e4578491b1e9baa72976a4c2d7e97590da`); the API's digest for the main
  tarball equals the `SHA256` already pinned in the adapter, so both come from the same release.
- A second `--apply` repairs a binary-only pin instead of reporting it complete, and stays a no-op
  when both artefacts are present (B4 asserts the sidecar's inode/mtime/size too).
- `--check` gained a `code_mode` row: `PASS` (with the path) when the sidecar sits beside the binary,
  `WARN` when it is absent — so a binary-only pin ends `CODEX: UNVERIFIED`, never a false `PASS`.
- The e2e fixture now mirrors the sidecar (digest computed in the test) and asserts that the node's
  `--apply` placed it; the fixture `curl` passes `file://` through to the real curl instead of
  stubbing an artefact fetch.

### 2. Two adapters let a non-install condition decide the install verdict

Both were the CF-384 defect class — a `WARN` row about something the adapter does not need, which
made `--check` unpassable on a host that HAD measured the harness:

| Adapter | Row | Was | Now |
|---|---|---|---|
| claude-code | `auth` | `WARN` for a missing credential, so an installed pin (binary + version PASS) ended `CLAUDE-CODE: UNVERIFIED` (exit 3) — while its own usage contract says `--check` exits 0 when the pin is installed, and `--turn` already reports the missing credential as `CLAUDE-CODE: SKIP (…)` exit 3 | `..` note; an **exported ambient key** is still `FAIL contract:ambient` |
| pi-agent | `credential_file` | `WARN` "a credential file is not a binary — the binary row above is the one that decides" while that binary row had just PASSed with version 1.5.0 | `..` note when a binary was measured; `WARN` when there is none (a credential alone certifies nothing) |

The decision rule and the table are now written into `specs/HARNESS.md` ("Which conditions are
notes, and which are WARNs"), per call site, with the measured reasoning for each row. `warn()` and
`verdict()` are untouched, and the codex rows are untouched (CF-384's decision stands).

## Acceptance criteria → evidence

| # | Criterion | State after this pass |
|---|---|---|
| 1 | Each adapter has `--check` (real) and `--apply` (refused until measured) | Six adapters ship. `hermes`/`codex`/`claude-code` have measured ladders and install; `opencode`/`deepseek`/`pi-agent` refuse `--apply` by name. On this host: codex `PASS`, claude-code `PASS`, pi-agent `PASS`, opencode `UNVERIFIED` (binary measured, no ladder — `--apply` refuses), deepseek `FAIL` (no binary), hermes `FAIL` (host `python3` is 3.14; the ladder stops by design and the battery names the `HERMES_PYTHON_BIN` knob). **`aider` and `goose` ship no adapter file** — they are named in `specs/HARNESS.md` so the absence is stated, they are not selectable, and `specs/HARNESS-MATRIX.md` §9 keeps them unmeasured/unpromised. No support is claimed for either. |
| 2 | ≥1 foreign harness measured end to end in a node, ladder recorded in `specs/HARNESS.md` | codex: ladder (now two digest-pinned artefacts) recorded in the adapters table; the node slice is proved offline by `tests/harness-node-e2e.sh`. The **live-node** run remains UNVERIFIED and is named as such. |
| 3 | That harness answers a directive non-interactively, machine-readably | Real turn through the pin: `PASS turn_exit`, `thread` parsed from `thread.started`, `model_served — requested gpt-6-luna → served gpt-6-luna`, artifact with the fixed token (sha256 `5eda6787…`). The e2e proves 3 JSONL events and the token in an artifact with no model in the loop; the conformance smoke (`codex:smoke PASS`) proves it with a token the battery chose. |
| 4 | A node created with that harness passes `verify-node.sh` | e2e `node:apply → NODE: PASS`, `verify:green → VERIFY: PASS` with `harness_identity` re-measured at the manifest's own binary, plus four red arms (tampered version, absent binary, null version → `UNVERIFIED`, absent manifest → note). |
| 5 | The node manifest records harness name and version | `harness{name:codex, version:0.166.0, binary:…/bin/codex, adapter, version_source}` read from the adapter's own rows, never from the pin default. |

## Tests added or extended (each with a pre-fix control where the arm can discriminate)

- `tests/harness/adapter-check-classification-test.sh` (new): three claude-code arms and three
  pi-agent arms on one fixture each. Positive → fixed adapter `PASS`; control → the adapter from
  `dc7641f` `UNVERIFIED`; negatives (ambient key refused by name; credential with no binary is
  `FAIL (1)`) prove the fix did not silence real blockers. Driven by `tests/selftest.sh` §56.
- `tests/harness/codex-install-test.sh`: B2b (sidecar digest mismatch refuses and places nothing),
  B3 (sidecar installed beside the pin and reported), B4 (idempotence now covers both artefacts),
  B8 (binary-only pin → `UNVERIFIED`; the pre-fix adapter calls the same tree `PASS`).
- `tests/harness-node-e2e.sh`: fixture sidecar mirror + digest, `file://` pass-through in the curl
  stub, and the node-apply arm now requires the `code_mode` row; the failure branch prints every
  FAIL row instead of a `tail -8` that could hide the culprit.

## What this does NOT prove (stated, not hidden)

- **No live node.** The e2e's fixture `codex` is a script and no model is called; the live run of
  `project-node.sh --apply --harness codex` + `verify-node.sh` on a bunker remains UNVERIFIED (no
  reachable bunker from this host). `specs/HARNESS.md` says the same in its own words.
- **`docs/HARNESS-CONFORMANCE.md` was not regenerated.** It is a generated file outside this brief's
  file fence and still records the 2026-11-06 run; the 2026-11-08 matrix is quoted in the transcript.
- **Three conformance FAILs remain, all measurements:** hermes (host interpreter), opencode-v2 (no
  v2 artefact exists), deepseek (no binary). None were converted into PASS/SKIP.
- **aider/goose** stay unmeasured and adapter-less; adding a check-only adapter for them would also
  require editing `README.md`/`docs/OPERATIONS.md` (outside the fence) to stay truthful, so the
  absence is documented in the two specs instead.
- **Two pre-existing doc sentences remain stale outside this fence** and are named here rather than
  silently left: `docs/OPERATIONS.md` still says `specs/HARNESS.md` "identifies Codex, aider, goose,
  and pi-agent as not measured, and no corresponding installer is tracked for those names" (codex has
  a measured ladder and claude-code/pi-agent have adapters), and `README.md`'s layout block is correct
  about the shipped set but does not mention the sidecar. Neither file is in this row's file fence.

## Trace

ch:trace row=CF-006 spec=docs/handbook/OUTLINE.md#M5-HARNESS wave=none:serial-worker test=tests/harness/adapter-check-classification-test.sh::check-classification doc=specs/HARNESS.md evidence=docs/audits/cf006-sidecar-and-classification-transcript.txt witness=none:live-node-not-authorized-in-worker verdict=none:foreman-judge commit=none:worker-commit memory=none:foreman-closeout
