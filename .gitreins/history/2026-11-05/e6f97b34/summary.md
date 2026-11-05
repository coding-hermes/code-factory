# Verdict: CF-220-R1

**Task:** verification-only closeout: CF-220 seed contract proven live on cf-node
**Evaluated:** 2026-11-05T13:18:24.200509
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ 1. bash tests/selftest.sh prints SELFTEST: PASS and its node_seed section prints six PASS arms (build/apply/tamper/mismatch/budget/backup).: Fresh run `bash tests/selftest.sh` exit_code=0; tail shows the node_seed section ("node_seed — the declared seed, its digests, and what it refuses") with exactly six PASS arms: build/apply install+green check/tamper named exit 1/digest-mismatch refuses and installs nothing/size budget refused/backup artefact refused, and final line `SELFTEST: PASS`. (One earlier line 'FAIL push — remote: rejected by fixture hook' is a fixture arm whose next PASS asserts the refusal is honored; the suite is green.)
  ✓ 2. scripts/node_seed.py and config/node-seed.txt exist and scripts/bunker-provision.sh invokes node_seed.py build+apply in its provisioning path.: `ls` shows scripts/node_seed.py (10141 B) and config/node-seed.txt (500 B, declaring prompts/*.md + skills globs). scripts/bunker-provision.sh:454-460 in the provisioning path: seed_manifest="$HERE/../config/node-seed.txt" then `python3 "$HERE/node_seed.py" build --manifest "$seed_manifest" --repo-root ... --out seed.tar`, stages tar+record+script to the agent, and runs `python3 $HOME/node_seed.py apply --tar $HOME/seed.tar --record $HOME/seed.tar.json --home $HOME`, with ok/bad rows on exit.
  ✓ 3. A committed evidence artifact docs/audits/code-factory-cf220-2026-11-05.md quotes the live red arm (FAIL seed_check prompts/foreman.md drifted) and the green arms on cf-node with the exact commands.: The file exists (5307 B, committed in HEAD ce86ca3 — commit adds it with 98 insertions, tree clean, `git status --porcelain` empty). It quotes the live red arm on cf-node: `FAIL  seed_check — prompts/foreman.md drifted (75da16fb93fd != 82c020b6f316)` / `1 of 13 seeded files differ from the record` EXIT=1, the green arms `PASS  seed_check — 13 files present and matching` EXIT=0 before the probe and after the `cp $HOME/foreman.md.bak-cf220` restore, and the exact commands: `bunker --server bunker-las-03 exec cf-node -- bash -lc '...'` for the state measurements and the ssh-side `node_seed.py check --record $HOME/.hermes/seed-applied.json --home $HOME` / `printf '\n<!-- drift probe -->\n' >> .../prompts/foreman.md` sequence, plus `bash tests/selftest.sh | tail -8` green output.
  ✓ 4. jq -e 'select(.id=="CF-220")|.status=="complete"' .coding-hermes/board/tasks.jsonl succeeds and the row carries commit_hash b3ed55c and evidence naming that artifact.: Ran the exact jq: output `true`, JQ_EXIT=0. The CF-220 row has status "complete", commit_hash "b3ed55cd944bccece799be5f79d0895bd9881293" (prefix b3ed55c — verified by `git show --stat b3ed55c` which shows the real feat(seed) commit), and detail.evidence[0] = {run_id: diag-node-1-2026-11-05-cf220-live, artifacts: ["docs/audits/code-factory-cf220-2026-11-05.md"]}, naming the artifact.
All four criteria verified with live command output: selftest green with six PASS node_seed arms, node_seed.py/node-seed.txt present and wired into bunker-provision.sh's build+apply provisioning path, the committed audit artifact quoting the live red and green seed_check runs on cf-node with exact commands, and the board row complete with commit b3ed55c and the artifact as evidence.

## Summary

Judge Result: CF-220-R1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ 1. bash tests/selftest.sh prints SELFTEST: PASS and its node_seed section prints six PASS arms (build/apply/tamper/mismatch/budget/backup).: Fresh run `bash tests/selftest.sh` exit_code=0; tail shows the node_seed section ("node_seed — the declared seed, its digests, and what it refuses") with exactly six PASS arms: build/apply install+green check/tamper named exit 1/digest-mismatch refuses and installs nothing/size budget refused/backup artefact refused, and final line `SELFTEST: PASS`. (One earlier line 'FAIL push — remote: rejected by fixture hook' is a fixture arm whose next PASS asserts the refusal is honored; the suite is green.)
  ✓ 2. scripts/node_seed.py and config/node-seed.txt exist and scripts/bunker-provision.sh invokes node_seed.py build+apply in its provisioning path.: `ls` shows scripts/node_seed.py (10141 B) and config/node-seed.txt (500 B, declaring prompts/*.md + skills globs). scripts/bunker-provision.sh:454-460 in the provisioning path: seed_manifest="$HERE/../config/node-seed.txt" then `python3 "$HERE/node_seed.py" build --manifest "$seed_manifest" --repo-root ... --out seed.tar`, stages tar+record+script to the agent, and runs `python3 $HOME/node_seed.py apply --tar $HOME/seed.tar --record $HOME/seed.tar.json --home $HOME`, with ok/bad rows on exit.
  ✓ 3. A committed evidence artifact docs/audits/code-factory-cf220-2026-11-05.md quotes the live red arm (FAIL seed_check prompts/foreman.md drifted) and the green arms on cf-node with the exact commands.: The file exists (5307 B, committed in HEAD ce86ca3 — commit adds it with 98 insertions, tree clean, `git status --porcelain` empty). It quotes the live red arm on cf-node: `FAIL  seed_check — prompts/foreman.md drifted (75da16fb93fd != 82c020b6f316)` / `1 of 13 seeded files differ from the record` EXIT=1, the green arms `PASS  seed_check — 13 files present and matching` EXIT=0 before the probe and after the `cp $HOME/foreman.md.bak-cf220` restore, and the exact commands: `bunker --server bunker-las-03 exec cf-node -- bash -lc '...'` for the state measurements and the ssh-side `node_seed.py check --record $HOME/.hermes/seed-applied.json --home $HOME` / `printf '\n<!-- drift probe -->\n' >> .../prompts/foreman.md` sequence, plus `bash tests/selftest.sh | tail -8` green output.
  ✓ 4. jq -e 'select(.id=="CF-220")|.status=="complete"' .coding-hermes/board/tasks.jsonl succeeds and the row carries commit_hash b3ed55c and evidence naming that artifact.: Ran the exact jq: output `true`, JQ_EXIT=0. The CF-220 row has status "complete", commit_hash "b3ed55cd944bccece799be5f79d0895bd9881293" (prefix b3ed55c — verified by `git show --stat b3ed55c` which shows the real feat(seed) commit), and detail.evidence[0] = {run_id: diag-node-1-2026-11-05-cf220-live, artifacts: ["docs/audits/code-factory-cf220-2026-11-05.md"]}, naming the artifact.
All four criteria verified with live command output: selftest green with six PASS node_seed arms, node_seed.py/node-seed.txt present and wired into bunker-provision.sh's build+apply provisioning path, the committed audit artifact quoting the live red and green seed_check runs on cf-node with exact commands, and the board row complete with commit b3ed55c and the artifact as evidence.

Overall: PASS ✓
