# Verdict: CF-QA-1103

**Task:** QA tick: re-verify six closed rows and file the three gaps the manifest/apply paths leave untested
**Evaluated:** 2026-11-03T15:46:44.640251
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ At the pushed tip, .coding-hermes/board/tasks.jsonl contains rows CF-078, CF-079 and CF-080 with status pending; each row's reasoning cites a file:line or a command whose output a reviewer can reproduce (grep -rn CRIER_BASE, sed -n on scripts/project-node.sh, and the documented --apply clone run); tests/selftest.sh still prints SELFTEST: PASS; origin/main equals HEAD after the push.: All sub-claims verified with live command output.

(1) ROWS PENDING — python3 parse of .coding-hermes/board/tasks.jsonl returned: `CF-078 | status= pending | priority= P3`, `CF-079 | status= pending | priority= P4`, `CF-080 | status= pending | priority= P4`. Added by commit a25b7fd (3 insertions to tasks.jsonl, 3 to events.jsonl; events rows 70/71 are `task_created` for CF-079/CF-080).

(2) grep -rn CRIER_BASE REPRODUCES — `grep -rn CRIER_BASE --include=*.sh --include=*.md --include=*.py .` returns exactly ONE hit: `./scripts/project-node.sh:264: "bus": {"base": __import__("os").environ.get("CRIER_BASE", "http://crier.example:8767")}` — precisely CF-078's claim of 'exactly one hit — that same line'.

(3) sed -n ON scripts/project-node.sh REPRODUCES — `sed -n '255,266p'` shows the manifest writer emitting `repo.path` as `"/home/" + $USER + "/repo"` (string-built, not measured), `harness {name,port}` with no `harness.version`, and `bus {base}` with no `bus.agent_id` — matching CF-078 verbatim. `sed -n '147,160p'` shows layer 00 measuring `CRIER="${CRIER_URL:-}"`, i.e. CRIER_URL not CRIER_BASE, as CF-078 states. `sed -n '197,208p'` shows layer 30 testing only `-f $STATE/crier.json` plus mode 600 with no pull worker (CF-079). `sed -n '250,270p'` shows layer 90 writing node.json only, no digest row (CF-079). `sed -n '141,143p'` shows the 'apply refuses immediately' comment (CF-080). Specs corroborate: specs/NODE.md:7-16 requires bus.agent_id + harness.version; :29 claims 'a pull worker'; :31 claims 'one round trip whose digest is recomputed'; AGENTS.md:26 rule 1 and AGENTS.md:42 rule 9 ('Bus before workspace') both exist as cited.

(4) DOCUMENTED --apply CLONE RUN REPRODUCED LIVE — `CRIER_URL=http://crier.example:8767 HOME=<tmp> ./scripts/project-node.sh --apply --project myproject --repo https://github.com/github/gitignore --ref main` printed `FAIL crier_identity — absent — stage a bundle and re-run; a node without an identity is invisible` at `[30] bus`, then `[40] repo .. cloning`, then `PASS repo_clone — /home/kara/.hermes/cache/scratch/tmp.ghYQ8mHhFJ/repo @ 6bb5af7`, ending `NODE: FAIL (3)`. `ls -d $TMPH/repo` confirmed the directory EXISTS afterward. This matches CF-080's transcript exactly, including the 6bb5af7 short SHA.

(5) SELFTEST PASSES — `bash tests/selftest.sh > /tmp/st.log 2>&1; echo EXIT=$?` returned `EXIT=0`; `/tmp/st.log:53: SELFTEST: PASS`; 35 PASS lines and no failing assertion.

(6) origin/main == HEAD — `git rev-parse HEAD` = `a25b7fd9f1477da991c198cabe9b098c51de13aa`; `git rev-parse origin/main` = `a25b7fd9f1477da991c198cabe9b098c51de13aa`. Identical. No tracked-file modifications outstanding (only untracked .gitreins/history bundles and board/.lock).
All three rows CF-078/CF-079/CF-080 are present with status pending, every cited file:line and command (grep -rn CRIER_BASE, sed -n on scripts/project-node.sh, and the documented --apply clone run) reproduces exactly as described, tests/selftest.sh exits 0 printing SELFTEST: PASS, and origin/main equals HEAD at a25b7fd.

