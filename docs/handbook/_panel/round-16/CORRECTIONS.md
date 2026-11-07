# CORRECTIONS — round 16

Generated 2026-11-06T22:28:44-0500.

## Verdicts

- **deepseek** — PASS, blocking 0, 5534 bytes, complete=True
- **glm** — FAIL, blocking 5, 20904 bytes, complete=True
- **grok** — FAIL, blocking 4, 24812 bytes, complete=True
- **kimi** — FAIL, blocking 10, 22261 bytes, complete=True
- **sol** — FAIL, blocking 27, 32033 bytes, complete=True

## Verdict text (verbatim, per seat)

### deepseek

```
VERDICT: PASS
BLOCKING: 0
NON-BLOCKING: 5

FINDINGS:

1. kind CONTRADICTION — RED-accounting rule applied two ways across chapters.
   M4 (RED note, §13) and the "uniform rule" M5/M6/M7/M8 cite it: "a contract row in §6 whose far side is an external peer (boundary or (local), no in-repo file:function) is a terminal state ... and is NOT counted as a RED." M9 §13 and M12 §13 state the opposite: "an UNVERIFIED contract state — boundary or internal — is a named RED" and count CT-01/CT-15 (boundary, M9) and M12-C1/M12-C2/CT-07 (boundary/local, M12) inside their RED field totals. Both cite "glm #4" as the authority; the same seat's guidance is applied two ways. Evidence: M4 §13 (RED accounting rule, "not counted as a RED") vs M9 §13 RED field count = 7 (includes "CT-01 UNVERIFIED (boundary)" and "CT-15 UNVERIFIED (boundary)"). Fix: settle one rule (boundary-terminal UNVERIFIED is not a RED; internal not-measured UNVERIFIED is a RED) and restate it uniformly, then stop counting boundary rows in M9/M12's RED totals. Does not make any factual claim false — non-blocking.

2. kind UNVERIFIED (environment-gated, disclosed) — live-node ladders not run this round: M1 §7 certification ladder, M5 §7 conformance battery, M3 §11 hook-enforcement rejecting-commit fixture, M7 §7 token mint (no App creds on host). These are "not measured", not "absence proved", so the OUTLINE Part VII.3 "WRITTEN" test is not met for those fields. Each is named, dated, and filed. Fix: run the ladders on a live node / mint a credential, or accept PARTIAL as the honest terminal state (the outline explicitly blesses a RED chapter over a green un-evidenced one).

3. kind OMISSION (declared scope, not hidden) — all 16 flow chapters F1-F16 are unwritten (OUTLINE Part II marks each MISSING). Every module chapter cross-references "flow chapter not written". This is the single largest remaining body of work and a declared structural gap, not a hidden omission inside a module chapter. Fix: a flows round, or an explicit outline decision to defer.

4. kind PADDING (provisional schema deviation) — the §9 "counted-not-enumerated" log-line exemption in M0/M1/M2/M3/M5/M7 declines to tabulate every helper call site (e.g. M1 = 141 sites, M2 = 70, M5 = 215, M7 = 103), arguing enumerating a templated label is padding. The schema §6 requires "every operator-visible line, verbatim." The argument is coherent (the template IS the line; the label is data) and each chapter discloses it as "provisional — subject to schema/pill approval." Fix: the panel rules on the exemption once, rather than each chapter carrying its own provisional hedge.

5. kind FAILING (code defect, correctly reported — not a writing defect) — M12 F12-7: cf-inference-proxy.py's healthy SSE stream is unframed (no Content-Length / Transfer-Encoding / Connection: close; returns at :224 without closing), reproduced this round as 200 with client EOF TimeoutError. The chapter correctly stamps the module FAILING for streaming. This is a demonstrated system defect, filed (CF-351/CF-343/CF-346), not a defect in the document's writing.

DEFECT CLASSES: cross-chapter convention drift (RED accounting), environment-gated unmeasured ladders, declared-scope omission (flows), provisional schema exemption (log-line enumeration). No new defect class this round: false-claim, one-sided-contract, name-only-setting, stale-locator and fabricated-citation classes are all resolved in the chapters themselves (each documents its prior-round false claim and its correction).

CHAPTER SCORECARD:
M0 — WRITTEN (metrics absence-proved; every claim carries file:line; local edge terminal)
M1 — PARTIAL (certification ladder needs a live node; metrics absence-proved)
M2 — PARTIAL (bus-worker ladder not repeatable from this host; metrics absence-proved)
M3 — PARTIAL (hook-enforcement rejecting-commit fixture missing; metrics absence-proved)
M4 — WRITTEN (store 357/519 verified, drift reconciled byte-parity, boundary states terminal)
M5 — PARTIAL (conformance battery not run; §9 4-of-215 inventory)
M6 — PARTIAL (own gate reads FAIL over legacy corpus; render-to-owner leg CT-18 missing)
M7 — PARTIAL (mint environment-gated, no App creds; §9 2-of-103)
M8 — WRITTEN (verified in full; metrics absence-proved)
M9 — PARTIAL (7 named REDs — most heavily gated; log inventory 376/378, per-route contract, CT-01/05/15 UNVERIFIED)
M10 — PARTIAL (per-metric contract and custody-proof unwritten; §9 beyond 5 handler/guard sites)
M11 — PARTIAL (live-job tests are decoration with no assert; metrics absence-proved)
M12 — PARTIAL (streaming FAILING demonstrated; node-client half config-wired not call-site)

Verified this round (independent, not from any prior seat): handbook_spine.py findings=0; all 349 file:line citations across the 13 chapters resolve with 0 out-of-range and 0 unresolved basenames; CF-355 silent-success (dispatch_leg.go:713-726 reads only payload["ok"], absence = success) vs node-bus-worker.py:1180 (sends status) vs dispatcher.py:501 (sends ok) all confirmed verbatim; dispatch.go:175 payload() emits text_b64 + board (not board_row); board census 357/519; scheduler 30 tables, 43 routes, 57 flags; num-levels clamp (urgency.go:18-22) and loader <1 rejection (loader.go:421-422); tick_duration_ms has no available field; configure_family.py:24-28 PID 1755676 hardcode; M12 streaming unframed; M11 kill -TERM targets run.sh's group, not the GNU-timeout group holding the harness.

PANEL REVIEW COMPLETE

EXIT=0
```

### glm

```
│ cache/scratch/panel16_claimcheck.py
│ @@ -0,0 +1,274 @@
│ +#!/usr/bin/env python3
│ +"""Round-16 panel judge: batch-verify chapter file:line claims against code."""
│ +import sys
│ +
│ +CF = "/home/kara/code-factory"
│ +SCH = "/home/kara/coding-hermes-scheduler/coding-herms-scheduler"
│ +CR = "/home/kara/crier"
│ +FL = "/home/kara/crier-fleet"
│ +PX = "/home/kara/.hermes/scripts/cf-inference-proxy.py"
│ +
│ +# (path, line, expected-substring, claim-id)
│ +CHECKS = [
│ +    # ---- M0 lib.sh ----
│ +    (f"{CF}/scripts/lib.sh", 5, "say()", "M0:5 say"),
│ +    (f"{CF}/scripts/lib.sh", 6, "PASS", "M0:6 ok"),
│ +    (f"{CF}/scripts/lib.sh", 7, "FAIL", "M0:7 bad"),
│ +    (f"{CF}/scripts/lib.sh", 11, "FAILED", "M0:11 FAILED"),
│ +    (f"{CF}/scripts/lib.sh", 13, "have()", "M0:13 have"),
│ +    (f"{CF}/scripts/lib.sh", 19, "fetch_verified()", "M0:19 fetch_verified"),
│ +    (f"{CF}/scripts/lib.sh", 22, "--max-time 120", "M0:22 max-time 120"),
│ +    (f"{CF}/scripts/lib.sh", 26, "digest mismatch", "M0:26 digest msg"),
│ +    (f"{CF}/scripts/lib.sh", 32, "cannot create destination directory", "M0:32 mkdir msg"),
│ +    (f"{CF}/scripts/lib.sh", 37, "cannot move verified download", "M0:37 mv msg"),
│ +    (f"{CF}/scripts/lib.sh", 40, "chmod +x", "M0:40 chmod"),
│ +    (f"{CF}/scripts/lib.sh", 45, "free_gb()", "M0:45 free_gb"),
│ +    (f"{CF}/scripts/lib.sh", 48, "require_disk()", "M0:48 require_disk"),
│ +    (f"{CF}/scripts/lib.sh", 54, "disk", "M0:54 disk floor fail row"),
│ +    (f"{CF}/scripts/lib.sh", 60, "once()", "M0:60 once"),
│ +    (f"{CF}/scripts/lib.sh", 67, "shq()", "M0:67 shq"),
│ +    (f"{CF}/scripts/lib.sh", 75, "bunker_exec()", "M0:75 bunker_exec"),
│ +    # ---- M1 ----
│ +    (f"{CF}/scripts/bunker-provision.sh", 181, "have bunker", "M1:181 have bunker"),
│ +    (f"{CF}/scripts/bunker-provision.sh", 182, "bunker_cli", "M1:182 bad bunker_cli"),
│ +    (f"{CF}/scripts/bunker-provision.sh", 214, "github.token", "M1:214 -s token probe"),
│ +    (f"{CF}/scripts/bunker-provision.sh", 233, "mode 600 (value not read)", "M1:233 mode-600 print"),
│ +    (f"{CF}/scripts/bunker-provision.sh", 356, "6h", "M1:356 TTL fallback"),
│ +    (f"{CF}/scripts/bunker-provision.sh", 454, "node_seed", "M1:454 node_seed build"),
│ +    (f"{CF}/scripts/bunker-provision.sh", 550, "destroy()", "M1:550 destroy fn"),
│ +    (f"{CF}/scripts/bunker-provision.sh", 552, "--yes", "M1:552 destroy refusal"),
│ +    (f"{CF}/scripts/bunker-provision.sh", 589, "command line always wins", "M1:589 precedence note"),
│ +    (f"{CF}/scripts/bunker-provision.sh", 601, "five", "M1:601 'five' comment"),
│ +    (f"{CF}/scripts/bunker-provision.sh", 604, "DUCKBRAIN_URL", "M1:604 re-apply block"),
│ +    (f"{CF}/scripts/disk_floor.py", 36, "worker", "M1 disk_floor:36 ROLE_DEFAULTS"),
│ +    (f"{CF}/scripts/disk_floor.py", 37, "DEFAULT_ROLE", "M1 disk_floor:37"),
│ +    (f"{CF}/scripts/disk_floor.py", 123, "unknown role", "M1 disk_floor:123-125"),
│ +    (f"{CF}/scripts/verify-node.sh", 20, "--agent", "M1 vn:20 flags"),
│ +    (f"{CF}/scripts/verify-node.sh", 40, "case", "M1 vn:40 port digit test"),
│ +    (f"{CF}/scripts/verify-node.sh", 47, "digits 1-65535", "M1 vn:47 port refusal"),
│ +    (f"{CF}/scripts/verify-node.sh", 51, "10#", "M1 vn:51 base-10"),
│ +    (f"{CF}/scripts/verify-node.sh", 76, "RESULT: FAIL", "M1 vn:76 early fail"),
│ +    (f"{CF}/scripts/verify-node.sh", 106, "UNVERIFIED", "M1 vn:106-110"),
│ +    (f"{CF}/scripts/verify-node.sh", 133, "artifact", "M1 vn:133 artifact leg"),
│ +    (f"{CF}/scripts/verify-node.sh", 150, "freshness", "M1 vn:150 checkout leg"),
│ +    (f"{CF}/scripts/verify-node.sh", 177, "warn", "M1 vn:177 warn no unverified"),
│ +    (f"{CF}/scripts/verify-node.sh", 225, "unverified", "M1 vn:225 seed unverified()"),
│ +    (f"{CF}/scripts/verify-node.sh", 233, "VERIFY: FAIL", "M1 vn:233 precedence"),
│ +    (f"{CF}/scripts/verify-node.sh", 241, "VERIFY: PASS", "M1 vn:241 PASS"),
│ +    (f"{CF}/scripts/node_seed.py", 43, "node-seed.txt", "M1 seed:43 manifest"),
│ +    (f"{CF}/scripts/node_seed.py", 44, "16", "M1 seed:44 budget"),
│ +    (f"{CF}/scripts/node_seed.py", 130, "getsize", "M1 seed:130-140 size sum"),
│ +    (f"{CF}/scripts/node_seed.py", 290, "rmtree", "M1 seed:290 force rmtree"),
│ +    (f"{CF}/scripts/node_gateway_auth.py", 56, "basic_auth", "M1 gwa:56-61"),
│ +    # ---- M2 ----
│ +    (f"{CF}/scripts/node-bus-worker.py", 81, "DEFAULT_INBOX_LIMIT", "M2:81 inbox limit"),
│ +    (f"{CF}/scripts/node-bus-worker.py", 82, "DEFAULT_LEASE_SECONDS", "M2:82 lease"),
│ +    (f"{CF}/scripts/node-bus-worker.py", 84, "DEFAULT_HARNESS_WALL", "M2:84 harness wall"),
│ +    (f"{CF}/scripts/node-bus-worker.py", 85, "SEEN_LIMIT", "M2:85 seen"),
│ +    (f"{CF}/scripts/node-bus-worker.py", 113, "40", "M2:113 max turns"),
│ +    (f"{CF}/scripts/node-bus-worker.py", 129, "def ok", "M2:129 local ok()"),
│ +    (f"{CF}/scripts/node-bus-worker.py", 385, "node.json", "M2:385 identity"),
│ +    (f"{CF}/scripts/node-bus-worker.py", 388, "crier.token", "M2:388 token file"),
│ +    (f"{CF}/scripts/node-bus-worker.py", 608, "refusing", "M2:608 identity refusal"),
│ +    (f"{CF}/scripts/node-bus-worker.py", 977, "def directive_text", "M2:977 directive_text"),
│ +    (f"{CF}/scripts/node-bus-worker.py", 1007, "def process", "M2:1007 process"),
│ +    (f"{CF}/scripts/node-bus-worker.py", 1176, "status", "M2:1176 reply"),
│ +    (f"{CF}/scripts/node-bus-worker.py", 1187, "branch", "M2:1187 branch/commit"),
│ +    (f"{CF}/scripts/node-bus-worker.py", 1200, "dispatch_wall", "M2:1200 dispatch_wall"),
│ +    (f"{CF}/scripts/node-bus-worker.py", 1208, "def deliver", "M2:1208 deliver"),
│ … omitted 196 diff line(s) across 1 additional file(s)/section(s)
│ cache/scratch/panel16_spine_nc.py
│ @@ -0,0 +1,74 @@
│ +#!/usr/bin/env python3
│ +"""Negative control for the handbook spine gate (round-16 judge)."""
│ +import pathlib
│ +import shutil
│ +import subprocess
│ +import sys
│ +
│ +BASE = pathlib.Path("/home/kara/.hermes/cache/scratch/spine_nc3")
│ +SRC = pathlib.Path("/home/kara/code-factory")
│ +
│ +if BASE.exists():
│ +    shutil.rmtree(BASE)
│ +BASE.mkdir(parents=True)
│ +shutil.copytree(SRC / "docs/handbook", BASE / "handbook")
│ +spine = BASE / "spine_patched.py"
│ +s = (SRC / "scripts/handbook_spine.py").read_text()
│ +s = s.replace(
│ +    'HB = Path("/home/kara/code-factory/docs/handbook")',
│ +    f'HB = Path("{BASE}/handbook")',
│ +)
│ +assert "spine_nc3" in s
│ +spine.write_text(s)
│ +
│ +
│ +def run(label):
│ +    r = subprocess.run(
│ +        [sys.executable, str(spine)], capture_output=True, text=True
│ +    )
│ +    print(f"--- {label}: rc={r.returncode}")
│ +    print(r.stdout.strip()[:1500])
│ +    if r.stderr.strip():
│ +        print("stderr:", r.stderr.strip()[:300])
│ +    return r.returncode
│ +
│ +
│ +chapters = BASE / "handbook/chapters"
│ +m8 = chapters / "M8-safety.md"
│ +orig = m8.read_text()
│ +
│ +# NC1: unregistered canonical id
│ +m8.write_text(orig.replace("| (local) | filesystem | in |", "| CT-99 | filesystem | in |", 1))
│ +rc1 = run("NC1 CT-99 injected")
│ +m8.write_text(orig)
│ +
│ +# NC2: state disagreement on an internal contract (M11 CT-06 works -> broken)
│ +m11 = chapters / "M11-dispatcher.md"
│ +o11 = m11.read_text()
│ +needle = "| CT-06 | scheduler | out |"
│ +i = o11.find(needle)
│ +assert i >= 0
│ +j = o11.find("\n", i)
│ +row = o11[i:j]
│ +row2 = row.replace("**works**", "**broken**", 1)
│ +assert row2 != row, row
│ +m11.write_text(o11[:i] + row2 + o11[j:])
│ +rc2 = run("NC2 CT-06 state flipped in M11")
│ +m11.write_text(o11)
│ +
│ +# NC3: setting default conflict (M0 --max-time 120 vs a second chapter saying 240)
│ +m1 = chapters / "M1-provisioning.md"
│ +o1 = m1.read_text()
│ +marker = "download stalling past 120 s fails"
│ +assert marker in o1
│ +m1.write_text(o1.replace(marker, "download stalling past 240 s fails", 1))
│ +rc3 = run("NC3 setting default 120 vs 240")
│ +m1.write_text(o1)
│ +
│ +# NC4: dangling reference
│ +m1.write_text(o1.replace("see M5 §11", "see M99 §11", 1))
│ +rc4 = run("NC4 dangling M99 reference")
│ +m1.write_text(o1)
│ +
│ +print(f"RESULTS NC1={rc1} NC2={rc2} NC3={rc3} NC4={rc4}")
│ +print("NEGATIVE CONTROL:", "FIRES" if {rc1, rc2, rc3, rc4} == {1} else "DID NOT ALL FIRE")
│ cache/scratch/panel16_spine_nc2.py
│ @@ -0,0 +1,53 @@
│ +#!/usr/bin/env python3
│ +"""Negative control round 2: SETTING CONFLICT + DANGLING REFERENCE."""
│ +import pathlib
│ +import shutil
│ +import subprocess
│ +import sys
│ +
│ +BASE = pathlib.Path("/home/kara/.hermes/cache/scratch/spine_nc4")
│ +SRC = pathlib.Path("/home/kara/code-factory")
│ +
│ +if BASE.exists():
│ +    shutil.rmtree(BASE)
│ +BASE.mkdir(parents=True)
│ +shutil.copytree(SRC / "docs/handbook", BASE / "handbook")
│ +spine = BASE / "spine_patched.py"
│ +s = (SRC / "scripts/handbook_spine.py").read_text()
│ +s = s.replace(
│ +    'HB = Path("/home/kara/code-factory/docs/handbook")',
│ +    f'HB = Path("{BASE}/handbook")',
│ +)
│ +assert "spine_nc4" in s
│ +spine.write_text(s)
│ +
│ +
│ +def run(label):
│ +    r = subprocess.run([sys.executable, str(spine)], capture_output=True, text=True)
│ +    print(f"--- {label}: rc={r.returncode}")
│ +    print(r.stdout.strip()[:1200])
│ +    return r.returncode
│ +
│ +
│ +chapters = BASE / "handbook/chapters"
│ +
│ +# NC3: CF_MAX_TURNS documented 40 in M5, flip to 400 (M2 also documents 40)
│ +m5 = chapters / "M5-harness.md"
│ +o5 = m5.read_text()
│ +marker5 = "| `CF_MAX_TURNS` | 40 (`:276`) |"
│ +assert marker5 in o5, "M5 marker missing"
│ +m5.write_text(o5.replace(marker5, "| `CF_MAX_TURNS` | 400 (`:276`) |", 1))
│ +rc3 = run("NC3 CF_MAX_TURNS 40 vs 400")
│ +m5.write_text(o5)
│ +
│ +# NC4: dangling M99 reference in M0
│ +m0 = chapters / "M0-shared-contract.md"
│ +o0 = m0.read_text()
│ +marker0 = "See M5 §11."
│ +assert marker0 in o0, "M0 marker missing"
│ +m0.write_text(o0.replace(marker0, "See M99 §11.", 1))
│ +rc4 = run("NC4 dangling M99")
│ +m0.write_text(o0)
│ +
│ +print(f"RESULTS NC3={rc3} NC4={rc4}")
│ +print("NEGATIVE CONTROL 2:", "FIRES" if rc3 == 1 and rc4 == 1 else "DID NOT FIRE")
All verification complete — 260+ claims checked across the 13 chapters, live gates re-run, spine negative-controlled. The verdict:

```
VERDICT: FAIL

