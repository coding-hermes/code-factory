# PERF-012 — selftest board validation was process-spawn bound

Tick: `code-factory-perf-2026-11-03-10-56-35`. Lane: code-factory / perf.
Measured clone: fresh `git clone git@github.com:coding-hermes/code-factory.git` at
`4638e90f6ef14c6360c25bf9bff22c6624701bf4` (origin/main), clean working tree.
The canonical checkout `/home/kara/code-factory` remains detached at `cc0a1e4` behind an
interrupted rebase (`.git/rebase-merge` since 2026-10-30 14:03) and was not touched.

Fixture: the tracked board, **30 rows**, `sha256 cfc42c9b2263a0b12e308786096d61ef6e4f161a8ca69680c8802fba6832ed22`.
Shell: bash. No build profile (the repo ships no build target).

## Measured defect

`tests/selftest.sh:150` validated the board by starting `python3` once per JSONL row:

```sh
while IFS= read -r line; do printf '%s' "$line" | python3 -c 'import json,sys; json.load(sys.stdin)' ... done < "$b"
```

30 rows = 30 interpreters. `strace -f -c` attributed 82.3 % of the run to `wait4`
(669 calls / 1.805 s) and 495 `execve` calls.

## Before / after

Paired, interleaved run (`hyperfine --warmup 3 --runs 15` benchmarks both commands in the same
session so host drift hits both arms):

| Metric | Before (`tests/selftest-old.sh` @ 4638e90) | After (`tests/selftest.sh`, in-tree parser) |
|---|---|---|
| mean | 1.572 s | 0.778 s |
| stddev | 0.249 s | 0.125 s |
| min | 1.309 s | 0.653 s |
| max | 2.153 s | 1.123 s |
| runs / exit codes | 15 / all 0 | 15 / all 0 |
| `wait4` calls / seconds (`strace -f -c`) | 669 / 1.805 s (82.3 %) | 576 / 1.692 s (83.4 %) |
| `execve` calls | 495 | 465 |

Headline: **1.572 s -> 0.778 s, 2.02 ± 0.46x faster**, 30 fewer interpreter launches.
Standalone runs of the single command (not paired) recorded 1.392 s ± 0.209 (before) and
854 ms ± 432 (after) on a busy host; the paired numbers are the ones to quote because the
unpaired pair straddled a load change.

Reproduction:

```sh
git clone git@github.com:coding-hermes/code-factory.git /tmp/cf && cd /tmp/cf
git checkout 4638e90f6ef14c6360c25bf9bff22c6624701bf4
git show HEAD:tests/selftest.sh > tests/selftest-old.sh          # baseline arm
hyperfine --warmup 3 --runs 15 'bash tests/selftest-old.sh' 'bash tests/selftest.sh'
strace -f -c -o /tmp/strace.txt bash tests/selftest.sh
```

Raw artifacts (JSON, this host): `/home/kara/.hermes/cache/scratch/cf-perf-20261103-114628/`
— `base-30row.json`, `after-30row.json`, `paired-30row.json`, `strace-base.txt`, `strace-after.txt`.

## Behaviour preserved (negative controls)

The one-process parser was required to keep the old `while read` semantics, so three fixtures were
run against both arms:

| Fixture | Old arm | New arm |
|---|---|---|
| tracked 30-row board | PASS 30/30, SELFTEST: PASS | PASS 30/30, SELFTEST: PASS |
| one malformed JSON line appended (31 lines) | FAIL 30 of 31, SELFTEST: FAIL (1) | FAIL 30 of 31, SELFTEST: FAIL (1) |
| trailing newline stripped | PASS 29/29 | PASS 29/29 |
| empty board | PASS 0/0 | PASS 0/0 |

The board file was restored after each fixture (`git checkout -- .coding-hermes/board/tasks.jsonl`,
hash re-checked to `cfc42c9b…`).

## Refuted prior record

PERF-012's original reasoning measured a 16-row fixture and reported 591.5 ms -> 213.7 ms.
Those numbers do not reproduce here: the current board has 30 rows and the script has grown two
test sections (4b, 10), so the old pair is not comparable and its "591.5 ms" headline is a
different input. The mechanism (one subprocess per row) is confirmed; the magnitude is this
document's paired pair at fixture sha256 `cfc42c9b…`. The row is closed on the numbers above.

## Discovered, not fixed here

The old loop never read an unterminated final line (`while read` returns nonzero at EOF without a
delimiter), so a board truncated mid-record still passed with `29/29`. That blind spot is preserved
verbatim by this change — fixing it is a behaviour change, filed separately as `CF-048`.

## Not measured

- build: the repo ships no build target (`CF-032`), so there is nothing to time.
- node provision / repo clone: measured in the previous lane tick, unchanged by this diff; not
  re-timed here because this change does not touch `scripts/`.
- live node round trip: no bunker node available to this lane.
