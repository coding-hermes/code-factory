# Verdict: CF-051

**Task:** node-create.sh --agent must validate the agent exists before reusing it
**Evaluated:** 2026-11-06T22:33:22.727242
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ AC1: with --agent naming no existing agent, scripts/node-create.sh fails at step 1 with a named FAIL line naming the missing agent and the remedy, and makes no staging invocation (no bunker exec/cp).: scripts/node-create.sh:107-111 — in the --agent branch, step 1 probes `"$b" info "$AGENT" --server "$SERVER"`; on failure it calls `bad "agent" "$AGENT not found on $SERVER — spawn it (drop --agent) or pass an existing agent id"` then `exit 1`. bad() (scripts/lib.sh:7) prints `  FAIL  agent — ...`, naming the id and the remedy. This runs before step 2 staging (line 114+), so no spawn/cp/exec occurs. Fixture ARM1 output: `PASS  missing --agent -> named FAIL agent, exit 1, info probed, zero staging calls`.
  ✓ AC2: with --agent naming an existing agent, reuse behaviour is unchanged and provisioning proceeds; the no-flag path still spawns and reuses its own agent.: scripts/node-create.sh:99-112 — no-flag path still spawns (`"$b" spawn "$AGENT" --server "$SERVER" --ttl "$TTL"`, SPAWNED=1, `ok "spawn" "$AGENT"`); --agent path with an existing agent prints `ok "spawn" "reusing $AGENT"` and falls through to unchanged step 2 staging / step 3 provision / step 4 verify. Fixture ARM2 output: `PASS  existing --agent -> reuse row printed, staging reached, node created (exit 0)`.
  ✓ AC3: bash tests/selftest.sh prints SELFTEST: PASS and carries a fixture with both arms (missing-agent -> named step-1 FAIL and no staging; existing-agent -> reuse PASS).: Ran `bash tests/selftest.sh` (exit 0); output line 107: `SELFTEST: PASS`, zero `  FAIL  ` lines. Section 53 at tests/selftest.sh:4594-4684 carries the fixture: ARM1 (4638-4650) asserts exit 1 + exact `missing_row` FAIL + `info ghost-agent` logged + no `^(spawn|cp|exec)` in log; ARM2 (4653-4663) asserts reuse row + staging reached + `NODE CREATED: ghost-agent`; ARM3 (4668-4682) pre-fix control. All three printed PASS.
  ✓ AC4: the script usage line or README states the reuse-without-spawn contract for --agent.: scripts/node-create.sh:88-89 usage line: `--agent ID reuses an agent that must already exist on the server; it is never spawned`. Also header comment lines 9-11 and README.md:154-156: "`--agent ID` reuses an agent that must **already exist** on the server: the create path proves it with `bunker info` before any success row or staging, prints a named `FAIL agent` naming the id and the remedy otherwise, and never spawns an agent you named."
All four criteria verified: the --agent existence probe with named FAIL+remedy precedes staging, reuse and no-flag spawn paths are intact, the selftest fixture covers both arms and prints SELFTEST: PASS, and the contract is documented in the usage line and README.

## Summary

Judge Result: CF-051

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ AC1: with --agent naming no existing agent, scripts/node-create.sh fails at step 1 with a named FAIL line naming the missing agent and the remedy, and makes no staging invocation (no bunker exec/cp).: scripts/node-create.sh:107-111 — in the --agent branch, step 1 probes `"$b" info "$AGENT" --server "$SERVER"`; on failure it calls `bad "agent" "$AGENT not found on $SERVER — spawn it (drop --agent) or pass an existing agent id"` then `exit 1`. bad() (scripts/lib.sh:7) prints `  FAIL  agent — ...`, naming the id and the remedy. This runs before step 2 staging (line 114+), so no spawn/cp/exec occurs. Fixture ARM1 output: `PASS  missing --agent -> named FAIL agent, exit 1, info probed, zero staging calls`.
  ✓ AC2: with --agent naming an existing agent, reuse behaviour is unchanged and provisioning proceeds; the no-flag path still spawns and reuses its own agent.: scripts/node-create.sh:99-112 — no-flag path still spawns (`"$b" spawn "$AGENT" --server "$SERVER" --ttl "$TTL"`, SPAWNED=1, `ok "spawn" "$AGENT"`); --agent path with an existing agent prints `ok "spawn" "reusing $AGENT"` and falls through to unchanged step 2 staging / step 3 provision / step 4 verify. Fixture ARM2 output: `PASS  existing --agent -> reuse row printed, staging reached, node created (exit 0)`.
  ✓ AC3: bash tests/selftest.sh prints SELFTEST: PASS and carries a fixture with both arms (missing-agent -> named step-1 FAIL and no staging; existing-agent -> reuse PASS).: Ran `bash tests/selftest.sh` (exit 0); output line 107: `SELFTEST: PASS`, zero `  FAIL  ` lines. Section 53 at tests/selftest.sh:4594-4684 carries the fixture: ARM1 (4638-4650) asserts exit 1 + exact `missing_row` FAIL + `info ghost-agent` logged + no `^(spawn|cp|exec)` in log; ARM2 (4653-4663) asserts reuse row + staging reached + `NODE CREATED: ghost-agent`; ARM3 (4668-4682) pre-fix control. All three printed PASS.
  ✓ AC4: the script usage line or README states the reuse-without-spawn contract for --agent.: scripts/node-create.sh:88-89 usage line: `--agent ID reuses an agent that must already exist on the server; it is never spawned`. Also header comment lines 9-11 and README.md:154-156: "`--agent ID` reuses an agent that must **already exist** on the server: the create path proves it with `bunker info` before any success row or staging, prints a named `FAIL agent` naming the id and the remedy otherwise, and never spawns an agent you named."
All four criteria verified: the --agent existence probe with named FAIL+remedy precedes staging, reuse and no-flag spawn paths are intact, the selftest fixture covers both arms and prints SELFTEST: PASS, and the contract is documented in the usage line and README.

Overall: PASS ✓
