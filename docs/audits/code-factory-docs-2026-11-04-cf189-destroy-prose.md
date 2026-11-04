# code-factory docs lane — tick `code-factory-docs-2026-11-04-10-01-07` (claim: destroy is BLOCKED)

Third execution of this tick id, and it is a duplicate dispatch: the same id fired more than once
and each session took a different claim. Left unclaimed and unmodified here:

- first execution → `CF-197` (public-bind auth-gate prose), evidence `docs/audits/code-factory-docs-2026-11-04-cf071-auth-prose.md`
- second execution → `CF-198` (acceptance-plan section mapping), evidence `docs/audits/code-factory-docs-2026-11-04-cf198-section-map.md`

This file covers a distinct claim and a distinct board row (`CF-189`).

## Claim corrected

`docs/OPERATIONS.md` asserted, in four places, that **destroying a bunker agent is an unmeasured,
BLOCKED / NOT YET action and that its CLI verb must not be guessed** — while the shipped create path
prints that exact verb to the operator on a failed provision, and a committed run in this same tree
records the verb being run to completion with `rc=0`. The runbook therefore forbade the one lifecycle
step its own tooling instructs the operator to perform, and a reader could not tell whether following
the printed command was supported.

Two sources falsify the old text, both in the tree at the same commit:

1. **Code path** — `scripts/node-create.sh:50-57`, `incomplete()`: when `$SPAWNED -eq 1` it prints
   `cleanup required: bunker destroy <agent> --server <server>` (line 54) and exits 1. The create
   path never destroys anything itself; it hands the operator the exact command.
2. **Recorded measurement** — `docs/audits/code-factory-dogfood-2026-11-04-02-20-15.md` §2c: the
   command was run on 2026-11-04 and destroyed a real agent (`home 256.9 MB; archiving before
   delete`; `Agent … destroyed.`; local SSH key removed; `rc=0`; `bunker list` back to the
   pre-existing count).

| Where | Before | After |
|---|---|---|
| `docs/OPERATIONS.md:63` | "There is no separate checked-in renew, destroy, or rebuild command. Those lifecycle actions are **BLOCKED / NOT YET**" | renew/rebuild/revocation stay BLOCKED; destroy named as a measured operator step (§8) that the create path prints (`scripts/node-create.sh:54`) |
| `docs/OPERATIONS.md:167` | destroy listed among the unmeasured actions; "These steps are **BLOCKED / NOT YET**" | new paragraph "Destroying an agent is a measured operator step" quoting the verb, its output, `rc=0` and the committed transcript; a separate paragraph keeps renewal / rebuild / credential revocation BLOCKED / NOT YET |
| `docs/OPERATIONS.md:171` | "Destruction/rebuild was not performed or tested here" | "only the destroy step has been performed and recorded"; rebuild, credential revocation and destroy-then-recreate are **not measured** |
| `docs/OPERATIONS.md:175` (§9 Teardown) | teardown marked "manual, operator-owned, BLOCKED", with destroy folded into the blocked set | teardown as a whole stays BLOCKED / NOT YET; its agent-destroy step is called out as the measured exception |
| `docs/OPERATIONS.md:205` | "There is no tracked … node renewal, destroy, rebuild, or teardown command" | list drops destroy; "No script destroys an agent for the operator either … prints the exact `bunker destroy … --server …` line to run (`scripts/node-create.sh:54`)" |

## What the corrected prose now says, and what it refuses to claim

Stated as measured: the destroy verb, the `--server` form, the CLI's archive-before-delete
behaviour, `rc=0`, and the post-destroy agent count — all quoted from the committed transcript.

Explicitly **not measured** (unchanged or newly labelled):

- renewing a TTL — no command or measured procedure exists; `--ttl 6h` is a creation default, not a renewal;
- rebuilding from a manifest, and the destroy-then-recreate round trip (`CF-110` remains BLOCKED);
- credential revocation — deleting the agent does not revoke a crier identity or inference key;
- destroying an agent that still has running jobs;
- any teardown step other than destroy (disarm, drain, credential revoke, final identity check).

## The re-runnable check (red before, green after)

`cf189-probe.sh <doc>` greps the doc for the six stale assertions. Run in the tick clone:

```
$ git show HEAD:docs/OPERATIONS.md > before.md && cf189-probe.sh before.md    # pre-fix arm
STALE  line 63: 'no separate checked-in renew, destroy, or rebuild command' …
STALE  line 203: 'node renewal, destroy, rebuild, or teardown command' …
stale_destroy_claims=6

$ cf189-probe.sh docs/OPERATIONS.md                                          # post-fix arm
OK     line 63: 'no separate checked-in renew, destroy, or rebuild command'
… (six OK rows)
stale_destroy_claims=0
```

The same assertions can be re-run without the helper:

```
grep -c 'no separate checked-in renew, destroy, or rebuild command' docs/OPERATIONS.md   # 0
grep -c 'destruction/rebuild was not performed'                     docs/OPERATIONS.md   # 0
grep -n 'cleanup required: bunker destroy'                    scripts/node-create.sh     # 1 hit, :54
git show HEAD:docs/audits/code-factory-dogfood-2026-11-04-02-20-15.md | grep -c 'Agent node-dogfood-public-20261104-212331 destroyed'   # 1
```

## Claims I could not verify

- The **live** destroy behaviour was not re-run by this tick — no bunker host was touched. The
  paragraph quotes the committed 2026-11-04 transcript and says so; anything beyond that run is
  `not measured`.
- The second measurement recorded in `CF-189`'s row text (home 435.2 MB, agent `node-myrepo-042342`)
  has **no committed transcript** in this tree, so it is not cited in the prose.
- Whether the `bunker` client refuses `--server`-less destroy (the printed form always carries
  `%q --server %q`) is `not measured`.
- `docs/ACCEPTANCE-PLAN.md:93` (`CF-110`) still reads "BLOCKED … no destroy-and-recreate path or
  evidence is present in the inspected flow". Its gate is destroy **and recreate**, which is still
  unmeasured, so the cell was left untouched — its wording about "no evidence" is looser than the
  tree now supports and is left for `CF-110`'s owner rather than silently re-scoped here.

ch:trace row=CF-189 spec=docs/OPERATIONS.md#8-failure-recovery-renew-destroy-rebuild test=none:docs-prose-grep-probe doc=docs/OPERATIONS.md evidence=docs/audits/code-factory-docs-2026-11-04-cf189-destroy-prose.md witness=tests/selftest.sh verdict=CF-189-DOC1 commit=HEAD memory=none:recorded-at-closeout
STATUS: done
TIER: T3
EVIDENCE: cf189-probe.sh — 6 stale destroy claims at HEAD 2bb114f, 0 in this tree; node-create.sh:54 and the §2c transcript both resolve at this commit; `bash tests/selftest.sh` PASS
