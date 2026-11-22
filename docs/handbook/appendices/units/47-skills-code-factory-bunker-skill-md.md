# 47. skills/code-factory-bunker/SKILL.md — the node onboarding skill

| Field | Value |
|---|---|
| Path | `~/code-factory/skills/code-factory-bunker/SKILL.md` |
| Repository | `code-factory` |
| Revision | `8f77667b` |
| Status | **VERIFIED — the onboarding document is described from its own lines; the scripts it names are the record-covered provisioner units** |

## 1. Purpose and why it matters

The skill an agent loads before it provisions, verifies, refreshes or destroys a project's
bunker node. Its isolation law is one line: every lane of a project enters that project's
single bunker — one clone, one harness, one router, one memory namespace; no two projects
share a bunker (`skills/code-factory-bunker/SKILL.md:13-16`) [fact: FACT-02]. What breaks
if it is absent: a foreman improvises provisioning and a node ends up hand-edited, or two
projects share a bunker and the isolation boundary silently dissolves. What breaks if it
lies: an operator believes a signed read alone proves connection — the skill states the
route check is the proof and the signed read is additional evidence, never a replacement
(`skills/code-factory-bunker/SKILL.md:24-25`).

## 2. Dependencies and library contracts

| Dependency | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `scripts/bunker-provision.sh` | this repo | config + agent lifecycle + clone + auth bundle + identity; `--destroy --yes` or it refuses and names what it would remove (`skills/code-factory-bunker/SKILL.md:19-30`) | the skill's script table drifts from the recorded provisioner (unit 05) |
| `scripts/bunker-crier-connect.sh` | this repo | stages `crier.json` at mode 600, proves the inbox route with 200; 401/403/404/000 named distinctly (`skills/code-factory-bunker/SKILL.md:24-25, 46-55`) | the connect ladder vocabulary changes under the skill's prose |
| `scripts/lib.sh` | this repo | both scripts share it; neither takes a secret as an argument (`skills/code-factory-bunker/SKILL.md:19-22`) | secrets leak into argv, breaking the credential rule [fact: FACT-05] |
| the config file | `config/bunker.example.conf` | KEY=VALUE data, never sourced (`skills/code-factory-bunker/SKILL.md:52-55`) | a config becomes a script |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| every locator on this page resolves | `python3 scripts/master_doc_check.py docs/handbook/appendices/units --only 47- --strict` | `MASTER-DOC: PASS` | 2026-11-22 | PASS |
| the named scripts exist and carry `--check`/`--apply` | `grep -l "\-\-check" scripts/bunker-provision.sh scripts/bunker-crier-connect.sh` | both files | 2026-11-22 at `8f77667b` | PASS |
| the fleet copy claim matches the tree | the skill names `~/.hermes/skills/coding-hermes/code-factory-bunker/SKILL.md` as the installed copy (`skills/code-factory-bunker/SKILL.md:33-35`) | the repo copy is the source of that text | 2026-11-22 | PASS — same two scripts named |

## 4. Metrics emitted

None. The skill is an instruction document; its outcomes are the scripts' own rows
(`BUNKER: PASS`, `CONNECTED`, the named refusal rows), which the provisioner record (05)
and the connect ladder vocabulary already carry.

## 5. Log lines it can generate

- Nothing directly — the skill is prose. The lines an operator following it sees are the
  scripts': `CONNECTED` only on a route 200 (`skills/code-factory-bunker/SKILL.md:24-25`),
  `UNVERIFIED` (exit 3) on an unsigned answer, and the provisioner's refusal naming the
  exact agent and server on a `--destroy` without `--yes` (`:26-28`).

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Second project placed on an existing bunker | cross-project lanes share clone/harness/memory | the isolation law is the first section; a second project means a second agent (`:13-16`) | provision a second agent; never widen the bunker |
| Signed read trusted over the route check | `CONNECTED` claimed from a node-side 200 alone | the skill names 401/403/404/000 as distinct and the route check as the proof (`:24-25`) | re-run the connect script's own ladder |
| Config sourced instead of parsed | a shell line in the conf executes | the grammar section: every non-comment line must be KEY=VALUE (`:52-55`) | fix the line; the provisioner refuses non-KEY=VALUE (record 49) |

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| the bunker config | `~/.config/code-factory/<project>.conf` per config/bunker.example.conf | KEY=VALUE data; command line overrides; never sourced |
| credential files | mode-600 paths named in the config, never values [fact: FACT-05] | the skill's scripts never take a secret as an argument |
| fleet-installed copy | `~/.hermes/skills/coding-hermes/code-factory-bunker/SKILL.md` | the repo copy is the source; the installed copy must name the same commands |

## 8. Evidence of record

- The skill itself: isolation law `skills/code-factory-bunker/SKILL.md:13-16`, script
  table `:19-30`, destroy refusal `:26-28`, route-proof rule `:24-25`, config grammar
  `:52-55`, fleet-copy note `:33-35`.
- The enforcing units it drives: provisioner record 05, connect script, and the config
  contract record 49; the foreman prompt binds provisioning to this skill
  (`prompts/foreman.md:105-107`).
- Topology facts this skill operationalizes: fact: FACT-02 (one bunker serves one
  project), fact: FACT-05 (credentials as file paths).
