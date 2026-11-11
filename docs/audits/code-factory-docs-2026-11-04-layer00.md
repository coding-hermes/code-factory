# code-factory docs tick — 2026-11-04T04:17:06-05:00 (layer 00)

Lane: `code-factory-docs`. Tick id: `code-factory-docs-2026-11-04-04-17-06`.
Baseline HEAD at selection: `fe1629e` (= `origin/main`, parity `0 0` after a disclosed
fast-forward from `c4fe94f`, which was one commit behind the published tip).

Filename note: `docs/audits/code-factory-docs-2026-11-04.md` (CF-079, layers 30/90),
`code-factory-docs-2026-11-04-CF-129.md` (board-drift flags) and
`code-factory-docs-2026-11-04-layer20.md` (layer 20) already exist in-tree from earlier ticks.
This file is a separate correction and does not overwrite or claim any of them.

## 1. The claim corrected

`specs/NODE.md`'s layer table row **00 preflight** claimed the ladder *establishes* "reachability to
crier / PyPI / Go proxy". The shipped preflight probes exactly two URLs and never a Go module proxy.
This is the last untouched cell of the class that `6f75e28` (layer 40), `2c48149` (layers 30, 90) and
`da4c5fd` (layer 20) narrowed; `git log -L 26,26:specs/NODE.md` shows the cell has not changed since
it was created in `d948c16`, and `docs/audits/code-factory-docs-2026-11-04.md:106` explicitly recorded
it as "not re-measured this tick" when the sibling cells were corrected. `docs/OPERATIONS.md:36`
already named only "crier and PyPI reachability", so the runbook and the spec disagreed and the spec
was the wrong side.

Row: CF-164 (`P3`), filed by this tick with the acceptance commands below.

| # | File:line | Claim (before) | Correction (after) |
|---|---|---|---|
| 1 | `specs/NODE.md:26` | "reachability to crier / PyPI / Go proxy" | "HTTP 200 from the only two endpoints this layer probes — `$CRIER_URL/health` and `https://pypi.org/simple/` (`scripts/project-node.sh:190`)"; with `CRIER_URL` unset the block is skipped and the layer prints `FAIL crier_url`; "Reachability to a Go module proxy is **not measured** by this or any shipped layer" |

Nothing else was touched: `git diff --numstat specs/NODE.md` → `1 1` (one line replaced).

## 2. The code path that proves the new statement

| Evidence | Path | What it shows |
|---|---|---|
| The probe loop | `scripts/project-node.sh:190` | `for u in "$CRIER/health" https://pypi.org/simple/; do` — two entries, and no third URL is appended anywhere in the loop (`:191-194`) |
| The guard around it | `scripts/project-node.sh:185-189` | `CRIER="${CRIER_URL:-}"`; unset → `bad "crier_url" "…"` and the loop never runs; set → `ok "crier_url"` then the loop |
| No proxy probe exists | `grep -rn 'proxy' scripts/` and `grep -rn 'GOPROXY\|GOPRIVATE' scripts/` | 0 hits each; also 0 hits under `tests/` — nothing in the shipped tooling measures a Go module proxy |
| The runbook already agreed | `docs/OPERATIONS.md:36` | "crier and PyPI reachability" — no Go proxy |

## 3. Literal command output (two arms, staged script)

Arm A — `env -u CRIER_URL HOME=<scratch> bash scripts/project-node.sh --check --layers 00 --project
probe --harness hermes`:

```
  PASS  disk_floor — 5 GiB from role-default
node provisioning — project=probe harness=hermes host=karaHermes-mde-7840hs
SCOPE: layers 00 (fixture mode — not a node certification)
[00] preflight
  PASS  arch — x86_64 (Linux 7.0.0-38-generic)
  PASS  role — worker (floor 5 GiB from role-default)
  PASS  disk — 407.8 GB free (floor 5 GB)
  PASS  mem — 41983 MB
  FAIL  crier_url — CRIER_URL unset — the node has nothing to connect to (export CRIER_URL=http://crier.example:8767)
  SKIP  layer 10 (out of scope)
  SKIP  layer 20 (out of scope)
  SKIP  layer 30 (out of scope)
  SKIP  layer 40 (out of scope)
  SKIP  layer 90 (fixture mode: no manifest)

NODE: FAIL (1)
ARM arm-a reach_rows=0
ARM arm-a proxy_rows=0
```

