# 61. docs/SCHEDULER-ADMISSION.md — the scheduler admission contract

| Field | Value | 
|---|---|
| Path | `~/code-factory/docs/SCHEDULER-ADMISSION.md` |
| Repository | `code-factory` |
| Revision | `8f77667b` |
| Status | **VERIFIED — the contract is described from its own sections and cross-checked against the scheduler-side allowlist, which was read at its on-disk revision on 2026-11-22** |

## 1. Purpose and why it matters

The scheduler-side gate a code-factory lane must satisfy before it is created — kept
deliberately separate from the repo's GitReins test gate (`docs/SCHEDULER-ADMISSION.md:3-4`).
Its core is the satellite-family allowlist: the scheduler API derives a lane's family from
its suffix and validates the workdir against canonical roots, with per-family cooldown
floors (`docs/SCHEDULER-ADMISSION.md:6-33`). What breaks if it is absent: satellite lanes
are created anywhere and the fleet's directory layout decays into guesswork. What breaks
if it lies: an operator moves a refused lane to dodge the gate — the contract and the
foreman skill both name that move as forbidden (`docs/SCHEDULER-ADMISSION.md:68-82`;
record 48). The authoritative implementation is named, not implied: the scheduler's
`internal/api/lane_onboarding.go` with its suffix vocabulary, roots, pins and validator
(`docs/SCHEDULER-ADMISSION.md:10-13`) — read and confirmed on 2026-11-22 [fact: FACT-12].

## 2. Dependencies and library contracts

| Dependency | Provider | Contract relied on | If it changes |
|---|---|---|---|
| the scheduler API | coding-hermes/scheduler | enforces the allowlist server-side: `satelliteLaneSuffixes` / `satelliteWorkdirRoots` / `validateLaneWorkdir` [fact: FACT-12] | this doc's tables drift from the served behavior |
| key-set parity test | scheduler `TestSCHEDGAP138_FamilyConstantsParity` | the doc's family table and the server's constants cannot diverge silently (`docs/SCHEDULER-ADMISSION.md:12-14`) | a family added here without roots rejects every workdir |
| `skills/code-factory-foreman/SKILL.md` | this repo | the client-side statement of the same gate (record 48) | two statements of one gate disagree |
| repo URL guard | `docs/SCHEDULER-ADMISSION.md:83-149` | intra-family repo_url agreement (CF-085) | satellites of one family carry diverged repo_urls |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| every locator on this page resolves | `python3 scripts/master_doc_check.py docs/handbook/appendices/units --only 61- --strict` | `MASTER-DOC: PASS` | 2026-11-22 | PASS |
| the server side defines what this doc declares | read `internal/api/lane_onboarding.go` in the scheduler checkout, constants at lines 46-73 | `satelliteLaneSuffixes` and `satelliteWorkdirRoots` present, unmatched pair refused | 2026-11-22 | PASS [fact: FACT-12] |
| the family table is where the doc says | `sed -n 20,33p docs/SCHEDULER-ADMISSION.md` | the nine families with roots and cooldown floors | 2026-11-22 at `8f77667b` | PASS |

## 4. Metrics emitted

None as counters. Its measurable output is the verification checklist — the exact checks
an operator runs before arming a lane (`docs/SCHEDULER-ADMISSION.md:68`) — and the
provenance section that names the commit each correction came from
(`docs/SCHEDULER-ADMISSION.md:150`).

## 5. Log lines it can generate

- Nothing by itself — a contract. Through the scheduler API it describes: the refusal a
  mismatched family/workdir pair produces (named by the server's validator [fact:
  FACT-12]), and the parity test's failure line when the constants drift — both carried
  by the scheduler's own surfaces, cited here as the gate's evidence.

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| A lane moved to dodge the gate | the refused workdir reappears elsewhere | the verification checklist forbids the workaround (`docs/SCHEDULER-ADMISSION.md:68-82`) | fix the root; record the refusal and the family |
| A family with no canonical root | every workdir of that family rejected | the foreman skill names this a scheduler defect, never an empty allowlist (`skills/code-factory-foreman/SKILL.md:35-36`) | add the roots with the family, in one change |
| Doc and server drift | a root that validates here fails there | the parity test pins the key sets (`docs/SCHEDULER-ADMISSION.md:12-14`) [fact: FACT-12] | re-read the server constants; correct this doc |

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| `$HERMES_HOME` | the operator's Hermes home (normally `~/.hermes`) | roots are relative to it; provisioning must not hard-code an operator path (`docs/SCHEDULER-ADMISSION.md:16-18`) |
| lane naming | `<primary>-<family>` suffixes; sync keeps the full name (`docs/SCHEDULER-ADMISSION.md:15-18`) | the family is derived, never declared by hand |
| repo URLs | per-family guard (`:83-149`) | a satellite agrees with its primary |

## 8. Evidence of record

- The contract: gate-vs-GitReins separation `docs/SCHEDULER-ADMISSION.md:3-4`, allowlist
  `:6-18`, family table `:20-33`, admission and arming `:37-66`, verification checklist
  `:68-82`, repo URL guard `:83-149`, provenance `:150-159`.
- The server-side counterpart read on 2026-11-22: `internal/api/lane_onboarding.go` in
  the scheduler checkout at its on-disk revision (constants at lines 46-73) [fact: FACT-12].
- The client-side restatement: record 48; the store this gate protects the layout of:
  the scheduler DB, which stays SQLite by fleet doctrine.
