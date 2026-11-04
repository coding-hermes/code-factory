# code-factory docs tick — 2026-11-04 (create-path environment contract)

Lane: `code-factory-docs`. Tick id: `code-factory-docs-2026-11-04-06-11-13`.
Baseline HEAD at selection: `1aeb0c7` (= `origin/main`, parity `0 0`). The correction was
re-applied and gated on the tip that was current when it was committed (`4169907`).

Filename note: `docs/audits/code-factory-docs-2026-11-04.md`, `-CF-129.md`, `-layer20.md` and
`-layer00.md` already exist in-tree from earlier ticks. This file covers a different claim and
does not overwrite or claim any of them.

Transport note: the family barrier was live for the whole tick — siblings of this repo
(`code-factory-pm`, `code-factory-duckbrain`, `code-factory-duckbrain-releng`,
`code-factory-duckbrain-sync`) read `status=running` on the same workdir, and one of them held an
uncommitted tracked edit in `docs/ACCEPTANCE-PLAN.md` when the work started. The read, the arms,
the gate and the correction were therefore produced in a fresh `git clone` of `origin/main` in the
tick scratch; the registered checkout was not written by this tick (a `git archive` copy is not a
valid transport here: without history the suite fails one arm, `FAIL pre-fix source unavailable`).

## 1. The claim corrected

`docs/OPERATIONS.md` states the control-host environment contract for node creation as
"requires `BUNKER_SERVER` in the environment" and never names `CRIER_URL`. Since `23c1c6d`
(2026-11-03, CF-126) `scripts/node-create.sh` refuses before any bunker call when `CRIER_URL` is
unset or empty, and that gate runs **before** the `BUNKER_SERVER` gate. The runbook as written
therefore documents an invocation that exits 1 with a value the runbook never mentions, and the
two acceptance recipes built on that contract (`CF-101`, `CF-110`) abort before the step they
certify.

The sentence had never been touched since it was written (`git log -L 47,47:docs/OPERATIONS.md`
→ one commit, `5356ba9`), so it predates both `5cf6c03` and `23c1c6d`.

| # | File:line | Claim (before) | Correction (after) |
|---|---|---|---|
| 1 | `docs/OPERATIONS.md:24` | "Set `BUNKER_SERVER` …" — the control-host prerequisites name one variable | Node creation additionally requires `CRIER_URL`, the bus URL the node probes at layer 00; `node-create.sh` refuses before any bunker call when it is unset (`scripts/node-create.sh:69-72`) |
| 2 | `docs/OPERATIONS.md:47` | "requires `BUNKER_SERVER` in the environment" | "requires both `BUNKER_SERVER` and `CRIER_URL`"; documents the gate order (`crier_url` first, then `server_declared`, `:69-79`), the forwarded value (`:112`) and that any other node-side consumer of it is **not measured** |
| 3 | `docs/OPERATIONS.md:195` | Table row: control-host orchestrator, no environment named | Table row names `BUNKER_SERVER` **and** `CRIER_URL`, "refuses on either before any bunker call" |
| 4 | `docs/ACCEPTANCE-PLAN.md:73` (CF-101) | Recipe sets only `BUNKER_SERVER=` | Recipe carries `CRIER_URL=http://crier.example:8767` (placeholders only, no private endpoint) |
| 5 | `docs/ACCEPTANCE-PLAN.md:82` (CF-110) | Recipe sets no environment | Recipe carries `CRIER_URL=http://crier.example:8767` |

Nothing else was touched: `git diff --numstat` → `docs/OPERATIONS.md 3 3`,
`docs/ACCEPTANCE-PLAN.md 2 2` (five single-line replacements, no other line moved).

Sibling-class check (docs-lane rule 1): `CF-009` and `CF-015` closed the README half of this class
(an undocumented `BUNKER_SERVER`). The runbook half was left behind, and `23c1c6d` added a second
required value to it. `README.md:19-20` and `:92-93` export both variables and remain correct; no
README change is needed.

## 2. The code path that proves the new statement