BLOCKING: 5 — findings that must be fixed before the affected chapters can be called written
NON-BLOCKING: 5

FINDINGS:

BLOCKING

1. kind FALSE CLAIM — chapter M5, §9 scope claim:
   "grep -rcE '\b(ok|bad|warn|note|say)\s+"' scripts/harness/ sums to 215 helper call sites"
   Evidence (measured this round): the exact quoted command sums to 274 across scripts/harness/
   (install-hermes 36, install-codex 86, install-claude-code 98, install-opencode 15,
   install-deepseek 13, install-pi-agent 17, harness-vars 9); the six installers without vars
   sum to 265. No file-set variant yields 215. The RED arithmetic built on it ("§9 inventory
   4 of 215") is wrong with it.
   Fix: re-run the command, restate the total (274) and the uncovered count; re-issue the RED row.

2. kind FALSE CLAIM — chapter M1, §9 scope claim:
   "grep -cE '\b(ok|bad|warn|note)\s+"' scripts/bunker-provision.sh scripts/verify-node.sh
   = 108 + 33 = 141 helper call sites"
   Evidence: the quoted command measures 89 + 27 = 116. The reported 108 + 33 = 141 is
   produced only by the say-inclusive pattern '\b(ok|bad|warn|note|say)\s+"' (measured:
   108 + 33). The counts are right; the command quoted beside them does not reproduce them.
   Fix: quote the say-inclusive command that yields 141 (the class of defect M0 §7 already
   fixed once for round-3's over-escaped greps).

3. kind FALSE CLAIM (misfiled locator) — chapter M7, §5 lifecycle table:
   "JWT_BACKDATE / JWT_LIFETIME | 60 s / 540 s (:50-51)" and "TIMEOUT | 20 s (:52)" —
   registered as github-app-refresh.sh controls.
   Evidence: github-app-refresh.sh:50-52 is the argument-parse fallthrough
   (`*) say "unknown argument: $1"; usage 2 ;;` / `esac` / `done`); refresh.sh defines no
   JWT or TIMEOUT setting (grep: 0). JWT_BACKDATE = 60, JWT_LIFETIME = 540, TIMEOUT = 20
   live at github-app-token.py:50, :51, :52 (measured). Right lines, wrong file.
   Fix: attribute the three rows to github-app-token.py.

4. kind CONTRADICTION — chapters M4 vs M9/M12, RED-accounting rule:
   M4 §RED-rule: a boundary contract row "is a terminal state … and is not counted as a RED"
   (echoed in M2/M3 footers, M5-M8). M9 §RED-count: "an UNVERIFIED contract state — boundary
   or internal — is a named RED; only a measured-works state is not" (counts CT-01, CT-15);
   M12 applies the same rule (counts CT-07, M12-C2).
   Evidence: M4-board.md "RED accounting rule (uniform across M4/M5/M6/M7/M8…)" vs
   M9-scheduler.md RED-count paragraph; both quoted in the chapters.
   Fix: adopt one rule document-wide (the spine cannot catch this — it checks states, not
   RED-count semantics) and restate the affected RED counts under it.

5. kind FALSE CLAIM (grep result misquoted) — chapter M2, §3 S1 classification:
   "grep -rn 'add_family_lanes\|configure_family\|load_lane_config' scripts/ matches only
   the files themselves (run this round)"
   Evidence: the command also matches scripts/handbook_spine.py:69 (a comment naming
   load_lane_config.py as CT-05 producer). The operator-invoked classification is unaffected
   (a spine comment is not a caller), but the quoted evidence does not reproduce as stated.
   Fix: restate the match set ("the three files plus a spine comment and __pycache__").

NON-BLOCKING

6. kind UNVERIFIED (locator drift) — M7 §5: GIT_CREDENTIALS store-guard cited "(:131)";
   :131 is `fi`; the guard is `if [ -f "$GIT_CREDENTIALS" ] && [ -s "$TOKEN_FILE" ]` at :134.
   Fix: re-pin to :132-134.

7. kind UNVERIFIED (locator drift) — M10 §3: "default lease 30 s (:1732-1743)"; actual
   `leaseSecs := 30 * time.Second` at handler.go:1734, parse block to ~:1745. Semantics
   (30 s default, historical `lease` wins over `lease_seconds`) verified correct at :1735-1745.
   Fix: re-pin.

8. kind UNVERIFIED (locator drift) — M7 §10: the quoted refusal "…is mode %04o; a private
   key must be 0600" is cited (:344-348); the message text sits at github-app-token.py:349-350
   (check block :342-351).
   Fix: re-pin.

9. kind PADDING risk (accepted, provisional) — M0/M1/M2/M3 §9 "counted-not-enumerated"
   exemption: the four house templates are fully specified with measured counts and the
   evidentiary rows are tabulated, so the distinct operator-visible formats ARE given — the
   exemption is accepted for M0 this round. M1's rests on the wrong count (blocking #2);
   M5 shows where the line is (uncovered sites named as RED). Fix: keep the exemption but
   every count under it must be a command-reproducible number.

10. kind OMISSION (document-level, declared) — Part II: all 16 flows remain MISSING; every
    chapter cross-references this honestly and the OUTLINE tracks it, so it is not a
    chapter-level deception — but the handbook cannot be called complete while Part II is
    empty. Fix: the flow chapters remain the next work item.

DEFECT CLASSES:
quoted-command-vs-count mismatch (2); wrong-file locator (1); locator line-drift +2/+3 (2,
non-blocking); acceptance-rule divergence / RED accounting (1); grep-result misquote (1);
declared structural omission (flows).

WHAT WAS VERIFIED CLEAN (so the next writer does not re-litigate it):
- handbook_spine.py: findings=0 on the live tree is meaningful — four negative controls
  (injected CT-99; CT-06 state flip; CF_MAX_TURNS 40-vs-400; dangling M99) each fire rc=1
  with the correct kind. M6's documentation of the spine's checks matches the source
  (finding kinds at :267/:278/:295/:320/:344/:365/:381/:389/:414, split_row :104).
- ~260 claim checks: 191/219 exact-line hits on first try; every other sampled locator
  adjudicated correct within its cited range (e.g. verify-node.sh:40-55 port refusals,
  node_seed.py:130-140 getsize sum, handler.go:1729-1730 max-cap 400, service_auth.go:134-168,
  dispatch.go:175/:202, dispatch_leg.go:713, admission_mode.go:98/:177/:230/:266-267).
- Counts reproduced exactly: M0 78/11/17; M2 70; M3 selftest 4852 with arms at :2463-2729 and
  :3433-3670; M7 103; M9 43 routes / 57 flags / 378+1 log.Printf sites / 372 distinct /
  30 tables / 0 verdicts / 10 LoadRootConfig sites / 7 cmd dirs; M10 1895 / 91 / 3 / 67;
  M11 538 / 25 / 0 asserts; M12 273 lines + sha256 b12a0ac5…e0b5; M6 443/268/461/170;
  13 headings in each of 13 chapters; OUTLINE 48-submodule arithmetic holds.
- Live reproduction: boardctl validate RESULT: OK (7 warnings) with 357/519 rows and drift
  RESULT: OK at HEAD==origin/main==3fba8a7; master_doc_check FAIL 44/37/50; verify-patch
  PASS (5 stages, 4 patches, 57432007…); proxy 401 no-token on live :8775, systemd active,
  config/node.env.example:22,26 wiring as cited; crier `go build ./...` rc=0; scheduler
  env-sensitive test trio green under `env -u SCHEDULER_OPERATOR_RESTART_APPROVED` (ambient
  var confirmed =1 here, validating F9-6's mechanism); crier Go grep for board admission = 0
  (F4-5); cf-inference-proxy streamed branch :200-224 sends no Content-Length /
  Transfer-Encoding / Connection — M12's FAILING self-grade is code-accurate.
- Internal contracts CT-02..CT-06 name both sides and every sampled side-locator checks out.

CHAPTER SCORECARD:
M0  — WRITTEN.  All 13 fields evidenced; the one RED (metrics) is absence-proved; lib.sh
               read end-to-end by this judge; local edge terminal under the two-register rule.
M1  — PARTIAL. §9 count defect (blocking #2); live certification ladder UNVERIFIED
               (environment-gated, honestly named); otherwise dense and accurate.
M2  — PARTIAL. §3 grep misquote (blocking #5); live bus-worker ladder not repeatable from
               this host; F2-2 PID hardcode correctly carried as OPEN.
M3  — PARTIAL. S3 hook *enforcement* unproven (no rejecting-commit fixture; the chapter says
               so); cf244 arm unrun; all landed claims verified.
M4  — WRITTEN. Every claim reproduced this round (357/519, OK-7, drift OK); one absence-proved
               RED; boundary rows terminal.
M5  — PARTIAL. §9 count false (blocking #1); conformance battery UNVERIFIED (live node);
               F5-5's computed-call-site correction verified real (project-node.sh:440,449-452).
M6  — PARTIAL. Status honestly RED (own gate reads FAIL over the legacy 44-unit corpus);
               CT-18 render leg missing; spine documentation verified accurate in full.
M7  — PARTIAL. Wrong-file locators (blocking #3) plus two drifted locators; mint UNVERIFIED
               (no App creds on this host — terminal this round).
M8  — WRITTEN. Both units small, read end-to-end by this judge, every claim and count
               reproduced; one absence-proved RED.
M9  — PARTIAL. Enormous verified surface (43/57/378/30 all reproduced), but S4 per-route
               contracts and §9's 376-of-378 uncovered sites are named REDs, and its RED rule
               conflicts with M4's (blocking #4).
M10 — PARTIAL. Per-metric register and the log inventory beyond the 5 tabulated sites are
               named REDs; lease-default locator drift (non-blocking #7); build reproduced.
M11 — PARTIAL. Verification cannot fail (decoration tests, no asserts — verified 0), the
               deadline-kill descendant guarantee honestly withdrawn (F11-8); metrics RED.
M12 — PARTIAL. Streaming FAILING is a real, reproduced framing defect (confirmed at
               :200-224); boundary REDs terminal under either accounting rule; hash, port,
               admission and systemd claims all reproduced.

The document is far closer than round 1: the two-register convention, the honest UNVERIFIED
states and the measured counts survive adversarial re-measurement almost everywhere. The five
blocking findings are mechanical (two wrong counts, one wrong file, one rule divergence, one
misquoted grep) — fix them and re-run the spine; the chapter set then grades 3 WRITTEN /
10 PARTIAL with no false claims outstanding.

PANEL REVIEW COMPLETE
```

session_id: local-153731e58147d2e17168752db8c5b12fe48ee9cf9b19db4c98cf8a3ed16e2113

EXIT=0
```

### grok

```
⚠️  Primary auth failed — switching to fallback: fireworks / accounts/fireworks/models/deepseek-v4p1-flash-1017
│ cache/scratch/cite_check.py
│ @@ -0,0 +1,64 @@
│ +#!/usr/bin/env python3
│ +"""Verify every file:line citation in the handbook chapters resolves."""
│ +import os, re, sys
│ +from pathlib import Path
│ +from collections import defaultdict
│ +
│ +CH = Path("/home/kara/code-factory/docs/handbook/chapters")
│ +ROOTS = {
│ +    "code-factory": Path("/home/kara/code-factory"),
│ +    "scheduler": Path("/home/kara/coding-hermes-scheduler/coding-herms-scheduler"),
│ +    "crier": Path("/home/kara/crier"),
│ +    "crier-fleet": Path("/home/kara/crier-fleet"),
│ +    "hermes-scripts": Path("/home/kara/.hermes/scripts"),
│ +}
│ +
│ +# index by basename -> list of (root, path)
│ +index = defaultdict(list)
│ +for name, root in ROOTS.items():
│ +    if not root.exists():
│ +        print(f"MISSING ROOT {name} {root}", file=sys.stderr)
│ +        continue
│ +    for dirpath, dirnames, filenames in os.walk(root):
│ +        # skip heavy dirs
│ +        dirnames[:] = [d for d in dirnames if d not in {".git", "node_modules", "vendor", ".venv", "__pycache__", "target", "dist"}]
│ +        for fn in filenames:
│ +            index[fn].append(Path(dirpath) / fn)
│ +
│ +LINE = re.compile(r"`?([\w./-]+\.(?:py|go|sh|ts|js|json|toml|yaml|md|jsonl|conf)):(\d{1,5})(?:-(\d{1,5}))?`?")
│ +
│ +bad, okc, unresolved = [], 0, []
│ +for p in sorted(CH.glob("M*.md")):
│ +    text = p.read_text(errors="replace")
│ +    for m in LINE.finditer(text):
│ +        fname, l1, l2 = m.group(1), int(m.group(2)), m.group(3)
│ +        base = os.path.basename(fname)
│ +        cands = index.get(base, [])
│ +        # prefer candidate whose path ends with the cited relative path
│ +        rel = fname.lstrip("./")
│ +        pref = [c for c in cands if str(c).endswith("/" + rel)] or cands
│ +        if not pref:
│ +            unresolved.append((p.stem, fname, l1))
│ +            continue
│ +        c = pref[0]
│ +        try:
│ +            n = sum(1 for _ in open(c, "rb"))
│ +        except OSError:
│ +            unresolved.append((p.stem, fname, l1)); continue
│ +        hi = int(l2) if l2 else l1
│ +        if l1 > n or hi > n:
│ +            bad.append((p.stem, fname, l1, hi, n, str(c)))
│ +        else:
│ +            okc += 1
│ +
│ +print(f"citations in-range: {okc}")
│ +print(f"OUT-OF-RANGE: {len(bad)}")
│ +for b in bad:
│ +    print("  OOR", b)
│ +print(f"UNRESOLVED FILE: {len(unresolved)}")
│ +seen=set()
│ +for u in unresolved:
│ +    k=(u[1],)
│ +    if k in seen: continue
│ +    seen.add(k)
│ +    print("  UNRESOLVED", u)
│ cache/scratch/cite_check2.py
│ @@ -0,0 +1,63 @@
│ +#!/usr/bin/env python3
│ +"""Verify every file:line citation in the handbook chapters resolves (suffix-scored)."""
│ +import os, re, sys
│ +from pathlib import Path
│ +from collections import defaultdict
│ +
│ +CH = Path("/home/kara/code-factory/docs/handbook/chapters")
│ +ROOTS = [
│ +    Path("/home/kara/code-factory"),
│ +    Path("/home/kara/coding-hermes-scheduler/coding-herms-scheduler"),
│ +    Path("/home/kara/crier"),
│ +    Path("/home/kara/crier-fleet"),
│ +    Path("/home/kara/.hermes/scripts"),
│ +]
│ +
│ +index = defaultdict(list)
│ +for root in ROOTS:
│ +    if not root.exists():
│ +        print(f"MISSING ROOT {root}", file=sys.stderr); continue
│ +    for dirpath, dirnames, filenames in os.walk(root):
│ +        dirnames[:] = [d for d in dirnames if d not in {".git","node_modules","vendor",".venv","__pycache__","target","dist"}]
│ +        for fn in filenames:
│ +            index[fn].append(Path(dirpath) / fn)
│ +
│ +LINE = re.compile(r"`?([\w./-]+\.(?:py|go|sh|ts|js|json|toml|yaml|md|jsonl|conf)):(\d{1,5})(?:-(\d{1,5}))?`?")
│ +
│ +def suffix_score(c, rel):
│ +    a = Path(str(c)).parts[::-1]
│ +    b = Path(rel).parts[::-1]
│ +    n = 0
│ +    for x, y in zip(a, b):
│ +        if x == y: n += 1
│ +        else: break
│ +    return n
│ +
│ +bad, okc, unresolved = [], 0, []
│ +for p in sorted(CH.glob("M*.md")):
│ +    text = p.read_text(errors="replace")
│ +    for m in LINE.finditer(text):
│ +        fname, l1, l2 = m.group(1), int(m.group(2)), m.group(3)
│ +        base = os.path.basename(fname)
│ +        cands = index.get(base, [])
│ +        if not cands:
│ +            unresolved.append((p.stem, fname, l1)); continue
│ +        rel = fname.lstrip("./")
│ +        best = max(suffix_score(c, rel) for c in cands)
│ +        pref = [c for c in cands if suffix_score(c, rel) == best]
│ +        # prefer code-factory then scheduler then crier order as listed
│ +        pref.sort(key=lambda c: next((i for i, r in enumerate(ROOTS) if str(c).startswith(str(r))), 99))
│ +        c = pref[0]
│ +        n = sum(1 for _ in open(c, "rb"))
│ +        hi = int(l2) if l2 else l1
│ +        if l1 > n or hi > n:
│ +            bad.append((p.stem, fname, l1, hi, n, str(c)))
│ +        else:
│ +            okc += 1
│ +
│ +print(f"citations in-range: {okc}")
│ +print(f"OUT-OF-RANGE: {len(bad)}")
│ +for b in bad:
│ +    print("  OOR", b)
│ +print(f"UNRESOLVED BASENAME: {len(unresolved)}")
│ +for u in unresolved: print("  UNRESOLVED", u)
│ cache/scratch/cite_check3.py
│ @@ -0,0 +1,58 @@
│ +#!/usr/bin/env python3
│ +"""Verify citations; tie-break by line count (suffix score first)."""
│ +import os, re
│ +from pathlib import Path
│ +from collections import defaultdict
│ +
│ +CH = Path("/home/kara/code-factory/docs/handbook/chapters")
│ +ROOTS = [
│ +    Path("/home/kara/code-factory"),
│ +    Path("/home/kara/coding-hermes-scheduler/coding-herms-scheduler"),
│ +    Path("/home/kara/crier"),
│ +    Path("/home/kara/crier-fleet"),
│ +    Path("/home/kara/.hermes/scripts"),
│ +]
│ +
│ +index = defaultdict(list)
│ +for root in ROOTS:
│ +    for dirpath, dirnames, filenames in os.walk(root):
│ +        dirnames[:] = [d for d in dirnames if d not in {".git","node_modules","vendor",".venv","__pycache__","target","dist"}]
│ +        for fn in filenames:
│ +            index[fn].append(Path(dirpath) / fn)
│ +
│ +LINE = re.compile(r"`?([\w./-]+\.(?:py|go|sh|ts|js|json|toml|yaml|md|jsonl|conf)):(\d{1,5})(?:-(\d{1,5}))?`?")
│ +
│ +def suffix_score(c, rel):
│ +    a = Path(str(c)).parts[::-1]; b = Path(rel).parts[::-1]
│ +    n = 0
│ +    for x, y in zip(a, b):
│ +        if x == y: n += 1
│ +        else: break
│ +    return n
│ +
│ +bad, okc, unresolved = [], 0, []
│ +for p in sorted(CH.glob("M*.md")):
│ +    text = p.read_text(errors="replace")
│ +    for m in LINE.finditer(text):
│ +        fname, l1, l2 = m.group(1), int(m.group(2)), m.group(3)
│ +        base = os.path.basename(fname)
│ +        cands = index.get(base, [])
│ +        if not cands:
│ +            unresolved.append((p.stem, fname, l1)); continue
│ +        rel = fname.lstrip("./")
│ +        best = max(suffix_score(c, rel) for c in cands)
│ +        pref = [c for c in cands if suffix_score(c, rel) == best]
│ +        pref.sort(key=lambda c: -sum(1 for _ in open(c, "rb")))
│ +        c = pref[0]
│ +        n = sum(1 for _ in open(c, "rb"))
│ +        hi = int(l2) if l2 else l1
│ +        if l1 > n or hi > n:
│ +            bad.append((p.stem, fname, l1, hi, n, str(c)))
│ +        else:
│ +            okc += 1
│ +
│ +print(f"citations in-range: {okc}")
│ +print(f"OUT-OF-RANGE: {len(bad)}")
│ +for b in bad: print("  OOR", b)
│ +print(f"UNRESOLVED BASENAME: {len(unresolved)}")
│ +for u in unresolved: print("  UNRESOLVED", u)
│ cache/scratch/subcount.py
│ @@ -0,0 +1,26 @@
│ +#!/usr/bin/env python3
│ +"""Count submodule inventory rows per chapter and compare with OUTLINE."""
│ +import re
│ +from pathlib import Path
│ +CH = Path("/home/kara/code-factory/docs/handbook/chapters")
│ +total = 0
│ +for p in sorted(CH.glob("M*.md"), key=lambda x: int(re.match(r"M(\d+)", x.stem).group(1))):
│ +    t = p.read_text(errors="replace")
│ +    m = re.search(r"^## 3\. Submodule inventory$(.*?)(?=^## )", t, re.S | re.M)
│ +    if not m:
│ +        print(f"{p.stem}: NO SECTION 3"); continue
│ +    body = m.group(1)
│ +    rows = [l for l in body.splitlines() if l.startswith("|") and not set(l) <= set("|-: ")]
│ +    rows = [r for r in rows if not r.lstrip("|").strip().lower().startswith("submodule")]
│ +    ids = []
│ +    for r in rows:
│ +        cells = [c.strip() for c in r.strip("|").split("|")]
│ +        ids.append(cells[0])
│ +    total += len(rows)
│ +    print(f"{p.stem}: {len(rows)} rows  {ids}")
│ +print("TOTAL submodule rows:", total)
│ +# OUTLINE claims
│ +out = Path("/home/kara/code-factory/docs/handbook/OUTLINE.md").read_text()
│ +for pat in [r"(\d+)\s+modules?,?\s+(\d+)\s+submodules", r"Submodule chapters \| 25 \| (\d+)"]:
│ +    for mm in re.finditer(pat, out):
│ +        print("OUTLINE count claim:", mm.group(0))
│ cache/scratch/ffc_probe2.sh
│ @@ -0,0 +1,4 @@
│ +#!/bin/bash
│ +. /home/kara/code-factory/scripts/lib.sh
│ +fetch_verified http://127.0.0.1:1/nothing "$1" deliberately-wrong-digest
│ +printf "rc=%s artifact=" "$?"; [ -e "$1" ] && echo yes || echo no
VERDICT: FAIL
BLOCKING: 4 — findings that must be fixed before these chapters can be called written
NON-BLOCKING: 6

I am the round-16 seat. I judged the document against the code, and I reproduced the commands rather than reading the chapters' own assurances. What follows is what I measured on this host at code-factory `3fba8a7` (== origin/main), scheduler HEAD `bbefa36c`, crier HEAD `7220a22b`, crier-fleet `283bca9`, proxy `b12a0ac5…`.

WHAT REPRODUCED (so the record is fair before the findings):

- `python3 scripts/handbook_spine.py` → `chapters=13 canonical contracts=18 findings=0`, rc 0.
- All 349 `file:line` citations in the 13 chapters resolve to an existing file, in range. Zero out-of-range, zero unresolved. No fabricated locator found.
- M0: `bash -n` PASS; 11 direct / 17 total sourcers; metrics grep 0; the `fetch_verified` probe reproduced `rc=1 artifact=no` with `curl: (7)`.
- M1/M2/M3/M5/M6/M8 unit suites: 12 / 40 / 4 / 28 / 9 tests all OK; `bash -n` and `py_compile` clean across every cited script.
- M4: 357 rows, 519 events, `boardctl validate` → `RESULT: OK (7 warning(s))` with exactly the warnings described (CF-150/CF-192/CF-371, duplicate event line 337, headerless board); `board_drift` → byte-parity identical, 0 divergent ids, HEAD == origin/main; duplicate-id refusal and the TR-251 `--evidence-run-id` completion refusal both reproduced by me on a scratch board copy.
- M6: `master_doc_check.py` → `44 module(s): 37 VERIFIED, 50 error(s)`, `MASTER-DOC: FAIL`, rc 1 — as stated. `verify-patch.sh` → `VERIFY-PATCH: PASS` (5 stages, 4 patches, `57432007…`).
- M8: `check_scan_scope.py` → 15 claims, RESULT OK; reclaim targets (`BUILD_CACHES`/`AGED_PARENTS`/`PROTECTED`) match the code exactly.
- M9: 30 tables / 0 `verdicts`; 57 flag definitions; 43 `mux.HandleFunc` routes and the enumerated list really is 43 items; 378 `log.Printf` / 372 distinct strings; 7 `cmd/` dirs; `go build ./...` rc 0. `dispatchReplyVerdict` does read only `payload["ok"]` and treats absence as success; `payload()` is at `internal/bus/dispatch.go:175` and emits `board` with no `run_id`; `buildForemanPrompt` is at `spawn.go:1244`; `load_lane_config.py:31-37` does `UPDATE projects SET prompt=?, prompt_mode='append'`.
- M10: handler is 1895 lines, 91 test files, 67 `crier_*` strings, `go build` rc 0; the three slog lines are really at `:1332/:1795/:1885`; config defaults at `:622-673` match row-for-row; `AGENTS.md:173` does carry the `:18767`/`:18877` demo.
- M11: `dispatcher.py` 538 lines, 25 `log(` hits, 23 sites enumerated and correct; `:501` sends `ok`; the GNU-timeout/process-group analysis at `:246-262, :329` is accurate and the defect is real.
- M12: sha256 `b12a0ac5…` reproduced, 273 lines, `py_compile` PASS, unit `active`, MainPID 2603939, no-token POST → 401; `LISTEN`/`MAX_BODY`/`ALLOWED_MODELS` at `:53-62` as documented.
- Negative claims that hold: `node-bus-worker.py` has 0 `duckbrain` and 0 `boardctl|tasks.jsonl|events.jsonl` hits; crier has 0 Go files referencing `tasks.jsonl|board_ownership|boardWorkable`; `gen_nasa_handbook` has no production invoker; `check_scan_scope` has no production invoker.

FINDINGS:

1. FALSE CLAIM — M10, §7 row "slog surface". Claim: `grep -c 'slog.(Info|Error|Warn|Debug)' internal/registry/handler.go` → "PASS — exactly 3 sites". Evidence: I ran it at crier HEAD; it returns **0**, rc 1, because that is a BRE where `(` and `|` are literal. The ERE form (`grep -cE 'slog\.(Info|Error|Warn|Debug)'`) returns 3. The underlying fact (3 sites, at `handler.go:1332`, `:1795`, `:1885`) is true and the lines are correct; the quoted command does not produce the quoted result. This is precisely the defect M12 §6 flags in round 4 ("quoted command omitted `-E`, so its BRE returned 0 — the opposite of the row's claim"), repeated in this chapter. Fix: replace the row's command with the `-E` form and re-stamp; or mark the row UNVERIFIED and count it. Verifiability of a §7 table is the whole point of the table.

2. OMISSION — M10, §3 S3 "binaries, ports and services". OUTLINE M10.S3 is defined as "server :8767 / :18767, front :8770, mcp, deploy units". The chapter's S3 row covers only `config/config.go:622` (8767) and `crier-front/main.go:39` (8770). Measured: `ls cmd/` → `crier-front`, `crier-mcp`, `server`; `crier-mcp` occurs **0 times** in the chapter; `deploy/` contains `crier.service`, `crier.user.service`, `crier.backup.service/.timer`, `prometheus-scrape.example.yml` — none is named, no unit path, no args, no port for the MCP binary, no deploy/restart surface. `:18767` appears once, only as "unmeasured". The chapter does not count this in its RED list. A reader cannot start, stop or verify the crier MCP or the deployed units from this chapter, and those are in-scope operator surfaces by the outline's own wording. Fix: write S3's mcp + deploy-unit rows (unit names, paths, ports/envs, how absence is detected), or declare S3 partial and add it to the RED count.

3. OMISSION — M9, §3 durable-state keys. Claim: "The 30-table store's run-correctness keys and their relationships". Measured: 14 of the 30 tables are named nowhere in M9 — `tick_workers`, `usage_pools`, `usage_pool_leases`, `usage_pool_lease_members`, `usage_pool_memberships`, `usage_pool_deferrals`, `usage_pool_deferrals`, `feature_usage`, `hook_runs`, `host_samples`, `lane_links`, `namespace_ticks`, `remote_events`, `remote_events_stats`, `sync_spool`. Two of those are load-bearing for things the chapter itself asserts elsewhere: admission step 5 is `reserveUsagePools` (`usage_pool_policy.go:26-63`) and the reservation's durable record is the `usage_pool*` family — so the chapter documents the decision and omits the store it writes; and OUTLINE M9.S3 names `tick_workers` explicitly. None of this is in the §RED list (which names only per-failure-mode recovery indications), so the field is understated. Fix: add the `usage_pool*` and `tick_workers` keys (at minimum), or scope the S3 claim to what it actually covers and count the rest RED.

4. CONTRADICTION — the §9 log-inventory exemption is accounted two different ways across chapters, and no authority authorizes it. `MASTER-DOC-SCHEMA.md` §6 requires "every operator-visible line, verbatim"; OUTLINE §9 says "verbatim, classified descriptive or evidentiary". M1, M2 and M3 declare a "schema exemption (deepseek B4) / provisional" and then **exclude** it from their RED counts (M1 = 2, M2 = 2, M3 = 2), while M5 (4 of 215), M7 (2 of 103), M9 (376 of 378) and M10 (webhook/store/detect/federation emitters untabulated) **count** the same uncovered inventory as a named RED. Same field, same exemption, two accounting rules. Under OUTLINE Part VII.3 a "not measured" field is a named RED, so M1/M2/M3 understate their own RED counts by one. Fix: pick one rule — either the schema grants the exemption (amend the schema, then M5/M7/M9/M10 over-count) or it does not (then M1/M2/M3 add §9 to their RED counts). It cannot be both.

5. CONTRADICTION — M4's RED count contradicts M4's own accounting rule. §1/§11 declare the rule ("RED counts only fields where the writer's own evidence is incomplete (an unread body, an unrun ladder, an untabulated log inventory)"), then §7 row "lock adjudication" says "UNVERIFIED — the classifier was read in full but not exercised against a held/unheld fixture this round", and the RED count is printed as **1** (metrics only). An unrun fixture is an unrun ladder by that rule. Count is 2. Fix: either run the ABSENT/HELD/RESIDUE fixture (it is cheap — `board_lock.py` against a scratch lock) or count it.

6. CONTRADICTION — the schema's section numbering is not the chapters'. OUTLINE Part III states the authority rule ("`docs/MASTER-DOC-SCHEMA.md` §1 puts Identity first… where this list and the schema disagree, the schema wins") then lists 13 headings, and every chapter implements 1–13: §3 = Submodule inventory, §5 = Settings register, §8 = Metrics, §9 = Log lines. The schema says §3 = Dependencies (3a/3b/3c), §4 = Verification, §5 = Metrics, §6 = Log lines, §7 = Failure modes, §8 = Evidence. So a worker told to fill "schema §5 Metrics" opens §5 and finds a settings table; a reader told "§3c names both sides of every wire" finds the store census. The content exists (it is all present, relocated), so this is an authority/numbering defect rather than missing fields — but it is the exact seam a work-derivation pass (Part VII.2 "each citing the section it closes") will miscite 13 times. Fix: either renumber the chapters to the schema, or amend the schema/OUTLINE so one document is authoritative for section numbers.

7. CONTRADICTION (count) — "13 modules, 48 submodules" vs 50 inventory rows. Distinct submodule IDs still total 48, but the chapters carry 50 §3 rows: M1 splits S1 into two rows ("disk floor", "bunker server") and M3 relabels S1 as S1a/S1b. `handbook_spine.py:401` sets `"submodule": None`, so no submodule count is ever compared — the gate is structurally blind here, which is why this survived. Non-blocking because the ID count is defensible; fix by stating "48 submodule ids, 50 rows (M1.S1 and M3.S1 each carry two units with different classifications)".

8. CONTRADICTION (stale exhaustiveness) — M9 §1 and M10 §1 quote closed-world `git diff` results that no longer hold. M9: "`git diff --name-only 34e44897..HEAD` returns only board JSONL and `.qa/chaos-probes/errorpath.sh`" — measured now: a **fourth** path, `internal/scheduler/usage_pool_policy_test.go`, and HEAD is `bbefa36c`, not the stated `81ce9fcb`. M10: "`git diff --name-only 0a372209..HEAD` = `README.md` only" — measured now: board JSONL, `.gitreins/tasks.yaml`, `README.md`, and HEAD is `7220a22b`, not `fa619c22`. In both cases the *conclusion* (cited Go files unchanged) survives — no `.go` file is in either diff — but the quoted output is not repeatable, which is rule 4. This is drift after the stamp, not fabrication; keep the claims, date them, and stop asserting the diff is exhaustive.

9. CONTRADICTION (minor, ownership) — M0 §12 says "F2 PROVISIONING uses `require_disk` (M1) and `fetch_verified` (M5)". `fetch_verified` is defined in `lib.sh:19-42` — M0's own unit, as M0 §3/§4 and M5 §12 both state. Fix the parenthetical to M0.

10. OMISSION (document-level) — Part II is empty. All 16 flows are `(MISSING)`; every chapter's §12 says so honestly, and the spine's count check hardcodes `"flow": 16` so a chapter repeating "16 flows" passes. Also absent: Part V settings register as a document (the material is only per-chapter), Part VI quadrants, Part VII requirement/task tables, Part VIII. The chapters are gradeable; the handbook is not deliverable. This is a non-blocking finding for the chapter round and a blocking one for the document round that follows.

DEFECT CLASSES: unevidenceable command (BRE vs ERE, repeated from a prior round's own finding); submodule-under-scope (a declared submodule half-written; the omission not counted in RED); store-inventory gap where the decision is documented and the durable record is not; internally inconsistent RED accounting for one declared exemption; schema/outline numbering split with a stated precedence rule that is then not followed; stale closed-world git facts presented as current; count claims the spine is structurally blind to; document-level parts unwritten while chapters are complete.

CHAPTER SCORECARD:

- M0 — WRITTEN. Every schema field filled, every claim carries `file:line`, both §7 probes reproduced by me, 1 RED (metrics, absence-proved with a 0-match grep). One cosmetic cross-reference error (§12 "fetch_verified (M5)").
- M1 — PARTIAL. Source-complete and the settings surface is exhaustive (I re-derived the ROLE_DEFAULTS, TTL, budget, verify-node port validation, and the six-flag precedence). Cannot be WRITTEN: certification ladder unrun (needs a live node), §9 counted-not-enumerated and excluded from the RED count.
- M2 — PARTIAL. Reply shape, `SECTION5_INTS`, inbox/lease/seen defaults and the dry-run lease all verified exactly. §7 live ladder not repeatable from this host; §9 excluded from RED count.
- M3 — PARTIAL. Landing arm boundaries (`:2463-2729`, `:3433-3670`) resolve, `GATE=""`/`run_gate` guard verified, F3-2/F3-5 true. Hook *enforcement* unproven (declared), §9 excluded from RED count.
- M4 — PARTIAL. Store, drift, validate, duplicate-id and TR-251 refusal all reproduced by me. Not WRITTEN because the lock classifier was never exercised and the RED count says 1 where its own rule says 2.
- M5 — PARTIAL. Adapter matrix, pins, python gate `>=3.11,<3.14` and `[0-7]00` predicate all verified; resolver CLI surface verified. Conformance battery unrun; §9 4 of 215 uncovered (correctly counted).
- M6 — PARTIAL. The gate's real behaviour is documented honestly (structural, not semantic; FAIL over 44/37/50 reproduced), the spine's five checks and its two blind spots are named. Not WRITTEN: own gate reads FAIL, and the render-to-owner leg does not select `M*.md` at all (CT-18).
- M7 — PARTIAL. CLI rc 2, mode-0600 key rule, `MIN_AGE` 2400 s and the `--dry-run`/`--quiet` correction verified; mint unrun (no App creds on this host, environment-gated), §9 2 of 103 (counted).
- M8 — WRITTEN. Both units read in full, all three §7 checks reproduced, targets and TTL semantics match the code exactly, 1 RED (metrics, absence-proved).
- M9 — PARTIAL. The strongest chapter on measurement (57/43/30/378/372 all exact; admission procedure and settlement defect both verified against source) but 7 declared REDs plus the unnamed `usage_pool*`/`tick_workers` store keys and a stale closed-world diff.
- M10 — PARTIAL. 1895-line body genuinely read; guard/metrics/custody/service-auth all check out against source; three REDs declared. Not WRITTEN: S3 omits `crier-mcp` and every deploy unit, and the §7 slog row's command does not reproduce.
- M11 — PARTIAL. 538 lines read, all 23 log sites correct, the deadline-kill descendant defect is real and correctly reasoned. The live-job tests are decoration (no assert) — honestly declared — and metrics are absent.
- M12 — PARTIAL. Hash, admission 401, unit state, sink paths and the `[200, 502]` framing analysis all verified. Streaming is FAILING (F12-7), and four of its fields are UNVERIFIED — the chapter says so plainly, which is the correct behaviour and still not WRITTEN.

The document is far better than a rejected draft: the locators are real, the counts are real, the defects it names are real, and it repeatedly corrects its own prior rounds with measurements. It still fails this round because four fields are demonstrably not as claimed — one evidence row that cannot be replayed, two declared submodules/stores that are half-written without being counted, and one RED-accounting rule applied two ways in the same document while the schema that owns the field says neither is allowed.

PANEL REVIEW COMPLETE

session_id: local-b68e1a04158329723d0bd139e3a7705a9cf9f5ec7095953229dd7c627c6d0dfb

EXIT=0
```

### kimi

```
│ cache/scratch/spine_negctl.py
│ @@ -0,0 +1,24 @@
│ +import pathlib, subprocess, sys
│ +
│ +S = pathlib.Path("/home/kara/.hermes/cache/scratch/spine-negctl-djsa")
│ +
│ +m0 = S / "docs/handbook/chapters/M0-shared-contract.md"
│ +out = []
│ +for l in m0.read_text().splitlines():
│ +    out.append(l)
│ +    if l.startswith("| (local) | bunker CLI |"):
│ +        out.append("| CT-99 | bogus peer | out | `a.py:1` `x()` | `b.py:2` `y()` | works |")
│ +m0.write_text("\n".join(out) + "\n")
│ +
│ +m5 = S / "docs/handbook/chapters/M5-harness.md"
│ +out = []
│ +for l in m5.read_text().splitlines():
│ +    out.append(l)
│ +    if l.startswith("| `CF_MAX_TURNS` | 40"):
│ +        out.append("| `CF_TIMEOUT_S` | 99 (`harness-vars.sh:1`) | 1..9 | turn | refused |")
│ +m5.write_text("\n".join(out) + "\n")
│ +
│ +r = subprocess.run([sys.executable, str(S / "scripts/handbook_spine.py")],
│ +                   capture_output=True, text=True)
│ +print(r.stdout)
│ +print("exit:", r.returncode)
VERDICT: FAIL
BLOCKING: 10
NON-BLOCKING: 6

Spine gate, run as instructed at 2026-11-06T22:21-05:00 (code-factory HEAD `3fba8a7`):
`python3 scripts/handbook_spine.py` → `chapters=13  canonical contracts=18  findings=0`, exit 0. No blocking CONTRADICTION from the gate.
I also ran a negative control on a scratch copy (same script, chapters copied, two defects injected inside §6 and §5): it returned `findings=2 CONTRACT UNKNOWN ID=1 SETTING CONFLICT=1`, exit 1 — the gate can fail, so the zero is a real zero, not a vacuous pass. Its scope limit is filed below (N-4).

FINDINGS

B-1. OMISSION — M0–M12, §6 (all 13 chapters)
Claim: each chapter's contract register is presented as the complete record of an interface (six columns: ID, Peer, Direction, Producer, Consumer, State).
Evidence: `OUTLINE.md` Part IV requires per contract "producer file:function, consumer file:function, payload, timing, failure semantics, measured state, breaking-change policy" — seven fields. No §6 table in any chapter carries payload, timing, failure semantics or breaking-change policy as a field; e.g. `M10-crier.md:148-151` (CT-02/CT-03/CT-04/CT-08) and `M9-scheduler.md:232-238` give state words and code locations only. Payload detail exists only as prose in three rows (CT-02's envelope fields), never as a per-contract field.
Fix: add the four missing fields per row (payload shape; timing/timeout; failure semantics; compatibility/breaking-change rule), each with `file:line`, or an adjacent per-contract table. This is the outline's own definition of the register, not a schema nicety.

B-2. OMISSION — document-level (OUTLINE Part II), cited in every chapter's §12
Claim: `documents/handbook/OUTLINE.md` Part II commits to 16 flows, each with 12 elements (trigger, exit, actors, preconditions, numbered steps, branches, state transitions, contracts, timing, duplicate case, empty case, degradation, diagram).
Evidence: zero flow chapters exist — `docs/handbook/chapters/` holds only `M0..M12`; `docs/handbook/README.md:41-58` marks II.1–II.16 **MISSING**; chapters defer to a chapter that does not exist (`M1:270`, `M2:203`, `M3:192`, `M4:172`, `M9:330`, `M11:196`). The document's own primary-flow owner (M3 owns F5, M9 owns F11) therefore has no flow chapter.
Fix: this is admitted (F-ROOT-1) but admission is not delivery. Write F11 then F1 (the two the control plane actually runs), or amend Part II to a smaller committed set with the owner's sign-off; a document that cannot satisfy its own structure is not PASS-able.

B-3. CONTRADICTION — M4 vs M9/M12 (red/status accounting rule)
Claim (M4:199-204): "**RED accounting rule (uniform across M4/M5/M6/M7/M8, round 16 — glm #4):** a contract row in §6 whose far side is an external peer … is **not** counted as a RED."
Claim (M9:377-378): "Rule applied this round (glm #4): an UNVERIFIED contract state — boundary or internal — is a named RED"; M12:229-231: "an UNVERIFIED contract state — boundary or local — and a FAILING submodule are both named REDs".
Evidence: both sentences cite the same round-16 seat ruling and reach opposite conclusions for the same class (boundary UNVERIFIED): M4 RED=1, M9 RED=7 (counts CT-01 and CT-15, both boundary), M12 RED=5 (counts CT-07, boundary), while M5 counts CT-17 UNVERIFIED but excludes M5-C2, and M10 excludes its boundary CT-08. The spine compares §6 state *words*, not RED tallies, so it cannot catch this.
Fix: one rule, stated once in `MASTER-DOC-SCHEMA.md`, then recompute all 13 tallies. As written, "is this chapter written" changes answer depending on which chapter you read.

B-4. CONTRADICTION — OUTLINE Part VII.3 vs `docs/MASTER-DOC-SCHEMA.md` vs all 13 chapters
Claim (OUTLINE Part VII.3): "A chapter is **WRITTEN** only when every schema field (§1–§13) is filled with evidence."
Evidence: the schema defines **eight** sections (`MASTER-DOC-SCHEMA.md:12-101`: 1 Identity, 2 Purpose, 3 Dependencies, 4 Verification, 5 Metrics, 6 Log lines, 7 Failure modes, 8 Evidence). All 13 chapters deliver **thirteen** sections with different meanings (§5 = Settings register, §8 = Metrics, §9 = Log lines, §10 = Failure modes). OUTLINE Part III also states "Where this list and the schema disagree, **the schema wins**" — the chapters do the opposite. Consequence in practice: `M4-board.md:199` cites "absence-proved metric (§5 'none' is RED)" — schema §5 is Metrics, chapter §5 is Settings; the pointer is wrong in the delivered artifact.
Fix: rewrite the schema to the 13-section contract the chapters use (or renumber every chapter to §1–§8), and correct Part VII.3's "§1–§13". Until then the acceptance gate has no definition to grade against.

B-5. FALSE CLAIM — M9 §1 (revision)
Claim: "HEAD has since advanced to `81ce9fcb` … Cited Go source files are byte-identical to the round-11 stamp `34e44897` — `git diff --name-only 34e44897..HEAD` returns only `.coding-hermes/board/events.jsonl`, `.coding-hermes/board/tasks.jsonl` and `.qa/chaos-probes/errorpath.sh`."
Evidence (measured this round): HEAD = `bbefa36c` (`bbefa36c merge(QA-CHS-188)…`, `b0da3761 test(scheduler): join the slot-timeout lease before asserting it`). `git diff --name-only 34e44897..HEAD` returns **four** paths, including `internal/scheduler/usage_pool_policy_test.go`. The quoted command no longer produces its quoted output, so the chapter's own repeatability rule fails on its revision stamp.
Fix: re-stamp (`81ce9fcb` → `bbefa36c`), re-run the diff and quote it, and state that a test file inside `internal/scheduler` changed after the `go test` run (`M9:252`, rev `34e44897`) — the 25/25 PASS is not at the re-stamped tree. (I re-ran `go build ./...` at `bbefa36c`: rc 0. I did not re-run the 275s suite — say so in the row rather than letting the old revision carry it.)

B-6. FALSE CLAIM — M10 §1 (revision)
Claim: "HEAD has since advanced to `fa619c22` — three README-only merges, `git diff --name-only 0a372209..HEAD` = `README.md` only".
Evidence (measured): HEAD = `7220a22b`; `git diff --name-only 0a372209..HEAD` = `.coding-hermes/board/events.jsonl`, `.coding-hermes/board/tasks.jsonl`, `.gitreins/tasks.yaml`, `README.md`. No Go file changed, so the conclusion ("every cited Go file is byte-identical") still holds and I re-ran the suite at current HEAD: `go test -count=1 ./...` → 41 `ok` + 3 `[no test files]`, 0 FAIL, 41s — the substance is right, the quoted command and HEAD label are wrong.
Fix: re-stamp to `7220a22b`, quote the real diff, and keep the measured PASS at that HEAD (it reproduces).

B-7. FALSE CLAIM — M9 §1 and M10 §1 (host toolchain)
Claim (both chapters, verbatim shape): "`/usr/bin/go` = **go1.26.9** (`/usr/lib/go-1.26/bin/go`; measured `readlink -f /usr/bin/go` + `/usr/bin/go version`)".
Evidence (measured): `/usr/bin/go version` → `go version go1.26.8 linux/amd64`; `/usr/lib/go-1.26/bin/go version` → same; `/usr/lib/go-1.26/VERSION` → `go1.26.8` (file dated 2026-08-28); `dpkg -S` → `golang-1.26-go`. The claimed 1.26.9 does not exist on this host, so this was not re-measured, despite the cell claiming a measurement. (`/home/kara/.local/bin/go` → `sdk/go1.26.5/bin/go` is correct, and `go env GOVERSION` in both repos resolves `go1.26.10`, so the GOTOOLCHAIN argument survives.)
Fix: correct both to go1.26.8 and re-run the quoted commands; the fact that two chapters repeat the same unmeasured number is the defect class, not the digit.

B-8. CONTRADICTION — M6 §3 (S1, S3) vs M3 §3 (S1a), with M2 §3 (S3) and M4 §3 (S1)
Claim (M6:42, 44): "S1 skeleton + census … **active** | `main()` entrypoint; structure-mapped" and "S3 gate … **active** | `main()` at `:160`".
Claim (M3:37): "…`clone_lane.py` … **operator-invoked (optional)** … (B07 / sol B09 re-grade: was misclassified **active** on the strength of a `main()` entrypoint, which proves executability, not activation)".
Evidence: the document rules twice, oppositely, on identical evidence. `grep -rn master_doc_skeleton scripts/ tests/ config/` finds no invoker (only a `.pyc`); `grep -rn 'boardctl create'` in-repo finds none; M2:35 and M4:33 likewise classify "active" from in-file call sites (`process`/`adjudicate`) rather than an invoking lane, cron, timer or unit, which OUTLINE Part III's classification rule requires.
Fix: apply one rule. Either `main()`/in-file call sites is insufficient (then M2 S3, M4 S1, M6 S1/S3/S4 become `unproven`/operator-invoked), or it is sufficient (then M3 S1a's re-grade is wrong). State the ruling once in OUTLINE Part III.

B-9. FALSE CLAIM — M10 §6, CT-02 row
Claim: "**This supersedes OUTLINE Part IV's \"scheduler → crier … broken\"** and README I.3's \"10 works / 6 broken / 2 missing\"".
Evidence: `OUTLINE.md` Part IV records CT-02 as **works** ("CT-02 scheduler → crier … **works** *(M9 §6 / M10 §6; CF-354 fixed node-side)*"), and Part I.5 already marks the "10 works / 6 broken / 2 missing" figure superseded structure text. There is no "broken" annotation for CT-02 to supersede; the sentence invents a defect in the document it is correcting.
Fix: delete the sentence, or cite the actual stale artifact (the pre-round-10 register text) instead of Part IV.

B-10. CONTRADICTION — self-declared RED tallies omit the chapters' own unmeasured fields (M4, M3, M10, M8)
Claim (M4:197): "RED field count: 1 (Metrics §8 — absence-proved)"; M3:216: "RED field count: 2"; M10:292-297: "RED field count: 3"; M8:146: "1".
Evidence: each of those chapters has an unrun check in its own §7/§9 that its tally does not carry — M4:111 "lock adjudication … **UNVERIFIED** — … not exercised against a held/unheld fixture"; M3:128 `cf244-node-freshness` "**UNVERIFIED** — arm present … not re-run"; M10:164 signed-read ladder "PASS (FACT-04) — not repeatable from this control host" (2026-11-05 provenance, judged 2026-11-06); M8 §9 tabulates 5 lines but the module emits more — `check_scan_scope.py:93,94,99,100,103,107` (`FAIL audit-scope …`, `RESULT: FAIL (…)`) and `reclaim_disk.py:140,164` (`--help` target list, JSON out) are unlisted and uncounted. M1/M2/M9/M12 do count their unrun rows, so the tallies are not computed the same way.
Fix: one tally method (count every UNVERIFIED/not-measured field), recompute, and add the missing M8 §9 lines. A RED count that omits the chapter's own unverified rows is the exact under-report the schema exists to prevent.

N-1. CONTRADICTION — M0 §12 helper ownership
Claim (M0:163): "F2 PROVISIONING uses `require_disk` (M1) and `fetch_verified` (M5)".
Evidence: both are `lib.sh` helpers owned by M0 and listed in M0 §3 — `require_disk` (`lib.sh:48-57`), `fetch_verified` (`lib.sh:19-42`). Only `harness-vars.sh` belongs to M5.S5.
Fix: "(M0)" for both, or reword as "M1 and M5 chapters cite these M0 helpers".

N-2. UNVERIFIED (locator drift) — M3 §7/§10, cf213 sub-arm ranges
Claim: "gate rejection (`:2541-2548`), dry-run (`:2551-2563`), successful landing and fresh-clone proof (`:2566-2584`), repeat landing (`:2586-2595`)".
Evidence (measured in `tests/selftest.sh`, 4852 lines): red-gate rejection is `:2546-2553`; `--dry-run` case is `:2555-2568`; the landing + fresh-clone proof is `:2570-2588`; repeat-landing is `:2590-2615`. Each cited range starts ~4 lines early and inside the previous case's tail. The arm's outer bounds (`:2463` BEGIN / `:2729` END) and `cf244` (`:3433`/`:3670`) are exact.
Fix: re-pin the four sub-ranges.

N-3. PADDING — audit-round archaeology inline in chapters
Claim/example: M1:64-72 ("Round-6's \"deletes without reporting them as data loss\" was **false** (B02, sol)"), M6:96-110 ("**Round 16 fixed the column-slicing blind spot (grok #4)**"), M9:180-215 ("expanded this round — sol B15"), M10:134-136 ("Contradicting artifact (N4, locator re-pinned)").
Evidence: these are supersession records and seat citations, which OUTLINE Appendix D ("Change log and supersession record") exists to hold. Inside a chapter they are unactionable to a reader who has no access to round-9/round-15 verdict files.
Fix: keep one line of current fact per item, move the "round N said X, seat Y corrected it" history to Appendix D and reference it.

N-4. CONTRADICTION — M6 overstates the spine gate's scope
Claim (M6:50): "(2) … an id outside the register is **rejected** (`CONTRACT UNKNOWN ID`, `:267`)" and "(3) setting-default conflicts (`SETTING CONFLICT`, `:365`)".
Evidence: both checks are section-scoped — `handbook_spine.py:130` reads only `section(text, 6)` and `:356` only `section(text, 5)`. Controlled test this round: identical injected defects returned `findings=0` when appended outside the §6/§5 table and `findings=2` (unknown id + setting conflict, exit 1) when placed inside it. M6 §5 lists the gate's other blind spots (no locator-existence check, trusts self-reported status) but not this one.
Fix: add the §5/§6-only scope to M6 §5's blind-spot list (or widen the scan to the whole chapter text for CT-id citations).

N-5. UNVERIFIED (rule 2, both sides as `file:function`) — CT-06 producer, M9 §6 and M11 §6
Claim: producer "`dispatcher.py:500-508` builds the completion reply `{in_reply_to, agent, ok, …}`".
Evidence: `dispatcher.py:500-508` is an inline dict literal inside the main loop; neither chapter names the enclosing function (`main`) or the call (`crier.deliver(..., sender=agent)`, `:508`). Rule 2 asks for producer as `file:function`; a bare line range cannot be matched against a peer row by function name (which is why the spine's function-token comparison silently skips this contract).
Fix: name it — "`dispatcher.py:main` (reply build `:500-508`, `crier.deliver` `:508`)" — in both rows.

N-6. CONTRADICTION (count) — 48 submodules claimed, 50 rows delivered
Claim: `OUTLINE.md:95` "PART III — MODULES (13 modules, 48 submodules)"; `README.md:28` "13 modules, 48 submodules".
Evidence: §3 tables contain **50** rows over 49 distinct submodule labels — M1 splits S1 into two rows (`disk floor`, `bunker server`) and M3 introduces `S1a`/`S1b` where the outline lists `S1–S3`. The spine cannot catch it: `handbook_spine.py:401` sets `"submodule": None`, so no submodule count is ever compared (M6 documents that gap at :50).
Fix: state the counting convention (rows vs ids) in Part III and align either the outline total or M1/M3's labels.

DEFECT CLASSES
- contract-field omission (Part IV's seven fields → six columns; all chapters)
- structural omission against own outline (16 flows, Parts I/V/VI/VII/VIII)
- cross-chapter rule contradiction (RED accounting; activation classification; schema section numbering)
- stale revision stamp / quoted command no longer reproducible (two repos)
- unmeasured host fact repeated in two chapters as "measured" (go 1.26.9)
- false supersession claim about the document itself
- RED tally undercount vs the chapter's own UNVERIFIED rows
- locator drift inside a correct outer range
- evidence-granularity shortfall (file:line where file:function is required)
- audit-round history left inline (padding)
- gate-scope overstatement (spine described wider than it scans)
- count claim not covered by any check (submodules)

CHAPTER SCORECARD
- M0 — PARTIAL. Strongest chapter: helper inventory, dependency table, settings row, metrics absence, 7 log lines and the `fetch_verified` probe all reproduce (`bash -n` rc 0; 11/17 source counts exact; `lib.sh:13/19-42/48-57/60-64/67-70/75-78` all exact). Not WRITTEN because §12 misattributes its own two helpers to M1/M5 (N-1), and §6's local row still lacks payload/timing/failure/compat.
- M1 — PARTIAL. Every locator I checked is exact (`verify-node.sh:20,25,40,46,51,73,76,106,177,225,233,241`; `node_seed.py:43,44,130-140,147,280-290,341,353,360`; `disk_floor.py:36,115-141`; `${TTL:-6h}` at `:356`; `:552` destroy refusal). Partially blocked by: certification ladder unrun (RED, honest), §9's 141-site "counted, not enumerated" exemption is a writer's argument awaiting approval, and B-1's missing contract fields.
- M2 — PARTIAL. Locators exact (`node-bus-worker.py:81,82,85,113,129,977,989,1007,1176,1180,1200-1205,1208,1312,1389,1402,1478,1511,1520`); the bus cap citation matches (`handler.go:1718-1731`, 400 `max must be <= 100`). Blocked by: live bus ladder not repeatable here (RED, honest), S3 labelled `active` on in-file call sites (B-8), §9 exemption, B-1.
- M3 — PARTIAL. Counting rule is applied honestly here (S1a/S1b demoted on evidence) and the landing script's claims reproduce (`:38,58,74-75,108,124,192,206,244,278,288,295,299,304,307`). Blocked by: hook *enforcement* unverified (honest RED), `cf244` arm unrun and uncounted (B-10), drifted §7 sub-ranges (N-2), B-1.
- M4 — PARTIAL. Store claims reproduce exactly — 357 rows / 519 events, `boardctl validate` `RESULT: OK (7 warning(s))` with the seven warnings as described, `board_drift` `RESULT: OK` with sha256 `5aa15431…`/`783d556c…` and HEAD == origin/main == `3fba8a7`; `board_lock.py:21,49,73,97,118,149-158` exact. Blocked by: lock classifier unexercised but not in the RED count (B-10), B-1, and its RED rule conflicting with M9/M12 (B-3).
- M5 — PARTIAL. Settings and installer evidence exact (`harness-vars.sh:28,31,176,181,203,204,276,277,281,287,313`; `harness_resolve.py:284,387-389`; opencode/deepseek/pi `--apply` refusals at `:92-93`/`:96`/`:108`; `project-node.sh:440,449-452`). Blocked by: conformance battery unrun (RED, honest), §9 covers 4 of 215 helper sites (honest RED), B-1.
- M6 — PARTIAL. Gate measurements reproduce: `master_doc_check.py` rc **1**, `44 module(s): 37 VERIFIED, 50 error(s)`, `MASTER-DOC: FAIL`; `verify-patch.sh` `VERIFY-PATCH: PASS` (5 stages, 4 patches, `57432007…`); glob and locator citations exact (`:52,128,160,188,220,263`); `panel_loop.py:323-342,351-357,381-385,410,442-454` exact. Blocked by: own gate reads FAIL (honest RED), spine scope overstated (N-4), B-1, B-4.
- M7 — PARTIAL. CLI surface reproduces (`github-app-token.py` with no subcommand → rc 2); locators exact (`:45,47,295,305,344,362,371,579,598,606,719`); the credential-domain correction (F7-3) is right. Blocked by: mint unrun (environment-gated RED, honest), §9 2 of 103 sites (honest RED), B-1.
- M8 — PARTIAL. `check_scan_scope.py` reproduces (`15 gitleaks claim(s)`, `RESULT: OK`); constants exact (`reclaim_disk.py:14-22,42,46,90,102-111,135,160-162`; `check_scan_scope.py:31-32,64-68,110,112`). Blocked by: §9 inventory incomplete and not counted as RED (B-10) — six operator-visible lines missing — plus B-1 for its local row.
- M9 — PARTIAL. The most load-bearing chapter and, citation for citation, accurate: 43 routes, 57 flags, 30 tables, 378/372 `log.Printf` sites, 7 `cmd/` dirs, `dispatch_leg.go:252,260,709-726`, `admission_mode.go:98,112,143,177,234,266`, `dispatch.go:170-175,202`, `migrations.go` and `execution_store.go` locators, `server_metrics.go:30,42,65,76,87,101,125,195,426`, `packer_select.go:462,602`, `load_gate.go:38,63,93`, `peers.go:28`, `loader.go:421-422`, six doctrine docs present. Blocked by B-5 (stale revision, false quoted diff), B-7 (go 1.26.9), B-10 (three UNVERIFIED contracts counted, own rule), B-1, plus its self-declared REDs: §9 376/378 uncovered, S4 per-route shapes, §5 reader precedence.
- M10 — PARTIAL. Handler/custody evidence exact (`handler.go:598,990,1147,1332,1690,1711,1718-1731,1734,1770,1795,1812,1885`; `service_auth.go:128-168`; `agentsig.go:167,204,364-368`; `guard.go:25,167,198,318,332,430-458`; `config.go:622,627-654,673`; TS client `:561-603`; `crier_client.py:975,1009,1038`); 3 slog sites, 0 `log.Printf`/`fmt.Printf`, 91 test files, 67 metric strings — all reproduce; `go test` reproduces at current HEAD. Blocked by B-6, B-7, B-9, and its own REDs (§8 per-metric contract, §9 beyond 5 sites, §5 custody proof).
- M11 — PARTIAL. Best-verified chapter in the set: 538 lines, exactly 23 `log()` call sites plus the `:81` comment and `:112` def, every one of the 23 lines at the stated number. Blocked by: §7 test row is decoration the chapter admits (RED), F11-8's descendant-kill claim rests on a round-5 disposable execution this judge cannot repeat (UNVERIFIED, honest), B-1, N-5.
- M12 — PARTIAL. Content sha256 `b12a0ac5…` reproduced, 273 lines, live 401 reproduced, systemd unit active with the named drop-in (PID differs from the stamped 2603939 because the stamp is a day old), four grep sites at the stated lines (`panel_loop.py:188`, `master_doc_skeleton.py:25,211`, `node.env.example:22`), sink constants exact (`:48-54`). Blocked by: streaming **FAILING** (F12-7, honest RED), M12-C1/M12-C2/CT-07 UNVERIFIED, metrics absence (RED), B-1.

No chapter is a SKELETON — every one carries real code evidence at `file:line` and none invents a citation I could break. That is why this is a close FAIL on structure and rule-consistency, not on accuracy: the system descriptions are trustworthy, the document is not yet the document its own outline and field contract describe, and two chapters carry measurements that no longer reproduce.

PANEL REVIEW COMPLETE

session_id: local-acf3550d6a523af1a2d716a12597b3af1343ffd18ed9ccf61f0a0e0ba24b89ae

EXIT=0
```

### sol

```
│ cache/scratch/round16-sol-judge-probes.py
│ @@ -0,0 +1,151 @@
│ +#!/usr/bin/env python3
│ +"""Read-only source audit, isolated local fixtures; no fleet credentials."""
│ +import ast
│ +import contextlib
│ +import fcntl
│ +import http.client
│ +import importlib.util
│ +import json
│ +import os
│ +from pathlib import Path
│ +import signal
│ +import subprocess
│ +import sys
│ +import tempfile
│ +import threading
│ +import time
│ +from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
│ +from unittest.mock import patch
│ +sys.dont_write_bytecode = True
│ +ROOT = Path('/home/kara/code-factory')
│ +
│ +def load(name, path):
│ +    spec = importlib.util.spec_from_file_location(name, path)
│ +    mod = importlib.util.module_from_spec(spec)
│ +    spec.loader.exec_module(mod)
│ +    return mod
│ +
│ +spine = load('judge_spine', ROOT / 'scripts/handbook_spine.py')
│ +print('SPINE_DECIMAL_DEFAULTS', json.dumps({v: spine.norm_default(v) for v in ['0.15', '0.66', '1.0', '1.9']}))
│ +print('SPINE_CLI_SETTING_RECOGNIZED', bool(spine.SETTING_ROW.match('| `--timeout` | 30 | seconds | effect |')))
│ +print('SPINE_FUNCTION_REFERENCE_BARE_FILENAME_ACCEPTED', spine.has_fq('dispatcher.py'))
│ +print('SPINE_INLINE_FUNCTION_TOKENS', sorted(spine.func_tokens('`dispatcher.py:500-508` builds completion')))
│ +
│ +with tempfile.TemporaryDirectory(prefix='round16-judge-', dir=os.environ['TMPDIR']) as temp:
│ +    td = Path(temp)
│ +    proxy = load('judge_proxy', '/home/kara/.hermes/scripts/cf-inference-proxy.py')
│ +    proxy.TOKENS_PATH = td / 'tokens.json'
│ +    proxy.TOKENS_PATH.write_text(json.dumps({'fixture-node': 'fixture-only-not-a-real-token'}))
│ +    proxy.CAPTURE_LOG = td / 'requests.jsonl'
│ +    proxy.USAGE_LOG = td / 'usage.jsonl'
│ +    proxy.upstream_key = lambda: 'fixture-key-not-a-real-credential'
│ +    proxy.ALLOWED_MODELS = {'hermes'}
│ +    class Upstream(BaseHTTPRequestHandler):
│ +        def do_POST(self):
│ +            self.rfile.read(int(self.headers.get('Content-Length', 0)))
│ +            body = b'data: [DONE]\n\n'
│ +            self.send_response(200)
│ +            self.send_header('Content-Type', 'text/event-stream')
│ +            self.send_header('Content-Length', str(len(body)))
│ +            self.end_headers()
│ +            self.wfile.write(body)
│ +        def log_message(self, *args):
│ +            pass
│ +    upstream = ThreadingHTTPServer(('127.0.0.1', 0), Upstream)
│ +    proxy.UPSTREAM = 'http://127.0.0.1:%d' % upstream.server_port
│ +    server = ThreadingHTTPServer(('127.0.0.1', 0), proxy.Handler)
│ +    threads = [threading.Thread(target=s.serve_forever, daemon=True) for s in (upstream, server)]
│ +    for thread in threads:
│ +        thread.start()
│ +    try:
│ +        conn = http.client.HTTPConnection('127.0.0.1', server.server_port, timeout=1)
│ +        body = json.dumps({'model': 'hermes', 'stream': True})
│ +        conn.request('POST', '/v1/chat/completions', body, {'Authorization': 'Bearer fixture-only-not-a-real-token', 'Content-Type': 'application/json'})
│ +        resp = conn.getresponse()
│ +        result = {'status': resp.status, 'content_length': resp.getheader('Content-Length'), 'transfer_encoding': resp.getheader('Transfer-Encoding'), 'connection': resp.getheader('Connection')}
│ +        try:
│ +            result['body'] = resp.read().decode()
│ +            result['eof_completed'] = True
│ +        except TimeoutError:
│ +            result['eof_completed'] = False
│ +            result['read_error'] = 'TimeoutError'
│ +        print('ISOLATED_PROXY_HEALTHY_SSE', json.dumps(result))
│ +        conn.close()
│ +    finally:
│ +        for s in (server, upstream):
│ +            s.shutdown()
│ +            s.server_close()
│ +
│ … omitted 73 diff line(s) across 1 additional file(s)/section(s)
VERDICT: FAIL
BLOCKING: 27 — findings that must be resolved before the affected chapters can be called WRITTEN
NON-BLOCKING: 0

FINDINGS:

Reviewed all 13 chapters against OUTLINE.md, MASTER-DOC-SCHEMA.md, and the implementing source in the five specified systems. Findings below distinguish incorrect documentation from correctly disclosed but still blocking RED fields.

Source-path abbreviations:
  CF = /home/kara/code-factory
  SCH = /home/kara/coding-hermes-scheduler/coding-herms-scheduler
  CR = /home/kara/crier
  DISP = /home/kara/crier-fleet
  PROXY = /home/kara/.hermes/scripts/cf-inference-proxy.py

Chapter references below are under CF/docs/handbook/chapters/.

B01 — FALSE CLAIM — M2, M10, M11 — Protected-service delivery is documented with the wrong wire header, and the node’s signing is mischaracterized.

  Claim: M10-crier.md:66 and M11-dispatcher.md:104 name “X-Crier-Service-Audience”. M2-dispatch.md:125 says the node’s reply “satisfies none of those” controls.

  Evidence: CR/internal/registry/agentsig.go:35 defines HeaderServiceAudience as “X-Crier-Audience”. CR/clients/python/crier_client.py:846-848 sends that header and appends the audience to the signed transcript. CF/scripts/node-bus-worker.py:328-338 supplies X-Agent-ID and a body-bound signature; :1208-1215 uses those headers for replies. The node lacks the body sender, idempotency key and audience, but it does not lack signed-sender/body-binding controls.

  Fix: Correct the literal header everywhere. Document the exact transcript and identify which controls each client actually supplies. Do not describe all protected-delivery requirements as absent when some are implemented.

B02 — CONTRADICTION — M0–M12 — There is no uniform RED-accounting rule.

  Claim: M4-board.md:199-204 declares boundary/local UNVERIFIED contracts “terminal” and “not counted as a RED”. M1, M2, M3, M5, M6, M7 and M8 adopt that exemption. Conversely, M9-scheduler.md:375-378 and M12-inference-proxy.md:227-231 explicitly count boundary UNVERIFIED contracts as RED.

  Evidence: The same unresolved evidence state is treated differently across chapters. MASTER-DOC-SCHEMA.md:7-8 makes an unfilled required field RED; :56-57 requires both implementing sides. OUTLINE.md:274-275 calls an unmeasured field UNVERIFIED and RED. The two-register convention does not itself approve a completeness exemption.

  Fix: Establish one approved rule and rederive every RED summary from it. Keep external boundaries honestly identified, but do not silently convert unverified evidence into completed fields. The spine’s findings=0 does not detect this contradiction.

B03 — OMISSION — M2, M9, M11 — Internal contracts still omit implementing function names.

  Claim: M9-scheduler.md:243 says CT-05 “names both file:function”. Its producer cell at :237 supplies load_lane_config.py:31-37, not a function. CT-06 producer cells in M9:236 and M11:100 similarly identify dispatcher.py:500-508 without naming main(). M2:106 identifies reply construction by line number without naming process().

  Evidence: CF/scripts/load_lane_config.py:31-37 executes at module scope. DISP/dispatcher.py:400 defines main(), which owns :500-508. CF/scripts/node-bus-worker.py:1007 defines process(). These are nameable implementing scopes, not external boundaries.

  Fix: Use explicit file:function identities, including a clearly defined <module> scope for top-level code, alongside line locators. Apply the same names at both ends of each internal contract.

B04 — OMISSION — M0–M12 — Required metrics fields remain RED or incomplete.

  Claim: M0–M8, M11 and M12 explicitly report “RED — none”. M10-crier.md:208-211 admits its per-metric type/labels/question/scrape contract is incomplete. M9-scheduler.md:264-283 describes JSON blocks and selected semantics, but does not provide the required per-metric contract.

  Evidence: MASTER-DOC-SCHEMA.md:72-79 requires those fields and explicitly makes “none” RED. Relevant implementing examples include SCH/internal/api/server_metrics.go:101-118 and CR/internal/guard/metrics.go:19-49.

  Fix: Keep the absent instrumentation RED until instrumentation or an explicit schema exception exists. Complete the emitted-metric contracts for M9 and M10. This is not permission to invent metrics or call honest absence a writing error; it is a reason the chapters cannot yet be WRITTEN.

B05 — OMISSION — M1, M2, M3 — The proposed log-template exemption does not satisfy the field contract.

  Claim: M1-provisioning.md:218, M2-dispatch.md:152-159 and M3-repository.md:156 argue that enumerating static measurement labels adds no operator knowledge.

  Evidence: MASTER-DOC-SCHEMA.md:83-91 requires operator-visible lines, triggering conditions and descriptive/evidentiary classification. A generic “PASS %s — %s” does not identify which check ran or the recovery it implies. M1 also owns distinct non-template terminal messages: CF/scripts/bunker-crier-connect.sh:94-102 emits NOT CONNECTED, CONNECTED and UNVERIFIED with different outcomes, none represented in M1’s log table.

  Fix: Supply a generated appendix or compact static-label/trigger/action register. Repeated formatting need not be duplicated, but the operational distinctions cannot be discarded. Until an exemption is approved, retain this field as RED.

B06 — OMISSION — M1 — The provisioning settings register does not cover all owned entry points.

  Claim: M1-provisioning.md:94-171 presents the module’s settings register, but has no register for bunker-server-install.sh, node-create.sh or bunker-crier-connect.sh.

  Evidence: CF/scripts/bunker-server-install.sh:14-16,37 reads BUNKER_SERVER/BUNKER_CONFIG. node-create.sh:21,63-75 exposes project/repo/ref/harness/agent/TTL/port/staging selectors. bunker-crier-connect.sh:23,142-156 exposes URL, timeout and check/apply/stage modes.

  Fix: Register their defaults, accepted forms, readers and consequences. In particular, explain existing-agent reuse versus spawning, stage-only versus verified connection, and the endpoint/config selectors that can target the wrong host.

B07 — OMISSION — M2 — Lane-configuration controls and durable side effects are largely absent from §5.

  Claim: M2-dispatch.md:64-93 registers the worker, while the three S1 configuration units remain only structure-mapped.

  Evidence: CF/scripts/load_lane_config.py:13-18 reads SCHEDULER_DB and CODE_FACTORY_ROOT; :20-37 supplies lane policies and writes namespace, admission mode and prompt data. configure_family.py:19-28 fixes DB/API/root/credential authority; :128-138 supplies pacing ceilings; :170-189 combines API mutations with direct SQL updates and a commit.

  Fix: Add the configuration-authority and pacing registers, credential acquisition, prompt replacement effects, and partial-failure/readback procedure. The worker’s settings are not the whole module’s settings.

B08 — OMISSION — M3 — The landing register omits required selectors and mutation-mode switches.

  Claim: M3-repository.md:70-82 registers REMOTE/MAIN/GATE and freshness controls, but not the lander’s complete CLI.

  Evidence: CF/scripts/land-node-branch.sh:101-118 exposes --workdir, --branch, --commit, --ff-only, --no-ff and --dry-run. :183-206 treats already-landed work specially; :218-244 changes refusal and publication behavior according to merge/dry-run mode.

  Fix: Register every selector and mode, including defaults and their effects on fetches, gates, merge topology and publication. Document that dry-run evaluates existing refs rather than fetching current remote state.

B09 — OMISSION — M5 — The node-entry and adapter turn controls are missing despite being run-correctness controls.

  Claim: M5-harness.md:99 calls its tables “Per-adapter installation registers”, but project-node.sh receives no settings register and several adapter execution controls are absent.

  Evidence: CF/scripts/project-node.sh:37-49,59-80 exposes NODE_KINDS, --layers, --role, --disk-floor and other selectors. :774-781 suppresses manifest creation for scoped runs. scripts/harness/install-codex.sh:58-60 reads CF_TURN_TOKEN, CF_TURN_FILE and the timeout; :112-113 exposes --turn, --app-server and --deep; :427-428 reads download URL/digest overrides; :544-545 removes and recreates the selected turn artifact.

  Fix: Document these defaults, ranges and consequences. A scoped fixture PASS is not node certification, and an artifact-path control that participates in deletion is not an incidental detail.

B10 — FALSE CLAIM — M6 — The cited revision does not contain the spine implementation being described.

  Claim: M6-documentation.md:9 says handbook_spine.py changed through 3fba8a7 and its locators were repinned “at HEAD”. :105-108 attributes the backtick-aware splitter and malformed-row check to that revision.

  Evidence: git diff -- scripts/handbook_spine.py shows split_row(), CONTRACT ROW MISPARSE, CONTRACT UNKNOWN ID and the backticked-default fallback as uncommitted changes. git show HEAD:scripts/handbook_spine.py has 340 lines; the reviewed working file has 443. Its measured SHA-256 is afbc65fc7bfec973969c27767bd5980b7d7ae5c1a3999c7d6511dfdaf3752163.

  Fix: Stamp the actual reviewed working-tree content hash and disclose the dirty-source delta, or cite a commit that really contains it. Do not attribute working-tree features and line numbers to an earlier committed file.

B11 — UNBUILDABLE — M6 — The delivered chapters still have no working render-to-owner path.

  Claim: M6-documentation.md:12 acknowledges that the legacy pipeline is unusable for M-numbered chapters and the render leg remains missing.

  Evidence: CF/scripts/gen_nasa_handbook.py:18 fixes MODULES to docs/master; :253-259 selects numbered NN-*.md files and rejects an empty selection. The delivered files are M*.md. M6’s CT-18 at :156 is therefore not an executable delivery path for this handbook.

  Fix: Provide and verify a chapter-aware renderer and its owner-facing artifact, or obtain an explicit scope exception. The spine is a consistency checker, not a replacement rendering/delivery mechanism.

B12 — OMISSION — M6 — The spine’s documented blind spots are incomplete.

  Claim: M6-documentation.md:108-110 identifies locator validity and status rederivation as “the remaining blind spots”.

  Evidence: CF/scripts/handbook_spine.py:87 recognizes only certain uppercase setting names, excluding CLI rows. :175-176 reduces decimal defaults to their integer prefix. My isolated source probe returned:
    norm_default("0.15") = "0"
    norm_default("0.66") = "0"
    CLI setting row recognized = False
    has_fq("dispatcher.py") = True
  The checker also hardcodes the flow count at :398 rather than deriving existing flow chapters.

  Fix: Disclose these additional coverage limits. Add negative fixtures for decimal-default conflicts, CLI settings and bare-file references before claiming the gate covers those dimensions.

B13 — FALSE CLAIM — M7 — The advertised environment-only mint invocation is not supported.

  Claim: M7-github.md:96 advertises token minting with GITHUB_APP_ID, GITHUB_APP_INSTALLATION_ID and GITHUB_APP_PRIVATE_KEY_FILE “set (or --env-file)”.

  Evidence: CF/scripts/github-app-token.py:276-293 requires a readable env file. :295-323 reads App/installation IDs from that file’s returned dictionary; check_key_file() at :326-358 likewise reads the key-file entry from that dictionary. It does not merge those values from exported environment variables.

  Fix: State that these are required env-file keys. Document GITHUB_APP_ENV_FILE/--env-file as the source selector, and provide a correct file-based invocation.

B14 — OMISSION — M7 — Node refresh creates/replaces a credential store and changes global Git configuration.

  Claim: M7-github.md:71 says the store is rewritten “only when it already exists” and the script “never creates a second store”. The node-mode description at :72 documents token installation but omits its Git credential mutations.

  Evidence: CF/scripts/github-app-refresh.sh:134 applies the existence restriction only to local mode. Node mode at :160-166 writes $HOME/.git-credentials regardless of prior existence and executes git config --global credential.helper "store --file=...".

  Fix: Scope the existing-store guarantee to local mode. Document the node-side overwrite, global helper change, possible replacement of existing credentials, and post-install readback.

B15 — OMISSION — M7 — First-install setup is named but its controls and partial-write semantics are unwritten.

  Claim: M7-github.md:31 includes github-app-setup.sh in S1; §5 primarily documents the minter and refresher.

  Evidence: CF/scripts/github-app-setup.sh:76-95 exposes setup mode, IDs, key, slug, repository, organization, name and output selectors. :234-244 implements interactive/noninteractive refusal. :256-272 writes the env file before API verification; :287-291 leaves it in place after verification failure.

  Fix: Register the setup controls and write-before-verification behavior. Give the first-install operator an actionable procedure that distinguishes configured, verified and incomplete states.

B16 — OMISSION — M8 — The safety register omits targeting/output switches.

  Claim: M8-safety.md:55-61 registers reclaim’s root/TTL/dry-run controls, but not the scanner’s root selector or reclaim’s --json switch.

  Evidence: CF/scripts/check_scan_scope.py:81-95 accepts an optional repository root and exits 2 on an invalid root. scripts/reclaim_disk.py:137,163-164 adds JSON after its human-readable rows rather than replacing those rows.

  Fix: Register both controls. Explain that changing the scanner root changes the evidence population, and --json stdout is mixed-format rather than one standalone JSON document.

B17 — FALSE CLAIM — M9 — The “ordered admission procedure” is not the composed execution order.

  Claim: M9-scheduler.md:58-88 labels its list an ordered procedure, placing usage-pool reservation before board-stasis and omitting several actual refusal gates.

  Evidence: SCH/internal/scheduler/packer_select.go:437-454 applies cooldown/tasks builder no-work gates; :462-482 applies stasis, stale-premise and blocked-premise gates; :492-525 applies concurrency, cadence ceiling and weight budget. Packing occurs in tick_process.go:285. Usage reservation occurs later in SlotPool.spawn at slot_pool.go:539-585.

  Fix: Derive the procedure from the calling sequence, not an ordered list of related helpers. Include tasks_no_work, stale-premise, blocked-head, cadence/concurrency/budget gates and the later usage-reservation phase, with their refusal semantics.

B18 — OMISSION — M9 — The auxiliary-settings table still lacks required ranges and verified reader/precedence contracts.

  Claim: M9-scheduler.md:180-215 presents the remaining flags as completed defaults-plus-consequences, but its table omits a range column and explicitly leaves reader/precedence verification unfinished.

  Evidence: SCH/cmd/schedulerd/main.go:174-208 defines the auxiliary controls. These include simulation probabilities, reap mutation switches, failure-rate thresholds and durable paths. The source also documents flag > env > TOML > flag-default for budget provenance at :211-216.

  Fix: Supply accepted ranges, zero/negative behavior where relevant, effective readers and precedence per control or a demonstrably shared rule. A consequence column alone does not satisfy the three-part setting contract.

B19 — OMISSION — M9 — Operator routes are inventoried, not documented as executable contracts.

  Claim: M9-scheduler.md:52-55 explicitly says per-route request/response shapes and write-authority readbacks are not written.

  Evidence: The measured route count is 43, matching the cited SCH/internal/api/server.go mounting surface. A route name does not establish its method, payload, authentication, refusal shape or verification/readback.

  Fix: Fill the S4 operator contract, prioritizing mutation and dispatch/recovery surfaces. Each write needs authority, request, response, failure semantics and exact-target readback.

B20 — OMISSION — M9 — Recovery names functions but does not provide the required recovery procedure.

  Claim: M9-scheduler.md:123-126 admits that post-recovery indications remain unwritten.

  Evidence: The chapter names RecoverExecutionState and the lease/outbox write authorities, but its §10 does not turn them into a crash/restart/orphan decision procedure. MASTER-DOC-SCHEMA.md:93-96 requires distinguishable failures and recovery; OUTLINE.md:131-133 requires expected indications after each step.

  Fix: Write the per-failure ladder: observation, authority queried, safe action, expected changed state, readback and stop/escalation condition. Merely naming the recovery selector is not an operator procedure.

B21 — OMISSION — M10 — Settings that determine the newly documented security boundary are absent from the register.

  Claim: M10-crier.md:59-71 explains protected service delivery, but §5 does not register the controls that enable and configure it.

  Evidence: CR/config/config.go:1010-1014 reads CR_SERVICE_DELIVERY_ALLOWLIST and CR_SERVICE_DELIVERY_AUDIENCE. CR/internal/registry/service_auth.go:44-66 defines exact directed sender>recipient syntax; :82-99 requires an audience for a nonempty protected policy. CR_AUTH_TOKEN is also read at config.go:624 but is not a complete settings row.

  Fix: Document defaults, syntax/ranges, startup refusal, restart/application semantics and operational consequences. An operator must be able to determine whether the “unprotected recipients only” compatibility qualification applies.

B22 — FALSE CLAIM — M10 — The guard does not have only the two documented log-message forms.

  Claim: M10-crier.md:231-235 says the guard’s “two sites” are tabulated and places remaining omissions outside the handler/guard.

  Evidence: CR/internal/guard/guard.go:306-307 emits “guard sanitize rewrite unavailable” with msg, fallback and err, in addition to “guard” and “guard blocked” at :452-457. TestCheck_RewriteUnavailableIsNamedInLog explicitly verifies that diagnostic; I reran it successfully.

  Fix: Add the missing warning, condition, fields and operator action. Correct the completeness claim and enumerate the guard through its logging wrappers, not just the final audit helper.

B23 — FALSE CLAIM — M10 — The saturation counter is not proof that a check failed open.

  Claim: M10-crier.md:192-194 calls crier_guard_saturated_total a counter for checks “failed open because the concurrency cap stayed full”.

  Evidence: CR/internal/guard/router.go:230-234 increments the counter when the acquire budget expires, before returning ErrConcurrencySaturated. guard.go:250-252 routes errors through errorResult(); :344-356 can block, sanitize or allow according to policy and deterministic evidence.

  Fix: Define the counter as saturation errors, not delivered/fail-open messages. Explain how to combine it with decision/error observations to determine actual admission outcomes. The metric HELP prose is not a substitute for following the increment and consumer.

B24 — OMISSION — M11 — The completion contract omits lossy output selection and the fallback recipient.

  Claim: M11-dispatcher.md §6 describes encoded replies, but §5/§11 does not document the output-retention algorithm or reply-target default.

  Evidence: DISP/dispatcher.py:159-163 defaults reply_to to “orchestrator”. The durable path polls only the last 4000 bytes at :303-305, then selects the last six nonempty lines at :320-324. The synchronous path also selects six lines at :355-358. The completion’s reply_len at :504 measures this selected output, not the harness’s full output.

  Fix: Document these limits and their effects on evidence/report preservation. Register the fallback recipient, and distinguish complete harness output from the transported excerpt.

B25 — UNVERIFIED — M1, M2, M3, M5, M7, M11, M12 — Required behavioral acceptance is still missing.

  Claim: The chapters disclose unrun live certification, bus-worker verification, hook enforcement, harness conformance, token minting and live-job verification. M12 additionally leaves valid-token/disallowed-model admission unrerun.

  Evidence: M1:205; M2:136; M3:183-188; M5:170; M7:96; M11:118; M12:121. DISP/tests/test_durable_job.py:8-11 prints a failed result without asserting. tests/test_job_kill.py:35 prints PASS/FAIL without converting FAIL into a failing exit.

  Fix: Provide repeatable behavioral oracles and run them in the required environment. Keep the associated fields UNVERIFIED until then. Syntax checks, source reads and printing a verdict are not substitutes. I did not invoke live-node provisioning, paid harness execution or real credential minting.

B26 — UNVERIFIED — M12 — Healthy streaming completion remains demonstrably FAILING.

  Claim: M12-inference-proxy.md:174-184 acknowledges an unframed healthy SSE response and correctly withdraws blanket streaming verification.

  Evidence: PROXY:206-224 sends HTTP/1.1 stream headers without Content-Length, Transfer-Encoding or Connection: close, then returns without closing the connection. I independently exercised the actual Handler against a finite local SSE fixture:
    status=200
    content_length=null
    transfer_encoding=null
    connection=null
    eof_completed=false
    read_error=TimeoutError

  Fix: Retain FAILING, supply a shipped completion/framing oracle, and verify the implementation’s eventual correction. This is confirmed system behavior, not speculation or an upstream-outage case. Under the current acceptance rule, the chapter cannot be WRITTEN while this required verification remains red.

B27 — UNVERIFIED — M4, M6, M10 — Several “active” classifications do not carry invoking evidence.

  Claim: M4-board.md:34 supports “active” with a command run by the writer. M6-documentation.md:42 supports S1 “active” with a main() entrypoint. M10-crier.md:34-35 supports active service/client classifications with “read” or a file having been read.

  Evidence: OUTLINE.md:113-119 requires an invoking lane/cron/timer/unit line. An entrypoint proves executability; a writer’s manual run proves an observation; neither proves production activation.

  Fix: Cite the actual invoking unit/service/call site, or mark activation UNVERIFIED. Do not infer inactivity either: the missing item is invoking evidence, not proof that no deployment exists.

Verification performed:

  Required spine command:
    python3 scripts/handbook_spine.py
    chapters=13  canonical contracts=18
    findings=0
    exit 0

  Consequently, there are no mechanically reported spine findings to convert into CONTRADICTION findings. B02 is an independently observed contradiction outside that checker’s coverage.

  Reproduced successfully:
    test_disk_floor.py — 12 tests, OK
    test_lane_target.py — 40 tests, OK
    test_clone_lane.py — 4 tests, OK
    test_harness_resolve.py — 28 tests, OK
    test_reclaim.py — 9 tests, OK
    check_scan_scope.py — 15 claims, RESULT: OK
    boardctl validate — 357 tasks, 519 events, RESULT: OK with 7 warnings
    board_drift.py — byte parity, 0 divergent IDs, RESULT: OK
    verify-patch.sh — 5 stages, 4 patches, VERIFY-PATCH: PASS
    isolated shipped cf213 landing arm — exit 0, failure count 0
    selected Crier service-auth/interoperability tests — PASS
    selected guard logging/policy tests — PASS

  Reproduced expected failure:
    master_doc_check.py — 44 modules, 37 declared VERIFIED, 50 errors, MASTER-DOC: FAIL, exit 1.

  Additional isolated observations:
    The actual dispatcher runner template leaves its GNU-timeout group alive when the runner group is terminated, confirming the chapter’s disclosed survivor defect.
    The node’s fractional wall_s=0.5 converts to 0; an oversized wall_s falls back to 1800, confirming its disclosed non-clamping behavior.
    The lock classifier produces the same RESIDUE shape for an uncontended lock and an injected indeterminate probe, confirming the documented observation-quality limitation.

  The isolated replay script is:
    /home/kara/.hermes/cache/scratch/round16-sol-judge-probes.py

  Full scheduler/Crier suites and live-node/credential-dependent ladders were not rerun. An additional permission-mode probe was approval-blocked; no result from it is asserted.

DEFECT CLASSES:
  Wire identifier drift
  Signed transcript misdescription
  Conflicting evidence policy
  Missing implementation identities
  Incomplete observability contracts
  Log inventory exemption
  Incomplete settings surfaces
  Uncommitted source attribution
  Missing delivery mechanism
  Checker coverage overstatement
  Unsupported credential invocation
  Undocumented credential mutation
  Incorrect admission ordering
  Missing recovery procedures
  Metric semantic overstatement
  Undocumented output truncation
  Missing behavioral oracles
  Broken stream completion
  Unsupported activation claims

CHAPTER SCORECARD:

  M0 — PARTIAL
    Useful source-grounded helper inventory, but metrics remain RED and its boundary evidence is subject to the unresolved completeness policy.

  M1 — PARTIAL
    Substantial provisioning and certification detail; entry-point settings and log contracts remain incomplete, and live certification is UNVERIFIED.

  M2 — PARTIAL
    Worker protocol and settlement detail are substantive; protected-service claims need correction, S1 controls remain incomplete, and live verification is missing.

  M3 — PARTIAL
    The shipped landing arm was independently reproduced successfully. Hook enforcement, complete landing controls and the log contract remain incomplete; metrics remain RED.

  M4 — PARTIAL
    Store census, validation and drift claims reproduced. RED accounting conflicts with other chapters, activation evidence is insufficient, and metrics remain RED.

  M5 — PARTIAL
    Shared variable and installer coverage is substantial, but node-entry/turn controls, conformance execution and log coverage remain incomplete; metrics remain RED.

  M6 — PARTIAL
    The spine runs clean, but the chapter misattributes dirty-source features to HEAD, omits checker limitations, and has no working render path for this chapter set.

  M7 — PARTIAL
    Credential domains are usefully separated, but the environment-only mint invocation is wrong, node credential-store mutations are underdocumented, and setup/mint verification remains incomplete.

  M8 — PARTIAL
    Reclaim tests and scan-scope checks reproduced. Targeting/output switches remain unwritten and metrics remain RED.

  M9 — PARTIAL
    Considerable source-grounded depth, but the claimed ordered procedure is not the call order; auxiliary ranges, route contracts, metrics contracts and recovery indications remain incomplete.

  M10 — PARTIAL
    Targeted tests pass and custody detail is substantive. The audience header and saturation semantics are wrong; guard logging, security settings and metric contracts remain incomplete.

  M11 — PARTIAL
    The dispatcher body and disclosed process-group defect are grounded. Protected-service terminology needs correction; output truncation/default targeting and executable behavioral assurance remain incomplete; metrics remain RED.

  M12 — PARTIAL
    Source hash and unauthenticated 401 reproduced; healthy SSE completion independently fails. Boundary evidence, remaining admission verification and metrics remain RED.

  Aggregate: 0 WRITTEN, 13 PARTIAL, 0 SKELETON.

PANEL REVIEW COMPLETE

session_id: local-8bad07bd0a358450aeb28b589f9549d7292e7ca47a256f5625d50e1da442e103

EXIT=0
```

