# Appendix D — Process history

This appendix records the process-era wording removed from the handbook by the wave-8
voice pass (2026-11-07): round/panel working notes, reviewer attributions, and work-order
sentences. The handbook chapters state facts about the system only; the material below is
preserved verbatim as an audit trail. This part is not listed in BOOK.yaml and does not
render in the built book.

Original line numbers refer to each file as it stood at commit cb48e59 (before this pass).


## Source: chapters/M1-provisioning.md, chapters/M2-dispatch.md

## M1-provisioning.md:9
code-factory HEAD at round-13 derivation

## M1-provisioning.md:12
`node_seed.py` (405 lines, apply/build/check state machine) read this round

## M1-provisioning.md:26
Two measured lies this round:

## M1-provisioning.md:39
(grok B7 re-grade: the row previously classified both units **active** on `disk_floor.py`'s caller alone)

## M1-provisioning.md:40
an operator runs it (glm 2)

## M1-provisioning.md:45
(B06, written this round)

## M1-provisioning.md:66
Round-6's "deletes without reporting them as data loss" was **false** (B02, sol)

## M1-provisioning.md:112
(sol B05)

## M1-provisioning.md:125
(S4, settings surface — sol B07, added this round)

## M1-provisioning.md:136
(S5, settings surface — sol B07, added this round)

## M1-provisioning.md:171
(locator re-pinned this round)

## M1-provisioning.md:188
the state is UNVERIFIED where the wire was not measured this round

## M1-provisioning.md:193
(sol B06)

## M1-provisioning.md:193
(B03, sol): the actual key-generation/registration producer is not established in any code read this round

## M1-provisioning.md:193
round-4 cited only `HandleRegister` for the id-in-path route, which is wrong (kimi B08)

## M1-provisioning.md:193
the token/registration exchange was not re-run this round

## M1-provisioning.md:207
not run this round

## M1-provisioning.md:211
(absence-proved this round)

## M1-provisioning.md:219
(B09, measured this round)

## M1-provisioning.md:258
shifted every round-9 locator ~+25; all re-pinned this round

## M1-provisioning.md:330
round-3 said `disk_floor.py` is "invoked by bunker-provision.sh"

## M2-dispatch.md:9
code-factory HEAD at round-13 derivation

## M2-dispatch.md:33
matches only the files themselves (run this round)

## M2-dispatch.md:34
(grok 3 / sol B09)

## M2-dispatch.md:34
Round-4's "no production caller" was false.

## M2-dispatch.md:79
(B08, added this round)

## M2-dispatch.md:92
the wire was not measured this round

## M2-dispatch.md:100
(sol B03)

## M2-dispatch.md:108
not this round's measured result

## M2-dispatch.md:112
(absence-proved this round)

## M2-dispatch.md:123
(B09, measured this round)

## M2-dispatch.md:157
(B10, read this round)

## M2-dispatch.md:162
(B10 correction, sol B10)

## M2-dispatch.md:166
Round-4's "crash-before-persistence" discussion missed this same-batch case.

## M2-dispatch.md:188
round-4 said `add_family_lanes.py`/`configure_family.py`/`load_lane_config.py` **and** `lane_target.py` have no in-repo production caller

## Source: chapters/M3-repository.md, chapters/M4-board.md

# Wave 8 M3/M4 voice pass — harvest of deleted/rewritten process chatter

Original line numbers refer to the pre-edit files (docs/handbook/chapters/M3-repository.md, M4-board.md at `fbc19cb`).

## M3-repository.md:9
`Revision | fbc19cbc… (code-factory HEAD at round-13 derivation; …` — draft-history locator "at round-13 derivation" deleted; head revision itself kept. Also "…every §1/§7 arm locator re-pinned this round, see §7" → "re-pinned, see §7".

## M3-repository.md:12
"…the shipped landing arm `cf213-land-node-branch` … and the freshness arm `cf244-node-freshness` … were both run standalone this round (`SHIPPED_LANDING_ARM_RC=0`, …)" — "this round" marker deleted, run results kept. Also "**S3 hook *enforcement* is UNVERIFIED (sol B10):**" → "(B10)".

## M3-repository.md:37
"**(operator-invoked optional)** evidence cell: "…(B07 / sol B09 re-grade: was misclassified **active** on the strength of a `main()` entrypoint, which proves executability, not activation)" — agent name "sol" dropped, finding ids B07/B09 and misclassification fact kept.

## M3-repository.md:38
"…the OUTLINE *active* rule is not satisfied by evidence, and the body is unread this round |" — "this round" deleted; unread-body fact kept.

## M3-repository.md:39
"Round-4's \"invoked by the node's result envelope\" was fabricated (grok 4 / sol B04 / glm 2); an operator or out-of-repo foreman step runs it with `--branch/--commit` from the envelope" → "An earlier citation that it is \"invoked by the node's result envelope\" was fabricated (B04); an operator …". Round-4 draft reference and grok/sol/glm attributions deleted; B04 kept.

## M3-repository.md:97
CT-12 row: "…it does **not** stage the diff itself (sol B08) | … the wire to the judge binary was not measured this round; \"works\" is not asserted without a measured observation (sol B03) |" — "sol" names dropped (B08/B03 kept); "this round" deleted.

## M3-repository.md:101
"The round-3 M3-C2 producer was \"rumour — one side only\". The producer is nameable: it is `node-bus-worker.py`'s reply envelope (`:1176-1192`), specifically the `branch`/`commit` fields at `:1187-1188`. Both sides are now named." → "The M3-C2 producer is nameable: it is `node-bus-worker.py`'s reply envelope (`:1176-1192`), specifically the `branch`/`commit` fields at `:1187-1188`." Round-3 draft history and "Both sides are now named" process statement deleted; locator facts kept.

## M3-repository.md:113
"…13 sub-cases against disposable local git fixtures, run standalone this round)" — "this round" deleted.

## M3-repository.md:115
"Mutation-checked this round: deleting the two entries reds arm 1 only; widening the allowlist to `.*\.py` reds all three (`scanned ~0 bytes` …)" — "this round" deleted; mutation results kept.

## M3-repository.md:117
"**Behavioral verification (B07, corrected this round).** Round-6 said \"none is shipped\" — false." → "**Behavioral verification (B07).**" Round-6 rebuttal clause deleted; the shipped-arm evidence in the following sentences kept.

## M3-repository.md:121
"This round the arm was run independently: `SHIPPED_LANDING_ARM_RC=0`, `LANDING_ARM_FAILURES=0`." → "The arm was run independently: …" — marker deleted, results kept.

## M3-repository.md:126
"**Note (B04 / grok 9).** Round-3 cited \"selftest.sh arm 41 / arm 51 / arm 33\" — `selftest.sh` is **5,002 lines** (measured `wc -l tests/selftest.sh` this round) with *named* arms (…), and `grep -nE '\barm (33|41|51)\b' tests/selftest.sh` returns nothing. The numbered-arm pointers were unrepeatable; they are replaced with the named arms above. The arm locators `:2464-2730` (cf213) and `:3434-3671` (cf244) still resolve exactly at this line count (re-pinned this round after `tests/selftest.sh` grew +150 lines in `08a2c8a..fbc19cb`)." → "**Note (B04).** An earlier citation used \"selftest.sh arm 41 / arm 51 / arm 33\" … (measured `wc -l tests/selftest.sh`) … The numbered-arm pointers are unrepeatable … (re-pinned after `tests/selftest.sh` grew +150 lines in `08a2c8a..fbc19cb`)." Round-3 draft reference and grok attribution deleted; B04, measurements, and locators kept.

## M3-repository.md:136
"**RED — none (absence-proved this round).**" → "**RED — none (absence-proved).**"

## M3-repository.md:143
"**Scope (B09, measured this round).** `grep -cE '\b(ok|bad|warn|note|say)\s+\"' scripts/land-node-branch.sh` = **35** helper call sites." → "**Scope (B09, measured).**" — measurement kept.

## M3-repository.md:168
"**Hook effectiveness is not proven by hook presence (B11, read this round).**" → "**Hook effectiveness is not proven by hook presence (B11, read).**"

## M3-repository.md:196
"**F3-4** (new) — the numbered \"arm 41/51\" citations were unrepeatable (`selftest.sh` arms are named). The round-8 failure-mode row citing an F841 at `panel_loop.py:114` was **false**: `grep -nE 'rc\s*=|rc=' scripts/panel_loop.py` → 0 matches (the file assigns no such `rc`); the row is removed this round rather than re-pointed at a defect that does not exist." → "A former failure-mode row … the row is removed rather than re-pointed …" — round-8 draft reference deleted; F841/grep evidence kept.

## M3-repository.md:200
"**F3-5** (new) — `land-node-branch.sh` has no in-repo invoker (grep matches only the script + selftest arms); round-4's \"invoked by the node's result envelope\" was fabricated. S2 is operator-invoked (optional); the envelope names `branch`/`commit` but does not call the lander." → "…selftest arms); an earlier citation that it is \"invoked by the node's result envelope\" was fabricated. S2 is operator-invoked (optional); …" — round-4 reference deleted.

## M4-board.md:9
`Revision | fbc19cbc… (code-factory HEAD at round-13 derivation; `scripts/board_read.py` was added …` — "at round-13 derivation" deleted; head revision kept.

## M4-board.md:34
"`python3 scripts/board_drift.py check …` → `RESULT: DRIFT (4 failed)` this round (see §7)" — "this round" deleted; drift result kept.

## M4-board.md:48
"**`board_lock.py` classifier (B11; re-read in full for CF-259 this round).**" → "(B11; re-read in full for CF-259)".

## M4-board.md:66
"**Degraded observation (B08, sol; repaired by CF-259):**" → "**Degraded observation (B08; repaired by CF-259):**" — agent name dropped, B08 and CF-259 kept.

## M4-board.md:114
"**UNVERIFIED** — round-3 carried \"broken (OUTLINE §IV)\" as an inherited state; the gitreins-verdict→board-close path was not re-run this round |" → "**UNVERIFIED** — an inherited earlier state read \"broken (OUTLINE §IV)\"; the gitreins-verdict→board-close path was not re-run |" — round-3 draft reference and "this round" deleted.

## M4-board.md:120
"The honest state is therefore **UNVERIFIED**/**broken** per OUTLINE, not \"works\" — a \"works\" verdict attached to an unnamed side is a rumour with a verdict (grok 11 / deepseek 1)." → "…is a rumour with a verdict." — grok/deepseek attributions deleted (no finding id attached); the rumour-with-a-verdict maxim kept.

## M4-board.md:134
"**Drift re-measured (supersedes the round-11/12 reconciliation).** The round-10/11 CF-270 divergence is still reconciled (commit `4dc0ef0` closed CF-270 and is in `origin/main`), but a **new, different divergence appeared this round**: `board_drift` at HEAD `fbc19cb` returns `RESULT: DRIFT (4 failed)` …" → "**Drift re-measured.** The CF-270 divergence is reconciled (…), but a **different, newer divergence exists**: …" — round-11/12 and round-10/11 draft references and "this round" deleted; commit, drift result, and CF-150 facts kept.

## M4-board.md:142
"This is exactly the state `board_read.py` (new this round) is designed to resolve" → "This is exactly the state `board_read.py` is designed to resolve" — marker deleted (provenance "added in `dbf810b`" retained in §3).

## M4-board.md:147
"…which this round returned `RESULT: OK (7 warning(s))` …" → "…which returned …".

## M4-board.md:155
"**RED — none (absence-proved this round).**" → "**RED — none (absence-proved).**"

## M4-board.md:162
"`boardctl` is an external binary (`~/.local/bin/boardctl`, measured this round — not in this repo), so these strings carry no in-repo `file:line`; the `validate` and `drift` rows are quoted from run output re-captured this round (2026-11-07, rev `fbc19cb`); the duplicate-id row is carried from the round-11/12 capture (N9):" → "…measured — not in this repo), … quoted from run output (2026-11-07, rev `fbc19cb`); the duplicate-id row is carried from an earlier capture (N9):" — "this round" markers and round-11/12 draft reference deleted; capture date/rev and N9 kept.

## M4-board.md:178
"…this is an UNKNOWN observation, not proof of staleness (sol B09). Re-run the probe …" → "…(B09)." — agent name dropped, B09 kept.

## M4-board.md:216
"…the round-10 draft's pre-reconciliation DRIFT (CF-270 workdir `pending` vs published `complete`) is superseded." → "…the earlier pre-reconciliation DRIFT … is superseded." — round-10 draft reference deleted; reconciliation facts kept.

## M4-board.md:219
"**F4-5** (new, B04) — the board-admission gate belongs to M9 alone; crier has no board admission." → "**F4-5** (B04) —" — "new" draft marker deleted, B04 kept.

## M4-board.md:220
"**F4-6** (new, round 13) — `scripts/board_read.py` (added in `dbf810b`) is a new board READ unit …" → "**F4-6** (new) —" — "round 13" deleted; `dbf810b` provenance and CF-150 facts kept.

## Source: chapters/M5-harness.md, chapters/M6-documentation.md

# Harvest — M5-harness.md / M6-documentation.md voice pass

Original line numbers refer to the pre-edit files (git HEAD `fbc19cbc807de729e25c358fa7e94207b912f010` working tree at pass start).

## M5-harness.md:9
Revision field: "(code-factory HEAD at round-13 derivation; ..." → "(code-factory HEAD; ..." — round-13 draft-history marker deleted.

## M5-harness.md:12
Status field: "...(113 lines) read this round; ... the conformance battery not run this round" → "read; ... not run" — time markers deleted, facts kept.

## M5-harness.md:34
"not the wired runtime authority round-2 claimed." → "not the wired runtime authority." — round-2 attribution of the earlier claim deleted; the factual finding stands.

## M5-harness.md:36-38
"**Finding F5-5 (B02, corrected round 11; re-pinned round 13).** Round-5's "the installers are operator-invoked; a source search finds no production invocation" was **false** — it was a *computed-call-site* blindness." → rewritten to "**Finding F5-5 (B02).** A literal source search misses the production invocation — a *computed-call-site* case." — Round-5 quote, "corrected round 11 / re-pinned round 13" draft history deleted; finding ID and call-site facts kept.

## M5-harness.md:101
"**Per-adapter installation registers (B12, added this round — ...)**" → "(B12 — ...)" — "added this round" deleted.

## M5-harness.md:118
"the Go toolchain installer register (sol B12, added this round; "pinned" was NAME ONLY)" → "(B12; "pinned" was NAME ONLY)" — sol attribution and "added this round" deleted.

## M5-harness.md:132
"**Resolver controls (sol B10, added this round).**" → "**Resolver controls (B10).**" — sol attribution and "added this round" deleted.

## M5-harness.md:171
CT-17 State cell: "**UNVERIFIED** — not run this round (needs a live node)" → "not run (needs a live node)".

## M5-harness.md:194
Verification table, conformance legs row: "Last run: not run this round" → "not run".

## M5-harness.md:201
"**RED — none (absence-proved this round).**" → "**RED — none (absence-proved).**"

## M5-harness.md:208
"**Scope (B09, measured this round).**" → "**Scope (B09, measured).**"

## M5-harness.md:214
Log-line row kind cell: "evidentiary — round-5 cited `:53` (the module docstring's refusal list, not the emitter); `:388` is the print, `:389` is `return 2` (grok A)" → "evidentiary — `:388` is the print, `:389` is `return 2` (A)" — round-5 cross-reference to a superseded citation and grok attribution deleted; emitter locators kept.

## M5-harness.md:235
"**Adapter capability matrix (F5-3, completed this round):**" → "**Adapter capability matrix (F5-3):**"

## M5-harness.md:283
"**F5-5** (B02, re-pinned round 13) —" → "**F5-5** (B02) —"

## M5-harness.md:287
"**F5-6** (new, round 13) —" → "**F5-6** (CF-150) —" — round marker converted to the board-row id the finding implements.

## M6-documentation.md:9
Revision field: "(code-factory HEAD at round-13 derivation; ..." → "(code-factory HEAD; ..."

## M6-documentation.md:18
"(F6-2, corrected this round)" → "(F6-2)".

## M6-documentation.md:49
S8 row: "no in-repo caller, no cron/timer; run manually this round (VERIFY-PATCH: PASS)" → "run manually (VERIFY-PATCH: PASS)".

## M6-documentation.md:50
S9 row: "**operator-invoked** (run manually each round)" → "(run manually)"; and "the legacy `[0-9][0-9]-*.md` globs in the fill/render/check pipeline do not" → "the legacy `[0-9][0-9]-*.md` globs in `master_doc_fill.py`/`gen_nasa_handbook.py`/`master_doc_check.py` do not" — pipeline chatter converted to named units; two "(sol B01: ...)" attributions → "(B01: ...)".

## M6-documentation.md:52-55
"Round-3 classified S5–S8 "active" on prose (...). The classification rule requires the invoking line; ..." → rewritten as "A prose classification (...) does not satisfy the classification rule, which requires the invoking line; ..." — Round-3 draft history deleted; the classification rule and grep evidence kept.

## M6-documentation.md:88
fill `--workers` cell: "... at `:450`). Round-4's "0 serialises" was false (sol B14)" → "... at `:450`) (B14)" — Round-4 quote deleted; correction fact (0 raises, 1 is serial) and B14 id kept.

## M6-documentation.md:94
fill `--dry-run` cell: "— round-6 documented five controls and omitted the switches that decide whether writing or provider execution occurs (sol B11)" → "— the documented five controls omit the switches that decide whether writing or provider execution occurs (B11)".

## M6-documentation.md:96
"**Spine gate (S9, added this round — grok B5).**" → "**Spine gate (S9, B5).**"

## M6-documentation.md:100-103
"The round-9 defect this gate exists to close: its predecessor compared function tokens but never the **state** column..." → "The defect this gate closes: its predecessor compared..." — round-9 marker and work-order phrasing ("exists to close") removed; "The state-agreement check (and the CT-05 boundary→internal re-grade) are added this round" → "are part of the gate".

## M6-documentation.md:107
"**`panel_loop.py` settings and stop semantics (sol B14; re-pinned round 13).**" → "(B14)."

## M6-documentation.md:112,114
panel_loop table: two "(sol B12)" → "(B12)" — sol attributions deleted, B12 ids kept.

## M6-documentation.md:149
Verification table, patch chain row: "**PASS** — `5 stages, 4 patches, 57432007…` (the `deploy-doc` stage landed in commit `8ae4f82`, after the round-10 stamp's `4 stages, 3 patches, f393a681…`; re-quoted this round)" → "...(the `deploy-doc` stage landed in commit `8ae4f82`)" — round-10 stamp history and "re-quoted this round" deleted; current measured output and landing commit kept.

## M6-documentation.md:155
"**RED — none (absence-proved this round).**" → "**RED — none (absence-proved).**"

## M6-documentation.md:167-168
Removed paragraph: "(The round-3 `WRITER ROUND COMPLETE` / `PANEL REVIEW COMPLETE` "row" had no locator in any module; it was this loop's own marker, not a log line, and is removed.)" — process-history note about a previously removed pseudo-row.

## M6-documentation.md:179
Failure-modes row: "**resolved this round** — the spine now compares..." → "**resolved** — the spine now compares...".

## M6-documentation.md:180
"...not that the line exists at that number in that file (grok B6)" → "(B6)".

## M6-documentation.md:188-189
"- **The fill/render pipeline does not operate on the delivered chapter set (B15, locator re-pinned this round).**" → "(B15)."

## M6-documentation.md:204
Evidence of record: "`panel_loop.py:33-38, 321-461` (main() + config, re-read this round)" → "(main() + config)".

## M6-documentation.md:213-214
"**F6-2** — the gate is structural/citation, not a semantic truth verifier (`:128-138`, `:214-216`). Round-3's "recomputes VERIFIED" claim was **false** — the gate reports the supplied status." → "...verifier (`:128-138`, `:214-216`); the gate reports the supplied status rather than recomputing it." — Round-3 quote deleted; the corrected fact kept.

## M6-documentation.md:219
"**F6-5** (grok B5) —" → "**F6-5** (B5) —".

## M6-documentation.md:222
"**F6-6** (new, round 13) —" → "**F6-6** (new) —".

## Source: chapters/M7-github.md, chapters/M8-safety.md, chapters/M11-dispatcher.md

# Wave-8 harvest: M7/M8/M11 voice pass — deleted process-history content

## M7-github.md:9
`fbc19cbc807de729e25c358fa7e94207b912f010` (code-factory HEAD at round-13 derivation; no M7-cited file (`github-app-*.sh`, `github-app-token.py`) changed in `08a2c8a..fbc19cb` — claims carried, stamp advanced)
→ dropped "at round-13 derivation" and "— claims carried, stamp advanced".

## M7-github.md:31
…only `github-app-setup.sh:201/:284` printing manual refresh instructions (kimi B43); an operator runs the mint/refresh on demand
→ "(kimi B43)" converted to "(B43)".

## M7-github.md:62
…**`--quiet` suppresses selected output only** (`say_q` at `:55`) and does **not** prevent minting — round-4's "`--dry-run`/`--quiet` change write/no-write" conflated them (sol B16); …
→ "round-4's … conflated them (sol B16)" converted to factual "the two flags are distinct controls (B16)".

## M7-github.md:96
| fresh token, value not printed | not run this round | **UNVERIFIED** …
→ "not run this round" → "not run".

## M7-github.md:100
**RED — none (absence-proved this round).** No counters or gauges.
→ "absence-proved this round" → "absence-proved".

## M7-github.md:107
**Scope (B09, measured this round).** `grep -rcE …`
→ "measured this round" → "measured".

## M7-github.md:133
- **Credential domains are separate (B16, corrected this round).** M7's `github-app-token.py`
→ dropped ", corrected this round".

## M7-github.md:139-140
…compares incoming bearer tokens against it (`:115-123`); the producer of that mapping is not established in any code read this round (see M12 §6).
→ dropped "this round".

## M7-github.md:153-154
- **F7-3** (new) — round-3 claimed "M7 mints the per-dispatch scoped token" and "M7/M1 produce the node tokens". Both are **false**: the scoped token comes from …
→ "round-3 claimed … Both are **false**" converted to present-tense fact: "M7 does **not** mint the per-dispatch scoped token, and M7/M1 do **not** produce the node tokens".

## M8-safety.md:9
`fbc19cbc807de729e25c358fa7e94207b912f010` (code-factory HEAD at round-13 derivation; `reclaim_disk.py`/`check_scan_scope.py` byte-identical since `47d68b4`; …)
→ dropped "at round-13 derivation".

## M8-safety.md:12
| Status | **VERIFIED** — `reclaim_disk.py` (169 lines) and `check_scan_scope.py` (118 lines) both read in full this round |
→ dropped "this round".

## M8-safety.md:34
no production caller (`grep -rn check_scan_scope scripts/` → no caller; run manually this round)
→ "run manually this round" → "run manually".

## M8-safety.md:90
**RED — none (absence-proved this round).** No counters or gauges —
→ "absence-proved this round" → "absence-proved".

## M11-dispatcher.md:9
`283bca91091933177ec521e52f37f1bc987cf7da` (crier-fleet HEAD, stamped this round)
→ dropped ", stamped this round".

## M11-dispatcher.md:12
| Status | **VERIFIED** — `dispatcher.py` read in full this round (job model, ledger, …)
→ dropped "this round".

## M11-dispatcher.md:28
- **The deadline kill does not kill the harness's children (B01, corrected this round).** …
→ dropped ", corrected this round".

## M11-dispatcher.md:34
An independent disposable execution (sol round-5) measured `timeout_still_live=True` after the runner group was terminated.
→ deleted "(sol round-5)" agent/round attribution (B01/F11-8 retained elsewhere in the bullet).

## M11-dispatcher.md:71
…a negative value fails the `sleep` and the loop continues. Round-4's "0 or negative suppresses progress" was false (sol B25)
→ converted to factual "; 0 or negative does not suppress progress (B25)".

## M11-dispatcher.md:73
…(`grep -n EXEC_TIMEOUT dispatcher.py` → 1 match, the assignment itself; sol B22 AST check: exactly one `Store` reference, no load). … Round-5's "the timeout prefix on every `bunker exec` run" was **false** — this env var changes nothing at run time
→ "sol B22" → "B22"; "Round-5's … was **false** —" converted to factual "; this env var adds no timeout prefix to `bunker exec` and changes nothing at run time".

## M11-dispatcher.md:74
…raises `ValueError` **at use** (`int(TASK_S)` at `:196`), not at admission (kimi 8)
→ deleted "(kimi 8)" bare agent attribution (no B/F/CT id to preserve).

## M11-dispatcher.md:102
| failure oracle | not run this round | **UNVERIFIED** — … so they cannot fail (F11-2, glm 8) |
→ "not run this round" → "not run"; "(F11-2, glm 8)" → "(F11-2)".

## M11-dispatcher.md:104-105
The round-3 "source read (538 lines) PASS" row was decoration — reading the file cannot fail. It is removed; the body read is recorded in §1/§13 instead.
→ round-3 draft-history reference converted to factual statement: "A \"source read (538 lines)\" row cannot be a test — reading a file cannot fail; the body read is recorded in §1/§13 instead."

## M11-dispatcher.md:109
**RED — none (absence-proved this round).** …
→ "absence-proved this round" → "absence-proved".

## M11-dispatcher.md:131
…so this is a credential/client-config failure, not node unreachability (kimi B64 / sol B26)
→ "(kimi B64 / sol B26)" → "(B64 / B26)".

## M11-dispatcher.md:168
- **F11-6 (B23 corrected, sol B24).** …
→ "(B23 corrected, sol B24)" → "(B23, B24)".

## M11-dispatcher.md:170-171
…with `timeout (limit+30)`. Round-4 claimed the synchronous path has "no replay ledger" — **false**: `main()` checks the ledger …
→ "Round-4 claimed … — **false**" converted to factual "The synchronous path is **not** ledger-less".

## M11-dispatcher.md:187
- Code read: `dispatcher.py` (538 lines, read in full this round).
→ dropped "this round".

## M11-dispatcher.md:189
- Rev stamped: `283bca9` (re-confirmed this round: `git rev-parse HEAD` = …, `wc -l dispatcher.py` = 538).
→ "re-confirmed this round" → "re-confirmed".

## M7-github.md:87
…**UNVERIFIED** — the mint was never run (no App creds on this host); the consumer is an external API, so the state is UNVERIFIED, not "works" (kimi B42)
→ "(kimi B42)" converted to "(B42)".

## Source: chapters/M9-scheduler.md, chapters/M12-inference-proxy.md

## M9-scheduler.md:9
Revision field: "(scheduler repo HEAD, re-stamped round 13; moved from `34e44897` through 15 commits" — round-stamp marker deleted; git-move fact kept.

## M9-scheduler.md:47
"`cooldown/residue`. Round-6 named 33; the ten added this round are `hooks/reload`, `features`, `features/prune-candidates`, `peers`, `peers/`, `agents`, `agents/`, `federation/query`, `federation/catalogue`, `cooldown/residue`." — draft-history comparison deleted; converted to "Ten of the 43 are later additions: …" (full route list kept in the chapter).

## M9-scheduler.md:71
"(the fail-open doc at `:222-229`). Round-8 called a non-owned/empty board \"a refusal\" — that is wrong: this predicate decides the waiver, and `packer_select.go` performs the actual gates and cooldown decision on top of it." — round history deleted; fact (predicate decides the waiver only; packer_select performs the gates) kept.

## M9-scheduler.md:78
"distinct outcomes (B14, sol)" — agent attribution deleted; B14 kept.

## M9-scheduler.md:85
"reservation. Round-6 conflated \"nil authority\" with \"disabled enforcement\" — they are different outcomes with different caller obligations." — round history deleted; fact (different outcomes, different caller obligations) kept.

## M9-scheduler.md:89
"**NOOP-PACING (new this round, F9-9)**" — time marker deleted; F9-9 kept.

## M9-scheduler.md:102
"(sol B16)" after execution_projections row — attribution deleted; B16 kept.

## M9-scheduler.md:163
"(default + consequence, expanded this round — sol B15)" — marker + attribution deleted; converted to "expanded (B15)".

## M9-scheduler.md:178
"the two controls interact (sol B17)" — attribution deleted; B17 kept.

## M9-scheduler.md:194
"both are admission/execution controls, which round-6's \"none is an admission/execution-settlement control\" exclusion denied (**false**)." — round history deleted; fact (both are admission/execution controls) kept.

## M9-scheduler.md:200
"**Load correction (F9-3, re-derived this round).** Round-4 claimed the `[daemon]` / `[gateway]` / `[duckbrain]` root sections are \"not loaded until FEAT-005 wires `LoadConfig`\". **That is FALSE.**" — round history deleted; fact (sections load at boot; `config.LoadRootConfig` called ten times at `main.go:640,673,762,854,870,968,995,1023,1054,1309`) kept.

## M9-scheduler.md:216
"(round-9 re-grade: CT-01 is a boundary contract, not internal)" — round marker deleted; boundary-contract fact kept.

## M9-scheduler.md:219
"(internal, round-9 grok B3: round-8 labelled the producer \"external\")" — round history harvested; kept "(internal, B3)". Also "the builtin prompt text changed this round — it now instructs" → "the builtin prompt text instructs"; quoted prompt text ("read your own board with `board_read.py`", "unblock before you block") kept verbatim as system/prompt text.

## M9-scheduler.md:220
"the wire was not measured this round; … (sol B03)" — marker + attribution deleted; B03 kept.

## M9-scheduler.md:237
"**Env-contamination correction (F9-6).** Round-4 reported `go test ./...` FAIL with `SCHED-GAP-1726 goroutine census: 1 goroutine(s) still parked in evalDrain at suite exit`. That FAIL is an artifact of the writer's shell carrying the ambient `SCHEDULER_OPERATOR_RESTART_APPROVED=1`" — round attribution deleted; fact (env-contamination artifact; unset the var) kept.

## M9-scheduler.md:250
"**Semantics (B22, read this round):**" — marker deleted; B22 kept.

## M9-scheduler.md:258
"**Scope, stated (deepseek #1).**" — agent attribution deleted (no B-id on this note); scope fact kept.

## M9-scheduler.md:260
"= 382, measured this round — up from 379 at round 12; the 3 new sites are in the NOOP-PACING path" — round history deleted; count 382 and NOOP-PACING fact kept.

## M9-scheduler.md:286
"**Admission authority (B19, locator re-pinned this round).**" — marker deleted; B19 kept.

## M9-scheduler.md:314
"- Rev re-stamped: `6606f856`" — process wording converted to "- Revision: `6606f856`".

## M9-scheduler.md:323
"round-4's `go test ./...` FAIL was env contamination" — round marker deleted; finding kept.

## M9-scheduler.md:326
"**F9-8** (new, round 13)" — round marker deleted.

## M9-scheduler.md:327
"**F9-9** (new, round 13)" — round marker deleted.

## M9-scheduler.md:328
"**F9-10** (new, round 13)" — round marker deleted.

## M12-inference-proxy.md:12
Status field: "read in full this round (273 lines); … reproduced this round; … corrected this round (F12-8). **Streaming completion is FAILING (sol B22):**" — three time markers + sol attribution deleted; F12-8/B22 and all facts kept.

## M12-inference-proxy.md:28
"round-5 shipped two invented filenames here (F12-8), which is the exact \"what breaks if it lies\" failure for a paths register." — round attribution deleted; converted to "two invented filenames shipped in an earlier register revision (F12-8)".

## M12-inference-proxy.md:74
"**F12-8 (paths, corrected this round).** … Round-5 wrote `~/.hermes/logs/cf-usage.jsonl` (`:49`) and `~/.hermes/logs/cf-capture.jsonl` (`:50`) — neither exists." — round attribution deleted; locators `:49`/`:50` and nonexistence fact kept.

## M12-inference-proxy.md:78
"An operator following the round-5 register would open two files that are never written." — round marker deleted; consequence kept.

## M12-inference-proxy.md:95
CT-07 row: "the wire was not measured this round; … (sol B03)" — marker + attribution deleted; B03 kept.

## M12-inference-proxy.md:96
"(ERE, re-run this round)" — marker deleted. "Round-4's quoted command omitted `-E`, so its bare-`\|` BRE returned **0** matches (measured rc 1) — the opposite of the row's claim (grok 2 / glm 4)." — round + agent attributions deleted; measured fact (BRE without `-E` → 0 matches, rc 1) kept.

## M12-inference-proxy.md:99
"The round-3 M12-C1 producer cell (\"node POST /v1/chat/completions with Authorization: Bearer ***\") was a broken table row (an unclosed code span, a `***` redaction artifact, a pipe inside the cell) with an unnamed producer. It is replaced by the empty-grep proof above" — draft-history deleted; conclusion (client half unproven, UNVERIFIED) kept.

## M12-inference-proxy.md:106
"**Corrected (kimi B65):**" — agent attribution deleted; B65 kept.

## M12-inference-proxy.md:121
"reproduced by round-3 judge kimi (`:155-160`); **not re-run by this writer** — the node token file was not read" — round/agent attribution + writer phrasing deleted; 403-not-re-run fact kept.

## M12-inference-proxy.md:159
"The round-2/round-3 claim \"a 502 is returned only when the failure happens before the first byte\" conflates two distinct cases (B24)." — round markers deleted; correction + B24 kept.

## M12-inference-proxy.md:174
"**F12-7 (stream-completion defect, sol B28).**" — attribution deleted; B28 kept.

## M12-inference-proxy.md:181
"(sol B24)" after `PROXY_STREAM_EOF_COMPLETED=False: TimeoutError` — attribution deleted; B24 kept.

## M12-inference-proxy.md:184
"(sol B22)" after "demonstrated defect, not a merely unverified property" — attribution deleted; B22 kept.

## M12-inference-proxy.md:193
"(B25, sol)" — attribution deleted; B25 kept.

## M12-inference-proxy.md:202
"(re-confirmed this round — file unchanged, `wc -l` = 273)" — marker deleted; sha256 re-confirmation fact kept.

## M12-inference-proxy.md:221
"**F12-8** (new) — round-5 invented two sink filenames (`cf-usage.jsonl`, `cf-capture.jsonl`)" — round attribution deleted; converted to "an earlier register revision carried two invented sink filenames".

## Source: parts/IV-contract-register.md

## IV-contract-register.md:51
- **To close:** quote the encode site in `owner` and the decode/validate site in `scheduler`, then replace both RED lines with those citations.

## IV-contract-register.md:63
- **To close:** quote the encode site in `scheduler` and the decode/validate site in `crier`, then replace both RED lines with those citations.

## IV-contract-register.md:75
- **To close:** quote the encode site in `crier` and the decode/validate site in `node`, then replace both RED lines with those citations.

## IV-contract-register.md:87
- **To close:** quote the encode site in `node` and the decode/validate site in `crier`, then replace both RED lines with those citations.

## IV-contract-register.md:99
- **To close:** quote the encode site in `foreman` and the decode/validate site in `scheduler`, then replace both RED lines with those citations.

## IV-contract-register.md:111
- **To close:** quote the encode site in `crier` and the decode/validate site in `scheduler`, then replace both RED lines with those citations.

## IV-contract-register.md:123
- **To close:** quote the encode site in `router` and the decode/validate site in `gateway`, then replace both RED lines with those citations.

## IV-contract-register.md:135
- **To close:** quote the encode site in `crier` and the decode/validate site in `gateway`, then replace both RED lines with those citations.

## IV-contract-register.md:147
- **To close:** quote the encode site in `node` and the decode/validate site in `duckbrain`, then replace both RED lines with those citations.

## IV-contract-register.md:159
- **To close:** quote the encode site in `node` and the decode/validate site in `board`, then replace both RED lines with those citations.

## IV-contract-register.md:171
- **To close:** quote the encode site in `node` and the decode/validate site in `sessionstore`, then replace both RED lines with those citations.

## IV-contract-register.md:183
- **To close:** quote the encode site in `node` and the decode/validate site in `gitreins`, then replace both RED lines with those citations.

## IV-contract-register.md:195
- **To close:** quote the encode site in `gitreins` and the decode/validate site in `board`, then replace both RED lines with those citations.

## IV-contract-register.md:207
- **To close:** quote the encode site in `foreman` and the decode/validate site in `board`, then replace both RED lines with those citations.

## IV-contract-register.md:219
- **To close:** quote the encode site in `foreman` and the decode/validate site in `duckbrain`, then replace both RED lines with those citations.

## IV-contract-register.md:231
- **To close:** quote the encode site in `docsgate` and the decode/validate site in `handbook`, then replace both RED lines with those citations.

## IV-contract-register.md:240
- **Measured defect:** not run this round (needs a live node); vars and memory had no executor (CF-328) (M5 §6)

## IV-contract-register.md:243
- **To close:** quote the encode site in `conformance` and the decode/validate site in `harness`, then replace both RED lines with those citations.

## IV-contract-register.md:255
- **To close:** quote the encode site in `handbook` and the decode/validate site in `owner`, then replace both RED lines with those citations.

## IV-contract-register.md:267
- **To close:** quote the encode site in `node` and the decode/validate site in `proxy`, then replace both RED lines with those citations.

## IV-contract-register.md:279
- **To close:** quote the encode site in `proxy` and the decode/validate site in `gateway`, then replace both RED lines with those citations.

## IV-contract-register.md:291
- **To close:** quote the encode site in `github` and the decode/validate site in `node`, then replace both RED lines with those citations.

## IV-contract-register.md:303
- **To close:** quote the encode site in `node` and the decode/validate site in `crier`, then replace both RED lines with those citations.

## IV-contract-register.md:315
- **To close:** quote the encode site in `provisioner` and the decode/validate site in `bunker`, then replace both RED lines with those citations.

## Source: chapters/M10-crier.md (direct edits, wave-8 lead)

## chapters/M10-crier.md:9
crier repo HEAD, re-stamped round 13 → "crier repo HEAD" (round stamp dropped)

## chapters/M10-crier.md:10
re-measured this round: /usr/bin/go version → measured: /usr/bin/go version

## chapters/M10-crier.md:12
`cmd/crier-front/main.go` read this round → read (round marker dropped)

## chapters/M10-crier.md:37
Custody lifecycle (B20, written this round) → Custody lifecycle (B20)

## chapters/M10-crier.md:80
Individual rows (B21, expanded this round) → Individual rows (B21)

## chapters/M10-crier.md:96
evidence (sol B20) → evidence (B20)

## chapters/M10-crier.md:114
(B20, sol — expanded with the memory backend, sol B19) → (B20; memory backend B19)

## chapters/M10-crier.md:123
"This supersedes OUTLINE Part IV's ... README I.3's '10 works / 6 broken / 2 missing'" (glm #2) → attribution (glm #2) dropped, claim kept

## chapters/M10-crier.md:126
(round-9 correction: round-8 called the producer "external", which was false) → (an earlier citation wrongly marked the producer "external")

## chapters/M10-crier.md:141
Assurance-gap note (kimi 6, re-measured). Round-3 reported `internal/registry` as "no tests to run". → Assurance-gap note (re-measured). An earlier audit recorded `internal/registry` as "no tests to run".

## chapters/M10-crier.md:146-158
`go test` flakiness (kimi 3, re-measured this round); round 12 (HEAD `86c4c469`) saw a fresh ... FAIL; kimi round-10 reproduced ...; This round (HEAD `ae9fc57f`) one fresh full run passed clean; changed since the round-12 stamp; ran green this round → all round/kimi markers converted to HEAD-revision and measurement phrasing; finding ids and all timings kept

## chapters/M10-crier.md:164
Inventory scope (grok #7, corrected this round) → Inventory scope (corrected)

## chapters/M10-crier.md:197-198
The round-5 "non-exhaustive" hedge is withdrawn with this measured count (deepseek #3) → An earlier "non-exhaustive" hedge is withdrawn with this measured count

## chapters/M10-crier.md:207
Guard log surface (B22, sol) → Guard log surface (B22)

## chapters/M10-crier.md:236
live listener status is unmeasured this round → unmeasured

## chapters/M10-crier.md:255
Rev stamped: ae9fc57f → Rev: ae9fc57f

## chapters/M10-crier.md:259
(re-measured; was 1.26.9 at round 12) → (re-measured; an earlier measurement recorded 1.26.9)

## chapters/M10-crier.md:266
F10-6 (new, round 13) → F10-6; "changed since the stamp" → "changed since the earlier measurement"

## parts/M6-documentation.md:186 (via lead)
The fill/render pipeline → The chapter-fill and render stages of the build pipeline

Note: IV-contract-register.md was rewritten by a concurrent reconcile wave after the first
pass; the 23 "To close" bullets and one "this round" marker were re-removed from the
reconciled version (2026-11-07 18:07). Bullets above are from the original harvest.
