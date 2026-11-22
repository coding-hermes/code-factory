# 53. config/node-seed.txt — the seed manifest

| Field | Value |
|---|---|
| Path | `~/code-factory/config/node-seed.txt` |
| Repository | `code-factory` |
| Revision | `8f77667b` |
| Status | **VERIFIED — the manifest is described alongside the seeder that reads it and the provisioner stage that applies it; all read at this revision** |

## 1. Purpose and why it matters

The whole story of what lands on a node: every line is a path or glob relative to the repo
root, and a file NOT named here is not seeded — the exclusion mechanism is the absence of
a line (`config/node-seed.txt:1-6`). The named set is the agent's operating surface:
`prompts/*.md` and the skills tree (`config/node-seed.txt:10-13`). Board state is
deliberately absent — `.coding-hermes/` is excluded because the board is delivered by git,
not a seed (`config/node-seed.txt:5-6`) [fact: FACT-09]. What breaks if it is absent: the
seed applies everything, and a node receives wave logs, backup tarballs and the operator's
full skill library. What breaks if it lies: a node believes it holds files its seed record
never declared — which the verifier refuses: a record declaring no files certifies nothing,
and `N seeded files present and matching` passes only for N > 0.

## 2. Dependencies and library contracts

| Dependency | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `scripts/node_seed.py` | this repo | reads this manifest by default (`DEFAULT_MANIFEST = "config/node-seed.txt"`, `scripts/node_seed.py:43`), builds a tar and digest-records every seeded file (CF-220, `scripts/node_seed.py:2`) | nodes seed content no record declares |
| `scripts/bunker-provision.sh` | this repo | stages the seed inside `--apply`: resolves the manifest next to the repo root (`scripts/bunker-provision.sh:613`) and applies it on the node (`:617-623`) | the seed stage and the manifest drift |
| `scripts/verify-node.sh` | this repo | step 6 compares the node's seeded files against the digests the seed record names | a seeded-but-unrecorded file is invisible |
| git | host | the delivery channel for everything the manifest excludes (board state) [fact: FACT-09] | seeding becomes the delivery mechanism for mutable state |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| every locator on this page resolves | `python3 scripts/master_doc_check.py docs/handbook/appendices/units --only 53- --strict` | `MASTER-DOC: PASS` | 2026-11-22 | PASS |
| the manifest names no mutable state | `cat config/node-seed.txt` | only prompts and skills globs; no `.coding-hermes/`, no backups | 2026-11-22 at `8f77667b` | PASS — four globs, all prompts/skills |
| the seeder reads this manifest by default | `scripts/node_seed.py:43` | `DEFAULT_MANIFEST` names it | 2026-11-22 (read) | PASS |

## 4. Metrics emitted

None in the manifest. The seeder's output is the per-file digest record (`seed.tar.json`)
and the applied count — the same numbers `verify-node.sh` step 6 grades, where a record
declaring no files is itself the named failure.

## 5. Log lines it can generate

- Through the provisioner's seed stage: the build/apply ladder
  (`scripts/bunker-provision.sh:613-623`) and, on verification, the
  `seed_drift` row — including the named refusal `the record declares no files … an empty
  seed certifies nothing` that keeps a zero-file apply from certifying a node.

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Mutable state added to the manifest | nodes receive board/backup content | the exclusion note names the deliberately-absent classes (`config/node-seed.txt:4-6`) | remove the line; deliver via git [fact: FACT-09] |
| A glob that matches nothing | a seed record with zero files | the verifier's refusal: an empty seed certifies nothing | fix the glob; re-seed |
| Drift after apply | a node's file differs from its recorded digest | `node_seed_drift.py` compares digests against the repo | re-apply the seed |

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| repo-root-relative globs | the manifest's lines (`config/node-seed.txt:10-13`) | every path is relative to the repo root; nothing outside the tree seeds |
| the node's `$HOME` | apply target | the tar unpacks into the node home; digests recorded per file |
| seed record | `seed.tar.json` on the node | must declare at least one file to certify anything |

## 8. Evidence of record

- The manifest: exclusion law `config/node-seed.txt:1-6`, named globs `:10-13`.
- The seeder: `scripts/node_seed.py:2` (CF-220 digest contract), `:43` (default
  manifest); the provisioner stage `scripts/bunker-provision.sh:613-623`.
- The zero-file refusal that makes absence measurable is recorded on the runbook page:
  docs/OPERATIONS.md:148.
- Board delivery discipline: fact: FACT-09.