Arm B — same command with `CRIER_URL=http://127.0.0.1:9` (a closed port; the arm grades WHICH
endpoints are probed, not their reachability):

```
  PASS  disk_floor — 5 GiB from role-default
node provisioning — project=probe harness=hermes host=karaHermes-mde-7840hs
SCOPE: layers 00 (fixture mode — not a node certification)
[00] preflight
  PASS  arch — x86_64 (Linux 7.0.0-38-generic)
  PASS  role — worker (floor 5 GiB from role-default)
  PASS  disk — 407.8 GB free (floor 5 GB)
  PASS  mem — 41977 MB
  PASS  crier_url — http://127.0.0.1:9
  FAIL  reach:http://127.0.0.1:9/health — -> 000
  PASS  reach:https://pypi.org/simple/ — 200
  SKIP  layer 10 (out of scope)
  SKIP  layer 20 (out of scope)
  SKIP  layer 30 (out of scope)
  SKIP  layer 40 (out of scope)
  SKIP  layer 90 (fixture mode: no manifest)

NODE: FAIL (1)
ARM arm-b reach_rows=2
ARM arm-b proxy_rows=0
```

Two arms with opposite counts (`reach_rows=0` unset vs `reach_rows=2` set) is the proof that the
layer's reachability coverage IS those two endpoints and nothing else. The `-> 000` in arm B is the
shipped `curl … || echo 000` path on a closed port (CF-037 owns that double-zero rendering); it is
quoted as printed and not tidied.

Recovery if re-run: the staged script lives at
`~/.hermes/cache/scratch/cf-docs-20261104-0417/arms.sh` on this host only; the two commands
in the acceptance criteria reproduce it without that file.

## 4. Claims I could not verify

- **Whether a real crier `/health` returns 200 on a provisioned node: not measured.** Arm B used a
  closed loopback port deliberately; this tick proved the endpoint set, not that a live crier answers.
- **Go module proxy reachability on a node: not measured, and not claimed.** No shipped layer probes
  one; whether a node needs one for a Go repo's `go mod download` is a product question with no owner
  row, and this correction only stops the spec from asserting it.
- **Layer 40's cell** ("the repo cloned at a pinned ref") was read, not re-run this tick: the clone
  branch (`scripts/project-node.sh:257-283`) still accepts a pre-existing `$HOME/repo` with any HEAD
  and does not verify `REF` on that path. Not corrected here — `6f75e28` (CF-032) owns the cell and
  the residual is a clone-path question, not a documentation one.
- **docs/BOARD.md's quoted warning count** was not re-measured: it is instrument-bound (CF-154) and a
  sibling lane's row already owns it.

## 5. Acceptance commands (re-runnable at the published tip)

```
grep -n 'Go proxy' specs/NODE.md                                   # -> no output, exit 1
sed -n '26p' specs/NODE.md                                         # -> names $CRIER_URL/health, https://pypi.org/simple/, project-node.sh:190
CRIER_URL=http://127.0.0.1:9 HOME=$(mktemp -d) bash scripts/project-node.sh --check --layers 00 --project probe   # -> 2 reach: rows
env -u CRIER_URL HOME=$(mktemp -d) bash scripts/project-node.sh --check --layers 00 --project probe               # -> FAIL crier_url, 0 reach: rows
grep -rn 'GOPROXY\|GOPRIVATE' scripts/                             # -> no hits, exit 1
```

ch:trace row=CF-164 spec=specs/NODE.md#layers run=code-factory-docs-2026-11-04-04-17-06 test=bash scripts/project-node.sh::layers-00 doc=specs/NODE.md prompt=prompts/docs.md evidence=docs/audits/code-factory-docs-2026-11-04-layer00.md witness=cmd:two-arm-reach-rows verdict=none:judged-after-commit

STATUS: PASS (documentation correction) · TIER: T3 — both arms executed against the shipped ladder
· EVIDENCE: re-runnable commands + committed transcripts
