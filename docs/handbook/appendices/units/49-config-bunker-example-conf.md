# 49. config/bunker.example.conf — the provisioning contract a user fills in

| Field | Value |
|---|---|
| Path | `~/code-factory/config/bunker.example.conf` |
| Repository | `code-factory` |
| Revision | `8f77667b` |
| Status | **VERIFIED — the example is described alongside the parser that enforces it; the refusal lines below were read at this revision** |

## 1. Purpose and why it matters

The KEY=VALUE contract an operator copies to `~/.config/code-factory/<project>.conf` and
fills in before `bunker-provision.sh --apply`. Its own header states the boundary: no
secrets in this file — it names the token files the provisioner reads into a single 600
bundle and deletes (`config/bunker.example.conf:1-5`); credentials travel as file paths,
never values [fact: FACT-05]. What breaks if it is absent: provisioning answers are
invented per invocation and no two nodes are built from comparable declarations. What
breaks if it lies: the file becomes a script — the provisioner refuses any line that is
not KEY=VALUE rather than sourcing it (`scripts/bunker-provision.sh:9,130`).

## 2. Dependencies and library contracts

| Dependency | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `scripts/bunker-provision.sh` | this repo | parses the file as data: a non-KEY=VALUE line is a named refusal, a clean file passes as `KEY=VALUE only` (`scripts/bunker-provision.sh:130,148`) | the example's keys and the parser's key set drift apart |
| `scripts/bunker_config_gen.py` | this repo | turns operator answers into this file's shape (unit 07) | the example stops matching the generator |
| bus credentials | `CRIER_AGENT_KEY_FILE` + `CRIER_AUTH_TOKEN_FILE` | without both, the node's inbox answers 401 to every read — the file's comment names the per-agent ed25519 signature AND the shared bearer (`config/bunker.example.conf:37-40`) [fact: FACT-03] | a node provisions "successfully" and still cannot read its inbox |
| GitHub auth | `GITHUB_TOKEN_FILE` or the App mode (`#GITHUB_AUTH_MODE=app`) | token paths, never values; the App private key stays on the control host (`config/bunker.example.conf:28-33`) | push rights silently vanish an hour in (record 50's refresh rule) |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| every locator on this page resolves | `python3 scripts/master_doc_check.py docs/handbook/appendices/units --only 49- --strict` | `MASTER-DOC: PASS` | 2026-11-22 | PASS |
| the example carries no literal secret | `grep -nE "(KEY|TOKEN|SECRET|PASS)=." config/bunker.example.conf` | only `*_FILE=` pointer assignments | 2026-11-22 at `8f77667b` | PASS — every credential line is a `*_FILE` path |
| the parser refuses a non-KEY=VALUE line | the refusal row at `scripts/bunker-provision.sh:130` | `bad "config" "$file:$n is not KEY=VALUE — refusing to run it"` | 2026-11-22 (read) | PASS — the guard is the same arm selftest drives |

## 4. Metrics emitted

None. The file is data; the observable output is the provisioner's config row
(`ok "config" ... KEY=VALUE only`, `scripts/bunker-provision.sh:148`) and the refusal row
when a line breaks the grammar — both carried by the provisioner record (05).

## 5. Log lines it can generate

- Nothing by itself. Through the provisioner: `ok "config" "<name> — N lines, KEY=VALUE
  only"` on a clean parse (`scripts/bunker-provision.sh:148`), and `bad "config"
  "<file>:<n> is not KEY=VALUE — refusing to run it"` on a grammar breach
  (`scripts/bunker-provision.sh:130`) — the line that keeps a config from becoming a script.

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| A secret pasted as a literal value | the file diffs a credential | the header rule + the `*_FILE` convention (`config/bunker.example.conf:2,29-33`) | replace with the pointer form; rotate the leaked value |
| An SSH REPO URL | provisioning cannot authenticate | the header: REPO must be HTTPS — the bundle installs an HTTPS credential store, not SSH keys (`config/bunker.example.conf:4-5`) | use the HTTPS remote |
| A shell line in the conf | provisioner refuses, naming the line | a parse the file was designed to fail (`scripts/bunker-provision.sh:130`) | fix the line to KEY=VALUE |
| Missing refresh timer in App mode | node loses push rights after one hour | the commented arm names the 20-minute refresh (`config/bunker.example.conf:30-31`; record 50) | arm `scripts/github-app-refresh.sh` |

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| operator identity | `GIT_AUTHOR_NAME`/`GIT_AUTHOR_EMAIL` (`config/bunker.example.conf:20-23`) | required for `--apply` — a node that commits anonymously is worse than one that refuses |
| node environment | optional `NODE_ENV_FILE` + the five `CONFIG_SET_*` scalars (`config/bunker.example.conf:48-54`) | only the declared keys exist; the grammar is record 52's |
| service URLs | `CRIER_URL`, `DUCKBRAIN_URL` (`config/bunker.example.conf:42-43`) | the two services a node must reach |

## 8. Evidence of record

- The example: header law `config/bunker.example.conf:1-5`, identity `:20-23`, credential
  pointers `:29-33`, bus pair `:37-40`, env grammar pointer `:48-54`.
- The enforcing parser: `scripts/bunker-provision.sh:9` (data, never executed), `:130`
  (refusal), `:148` (clean-parse row).
- The bus signature rule the file's comment states is the measured control: fact: FACT-03;
  the pointer-not-value rule: fact: FACT-05.
- The onboarding skill that binds operators to this file: record 47, config grammar
  section (`skills/code-factory-bunker/SKILL.md:52-55`).
