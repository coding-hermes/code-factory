# code-factory documentation correction evidence

Docs lane tick `code-factory-docs-2026-11-04-02-39-16`. Source window
`git log --since='2026-10-27' --oneline` (244 commits) read from a dedicated clone of
`origin/main` at `1384404`; every command below was re-run in that clone.

## Claim corrected

`specs/NODE.md` — the "Layers (each has a check that can fail)" table named two capabilities as
shipped layer behaviour that no shipped layer establishes:

| Cell | Before | After |
|---|---|---|
| 30 bus | `a crier identity file (600) and a pull worker` | `a crier identity file at $HOME/.node/crier.json and its mode 600` |
| 90 verify | `one round trip whose digest is recomputed on the control host` | `the node manifest ($HOME/.node/node.json), written only when every layer passed` |

The new paragraph under the table names the two unshipped capabilities explicitly and hands them to
the rows that own them: CF-004 (build the round trip) and CF-068 (layer 30's file-existence
weakness), with the node-side worker recorded as **not measured** by this ladder.

### Code path that proves the new statement

- **Layer 30 establishes an identity file and its mode, nothing else.**
  `scripts/project-node.sh:241-252`:

  ```sh
  if [ -f "$STATE/crier.json" ]; then
    ok "crier_identity" "$STATE/crier.json"
    m=$(stat -c '%a' "$STATE/crier.json"); [ "$m" = 600 ] && ok "crier_mode" "600" || bad "crier_mode" "$m (must be 600)"
  else
    bad "crier_identity" "absent — stage a bundle and re-run; a node without an identity is invisible"
  fi
  ```

  No process is started, no socket is opened and no worker is queried. `grep -c digest
  scripts/project-node.sh` prints `0`, so no layer recomputes an artifact digest anywhere.
  (`worker` appears four times in the script and every one is the `NODE_ROLE=worker` sizing role at
  lines 35, 43, 101 and 104 — not a bus worker.)

- **Layer 90 writes the node manifest and prints one row.**
  `scripts/project-node.sh:288-316`: `say "[90] manifest"`; in `--apply` mode it writes
  `$HOME/.node/node.json` with the inline Python block, otherwise it prints `ok`/`note manifest is
  written only when every layer passes`. It contacts no control host and recomputes no digest.

- **The repository already said so elsewhere**, which is why the table was the defect:
  `docs/OPERATIONS.md:115` ("Current state: BLOCKED / NOT YET"), `docs/OPERATIONS.md:121` ("no
  checked-in command dispatches a production job"), `docs/THREAT-MODEL.md:30` ("their implementation
  is not in this repository"). `AGENTS.md` rule 1 makes a script/spec disagreement a bug in one of
  them; the shipped script is the measured side.

- **Same class, already fixed once, left incomplete.** Commit `6f75e28` ("docs: narrow node layer 40
  to clone — align claims with shipped behavior. Addresses CF-032.") narrowed layer 40's cell and
  left 30 and 90 claiming their unshipped capabilities. This correction finishes that class.

## Verification (re-runnable, literal output)

Run from the repository root of the corrected tree.

1. The claimed string is gone — `grep -n 'pull worker' specs/NODE.md` prints nothing (rc=1,
   0 matching lines).

2. Layer 30, arm A (no identity staged), fresh `HOME`:
   `HOME=$H ./scripts/project-node.sh --check --project p --layers 30` →

   ```
   [30] bus
     FAIL  crier_identity — absent — stage a bundle and re-run; a node without an identity is invisible
   NODE: FAIL (1)
   ```

   arm B (identity staged, mode 600) → `PASS  crier_identity` + `PASS  crier_mode — 600`,
   `NODE: PASS`, rc 0; arm C (same file, mode 644) → `PASS  crier_identity` +
   `FAIL  crier_mode — 644 (must be 600)`, `NODE: FAIL (1)`, rc 1. Three arms cover presence, the
   documented mode and the failure path; **no worker row is printed in any of them.**

3. Layer 90, fresh `HOME`: `HOME=$H ./scripts/project-node.sh --check --project p` prints

   ```
   [90] manifest
     ..    manifest is written only when every layer passes
   NODE: FAIL (4)
   ```

   and no digest row. (The `NODE: FAIL (4)` comes from layers 00/10/20 on this bare host — the
   fixture scope `--layers` accepts `00,10,20,30,40` only, so 90 always runs; that is the documented
   fixture behaviour, not a correction finding.)

4. Gate: `bash tests/selftest.sh` → `SELFTEST: PASS` (29 numbered sections plus arms 4b and 7b),
   rc 0.

5. Board: `bash scripts/boardctl validate` → `RESULT: OK (54 warning(s))`, rc 0 at the landing tip
   `e657d98` (53 warnings at `1384404`, before CF-150's row added one more free-form `probe` key).
   Every warning is a pre-existing free-form key or the headerless board, none introduced by this
   diff.

6. Diff is documentation-only: `git diff --stat` → `specs/NODE.md | 20 ++++++++++++++++++--`
   (18 insertions, 2 deletions) plus this evidence file.

## Claims I could not verify — stated as not measured

- **Whether a bus worker is actually running on any node: not measured.** The ladder opens no
  socket and starts no process, and this lane had no node access this tick. The corrected spec says
  so instead of implying coverage.
- **The control-host digest round trip: not measured, and not buildable from this repo.** No shipped
  command performs it; CF-004 owns it and `docs/OPERATIONS.md` §6 keeps it NOT YET.
- **Layer 00's "reachability to crier / PyPI / Go proxy" cell was not re-measured** this tick. It is
  a live-network claim and CF-124 tracks the gate's dependence on a live `pypi.org` probe; I did not
  widen this correction to it.
- **Layer 40's clone claim** was verified only by reading `6f75e28` and the current cell; I did not
  re-run a `--apply` clone against a public fixture this tick.

ch:trace row=CF-079 spec=specs/NODE.md#layers wave=code-factory-docs-2026-11-04-02-39-16#docs test=tests/selftest.sh::selftest doc=specs/NODE.md prompt=prompts/docs.md evidence=docs/audits/code-factory-docs-2026-11-04.md witness=cmd:grep-0/layer30-3-arms/layer90-manifest-row verdict=none:judged-after-commit commit=none:self-referential-hash memory=none:recorded-separately

STATUS: PASS
TIER: T3 — every corrected cell was executed against the shipped ladder and captured verbatim
EVIDENCE: scripts/project-node.sh:241-252, :288-316; docs/audits/code-factory-docs-2026-11-04.md
