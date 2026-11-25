# CF-531 verification — bunker provisioning emits per-bunker chat gateway config

- Date: 2026-11-25T15:40Z (10:40 -05:00)
- Tick: code-factory-foreman-2026-11-25-15-22-20
- Row: CF-531 (P1, Bunker provisioning emits per-bunker chat gateway config)
- Implementation commit under verification: a3e30926d8f908eb1ed44b90d5d56be3cf03db49
  (already an ancestor of origin/main at probe time; HEAD = 131deba0)
- Mode: verification-only (the gitreins task CF-531 was created/in_progress at
  2026-11-25T14:24:04Z by an earlier tick that never completed it; no verdict existed;
  this tick completes the existing task instead of minting a duplicate)

## Acceptance clauses and measured results

| AC clause | Mechanism | Measured result |
|---|---|---|
| Gateways section emits platforms block per specs/M13-chat-gateways.md §3, tokens by token_env reference only | `python3 scripts/bunker_config_gen.py --db <fixture> --server fixture-server --projects <outdir> --gateways <g>.json` (APPLY) then the same with `--check` | APPLY rc=0: `PASS wrote …/demo.conf — 11 keys`, `PASS wrote …/demo.gateways.json — platforms: telegram` + `BUNKER-CONFIG: PASS — 1 config (2 written, 0 refused)`. CHECK rc=0: `PASS gateways — …/demo.gateways.json — platforms: telegram` + `BUNKER-CONFIG: PASS — 1 config checked, no drift`. Artifact `platforms` keys = `['telegram']`; `token_env` string present in `demo.gateways.json`; `demo.conf` carries NO token_env bytes; token-shape regex `[0-9]{8,10}:[A-Za-z0-9_-]{35}` over both emitted files: **0 matches** |
| verify-node.sh gateway leg: generated config parses as YAML, no token bytes on disk, token_env referenced | `tests/test_m13_bunker_gateways.py` arm set driving the REAL verify-node.sh fixture rig | 14/14 arms pass (`python3 -m pytest -q tests/test_m13_bunker_gateways.py` → `14 passed in 4.72s`, rc=0) |
| Signal-instead-of-telegram bunker provisions without error (R5); no-gateways bunker unchanged (R3) | Test arms GATEWAYS_SIGNAL / no-gateways invariants (real scripts, throwaway fixtures) | Included in the same 14-arm passing run |
| `bash tests/selftest.sh` exits 0; the new generator path prints the emitted platform keys on `--check` | selftest §46 arms unchanged + AC5 line | `--check` prints `.. gateways — platforms: telegram` and `PASS  gateways — …/demo.gateways.json — platforms: telegram` (AC5 satisfied, live probe above). Full selftest exercised through the pre-commit tier-1 guard at the commit landing this artifact; the guard verdict is quoted in the row closeout evidence and gitreins verdict |

## Probe reproduction

The live probe used the exact fixture pattern of tests/test_m13_bunker_gateways.py
(sqlite registry → one `demo` project with `local:` repo URL; `--gateways` JSON with one
telegram platform per §3; isolated `HOME` for the generator subcommand). Scratch was a
throwaway `tempfile.mkdtemp` and has been left as-is (outside the repo; no tracked files
touched — `git status` in the repo is all-committed except this artifact).

## Provenance

- Landed implementation: a3e30926 (subject "feat(CF-531): bunker provisioning emits per-
  bunker chat gateways per M13", authored by the fleet identity 2026-11-25T10:15:09-05:00).
- Board note discloses that the merge of the emitted gateways artifact into the bunker
  config at provision/re-sync is the follow-up consumer of this surface (provisioning
  script is outside this row's file scope per the commit message).
