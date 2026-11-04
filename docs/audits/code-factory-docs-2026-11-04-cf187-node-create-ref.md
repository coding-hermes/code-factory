# CF-187 — the runbook still said the create path drops `--ref`, a claim the fix commit made false

Lane tick `code-factory-docs-2026-11-04-08-12-52`, fourth execution of that tick id. The first two
executions closed CF-176 (`e0ff859`, verdict dir `d731d2df`) and CF-155 (`32f38a5`, verdict dir
`69407914`); the third (`13f6d7d`) verified both and implemented nothing. This pass takes a claim
none of them touched, corrects it, and writes this suffixed evidence file rather than overwriting
the series file `docs/audits/code-factory-docs-2026-11-04.md`.

Row: CF-187 (filed by this tick). GitReins task: `CF-187-DOC1`.
Source tip: `gh/main` = `328ee68`; every command below was run in a `--no-hardlinks` clone of the
canonical checkout with `gh` added as the published remote.

## 1. The claim that was false

`docs/OPERATIONS.md:59`, §2 "BLOCKED provisioning path", last-but-two bullet:

> `project-node.sh` writes a manifest only when all its layers pass, but its manifest generation
> currently embeds `repo` and `ref` inputs; `node-create.sh` invokes it without passing `--ref`,
> while the clone uses the default `main`. Review before relying on manifest provenance.

That sentence was written on 2026-10-29 (`5356ba9`) and was true then. Commit `a112726`
2026-11-04 02:28 — *fix(node-create): accept and forward --ref so README step 3 is reachable
(CF-153)* — made it false: `node-create.sh` now parses `--ref` and forwards it into the in-node
`--apply` command, so the ref the manifest records and the ref the clone pins are one value.

The row that owned the defect (CF-153) is `complete`: it graded the code change, and the runbook
sentence it invalidated was never swept. That is the drift this tick corrects.

| File:line | Before | After |
|---|---|---|
| `docs/OPERATIONS.md:59` | manifest "embeds `repo` and `ref` inputs"; `node-create.sh` "invokes it without passing `--ref`"; "Review before relying on manifest provenance" | manifest records the `repo`/`ref` it was invoked with; `scripts/node-create.sh:63` parses `--ref`, `:83` escapes it, `:121` forwards it into the in-node `--apply`; the same `$REF` is what `scripts/project-node.sh:265` clones; CF-153 closed the code; the `bus.base` remainder belongs to CF-078 |
| `docs/OPERATIONS.md:24` | `scripts/node-create.sh:69-72` | `scripts/node-create.sh:73-76` (the `CRIER_URL` refusal, moved by the same two commits) |
| `docs/OPERATIONS.md:47` | gate order `scripts/node-create.sh:69-79`; `CRIER_URL` forwarded "as a single-quoted assignment (`:112`)" | gate order `scripts/node-create.sh:73-88`; `CRIER_URL` **and** `--ref` forwarded as `shq`-escaped assignments (`scripts/lib.sh:54-57`, `:80` and `:83`, used at `:121`) |

## 2. Code path that proves the new statement

`scripts/node-create.sh` (published tree):

```
18:PROJECT="" REPO="" REF="${NODE_REF:-main}" HARNESS="hermes" ...
63:    --ref) REF="$2"; shift 2 ;;
73:if [ -z "${CRIER_URL:-}" ]; then
74:  bad "crier_url" "CRIER_URL unset or empty — export CRIER_URL=http://crier.example:8767"
83:REF_QUOTED=$(shq "$REF")
85:if [ -z "$SERVER" ]; then
86:  bad "server_declared" "BUNKER_SERVER unset — no agent host to create the node on"
121:     "NODE_PROJECT=$PROJECT_QUOTED NODE_GATEWAY_PORT=$PORT_QUOTED CRIER_URL=$CRIER_QUOTED ~/node-scripts/project-node.sh --apply --project $PROJECT_QUOTED --harness $HARNESS_QUOTED --repo $REPO_QUOTED --ref $REF_QUOTED"; then
```

`scripts/project-node.sh`:

```
53:    --ref) REF="$2"; shift 2 ;;
265:      if git clone --depth 1 --branch "$REF" "$REPO" "$RP" >"$clone_log" 2>&1; then
299:path, project, harness, port, repo, ref, host = sys.argv[1:8]
301:           "repo": {"origin": repo, "ref": ref, "path": ...},
303:           "bus": {"base": __import__("os").environ.get("CRIER_BASE", "http://crier.example:8767")},
```

