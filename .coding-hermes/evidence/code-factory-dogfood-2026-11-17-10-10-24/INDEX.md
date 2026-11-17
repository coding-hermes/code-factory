# Evidence — dogfood tick `code-factory-dogfood-2026-11-17-10-10-24`

Tip measured: `0014b76ac0b5a33081068d743e52754b928b4e0c`. Report:
`docs/dogfood/2026-11-17-dogfood-path.md`. Log: `.coding-hermes/dogfood-log.md`.

Every arm was run from this checkout with stdout and stderr captured SEPARATELY, and the exit
status read from the `bash <script>` invocation itself (never after a pipe). `WALL=` lines come from
`/usr/bin/time -f 'WALL=%es'` written to the arm's own `.err` file.

| File | Arm |
|---|---|
| `probeA.sh`, `step1-noenv.*` | README step 1 with no env — `FAIL server_declared`, rc 1 |
| `step1-env.*` | README step 1 with the shipped placeholder `BUNKER_SERVER` — rc 1, 2 FAILs |
| `step1-real.*` | README step 1 against `<bunker-server>` — rc 0, `RESULT: PASS` + the residue WARN (CF-483) |
| `step2.*` | README step 2 default arm — rc 1, `NODE: FAIL (5)`, 38.16 s (CF-387 owns the cost) |
| `probeB.sh`, `b1.*` | documented interpreter remedy — rc 1, `NODE: FAIL (7)` (CF-484) |
| `b2.*` | `node-create.sh --help` with no env — rc 0, no spawn |
| `b3.*` | `--staged-files --harness hermes` — rc 0, staging manifest |
| `b4.*` | `--staged-files --harness hemes` — rc 1, names the adapter set (CF-125) |
| `b5.*` | README step 3 with a placeholder server — rc 1, spawn attempted then named (CF-469) |
| `b6.*` | `node-create.sh` with no arguments — rc 2, usage |
| `probeC.sh`, `c1.*` | `bunker-crier-connect.sh --check` with no flags — rc 2, `--server is required` |
| `c2.*` | `verify-node.sh` no args — rc 2, usage |
| `c3.*` | `verify-node.sh --agent … --artifact /nonexistent` — rc 2, `set BUNKER_SERVER` |
| `c4.*` | `land-node-branch.sh` on an absent workdir — rc 1, `LAND: REFUSED` |
| `c5.*` | `project-node.sh --check --layers 20` — rc 1, `SCOPE: layers 20 (fixture mode)` |
| `file-rows.sh`, `r1-*.txt`, `r2-*.txt`, `cf057-note.txt` | the exact board payloads this tick filed (CF-483, CF-484, CF-057 note) |

One arm is **not** here because it was refused by the unattended command gate and not retried in
another form: `node-create.sh` with neither `CRIER_URL` nor `BUNKER_SERVER`, reading its exit
status. The earlier `CRIER_URL`-unset arm printed `FAIL  crier_url — CRIER_URL unset or empty` on
stdout; its exit status is not claimed anywhere in the report.

## Publication substitutions (disclosed, not silent)

Before this directory entered the published tree, host-identifying literals were elided with `sed`
(§61 publish-path gate: baseline 0 absolute host-home paths; AGENTS.md: no personal data):

| Literal | Replaced with | Files affected |
|---|---|---|
| the absolute host-home prefix | `~` | every file that carried it (`step1-real.out`, `step1-env.out`, `step2.out`, `b1.out`, `c5.out`, `probe{A,B,C}.sh`, `file-rows.sh`, `r2-reason.txt`) |
| the control host's hostname | `<control-host>` | `step2.out`, `b1.out`, `c5.out` |
| the bunker server's address and port | `<bunker-host>:<port>` | `step1-real.out`, `step1-env.out` |
| the bunker server's name | `<bunker-server>` | every file that carried it (`step1-real.*`, `probeA.sh`, `INDEX.md`, the report) |

Nothing else was changed: every PASS/FAIL/WARN row, every `WALL=` line and every exit status in
these files is what the arm printed. The probe scripts still run as staged (`~` expands to the
operator's home); `probeA.sh`/`probeB.sh`/`probeC.sh` reference the tick's scratch root, which is
pruned on a timer, so re-running them needs that root recreated.

The `r*.txt` payload copies are the text actually passed to `boardctl create`, with the same
host-home elision applied — the board rows `CF-483`/`CF-484` therefore carry the operator's absolute
home path inside their quoted FAIL row (`binary — host-provided <home>/.local/bin/hermes`) where
these copies carry `~/…`. The board path is exempt from the publish gate; this directory is not.

---

# Delivery 3 — the node-create leg (README step 3), added at `db42390d`

Report: `docs/dogfood/2026-11-17-node-create-leg.md`. Rows: `CF-489` (P1), `CF-490` (P2).

Deliveries 1 and 2 left step 3 unverified. These arms are that leg, run against real hosts with a
real public fixture (`https://github.com/github/gitignore`) and a live crier. stdout and stderr were
captured separately per arm; the exit status is the `/usr/bin/time … CREATE_WALL=/CREATE_RC=` line in
the arm's own `.err`, and the wall clock is also written into the `.out` as
`CREATE_WALL_CLOCK_S`/`STARTED_UTC`/`ENDED_UTC` so the transcript is self-dating.

| File | Arm |
|---|---|
| `step3-manifest.*` | `node-create.sh --staged-files` — rc 0, 14-file manifest, 0.42 s (the host-free arm) |
| `step3-nodecreate-las03.sh`, `step3-create.*` | the documented command against an ONLINE host — rc 1, `FAIL spawn — … slice-limits … memory.swap.max = "max", want "0"`, 27.19 s (`CF-489`) |
| `step3-nodecreate-las02.sh`, `step3-create-las02.*` | the IDENTICAL command with only `BUNKER_SERVER` changed, against a second ONLINE host — rc 1, same assertion at a different read budget (5 vs 40), 20.59 s (`CF-489`) |
| `step3-file-rows.py`, `r3-*.txt`, `r4-*.txt` | the exact board payloads this delivery filed (`CF-489`, `CF-490`) — the driver passes every field as an argv list, no shell interpolation |

## Substitutions (disclosed, not silent)

| Literal | Replaced with | Files affected |
|---|---|---|
| the absolute host-home prefix | `~` | `step3-nodecreate-las03.sh`, `step3-nodecreate-las02.sh`, `step3-file-rows.py`, the `r3-*`/`r4-*` payload copies |

Nothing else was changed. The node host names (`bunker-las-02`, `bunker-las-03`) are left as printed
because the tracked tree already carries them (`.coding-hermes/dogfood-log.md`, `docs/audits/`, the
handbook appendices) and no address or port appears in these transcripts. The one host-filesystem
literal that remains is the bunkerd spawn-log path (`/mnt/ssd/tmp/cf-spawn-…`), quoted verbatim
because it is the only handle the failure message gives a user; it is a scratch path, not a home
path and not a network address.

Two further disclosures about `step3-file-rows.py`: the committable copy is re-emitted in `ruff
format` style (the repo's lint lane grades staged `*.py`; `ruff format --check` on this copy reports
"already formatted"), and its `BOARD`/`BOARDCTL`/`SCRATCH` roots carry the same `~` elision. It is the
same argv-list logic that filed `CF-489`/`CF-490`, not a second implementation.



