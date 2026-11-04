# Verdict: CF-DOG-2026-11-04C

**Task:** File CF-179: node-create success line names a literal <uid> placeholder
**Evaluated:** 2026-11-04T08:10:56.766483
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Filing-only scope: row CF-179 is present and pending in .coding-hermes/board/tasks.jsonl at this commit, carries acceptance_criteria and a re-runnable probe, and the probe's reproduction (grep shows the /home/<uid> line; test -e on the named path exits 1) is quoted verbatim in the commit body. The repair is future work tracked by the pending row and is NOT expected at this commit.: Row present: .coding-hermes/board/tasks.jsonl:153 (added by HEAD 409b07b, which changes only tasks.jsonl + events.jsonl). Parsed the added JSON line: id=CF-179, status="pending", keys include acceptance_criteria (1479 chars, 5 numbered items) and probe="grep -n 'manifest: /home/<uid>' scripts/node-create.sh && test -e '/home/<uid>/.node/node.json'; echo \"named_path_exists=$?\"" (re-runnable). events.jsonl adds task_created event id=281 for CF-179 with detail {"id":"CF-179","status":"pending"}. I re-ran the probe: grep printed `130:[ "$FAILED" -eq 0 ] && { say "NODE CREATED: $AGENT"; say "manifest: /home/<uid>/.node/node.json"; exit 0; }` with G1_RC=0, and `test -e '/home/<uid>/.node/node.json'` gave named_path_exists=1. Commit body lines 14-20 quote this verbatim (including the `130:` grep prefix, `G1_RC=0` and `named_path_exists=1`); diff of the quoted line against scripts/node-create.sh:130 is byte-identical after stripping the grep prefix. Repair correctly absent: scripts/node-create.sh:130 still contains the literal /home/<uid>, `git diff HEAD -- scripts/node-create.sh` is empty, and the commit touches no source files — the fix is tracked as future work by the pending row.
CF-179 is filed as a pending board row with acceptance_criteria and a re-runnable probe whose reproduction I re-verified and which is quoted verbatim in the commit body, while the actual repair is correctly left as future work.

## Summary

Judge Result: CF-DOG-2026-11-04C

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Filing-only scope: row CF-179 is present and pending in .coding-hermes/board/tasks.jsonl at this commit, carries acceptance_criteria and a re-runnable probe, and the probe's reproduction (grep shows the /home/<uid> line; test -e on the named path exits 1) is quoted verbatim in the commit body. The repair is future work tracked by the pending row and is NOT expected at this commit.: Row present: .coding-hermes/board/tasks.jsonl:153 (added by HEAD 409b07b, which changes only tasks.jsonl + events.jsonl). Parsed the added JSON line: id=CF-179, status="pending", keys include acceptance_criteria (1479 chars, 5 numbered items) and probe="grep -n 'manifest: /home/<uid>' scripts/node-create.sh && test -e '/home/<uid>/.node/node.json'; echo \"named_path_exists=$?\"" (re-runnable). events.jsonl adds task_created event id=281 for CF-179 with detail {"id":"CF-179","status":"pending"}. I re-ran the probe: grep printed `130:[ "$FAILED" -eq 0 ] && { say "NODE CREATED: $AGENT"; say "manifest: /home/<uid>/.node/node.json"; exit 0; }` with G1_RC=0, and `test -e '/home/<uid>/.node/node.json'` gave named_path_exists=1. Commit body lines 14-20 quote this verbatim (including the `130:` grep prefix, `G1_RC=0` and `named_path_exists=1`); diff of the quoted line against scripts/node-create.sh:130 is byte-identical after stripping the grep prefix. Repair correctly absent: scripts/node-create.sh:130 still contains the literal /home/<uid>, `git diff HEAD -- scripts/node-create.sh` is empty, and the commit touches no source files — the fix is tracked as future work by the pending row.
CF-179 is filed as a pending board row with acceptance_criteria and a re-runnable probe whose reproduction I re-verified and which is quoted verbatim in the commit body, while the actual repair is correctly left as future work.

Overall: PASS ✓