## Summary

Judge Result: CF-QA-1103

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ At the pushed tip, .coding-hermes/board/tasks.jsonl contains rows CF-078, CF-079 and CF-080 with status pending; each row's reasoning cites a file:line or a command whose output a reviewer can reproduce (grep -rn CRIER_BASE, sed -n on scripts/project-node.sh, and the documented --apply clone run); tests/selftest.sh still prints SELFTEST: PASS; origin/main equals HEAD after the push.: All sub-claims verified with live command output.

(1) ROWS PENDING — python3 parse of .coding-hermes/board/tasks.jsonl returned: `CF-078 | status= pending | priority= P3`, `CF-079 | status= pending | priority= P4`, `CF-080 | status= pending | priority= P4`. Added by commit a25b7fd (3 insertions to tasks.jsonl, 3 to events.jsonl; events rows 70/71 are `task_created` for CF-079/CF-080).

(2) grep -rn CRIER_BASE REPRODUCES — `grep -rn CRIER_BASE --include=*.sh --include=*.md --include=*.py .` returns exactly ONE hit: `./scripts/project-node.sh:264: "bus": {"base": __import__("os").environ.get("CRIER_BASE", "http://crier.example:8767")}` — precisely CF-078's claim of 'exactly one hit — that same line'.

(3) sed -n ON scripts/project-node.sh REPRODUCES — `sed -n '255,266p'` shows the manifest writer emitting `repo.path` as `"/home/" + $USER + "/repo"` (string-built, not measured), `harness {name,port}` with no `harness.version`, and `bus {base}` with no `bus.agent_id` — matching CF-078 verbatim. `sed -n '147,160p'` shows layer 00 measuring `CRIER="${CRIER_URL:-}"`, i.e. CRIER_URL not CRIER_BASE, as CF-078 states. `sed -n '197,208p'` shows layer 30 testing only `-f $STATE/crier.json` plus mode 600 with no pull worker (CF-079). `sed -n '250,270p'` shows layer 90 writing node.json only, no digest row (CF-079). `sed -n '141,143p'` shows the 'apply refuses immediately' comment (CF-080). Specs corroborate: specs/NODE.md:7-16 requires bus.agent_id + harness.version; :29 claims 'a pull worker'; :31 claims 'one round trip whose digest is recomputed'; AGENTS.md:26 rule 1 and AGENTS.md:42 rule 9 ('Bus before workspace') both exist as cited.

(4) DOCUMENTED --apply CLONE RUN REPRODUCED LIVE — `CRIER_URL=http://crier.example:8767 HOME=<tmp> ./scripts/project-node.sh --apply --project myproject --repo https://github.com/github/gitignore --ref main` printed `FAIL crier_identity — absent — stage a bundle and re-run; a node without an identity is invisible` at `[30] bus`, then `[40] repo .. cloning`, then `PASS repo_clone — /home/kara/.hermes/cache/scratch/tmp.ghYQ8mHhFJ/repo @ 6bb5af7`, ending `NODE: FAIL (3)`. `ls -d $TMPH/repo` confirmed the directory EXISTS afterward. This matches CF-080's transcript exactly, including the 6bb5af7 short SHA.

(5) SELFTEST PASSES — `bash tests/selftest.sh > /tmp/st.log 2>&1; echo EXIT=$?` returned `EXIT=0`; `/tmp/st.log:53: SELFTEST: PASS`; 35 PASS lines and no failing assertion.

(6) origin/main == HEAD — `git rev-parse HEAD` = `a25b7fd9f1477da991c198cabe9b098c51de13aa`; `git rev-parse origin/main` = `a25b7fd9f1477da991c198cabe9b098c51de13aa`. Identical. No tracked-file modifications outstanding (only untracked .gitreins/history bundles and board/.lock).
All three rows CF-078/CF-079/CF-080 are present with status pending, every cited file:line and command (grep -rn CRIER_BASE, sed -n on scripts/project-node.sh, and the documented --apply clone run) reproduces exactly as described, tests/selftest.sh exits 0 printing SELFTEST: PASS, and origin/main equals HEAD at a25b7fd.

Overall: PASS ✓
