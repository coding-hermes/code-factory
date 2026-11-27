# CF-458 dispatchability audit

Scope: two pending, non-deferred, code-factory-owned rows, CF-301 and CF-326. Their original criteria and all board history remain intact. Their new verification clauses name existing paths, a runnable test command, a falsifiable expected outcome, FAILIF and an outline citation. The commands are verification targets after the work, not claims that the requested new fixtures already exist. The scan-scope existing test was run separately (7 tests, exit 0); it does not yet cover the new fence controls. CF-326's full selftest is a target, not claimed green here. No row was closed as superseded.

Residual classification is a triage disposition, not an authoritative assignment or a gate exemption. Explicitly deferred rows remain deferred; all others are concrete follow-ups owned by their named row and the code-factory foreman, who must route foreign work or resolve owner gates after inspecting each original row. The failure finding is included verbatim so each follow-up is actionable; no row was silently excluded. Some gate findings may be false positives, and a row's existing intent governs the remedy. No acceptance-gate exclusion mechanism was applied.

Residual counts: concrete follow-up=174, deferred=12; total=186.

## Baseline (exit 1)

Command shape: `python3 <acceptance-gate-path> audit <repo-root>` (the measured run used the configured acceptance-gate helper against the repository root).

```text
info: generated-artifact (gitignored) path exempted: .node/node.json
info: generated-artifact (gitignored) path exempted: .gitreins/history/2026-11-03/410022a2/verdict.json
info: generated-artifact (gitignored) path exempted: .gitreins/history/2026-11-03/410022a2/verdict.json
FAIL CF-001: path not in repo: internal/bus/dispatch_test.go; path not in repo: docs/dispatch-spec.md
FAIL CF-002: names no runnable command
FAIL CF-045: unexpanded placeholder <reason> — a context-free worker cannot fill it
FAIL CF-046: unexpanded placeholder <id> — a context-free worker cannot fill it
FAIL CF-053: unexpanded placeholder <agent> — a context-free worker cannot fill it; unexpanded placeholder <path> — a context-free worker cannot fill it
FAIL CF-059: unexpanded placeholder <reason> — a context-free worker cannot fill it; unexpanded placeholder <fp> — a context-free worker cannot fill it; unexpanded placeholder <reason> — a context-free worker cannot fill it
FAIL CF-060: unexpanded placeholder <workdir> — a context-free worker cannot fill it; unexpanded placeholder <url> — a context-free worker cannot fill it; names a flag that does not exist: --expect-remote
FAIL CF-067: unexpanded placeholder <run_id> — a context-free worker cannot fill it; unexpanded placeholder <commit_hash> — a context-free worker cannot fill it; unexpanded placeholder <reason> — a context-free worker cannot fill it
FAIL CF-070: unexpanded placeholder <VARNAME> — a context-free worker cannot fill it
FAIL CF-073: unexpanded placeholder <fp> — a context-free worker cannot fill it; unexpanded placeholder <run_id> — a context-free worker cannot fill it; unexpanded placeholder <reason> — a context-free worker cannot fill it; unexpanded placeholder <commit_hash> — a context-free worker cannot fill it
FAIL PERF-013: unexpanded placeholder <list> — a context-free worker cannot fill it; unexpanded placeholder <fresh> — a context-free worker cannot fill it
FAIL CF-074: unexpanded placeholder <ref> — a context-free worker cannot fill it; unexpanded placeholder <fp> — a context-free worker cannot fill it; unexpanded placeholder <reason> — a context-free worker cannot fill it; unexpanded placeholder <reason> — a context-free worker cannot fill it; unexpanded placeholder <ref> — a context-free worker cannot fill it; unexpanded placeholder <path> — a context-free worker cannot fill it
FAIL CF-076: unexpanded placeholder <history-date-dir> — a context-free worker cannot fill it; unexpanded placeholder <commit> — a context-free worker cannot fill it
FAIL CF-084: unexpanded placeholder <path> — a context-free worker cannot fill it
FAIL PERF-015: names no runnable command; path not in repo: docs/audits/code-factory-perf-2026-11-03-PERF-015.md
FAIL CF-120: unexpanded placeholder <org> — a context-free worker cannot fill it; unexpanded placeholder <repo> — a context-free worker cannot fill it; unexpanded placeholder <org> — a context-free worker cannot fill it; unexpanded placeholder <repo> — a context-free worker cannot fill it
FAIL CF-121: unexpanded placeholder <ref> — a context-free worker cannot fill it
FAIL CF-122: unexpanded placeholder <path> — a context-free worker cannot fill it
FAIL CF-132: names no runnable command
FAIL CF-136: names no runnable command
FAIL CF-137: names no runnable command
FAIL CF-139: names no runnable command; path not in repo: internal/bus/dispatch.go
FAIL CF-140: unexpanded placeholder <src> — a context-free worker cannot fill it; unexpanded placeholder <new> — a context-free worker cannot fill it; unexpanded placeholder <workdir> — a context-free worker cannot fill it; names a flag that does not exist: --cooldown-s
FAIL CF-144: unexpanded placeholder <committed artifact> — a context-free worker cannot fill it
FAIL CF-146: names no runnable command
FAIL CF-149: names no runnable command
FAIL CF-158: path not in repo: scripts/__scope_probe.sh; path not in repo: scripts/boardctl_scope_probe.sh
FAIL CF-160: unexpanded placeholder <repo> — a context-free worker cannot fill it; unexpanded placeholder <node-host> — a context-free worker cannot fill it; unexpanded placeholder <angle-bracket> — a context-free worker cannot fill it; unexpanded placeholder <repo> — a context-free worker cannot fill it
FAIL CF-161: path not in repo: specs/RELEASE.md; path not in repo: docs/RELEASE.md
FAIL CF-162: unexpanded placeholder <base> — a context-free worker cannot fill it
FAIL CF-164: unexpanded placeholder <nnn> — a context-free worker cannot fill it
FAIL CF-165: unexpanded placeholder <tmp-board-dir> — a context-free worker cannot fill it; unexpanded placeholder <tmp-board-dir> — a context-free worker cannot fill it
FAIL CF-168: unexpanded placeholder <arm> — a context-free worker cannot fill it
FAIL CF-173: names a flag that does not exist: --bind; names a flag that does not exist: --limit-rate
FAIL CF-174: unexpanded placeholder <version string> — a context-free worker cannot fill it
FAIL CF-177: path not in repo: internal/api/lane_onboarding.go; unexpanded placeholder <sha> — a context-free worker cannot fill it; unexpanded placeholder <sha> — a context-free worker cannot fill it
FAIL CF-178: names a flag that does not exist: --re-arm
FAIL CF-179: unexpanded placeholder <uid> — a context-free worker cannot fill it; unexpanded placeholder <uid> — a context-free worker cannot fill it; unexpanded placeholder <uid> — a context-free worker cannot fill it; unexpanded placeholder <uid> — a context-free worker cannot fill it; unexpanded placeholder <uid> — a context-free worker cannot fill it; unexpanded placeholder <AGENT> — a context-free worker cannot fill it; unexpanded placeholder <server> — a context-free worker cannot fill it; unexpanded placeholder <agent> — a context-free worker cannot fill it
FAIL CF-185: unexpanded placeholder <reason> — a context-free worker cannot fill it; unexpanded placeholder <pid> — a context-free worker cannot fill it; unexpanded placeholder <lane> — a context-free worker cannot fill it
FAIL CF-186: unexpanded placeholder <tip> — a context-free worker cannot fill it
FAIL CF-194: unexpanded placeholder <that directory> — a context-free worker cannot fill it; unexpanded placeholder <path> — a context-free worker cannot fill it
FAIL CF-196: names a flag that does not exist: --force-id
FAIL CF-200: unexpanded placeholder <artifact> — a context-free worker cannot fill it
FAIL CF-201: unexpanded placeholder <run> — a context-free worker cannot fill it; unexpanded placeholder <reason> — a context-free worker cannot fill it
FAIL CF-203: names no runnable command
FAIL CF-204: does not state the expected outcome
FAIL CF-208: does not state the expected outcome
FAIL CF-212: unexpanded placeholder <branch> — a context-free worker cannot fill it
FAIL CF-213: does not state the expected outcome
FAIL CF-216: names no runnable command; path not in repo: internal/bus/dispatch.go
FAIL CF-217: names no runnable command
FAIL CF-221: path not in repo: scripts/install-omp.sh
FAIL CF-222: path not in repo: scripts/install-omh.sh
FAIL CF-223: path not in repo: scripts/install-hilo.sh
FAIL CF-232: path not in repo: specs/DESIGN.md
FAIL CF-233: names no runnable command
FAIL CF-234: names no runnable command
FAIL CF-236: names no runnable command
FAIL CF-237: names no runnable command
FAIL CF-242: unexpanded placeholder <copy> — a context-free worker cannot fill it
FAIL CF-243: names no runnable command
FAIL CF-249: names no runnable command
FAIL CF-251: names no runnable command; does not state the expected outcome
FAIL CF-255: unexpanded placeholder <id> — a context-free worker cannot fill it
FAIL CF-260: names no runnable command
FAIL CF-263: names no runnable command; does not state the expected outcome
FAIL CF-265: names no runnable command
FAIL CF-267: names no runnable command; does not state the expected outcome
FAIL CF-268: names no runnable command
FAIL CF-269: names no runnable command
FAIL CF-271: names no runnable command
FAIL CF-279: does not state the expected outcome
FAIL CF-282: names no runnable command
FAIL CF-284: names no runnable command
FAIL CF-286: names no runnable command
FAIL CF-293: names no runnable command
FAIL CF-294: names no runnable command
FAIL CF-295: names no runnable command
FAIL CF-296: names no runnable command; does not state the expected outcome
FAIL CF-297: names no runnable command
FAIL CF-301: names no runnable command; does not state the expected outcome
FAIL CF-308: names no runnable command
FAIL CF-310: names no runnable command; does not state the expected outcome
FAIL CF-311: names no runnable command; does not state the expected outcome
FAIL CF-312: names no runnable command
FAIL CF-314: names no runnable command; does not state the expected outcome
FAIL CF-317: names no runnable command; does not state the expected outcome; unexpanded placeholder <project> — a context-free worker cannot fill it; unexpanded placeholder <YYYY-Www> — a context-free worker cannot fill it
FAIL CF-318: names no runnable command; does not state the expected outcome
FAIL CF-324: names no runnable command
FAIL CF-325: names no runnable command
FAIL CF-326: names no runnable command
FAIL CF-327: names no runnable command
FAIL CF-328: names no runnable command
FAIL CF-331: names no runnable command; does not state the expected outcome
FAIL CF-332: names no runnable command
FAIL CF-333: names no runnable command
FAIL CF-337: names no runnable command
FAIL CF-338: names no runnable command
FAIL CF-340: names no runnable command
FAIL CF-341: names no runnable command
FAIL CF-342: names no runnable command; does not state the expected outcome
FAIL CF-343: names no runnable command; does not state the expected outcome
FAIL CF-347: names no runnable command
FAIL CF-348: names no runnable command
FAIL CF-349: names no runnable command
FAIL CF-350: names no runnable command
FAIL CF-351: names no runnable command
FAIL CF-352: names no runnable command; does not state the expected outcome
FAIL CF-353: names no runnable command; does not state the expected outcome
FAIL CF-358: names no runnable command; names a flag that does not exist: --allow-missing-workdir
FAIL CF-359: names no runnable command
FAIL CF-362: does not state the expected outcome
FAIL CF-363: names no runnable command
FAIL CF-364: path not in repo: docs/master/00-INDEX.md
FAIL CF-365: names no runnable command
FAIL CF-367: names no runnable command
FAIL CF-368: names no runnable command
FAIL CF-369: names no runnable command
FAIL CF-371: unexpanded placeholder <name> — a context-free worker cannot fill it; unexpanded placeholder <name> — a context-free worker cannot fill it
FAIL CF-375: unexpanded placeholder <TAB> — a context-free worker cannot fill it
FAIL CF-377: unexpanded placeholder <fix> — a context-free worker cannot fill it; unexpanded placeholder <board> — a context-free worker cannot fill it; names a flag that does not exist: --closeout-kind; names a flag that does not exist: --closeout-ref
FAIL CF-380: unexpanded placeholder <file> — a context-free worker cannot fill it
FAIL CF-386: unexpanded placeholder <ids> — a context-free worker cannot fill it; unexpanded placeholder <name> — a context-free worker cannot fill it
FAIL CF-389: path not in repo: docs/audits/fixtures/does-not-exist.json; unexpanded placeholder <row> — a context-free worker cannot fill it; unexpanded placeholder <id> — a context-free worker cannot fill it; unexpanded placeholder <path> — a context-free worker cannot fill it; unexpanded placeholder <tip> — a context-free worker cannot fill it; unexpanded placeholder <path> — a context-free worker cannot fill it
FAIL CF-391: unexpanded placeholder <id> — a context-free worker cannot fill it; unexpanded placeholder <id> — a context-free worker cannot fill it
FAIL P3B-01: names no runnable command
FAIL P3B-02: names no runnable command
FAIL P3B-03: names no runnable command
FAIL P3B-05: names no runnable command
FAIL P3B-06: names no runnable command
FAIL P3B-08: names no runnable command
FAIL P3B-09: names no runnable command
FAIL P3B-10: names no runnable command
FAIL P3B-11: names no runnable command
FAIL P3B-14: names no runnable command
FAIL P3B-15: names no runnable command
FAIL P3B-16: names no runnable command
FAIL P3B-17: names no runnable command
FAIL P3B-18: names no runnable command
FAIL P3B-19: names no runnable command
FAIL P3B-21: names no runnable command
FAIL P3B-22: names no runnable command
FAIL P3B-23: names no runnable command
FAIL P3B-28: names no runnable command
FAIL P3B-29: names no runnable command
FAIL P3B-35: names no runnable command
FAIL P3B-36: names no runnable command
FAIL P3B-37: names no runnable command
FAIL P3B-38: names no runnable command; does not state the expected outcome
FAIL P3B-39: names no runnable command
FAIL P3B-41: names no runnable command
FAIL P3B-43: names no runnable command
FAIL P3B-44: names no runnable command
FAIL P3B-48: names no runnable command
FAIL P3B-49: names no runnable command
FAIL P3B-50: names no runnable command
FAIL P3B-52: names no runnable command; does not state the expected outcome
FAIL P3B-53: names no runnable command
FAIL P3B-57: names no runnable command; does not state the expected outcome
FAIL P3B-60: names no runnable command
FAIL P3B-62: names no runnable command
FAIL P3B-63: names no runnable command
FAIL P5G-05: names no runnable command
FAIL CF-425: names no runnable command
FAIL CF-426: names no runnable command
FAIL P5G-08-R2: unexpanded placeholder <line> — a context-free worker cannot fill it; unexpanded placeholder <commit> — a context-free worker cannot fill it
FAIL CF-441: names no runnable command
FAIL CF-444: names no runnable command; names a flag that does not exist: --skip-tier2
FAIL CF-447: names no runnable command
FAIL P5G-37: unexpanded placeholder <operation_id> — a context-free worker cannot fill it
FAIL CF-452: names no runnable command
FAIL CF-453: names no runnable command
FAIL CF-469: unexpanded placeholder <code> — a context-free worker cannot fill it; unexpanded placeholder <server> — a context-free worker cannot fill it
FAIL CF-108: unexpanded placeholder <bundle> — a context-free worker cannot fill it; unexpanded placeholder <pid> — a context-free worker cannot fill it; unexpanded placeholder <bundle> — a context-free worker cannot fill it
FAIL CF-109: unexpanded placeholder <label> — a context-free worker cannot fill it; unexpanded placeholder <msg> — a context-free worker cannot fill it
FAIL CF-471: unexpanded placeholder <prefix-sha> — a context-free worker cannot fill it
FAIL CF-474: unexpanded placeholder <pathspec> — a context-free worker cannot fill it; unexpanded placeholder <path> — a context-free worker cannot fill it
FAIL CF-477: path not in repo: scripts/board_criteria_check.py
FAIL CF-489: unexpanded placeholder <host> — a context-free worker cannot fill it; unexpanded placeholder <live-crier-url> — a context-free worker cannot fill it; unexpanded placeholder <host> — a context-free worker cannot fill it; unexpanded placeholder <tick> — a context-free worker cannot fill it
FAIL CF-493: path not in repo: docs/leak.md; unexpanded placeholder <root> — a context-free worker cannot fill it; unexpanded placeholder <run> — a context-free worker cannot fill it
FAIL CF-494: names no runnable command
FAIL CF-502: names a flag that does not exist: --deferred
FAIL CF-512: unexpanded placeholder <submodule> — a context-free worker cannot fill it
FAIL CF-524: unexpanded placeholder <module> — a context-free worker cannot fill it; unexpanded placeholder <submodule> — a context-free worker cannot fill it
FAIL CF-527: unexpanded placeholder <id> — a context-free worker cannot fill it
FAIL CF-532: unexpanded placeholder <chat> — a context-free worker cannot fill it; unexpanded placeholder <thread> — a context-free worker cannot fill it
FAIL CF-536: path not in repo: internal/scheduler/dispatch_leg.go; unexpanded placeholder <UTC date> — a context-free worker cannot fill it
FAIL CF-537: unexpanded placeholder <project> — a context-free worker cannot fill it

audit: 381 open rows, 188 failing, 193 passing
```

