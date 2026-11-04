# CF-176 — the family census claimed a fully armed family while one row was auto-disabled

- **Lane:** `code-factory-docs`, tick `code-factory-docs-2026-11-04-08-12-52`
- **Tip measured:** `1fea92d204b6d851c7262b89e4b202636a85785d` (= `origin/main` when the tick began)
- **Transport:** fresh clone of the published remote under tick scratch; the registered checkout
  `/home/kara/code-factory` was not written to (siblings `code-factory`, `code-factory-perf` and
  `code-factory-duckbrain-sync` read `running` on the same workdir for this slot).
- **Row:** CF-176 (`P3`, pending) — filed by `code-factory-qa` after the CF-169 correction.
- **GitReins task:** `CF-176-DOC1`.

## 1. The claim that was false

`docs/SCHEDULER-ADMISSION.md:53-55`, written by the CF-169 correction (`6fd2279`):

> Measured 2026-11-04: the live family carried ceiling/floor ratios of 8× (`docs`, `perf`, `qa`,
> `readme`, `review`), 16×, 48×, 192×, 224× and 576×, **every row enabled**. Read the pair back
> after arming; the API will not check it for you.

The ratios are true and reproduce exactly (section 3). The arm assertion is false at the same
measurement: the row the sentence itself names as an 8× row, `code-factory-qa`, has been
`enabled=0` since `2026-11-04T06:03:49Z` (`disabled_by=auto-disable`), which is **seven minutes
before** the docs tick that measured the census. An operator auditing whether the family is armed
would read that sentence and skip the read-back it tells them to perform.

Why it can only be a live fact: `enabled` is rewritten at runtime by the auto-disable path, so no
paragraph can state a family-wide arm state as a property of the tree.

```go
// coding-hermes/scheduler internal/scheduler/alert_escalation.go:544-548
reason := fmt.Sprintf("failure rate %.1f%% (%d/%d ticks, window %d, threshold %.2f)",
    rate*100, failed, total, window, ae.autoDisable.failureRate)
_, err = ae.db.ExecContext(ctx,
    `UPDATE projects SET enabled = 0, disabled_at = ?, disabled_by = 'auto-disable', disabled_reason = ?, updated_at = ? WHERE name = ? AND enabled = 1`,
    nowStr, reason, nowStr, name)
```

## 2. The correction

| | File:line | Text |
|---|---|---|
| Before | `docs/SCHEDULER-ADMISSION.md:55` | `and 576×, every row enabled. Read the pair back after arming; the API will not check it for you.` |
| After | `docs/SCHEDULER-ADMISSION.md:55-63` | `… and 576×, across 17 ceiling-bearing rows of which 16 were enabled: code-factory-qa read enabled=0, set by auto-disable on failure rate 91.3% (84/92 ticks, window 100, threshold 0.90). Arm state is a per-row fact, not a family property — an auto-disable can land minutes before or after a census, so read the flags back alongside the pair and report the disabled rows instead of summarising the family as armed: sqlite3 … "select name, case when cooldown_floor_s>0 then cooldown_ceiling_s/cooldown_floor_s end ratio, enabled, coalesce(disabled_by,'-') disabled_by from projects where name like '<family>%' and cooldown_ceiling_s>0;". The API will not check the ratio for you.` |

The replacement names the capability in different words rather than negating the removed sentence,
so the row's literal acceptance grep cannot match it.
The measured counts and the auto-disable reason are stated as a dated measurement of a live system,
with the SQL that produces them beside them — not as a property of the repository.

## 3. Literal output

Removed assertion, before the change:

```
$ grep -n 'every row enabled' docs/SCHEDULER-ADMISSION.md
55:  and 576×, every row enabled. Read the pair back after arming; the API will not check it for you.
```

After the change:

```
$ grep -c 'every row enabled' docs/SCHEDULER-ADMISSION.md
0
$ grep -rc 'every row enabled' docs/*.md README.md specs/*.md | grep -v ':0$' || echo "NO_MATCHES_ANY_DOC"
NO_MATCHES_ANY_DOC
```

Census (the read-back the corrected prose prescribes), run at 2026-11-04T03:2x-05:00 against the
live scheduler DB:

```
$ sqlite3 -header -column ~/.hermes/coding-hermes/scheduler.db "select name, cooldown_floor_s floor, cooldown_ceiling_s ceil, case when cooldown_floor_s>0 then cooldown_ceiling_s/cooldown_floor_s else null end ratio, enabled, coalesce(disabled_by,'-') disabled_by from projects where name like 'code-factory%' and cooldown_ceiling_s>0 order by ratio, name;"
name               floor    ceil    ratio  enabled  disabled_by
-----------------------------  ------  -------  -----  -------  ------------
code-factory-docs               604800  4838400      8        1  -
code-factory-perf               604800  4838400      8        1  -
code-factory-qa                  21600   172800      8        0  auto-disable
code-factory-readme             604800  4838400      8        1  -
code-factory-review             604800  4838400      8        1  -
code-factory-duckbrain-dogfood   21600   345600     16        1  -
code-factory-duckbrain-pm        21600   345600     16        1  -
code-factory-duckbrain-qa        21600   345600     16        1  -
code-factory-duckbrain-releng    21600   345600     16        1  -
code-factory-duckbrain-sync      21600   345600     16        1  -
code-factory-readme-qa           21600   345600     16        1  -
code-factory-releng-qa           21600   345600     16        1  -
code-factory-sync                 3600   172800     48        1  -
code-factory-pm                   3600   691200    192        1  -
code-factory-releng               3600   691200    192        1  -
code-factory-docs-qa             21600  4838400    224        1  -
code-factory-dogfood              3600  2073600    576        1  -

$ sqlite3 ~/.hermes/coding-hermes/scheduler.db "select name, enabled, disabled_by, disabled_reason from projects where name like 'code-factory%' and cooldown_ceiling_s>0 and enabled=0;"
code-factory-qa|0|auto-disable|failure rate 91.3% (84/92 ticks, window 100, threshold 0.90)
```

