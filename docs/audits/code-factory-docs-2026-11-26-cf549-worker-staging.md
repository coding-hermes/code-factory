# CF-549 — OPERATIONS.md bus-worker staging claim corrected (staged since 66b26147 / CF-276)

Tick: code-factory-docs-2026-11-26-13-21-10. Base tip: `be3bc6f4f9e2b2895c1525a889185859b4644c2d` (origin/main at measurement).
Lane: code-factory docs. This artifact is the evidence for board row CF-549; it carries no trace
markers of its own (the marker-form line count in this file is 0 by design).

## The claim as it was written (pre-fix)

`docs/OPERATIONS.md:136` at `be3bc6f4` (one sentence inside the §6 current-state paragraph):

```
... what is not yet done is staging the worker into a new node (CF-276), not writing it; no Crier registration/target-enablement command is documented here.
```

Pre-fix grep freeze (run at `be3bc6f4`):

```bash
grep -n 'not yet done is staging the worker' docs/OPERATIONS.md   # -> 136 (one hit)
```

## Why it is false

CF-276 closed 2026-11-17; the fix commit `66b26147` (2026-11-10, "fix(node): stage bus worker at
its probe path (CF-276)") put `node-bus-worker.py` into the derived staged set. At `be3bc6f4`:

```bash
sed -n '80p;87p;428p;435p' scripts/node-create.sh
# :80  node_gateway_auth.py node_hygiene.py gomodcache.py deploy_key.py node-bus-worker.py
# :87  local -a extra=(deploy_key.py harness/harness-vars.sh node-bus-worker.py)
# :428 node-bus-worker.py) destination="$AGENT:node-bus-worker.py" ;;
# :435 "$b" exec --server "$SERVER" "$AGENT" -- bash -lc 'chmod +x ~/node-bus-worker.py ...'

bash scripts/node-create.sh --staged-files   # rc=0; line 11 of the manifest is node-bus-worker.py
```

The same file already agreed at `:244` ("it is staged by provisioning"), so `:136` was an internal
contradiction as well as a false claim. The falsifying commit (`66b26147`, 2026-11-10) sits just
outside the strict seven-day window; this correction was found during the CF-548 sweep and is the
same defect class (shipped prose declaring done work undone), so it is corrected in the same tick
and disclosed as the secondary finding.

## The corrected sentence (post-fix)

`docs/OPERATIONS.md:136` now reads (working tree at `be3bc6f4` plus this change):

```
... the worker is staged into a new node by `scripts/node-create.sh` (CF-276) — `node-bus-worker.py` is in the derived staged set (`scripts/node-create.sh:80,87`), copied to `$HOME/node-bus-worker.py` (`scripts/node-create.sh:428`) and chmodded executable (`scripts/node-create.sh:435`), and `bash scripts/node-create.sh --staged-files` prints it in the manifest; no Crier registration/target-enablement command is documented here.
```

## Post-fix verification (every command re-runnable)

```bash
grep -c 'not yet done is staging the worker' docs/OPERATIONS.md   # -> 0
grep -n 'Current state: BLOCKED / NOT YET' docs/OPERATIONS.md     # -> 136 (paragraph carries the new sentence)
sed -n '80p;87p;428p' scripts/node-create.sh                      # -> each line names node-bus-worker.py
bash scripts/node-create.sh --staged-files | grep -n 'node-bus-worker'   # -> 11:node-bus-worker.py, rc=0
grep -c 'no Crier registration/target-enablement command' docs/OPERATIONS.md   # -> 1 (remaining NOT-YET scope intact)
```

The paragraph's wider verdict is unchanged and still true: the crier identity bundle is not staged
by `node-create.sh` (no identity reference exists in that script), scheduler→crier dispatch stays
disarmed, and no Crier registration/target-enablement command is documented. Only the staging
sub-claim was false.

## Not measured

- A live node create (`node-create.sh` against a real bunker agent): the staged-files manifest is
  the repo's own hermetic probe; no agent was spawned for this correction.
- Whether the staged worker passes `--check` on a fresh node (that is CF-365's deployed-bus probe,
  in progress on another lane).
