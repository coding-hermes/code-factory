# code-factory docs tick — 2026-11-04T02:39:16-05:00 (layer 20)

Lane: `code-factory-docs`. Baseline HEAD at selection: `4bf29e9`. Sibling lanes land on this
checkout continuously; the binding SHA is the implementation commit named in the tray below.

Filename note: `docs/audits/code-factory-docs-2026-11-04.md` already exists in-tree from `2c48149`
(committed 2026-11-03 21:46, header naming this same tick id) and records the **CF-079** correction
to layers 30 and 90. This file is the same tick id's separate correction and does not overwrite it.

## 1. The claim corrected

`specs/NODE.md` layer table row **20 harness** claimed the ladder *establishes* "the chosen harness
+ its gateway/CLI". The shipped create path cannot reach a started gateway: the Hermes adapter starts
`hermes serve` only when `~/.hermes/config.yaml` already carries `dashboard.basic_auth`, and no
shipped stage writes that file. This is the last cell of the class that `6f75e28` (layer 40) and
`2c48149` (layers 30, 90) narrowed. Row `CF-150` records the same defect as a create-path bug and
named the missing documentation half ("and no doc says how").

| # | File:line | Claim (before) | Correction (after) |
|---|---|---|---|
| 1 | `specs/NODE.md:28` | "the chosen harness + its gateway/CLI" | the harness binary plus the adapter's own gate rows, printed verbatim (`python`, `binary`, `version`, `port`, `inference_key`, `gateway_start`); `gateway_start` is a **refusal** on a node whose `~/.hermes/config.yaml` carries no `dashboard.basic_auth` |
| 2 | `specs/NODE.md:33-45` | "Two capabilities … not established by any shipped layer" | "Three capabilities …", new first bullet **A started gateway on a freshly created node**: the create path, the adapter gate, `HERMES: FAIL (n)` → `NODE: FAIL (n)`, `NODE: PASS` unreachable, and "not measured" for the agent image |
| 3 | `docs/OPERATIONS.md:11` | create-path boundary named only the missing crier identity bundle | adds: the create path stages no `~/.hermes/config.yaml`, so the adapter refuses the public bind and layer 20 fails (CF-150) |

Nothing else in either file was touched: `git diff --stat` → `docs/OPERATIONS.md | 2 +-`,
`specs/NODE.md | 15 +++++++++++++--`.

## 2. The code path that proves the new statement

| Evidence | Path | What it shows |
|---|---|---|
| The gate | `scripts/harness/install-hermes.sh:93-102` | `if ! (ss … grep -q ":$PORT ")` → `if grep -q 'basic_auth' "$HOME/.hermes/config.yaml"` → start `hermes serve`; **else** `bad "gateway_start" "refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml"` (line 100) |
| The caller | `scripts/project-node.sh:228`, `:233-236`, `:318` | layer 20 runs the adapter with `--apply`; the adapter's `  FAIL` rows are counted into the parent counter, so the refusal reaches `NODE: FAIL (n)` |
| The create path | `scripts/node-create.sh` (`--staged-files`) | stages exactly five files: `project-node.sh`, `lib.sh`, `disk_floor.py`, `reclaim_disk.py`, `harness/install-hermes.sh` — no `config.yaml` |
| No writer anywhere | `grep -rnE 'config\.yaml"?[[:space:]]*>>?\|tee .*config\.yaml\|write_text.*config\.yaml\|safe_dump' scripts/` | 0 hits: the file is only read (`install-hermes.sh:94`) |

## 3. Literal command output

Transcripts committed beside this file: `docs/audits/code-factory-CF-150-DOC1.probe.txt` (arms A/B,
staged-file census, writer grep) and `docs/audits/code-factory-CF-150-DOC1.layer20.txt` (the ladder).

Arm A — create-path state (throwaway `HOME`, no `config.yaml`, stub `$HOME/hermes-venv/bin/hermes`
so no network or pip is involved):

```
apply
  ..    already installed: hermes 0.19.0
  FAIL  gateway_start — refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml

HERMES: FAIL (3)
arm_rc=1
```

Arm B — control, same fixture plus a `dashboard.basic_auth` block: the refusal row is gone and the
branch runs (`FAIL gateway_start — -> 000000` comes from the stub exiting immediately; the doubled
`000` is the shipped `curl … || echo 000` at line 97 firing after curl itself wrote `000`). This is
what proves the gate is exactly the `basic_auth` grep and not something else.

Arm C — the ladder's own end, scoped to layer 20:

```
[20] harness
…
  FAIL  gateway_start — refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml

HERMES: FAIL (3)
  SKIP  layer 30 (out of scope)
  SKIP  layer 40 (out of scope)
  SKIP  layer 90 (fixture mode: no manifest)

NODE: FAIL (3)
layer20_rc=1
```

Staged-file census, printed by the shipped code:

```
project-node.sh
lib.sh
disk_floor.py
reclaim_disk.py
harness/install-hermes.sh
staged_rows=5
staged_config_yaml=0
```

Re-run the whole set from the repository root: `bash tests/selftest.sh`,
`bash scripts/node-create.sh --staged-files`, and the two committed transcripts (each is the saved
stdout of a staged probe script quoted in §2).

## 4. Claims I could not verify

- Whether a bunker agent image already ships `~/.hermes/config.yaml` with `dashboard.basic_auth` —
  **not measured**. No agent was spawned by this tick; the correction says so in the same sentence.
- Whether layer 20 succeeds on a node that *does* carry the file — **not measured**. Arm B only
  proves the branch is taken; the stub is not a gateway, so it cannot prove `-> 200`.
- Whether the adapter's `basic_auth` check validates the secret's strength — already stated as
  unvalidated in `docs/OPERATIONS.md` §3; **not measured** by this tick either.

## 5. Found but not fixed (owned elsewhere)

- `CF-150` — the create-path code fix itself (stage the config, or add the operator step to the
  create path). This tick corrected only the spec/runbook side.
- `CF-153` — `scripts/node-create.sh` accepts no `--ref`, while `README.md:80-82` tells a reader to
  use one; the flag exists on `project-node.sh` only. README is the readme lane's surface.
- `CF-145` — the README's fresh-host promise for Quick start; README lane.
- `CF-154` — `docs/BOARD.md`'s census block quotes a warning count that is not a function of the
  tree; docs-side, but a count, and it needs a stable `boardctl` binary to be provable.
- `docs/audits/code-factory-docs-2026-11-04.md` was committed on 2026-11-03 21:46 carrying this
  tick's id in its header (`2c48149`) — an evidence file that names a tick before it fired. Not
  corrected here; it is the kind of claim this lane exists to catch and needs an owner.

ch:trace row=CF-150 spec=specs/NODE.md#layers run=code-factory-docs-2026-11-04-02-39-16 test=bash tests/selftest.sh doc=specs/NODE.md prompt=prompts/docs.md evidence=docs/audits/code-factory-docs-2026-11-04-layer20.md witness=docs/audits/code-factory-CF-150-DOC1.layer20.txt verdict=none:judged-after-commit

STATUS: PASS (documentation correction) · TIER: T3 — each corrected cell executed against the
shipped ladder · EVIDENCE: re-runnable commands + committed transcripts
