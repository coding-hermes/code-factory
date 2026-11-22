# 52. config/node.env.example — the declared environment of one node

| Field | Value |
|---|---|
| Path | `~/code-factory/config/node.env.example` |
| Repository | `code-factory` |
| Revision | `8f77667b` |
| Status | **VERIFIED — the profile grammar is described alongside the applier that enforces it; the refusal lines were read at this revision** |

## 1. Purpose and why it matters

The environment profile `scripts/node_env.py` applies ON a node: `ENV_<NAME>=<value>` puts
a literal into `~/.hermes/.env`, `ENV_<NAME>=@<path>` reads the value from a mode-600 file,
and `CONFIG_SET_*` declares the only five config scalars a profile may own
(`config/node.env.example:1-13,24-31`). The example is committed, copied to nodes and
quoted in diffs — so its secret rule is absolute: a name matching
KEY|TOKEN|SECRET|PASS must use the `@<path>` form, and node_env.py refuses a literal by
name without echoing the value (`config/node.env.example:14-20`; `scripts/node_env.py:178`)
[fact: FACT-05]. What breaks if it is absent: nodes are configured by hand-edited env
files that drift and cannot be re-checked. What breaks if it lies: a literal secret ships
in a committed file — the exact leak the grammar exists to refuse.

## 2. Dependencies and library contracts

| Dependency | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `scripts/node_env.py` | this repo | the line grammar `ENV_LINE` (`scripts/node_env.py:52`), per-line match (`:294,304`), and the secret refusal on resolve (`:178`); `--check` prints drift, `--apply` closes it (`config/node.env.example:7-9`) | the example's grammar and the applier's regex drift apart |
| `config/bunker.example.conf` | this repo | names this file via `NODE_ENV_FILE` (`config/bunker.example.conf:48-49`) | the two files disagree on the profile path |
| `~/.hermes/config.yaml` | the node's Hermes | the only `CONFIG_SET_*` targets allowed (`config/node.env.example:24-31`) | a guessed key produces a setting nothing honours |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| every locator on this page resolves | `python3 scripts/master_doc_check.py docs/handbook/appendices/units --only 52- --strict` | `MASTER-DOC: PASS` | 2026-11-22 | PASS |
| the example carries no literal secret | `grep -n "^ENV_" config/node.env.example` | the one ENV line uses the `@~/.node/...` form | 2026-11-22 at `8f77667b` | PASS — `ENV_CF_PROXY_API_KEY=@~/.node/auth/provider.key` |
| the applier refuses a literal for a secret-named key | `scripts/node_env.py:178` ("A literal value for a secret-named key is refused") | refusal, not echo | 2026-11-22 (read) | PASS |

## 4. Metrics emitted

None. The applier's observable output is its per-line check rows (what drifted, what was
applied) and its named refusals; the file itself is inert data.

## 5. Log lines it can generate

- Through `node_env.py`: a refusal naming the profile and line — `ENV_<name>=@ names no
  file` for a dangling pointer, the empty-value refusal for an empty target
  (`scripts/node_env.py:189,201`), and the literal-secret refusal on resolve
  (`scripts/node_env.py:178`) — none of which ever prints the secret value.

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| A literal secret in a committed profile | a credential in git history | the grammar rule + the applier's refusal (`config/node.env.example:14-20`; `scripts/node_env.py:178`) | switch to `@<path>`; rotate the value |
| A `CONFIG_SET_*` key guessed outside the five | a setting nothing honours | the closed list + "any other path is refused by name" (`config/node.env.example:26-31`) | use only the declared scalars |
| An inline comment after a value | the comment becomes part of the value | the grammar: a value is everything after the first `=` — no inline comments, no quoting (`config/node.env.example:10-13`) | move comments to their own lines |

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| `NODE_ENV_FILE` | the project's bunker conf | the profile path the provisioner stages (`config/bunker.example.conf:48-49`) |
| node-side target files | `@<path>` targets, leading `~/` is the node's own `$HOME` (`config/node.env.example:11-12`) | targets exist at mode 600 before apply |
| the five config scalars | `~/.hermes/config.yaml` on the node | model.provider/model.name/gateway.bind/gateway.port/agent.max_iterations only |

## 8. Evidence of record

- The example: header + grammar `config/node.env.example:1-13`, secret rule `:14-20`,
  the restricted key line `:18-22`, closed CONFIG_SET list `:24-31`.
- The applier: grammar `scripts/node_env.py:52`, resolve contract `:178`, match sites
  `:294,304`, pointer refusals `:189,201`.
- The credential discipline implemented here: fact: FACT-05.
