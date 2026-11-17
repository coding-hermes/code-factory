# PERF-021 — attributing the three "cold-cache-only" gate rows

**Verdict: the three rows do not reproduce, and two of the three are not independent rows at all —
they are the parsed-out body of the first row's own message. The empty toolchain cache is excluded
as a mechanism for the cf183 row (the fixture is `env -i`-isolated and never reads the cache), and
it is excluded as a mechanism for the other two because they exist only when that first row trips.**
Nothing below fixes a test: the defects found are reported, not repaired.

- Audited tip at session start: `0014b76ac0b5a33081068d743e52754b928b4e0c` (clean tree).
- Tip the cold/warm pair was measured on: `f2127dd94d706d6a70d3431ee6d63194f94ac388` — a **sibling
  dogfood lane committed into this checkout mid-session** (`.coding-hermes/` board, evidence and
  `docs/` only; `git diff --stat 0014b76a..f2127dd9 -- tests scripts` is empty, so the code under
  test is identical). Disclosed because the brief said this checkout had one worker; it did not.
- All logs live outside the repo, in `~/.hermes/cache/scratch/cf-perf021-w/`. Host-home paths are
  written as `~` throughout: the CF-050 publish gate (`tests/selftest.sh:7046-7085`) refuses a staged
  file containing an absolute `/home/<user>/` path, and it refused this audit's first commit for
  exactly that (§6.2).

---

## 1. Both arms, both takes

A "verdict row" below is exactly what the suite prints and what a row-based diff can see:

```bash
grep -cE '^  PASS  ' <log>; grep -cE '^  FAIL  ' <log>
```

| arm | HEAD | toolchain cache | wall | PASS | FAIL | rows | SELFTEST line |
|---|---|---|---|---|---|---|---|
| `warm-1` | `0014b76a` | default `$TMPDIR/cf-toolchain-cache` (230 M, warm) | 168 s | 588 | 62 | 650 | `SELFTEST: FAIL (1)` exit 1 |
| `cold-1` | `0014b76a` | fresh **empty** → still **12 K** at end | 158 s | 588 | 62 | 650 | `SELFTEST: FAIL (1)` exit 1 |
| `warm2`| `0014b76a` | default (warm) | 201 s | 588 | 62 | 650 | `SELFTEST: FAIL (1)` exit 1 |
| `cold2`| `f2127dd9` | fresh **empty** → **230 M** at end | 265 s | 588 | 62 | 650 | `SELFTEST: FAIL (1)` exit 1 |
| `warm3`| `f2127dd9` | default (warm, 230 M) | 231 s | 588 | 62 | 650 | `SELFTEST: FAIL (1)` exit 1 |

Load windows (`uptime` recorded in `<arm>.pre.txt` / `<arm>.post.txt`): `warm-1` 10.65→…, `cold-1`
7.47→…, `warm2` 13.42→…, `cold2` 46.41→38.73, `warm3` 33.48→38.11. The matched pair is
**`warm3` vs `cold2`** (same HEAD, same clean tree, adjacent windows): **+34 s (+14.7 %) for the
empty cache, and zero row differences**.

**Measurement defect found in take 1 and fixed by re-running (this is why there are two takes).** A
cron-spawned shell's `PATH` does not begin with `~/.local/share/vite-plus/bin`, the shim
that provisions the JS toolchain into `XDG_DATA_HOME`. Recorded verbatim in `env-probe.txt`:

```
PATH=~/.hermes/hermes-agent/.hermes/bin:~/.hermes/installs/…/venv/bin:…:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

With that `PATH`, `tests/selftest.sh` never writes to `CF_TOOLCHAIN_CACHE` at all — the cold root
stayed at 12 K, i.e. take 1 measured "an empty directory nothing reads". Take 2/3 prepend the shim
(`warm2.pre.txt`/`cold2.pre.txt` record the full `PATH`) and the cold root grows 12 K → **230 M**
inside the node/E2E section, which is the provisioning the cache exists to avoid. Only the take-2/3
pair is evidence about a cold cache; take 1 is kept in this record because it shows the trap.

### Row-set diff (normalised)

Normaliser (re-runnable; the copy used during the run is
`~/.hermes/cache/scratch/cf-perf021-w/norm.sh`):

```bash
#!/usr/bin/env bash
set -uo pipefail
sed -E \
  -e 's#/mnt/ssd/tmp/tmp\.[A-Za-z0-9]+#<TMPD>#g' \
  -e 's#/tmp/tmp\.[A-Za-z0-9]+#<TMPD>#g' \
  -e "s#$HOME/\.hermes/cache/scratch/[A-Za-z0-9._-]+#<SCRATCH>#g" \
  -e 's#/[A-Za-z0-9._-]*-[0-9]{6}-[A-Za-z0-9]{6}\.log#/<UNIQ>.log#g' \
  -e 's#holder=pid-[0-9]+#holder=<PID>#g' \
  -e 's#mtime [0-9]+ -> [0-9]+#mtime <N> -> <N>#g' \
  -e 's#\b[0-9a-f]{12,40}\b#<SHA>#g' \
  -e 's#[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}Z?#<TS>#g' \
  -e 's#\b[0-9]+(\.[0-9]+)?[[:space:]]?s\b#<DUR>#g' \
  -e 's#\bpid [0-9]+#pid <PID>#g' \
  "$1" \
  | grep -E '^  (PASS|FAIL)  ' \
  | sed -E 's/^  (PASS|FAIL)  /\1\t/' \
  | sort | uniq -c | sed -E 's/^ +//' | sort -k2,2
```

(Stable 7–8 char revisions the suite names, e.g. `deafbc3`, survive; per-run fixture commit ids,
throwaway paths, pids, mtimes, timestamps and durations do not.)

```
$ diff warm3.norm cold2.norm
(no output)      # 607 distinct normalised rows each
$ diff warm.norm  cold.norm
(no output)      # take-1 pair, 607 each
```

**Rows present in only one arm: none, in either pair.** The three rows the brief lists as
cold-only did not appear in any of the five arms I ran:

```
$ grep -cE '^  FAIL  cf183'                  <every arm>   -> 0
$ grep -cE '^  FAIL  inference_key'          <every arm>   -> 0
$ grep -c  ':10800'                          <every arm>   -> 4
```

Verbatim, the cf183 rows in a full arm (all 18 PASS in all five arms):

```
31b. Hermes certifies the pinned venv binary, not a host-provided command (CF-183)
  PASS  cf183 host-mismatch --check: ownership and measured version vs pin
  PASS  cf183 host-mismatch --apply: pinned venv installed or matching venv retained
  PASS  cf183 host-mismatch installed --check: owned pin passes, missing port/key still fail
  …
  PASS  cf183 venv-mismatch installed --check: owned pin passes, missing port/key still fail
```

My arms' row totals (650 = 588 + 62) do **not** equal the PERF-018 baseline (644 = 583 + 61); see
§5.6 — that delta is not reconciled and is not attributable to the cache (it is identical in both
of my arms, warm and cold).

---

## 2. Row 2 and row 3 are the parsed-out body of row 1

`tests/selftest.sh:2301` does not emit a one-line verdict when a cf183 arm trips — it emits the
**whole multi-line adapter output** as one `say`:

```bash
say "  FAIL  cf183 $arm installed --check (exit $rc): $out"; fails=$((fails+1))
```

`$out` is `scripts/harness/install-hermes.sh --check`, whose own rows include (file:line in the
adapter):

- `scripts/harness/install-hermes.sh:270` — `say "harness: hermes (pin $PIN, port $PORT)"`
- `scripts/harness/install-hermes.sh:328` — `bad "port" "nothing on :$PORT"` → `FAIL  port — nothing on :10800`
- `scripts/harness/install-hermes.sh:336` — `bad "inference_key" "no provider key — a turn dies at 'No inference provider configured'"`

So a row-based reader sees the adapter's rows as suite rows, and the suite's verdict counts them.

### Mechanism demonstration (scratch copy — the repo was not edited)

A copy of the cf183 block (`tests/selftest.sh:2215-2306`, extracted verbatim) with exactly one
expectation changed, `HERMES: FAIL (2)` → `HERMES: FAIL (99)`, to make all six arms trip:

```
$ diff cf183-arm.sh cf183-arm-tripped.sh
90c90
<     && printf '%s\n' "$out" | grep -Fxq 'HERMES: FAIL (2)'; then
---
>     && printf '%s\n' "$out" | grep -Fxq 'HERMES: FAIL (99)'; then
```

Rows the tripped copy adds, per arm (normalised, `comm -13 clean tripped`):

```
FAIL  cf183 venv-mismatch installed --check (exit 1): harness: hermes (pin 0.19.0, port 10800)
FAIL  port — nothing on :10800
FAIL  inference_key — no provider key — a turn dies at 'No inference provider configured'
PASS  binary — <TMPD>/venv-mismatch/hermes-venv/bin/hermes
PASS  version — 0.19.0 (pin 0.19.0)
PASS  python — 3.12.3 (hermes-agent 0.19.0 requires >=3.11,<3.14)
```

Raw, the injected body appears as separate lines in the suite's stream:

```
  FAIL  cf183 host-mismatch installed --check (exit 1): harness: hermes (pin 0.19.0, port 10800)
  ..    contract:CF_API_KEY_FILE — unset …
  PASS  python — 3.12.3 (hermes-agent 0.19.0 requires >=3.11,<3.14)
  PASS  binary — /mnt/ssd/tmp/tmp.1EeEobdaB2/host-mismatch/hermes-venv/bin/hermes
  PASS  version — 0.19.0 (pin 0.19.0)
  FAIL  port — nothing on :10800
  FAIL  inference_key — no provider key — a turn dies at 'No inference provider configured'