The create command's `--ref` value therefore reaches both readers as one string: the clone
(`project-node.sh:265`) and the manifest field (`:301`). The manifest's `bus.base` is the one field
still filled from an environment variable no shipped stage sets (`scripts/project-node.sh:303`),
which is CF-078's subject, not this correction's.

## 3. Literal command output — two arms, opposite verdicts

Arm 1, the parent tree (`a112726^`) — the documented create form rejected the flag, which is why
the sentence was true when written:

```
$ cp -r scripts $S/proof/scripts-prefix
$ git show a112726^:scripts/node-create.sh > $S/proof/scripts-prefix/node-create.sh
$ bash -n $S/proof/scripts-prefix/node-create.sh && echo "syntax ok"
syntax ok
$ bash $S/proof/scripts-prefix/node-create.sh --staged-files --ref master
unknown arg: --ref
rc=2
```

Arm 2, the published tree (`gh/main` = `328ee68`):

```
$ bash scripts/node-create.sh --staged-files --ref master
project-node.sh
lib.sh
disk_floor.py
reclaim_disk.py
harness/install-hermes.sh
rc=0
```

Arm 3, the forwarding sites (static, the sentence's own subject):

```
$ grep -n 'REF="${NODE_REF\|--ref) REF\|REF_QUOTED\|--ref $REF_QUOTED' scripts/node-create.sh
18:PROJECT="" REPO="" REF="${NODE_REF:-main}" ...
63:    --ref) REF="$2"; shift 2 ;;
83:REF_QUOTED=$(shq "$REF")
121:     "NODE_PROJECT=$PROJECT_QUOTED ... --ref $REF_QUOTED"; then
```

Arm 4, the claim is gone from the corrected file:

```
$ grep -c 'invokes it without passing' docs/OPERATIONS.md
0
$ grep -c 'scripts/node-create.sh:63' docs/OPERATIONS.md
1
```

## 4. Claims checked that came back TRUE (not changed)

| Claim | Command | Result |
|---|---|---|
| `--staged-files` prints the five staged files and needs no bunker | `bash scripts/node-create.sh --staged-files --ref master` | five names, rc 0 |
| gate order is `crier_url` before `server_declared`, both before any bunker call | `grep -n 'bad "crier_url"\|bad "server_declared"\|have bunker' scripts/node-create.sh` | `:74`, `:86`, `:91` — both refusals precede the client lookup |
| `--ref` defaults to `main` | `scripts/node-create.sh:18` | `REF="${NODE_REF:-main}"` |
| layer 40 clones the forwarded ref | `scripts/project-node.sh:265` | `git clone --depth 1 --branch "$REF"` |

## 5. Claims I could not verify

- **An end-to-end create with a non-`main` ref.** Not measured: no bunker server or agent was used
  in this tick, and the runbook itself is a design/runbook, not an installation receipt. The
  correction is a statement about the shipped code path, and it says so.
- **That the node-side manifest's `repo.ref` is what `git -C $HOME/repo rev-parse` reports.** Not
  measured here; it follows from the forwarded value only when the clone succeeds, which no tick
  has observed on a live node for a non-`main` ref.
- **`docs/OPERATIONS.md`'s remaining §7 sentence** ("It checks shell syntax, a node-checker
  failure path, `fetch_verified` digest mismatch handling, literal credential assignments, and
  board JSONL parseability") still describes a five-item subset of a 39-arm suite. It is not false
  — those five are still checked — but it is not a census. Left alone deliberately: the lane
  corrects contradictions, and re-censusing `tests/selftest.sh` is CF-155's surface.

ch:trace row=CF-187 spec=docs/OPERATIONS.md#blocked-provisioning-path test=scripts/node-create.sh::ref-forwarding doc=docs/OPERATIONS.md prompt=prompts/docs.md evidence=docs/audits/code-factory-docs-2026-11-04-cf186-node-create-ref.md witness=cmd:arm1-unknown-arg-rc2-vs-arm2-staged-set-rc0 verdict=CF-187-DOC1 commit=self tick=code-factory-docs-2026-11-04-08-12-52

STATUS: complete
TIER: T3 — both arms executed against the shipped trees, plus a static code-path read with line numbers
EVIDENCE: this file (two-arm transcript in §3) + `bash tests/selftest.sh` at the corrected tree