Rows with a non-zero ceiling: 17. Enabled among them: 16.

The one query the corrected paragraph now prescribes — ratios and arm flags in the same output, so
the two numbers cannot drift apart again:

```
$ sqlite3 -header -column ~/.hermes/coding-hermes/scheduler.db "select name, case when cooldown_floor_s>0 then cooldown_ceiling_s/cooldown_floor_s end ratio, enabled, coalesce(disabled_by,'-') disabled_by from projects where name like 'code-factory%' and cooldown_ceiling_s>0 order by ratio, name;"
name               ratio  enabled  disabled_by
-----------------------------  -----  -------  ------------
code-factory-docs                   8        1  -
code-factory-perf                   8        1  -
code-factory-qa                     8        0  auto-disable
code-factory-readme                 8        1  -
code-factory-review                 8        1  -
code-factory-duckbrain-dogfood     16        1  -
code-factory-duckbrain-pm          16        1  -
code-factory-duckbrain-qa          16        1  -
code-factory-duckbrain-releng      16        1  -
code-factory-duckbrain-sync        16        1  -
code-factory-readme-qa             16        1  -
code-factory-releng-qa             16        1  -
code-factory-sync                  48        1  -
code-factory-pm                   192        1  -
code-factory-releng               192        1  -
code-factory-docs-qa              224        1  -
code-factory-dogfood              576        1  -
```

## 3b. The sibling artifact that carried the same false measurement

CF-176 acceptance criterion 3 required the closed row's own evidence file to stop repeating the
false value. `docs/audits/code-factory-docs-2026-11-04-cf169-validator-claim.md:89` read:

> Every one of those rows is `enabled=1`, and none of the non-8× rows is refused …

It now reads `At that same measurement 16 of those 17 rows were enabled=1: code-factory-qa was
already enabled=0 (disabled_by=auto-disable, failure rate 91.3%). An earlier wording of this
section described the whole set as enabled; that sentence was wrong and is superseded by CF-176 …`.
The sibling's numbers (ratios, refusal reasoning) are left intact — only the arm claim is corrected
and attributed.

Claims in the same sentence that came back **true** (re-tested, not repeated):

| Claim | Verdict | Instrument |
|---|---|---|
| ratios 8× for `docs`, `perf`, `qa`, `readme`, `review` | true | table above |
| ratios 16×, 48×, 192×, 224×, 576× present in the family | true | table above |
| the API does not check the ratio for you | true | `laneIsUnarmed`/`validateLaneArming` as cited by CF-169's evidence, unchanged by this tick |

## 4. Gate

`bash tests/selftest.sh` in the same clone:

| Commit | Result |
|---|---|
| `1fea92d` (base, before the edit) | `SELFTEST: PASS`, exit 0 — log `selftest-base.log` |
| `9149ff8` (first implementation commit) | `SELFTEST: PASS`, exit 0 — log `selftest-head.log` |
| this commit (second, satisfies AC2 and AC3) | `SELFTEST: PASS`, exit 0 — log `selftest-head2.log` |

`bash scripts/boardctl validate` at this commit: `RESULT: OK (3 warning(s))` — the three warnings are
pre-existing (`CF-034`'s free-form guard/ci values and the headerless board), not introduced here.

Two implementation commits, disclosed rather than squashed: the first (`9149ff8`) corrected the
paragraph and carried a verdict (`CF-176-DOC2`, PASS, bound to that SHA); re-reading the row's
acceptance criteria afterwards surfaced AC2 (one query printing ratios *and* enabled together) and
AC3 (the sibling artifact still carrying the false value), which this second commit satisfies. The
row's closure binds to the second commit's own verdict, not to the first one.

The suite reads neither this paragraph nor the scheduler DB, so a PASS at every tip is the expected
result; it is quoted to show the correction adds no new failure, not to claim the gate covers it.

## 5. Claims I could not verify

- **Whether `code-factory-qa` remains disabled.** Its `enabled` flag is live runtime state; this
  tick measured it at the timestamp in section 3 and nothing in the repository records it. Later
  arm state: **not measured**.
- **Whether an operator was ever misled by the sentence.** Not measured — the repo carries no
  consumer of this paragraph, and `tests/selftest.sh` does not read it.
- **The other `docs/` counts that describe live schedulers.** The same class (a hand-typed live
  fact inside a shipped document) is owned by CF-081 and CF-176's siblings CF-177/CF-178; this tick
  corrected only the `docs/SCHEDULER-ADMISSION.md` arm sentence.

ch:trace row=CF-176 spec=docs/SCHEDULER-ADMISSION.md test=tests/selftest.sh evidence=docs/audits/code-factory-docs-2026-11-04-CF-176.md verdict=CF-176-DOC1 memory=code-factory:/code-factory/tick/docs/2026-11-04-0812

STATUS: complete
TIER: T3 (command run and output observed)
EVIDENCE: grep (0 matches after), live sqlite census (17 rows / 16 enabled), `tests/selftest.sh` PASS at base and head