```

This is what the brief's three rows are:

1. **`cf183 … installed --check (exit 1): harness: hermes (pin 0.19.0, port 10800)`** — the message
   of the tripped assertion, whose first embedded line is the adapter's `harness:` header. That is
   why the quoted row stops exactly there: the rest of the message is on following lines.
2. **`inference_key — no provider key …`** — line 336 of the adapter, injected by row 1.
3. **one extra `:10800` row** — the injected `FAIL port — nothing on :10800` (line 328). My arms
   print four `:10800` lines; the injected `FAIL port` row is the fifth, which is exactly "5 vs 4".
   (The `harness: hermes (pin 0.19.0, port 10800)` text is *not* a separate row; it is the tail of
   row 1's own message — so it does not add to a row count.)

The mechanism is not specific to cf183: **32** `say "  FAIL … $out"` sites in `tests/selftest.sh`
embed a sub-process's multi-line output in one row (`grep -cE 'say "  FAIL[^"]*\$out' tests/selftest.sh`
→ `32`), so any one of them tripping inflates the row stream by however many rows the child printed.

---

## 3. Controlled re-runs of the cf183 block — warm vs cold

Only the block (not the suite), extracted verbatim to `cf183-arm.sh`, run twice warm and four times
cold, each cold run with its own never-reused empty cache root:

```bash
CF_TOOLCHAIN_CACHE=<fresh dir> bash cf183-arm.sh   # cold
bash cf183-arm.sh                                  # warm, no CF_TOOLCHAIN_CACHE exported
```

| run | cache root | rc | FAIL rows | output |
|---|---|---|---|---|
| `cf183-warm-1.log` | default | 0 | 0 | baseline |
| `cf183-warm-2.log` | default | 0 | 0 | identical to baseline |
| `cf183-cold-1.log` … `-4.log` | 4 × fresh empty | 0 | 0 | **identical to baseline** (`diff warm-1 cold-1` → no output) |

18 / 18 cf183 rows PASS in every one of the six runs.

**Why the cache cannot reach this block.** The fixture launches the adapter through `env -i`
(`tests/selftest.sh:2245`), which scrubs `CF_TOOLCHAIN_CACHE` and both XDG variables:

```
2245:  env -i PATH="$tmpd/bin:/usr/bin:/bin" HOME="$cf183_home" TMPDIR="$tmpd" \
```

The only sites that thread the cache through isolation are the six XDG passthroughs at
`tests/selftest.sh:7000-7001, 7025-7026, 7434-7435, 7459-7460, 7474-7475, 7484-7485` — none of them
is inside the cf183 block. An empty cache changes only how long a *provisioning* fixture takes; it
cannot change a row's text here.

**Why a stray listener cannot explain it either.** `tests/selftest.sh:2242` writes an `ss` stub that
exits 1 inside the fixture `PATH`, so `scripts/harness/install-hermes.sh:305` always takes the
"nothing on :$PORT" branch and the port row is deterministic (`:328`). This matters because the
fleet runs several suites concurrently (I measured 7–8 `selftest.sh` processes on this host), and a
real listener on :10800 would otherwise be a plausible flake source. It is not one.

The third check (`tests/selftest.sh:2294-2298`) trips only when one of these is not exactly right:
`PASS binary — $cf183_home/hermes-venv/bin/hermes`, `PASS version — 0.19.0 (pin 0.19.0)`, and
`HERMES: FAIL (2)`. All three are functions of the fixture's own throwaway home, not of the cache.

---

## 4. Attribution, row by row

| # | row (as the brief reports it) | classification | confidence |
|---|---|---|---|
| 1 | `cf183 venv-mismatch installed --check (exit 1): harness: hermes (pin 0.19.0, port 10800)` | **not reproduced**; cold cache **excluded** as its cause; the trip's own trigger is **NOT PROVEN** | high that the cache is not the cause; none for the trigger |
| 2 | `inference_key — no provider key` | **(c) counting artifact** — injected by row 1 (`tests/selftest.sh:2301` embedding `scripts/harness/install-hermes.sh:336`) | high — proven by construction |
| 3 | the extra `:10800` row (5 vs 4) | **(c) counting artifact** — it *is* row 2's sibling, `FAIL port — nothing on :10800` (`install-hermes.sh:328`) | high — proven by construction |

Practical consequence: rows 2 and 3 carry no independent information. Counting them as separate
cold-only failures double-counts one assertion. The only row worth attributing was row 1, and it
did not reproduce in five full-suite arms (three of them with the vite-plus shim on `PATH`, one of
them with a genuinely cold, 230 M-provisioning cache) or in six isolated block runs.

---

## 5. NOT PROVEN

1. **What made cf183's third check trip in the PERF-018 cold arm.** Not reproduced. The mechanism
   must be a change in the adapter's own output (binary/version/PASS-count), and I found no path by
   which an empty cache reaches that fixture. Candidates I could not test against a run I do not
   have: a transient ENOENT/ENOSPC inside the throwaway home at the moment of `cp` in the fixture
   `python` stub (`tests/selftest.sh:2237`, which copies `hermes.pin` into
   `$HOME/hermes-venv/bin/hermes`), and a short-read of the pin binary. Both are **hypotheses,
   unmeasured**.
2. **Which row collided in their cold arm.** Their delta is +5 rows (649 vs 644: +3 FAIL, +2 PASS).
   My demonstration injects 6 rows per tripped arm (3 FAIL + 3 PASS). One of the three injected PASS
   rows must therefore have coincided with a row already present in their tree; I cannot tell which
   from a summary. So "their cold-only set is exactly {row1, row2, row3}" is consistent with the
   mechanism but **not proven row-for-row**.
3. **Their wall time (565.27 s) versus mine.** Not comparable: their window ran at load 38.6 → 66.8,
   mine at 46.4 → 38.7 (cold) and 33.5 → 38.1 (warm). The only wall claim I can defend is the
   matched pair: **cold2 265 s vs warm3 231 s, +34 s (+14.7 %), same HEAD, adjacent windows**.
4. **That the +34 s is all provisioning.** The node/E2E section is where the cache root grows, but I
   did not attribute the delta per section.
5. **Why my row totals differ from the PERF-018 baseline** (mine 650 = 588 + 62; theirs 644 = 583 +
   61). The delta is identical in my warm and cold arms, so it is state, not cache — most likely
   tree/board content (my arms print `576/576 rows parse` and `542 tracked file(s)` where an earlier
   arm printed `574/574` and `498`), but I did not reconcile it row-by-row.
6. **The single red both my arms share.** Every arm ends `SELFTEST: FAIL (1)`, and the red is
   section 51's tracked-python-surface check:

   ```
     FAIL  tracked python surface is red: a python-staging commit is refused
       | I001 [*] Import block is un-sorted or un-formatted
       |   --> docs/audits/cf089-census-standin.py:7:1
   ```

   It is **not** cache-related (present in all five arms, warm and cold). Cause, measured: the
   suite's verdict depends on which `ruff` wins the `PATH` race —

   ```
   $ <hermes venv>/bin/ruff --version            -> ruff 0.17.5
   $ <hermes venv>/bin/ruff check $(git ls-files '*.py')  -> rc=1, I001 at docs/audits/cf089-census-standin.py:7:1
   $ ~/.local/bin/ruff --version        -> ruff 0.15.22
   $ ~/.local/bin/ruff check $(git ls-files '*.py') -> rc=0, "All checks passed!"
   ```

   The cron-spawned suite resolves the venv ruff (0.17.5, first on its `PATH`); an operator shell
   resolves `~/.local/bin/ruff` (0.15.22). A stale `.ruff_cache/0.17.5/` sits in the repo beside
   `.ruff_cache/0.15.22/`, consistent with both versions having run here. **Reported, not fixed** —
   it is outside this row's scope and it is not mine to re-scope. Note this also means the
   documented expectation `bash tests/selftest.sh` → `SELFTEST: PASS` is not reachable on this host
   as configured, independent of the cache.

---

## 6. Defects to report (not fixed here)

### 6.1 One assertion becomes many rows

`say "  FAIL  …: $out"` turns one failed assertion into a variable number of printable rows (32
sites in `tests/selftest.sh`). Any cross-run row-set comparison — exactly the tool this investigation
needed — is then unreliable: it reports the *child's* rows as the *suite's* rows, which is how two of
the three "cold-only rows" came to exist. A fix would print `$out` on indented continuation lines
that a row parser cannot mistake for verdicts (or write it to a per-section file and name the path).
Per the brief, this is recorded rather than changed.

### 6.2 The publish gate refused this audit's own first commit (observed, then complied with)

The first commit of this file was refused by the pre-commit guard, whose Tier-1 suite runs the CF-050
publish gate. Verbatim from `commit.out` and the guard log:

```
Tier 1 Guards: FAIL  (test mode: full)
  ✓ secrets — clean (gitleaks + builtin cross-check); scanners: nice=nice -n 10
  ~ lint — skipped (no staged files)
  ✗ tests (full) — EXIT=1
  guard log: .gitreins/logs/guard-20261117T104656.101189Z.log

