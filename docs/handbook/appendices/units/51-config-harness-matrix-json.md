# 51. config/harness-matrix.json — the family-to-harness selection matrix

| Field | Value |
|---|---|
| Path | `~/code-factory/config/harness-matrix.json` |
| Repository | `code-factory` |
| Revision | `8f77667b` |
| Status | **VERIFIED — the matrix is described from its own keys alongside the resolver that loads it; both were read at this revision** |

## 1. Purpose and why it matters

The data file that maps model families to harnesses: a `default` (`hermes`), a
`by_family` table (claude→claude-code, openai→codex, deepseek→dsh, oss→opencode), a
`hosts` map naming which harness may run where, and a `shims` map
(`config/harness-matrix.json:2-17`). It is configuration as data so that switching a
lane's harness is a file edit, not a reprovision — the switching-as-configuration
requirement the harness spec carries. What breaks if it is absent: every consumer guesses
a harness per family and two lanes of one family drift onto different harnesses. What
breaks if it lies: a harness is selected for a host that cannot run it — which is why
selection and SUPPORT are different claims: support means five green legs per harness in
the conformance battery, not an install [fact: FACT-08].

## 2. Dependencies and library contracts

| Dependency | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `scripts/harness_resolve.py` | this repo | loads this file by default (`DEFAULT_MATRIX_FILE`, `scripts/harness_resolve.py:83`) and resolves a lane's harness from it (`:190`) | a key rename silently resolves to the default |
| `specs/HARNESS-MATRIX.md` | this repo | the design authority the matrix implements; the foreman is always Hermes and a lane's harness is a setting (`prompts/foreman.md:91-95`) | the JSON and the spec disagree — the spec wins until both move in one change |
| the conformance battery | `tests/harness-conformance.sh` | the proof that a mapped harness is supported, not merely mapped [fact: FACT-08] | mapping claims outrun measured support |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| every locator on this page resolves | `python3 scripts/master_doc_check.py docs/handbook/appendices/units --only 51- --strict` | `MASTER-DOC: PASS` | 2026-11-22 | PASS |
| the file is valid JSON with the four keys | `jq -r "keys | sort | join(\",\")" config/harness-matrix.json` | `by_family,default,hosts,shims` | 2026-11-22 at `8f77667b` | PASS — exactly those four |
| the resolver reads this file by default | `scripts/harness_resolve.py:83,190` | `DEFAULT_MATRIX_FILE` names it; the load path defaults to it | 2026-11-22 (read) | PASS |

## 4. Metrics emitted

None. Selection is a pure function of (family, host) at resolve time; the resolver's
refusals name the missing harness for the requested host set, and nothing counts
selections — the switching requirement's measurable form is the conformance battery, not
a counter.

## 5. Log lines it can generate

- Nothing by itself — data. Through the resolver: the resolution row naming the harness a
  lane resolves to, and a refusal naming the node set missing that harness
  (`scripts/harness_resolve.py:59-64`); both are carried by the resolver's own surface.

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| A family mapped to an unsupported harness | the battery, not the matrix, flags it | mapping ≠ support: support is five green legs [fact: FACT-08] | map only after the battery passes on a real node |
| A host key renamed in `hosts` | resolutions silently fall to the default | the resolver loads the file wholesale (`scripts/harness_resolve.py:83,190`) | keep key renames in the same change as their consumer |
| `shims` used to force a foreign harness | a run claims support via a shim | the spec's authority: §3 selection, battery-gated support | treat shims as experimental until measured |

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| lane family | the scheduler's lane name | drives `by_family`; unknown families take `default` |
| host set | `hosts` map | a harness may be constrained to named hosts (`config/harness-matrix.json:9-16`) |
| `HARNESS` per project | `config/bunker.example.conf` | the provisioned default; the matrix is the switching surface |

## 8. Evidence of record

- The matrix: default `config/harness-matrix.json:2`, family table `:3-8`, hosts `:9-16`,
  shims `:17`.
- The resolver contract: `scripts/harness_resolve.py:83` (default path), `:190` (load),
  refusal vocabulary `:59-64,123`.
- The authority chain: `specs/HARNESS-MATRIX.md` via `prompts/foreman.md:91-95`; support
  defined by the battery: fact: FACT-08.