## Final (exit 1)

Same command, after the two row edits.

```text
info: generated-artifact (gitignored) path exempted: .node/node.json
info: generated-artifact (gitignored) path exempted: .gitreins/history/2026-11-03/410022a2/verdict.json
info: generated-artifact (gitignored) path exempted: .gitreins/history/2026-11-03/410022a2/verdict.json
FAIL CF-001: path not in repo: internal/bus/dispatch_test.go; path not in repo: docs/dispatch-spec.md
FAIL CF-002: names no runnable command
FAIL CF-045: unexpanded placeholder <reason> — a context-free worker cannot fill it
FAIL CF-046: unexpanded placeholder <id> — a context-free worker cannot fill it
FAIL CF-053: unexpanded placeholder <agent> — a context-free worker cannot fill it; unexpanded placeholder <path> — a context-free worker cannot fill it
FAIL CF-059: unexpanded placeholder <reason> — a context-free worker cannot fill it; unexpanded placeholder <fp> — a context-free worker cannot fill it; unexpanded placeholder <reason> — a context-free worker cannot fill it
FAIL CF-060: unexpanded placeholder <workdir> — a context-free worker cannot fill it; unexpanded placeholder <url> — a context-free worker cannot fill it; names a flag that does not exist: --expect-remote
FAIL CF-067: unexpanded placeholder <run_id> — a context-free worker cannot fill it; unexpanded placeholder <commit_hash> — a context-free worker cannot fill it; unexpanded placeholder <reason> — a context-free worker cannot fill it
FAIL CF-070: unexpanded placeholder <VARNAME> — a context-free worker cannot fill it
FAIL CF-073: unexpanded placeholder <fp> — a context-free worker cannot fill it; unexpanded placeholder <run_id> — a context-free worker cannot fill it; unexpanded placeholder <reason> — a context-free worker cannot fill it; unexpanded placeholder <commit_hash> — a context-free worker cannot fill it
FAIL PERF-013: unexpanded placeholder <list> — a context-free worker cannot fill it; unexpanded placeholder <fresh> — a context-free worker cannot fill it
FAIL CF-074: unexpanded placeholder <ref> — a context-free worker cannot fill it; unexpanded placeholder <fp> — a context-free worker cannot fill it; unexpanded placeholder <reason> — a context-free worker cannot fill it; unexpanded placeholder <reason> — a context-free worker cannot fill it; unexpanded placeholder <ref> — a context-free worker cannot fill it; unexpanded placeholder <path> — a context-free worker cannot fill it
FAIL CF-076: unexpanded placeholder <history-date-dir> — a context-free worker cannot fill it; unexpanded placeholder <commit> — a context-free worker cannot fill it
FAIL CF-084: unexpanded placeholder <path> — a context-free worker cannot fill it
FAIL PERF-015: names no runnable command; path not in repo: docs/audits/code-factory-perf-2026-11-03-PERF-015.md
FAIL CF-120: unexpanded placeholder <org> — a context-free worker cannot fill it; unexpanded placeholder <repo> — a context-free worker cannot fill it; unexpanded placeholder <org> — a context-free worker cannot fill it; unexpanded placeholder <repo> — a context-free worker cannot fill it
FAIL CF-121: unexpanded placeholder <ref> — a context-free worker cannot fill it
FAIL CF-122: unexpanded placeholder <path> — a context-free worker cannot fill it
FAIL CF-132: names no runnable command
FAIL CF-136: names no runnable command
FAIL CF-137: names no runnable command
FAIL CF-139: names no runnable command; path not in repo: internal/bus/dispatch.go
FAIL CF-140: unexpanded placeholder <src> — a context-free worker cannot fill it; unexpanded placeholder <new> — a context-free worker cannot fill it; unexpanded placeholder <workdir> — a context-free worker cannot fill it
FAIL CF-144: unexpanded placeholder <committed artifact> — a context-free worker cannot fill it
FAIL CF-146: names no runnable command
FAIL CF-149: names no runnable command
FAIL CF-158: path not in repo: scripts/__scope_probe.sh; path not in repo: scripts/boardctl_scope_probe.sh
FAIL CF-160: unexpanded placeholder <repo> — a context-free worker cannot fill it; unexpanded placeholder <node-host> — a context-free worker cannot fill it; unexpanded placeholder <angle-bracket> — a context-free worker cannot fill it; unexpanded placeholder <repo> — a context-free worker cannot fill it
FAIL CF-161: path not in repo: specs/RELEASE.md; path not in repo: docs/RELEASE.md
FAIL CF-162: unexpanded placeholder <base> — a context-free worker cannot fill it
FAIL CF-164: unexpanded placeholder <nnn> — a context-free worker cannot fill it
FAIL CF-165: unexpanded placeholder <tmp-board-dir> — a context-free worker cannot fill it; unexpanded placeholder <tmp-board-dir> — a context-free worker cannot fill it
FAIL CF-168: unexpanded placeholder <arm> — a context-free worker cannot fill it
FAIL CF-173: names a flag that does not exist: --limit-rate; names a flag that does not exist: --bind
FAIL CF-174: unexpanded placeholder <version string> — a context-free worker cannot fill it
FAIL CF-177: path not in repo: internal/api/lane_onboarding.go; unexpanded placeholder <sha> — a context-free worker cannot fill it; unexpanded placeholder <sha> — a context-free worker cannot fill it
FAIL CF-178: names a flag that does not exist: --re-arm
FAIL CF-179: unexpanded placeholder <uid> — a context-free worker cannot fill it; unexpanded placeholder <uid> — a context-free worker cannot fill it; unexpanded placeholder <uid> — a context-free worker cannot fill it; unexpanded placeholder <uid> — a context-free worker cannot fill it; unexpanded placeholder <uid> — a context-free worker cannot fill it; unexpanded placeholder <AGENT> — a context-free worker cannot fill it; unexpanded placeholder <server> — a context-free worker cannot fill it; unexpanded placeholder <agent> — a context-free worker cannot fill it
FAIL CF-185: unexpanded placeholder <reason> — a context-free worker cannot fill it; unexpanded placeholder <pid> — a context-free worker cannot fill it; unexpanded placeholder <lane> — a context-free worker cannot fill it
FAIL CF-186: unexpanded placeholder <tip> — a context-free worker cannot fill it
FAIL CF-194: unexpanded placeholder <that directory> — a context-free worker cannot fill it; unexpanded placeholder <path> — a context-free worker cannot fill it
FAIL CF-196: names a flag that does not exist: --force-id
FAIL CF-200: unexpanded placeholder <artifact> — a context-free worker cannot fill it
FAIL CF-201: unexpanded placeholder <run> — a context-free worker cannot fill it; unexpanded placeholder <reason> — a context-free worker cannot fill it
FAIL CF-203: names no runnable command
FAIL CF-204: does not state the expected outcome
FAIL CF-208: does not state the expected outcome
FAIL CF-212: unexpanded placeholder <branch> — a context-free worker cannot fill it
FAIL CF-213: does not state the expected outcome
FAIL CF-216: names no runnable command; path not in repo: internal/bus/dispatch.go
FAIL CF-217: names no runnable command
FAIL CF-221: path not in repo: scripts/install-omp.sh
FAIL CF-222: path not in repo: scripts/install-omh.sh
FAIL CF-223: path not in repo: scripts/install-hilo.sh
FAIL CF-232: path not in repo: specs/DESIGN.md
FAIL CF-233: names no runnable command
FAIL CF-234: names no runnable command
FAIL CF-236: names no runnable command
FAIL CF-237: names no runnable command
FAIL CF-242: unexpanded placeholder <copy> — a context-free worker cannot fill it
FAIL CF-243: names no runnable command
FAIL CF-249: names no runnable command
FAIL CF-251: names no runnable command; does not state the expected outcome
FAIL CF-255: unexpanded placeholder <id> — a context-free worker cannot fill it
FAIL CF-260: names no runnable command
FAIL CF-263: names no runnable command; does not state the expected outcome
FAIL CF-265: names no runnable command
FAIL CF-267: names no runnable command; does not state the expected outcome
FAIL CF-268: names no runnable command
FAIL CF-269: names no runnable command
FAIL CF-271: names no runnable command
FAIL CF-279: does not state the expected outcome
FAIL CF-282: names no runnable command
FAIL CF-284: names no runnable command
FAIL CF-286: names no runnable command
FAIL CF-293: names no runnable command
FAIL CF-294: names no runnable command
FAIL CF-295: names no runnable command
FAIL CF-296: names no runnable command; does not state the expected outcome
FAIL CF-297: names no runnable command
FAIL CF-308: names no runnable command
FAIL CF-310: names no runnable command; does not state the expected outcome
FAIL CF-311: names no runnable command; does not state the expected outcome
FAIL CF-312: names no runnable command
FAIL CF-314: names no runnable command; does not state the expected outcome
FAIL CF-317: names no runnable command; does not state the expected outcome; unexpanded placeholder <project> — a context-free worker cannot fill it; unexpanded placeholder <YYYY-Www> — a context-free worker cannot fill it
FAIL CF-318: names no runnable command; does not state the expected outcome
FAIL CF-324: names no runnable command
FAIL CF-325: names no runnable command
FAIL CF-327: names no runnable command
FAIL CF-328: names no runnable command
FAIL CF-331: names no runnable command; does not state the expected outcome
FAIL CF-332: names no runnable command
FAIL CF-333: names no runnable command
FAIL CF-337: names no runnable command
FAIL CF-338: names no runnable command
FAIL CF-340: names no runnable command
FAIL CF-341: names no runnable command
FAIL CF-342: names no runnable command; does not state the expected outcome
FAIL CF-343: names no runnable command; does not state the expected outcome
FAIL CF-347: names no runnable command
FAIL CF-348: names no runnable command
FAIL CF-349: names no runnable command
FAIL CF-350: names no runnable command
FAIL CF-351: names no runnable command
FAIL CF-352: names no runnable command; does not state the expected outcome
FAIL CF-353: names no runnable command; does not state the expected outcome
FAIL CF-358: names no runnable command; names a flag that does not exist: --allow-missing-workdir
FAIL CF-359: names no runnable command
FAIL CF-362: does not state the expected outcome
FAIL CF-363: names no runnable command
FAIL CF-364: path not in repo: docs/master/00-INDEX.md
FAIL CF-365: names no runnable command
FAIL CF-367: names no runnable command
FAIL CF-368: names no runnable command
FAIL CF-369: names no runnable command
FAIL CF-371: unexpanded placeholder <name> — a context-free worker cannot fill it; unexpanded placeholder <name> — a context-free worker cannot fill it
FAIL CF-375: unexpanded placeholder <TAB> — a context-free worker cannot fill it
FAIL CF-377: unexpanded placeholder <fix> — a context-free worker cannot fill it; unexpanded placeholder <board> — a context-free worker cannot fill it; names a flag that does not exist: --closeout-kind; names a flag that does not exist: --closeout-ref
FAIL CF-380: unexpanded placeholder <file> — a context-free worker cannot fill it
FAIL CF-386: unexpanded placeholder <ids> — a context-free worker cannot fill it; unexpanded placeholder <name> — a context-free worker cannot fill it
FAIL CF-389: path not in repo: docs/audits/fixtures/does-not-exist.json; unexpanded placeholder <row> — a context-free worker cannot fill it; unexpanded placeholder <id> — a context-free worker cannot fill it; unexpanded placeholder <path> — a context-free worker cannot fill it; unexpanded placeholder <tip> — a context-free worker cannot fill it; unexpanded placeholder <path> — a context-free worker cannot fill it
FAIL CF-391: unexpanded placeholder <id> — a context-free worker cannot fill it; unexpanded placeholder <id> — a context-free worker cannot fill it
FAIL P3B-01: names no runnable command
FAIL P3B-02: names no runnable command
FAIL P3B-03: names no runnable command
FAIL P3B-05: names no runnable command
FAIL P3B-06: names no runnable command
FAIL P3B-08: names no runnable command
FAIL P3B-09: names no runnable command
FAIL P3B-10: names no runnable command
FAIL P3B-11: names no runnable command
FAIL P3B-14: names no runnable command
FAIL P3B-15: names no runnable command
FAIL P3B-16: names no runnable command
FAIL P3B-17: names no runnable command
FAIL P3B-18: names no runnable command
FAIL P3B-19: names no runnable command
FAIL P3B-21: names no runnable command
FAIL P3B-22: names no runnable command
FAIL P3B-23: names no runnable command
FAIL P3B-28: names no runnable command
FAIL P3B-29: names no runnable command
FAIL P3B-35: names no runnable command
FAIL P3B-36: names no runnable command
FAIL P3B-37: names no runnable command
FAIL P3B-38: names no runnable command; does not state the expected outcome
FAIL P3B-39: names no runnable command
FAIL P3B-41: names no runnable command
FAIL P3B-43: names no runnable command
FAIL P3B-44: names no runnable command
FAIL P3B-48: names no runnable command
FAIL P3B-49: names no runnable command
FAIL P3B-50: names no runnable command
FAIL P3B-52: names no runnable command; does not state the expected outcome
FAIL P3B-53: names no runnable command
FAIL P3B-57: names no runnable command; does not state the expected outcome
FAIL P3B-60: names no runnable command
FAIL P3B-62: names no runnable command
FAIL P3B-63: names no runnable command
FAIL P5G-05: names no runnable command
FAIL CF-425: names no runnable command
FAIL CF-426: names no runnable command
FAIL P5G-08-R2: unexpanded placeholder <line> — a context-free worker cannot fill it; unexpanded placeholder <commit> — a context-free worker cannot fill it
FAIL CF-441: names no runnable command
FAIL CF-444: names no runnable command; names a flag that does not exist: --skip-tier2
FAIL CF-447: names no runnable command
FAIL P5G-37: unexpanded placeholder <operation_id> — a context-free worker cannot fill it
FAIL CF-452: names no runnable command
FAIL CF-453: names no runnable command
FAIL CF-469: unexpanded placeholder <code> — a context-free worker cannot fill it; unexpanded placeholder <server> — a context-free worker cannot fill it
FAIL CF-108: unexpanded placeholder <bundle> — a context-free worker cannot fill it; unexpanded placeholder <pid> — a context-free worker cannot fill it; unexpanded placeholder <bundle> — a context-free worker cannot fill it
FAIL CF-109: unexpanded placeholder <label> — a context-free worker cannot fill it; unexpanded placeholder <msg> — a context-free worker cannot fill it
FAIL CF-471: unexpanded placeholder <prefix-sha> — a context-free worker cannot fill it
FAIL CF-474: unexpanded placeholder <pathspec> — a context-free worker cannot fill it; unexpanded placeholder <path> — a context-free worker cannot fill it
FAIL CF-477: path not in repo: scripts/board_criteria_check.py
FAIL CF-489: unexpanded placeholder <host> — a context-free worker cannot fill it; unexpanded placeholder <live-crier-url> — a context-free worker cannot fill it; unexpanded placeholder <host> — a context-free worker cannot fill it; unexpanded placeholder <tick> — a context-free worker cannot fill it
FAIL CF-493: path not in repo: docs/leak.md; unexpanded placeholder <root> — a context-free worker cannot fill it; unexpanded placeholder <run> — a context-free worker cannot fill it
FAIL CF-494: names no runnable command
FAIL CF-502: names a flag that does not exist: --deferred
FAIL CF-512: unexpanded placeholder <submodule> — a context-free worker cannot fill it
FAIL CF-524: unexpanded placeholder <module> — a context-free worker cannot fill it; unexpanded placeholder <submodule> — a context-free worker cannot fill it
FAIL CF-527: unexpanded placeholder <id> — a context-free worker cannot fill it
FAIL CF-532: unexpanded placeholder <chat> — a context-free worker cannot fill it; unexpanded placeholder <thread> — a context-free worker cannot fill it
FAIL CF-536: path not in repo: internal/scheduler/dispatch_leg.go; unexpanded placeholder <UTC date> — a context-free worker cannot fill it
FAIL CF-537: unexpanded placeholder <project> — a context-free worker cannot fill it

audit: 381 open rows, 186 failing, 195 passing
```

