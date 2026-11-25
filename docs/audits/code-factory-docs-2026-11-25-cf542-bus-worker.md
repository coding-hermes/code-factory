# CF-542 — DESIGN.md §3 step 3 declared the node-side bus worker nonexistent while it ships

Tick: code-factory-docs-2026-11-25-15-22-20 (docs lane, THIRD execution of this tick id).
Date: 2026-11-25. Base: origin/main `4168411cf4f14f0c358719049ef9db10e009fb19` (registered
checkout, clean at measurement; ownership.py `state: clean`, exact-cwd census empty).

Execution trail: the FIRST execution landed CF-538 (OPERATIONS.md destroy prose) and filed
CF-539 + CF-540; the SECOND execution closed CF-539 (handbook unit 05 re-derivation) and filed
CF-541. Both are published (CF-538 at `9ccee1b8`, CF-539 close at `4168411c`). This execution
re-verified those rows at the published tip (CF-538 `complete`, commit_hash `9ccee1b8` an
ancestor of origin/main; CF-539 `complete` at the tip; CF-540/CF-541 still `pending`, untouched)
and took the next-largest false claim, which no open row owns.

## The claim that was false

`docs/DESIGN.md` §3 ("The path of one unit of work"), step 3 cell, at the base tip:

```
| 3 | The node's bus worker pulls the message (signed), verifies the brief digest, hands the
directive to the harness (Hermes gateway, or a foreign CLI). | **Not shipped.** No bus worker
exists. Layer 30 stats a file and starts nothing: `scripts/project-node.sh:245-249` tests
`-f $HOME/.node/crier.json` and its mode `600`, and `specs/NODE.md` § Layers ("A node-side bus
worker") states the layer opens no socket. Whether a worker runs on a node is **not measured**
by this repo; CF-068 owns the file-existence weakness. |
```

and the §3 summary sentence:

```
So two legs are demonstrated nowhere in this repository: a node-side bus worker (step 3) and a
control-host digest recomputation that decides a run (step 6).
```

Pre-fix counts at the base tip:

```
$ grep -c 'No bus worker exists' docs/DESIGN.md
1
$ grep -c 'two legs are demonstrated nowhere' docs/DESIGN.md
1
$ grep -c ':245-249' docs/DESIGN.md
1
$ grep -c ':244-249' specs/NODE.md
1
```

The contradicting tree at the same tip:

- `scripts/node-bus-worker.py` EXISTS — 2,294 lines (`wc -l`), the node side of the crier bus:
  signed inbox pull (per-agent ed25519, transcript per crier `internal/registry/agentsig.go`),
  `cf.brief-input.v1` digest verification, harness handoff, reply with `corr_id`, ack after
  delivery. Added by `e149d1a1` (2026-11-04, "feat(bus): the node consumes its own inbox").
- It is staged onto the node: `scripts/node-create.sh:80` (declared staged set), `:87`
  (required sidecar), `:428` (copy destination), `:435` (chmod +x).
- It is invoked: `scripts/bunker-crier-connect.sh:64` runs
  `python3 $HOME/node-bus-worker.py --check` on the node as the `signed_read` probe.
- It is demonstrated against fixtures: 45 tests collected at the base tip across
  `tests/test_bus_completion_guard.py`, `test_bus_result_delivery.py`,
  `test_bus_dispatch_encoding.py`, `test_bus_dispatch_idempotency.py`,
  `test_bus_envelope_identity.py`, `test_node_bus_staging.py`
  (`python3 -m pytest <those six> --collect-only -q` → `45 tests collected`).
- It runs: `python3 scripts/node-bus-worker.py --check` on this host prints named FAIL rows
  (identity / signing_key / bus_bearer / bus_health / inbox / harness absent) and exits 0 —
  the CLI executes; the failures are this host's missing node identity, not the script's.
- The cell's own evidence pointer was also dead: the crier.json test it cites at
  `scripts/project-node.sh:245-249` actually lives at `:791-793` (`sed -n '791,793p'` prints
  the `-f "$STATE/crier.json"` test, the `stat -c '%a'` mode-600 check and the
  `crier_identity` / `crier_mode` rows). `specs/NODE.md:70` cited the same drifted `:244-249`.

What stays TRUE (kept in the corrected text): layer 30 starts no process and opens no socket
(`specs/NODE.md` § Layers), no live node run of the worker is measured by this repo, and CF-068
(pending) owns the file-existence weakness.

Falsification timeline: the claim was falsified when the worker shipped (`e149d1a1`,
2026-11-04 — the same day as DESIGN.md's last edit, `6685c631`; the cell was never updated).
This week's bus-worker commits widened the contradiction: `e3794bfa` + `e88649e1` (CF-131,
2026-11-22, completion-guard strip + crier guard table), `dcc7c030` (CF-355, 2026-11-25,
verdict-law comments), `56f44fa5` (CF-361, 2026-11-22, contract pages touching the worker).

## What was corrected

| File:line (pre-fix) | Claim as written | Correction |
|---|---|---|
| docs/DESIGN.md:53 (step-3 cell) | "Not shipped. No bus worker exists." + dead cite `:245-249` | "Partly shipped." — names the shipped worker (2,294 lines at `4168411c`, added `e149d1a1`), its staging (`node-create.sh:80,:87,:428,:435`), its invocation (`bunker-crier-connect.sh:64`), its fixture demonstration (45 tests), and keeps the true halves: layer 30 starts nothing (cite re-pointed to `:791-793`), no live run measured, CF-068 owns the weakness |
| docs/DESIGN.md:59-62 (§3 summary) | "two legs are demonstrated nowhere … a node-side bus worker (step 3) and a control-host digest recomputation (step 6)" | one leg remains demonstrated nowhere (step 6); the step-3 worker is fixture-demonstrated, not live-bus-demonstrated |
| specs/NODE.md:70 | cite `scripts/project-node.sh:244-249` | cite re-pointed to `:791-793` (substance unchanged — the layer-30 claim is true) |

