# 58. docs/THREAT-MODEL.md — the public-repo threat model

| Field | Value |
|---|---|
| Path | `~/code-factory/docs/THREAT-MODEL.md` |
| Repository | `code-factory` |
| Revision | `8f77667b` |
| Status | **VERIFIED — the model is described from its own sections; its evidence-boundary vocabulary is quoted with resolving lines and its controls cross-checked against the measured ones** |

## 1. Purpose and why it matters

The security assessment of the published template: its objective is that only intended
work runs in the intended repository, credentials remain protected, and untrusted node
claims do not become trusted results without independent verification
(`docs/THREAT-MODEL.md:7`) — and it states its own status honestly: source-grounded design
assessment, NOT a penetration test or deployment attestation (`docs/THREAT-MODEL.md:3`).
What breaks if it is absent: controls get argued from "nobody would bother". What breaks
if it lies: an "Existing (source)" claim for a control the tree does not carry — which is
why every control row names its evidence boundary and the assets table marks what source
alone cannot prove (`docs/THREAT-MODEL.md:11-21`).

## 2. Dependencies and library contracts

| Dependency | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `AGENTS.md` rules 8 | this repo | the credential non-disclosure policy the assets table cites (`docs/THREAT-MODEL.md:13-14`) | the policy and the model disagree |
| `specs/ENVELOPE.md` + `scripts/verify-node.sh` | this repo | the integrity controls for results: envelope fields, optional byte digest comparison (`docs/THREAT-MODEL.md:18-21`) | an "existing control" row cites a retired mechanism |
| crier's per-agent signature | external relay | an unsigned read is refused BY DESIGN before lookup — the strongest existing control the node's claims rest on [fact: FACT-03] | the model's trust boundary inherits a weaker transport |
| the credential discipline | mode-600 pointer files, never argv | the assets table's confidentiality row [fact: FACT-05] | a secret enters argv and the model's assumption breaks |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| every locator on this page resolves | `python3 scripts/master_doc_check.py docs/handbook/appendices/units --only 58- --strict` | `MASTER-DOC: PASS` | 2026-11-22 | PASS |
| the objective sentence is on the named line | `sed -n 7p docs/THREAT-MODEL.md` | the security objective, verbatim | 2026-11-22 at `8f77667b` | PASS |
| the "existing controls" section names its proof status per row | `sed -n 36,55p docs/THREAT-MODEL.md` | each row marked Existing (source) / Recorded measurement / Recommendation | 2026-11-22 | PASS |

## 4. Metrics emitted

None. The model's measurable output is its disposition table — abuse cases mapped to
controls with named evidence boundaries (`docs/THREAT-MODEL.md:56-71`) — and the residual
risks it declines to resolve unilaterally (`docs/THREAT-MODEL.md:86-108`).

## 5. Log lines it can generate

- Nothing — an assessment. The control lines it describes belong to their components:
  crier's 401-before-lookup [fact: FACT-03], the node's `FAIL` rows for unsigned or
  unverified answers, and the gateway's public-bind refusal — each recorded on its own
  unit page, cited here only as evidence.

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| A control claimed "existing" without source | a false sense of cover | the vocabulary: Existing (source) vs Recorded measurement vs Recommendation (`docs/THREAT-MODEL.md:3,36-55`) | downgrade the row; implement the control |
| Repo-only proof treated as deployment attestation | "the node is secure" | the status line refuses exactly that claim (`docs/THREAT-MODEL.md:3`) | keep the evidence boundary row honest |
| An executed member escaping the digest | attacker-chosen code runs under a valid-looking brief | the runbook's digest-boundary rule (record 54, `docs/OPERATIONS.md:167`) | put the member inside the canonical object in the same change |

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| public-repo assumption | the repo's published state (`docs/THREAT-MODEL.md:3-5`) | no secrets, private hostnames or private IPs included — template boundary holds |
| credential custody | NOT inspected; expectations only (`docs/THREAT-MODEL.md:13-14`) [fact: FACT-05] | the model never claims to have audited live secrets |
| trust boundaries | control host / bunker / public contributor / compromised node or model (`docs/THREAT-MODEL.md:23-34`) | each actor's capability is named, not assumed |

## 8. Evidence of record

- The model: status `docs/THREAT-MODEL.md:3`, objective `:7`, assets `:11-21`, actors
  `:23-34`, existing controls `:36-55`, abuse cases `:56-71`, fail-closed rules `:72-85`,
  residuals `:86-108`, evidence boundary `:110-111`.
- The measured controls it leans on: the bus signature rule [fact: FACT-03] and the
  credential discipline [fact: FACT-05]; the digest boundary is carried by record 54.
- The fail-closed rules section aligns with the battery's negative fixtures: record 45.
