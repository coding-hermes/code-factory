# CORRECTIONS — round 1

Generated 2026-11-06T16:00:47-0500.

## Verdicts

- **deepseek** — FAIL, blocking 8, 8162 bytes, complete=True
- **glm** — FAIL, blocking 7, 10932 bytes, complete=True
- **grok** — FAIL, blocking 9, 12207 bytes, complete=True
- **kimi** — FAIL, blocking 7, 10685 bytes, complete=True
- **sol** — FAIL, blocking 28, 26551 bytes, complete=True

## Verdict text (verbatim, per seat)

### deepseek

```
All verification complete. Here is the verdict.

---

VERDICT: FAIL

BLOCKING: 8

NON-BLOCKING: 6

FINDINGS:

1. FALSE CLAIM — M11 (and the schema it copies). `docs/MASTER-DOC-SCHEMA.md` §7 and M11 §7 both claim "OPEN — `dispatch_leg.go:438-454` checks only `ok:false`". Measured: `internal/scheduler/dispatch_leg.go:438-454` is the uncorrelated-inbox-residue settling block (`settleDispatchInboxResidue`, `stats.Uncorrelated++`). The `ok:false` check is at `dispatch_leg.go:714` (`if v, ok := payload["ok"].(bool); ok && !v {`). The field contract's own worked example carries a wrong line citation, and M11 inherits it verbatim. Fix: re-cite the true line, and correct the schema first so no downstream chapter copies the wrong locator.

2. FALSE CLAIM — M0 §2/§4. "Twenty scripts source lib.sh; seventeen measured directly by `grep -rl '\. "$HERE/lib.sh"\|source.*lib.sh' scripts/` (17 matches)". Measured: that exact command returns 11 files. The six `scripts/harness/install-*.sh` source via `. "$HERE/../lib.sh"`, which the pattern misses. The true source count is 17 (11 in `scripts/` + 6 in `scripts/harness/`), so the number is coincidentally right, but the quoted command does not reproduce it and "twenty" is flat wrong. Rule 1 and rule 4 both broken. Fix: state the two-part grep (`$HERE/lib.sh` and `$HERE/../lib.sh`) or a glob, and delete "twenty".

3. OMISSION — control-plane modules are skeletons, reproducing the v1 rejection. M9 (scheduler), M10 (crier), M11 (dispatcher), M12 (inference proxy) each say "no source read this round", have empty 3b tables ("RED — not read"), and verification is only `ls` / `wc -l`. The v1→v2 correction's whole point was that these four must be documented as systems, not contract-table entries; they are still contract-table entries with a reachability check. M9/M10/M11/M12 are not WRITTEN.

4. OMISSION — the Settings Register is absent from all 13 chapters. Outline heading #5 and Part V commit to "~83 env vars, ~215 CLI switches, timeouts, caps, floors, rates", each with default + range + what breaks. Zero chapters contain a settings register; the 3a tables list runtime deps, not governed settings. Rule 3 (consequence) is unmet document-wide.

5. OMISSION — three corrected outline headings are missing from every chapter: #3 submodule inventory with active/optional/legacy/designed-not-built classification (no chapter classifies its submodules), #11 limits and margins, #12 cross-references. The chapters implement the older 8-field SCHEMA shape, not the corrected 13-heading OUTLINE shape. The two authoritative structures disagree and the chapters followed the wrong one.

6. CONTRADICTION (rule 2) — every 3c service-contract table names a peer, a direction, and a payload shape, but no contract names both producer and consumer as file:function. Outline §IV states "0 of 18 name both implementations"; the chapters do not advance this. Example: M2 3c "crier | in | HTTP inbox read + lease | envelope run_id…" names neither `crier_client.py`'s function nor the server handler. One side of every contract is still a rumour.

7. UNVERIFIED — stale and uncommitted revision stamp. All 13 chapters stamp revision `f0ca317e96ac0616e2c92514ee99e5755ce734d2`, but the repo HEAD is `943ef984dc093e5780605ac6e54cd043122126ef` (f0ca317 is its parent), and the chapters are untracked (`?? docs/handbook/chapters/`). The schema requires "one revision per document issue" and a dated last run; the whole document is stamped one commit behind HEAD and not committed.

8. FALSE CLAIM — M0 §8 lists "board rows CF-105 (digest), CF-109 (disk floor)". Measured: `jq 'select(.id=="CF-105" or .id=="CF-109")'` returns nothing. CF-105 and CF-109 are not row ids; they appear only as ticket numbers in `lib.sh` comments (lines 15, 47) and in another row's body text. Two of the four "evidence of record" board rows do not exist as rows. (CF-280 and CF-229 are real rows.)

NON-BLOCKING findings:

9. Metrics RED in all 13 chapters — disclosed, and "none" is the honest answer for the node scripts, but M9/M10/M12 write "unverified" instead of measuring whether the scheduler/crier/proxy actually emit metrics (OUTLINE names scheduler HTTP/dashboard metrics and M12.S4 "usage and request capture"). A claim of "none" must be a measurement, not an absence of measurement.

10. CONTRADICTION — M11 §1 states runtime "Python 3.11 (per schema worked example)" while M1/M2/M4/M5/M6/M7/M8 all state "Python 3.14.9 (measured)". The dispatcher's runtime is unmeasured and the document gives two different host Pythons without resolving which applies.

11. FALSE/OMISSION — M9 §8 lists `scheduler.db` as evidence of presence; measured it is a 0-byte file (2026-11-06 14:13). OUTLINE M9.S3 claims 26 tables. Presence is not the same as a populated durable store; the chapter should say so.

12. IMPRECISION — M5 §6 quotes the log line "installed %s but the pin is %s" for `install-gitreins.sh:105`; the actual line is `bad "install" "installed ${ver:-nothing} but the pin is $PIN (log $log)"`. Verbatim rule broken (minor).

13. CONTRADICTION (self-disclosed, unresolved) — UNIT-MAP.yaml disagrees with OUTLINE v2 on submodule counts for M5 (3 vs 5), M6 (6 vs 8), M8 (2 vs 3). The chapters flag it; nothing reconciles the two structure maps, so a reader cannot tell which submodule inventory is authoritative.

14. OMISSION (in-scope) — `scripts/ownership.py` exists (added in the HEAD commit, "ownership tooling") and has no home in any chapter or submodule inventory. Per the outline's scope rule it should be classified, not orphaned.

DEFECT CLASSES:

STALE-REVISION · SKELETON-CONTROL-PLANE · MISSING-SETTINGS-REGISTER · MISSING-HEADINGS · ONE-SIDED-CONTRACTS · FALSE-COUNT · FALSE-LINE-CITE · GHOST-BOARD-ROWS · VERSION-DISAGREEMENT

CHAPTER SCORECARD:

- M0 shared-contract — PARTIAL. lib.sh and harness-vars.sh read in full, line refs verified accurate (lib.sh:6/7/8, 19-42, 48-57, 75-78; harness-vars:34/66/157-159 all check out), but the source count is a false claim and CF-105/CF-109 are ghost rows.
- M1 provisioning — PARTIAL. Structure mapped, concrete defects named (CF-192/224/379), but status UNVERIFIED and no script body read line-by-line.
- M2 dispatch — PARTIAL. Module structure verified, but the 1498-line node-bus-worker.py is unread; both bus contracts are "broken" with no both-sides file:function.
- M3 repository — PARTIAL. The best-evidenced node chapter: land-node-branch.sh (295 lines) and the gate fully read, every cited line verified (:8-9, :22-24, :53-58, :91-93, :167, :214, :231, :265, :282-283, :291, :294). Still missing settings register and classification.
- M4 board — PARTIAL. Store verified at 357 rows / 515 events (both match), but boardctl verb surface unread.
- M5 harness — PARTIAL. harness-vars.sh verified; installer bodies and harness_resolve.py unread; UNIT-MAP/OUTLINE submodule split unresolved.
- M6 documentation — PARTIAL. panel_loop.py verified; the doc gate itself is FAILING (CF-374, PASS over 0 modules) and the chapter honestly records it.
- M7 github — SKELETON. No body read; verification is parse-only.
- M8 safety — SKELETON. No body read; verification is parse-only.
- M9 scheduler — SKELETON. No source read; `ls` only; 6 RED fields.
- M10 crier — SKELETON. No source read; `ls` only; 6 RED fields.
- M11 dispatcher — SKELETON. No source read; inherits the schema worked example, whose own line citation is false (finding 1).
- M12 inference-proxy — SKELETON. `wc -l` only; 5 RED fields.

Bottom line: the node-side chapters (M0-M6) are real progress and mostly accurate where they cite code, but the document as a whole is not written. The four control-plane modules — the exact gap four seats named in v1 — are still skeletons with `ls`-level evidence, no chapter satisfies the settings register or the both-sides contract rule, and the field contract itself carries a false line citation that is propagating into the chapters. 0 of 13 chapters are WRITTEN.

PANEL REVIEW COMPLETE

session_id: local-7a7383bee35d7025fc6d79b7529620441d290f11f2b5c922339221d51fb81224

EXIT=0
```

### glm

```
VERDICT: FAIL

BLOCKING: 7 — findings that must be fixed before the affected chapters can be called written
NON-BLOCKING: 6

FINDINGS:

BLOCKING

1. FALSE CLAIM — M3 §7
   Claim quoted: "`clone_lane --to == --from` | rewrites the SOURCE lane row | a safe clone | **OPEN** — CF-357"
   Evidence: code refuses before any write — scripts/clone_lane.py:38-45 (`refuse_same_lane`) called at :65-68 ("CF-357: refuse BEFORE sqlite3.connect"); board row CF-357 status is `complete` (tasks.jsonl, measured). The defect is fixed and closed; the chapter calls it open.
   Fix: move CF-357 from the OPEN failure-mode row to evidence of record, citing clone_lane.py:38-45 and the `complete` board status.

2. FALSE CLAIM (stale measurement presented as current) — M6 §4, §7
   Claim quoted: "doc gate over real modules … **FAILING** — CF-374: prints PASS over 0 modules"
   Evidence: re-run this round: `python3 scripts/master_doc_check.py` → "44 module(s): 37 VERIFIED, 50 error(s)… MASTER-DOC: FAIL", exit 1. The PASS-over-0 mechanism no longer exists — DEFAULT_ROOTS falls back to docs/handbook/appendices/units (master_doc_check.py:52). The status word FAILING is accidentally right; the stated reason is wrong (the real failure is 50 locator errors naming nonexistent docs/master paths).
   Fix: re-run the gate, record the actual output and exit code, reword the failure mode to the current defect (stale locators into the deleted docs/master root).

3. UNREPEATABLE COMMAND + FALSE COUNT — M0 §4, §2
   Claim quoted: "who sources it | `grep -rl '\. "$HERE/lib.sh"' scripts/` | >= 17 files | PASS (17)" and "Twenty scripts source lib.sh"
   Evidence: the quoted command yields 11 (measured). 17 is the true count only including the six harness files that source `$HERE/../lib.sh`: `grep -rlE '\. "\$HERE/(\.\./)?lib\.sh"' scripts/` → 17 (measured). "Twenty" is the .sh file count (bash -n sweep), not the source count.
   Fix: correct the pattern in the verification row and the sentence in §2 to the measured 11+6=17.

4. OMISSION (prescribed headings absent) — all chapters M0–M12
   Claim quoted: OUTLINE Part III prescribes 13 headings per chapter; every chapter implements only the SCHEMA's 8 fields.
   Evidence: no chapter contains a submodule inventory with active/optional/legacy classification backed by invoking file:line (heading 3), a settings register with default/range/consequence (heading 5), limits and margins (heading 11), or a cross-reference section (heading 12). The chapters satisfy MASTER-DOC-SCHEMA.md but not the outline's own buildability row ("Headings per chapter … 13").
   Fix: either extend each chapter with the four missing sections or obtain an explicit quorum ruling that the 8-field schema supersedes the 13-heading list — as written, no chapter can be called WRITTEN under the outline.

5. NAME ONLY — M0/M5 (the CF_* variable contract)
   Claim quoted: M0 §1 claims harness-vars.sh "VERIFIED (318 lines read in full)"; outline M5.S5 names the variable contract a submodule.
   Evidence: harness-vars.sh (318 lines, measured) has no settings register in any chapter and no appendix — `ls docs/handbook/appendices/units/ | grep harness-vars` → empty; CF_MODEL/CF_PROVIDER appear only incidentally inside installer/specs appendices. Per the outline's decision rule ("a name with no consequence is NAME ONLY and counts as unwritten"), the most load-bearing settings surface in the repo is unwritten.
   Fix: write the CF_* register (default, range, what breaks) into M0/M5 or a dedicated unit appendix.

6. ONE-SIDED CONTRACT — M2 §3c
   Claim quoted: "crier | in | HTTP inbox read + lease | envelope `run_id, corr_id, lane, board_row, text_b64` | **broken** — see CF-354 below"
   Evidence: the row names neither producer nor consumer file:function. Both sides exist and verify: producer internal/bus/dispatch.go:202 (`p["text_b64"] = base64.StdEncoding.EncodeToString([]byte(w.Text))`), consumer scripts/node-bus-worker.py:986 (`text = dispatch.get("text")`; zero `text_b64` hits in the file). One side is a rumour; here neither side is named.
   Fix: put both locators in the contract row.

7. CLAIM WITHOUT LOCATOR — M9 §2, §7
   Claim quoted: "A scheduler that records a pass for a `status:\"failed\"` reply is the control-plane half of the silent-success defect (CF-355: it never reads the 12 result fields)"; §8: "No commands were run against the scheduler source this round."
   Evidence: the mechanism is real and I verified it — internal/scheduler/dispatch_leg.go:713-725, `dispatchReplyVerdict` reads only `payload["ok"]`; no `status` read exists in the file — but the chapter asserts the fact while citing only a board row. Per rule 1 the claim is UNVERIFIED as written.
   Fix: add dispatch_leg.go:713-725 (and dispatch.go:202 for CF-354) to the chapter, or explicitly mark both as inherited-unverified claims.

NON-BLOCKING

8. CONTRADICTION — handbook README (not a chapter)
   Claim quoted: README.md:71 "Every chapter here is currently **EVIDENCE ONLY**", 10 flows, 9 modules/25 submodules.
   Evidence: OUTLINE.md (v4, accepted round 4, commit 1983899) has 16 flows, 13 modules, 34 submodules; docs/handbook/chapters/ contains 13 chapters. The ToC misdirects every reader who enters through it.
   Fix: regenerate the README at the end of this round.

9. CENSUS LAG — all chapters
   Evidence: chapters stamp f0ca317; HEAD is 943ef98 ("ops: ownership tooling"), which adds scripts/ownership.py (170 lines) — no chapter, no appendix, no census entry. The py_compile sweep is now 32 files, not the claimed 31 (31 was correct at the stamped revision). Honest stamping, one commit behind.
   Fix: re-stamp the issue at HEAD and re-run the two sweeps before merge.

10. UNMEASURED REPEAT — M4 §3b
    Claim quoted: "21 verbs: create, update, validate, doctor, stats (UNIT-MAP M4.S1)"
    Evidence: cited to UNIT-MAP.yaml:129-130, a derived map; the boardctl wrapper delegates to an external executable and the chapter honestly marks the verb surface UNVERIFIED. Not false — carried on borrowed authority.
    Fix: count the verbs from the executable when M4 closes.

11. UNMEASURED REPEAT — M9 §8
    Claim quoted: "durable state 26 tables" (repeated from OUTLINE M9.S3)
    Evidence: not measured by the writer and not verified by this seat (one sqlite3 probe returned nothing usable). Inherits the outline's number.
    Fix: `sqlite3 scheduler.db '.tables' | wc -w` and record it.

12. NOT REPEATABLE FROM THIS HOST — M2 §4, M10 §4
    Claim quoted: "`python3 ~/node-bus-worker.py --check` on cf-node" (FACT-04)
    Evidence: node-side check; correctly dated 2026-11-05 and attributed to _facts.md. Per rule 4, stated: I could not repeat it from the control host.

13. OBSERVATION — M9–M12 evidence rot
    Evidence: during this review internal/scheduler/dispatch_leg.go was transiently unreadable (present, then absent, then present); the scheduler repo HEAD moved to dfa9c84f mid-session — a live lane is committing there. The chapters' decision not to stamp external repos is correct; any locator written into them must carry the external repo's own HEAD when added.

DEFECT CLASSES:
STALE-MEASUREMENT-PRESENTED-AS-CURRENT · UNREPEATABLE-VERIFICATION-COMMAND · FIXED-DEFECT-CALLED-OPEN · ONE-SIDED-CONTRACT-ROW · CLAIM-WITHOUT-LOCATOR · PRESCRIBED-HEADING-ABSENT · NAME-ONLY-SETTINGS · TOC-DRIFT · CENSUS-LAG · BORROWED-AUTHORITY-COUNT

Verified correct this round (for the record): lib.sh line refs exact (:6-8, :19-42, :24-27, :26, :48-57, :75-78; 78 lines); harness-vars.sh refs exact (:34, :66, :157-159; 318 lines); land-node-branch.sh refs exact (:8-9, :53-58, :91-93, :167, :214, :231, :265-283, :282, :291, :294; 295 lines); install-gitreins.sh refs exact (:12-14, :53, :105, :120-139, :130-132; 180 lines); .gitleaks.toml 48 lines; scripts/hooks/ genuinely absent (M3's outline correction stands); board 357 rows / 515 events exact; 20/20 bash -n and 32/32 py_compile pass; Python 3.14.9 / bash 5.3.9 / go1.26.5 all match the "measured" claims; CF-354 verified on both sides (dispatch.go:202 vs node-bus-worker.py:986); CF-355 mechanism verified (dispatch_leg.go:713-725); M3's supersession of QA-CODE-FACTORY-2 reproduced (repo_freshness emits `PASS <name> — lag 2, ahead 0` at rc=0 under --bound 5 and refuses rc=1 beyond bound; the live RED selftest case is arm 51 — ruff over tracked py: "Found 1 error"); M10/M11/M12 identity rows all check (crier clients/python+typescript, Dockerfile.mcp, coverage*.out; crier-fleet dispatcher text_b64 fallback at dispatcher.py:142-148; proxy 273 lines, mtime 2026-11-05); all 42 cited appendix files exist; FACT-03/04/08/10 present with sources; 00-INDEX.md:87-89 matches M6's quote; UNIT-MAP M5=3 vs OUTLINE=5 (M5's own finding is correct); outline §IV arithmetic 18=10+6+2 checks; all 25 sampled board rows exist (only CF-357's status contradicts its chapter).

CHAPTER SCORECARD:

M0  — PARTIAL. Line-accurate and honestly RED, but its central verification command does not reproduce (11 vs 17) and it owns half of a CF_* contract that is registered nowhere (findings 3, 4, 5).
M1  — PARTIAL. Honest UNVERIFIED status, structure verified, sweeps pass; missing classification and settings sections (finding 4).
M2  — PARTIAL. Every OPEN failure-mode row (CF-354/355/356/358/359) verified true against code and board; blocked by the one-sided envelope contract row (finding 6).
M3  — PARTIAL. Strongest chapter: all line citations exact, QA-CODE-FACTORY-2 supersession independently reproduced; blocked only by the stale CF-357 OPEN (finding 1).
M4  — PARTIAL. Store counts exact, lock/drift honesty intact; verb surface counted on borrowed authority (finding 10).
M5  — PARTIAL. Structure-disagreement finding correct, installers verified; owns the harness surface with no settings register (findings 4, 5).
M6  — PARTIAL. Pipeline compiled and census quotes exact, but its headline verification row describes a failure mode that no longer exists (finding 2).
M7  — PARTIAL. Thin but honest: bodies unread, self-declared, no false claims found.
M8  — PARTIAL. Same shape as M7; open defects (CF-290/341/368) confirmed pending on the board.
M9  — SKELETON. Self-declared RED is accurate: no scheduler source read; central claims carried without locators (finding 7); repo/structure/runtime claims all check.
M10 — SKELETON. Externals verified (clients/, ports per outline, coverage files) but no crier source read; client-library gap correctly named.
M11 — SKELETON. Leans entirely on the schema worked example (rev 98eb5ce) and prior-round test dates (2026-11-04); own body unread this round — honestly labelled.
M12 — SKELETON. wc -l and mtime only; every substantive field RED, accurately.

PANEL REVIEW COMPLETE

session_id: local-9831578d4c017c8fabaf842370603fddeca19adc625bf480d61b8e7c4840cc48

EXIT=0
```

### grok

```
⚠️  Primary auth failed — switching to fallback: fireworks / accounts/fireworks/models/deepseek-v4p1-flash-1017
VERDICT: FAIL
BLOCKING: 9 — findings that must be fixed before this chapter can be called written
NON-BLOCKING: 8

FINDINGS:

1. FALSE CLAIM — M6 — "doc gate over real modules … **FAILING** — CF-374: prints PASS over 0 modules"
   Evidence: measured `python3 scripts/master_doc_check.py` at HEAD (943ef98, one commit past the stamped f0ca317, diff touches no `scripts/` file) → `44 module(s): 37 VERIFIED, 50 error(s)`, `MASTER-DOC: FAIL`, real rc=1. The 0-module root was fixed: `DEFAULT_ROOTS = ("docs/master", "docs/handbook/appendices/units")` (`scripts/master_doc_check.py:52`). Board row CF-374 status is **complete** (`updated_at 2026-11-06T09:34:46Z`), six hours before the chapter was stamped 15:48.
   Fix: restate §4 as "exits 1 over 44 modules with 50 locator errors", and file the 50 locator errors as the live gate defect.

2. CONTRADICTION — M6 — §4/§7 call CF-374 open while §8 of the same chapter reads "Board rows: CF-360, CF-374 (complete), CF-381."
   Fix: one status per row per chapter; re-derive from `boardctl show CF-374` at write time.

3. FALSE CLAIM — M3 — "`clone_lane --to == --from` … **OPEN** — CF-357"
   Evidence: CF-357 is **complete** on the board; the guard ships — `refuse_same_lane` at `scripts/clone_lane.py:38-45`, called at `:65-68` *before* `sqlite3.connect`, message `REFUSED: --to and --from are the same lane`.
   Fix: delete the OPEN row; cite `clone_lane.py:38-45` as the shipped refusal.

4. FALSE CLAIM — M11 — "Language / runtime | Python 3.11 (per `docs/MASTER-DOC-SCHEMA.md` worked example)"
   Evidence: `head -3 /home/kara/crier-fleet/dispatcher.py` → docstring reads `Python 3.14.9`; host `python3` is 3.14.9. The chapter derived a runtime fact from another document and got it wrong, then admitted in §8 "no dispatcher source commands were run this round beyond `ls`."
   Fix: measure the interpreter; never carry a runtime from a prose example.

5. OMISSION (13/13 chapters) — zero `file:function` references anywhere. Measured `fn_refs=0` for every one of M0–M12; line refs are module-local only (M3 8, M0 11) and M9/M10/M12 have **0**. Every cross-module contract in the document is therefore a rumour by rule 2: e.g. M2 §3c names `in_reply_to, corr_id, run_id, outcome` with neither side's function; M11 §3c names payload fields and "scheduler decodes `reply_b64`" with no file.
   Fix: every service-contract row gets producer `file:function` and consumer `file:function`.

6. OMISSION — M9, M10, M12 (and M7, M8) — chapters about the systems are written with no code read; contract states are copied from the outline. M9 §3c/§7, M10 §3c, M6 §3c, M4 §3c literally cite "(OUTLINE §IV)" as the evidence for a measured state word.
   Evidence: M9 "no scheduler source read this round", verification row is `ls`; M10 likewise. I measured in one command what M10 declares unread: default port 8767 at `/home/kara/crier/config/config.go:622`, front 8770 at `/home/kara/crier/cmd/crier-front/main.go:39`. The outline's "scheduler.db, 26 tables" is also false: the live store has **30** tables (`/home/kara/.hermes/coding-hermes/scheduler.db`, 16.87 GB) and carries **no** `verdicts` table; the in-repo `scheduler.db` M9 lists in its path table is 0 bytes / 0 tables.
   Fix: read each system's entry points; stamp a revision; stop sourcing state words to the outline.

7. FALSE CLAIM — M0 — verification row "who sources it | `grep -rl '\. "$HERE/lib.sh"' scripts/` | >= 17 files | PASS (17)"
   Evidence: that exact command returns **11** files. The 17 count is real but comes from a different query: 11 × `. "$HERE/lib.sh"` plus 6 × `. "$HERE/../lib.sh"` in `scripts/harness/`. The prose compounds it: "Twenty scripts source `lib.sh`; seventeen measured directly" — three numbers, one sentence, none matching the quoted command.
   Fix: quote the command that yields the number (`grep -rn 'lib\.sh' scripts/ | grep -cE ':[0-9]+:\s*(\.|source)'`).

8. FALSE CLAIM (phantom evidence) — M0 cites board rows CF-105 (digest) and CF-109 (disk floor) in §2, §7 and §8. Neither id exists: `boardctl show CF-105` → "task not found (searched tasks.jsonl and fixtures.jsonl)". The behavioural claims are true (`lib.sh:19-42`, `:48-57`), but the record they lean on is invented.
   Fix: cite the code lines, or the real ids.

9. UNBUILDABLE — the document implements 8 schema sections and **0** of the 13 mandated chapter headings. Union of headings across all 13 files is exactly `1. Identity … 8. Evidence of record`. Missing everywhere: Submodule inventory with active/optional/legacy/designed-not-built classification (`designed-not-built` appears **0** times in all 13 files), Settings register (`grep -il 'settings\|env var\|default value'` → **no match in any chapter**), Limits and margins, Cross-references. Parts I, II (16 flows), IV (18 contracts), V (~83 env vars, ~215 switches), VI, VII, VIII have no chapter at all.
   Fix: the 13 headings are the acceptance gate; a chapter missing four of them is not a chapter, and PART V has no home in the whole document.

NON-BLOCKING:

10. FALSE CLAIM — M4 — "21 verbs: create, update, validate, doctor, stats". `boardctl --help` lists **20** (`init list show next-id create update event header validate sweep-status normalize-statuses normalize-board doctor version stats render import serve install umbrella`). `doctor` and `stats` do exist (rc=0), so only the count is wrong. The row/event counts are exact: 357 rows, 515 events — also what `boardctl doctor` reports.
11. OMISSION — M1's central "what breaks if it lies" is true and uncredited: the node probe tests non-emptiness only (`[ -s "$HOME/.node/auth/github.token" ]`, `scripts/bunker-provision.sh:214`) while the row printed at `:233` claims "token file installed, **mode 600**". The chapter cites a panel JSON and a board id, never those two lines.
12. PADDING/OMISSION — M12 declares 5 RED fields over a 273-line file that answers them. It says "The proxy has no contract" while the file carries a CONTRACT section at `cf-inference-proxy.py:9-19` (three routes, Bearer token, "no anonymous path and no fallback"); §3a names one runtime dep (python3) when the code fails closed on a token file (`:265-267`), a missing `API_SERVER_KEY` (`:268-270`), `MAX_BODY` 4 MiB, a 300 s upstream timeout and an `ALLOWED_MODELS` allowlist defaulting to `hermes` (`:60-62`). §4's "admission/routing → UNVERIFIED" is a curl away (`:155-160` returns 403).
13. OMISSION — Metrics are RED in 13/13 chapters (§5 of each). For M9/M10/M12 "unverified" is a confession, not a measurement: the proxy emits no counters but does append structured usage/capture JSONL with `ts, node, model, status, bytes, secs, first_byte` (`:98-101`, `:220-223`).
14. PADDING — M4 §7 "Sibling row reversion … normalize the sibling's stale copy after a supersession (memory)": citing the author's memory as a document evidence class. Same pattern in M0 (panel JSON), M9/M10 ("(OUTLINE §IV)").
15. OMISSION — M3's dry-run row and M5's two rows, M1's disk-floor row, M2's `test_lane_target.py`, M7's mint, M8's reclaim unit, M8/M4's drift all sit at "not run this round | UNVERIFIED" while the fixtures exist and are cheap (`tests/test_disk_floor.py`, `tests/test_lane_target.py`, `tests/test_reclaim.py`, `tests/harness-conformance.sh` all present).
16. UNVERIFIED (repeatability, rule 4) — I could not repeat four cited checks: `python3 ~/node-bus-worker.py --check` on cf-node (M2 §4, M10 §4 — no route from here to that node, and it is offered as evidence of *crier*, which is proxy evidence), the full `tests/selftest.sh` 4,591-line battery behind M3's "arm 41 12/12" and arm-51 claims (I confirmed the FAIL string exists verbatim at `tests/selftest.sh:4334` and the arm title at `:4300`, but did not run the battery), `go test ./...` in crier and scheduler (M9/M10), and M11's three "PASS (prior round)" rows, which are 2026-11-04 results lifted from the schema worked example.
17. M5 §8 honestly files a real contradiction — UNIT-MAP gives M5 three submodules, the outline gives five. Good practice; it should be a board row, not a parenthetical. M3's two "finding filed this round" blocks (no `scripts/hooks/`, QA-CODE-FACTORY-2 misdiagnosed) are the strongest writing in the set.

DEFECT CLASSES:
- stale-board-cite (row completed, chapter still says OPEN)
- self-contradicting-status (same row both open and complete in one chapter)
- derivation-from-document-not-code (runtime from a schema example; contract state from the outline)
- one-sided-contract (no file:function on either side)
- unread-module (system chapters with zero source read)
- phantom-evidence (board ids that do not exist)
- broken-reproduction (quoted command does not yield the quoted number)
- count-drift (21 vs 20 verbs; 26 vs 30 tables; 20/17/11 lib.sh sources)
- self-inflicted-RED (small file left unread, then declared unverifiable)
- memory-as-evidence
- mandated-heading-absent (settings register, submodule classification, limits, cross-refs)
- unrun-fixture (cheap test present, row left UNVERIFIED)

CHAPTER SCORECARD:

M0 — PARTIAL. Eight sections, `lib.sh` genuinely read and cited accurately (`:6/:7/:8`, `fetch_verified:19-42`, `require_disk:48-57`, `bunker_exec:75-78`, `harness-vars.sh:34/:66/:158` all verified); one verification row that does not reproduce (11, not 17), two phantom board ids, metrics RED, no settings register.

M1 — PARTIAL. Claims hold against code, including the mode-600 lie at `bunker-provision.sh:214/:233`; status UNVERIFIED is honest; disk-floor row unrun; no settings register; the `NODE_DISK_FLOOR` precedence is a NAME with no default, range or consequence.

M2 — PARTIAL. Core defect is true and sharp (`node-bus-worker.py:986` reads `text`, refuses without it at `:990`, and `text_b64` appears nowhere; 1,498 lines confirmed); but the failure table carries board ids where the brief demands `file:line`, and the `--check` row cannot be repeated off cf-node.

M3 — PARTIAL. The best-evidenced chapter: `:8-9`, `:53-58`, `:91-93`, `:167`, `:214`, `:231`, `:268-283`, `:291`, `:294` all land exactly; `install-gitreins.sh:53/:105/:120-139/:130-132` exact; `.gitleaks.toml` line count correct. Blocked by the CF-357 false claim in a module it admits it did not read.

M4 — PARTIAL. Counts exact (357/515, corroborated by `boardctl doctor`), store topology verified, but the verb count is off by one, the failure table cites memory, and metrics RED.

M5 — PARTIAL. Submodule and installer inventory correct (six installers incl. the two v1 omitted); no installer body or `harness_resolve.py` read; two UNVERIFIED rows; the UNIT-MAP/outline submodule-count contradiction is a real find.

M6 — PARTIAL. Sections complete and `panel_loop.py` (305) read, but its central verification row is a false claim about a fix that had already landed, contradicted by its own §8, and it omits the gate's actual 50-error state.

M7 — SKELETON. Three scripts, none read; every claim traced to `docs/UNIT-MAP.yaml`; single-line log table; metrics RED.

M8 — SKELETON. Two scripts, none read; claims traced to UNIT-MAP; the `reclaim_disk.py` age-gate claim is a board assertion, not a code reading.

M9 — SKELETON. Zero scheduler source read; contracts and failure modes restated from the outline; verification is `ls`; the named `scheduler.db` is a 0-byte file; six RED fields.

M10 — SKELETON. Zero crier source read; the port facts were measurable in one grep; no log lines, no metrics, contracts from the outline.

M11 — SKELETON. The chapter is the schema's worked example re-cast as a module section; its runtime is wrong (3.11 vs 3.14.9), its verification rows are another round's results, and §8 concedes only `ls` was run.

M12 — SKELETON. A 273-line, fully readable, self-documenting file left unread; five RED fields that the code answers; the one contract the node depends on stated as absent.

PANEL REVIEW COMPLETE

session_id: local-f14835c516a39dfddb9dc9d141fa5425cc10126a40be6240920deff797e01f3d

EXIT=0
```

### kimi

```
VERDICT: FAIL

BLOCKING: 7 — findings that must be fixed before this chapter set can be called written
NON-BLOCKING: 7

FINDINGS

B1. FALSE CLAIM + CONTRADICTION — M6 (chapters/M6-documentation.md §4, §7, §8)
  Claim: verification row dated 2026-11-06 reads "FAILING — CF-374: prints PASS over 0 modules";
  §7 lists "OPEN — CF-374: point the check at the real root"; §8 lists "CF-374 (complete)".
  Evidence: I re-ran the exact command (`python3 scripts/master_doc_check.py`, repo root, tree at
  HEAD 943ef98, one commit past the stamped f0ca317, touching only scripts/ownership.py): output is
  "44 module(s): 37 VERIFIED, 50 error(s), 0 warning(s), 10 fact(s) in the ledger / MASTER-DOC: FAIL".
  The board row itself: `"id":"CF-374",...,"status":"complete"` (.coding-hermes/board/tasks.jsonl).
  The gate does not print PASS over 0 modules; it FAILs over 44 modules. The chapter's measured
  result does not reproduce, and §7 contradicts §8 and the board.
  Fix: re-run the gate, record the real output, delete the stale CF-374 narrative, reconcile §4/§7/§8.

B2. FALSE CLAIM (evidence command does not reproduce) — M0 (§2, §4)
  Claim: "seventeen measured directly by `grep -rl '\. \"$HERE/lib.sh\"\|source.*lib.sh' scripts/`
  (17 matches)" and §4 row "who sources it ... >= 17 files ... PASS (17)".
  Evidence: I ran the quoted command verbatim twice: 11 matches both times. The true count of shell
  files that source lib.sh is 17 (measured via `grep -rn '^\s*\.\s\|^\s*source\s' scripts/
  --include='*.sh' | grep lib.sh | sort -u | wc -l` = 17), so the conclusion is accidentally right,
  but the §4 check as written FAILS when a stranger repeats it — 11 < 17 against a ">= 17" expectation.
  Fix: quote the command that actually yields 17, or state 11 for that command.

B3. UNVERIFIED contracts (rule 2, both-sides) — ALL 13 chapters, §3c
  Claim: ~20 service-contract rows across the document; not one names producer AND consumer as
  file:function. Most name neither side (M9/M12 name only a direction and an OUTLINE section).
  Evidence: brief rule 2 ("One side is a rumour"); MASTER-DOC-SCHEMA.md §3c line 56 ("Every wire
  contract names both sides' file and function"). Root cause: the schema's own worked example
  (MASTER-DOC-SCHEMA.md lines 136-142) violates the same rule — the chapters copied the example.
  Verified counterexample exists in-repo: scheduler emits text_b64 at
  coding-herms-scheduler/internal/bus/dispatch.go:202; node reads `dispatch.get("text")` at
  code-factory/scripts/node-bus-worker.py:986 — both sides were findable; nobody wrote them down.
  Fix: fix the schema worked example first, then add file:function on both sides of every §3c row.

B4. OMISSION (mandated structure) — ALL 13 chapters
  Claim: OUTLINE.md PART III mandates 13 headings per chapter. Every chapter implements only the
  8-section MASTER-DOC-SCHEMA shape. Missing everywhere: #3 submodule inventory with
  active/optional/legacy/designed-not-built classification proven by invoking file:line; #5 settings
  register (default, range, consequence — under the outline's own decision rule every setting in the
  document is therefore NAME ONLY and counts as unwritten); #11 limits and margins; #12 cross-references.
  Evidence: OUTLINE.md lines 97-131 vs. any chapter's section list. Zero settings registers exist
  in docs/handbook/chapters/.
  Fix: either write the four missing headings per chapter, or amend the outline — the document may
  not silently satisfy the weaker of its two governing specs.

B5. CONTRADICTION + FALSE CLAIM — M6 vs M8 over verify-patch.sh
  Claim: M6 §8 and OUTLINE assign verify-patch.sh to M6.S8; M8 §1 lists it in M8's path and M8 §8
  asserts "OUTLINE.md v2 adds M8.S3 patch-chain drift (verify-patch.sh)".
  Evidence: OUTLINE.md line 170 assigns verify-patch.sh to M6.S8; the M8 entry (line 173) has only
  S1/S2 — no M8.S3 exists. One unit claimed by two chapters, and M8's outline citation is fabricated.
  Fix: single ownership (the outline says M6.S8); M8 drops the file and the invented citation.

B6. UNVERIFIED skeletons — M9, M10, M11, M12
  Claim: four control-plane chapters whose own status fields read "RED — UNVERIFIED", with §3b
  explicitly empty ("not read this round"), no revision stamp (schema §1 requires one; "external
  repo — not stamped" is a RED identity field), zero captured log lines, metrics unverified, and
  verification limited to `ls` / `wc -l`. Self-declared RED counts: 6, 6, 4, 5.
  Evidence: chapters/M9-scheduler.md §1/§3b/§5/§6; M10-crier.md same; M11-dispatcher.md §1/§5;
  M12-inference-proxy.md §1/§3b/§6. Their repo-path rows do reproduce (cmd/, internal/,
  config.example.toml, scheduler.db all exist at the stated paths; crier clients/ holds python +
  typescript; cf-inference-proxy.py is exactly 273 lines) — but reachability is not a chapter.
  Fix: read the source, stamp each repo's revision, fill 3b/5/6, or declare these chapters unwritten.

B7. UNVERIFIED verification rows shipped open — M0, M1, M2, M3, M4, M5, M7, M8
  Claim (rule 1: a claim without evidence is UNVERIFIED and blocks): M0 fetch_verified fail-closed
  "not run this round"; M1 disk-floor unit unrun and selftest row left at "running this round — see
  manifest" (manifest not path-named; I ran it to completion: SELFTEST FAIL (1)); M2 test_lane_target
  unrun; M3 land dry-run unrun; M4 board_drift unrun; M5 conformance battery + test_harness_resolve
  unrun; M7 token mint unrun; M8 test_reclaim unrun.
  Fix: run them or strike the rows; a finished chapter cannot carry "running" as a result.

NON-BLOCKING
N1. Citation slip — M5 §6: "installed %s but the pin is %s (`install-gitreins.sh:105`)" — actual
  line 106, and the verbatim drops "(log $log)".
N2. Count drift — M4 §3b: "21 verbs" — `boardctl --help` lists 20 subcommands (doctor does exist;
  boardctl reports version "dev", so drift is plausible; re-measure and stamp a version).
N3. Repeatability disclosure — M2 §4: `python3 ~/node-bus-worker.py --check` is a cf-node command;
  ~/node-bus-worker.py does not exist on this host (verified). Dated FACT-04 stands, but say where
  it must be run.
N4. Stale stamp — all chapters stamp f0ca317; HEAD moved to 943ef98 at 15:48 mid-round
  (scripts/ownership.py added). The "31/31" py_compile sweep is now 32/32. Re-stamp at publication.
N5. Stale carried evidence — M11 §4 PASSes are stamped rev 98eb5ce (2026-11-04); crier-fleet HEAD
  is 283bca9. Per the schema's own rule, a check from a prior revision is UNVERIFIED.
N6. Count slip (outline-side) — OUTLINE appendix A claims 47 unit files; 46 .md measured in
  docs/handbook/appendices/units/ (including 00-INDEX and _facts).
N7. Overstatement — M0 §2 "Twenty scripts source lib.sh": 17 shell sourcers measured; 20 is the
  count of all .sh files in scripts/.

WHAT I RE-VERIFIED AS TRUE (so the next round keeps it)
- M3's round-measured claims reproduce exactly. My own run of tests/selftest.sh: SELFTEST FAIL (1);
  the single failing case is "FAIL tracked python surface is red: a python-staging commit is refused"
  (arm 51); the arm-41 section passes 12/12. QA-CODE-FACTORY-2's repo-freshness diagnosis is stale,
  as M3 §8 says.
- M4 store counts reproduce two ways: jq/wc give 357 rows / 515 events; `boardctl doctor`
  independently reports "rows: 357 tasks, 515 events".
- CF-354/CF-355 are real, open, and code-accurate: text_b64 emitted at internal/bus/dispatch.go:202,
  `text` read at node-bus-worker.py:986, and dispatchReplyVerdict (dispatch_leg.go:713-726) checks
  only ok:false.
- Every line citation I spot-checked is exact: lib.sh:6-8, 19-42, 26, 48-57, 75-78;
  land-node-branch.sh:8-9, 22-24, 53-58, 91-93, 167, 214, 231, 265-283, 291, 294;
  install-gitreins.sh:12-14, 53, 120-139; .gitleaks.toml:11-33; harness-vars.sh:34, 66, 157-159.
- Measured values reproduce: bash 5.3.9, python 3.14.9, go 1.26.5; lib.sh 78 / harness-vars.sh 318 /
  land-node-branch.sh 295 / install-gitreins.sh 180 / .gitleaks.toml 48 / proxy 273 / bus worker 1498 /
  gen_unit_map.py 359 / panel_loop.py 305 lines; bash -n 20/20 PASS; no scripts/hooks/ directory
  (M3's outline correction is correct).

DEFECT CLASSES
stale-diagnosis-carried-forward (B1, and QA-CODE-FACTORY-2 caught by M3); evidence-command-does-not-
reproduce (B2); one-sided-contract (B3); missing-mandated-heading (B4); spec-vs-spec-contradiction
(B3 root cause, B4); double-claimed-unit (B5); fabricated-citation (B5); unread-body-skeleton (B6);
unstamped-external-revision (B6, N4, N5); open-UNVERIFIED-row (B7); count-drift (N2, N6, N7);
off-by-one-citation (N1).

CHAPTER SCORECARD
M0  PARTIAL — exact citations and honest RED metrics, but its own §4 source-count check fails when
    repeated (B2); one UNVERIFIED row open.
M1  PARTIAL — structure verified against UNIT-MAP, bodies unread, §4 selftest row left "running"
    with no manifest path; disk-floor row open.
M2  PARTIAL — strongest node-side chapter; honest about the unread 1498-line worker; failure modes
    are code-accurate (verified CF-354/355); contracts one-sided; lane_target row open.
M3  PARTIAL — closest to written: three files read in full with every citation exact, round-measured
    selftest claim independently reproduced by this judge, two correct findings filed against the
    outline and a stale board row. Held back by B3/B4, an open dry-run row, and UNVERIFIED
    clone_lane/repo_freshness.
M4  PARTIAL — store-level claims reproduced two independent ways; verb surface taken from a doc,
    not the tool, and the count is off (N2); drift row open.
M5  PARTIAL — harness-vars.sh read in full; installer bodies and resolver unread; two open
    verification rows; citation slip N1.
M6  PARTIAL (blocking) — its central gate claim is inverted against reality and disagrees with
    itself and the board (B1); double-claims verify-patch.sh (B5).
M7  SKELETON — bodies unread, one thin contract row, token-mint check never run.
M8  SKELETON — bodies unread, and it carries a fabricated outline citation plus a unit the outline
    assigns to M6 (B5).
M9  SKELETON — self-declared 6 RED fields; no source read, no revision stamp, no logs, no metrics.
M10 SKELETON — self-declared 6 RED fields; same shape as M9.
M11 SKELETON — leans on the schema's worked example stamped at a superseded revision; 4 RED fields.
M12 SKELETON — a 273-line file measured by wc -l and nothing else; 5 RED fields; every contract
    row names no function on either side.

PANEL REVIEW COMPLETE

session_id: local-7ad5f8a252cc7fe33d3630cab9cf0125a64c92c13e8bd6d5bf4229033167b7a1

EXIT=0
```

### sol

```
VERDICT: FAIL
BLOCKING: 28 — findings that must be fixed before the affected chapters can be called written
NON-BLOCKING: 0

FINDINGS:

Review basis

Read all 13 chapter files, the outline, the field schema, and implementation paths across all five systems. The outline was used for required structure, not as evidence that runtime behaviour exists.

Source references below use:
  CF = /home/kara/code-factory
  SCHED = /home/kara/coding-hermes-scheduler/coding-herms-scheduler
  CRIER = /home/kara/crier
  DISPATCH = /home/kara/crier-fleet
  PROXY = /home/kara/.hermes/scripts/cf-inference-proxy.py
  HB = CF/docs/handbook/chapters

Observed repository HEADs:
  CF:      943ef984dc093e5780605ac6e54cd043122126ef
  SCHED:   dfa9c84fbf0c0de0be5de6259609a13fc6ca8b1b
  CRIER:   691f0c78fc75717295abf3bd85aaa9192616aac0
  DISPATCH:283bca91091933177ec521e52f37f1bc987cf7da

The CF chapter stamp, f0ca317e96ac0616e2c92514ee99e5755ce734d2, is an ancestor of the reviewed HEAD. In particular, master_doc_check.py and reclaim_disk.py are byte-identical at that stamp and in the reviewed working tree. Their contradictions below are not explained by a later code change.

Checks actually repeated:
  Individual bash -n checks: 20 files passed.
  test_disk_floor.py: 12 tests passed.
  test_lane_target.py: 40 tests passed.
  test_harness_resolve.py: 28 tests passed.
  test_reclaim.py: 9 tests passed.
  Total hermetic Python tests: 89 passed.
  Board count commands: 357 task rows, 515 event lines.
  python3 -B scripts/github-app-token.py:
    printed usage; exit 2.
  python3 -B scripts/master_doc_check.py:
    resolved docs/handbook/appendices/units;
    “44 module(s): 37 VERIFIED, 50 error(s), 0 warning(s), 10 fact(s) in the ledger”
    “MASTER-DOC: FAIL”; exit 1.

These results do not certify deployment, provisioning, model execution, or the control-plane integrations. No live provisioning, credential mint, inbox lease, remote job, landing, or cleanup operation was performed. Full Go suites were not run. One supplemental inline-Python probe was blocked by unattended approval policy; no result is attributed to it.

1. OMISSION — M0–M12 — Required chapter structure is absent.

  Claim quoted: the repeated sequence ends with “## 8. Evidence of record”; there is no independently addressable submodule inventory, settings register, limits and margins, or cross-reference section.

  Evidence: every chapter was read in full. The required chapter structure is CF/docs/handbook/OUTLINE.md:102–131. These are operational fields, not decorative headings: for example, CF/scripts/node-bus-worker.py:80–114 defines distinct transport and execution limits, while DISPATCH/dispatcher.py:361–397 implements durable state requiring its own recovery description.

  Fix: supply the thirteen required responsibilities per chapter, including each submodule’s authority, invocation, execution location and evidence-backed active/optional/legacy/designed-not-built classification. A UNIT-MAP pointer does not fill those fields.

2. OMISSION — M0–M12 — Settings are unwritten, not merely incomplete.

  Claim quoted: M5 calls harness-vars.sh “CF_* validation”; M12 calls admission “token → node, model allowlist, fail-closed.” Neither provides the required settings register.

  Evidence: CF/scripts/harness/harness-vars.sh:275–287 supplies defaults and bounds for turn/time budgets; CF/scripts/disk_floor.py:36–40 supplies role defaults and floor bounds; DISPATCH/dispatcher.py:38–60 supplies polling, lease, deadline and cap controls; PROXY:43–62 supplies routing, model admission and body-size controls. The chapters do not state default, range and consequence for these settings.

  Fix: derive registers from implementation. Each setting needs reader file:function, precedence, default, accepted range, failure response and consequence of changing it. Merely listing a variable remains NAME ONLY.

3. UNVERIFIED — M0–M12 — Contract tables do not identify both implementations.

  Claim quoted: repeated rows such as “crier | in | HTTP inbox read + lease” and “scheduler | out | crier complete.”

  Evidence: those tables name peers and payload summaries, not producer and consumer file:function pairs. Actual examples include CF/scripts/node-bus-worker.py:1204 once → CRIER/internal/registry/handler.go:1690 HandleRetrieve, and DISPATCH/dispatcher.py:500–519 main → CRIER/clients/python/crier_client.py:975 deliver / :1038 ack.

  Fix: assign contract IDs and name both implementations, exact serialization, correlation rules, timing, failure semantics and compatibility policy. Do not inherit “works” or “broken” from the outline.

4. UNVERIFIED — M0–M12 — Metrics fields remain explicitly RED.

  Claim quoted: “RED — none” or “RED — unverified” in every chapter’s metrics section.

  Evidence: CF/docs/MASTER-DOC-SCHEMA.md:72–79 makes this a blocking field. The chapters either admit no emitted metrics or have not inspected the implementation. M9 and M10 substitute dashboard/API or port descriptions for metric names, types, labels and scrape locations.

  Fix: inventory real instruments with source locators and collection paths. Where none exist, retain RED and identify the exact observability work needed. JSONL records and manually counted log lines must not be relabelled as emitted counters.

5. UNVERIFIED — M0–M12 — Verification provenance does not support the status claims.

  Claim quoted: M0:12 says “VERIFIED … lines read in full”; M9–M11 say “external repo — not stamped this round”; M12:9 substitutes a modification date for revision identity.

  Evidence: reading source is not a behavioural verification. CF/docs/MASTER-DOC-SCHEMA.md:18 and :59–70 require revision-bound checks. M11 imports historical PASS results without a current implementation stamp; M9, M10 and M12 do not bind behaviour to any source revision.

  Fix: separate source inspection, syntax checks, unit tests and deployed verification. Stamp each external repository and the proxy’s content hash; bind each result to its command, output, exit status, date and exact source. Until then, behaviour remains UNVERIFIED.

6. FALSE CLAIM — M0 — bunker_exec is documented as a crier service contract.

  Claim quoted: M0:51, “crier (via bunker_exec).”

  Evidence: CF/scripts/lib.sh:75–78 invokes the bunker CLI and bash -lc. It does not address crier, serialize a bus envelope, lease a message or call a crier client.

  Fix: name the actual bunker execution boundary. Document crier separately at the units that implement its HTTP protocol.

7. FALSE CLAIM — M0, with consequences for M1–M8 — Generic PASS output is classified as proof.

  Claim quoted: M0:73 classifies “PASS %s — %s” as “evidentiary”; the same classification is copied into other chapters.

  Evidence: CF/scripts/lib.sh:6 unconditionally prints its two arguments. It performs no measurement. A caller can emit this line before, after, or without the operation it purports to certify.

  Fix: classify the generic helper output as descriptive. Only promote a specific instance to evidence when the chapter supplies the predicate measured, failure branch, exit status and independent effect check.

8. FALSE CLAIM — M1 — The provisioner does not pin bunker by absolute path.

  Claim quoted: M1:35, “bunker CLI … control host, absolute path in code.”

  Evidence: CF/scripts/bunker-provision.sh:181 resolves b through have bunker; lib.sh:13 implements have using command -v. node-create.sh:92 uses the same PATH-based resolution. DISPATCH/dispatcher.py:60 has an absolute-path default, but that is another component.

  Fix: document per-entrypoint resolution accurately, including PATH ambiguity and any version check actually performed. Do not transfer the dispatcher’s protection to the provisioner.

9. UNBUILDABLE — M1, M5, M7 — Advertised multi-file shell parse commands do not check every supplied file.

  Claim quoted:
    M1:56, “bash -n scripts/bunker-*.sh scripts/node-create.sh …”
    M5:55, “bash -n scripts/harness/*.sh”
    M7:51, “bash -n scripts/github-app-*.sh”

  Evidence: bash accepts one script-file operand; subsequent operands are script arguments. These commands therefore do not implement the claimed sweep. The independently repeated per-file loop did parse all 20 shell files successfully, but that is a different command.

  Fix: print the actual loop, failing immediately on any individual parse error, and quote its executed output. Do not present the abbreviated commands as equivalent verification.

10. FALSE CLAIM — M2, M11 — The documented Python SDK interface does not match the consumer code.

  Claim quoted:
    M2:40, “crier_client … send/retrieve/complete.”
    M11:38, “Crier … send/retrieve/complete.”

  Evidence: node-bus-worker.py:66–78 imports urllib, not crier_client, and :1269–1274 calls its own request helper. The dispatcher imports Crier at dispatcher.py:34–36 but calls retrieve, deliver and ack at :435, :508 and :519. Those operations are implemented at CRIER/clients/python/crier_client.py:1009, :975 and :1038.

  Fix: distinguish the node’s independent HTTP/signing implementation from the dispatcher’s SDK dependency, and document the actual methods and data conversion each relies on.

11. FALSE CLAIM — M2 — The reply shape is not the implemented reply shape.

  Claim quoted: M2:48, “in_reply_to, corr_id, run_id, outcome.”

  Evidence: CF/scripts/node-bus-worker.py:1128–1144 constructs env_version, dispatch_id, corr_id, status, host_identity, harness, vars, exit_codes, gate_exit, branch, commit, artifacts, wall_s and finished_at. It does not construct run_id or outcome there. SCHED/internal/bus/dispatch.go:175–207 also differs from the chapter’s outbound envelope summary: it emits board, not the claimed board_row.

  Fix: derive request and result schemas from the actual builders and delivery wrappers. State which fields are absent, renamed, optional or unsupported, and show the consumer behaviour for each difference.

12. FALSE CLAIM — M9, also affecting M2/M10 — “No completion write-back” is overgeneralized into no settlement.

  Claim quoted: M9:70, “scheduler never learns a run finished.”

  Evidence: SCHED/internal/scheduler/dispatch_leg.go:260 awaits a correlated reply, :262–336 updates the dispatch receipt and constructs timeout/failed/completed outcomes. :713–725 genuinely has the narrower defect that absence of ok:false is treated as success.

  Fix: distinguish implemented inbox-based completion from any missing separate completion-event bridge. Preserve the real status-field incompatibility, but remove the claim that the scheduler has no way to learn completion.

13. OMISSION — M3 — The landing proof’s degraded branch is omitted.

  Claim quoted: M3:23–25, “re-fetches, and proves git merge-base --is-ancestor.”

  Evidence: CF/scripts/land-node-branch.sh:275–277 continues after a failed post-push fetch, explicitly verifying against the existing tracking ref. :284–286 only warns if ls-remote disagrees with that ref.

  Fix: describe the failed-fetch and moved-remote branches separately from a fresh remote proof. State exactly what LANDED establishes in each branch and what remains unverified.

14. UNBUILDABLE — M3 — The landing verification cannot be copied and run.

  Claim quoted: M3:59, “./scripts/land-node-branch.sh --dry-run ….”

  Evidence: CF/scripts/land-node-branch.sh:85–86 requires workdir, branch and commit; :95–106 requires a clean checkout on the target main branch; :127–148 requires resolvable refs and commit reachability. The chapter supplies neither fixture preparation nor concrete arguments.

  Fix: provide a disposable local fixture with explicit refs and SHA selection, execute the exact dry-run command, and record no-ref-change evidence. Keep the live landing command distinct.

15. FALSE CLAIM — M4 — boardctl’s implementation and runtime dependency are misattributed.

  Claim quoted: M4:40, “boardctl verbs | this repo | 21 verbs.”

  Evidence: CF/scripts/boardctl:15–18 requires an external boardctl executable and exits 127 when absent; :21 execs that executable with -C. The repository wrapper does not implement the advertised verb surface. M4’s runtime dependency table omits the executable it actually requires.

  Fix: identify the external provider, required version or compatibility policy, installation source, supported verbs and refusal behaviour. Verify through the wrapper rather than attributing external implementation to this repository.

16. FALSE CLAIM — M5, also M1 — “Python 3.x” is not a sufficient dependency constraint.

  Claim quoted: M5:33, “python3 + venv | 3.x.”

  Evidence: CF/scripts/harness/install-hermes.sh:26–30 defines interpreter bounds, and :108–115 refuses versions outside >=3.11,<3.14. The measured host Python is 3.14.9. Compile success on that interpreter does not demonstrate installer compatibility.

  Fix: specify interpreter constraints by adapter and execution location, including HERMES_PYTHON_BIN selection and the expected refusal. Do not imply the controller’s measured interpreter is a valid node installer interpreter.

17. OMISSION — M5 — Harness resolution is named but its decisions are not documented.

  Claim quoted: M5:12, “UNVERIFIED … harness_resolve.py”; M5:85 discusses the structure-map discrepancy instead of the resolver’s behaviour.

  Evidence: CF/scripts/harness_resolve.py:9–64 defines selection precedence, lane classification, refusal ordering and recorded decision fields; :153–160 implements lane classification. Its hermetic suite passed 28 tests during this review.

  Fix: write M5.S4 as an operational contract: directive > lane > matrix > fallback, bound-foreman restrictions, installed-set checks, shim handling, decision fields and failure recovery. Cite and exercise the implementation rather than only its filename.

18. FALSE CLAIM — M6 — The reported live zero-module PASS defect is already fixed in the stamped source.

  Claim quoted:
    M6:56, “prints PASS over 0 modules.”
    M6:76, “OPEN … point the check at the real root.”

  Evidence: CF/scripts/master_doc_check.py:52 defines fallback roots; :55–74 resolves them; :175–181 refuses missing roots; :195–209 detects empty selections; :262–264 fails vacuous checks. The repeated command checked 44 modules and exited 1 with 50 locator errors. The file is identical at the chapter’s stamped revision.

  Fix: describe the fix as historical and superseded. Replace the live diagnosis with the observed stale-locator failures and preserve the actual command output.

19. OMISSION — M6 — The documented gate does not select these M-numbered chapters.

  Claim quoted: M6:17–19, “the gate that recomputes VERIFIED … without it a VERIFIED stamp is prose.”

  Evidence: CF/scripts/master_doc_check.py:188 selects “[0-9][0-9]-*.md”, while the reviewed chapters are M0-shared-contract.md through M12-inference-proxy.md. Default resolution selected appendices/units, not chapters/. Passing an explicit chapters root would still not match that filename pattern.

  Fix: state the gate’s actual coverage boundary. Add and demonstrate a chapter-aware gate or an explicitly separate verification path; do not imply the existing appendix gate certifies the handbook chapters.

20. UNBUILDABLE — M7 — The “token mint” command performs no mint.

  Claim quoted: M7:53, “python3 scripts/github-app-token.py … fresh token, value not printed.”

  Evidence: repeating the exact command printed usage and exited 2. CF/scripts/github-app-token.py:748–751 returns 2 when no command is selected. check and token are distinct operations at :702–724 and :752–755.

  Fix: supply the intended mode and required file-path arguments. Clearly separate a read-only check that mints in memory from token output that writes a private credential file. Do not publish credential values.

21. FALSE CLAIM — M8 — “No age gate” contradicts the reclaimer.

  Claim quoted:
    M8:23–24, “no age gate.”
    M8:70, “add an age gate.”

  Evidence: CF/scripts/reclaim_disk.py:42 defaults job_ttl_hours to 24; :46–47 validates it; :90–92 retains fresh directories; :104–111 applies aged=True to job and clone directories. tests/test_reclaim.py:50–59 tests TTL behaviour and passed during this review. This implementation is also identical at the chapter stamp.

  Fix: document the existing TTL, its mtime basis, the unaged build-cache policy and the actual target roots. Treat evidence retention as a separate question: a TTL is not an evidence-reference exclusion rule.

22. FALSE CLAIM — M8 — Its “verbatim” logs are borrowed from unrelated helpers.

  Claim quoted: M8:64, “PASS %s — %s / FAIL %s — %s … scan/reclaim rows.”

  Evidence: reclaim_disk.py:147–164 emits reap/keep/skip rows, a “note reclaim” line and optional JSON. check_scan_scope.py:102–113 emits audit-scope rows and RESULT: FAIL/OK. verify-patch.sh:156–160 emits VERIFY-PATCH: FAIL/PASS. These implementations do not use the documented generic lib.sh log table.

  Fix: enumerate actual messages, conditions and exit codes for each safety submodule. Include scanner scope and the distinction between no matching posture documents and a checked set of claims.

23. FALSE CLAIM — M10 — Signature verification does not precede registry lookup.

  Claim quoted: M10:22–23, “crier verifies a per-agent ed25519 signature before lookup.”

  Evidence: CRIER/internal/registry/agentsig.go:167–194 checks required headers first, :198 looks up the target, and :225 onward checks timestamp, key and signature data. Unknown targets can return 404 at :204. Enforcement itself is conditional at :364–368.

  Fix: document the real refusal order and deployment toggle. Separate absent headers, unknown agent, stale timestamp, malformed proof and invalid signature; do not claim a stronger pre-lookup property.

24. FALSE CLAIM — M10, with dependency correction needed in M9 — Build requirements are understated and confused with runtime requirements.

  Claim quoted: M10:31, “Go runtime | 1.26.x”; M10:10 reports Go 1.26.5.

  Evidence: CRIER/go.mod:3 requires Go 1.26.10. SCHED/go.mod:3–5 declares Go 1.26.0 with toolchain go1.26.6. The host-level go version command returned go1.26.5. A broad “1.26.x” does not communicate the required patch level, and a compiled Go service’s execution requirements are not its source-build toolchain requirements.

  Fix: separate build/test toolchain, automatic toolchain selection and deployed-binary runtime dependencies. Record the toolchain selected inside each repository and the running artifact identity.

25. UNBUILDABLE — M11 — The historical verification scripts are not reliable pass/fail oracles as documented.

  Claim quoted:
    M11:52, “DURABLE-OK, rc=0.”
    M11:53, “rc=124, 0 survivors.”

  Evidence: DISPATCH/tests/test_durable_job.py:8–11 invokes a real remote model job and only prints results; it does not assert success. test_job_kill.py:23–35 prints a PASS/FAIL sentence but does not translate failure into a nonzero script exit. test_job_boundary.py:15–22 similarly prints observations without a failure exit. These scripts hardcode cf-node and bunker-las-03.

  Fix: make negative outcomes fail the test process, distinguish harness exit codes from test-script exit codes, parameterize the remote target, and document credentials, cost and side effects. These live tests were not repeated; their historical success is not independently certified here.

26. OMISSION — M11 — Ledger and acknowledgement semantics are not an operational chapter.

  Claim quoted: M11 names “job model and durable execution” but leaves S2 ledger and S3 completion-bridge internals unread and provides no recovery state machine.

  Evidence: DISPATCH/dispatcher.py:361–397 defines ledger location, replay and write-failure handling; :470–483 replays recorded results; :500–519 delivers the result before acknowledging; :509–511 leaves failed delivery unacked. Task failure and reply-delivery failure therefore have different consequences.

  Fix: document transitions for execution, ledger persistence, reply acceptance and ack. Include crash windows, ledger-write failure, redelivery, failed-task acknowledgement and the exact recovery indications. Do not imply a ledger alone proves exactly-once execution.

27. OMISSION — M12 — An accessible implementation is replaced by an outline-shaped placeholder.

  Claim quoted: M12:12, “body not read this round”; M12:54, “whether it emits counters was not measured.”

  Evidence: PROXY implements token loading at :65–72, token resolution at :115–123, route/body/model admission at :125–162, model rewriting at :164–180, streaming at :188–238, buffered forwarding at :240–258, request capture at :83–95 and usage logging at :98–101. These are concrete implementations, not unknown future submodules.

  Fix: write S1–S4 from the code, including response codes, startup refusal, per-request key lookup, timeout behaviour, partial-stream failure and logging/capture limitations. Explicitly distinguish implemented behaviour from behaviour actually exercised in a test.

28. FALSE CLAIM — M12 — The proxy’s execution location is assigned to the node.

  Claim quoted: M12:30, “python3 | 3.x | node.”

  Evidence: PROXY:2 describes remote nodes forwarding to the control-host gateway; :43 defaults upstream to control-host loopback; :48–50 use control-host token, credential and usage paths; :53 binds the proxy listener. The file’s own operating model is a control-host service consumed by nodes.

  Fix: distinguish controller-hosted proxy dependencies from node client dependencies. Document listener reachability, credential ownership and failure consequences on both sides. Do not direct an operator to install or diagnose the proxy as a node-local component.

DEFECT CLASSES:
missing operational structure, settings without consequences, one-sided contracts, RED observability, inspection mistaken for verification, unstamped external evidence, wrong component boundary, descriptive logs promoted to proof, PATH-resolution misstatement, ineffective verification commands, invented SDK interface, wire-schema drift, completion-path conflation, degraded-proof omission, missing verification fixture, external dependency misattribution, unsupported interpreter range, omitted resolution authority, stale defect diagnosis, gate coverage mismatch, nonexistent mint invocation, retention-policy misstatement, copied log vocabulary, authentication-order misstatement, build-runtime confusion, non-failing test oracle, undocumented crash windows, control-plane skeleton, wrong execution location

CHAPTER SCORECARD:

M0 — PARTIAL
  Shared helper definitions and several locators are accurate. The service boundary is wrong, generic print helpers are promoted to evidence, settings are absent, and “read in full” is used as VERIFIED.

M1 — PARTIAL
  Provisioning units and some genuine failure classes are identified. The bunker resolution claim is false, verification commands are inadequate, and the provisioning/certification submodules lack executable procedures and complete dependency contracts.

M2 — PARTIAL
  The text_b64-versus-text mismatch is supported by the producer and consumer code inspected in this review. However, the chapter names the wrong client dependency and inaccurate request/result fields; transport, execution and settlement are not independently documented.

M3 — PARTIAL
  The most substantive chapter: several landing safeguards have valid source locators. It still omits degraded proof semantics, supplies no runnable landing fixture, and leaves repository freshness and hook operation incompletely specified.

M4 — PARTIAL
  The reported 357 task rows and 515 event lines were reproduced. Counts do not establish the whole board contract. The executable provider is misattributed, its dependency is omitted, and the actual verb/validation surface remains unverified.

M5 — PARTIAL
  Harness names and shared-variable enforcement have implementation anchors. Interpreter compatibility is misstated; resolution policy, adapter-specific settings and conformance procedures remain unwritten.

M6 — PARTIAL
  Pipeline components are named, but the central live-defect diagnosis contradicts the stamped code. The current gate reports real locator failures and does not select these chapters. Panel and gate operation are not documented sufficiently to reproduce their authority.

M7 — SKELETON
  Mostly schema-shaped statements and references to another document. Its sole functional mint command exits with usage. Credential input, caching, refresh, output and failure procedures are not specified.

M8 — PARTIAL
  Real units are identified, but the key reclaimer diagnosis and log inventory contradict implementation. Scan scope, retention distinctions and patch-chain operation need source-derived procedures.

M9 — SKELETON
  Admits that no scheduler source was read. Admission, allocation, durable state and operator surfaces are outline references rather than implemented contracts. The blanket no-completion statement is contradicted by the dispatch settlement path.

M10 — SKELETON
  Admits no source inspection. Custody, guard, services and clients are not independently described. Authentication order and toolchain constraints are inaccurate.

M11 — SKELETON
  Repeats the schema’s historical example rather than documenting the reviewed dispatcher. Actual SDK operations, ledger crash windows, deadline controls and reply-before-ack behaviour are missing. Historical test scripts do not provide the documented failure oracle.

M12 — SKELETON
  File existence and line count substitute for inspection of a readable implementation. Admission, routing, streaming and capture are implemented but unwritten; the execution location is wrong.

No chapter meets WRITTEN. Explicitly retaining RED is preferable to inventing success, but a RED placeholder is not a completed operational chapter.

PANEL REVIEW COMPLETE

session_id: local-b509a4b3f0d3414c9bc667bbcad2b27ac500836f8645b4025048f0668424bbd9

EXIT=0
```