Sibling sweep for the retired literals: the only remaining occurrence of the retired sentence
in the corpus is `docs/handbook/_quorum-apollo-gap-20261105/seat-sol.txt:118`, a dated quorum
transcript (2026-11-05) quoting the then-current DESIGN.md — a frozen artifact, deliberately
not rewritten (same rule as CF-538's dated dogfood transcript).

## Post-fix verification (run in the registered checkout at the fix state)

```
$ grep -c 'No bus worker exists' docs/DESIGN.md
0
$ grep -c 'two legs are demonstrated nowhere' docs/DESIGN.md
0
$ grep -c ':245-249' docs/DESIGN.md
0
$ grep -c ':244-249' specs/NODE.md
0
$ grep -c ':791-793' specs/NODE.md
1
$ grep '^| 3 |' docs/DESIGN.md | grep -c 'Partly shipped'
1
$ sed -n '791,793p' scripts/project-node.sh
  if [ -f "$STATE/crier.json" ]; then
    ok "crier_identity" "$STATE/crier.json"
    m=$(stat -c '%a' "$STATE/crier.json"); [ "$m" = 600 ] && ok "crier_mode" "600" || bad "crier_mode" "$m (must be 600)"
$ sed -n '64p' scripts/bunker-crier-connect.sh
      'if [ -s "$HOME/.node/agent.key" ] && [ -s "$HOME/.node/auth/crier.token" ] && [ -f "$HOME/node-bus-worker.py" ]; then CRIER_URL='"$URL"' python3 "$HOME/node-bus-worker.py" --check 2>&1 | grep -E "PASS  inbox|FAIL  inbox" | head -1; fi' 2>/dev/null || true)
$ sed -n '80p;87p;428p;435p' scripts/node-create.sh
                     node_gateway_auth.py node_hygiene.py gomodcache.py deploy_key.py node-bus-worker.py
  local -a extra=(deploy_key.py harness/harness-vars.sh node-bus-worker.py)
    node-bus-worker.py) destination="$AGENT:node-bus-worker.py" ;;
"$b" exec --server "$SERVER" "$AGENT" -- bash -lc 'chmod +x ~/node-bus-worker.py ~/node-scripts/project-node.sh ~/node-scripts/install-go.sh ~/node-scripts/install-node.sh ~/node-scripts/harness/*.sh' \
$ grep -c '/home/kara' docs/DESIGN.md specs/NODE.md
docs/DESIGN.md:0
specs/NODE.md:0
$ wc -l scripts/node-bus-worker.py
2294 scripts/node-bus-worker.py
$ python3 -m pytest tests/test_bus_completion_guard.py tests/test_bus_result_delivery.py tests/test_bus_dispatch_encoding.py tests/test_bus_dispatch_idempotency.py tests/test_bus_envelope_identity.py tests/test_node_bus_staging.py --collect-only -q | tail -1
45 tests collected in 0.15s
```

The greps above are scoped to the shipped prose files; this audit keeps the retired sentences
quoted on purpose, so a recursive grep over `docs/` still finds them here and in the dated
quorum transcript, and nowhere else in shipped prose.

Gate: the diff is prose-only (docs/DESIGN.md, specs/NODE.md, this artifact). No test in the
tree asserts on the step-3 cell or the §3 summary (the only test reading specs/NODE.md,
`tests/test_node_credential_law.py:19`, asserts on the Credentials section, untouched).
`tests/selftest.sh` mentions specs/NODE.md only inside ch:trace comment lines. The commit-time
guard's Tier-1 verdict for the prose-only commit is quoted in the tick report (DEGRADED PASS
naming its skips is the expected shape; a host-condition suite red at the parent tip is
disclosed at CF-539's close and is not this row's surface).

## Found but not fixed (filed separately)

- OPERATIONS.md's verify-node.sh enumeration stops at step 6 (`docs/OPERATIONS.md:148` and the
  `:236` table row) while the script header lists 8 legs — leg 7 (harness manifest, CF-006,
  `0ec9634a`, 2026-11-07) and leg 8 (chat gateway, M13, CF-531, `a3e30926`, 2026-11-25) are
  missing from the prose. Filed as CF-543.

## Not measured

- A live node run of the bus worker: no node was authorized; the worker's `--check` was run on
  this control host only (named FAIL rows for the absent node identity, exit 0).
- The `signed_read` probe end to end: requires a live bunker agent + bus; fixture-covered only.

ch:trace row=CF-542 spec=docs/DESIGN.md#3-the-path-of-one-unit-of-work wave=none:serial-docs-lane test=none:no-arm-pins-design-md-step3 doc=docs/DESIGN.md evidence=docs/audits/code-factory-docs-2026-11-25-cf542-bus-worker.md witness=none:repo-local-docs-claim verdict=none:open-finding commit=none:open memory=/project/code-factory/docs-lane-2026-11-25-15-22-20-r3

STATUS: PASS
TIER: T3 — the corrected claim was measured by running the shipped worker's CLI, collecting
its test files, and resolving every cited line against the base-tip blob; the live-bus half is
named not-measured above.
EVIDENCE: docs/audits/code-factory-docs-2026-11-25-cf542-bus-worker.md (this file) +
docs/DESIGN.md and specs/NODE.md at the fix commit.