## Every residual failure

- CF-001 | deferred | owner: CF-001 / code-factory foreman | preserve deferral and review date; foreman reviews before dispatch | gate finding: path not in repo: internal/bus/dispatch_test.go; path not in repo: docs/dispatch-spec.md
- CF-002 | concrete follow-up | owner: CF-002 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-045 | concrete follow-up | owner: CF-045 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <reason> — a context-free worker cannot fill it
- CF-046 | concrete follow-up | owner: CF-046 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <id> — a context-free worker cannot fill it
- CF-053 | concrete follow-up | owner: CF-053 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <agent> — a context-free worker cannot fill it; unexpanded placeholder <path> — a context-free worker cannot fill it
- CF-059 | concrete follow-up | owner: CF-059 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <reason> — a context-free worker cannot fill it; unexpanded placeholder <fp> — a context-free worker cannot fill it; unexpanded placeholder <reason> — a context-free worker cannot fill it
- CF-060 | concrete follow-up | owner: CF-060 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <workdir> — a context-free worker cannot fill it; unexpanded placeholder <url> — a context-free worker cannot fill it; names a flag that does not exist: --expect-remote
- CF-067 | concrete follow-up | owner: CF-067 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <run_id> — a context-free worker cannot fill it; unexpanded placeholder <commit_hash> — a context-free worker cannot fill it; unexpanded placeholder <reason> — a context-free worker cannot fill it
- CF-070 | concrete follow-up | owner: CF-070 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <VARNAME> — a context-free worker cannot fill it
- CF-073 | concrete follow-up | owner: CF-073 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <fp> — a context-free worker cannot fill it; unexpanded placeholder <run_id> — a context-free worker cannot fill it; unexpanded placeholder <reason> — a context-free worker cannot fill it; unexpanded placeholder <commit_hash> — a context-free worker cannot fill it
- PERF-013 | concrete follow-up | owner: PERF-013 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <list> — a context-free worker cannot fill it; unexpanded placeholder <fresh> — a context-free worker cannot fill it
- CF-074 | concrete follow-up | owner: CF-074 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <ref> — a context-free worker cannot fill it; unexpanded placeholder <fp> — a context-free worker cannot fill it; unexpanded placeholder <reason> — a context-free worker cannot fill it; unexpanded placeholder <reason> — a context-free worker cannot fill it; unexpanded placeholder <ref> — a context-free worker cannot fill it; unexpanded placeholder <path> — a context-free worker cannot fill it
- CF-076 | concrete follow-up | owner: CF-076 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <history-date-dir> — a context-free worker cannot fill it; unexpanded placeholder <commit> — a context-free worker cannot fill it
- CF-084 | concrete follow-up | owner: CF-084 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <path> — a context-free worker cannot fill it
- PERF-015 | concrete follow-up | owner: PERF-015 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command; path not in repo: docs/audits/code-factory-perf-2026-11-03-PERF-015.md
- CF-120 | concrete follow-up | owner: CF-120 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <org> — a context-free worker cannot fill it; unexpanded placeholder <repo> — a context-free worker cannot fill it; unexpanded placeholder <org> — a context-free worker cannot fill it; unexpanded placeholder <repo> — a context-free worker cannot fill it
- CF-121 | concrete follow-up | owner: CF-121 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <ref> — a context-free worker cannot fill it
- CF-122 | concrete follow-up | owner: CF-122 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <path> — a context-free worker cannot fill it
- CF-132 | deferred | owner: CF-132 / code-factory foreman | preserve deferral and review date; foreman reviews before dispatch | gate finding: names no runnable command
- CF-136 | deferred | owner: CF-136 / code-factory foreman | preserve deferral and review date; foreman reviews before dispatch | gate finding: names no runnable command
- CF-137 | deferred | owner: CF-137 / code-factory foreman | preserve deferral and review date; foreman reviews before dispatch | gate finding: names no runnable command
- CF-139 | deferred | owner: CF-139 / code-factory foreman | preserve deferral and review date; foreman reviews before dispatch | gate finding: names no runnable command; path not in repo: internal/bus/dispatch.go
- CF-140 | concrete follow-up | owner: CF-140 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <src> — a context-free worker cannot fill it; unexpanded placeholder <new> — a context-free worker cannot fill it; unexpanded placeholder <workdir> — a context-free worker cannot fill it
- CF-144 | concrete follow-up | owner: CF-144 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <committed artifact> — a context-free worker cannot fill it
- CF-146 | concrete follow-up | owner: CF-146 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-149 | concrete follow-up | owner: CF-149 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-158 | concrete follow-up | owner: CF-158 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: path not in repo: scripts/__scope_probe.sh; path not in repo: scripts/boardctl_scope_probe.sh
- CF-160 | concrete follow-up | owner: CF-160 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <repo> — a context-free worker cannot fill it; unexpanded placeholder <node-host> — a context-free worker cannot fill it; unexpanded placeholder <angle-bracket> — a context-free worker cannot fill it; unexpanded placeholder <repo> — a context-free worker cannot fill it
- CF-161 | concrete follow-up | owner: CF-161 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: path not in repo: specs/RELEASE.md; path not in repo: docs/RELEASE.md
- CF-162 | concrete follow-up | owner: CF-162 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <base> — a context-free worker cannot fill it
- CF-164 | concrete follow-up | owner: CF-164 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <nnn> — a context-free worker cannot fill it
- CF-165 | concrete follow-up | owner: CF-165 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <tmp-board-dir> — a context-free worker cannot fill it; unexpanded placeholder <tmp-board-dir> — a context-free worker cannot fill it
- CF-168 | concrete follow-up | owner: CF-168 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <arm> — a context-free worker cannot fill it
- CF-173 | concrete follow-up | owner: CF-173 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names a flag that does not exist: --limit-rate; names a flag that does not exist: --bind
- CF-174 | concrete follow-up | owner: CF-174 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <version string> — a context-free worker cannot fill it
- CF-177 | concrete follow-up | owner: CF-177 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: path not in repo: internal/api/lane_onboarding.go; unexpanded placeholder <sha> — a context-free worker cannot fill it; unexpanded placeholder <sha> — a context-free worker cannot fill it
- CF-178 | concrete follow-up | owner: CF-178 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names a flag that does not exist: --re-arm
- CF-179 | concrete follow-up | owner: CF-179 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <uid> — a context-free worker cannot fill it; unexpanded placeholder <uid> — a context-free worker cannot fill it; unexpanded placeholder <uid> — a context-free worker cannot fill it; unexpanded placeholder <uid> — a context-free worker cannot fill it; unexpanded placeholder <uid> — a context-free worker cannot fill it; unexpanded placeholder <AGENT> — a context-free worker cannot fill it; unexpanded placeholder <server> — a context-free worker cannot fill it; unexpanded placeholder <agent> — a context-free worker cannot fill it
- CF-185 | concrete follow-up | owner: CF-185 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <reason> — a context-free worker cannot fill it; unexpanded placeholder <pid> — a context-free worker cannot fill it; unexpanded placeholder <lane> — a context-free worker cannot fill it
- CF-186 | concrete follow-up | owner: CF-186 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <tip> — a context-free worker cannot fill it
- CF-194 | concrete follow-up | owner: CF-194 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <that directory> — a context-free worker cannot fill it; unexpanded placeholder <path> — a context-free worker cannot fill it
- CF-196 | concrete follow-up | owner: CF-196 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names a flag that does not exist: --force-id
- CF-200 | concrete follow-up | owner: CF-200 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <artifact> — a context-free worker cannot fill it
- CF-201 | concrete follow-up | owner: CF-201 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <run> — a context-free worker cannot fill it; unexpanded placeholder <reason> — a context-free worker cannot fill it
- CF-203 | concrete follow-up | owner: CF-203 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-204 | deferred | owner: CF-204 / code-factory foreman | preserve deferral and review date; foreman reviews before dispatch | gate finding: does not state the expected outcome
- CF-208 | concrete follow-up | owner: CF-208 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: does not state the expected outcome
- CF-212 | concrete follow-up | owner: CF-212 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <branch> — a context-free worker cannot fill it
- CF-213 | concrete follow-up | owner: CF-213 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: does not state the expected outcome
- CF-216 | concrete follow-up | owner: CF-216 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command; path not in repo: internal/bus/dispatch.go
- CF-217 | concrete follow-up | owner: CF-217 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-221 | concrete follow-up | owner: CF-221 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: path not in repo: scripts/install-omp.sh
- CF-222 | concrete follow-up | owner: CF-222 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: path not in repo: scripts/install-omh.sh
- CF-223 | concrete follow-up | owner: CF-223 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: path not in repo: scripts/install-hilo.sh
- CF-232 | concrete follow-up | owner: CF-232 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: path not in repo: specs/DESIGN.md
- CF-233 | concrete follow-up | owner: CF-233 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-234 | concrete follow-up | owner: CF-234 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-236 | concrete follow-up | owner: CF-236 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-237 | concrete follow-up | owner: CF-237 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-242 | concrete follow-up | owner: CF-242 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <copy> — a context-free worker cannot fill it
- CF-243 | concrete follow-up | owner: CF-243 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-249 | concrete follow-up | owner: CF-249 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-251 | deferred | owner: CF-251 / code-factory foreman | preserve deferral and review date; foreman reviews before dispatch | gate finding: names no runnable command; does not state the expected outcome
- CF-255 | concrete follow-up | owner: CF-255 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <id> — a context-free worker cannot fill it
- CF-260 | concrete follow-up | owner: CF-260 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-263 | concrete follow-up | owner: CF-263 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command; does not state the expected outcome
- CF-265 | concrete follow-up | owner: CF-265 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-267 | concrete follow-up | owner: CF-267 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command; does not state the expected outcome
- CF-268 | concrete follow-up | owner: CF-268 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-269 | concrete follow-up | owner: CF-269 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-271 | concrete follow-up | owner: CF-271 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-279 | concrete follow-up | owner: CF-279 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: does not state the expected outcome
- CF-282 | concrete follow-up | owner: CF-282 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-284 | concrete follow-up | owner: CF-284 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-286 | concrete follow-up | owner: CF-286 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-293 | concrete follow-up | owner: CF-293 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-294 | concrete follow-up | owner: CF-294 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-295 | concrete follow-up | owner: CF-295 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-296 | concrete follow-up | owner: CF-296 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command; does not state the expected outcome
- CF-297 | concrete follow-up | owner: CF-297 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-308 | concrete follow-up | owner: CF-308 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-310 | concrete follow-up | owner: CF-310 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command; does not state the expected outcome
- CF-311 | concrete follow-up | owner: CF-311 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command; does not state the expected outcome
- CF-312 | deferred | owner: CF-312 / code-factory foreman | preserve deferral and review date; foreman reviews before dispatch | gate finding: names no runnable command
- CF-314 | deferred | owner: CF-314 / code-factory foreman | preserve deferral and review date; foreman reviews before dispatch | gate finding: names no runnable command; does not state the expected outcome
- CF-317 | concrete follow-up | owner: CF-317 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command; does not state the expected outcome; unexpanded placeholder <project> — a context-free worker cannot fill it; unexpanded placeholder <YYYY-Www> — a context-free worker cannot fill it
- CF-318 | concrete follow-up | owner: CF-318 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command; does not state the expected outcome
- CF-324 | concrete follow-up | owner: CF-324 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-325 | concrete follow-up | owner: CF-325 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-327 | concrete follow-up | owner: CF-327 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-328 | concrete follow-up | owner: CF-328 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-331 | concrete follow-up | owner: CF-331 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command; does not state the expected outcome
- CF-332 | concrete follow-up | owner: CF-332 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-333 | concrete follow-up | owner: CF-333 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-337 | concrete follow-up | owner: CF-337 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-338 | concrete follow-up | owner: CF-338 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-340 | concrete follow-up | owner: CF-340 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-341 | concrete follow-up | owner: CF-341 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-342 | concrete follow-up | owner: CF-342 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command; does not state the expected outcome
- CF-343 | concrete follow-up | owner: CF-343 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command; does not state the expected outcome
- CF-347 | deferred | owner: CF-347 / code-factory foreman | preserve deferral and review date; foreman reviews before dispatch | gate finding: names no runnable command
- CF-348 | concrete follow-up | owner: CF-348 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-349 | concrete follow-up | owner: CF-349 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-350 | concrete follow-up | owner: CF-350 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-351 | concrete follow-up | owner: CF-351 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-352 | concrete follow-up | owner: CF-352 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command; does not state the expected outcome
- CF-353 | concrete follow-up | owner: CF-353 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command; does not state the expected outcome
- CF-358 | concrete follow-up | owner: CF-358 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command; names a flag that does not exist: --allow-missing-workdir
- CF-359 | concrete follow-up | owner: CF-359 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-362 | concrete follow-up | owner: CF-362 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: does not state the expected outcome
- CF-363 | concrete follow-up | owner: CF-363 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-364 | concrete follow-up | owner: CF-364 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: path not in repo: docs/master/00-INDEX.md
- CF-365 | concrete follow-up | owner: CF-365 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-367 | concrete follow-up | owner: CF-367 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-368 | concrete follow-up | owner: CF-368 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-369 | concrete follow-up | owner: CF-369 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-371 | concrete follow-up | owner: CF-371 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <name> — a context-free worker cannot fill it; unexpanded placeholder <name> — a context-free worker cannot fill it
- CF-375 | concrete follow-up | owner: CF-375 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <TAB> — a context-free worker cannot fill it
- CF-377 | concrete follow-up | owner: CF-377 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <fix> — a context-free worker cannot fill it; unexpanded placeholder <board> — a context-free worker cannot fill it; names a flag that does not exist: --closeout-kind; names a flag that does not exist: --closeout-ref
- CF-380 | concrete follow-up | owner: CF-380 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <file> — a context-free worker cannot fill it
- CF-386 | concrete follow-up | owner: CF-386 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <ids> — a context-free worker cannot fill it; unexpanded placeholder <name> — a context-free worker cannot fill it
- CF-389 | concrete follow-up | owner: CF-389 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: path not in repo: docs/audits/fixtures/does-not-exist.json; unexpanded placeholder <row> — a context-free worker cannot fill it; unexpanded placeholder <id> — a context-free worker cannot fill it; unexpanded placeholder <path> — a context-free worker cannot fill it; unexpanded placeholder <tip> — a context-free worker cannot fill it; unexpanded placeholder <path> — a context-free worker cannot fill it
- CF-391 | concrete follow-up | owner: CF-391 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <id> — a context-free worker cannot fill it; unexpanded placeholder <id> — a context-free worker cannot fill it
- P3B-01 | concrete follow-up | owner: P3B-01 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-02 | concrete follow-up | owner: P3B-02 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-03 | concrete follow-up | owner: P3B-03 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-05 | concrete follow-up | owner: P3B-05 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-06 | concrete follow-up | owner: P3B-06 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-08 | concrete follow-up | owner: P3B-08 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-09 | concrete follow-up | owner: P3B-09 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-10 | concrete follow-up | owner: P3B-10 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-11 | concrete follow-up | owner: P3B-11 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-14 | concrete follow-up | owner: P3B-14 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-15 | concrete follow-up | owner: P3B-15 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-16 | concrete follow-up | owner: P3B-16 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-17 | concrete follow-up | owner: P3B-17 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-18 | concrete follow-up | owner: P3B-18 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-19 | concrete follow-up | owner: P3B-19 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-21 | concrete follow-up | owner: P3B-21 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-22 | concrete follow-up | owner: P3B-22 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-23 | concrete follow-up | owner: P3B-23 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-28 | concrete follow-up | owner: P3B-28 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-29 | concrete follow-up | owner: P3B-29 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-35 | concrete follow-up | owner: P3B-35 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-36 | concrete follow-up | owner: P3B-36 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-37 | concrete follow-up | owner: P3B-37 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-38 | concrete follow-up | owner: P3B-38 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command; does not state the expected outcome
- P3B-39 | concrete follow-up | owner: P3B-39 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-41 | concrete follow-up | owner: P3B-41 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-43 | concrete follow-up | owner: P3B-43 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-44 | concrete follow-up | owner: P3B-44 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-48 | concrete follow-up | owner: P3B-48 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-49 | concrete follow-up | owner: P3B-49 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-50 | concrete follow-up | owner: P3B-50 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-52 | concrete follow-up | owner: P3B-52 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command; does not state the expected outcome
- P3B-53 | concrete follow-up | owner: P3B-53 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-57 | concrete follow-up | owner: P3B-57 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command; does not state the expected outcome
- P3B-60 | concrete follow-up | owner: P3B-60 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-62 | concrete follow-up | owner: P3B-62 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P3B-63 | concrete follow-up | owner: P3B-63 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P5G-05 | concrete follow-up | owner: P5G-05 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-425 | concrete follow-up | owner: CF-425 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-426 | concrete follow-up | owner: CF-426 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P5G-08-R2 | concrete follow-up | owner: P5G-08-R2 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <line> — a context-free worker cannot fill it; unexpanded placeholder <commit> — a context-free worker cannot fill it
- CF-441 | concrete follow-up | owner: CF-441 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-444 | concrete follow-up | owner: CF-444 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command; names a flag that does not exist: --skip-tier2
- CF-447 | concrete follow-up | owner: CF-447 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- P5G-37 | concrete follow-up | owner: P5G-37 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <operation_id> — a context-free worker cannot fill it
- CF-452 | deferred | owner: CF-452 / code-factory foreman | preserve deferral and review date; foreman reviews before dispatch | gate finding: names no runnable command
- CF-453 | concrete follow-up | owner: CF-453 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-469 | concrete follow-up | owner: CF-469 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <code> — a context-free worker cannot fill it; unexpanded placeholder <server> — a context-free worker cannot fill it
- CF-108 | concrete follow-up | owner: CF-108 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <bundle> — a context-free worker cannot fill it; unexpanded placeholder <pid> — a context-free worker cannot fill it; unexpanded placeholder <bundle> — a context-free worker cannot fill it
- CF-109 | concrete follow-up | owner: CF-109 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <label> — a context-free worker cannot fill it; unexpanded placeholder <msg> — a context-free worker cannot fill it
- CF-471 | concrete follow-up | owner: CF-471 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <prefix-sha> — a context-free worker cannot fill it
- CF-474 | deferred | owner: CF-474 / code-factory foreman | preserve deferral and review date; foreman reviews before dispatch | gate finding: unexpanded placeholder <pathspec> — a context-free worker cannot fill it; unexpanded placeholder <path> — a context-free worker cannot fill it
- CF-477 | concrete follow-up | owner: CF-477 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: path not in repo: scripts/board_criteria_check.py
- CF-489 | concrete follow-up | owner: CF-489 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <host> — a context-free worker cannot fill it; unexpanded placeholder <live-crier-url> — a context-free worker cannot fill it; unexpanded placeholder <host> — a context-free worker cannot fill it; unexpanded placeholder <tick> — a context-free worker cannot fill it
- CF-493 | concrete follow-up | owner: CF-493 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: path not in repo: docs/leak.md; unexpanded placeholder <root> — a context-free worker cannot fill it; unexpanded placeholder <run> — a context-free worker cannot fill it
- CF-494 | concrete follow-up | owner: CF-494 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names no runnable command
- CF-502 | concrete follow-up | owner: CF-502 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: names a flag that does not exist: --deferred
- CF-512 | concrete follow-up | owner: CF-512 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <submodule> — a context-free worker cannot fill it
- CF-524 | concrete follow-up | owner: CF-524 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <module> — a context-free worker cannot fill it; unexpanded placeholder <submodule> — a context-free worker cannot fill it
- CF-527 | concrete follow-up | owner: CF-527 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <id> — a context-free worker cannot fill it
- CF-532 | concrete follow-up | owner: CF-532 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <chat> — a context-free worker cannot fill it; unexpanded placeholder <thread> — a context-free worker cannot fill it
- CF-536 | concrete follow-up | owner: CF-536 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: path not in repo: internal/scheduler/dispatch_leg.go; unexpanded placeholder <UTC date> — a context-free worker cannot fill it
- CF-537 | concrete follow-up | owner: CF-537 / code-factory foreman | foreman for this row: inspect original intent and repair the cited gate finding; do not dispatch solely on this audit | gate finding: unexpanded placeholder <project> — a context-free worker cannot fill it

