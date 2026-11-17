# CF-482 — judge findings against the shipped instruments, upheld and refuted

Judge run `68b41a9b` (task CF-482, commit `f3a61ff7`) returned **Overall: PASS** with
`merge_recommendation: no_concerns_found`, and its review raised six findings against the probe
scripts that ship beside `docs/audits/cf482-board-gate-arm-flake-evidence.md`. This artifact
grades all six: three stand and are still open, three are refuted by running them.

The certified artifact was **not** edited to answer this — its sha256 is the evidence fingerprint
on the closed CF-482 row, so a rewrite would silently rebind the row. The open items are filed as
CF-485.

## Upheld (still open)

1. **`cf482-decider-differential.sh` can report a false reproduction in a checkout with no
   `origin/main`.** The script does `git -C "$repo" show origin/main:tests/selftest.sh` under
   `set -uo pipefail` with no `-e` and no guard. Where that ref does not resolve, `pre.sh` is
   empty, the awk extraction yields an empty `pre_cond`, `eval ""` returns 0, and every
   `decide_pre` call prints `PASS` — the differential would "reproduce" nothing and read clean.
   Severity is high because it fails toward a false green.
2. **The differential never asserts the helper's printed decision text.** `decide_post` runs
   `verdict=$(board_fixture_verdict …)` and reports its exit status. A helper that returned 0
   while printing a FAIL reason would pass this differential, and the artifact's claim is that the
   printed decision *is* the evidence.
3. **`cf482-pipefail-probe-direction2.sh` exercises one ordering only.** The payload puts the
   `PASS` row first, so the `case` branch is never compared against a payload where the `PASS` row
   sits elsewhere — narrower than the doc's claim of a general comparison.

## Refuted (with the run that refutes them)

4. *"`if eval <stripped conjunction>` tests only the last command in the list, so the measured
   pre-fix decider is not the shipped one."* An AND-list returns non-zero as soon as any term
   fails, so its status **is** the conjunction:

   ```
   true && false && true -> 1
   false && true && true -> 1
   true && true && true  -> 0
   if eval(...) BRANCH: FALSE (correct)
   first-term-false BRANCH: FALSE (correct)
   ```

   The differential's own cases C (`rc=0`) and D (named FAIL row absent) return FAIL for the
   pre-fix decider, which is only possible if the earlier terms are being honoured. If the claim
   were true, both would have read PASS.

5. *"`[ "$?" -eq 141 ]` reads the status of the previous `[` test, so the rc=141 column can never
   increment."* Both reads in the probe follow their own pipeline directly, and the column does
   increment — the published run printed `rc=141=30/30`. Re-run:

   ```
   pipeline 2 exited 141 (status read immediately after THAT pipeline, not after the previous [ test ])
   ```

   (The `matched` line of that same probe correctly prints nothing for pipeline 1: the pipeline
   really did fail with 141, which is the finding, not a script bug.)

6. *"the helper's `why` message says `board_arm leaked a PASS row` when the leaked row is the
   fixture's own `PASS  3/3 rows parse`."* The captured variable **is** `board_arm`'s stdout, so a
   `PASS` line in it is a `board_arm` line by construction; the wording is accurate.

## Also open, from the verdict's uncovered failure paths

Nothing reds if a future edit reintroduces a producer-piped `grep -q` into an arm of section 7b.
The helper makes today's arms deterministic; it does not stop the shape from coming back. Carried
in CF-485 with the three upheld items.

## Reproduce

```bash
bash docs/audits/cf482-decider-differential.sh "$PWD"     # items 1, 2, 4
bash docs/audits/cf482-pipefail-probe.sh                  # item 5 (TRIES=10 is enough)
bash docs/audits/cf482-pipefail-probe-direction2.sh       # item 3
```

Tier: T3 — every item above was decided by executing the shipped script, not by reading it.