| Evidence | Path | What it shows |
|---|---|---|
| The `CRIER_URL` gate | `scripts/node-create.sh:69-72` | `if [ -z "${CRIER_URL:-}" ]; then bad "crier_url" "CRIER_URL unset or empty — export CRIER_URL=http://crier.example:8767"; exit 1; fi` — runs after `--staged-files` handling and **before** the staged set and every bunker call |
| Quote-escaping | `scripts/node-create.sh:74` | `CRIER_QUOTED="${CRIER_URL//\'/\'\\\'\'}"` |
| The `BUNKER_SERVER` gate | `scripts/node-create.sh:76-79` | `if [ -z "$SERVER" ]; then bad "server_declared" "BUNKER_SERVER unset — no agent host to create the node on"; incomplete; fi` — second, proved by ARM 2 |
| The handoff | `scripts/node-create.sh:112` | `NODE_PROJECT='…' NODE_GATEWAY_PORT='…' CRIER_URL='$CRIER_QUOTED' ~/node-scripts/project-node.sh --apply …` — the value reaches the node |
| What the node does with it | `scripts/project-node.sh:185-195` | layer 00 sets `CRIER="${CRIER_URL:-}"`, prints `ok "crier_url" "$CRIER"` or `bad "crier_url" …`, and probes `"$CRIER/health"` plus `https://pypi.org/simple/` — two URLs; nothing else reads the value |

## 3. Literal command output (three arms, staged script)

Script: `<scratch>/cf126-env-arms.sh` (`bash -n` clean, run from the repo root at `1aeb0c7`).

```
=== ARM 1 — documented invocation from docs/OPERATIONS.md:47, only BUNKER_SERVER set ===
  FAIL  crier_url — CRIER_URL unset or empty — export CRIER_URL=http://crier.example:8767
ARM1_RC=1

=== ARM 2 — CRIER_URL set, BUNKER_SERVER unset ===
  FAIL  server_declared — BUNKER_SERVER unset — no agent host to create the node on
NODE INCOMPLETE (1)
ARM2_RC=1

=== ARM 3 (control) — both env vars set, PATH-local bunker stub ===
node-create — project=myrepo harness=hermes server=your-bunker-server
  ..    spawning node-myrepo-011358 (ttl 6h)
  FAIL  spawn — bunker-stub spawn node-myrepo-011358 --server your-bunker-server --ttl 6h
ARM3_RC=1
```

ARM 1 is the correction's red arm: the runbook's documented contract exits 1 with no spawn.
ARM 2 proves the runbook's `BUNKER_SERVER` sentence is true but *second*. ARM 3 proves both gates
are the only early refusals — with both set the script reaches `spawning`, so the corrected
sentence names exactly the two values the create path requires.

## 4. Gate at the corrected tree

| Gate | Command | Result |
|---|---|---|
| Selftest | `bash tests/selftest.sh` | `SELFTEST: PASS`, rc 0 — and rc 0 at the pre-edit baseline of the same clone, so the docs edit moved nothing |
| Board | `bash scripts/boardctl validate` | `RESULT: OK (3 warning(s))` — the three pre-existing warnings |

## 5. Claims I could not verify

- Whether anything on the node other than layer 00's health probe consumes `CRIER_URL` is
  **not measured** — no bus worker ships (`specs/NODE.md` § Layers), and the corrected prose says so.
- Whether the forwarding survives every operator-supplied URL is **not measured** beyond the
  selftest's quote/metacharacter arm; this tick ran a plain `http://crier.example:8767` only.
- Whether `NODE CREATED` can be reached on a real node remains unproven for the reasons the runbook
  already lists (CF-080, CF-150). This tick corrects the environment contract, not the lifecycle.

## 6. Found while selecting — already filed by a sibling

`specs/NODE.md:26` cites `CF-164`, which no board row carried at `1aeb0c7`, and
`docs/audits/code-factory-docs-2026-11-04-layer00.md` states "Row: CF-164 (P3), filed by this
tick". A sibling PM tick filed exactly that row in `4e3c33a` while this tick was reading, so this
tick files nothing for it and records the dedupe instead: CF-164 (pending, P3) owns the
trace-forward gap, and its AC3 is the check that would have caught the phantom id.

## 7. Row id renumbered during publication

This tick minted its row as `CF-165` against the tip it read. A sibling landed its own `CF-165`
(boardctl event `task_id` serialization) on `origin/main` while this commit was being published,
so the id collides: both rows are kept, and this tick's row was renumbered to `CF-166` together
with its `task_created` event (contributor event renumbered past the sibling's, 238 → 239). No
other lane's line was rewritten.

ch:trace row=CF-166 spec=specs/NODE.md test=tests/selftest.sh evidence="bash tests/selftest.sh; bash scripts/boardctl validate; env -u CRIER_URL BUNKER_SERVER=x bash scripts/node-create.sh --project p --repo https://github.com/github/gitignore --harness hermes" verdict=pending

STATUS: complete
TIER: T3
EVIDENCE: docs/audits/code-factory-docs-2026-11-04-create-env.md (this file) + the three-arm transcript in §3 + `bash tests/selftest.sh` rc 0 at the corrected tree
