# 56. docs/DESIGN.md — the factory's shape

| Field | Value |
|---|---|
| Path | `~/code-factory/docs/DESIGN.md` |
| Repository | `code-factory` |
| Revision | `8f77667b` |
| Status | **VERIFIED — the design note is described from its own sections; its topology is the topology the ledger's operator-stated facts record** |

## 1. Purpose and why it matters

The one-page shape of the system: the control host (task-router, scheduler, crier,
DuckBrain, board) and the bunker node (Hermes foreman, router, repo, gitreins gate,
namespace) joined by the tailnet, with one bunker per project (`docs/DESIGN.md:3-25`)
[fact: FACT-02]. It names the path of one unit of work and the failure model
(`docs/DESIGN.md:41,74`). What breaks if it is absent: no reader can place any other
document's component — every spec assumes this picture. What breaks if it lies: work is
sized, routed or recovered against a topology that is not the deployed one; the design
itself carries the authority rule that the node reports evidence but does not grade
itself, so a lying design breaks the independence the whole evidence chain relies on.

## 2. Dependencies and library contracts

| Dependency | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `specs/NODE.md` | this repo | the node contract the design summarizes | the design and the node spec disagree |
| `specs/ENVELOPE.md` | this repo | the wire the design's "path of one unit of work" walks (`docs/DESIGN.md:41-62`) | the flow describes a dialect the envelope retired |
| the scheduler + crier | external services | the design describes them from the client side; they are not implemented here (`docs/DESIGN.md:97-103`) | the design claims internals it does not own |
| DuckBrain | external memory service | the memory every node writes to; namespace = the project (`docs/DESIGN.md:8-22`) | namespace-per-project isolation breaks |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| every locator on this page resolves | `python3 scripts/master_doc_check.py docs/handbook/appendices/units --only 56- --strict` | `MASTER-DOC: PASS` | 2026-11-22 | PASS |
| the isolation rule is where the design says | `sed -n 34,40p docs/DESIGN.md` | "Why one node per project" names the isolation unit | 2026-11-22 at `8f77667b` | PASS |
| the topology matches the ledger's operator-stated facts | compare §1's diagram with fact: FACT-01/FACT-02 | foreman on the bunker; one bunker per project | 2026-11-22 | PASS — same topology, including the control-host caveat |

## 4. Metrics emitted

None. The design is prose and a diagram; the measurable claims it makes live in the specs
and scripts it points at (node contract, envelope, provisioning units), each of which
carries its own verification rows.

## 5. Log lines it can generate

- Nothing — a design note. The lines a reader following it sees belong to the components
  it arranges: the scheduler's admission rows, crier's refusal rows, the node layer's
  `PASS/FAIL` rows — all recorded on their own unit pages, never here.

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Design and code disagree | a reader cannot tell which is authority | the working agreement: the code is right and the disagreement is a finding (AGENTS.md; `prompts/foreman.md:37-38`) | file the finding; fix the design in the same change |
| The diagram drifts from the flows | F1–F16 tell a different story than §3 | handbook flows are reconciled against contracts (BOOK.yaml part II) | update §3 with the flow change |
| External internals claimed as owned | the design "documents" scheduler internals | §6 states what the design deliberately does not do (`docs/DESIGN.md:97-103`) | keep the client-side boundary honest |

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| tailnet addressing | the operator's network | the design uses placeholders, never private addresses (template boundary) |
| one bunker per project | deployed topology (`docs/DESIGN.md:16,34-40`) [fact: FACT-02] | the isolation unit of the whole factory |
| foreman placement | the project's bunker node (`docs/DESIGN.md:17-23`) [fact: FACT-01] | some projects still run on the control host — the rule is the target topology |

## 8. Evidence of record

- The design: shape diagram `docs/DESIGN.md:3-25`, one-node-per-project rationale
  `:34-40`, the unit-of-work path `:41-62`, what runs where `:64-72`, failure model
  `:74-95`, deliberate non-goals `:97-103`.
- The topology facts it operationalizes: fact: FACT-01 (foreman on the bunker; some
  projects still on the control host) and fact: FACT-02 (one bunker per project).
- The runbook and onboarding skill assume exactly this picture: records 54 and 47.
