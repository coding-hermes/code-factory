# CF-548 — MVP-PLAN.md conformance-battery claim corrected (six leg families, vars/memory wired)

Tick: code-factory-docs-2026-11-26-13-21-10. Base tip: `be3bc6f4f9e2b2895c1525a889185859b4644c2d` (origin/main at measurement).
Lane: code-factory docs. This artifact is the evidence for board row CF-548; it carries no trace
markers of its own (the marker-form line count in this file is 0 by design).

## The claim as it was written (pre-fix)

`docs/MVP-PLAN.md:123-124` at `be3bc6f4`:

```
**Support is measured, not claimed.** `tests/harness-conformance.sh` runs three legs per harness today
(`check`, `apply`, `smoke`); the `vars` and `memory` legs are the targets in CF-229/CF-231 and are not yet wired into it and writes `docs/HARNESS-CONFORMANCE.md`; a harness
```

Pre-fix grep freeze (run at `be3bc6f4`):

```bash
grep -n 'runs three legs' docs/MVP-PLAN.md    # -> 123 (one hit)
grep -n 'not yet wired' docs/MVP-PLAN.md      # -> 124 (one hit)
```

## Why it is false

`tests/harness-conformance.sh:54` ships six leg families, and both legs the sentence calls
unwired are implemented and run:

```bash
sed -n '54p' tests/harness-conformance.sh
# LEG_FAMILIES=(check apply vars node smoke memory)

bash tests/harness-conformance.sh --list-legs   # rc=0, prints:
# check
# apply
# vars
# node
# smoke
# memory
```

The vars leg lives at `tests/harness-conformance.sh:320-395` (CF-229, closed 2026-11-06), the
memory leg at `:396-437` (CF-231, closed 2026-11-21; exporter commit `c0e0fabe`). The falsifying
commits inside the last week are `59d905ec` and `111be1b6` (both 2026-11-22, CF-322: "name the
five legs the battery emits and prove the vars/memory red paths", "single-source harness leg
families and gate drift"). `specs/HARNESS-MATRIX.md` I4 (`:55-57`) and §7 (`:200`) already
document six leg families with `apply` conditional on `--install` and `node` dispatched only for
`codex`; the generated `docs/HARNESS-CONFORMANCE.md` carries the vars-leg table with PASS rows
for all seven harnesses. MVP-PLAN.md contradicted the repo's own spec and generated matrix.

## The corrected sentence (post-fix)

`docs/MVP-PLAN.md:123-129` now reads (working tree at `be3bc6f4` plus this change):

```
**Support is measured, not claimed.** `tests/harness-conformance.sh` runs six leg families today
(`check`, `apply`, `vars`, `node`, `smoke`, `memory` — `tests/harness-conformance.sh:54`; `apply`
runs only under `--install`, `node` only for `codex`), and `--write-doc` regenerates
`docs/HARNESS-CONFORMANCE.md` from the run. The `vars` leg (CF-229) and the `memory` leg (CF-231)
are wired into it: `--vars-only` and `--memory-only` run them hermetically. A harness
counts as supported when all five per-harness families are `PASS` on a real node, or `SKIP` with the missing credential
named (`specs/HARNESS-MATRIX.md` I4).
```

## Post-fix verification (every command re-runnable)

```bash
grep -c 'runs three legs' docs/MVP-PLAN.md     # -> 0
grep -c 'not yet wired' docs/MVP-PLAN.md       # -> 0
grep -n 'Support is measured' docs/MVP-PLAN.md # -> 123
sed -n '54p' tests/harness-conformance.sh      # -> LEG_FAMILIES=(check apply vars node smoke memory)
bash tests/harness-conformance.sh --list-legs  # -> six lines, rc=0
grep -c 'all five' docs/MVP-PLAN.md            # -> 1
grep -rn 'not yet wired' docs/*.md specs/*.md README.md   # -> no hits, rc=1
```

## The two legs run hermetically (T3)

`--vars-only`, four consecutive runs at one tip (working tree `be3bc6f4` + this change):

| run | summary line | battery rc |
|---|---|---|
| 1 | `summary: 10 pass, 1 fail, 0 skip` / `HARNESS CONFORMANCE: FAIL (1)` | (piped, masked) |
| 2 | `summary: 11 pass, 0 fail, 0 skip` / `HARNESS CONFORMANCE: PASS` | 0 |
| 3 | `summary: 11 pass, 0 fail, 0 skip` / `HARNESS CONFORMANCE: PASS` | 0 |
| 4 | `summary: 10 pass, 1 fail, 0 skip` / `HARNESS CONFORMANCE: FAIL (1)` | 1 |

Both reds are the same row: `FAIL  goose:vars — accepted but never recorded: CF_MAX_TURNS
CF_TIMEOUT_S`. The flake is filed as CF-550; it does not bear on this row's claim (the legs exist
and run), and it is disclosed here rather than quietly dropped.

`--memory-only`, one run at the same tip:

```
summary: 61 pass, 0 fail, 10 skip
HARNESS CONFORMANCE: PASS   (battery rc=0)
```

The 10 skips are the live-DuckBrain rows, each printed as `SKIP  <harness>:memory — no live
DuckBrain node/readback was available; fixture is not live support evidence` — the battery's own
honest-skip shape.

Substitution table (publish gate): the battery's `work:` line names a scratch dir under the
operator home; it is elided here as `~/.harness-conformance/run-…`. No other path in the quoted
output names a host, user or credential.

## Not measured

- The `apply` leg (runs only under `--install`; this tick installs nothing).
- The `node` leg (dispatched only for `codex`; not selected).
- Live-node support (I4 requires a real node for a real turn; the hermetic runs above are not
  that, and the battery's own SKIP rows say so).
