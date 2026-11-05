# SPEC — harness matrix

Which harness runs which model, what every harness must be given, and what it must report back.
This is the design authority for the harness work; `specs/HARNESS.md` owns the adapter
contract, `specs/NODE.md` owns the node, and this file owns the **selection rule** and the
**variable contract** that binds them.

Measured inputs for every claim here: `/home/kara/code-factory-reports/spec-crier-harness-support-2026-11-05.md`
(crier adapter set, file:line) and `/home/kara/code-factory-reports/spec-bunker-toolchain-2026-11-05.md`
(what a node must install beyond the harness).

---

## 1. The invariants

**I1 — The foreman is always Hermes.** Every lane that grades, closes a row, writes the board,
or decides "this is done" runs on Hermes, on the node, with the coding-hermes skills loaded. No
model choice changes this. Reason: the foreman owns the evidence chain (`boardctl`, tick
accounting, artifact digests). A harness that cannot write the board cannot be the foreman.

**I2 — A worker lane's harness follows its model family.** task-router picks a model; the model
family picks the harness. A Claude model is not run through Codex because a node happened to be
provisioned with Codex. Selection is by data, never by which binary is on PATH:

```
lane.model  ->  family  ->  harness        (resolution order: directive > node default > refuse)
```

**I3 — Every harness reports to the same DuckBrain namespace.** Whether the work ran in
claude-code, codex, pi or hermes, the memory write is the same shape: same namespace as the
project, same key grammar, same provenance fields (`run_id`, `lane`, `model_requested`,
`model_served`, `harness`, `harness_version`, `commit`, `tick`). A harness that cannot report
this is not supported, regardless of whether it can code. This is the requirement that makes the
matrix worth having: five harnesses, one memory.

**I4 — Nothing is supported because it is installed.** Support means five green legs in the
conformance battery (`PASS`/`SKIP`/`FAIL` with a measured value), on a real node, for a real
turn. `--check` alone is not support.

**I5 — The node refuses what it cannot run.** A directive naming a harness the node cannot
resolve is a named failure (`harness_unsupported: <name>; node has: <set>`), never a silent
fallback to Hermes. Hermes is the fallback only where the *policy* says so (§3), not the
implementation.

---

## 2. The matrix

| Model family (prefix) | Harness | State today | Evidence |
|---|---|---|---|
| `claude-*`, `anthropic/*` | **claude-code** | **ABSENT** — crier has never heard of it (`grep claude` → only an example Dockerfile); installer is check-only and refuses | audit §2 |
| `gpt-*`, `o1*`, `o3*`, `o4*`, `codex*`, provider `openai` / `openai-codex` | **codex** | adapter exists (`internal/harness/codex/codex.go`), **binary absent** on the host, **no installer in this repo** | audit §2, §7 |
| `deepseek-*` | **hermes** (policy fallback) — *a "deepseek harness" does not exist in either repo* | adapter: none; the name resolves nowhere | audit §2 |
| `pi-*`, provider `pi` | **pi** (`omp` = oh-my-pi is its installer) | adapter exists as **`pi`**, so the spelling `pi-agent` fails; no installer | audit §2; toolchain §3 |
| `qwen*`, `glm*`, `kimi*`, `gemini*`, `grok*`, local/OSS models | **opencode** | adapter exists (v1, live 1.18.29); installer check-only; **no v2 artefact exists** (`opencode2` is a squatted `0.0.1-security`) | audit §2 |
| anything else, and every foreman lane | **hermes** | **MEASURED**: pin 0.19.0, gateway `/api/status 200`, bus worker READY on `cf-node` | this session |

**Why Hermes is the fallback and not merely "another adapter":** it is model-agnostic — it talks
to any provider through its own gateway — so `deepseek-*`, an unknown family, or a family whose
native harness is not installed can still run *something* with full DuckBrain reporting. The
specialised harnesses exist because they use the model's native surface better, not because
Hermes cannot run the model.