## Targeted validation, exact captured output

The drift check compares the intentionally edited board with the unchanged published ref. Its byte-parity failure is expected until the foreman publishes the change; it is not a clean result.

```text
$ jq -e -c . .coding-hermes/board/tasks.jsonl > /dev/null
exit=0
$ wc -l .coding-hermes/board/tasks.jsonl
643 .coding-hermes/board/tasks.jsonl
exit=0
$ bash scripts/boardctl validate
The validation was run from the repository root; its board path is intentionally described as `board/tasks.jsonl` (not an absolute host path).
rows: 643 tasks, 1073 events, 0 fixtures
key uniformity: 638/643 rows carry only canon keys; drift 5 row(s): acceptance(2), chapter(2), created(2), model(2), notes(2), owner(1) — 0 fixable by 'boardctl update <id> --normalize'
[warn] tasks.jsonl line 20 (task CF-034): guard_result "PASS (Tier 1 on merged tree; secrets clean, selftest PASS; Tier 2 INCOMPLETE due evaluator iteration cap 15, not a source failure)" is free-form — not in the guard_result vocabulary {PASS,FAIL,SKIP} (valid: that vocabulary or the structured form {"status":"pass|fail|skip|pending","details":"<prose>"}; writes now enforce this; hand-edit the row or rewrite via boardctl update)
[warn] tasks.jsonl line 20 (task CF-034): ci_result "pending push" is free-form — not in the ci_result vocabulary {GREEN,RED,SKIP} (valid: that vocabulary or the structured form {"status":"pass|fail|skip|pending","details":"<prose>"}; writes now enforce this; hand-edit the row or rewrite via boardctl update)
[warn] tasks.jsonl line 108 (task CF-133): key(s) {notes} outside the declared canon
[warn] tasks.jsonl line 125 (task CF-150): title carries "P3" but priority is "P1" — the priority field wins; rewrite the title with 'boardctl update CF-150 --title', or fix the field with 'boardctl update CF-150 --priority <Pn>', or re-file the row with 'boardctl create --id CF-150 --force --priority <Pn>' if it should be re-filed
[warn] tasks.jsonl line 167 (task CF-192): title carries "P3" but priority is "P1" — the priority field wins; rewrite the title with 'boardctl update CF-192 --title', or fix the field with 'boardctl update CF-192 --priority <Pn>', or re-file the row with 'boardctl create --id CF-192 --force --priority <Pn>' if it should be re-filed
[warn] tasks.jsonl line 205 (task CF-231): guard_result "PASS (tier-1 selftest SELFTEST: PASS EXIT=0 at 6c6d4ac; tier-2 verdict see foreman_note)" is free-form — not in the guard_result vocabulary {PASS,FAIL,SKIP} (valid: that vocabulary or the structured form {"status":"pass|fail|skip|pending","details":"<prose>"}; writes now enforce this; hand-edit the row or rewrite via boardctl update)
[warn] tasks.jsonl line 222 (task CF-248): non-deferred row carries defer_reason or defer_review_by — defer the row or remove the stale fields
[warn] tasks.jsonl line 345 (task CF-371): title carries "P1" but priority is "P3" — the priority field wins; rewrite the title with 'boardctl update CF-371 --title', or fix the field with 'boardctl update CF-371 --priority <Pn>', or re-file the row with 'boardctl create --id CF-371 --force --priority <Pn>' if it should be re-filed
[warn] tasks.jsonl line 371 (task CF-395): guard_result "PASS (Tier 1 selftest PASS at 58be4c34; Tier 2 judge PASS, verdict 675a8acd)" is free-form — not in the guard_result vocabulary {PASS,FAIL,SKIP} (valid: that vocabulary or the structured form {"status":"pass|fail|skip|pending","details":"<prose>"}; writes now enforce this; hand-edit the row or rewrite via boardctl update)
[warn] tasks.jsonl line 371 (task CF-395): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 372 (task CF-396): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 373 (task CF-397): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 374 (task P3B-01): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 375 (task P3B-02): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 376 (task P3B-03): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 377 (task P3B-04): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 378 (task P3B-05): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 379 (task P3B-06): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 380 (task P3B-07): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 381 (task P3B-08): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 382 (task P3B-09): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 383 (task P3B-10): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 384 (task P3B-11): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 385 (task P3B-12): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 386 (task P3B-13): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 387 (task P3B-14): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 388 (task P3B-15): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 389 (task P3B-16): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 390 (task P3B-17): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 391 (task P3B-18): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 392 (task P3B-19): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 393 (task P3B-20): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 394 (task P3B-21): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 395 (task P3B-22): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 396 (task P3B-23): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 397 (task P3B-24): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 398 (task P3B-25): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 399 (task P3B-26): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 400 (task P3B-27): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 401 (task P3B-28): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 402 (task P3B-29): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 403 (task P3B-30): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 404 (task P3B-31): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 405 (task P3B-32): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 406 (task P3B-33): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 407 (task P3B-34): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 408 (task P3B-35): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 409 (task P3B-36): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 410 (task P3B-37): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 411 (task P3B-38): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 412 (task P3B-39): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 413 (task P3B-40): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 414 (task P3B-41): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 415 (task P3B-42): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 416 (task P3B-43): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 417 (task P3B-44): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 418 (task P3B-45): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 419 (task P3B-46): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 420 (task P3B-47): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 421 (task P3B-48): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 422 (task P3B-49): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 423 (task P3B-50): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 424 (task P3B-51): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 425 (task P3B-52): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 426 (task P3B-53): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 427 (task P3B-54): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 428 (task P3B-55): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 429 (task P3B-56): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 430 (task P3B-57): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 431 (task P3B-58): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 432 (task P3B-59): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 433 (task P3B-60): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 434 (task P3B-61): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 435 (task P3B-62): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 436 (task P3B-63): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 437 (task CF-398): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 438 (task CF-399): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 439 (task CF-401): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 440 (task CF-400): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 441 (task CF-402): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 442 (task CF-403): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 443 (task CF-404): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 444 (task CF-405): branches is not an array (null) — treated as no associations (writes store an array of validated elements)
[warn] tasks.jsonl line 445 (task CF-406): created_at absent — the report parser excludes this row from time-based metrics; hand-edit the row to add a parseable created_at
[warn] tasks.jsonl line 445 (task CF-406): key(s) {acceptance, chapter, created, model} outside the declared canon
[warn] tasks.jsonl line 446 (task CF-407): created_at absent — the report parser excludes this row from time-based metrics; hand-edit the row to add a parseable created_at
[warn] tasks.jsonl line 446 (task CF-407): key(s) {acceptance, chapter, created, model} outside the declared canon
[warn] tasks.jsonl line 451 (task CF-412): non-deferred row carries defer_reason or defer_review_by — defer the row or remove the stale fields
[warn] tasks.jsonl line 454 (task CF-415): created_at absent — the report parser excludes this row from time-based metrics; hand-edit the row to add a parseable created_at
[warn] tasks.jsonl line 458 (task P5G-04): guard_result "PASS (no source touched; board-only diff)" is free-form — not in the guard_result vocabulary {PASS,FAIL,SKIP} (valid: that vocabulary or the structured form {"status":"pass|fail|skip|pending","details":"<prose>"}; writes now enforce this; hand-edit the row or rewrite via boardctl update)
[warn] tasks.jsonl line 458 (task P5G-04): ci_result "SKIP (repo declares no workflows)" is free-form — not in the ci_result vocabulary {GREEN,RED,SKIP} (valid: that vocabulary or the structured form {"status":"pass|fail|skip|pending","details":"<prose>"}; writes now enforce this; hand-edit the row or rewrite via boardctl update)
[warn] tasks.jsonl line 559 (task CF-470): guard_result "gitreins task complete CF-470: task marked complete 2026-11-16T21:14:09Z; guard leg ran bash tests/selftest.sh -> SELFTEST: PASS, EXIT=0 (.gitreins/logs/guard-20261116T210222.246519Z.log); tier-2 judge still evaluating when this row was written (verdict.json not yet on disk)." is free-form — not in the guard_result vocabulary {PASS,FAIL,SKIP} (valid: that vocabulary or the structured form {"status":"pass|fail|skip|pending","details":"<prose>"}; writes now enforce this; hand-edit the row or rewrite via boardctl update)
[warn] tasks.jsonl line 559 (task CF-470): ci_result "local: bash tests/selftest.sh on the rebased tree 86543619 -> 'SELFTEST: PASS', EXIT=0, 0 FAIL (foreman re-run, independent of the worker's run). gate: anchored private-IPv4 grep over origin/main excluding .coding-hermes and docs/audits -> 0 hits, exit 1 (baseline 4 at da65a9a8). CI: run 43957908646 on 86543619 is RED on one arm only, 'CF-398 evidence checker (exit 0, strict 1): checked 175 complete rows, 103 unresolved'; the same arm is red at 4382a38a (run 43952756581) and 28aa4778 (run 43956476062), i.e. before this commit — reproduced from a fresh clone outside CI (nonstrict rc=0, strict rc=1, expected_unresolved=62 vs 103 unresolved). That break is owned by CF-475, not this row. gitleaks and every section-61 arm are green." is free-form — not in the ci_result vocabulary {GREEN,RED,SKIP} (valid: that vocabulary or the structured form {"status":"pass|fail|skip|pending","details":"<prose>"}; writes now enforce this; hand-edit the row or rewrite via boardctl update)
[warn] tasks.jsonl line 595 (task CF-503): created_at unparseable "2026-11-20" — the report parser excludes this row from time-based metrics; hand-edit the row to add a parseable created_at
[warn] tasks.jsonl line 595 (task CF-503): key(s) {owner} outside the declared canon
[warn] tasks.jsonl line 613 (task CF-521): key(s) {notes} outside the declared canon
[warn] tasks.jsonl line 621 (task CF-529): guard_result "FAIL tier1 tests-full, sole arm = foreign consumer-pin drift (CF-534, out-of-repo dispatch_leg.go anchors), counterfactually red at parent tip, disclosed; lint+secrets clean; tests.test_bus_result_delivery solo 13 OK" is free-form — not in the guard_result vocabulary {PASS,FAIL,SKIP} (valid: that vocabulary or the structured form {"status":"pass|fail|skip|pending","details":"<prose>"}; writes now enforce this; hand-edit the row or rewrite via boardctl update)
[warn] tasks.jsonl line 621 (task CF-529): ci_result "GREEN at 5e14cfea (hosted run 2026-11-25T00:39:58Z, success)" is free-form — not in the ci_result vocabulary {GREEN,RED,SKIP} (valid: that vocabulary or the structured form {"status":"pass|fail|skip|pending","details":"<prose>"}; writes now enforce this; hand-edit the row or rewrite via boardctl update)
[warn] events.jsonl line 337: duplicate event id 336 (also line 336) — benign legacy duplicates exist on live boards
[warn] events.jsonl line 670: event has no id field (legacy shape tolerated)
[warn] events.jsonl line 973: duplicate event id 970 (also line 971) — benign legacy duplicates exist on live boards
[warn] events.jsonl line 974: duplicate event id 971 (also line 972) — benign legacy duplicates exist on live boards
[warn] headerless board (no board.jsonl): tasks.jsonl line 1 is a task row, not board metadata — no header to validate; header counter checks skipped
RESULT: OK (103 warning(s))
exit=0
$ python3 scripts/board_drift.py check --workdir . --ref origin/main
PASS  workdir files — tasks.jsonl: 2248232 bytes
PASS  workdir files — events.jsonl: 615088 bytes
PASS  published ref — origin/main:.coding-hermes/board/tasks.jsonl resolved
PASS  published ref — origin/main:.coding-hermes/board/events.jsonl resolved
PASS  sha256 workdir tasks.jsonl — 448b7291a3aff35b22bc53c3620363e2dc35782c3572d8e612c9c6289cefba44
PASS  sha256 published tasks.jsonl — c0d6c7e2181e0c35669080d968db8da94c87d16f261362b5de1deeed186a8bae
FAIL  byte parity tasks.jsonl — bytes differ
PASS  sha256 workdir events.jsonl — e508465f3cc5f841098622238e1c73dca456acba2335cc6c9a218ff9225b76a2
PASS  sha256 published events.jsonl — e508465f3cc5f841098622238e1c73dca456acba2335cc6c9a218ff9225b76a2
PASS  byte parity events.jsonl — identical
PASS  board missing ids — none
PASS  board extra ids — none
PASS  board rows — 643 vs 643 rows; 0 divergent ids: none
PASS  HEAD — git rev-parse HEAD: f71c61ace780b8ef1b5b2c226e7faaa47ee3d538
PASS  HEAD ancestry — git merge-base --is-ancestor HEAD origin/main: exit 0; HEAD=f71c61ace780b8ef1b5b2c226e7faaa47ee3d538 origin/main=f71c61ace780b8ef1b5b2c226e7faaa47ee3d538
RESULT: DRIFT (1 failed)
exit=1
```