Fix the issues above and re-run: gitreins guard
COMMIT_RC=1
```

and inside that log the single red (the suite's own `SELFTEST: FAIL (1)`) was not the ruff row this
audit discusses — section 51 **passed** in the guard's run (`PASS tracked python surface clean: 86
files graded`, because the guard's `PATH` resolves `~/.local/bin/ruff` 0.15.22 first) — but:

```
FAIL  publish paths — baseline 0, current 1; paths: docs/audits/cf-PERF-021-cold-cache-attribution.md
```

That row comes from `cf050_publish_gate` (`tests/selftest.sh:7046-7085`), which greps the **index**
for an absolute `/home/<name>/` path and treats it as a publication leak. Quoting the raw evidence
paths in this file tripped it. The gate is right and the file was wrong: every host-home path here is
now written as `~` (the normaliser resolves the running user's home through `$HOME`). No gate was
weakened, no assertion re-scoped, and the refusal is recorded rather than routed around.

Note the coupling this exposes: the gate greps the *index*, so a documentation commit can be refused
by a rule about publication hygiene while the suite is simultaneously red for an unrelated reason
(§5.6) — two independent reds, one guard run, one exit code.

---

## 7. Reproduce

```bash
# arm (either take): the suite is launched the same way, only the cache root differs
cd ~/code-factory
env -u CF_TOOLCHAIN_CACHE bash tests/selftest.sh > warm.log 2>&1          # warm
mkdir -p /path/to/fresh-empty-dir
CF_TOOLCHAIN_CACHE=/path/to/fresh-empty-dir bash tests/selftest.sh > cold.log 2>&1

# counts
grep -cE '^  PASS  ' warm.log; grep -cE '^  FAIL  ' warm.log; grep -c  ':10800' warm.log

# normalised row-set diff  (norm.sh as embedded in §1)
diff <(norm.sh warm.log) <(norm.sh cold.log)

# cf183 block in isolation (warm ×2, cold ×N with a fresh root each)
bash cf183-arm.sh                     # extracted verbatim from tests/selftest.sh:2215-2306
CF_TOOLCHAIN_CACHE=<fresh> bash cf183-arm.sh

# the red's real cause
<hermes venv>/bin/ruff check $(git ls-files '*.py')   # rc=1 (0.17.5)
~/.local/bin/ruff check $(git ls-files '*.py')  # rc=0 (0.15.22)
```

Raw artefacts (outside the repo, pruned after a day by the scratch policy):
`~/.hermes/cache/scratch/cf-perf021-w/` — `warm{,2,3}.log`, `cold{,2}.log`,
`cf183-{warm,cold,}-*.log`, `cf183-arm-tripped.sh`, `norm.sh`, `*.pre.txt`, `*.post.txt`,
`*.meta`, `env-probe.txt`.