---

## 3. The resolution rule

```
harness = directive.harness                       # explicit wins
        | matrix[lane.model.family]               # else the matrix
        | "hermes"                                # else policy fallback (foreman lanes always)
```

Refuse, do not fall back, when: the lane is a foreman lane and the harness is not hermes (I1);
the harness is not installed on the node **and** the model family has a native harness (running
Claude through opencode silently changes what the evidence means); the directive names an
unknown harness (I5).

Record the decision: every run writes `harness_selected`, `harness_reason`
(`directive|matrix|fallback`), and `model_requested` vs `model_served`. A fallback that is not
recorded is indistinguishable from a mistake.

---

## 4. The variable contract — what an installer and a harness are given

The same set goes to `scripts/harness/install-<name>.sh --apply` and to the harness at run time
(from the directive, never from the node's ambient environment). Names are stable; a harness that
needs an additional input must declare it in its adapter section and add it here.

| Variable | Meaning | Rule |
|---|---|---|
| `CF_MODEL` | model id requested by task-router | required |
| `CF_PROVIDER` | provider lane (`anthropic`, `openai-codex`, `deepseek`, `pi`, …) | required |
| `CF_BASE_URL` | endpoint the harness must talk to (the node's router or the gateway) | optional; default = node router |
| `CF_API_KEY_FILE` | **path** to a mode-600 file holding the key | required for a paid provider; **a value in argv is a FAIL** (AGENTS.md r8) |
| `CF_WORKDIR` | the clone the harness may write in | required; must be inside `$HOME` |
| `CF_NAMESPACE` | DuckBrain namespace for the run's writes | required (I3) |
| `CF_RUN_ID` | correlation id from the bus envelope | required; echoed into every memory write |
| `CF_LANE` | lane name (e.g. `code-factory-qa`) | required; the node serves one project, many lanes |
| `CF_SKILLS_DIR` | seeded skills root on the node | optional; Hermes requires it, others accept it |
| `CF_MAX_TURNS` / `CF_TIMEOUT_S` | budget | optional; default 40 / 1800 |

Two rules that are cheap now and expensive later: **no credential is ever passed as a value**, and
**no harness may read a model or a key from the node's ambient environment** — the directive is
the only source, so two lanes on one node cannot contaminate each other.

---

## 5. What "wired up" means, per harness

Five legs. A harness is supported when all five are `PASS` on a real node, and `SKIP` is only
acceptable when the reason is named (no credential, no artefact).

| Leg | Proves |
|---|---|
`check` | the adapter reports absence honestly and a version that was read back |
`install` | `--apply` is idempotent, user-space, pinned, and the pin is measured after install |
`vars` | the harness accepts the §4 set and the *negative* case fails: a value in argv or an ambient key is refused |
`turn` | one real turn produces a known artifact (a file with a fixed token), and the run reports `model_served` |
`memory` | the run writes the §1-I3 record to DuckBrain with the correct namespace and `run_id`, read back by the battery |

`tests/harness-conformance.sh` is the implementation of this table; its matrix is the release
gate for the word "supported".

---

## 6. Non-claims

- **opencode v2 is not a thing we can install.** There is no v2 artefact: `opencode2` on npm is
  `0.0.1-security` (squatted) and `opencode-ai@latest` is 1.19.5, the v1 line. The matrix has one
  `opencode`, and a v2 id is refused in writing until an artefact exists (CRIER-HARNESS-10).
- **There is no "deepseek harness".** The only `deepseek` in either repo is a guard *provider*
  preset. `deepseek-*` models run on Hermes by policy until someone builds one (CF-226).
- **claude-code is unimplemented in crier.** Its row is `CRIER-HARNESS-11`; the matrix cannot
  promise it before that lands.
- **Aider and goose** appear in `specs/HARNESS.md`'s older table and are not in this matrix; they
  are unmeasured and unlisted here deliberately.
