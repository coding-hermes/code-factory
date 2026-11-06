# 38. specs/HARNESS-MATRIX.md

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/specs/HARNESS-MATRIX.md` |
| Repository | `code-factory` |
| Revision | `6eea792` (doc-set base); spec content last changed at `160b872` |
| Status | **FAILING — the spec's five-leg support gate is implemented as three legs, and the measured battery run is 5 PASS / 7 FAIL / 9 SKIP, exit 1** |

## 1. Purpose and why it matters

The spec owns three decisions and delegates the rest: "this file owns the **selection rule**, the
**variable contract** and the **switching model**", while `specs/HARNESS.md` owns the adapter
contract (`HARNESS-MATRIX.md:7-8`). The invariants force three things that cannot be deferred:

- **I1 makes the foreman's harness unselectable.** Every lane that grades, closes a row or writes
  the board "runs on Hermes, on the node", and "No model choice changes this"
  (`HARNESS-MATRIX.md:18-21`). The forced decision: harness choice may cheapen a worker lane, never
  the lane that decides the work is done. "A harness that cannot write the board cannot be the
  foreman" is the stated test (`HARNESS-MATRIX.md:20-21`), and the node the foreman runs on is the
  project's bunker, not the control host (`fact: FACT-01`).
- **I2 makes the matrix a default, not a constraint.** "The harness is a per-lane SETTING, not a
  property of the model"; an OpenAI model in Claude Code and a Claude model in Codex are
  "legitimate configurations, not mistakes" (`HARNESS-MATRIX.md:23-27`). The forced decision: the
  model-family table at `HARNESS-MATRIX.md:94-99` is the third of four resolution sources, ranked
  below lane and directive and above the `"hermes"` policy fallback.
- **I4 makes "installed" a non-word.** "Nothing is supported because it is installed"; support means
  "five green legs in the conformance battery (`PASS`/`SKIP`/`FAIL` with a measured value), on a real
  node, for a real turn", and "`--check` alone is not support" (`HARNESS-MATRIX.md:35-37`). The
  forced decision: no document, table or operator may quote a harness as supported from a version
  string.

What breaks if the module is absent: no rule decides which harness serves a lane, no variable set is
owed to an installer, and no switch is auditable. The spec states the concrete cost of the last one —
"An unrecorded fallback is indistinguishable from a mistake, and an unrecorded shim is worse"
(`HARNESS-MATRIX.md:105-107`).

What breaks if it lies: it already has once, and the scar is in the file. A previous revision said
"there is no deepseek harness", which "was measured against *our* two trees and then stated as a fact
about the world" (`HARNESS-MATRIX.md:58-61`). The correction is recorded rather than quietly edited
(`HARNESS-MATRIX.md:58-66`), which is the standard this document is held to.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `tests/harness-conformance.sh` | repo HEAD; 3 legs | run from the worktree root | it is the only executor of §7 (`HARNESS-MATRIX.md:169-170`) |
| `scripts/lib.sh` | sourced by the battery | `scripts/` | sourcing at `tests/harness-conformance.sh:27`; `ok`/`bad`/`say` at `scripts/lib.sh:5-9` |
| `scripts/harness/install-hermes.sh` | pin `0.19.0` (`scripts/harness/install-hermes.sh:17`) | `scripts/harness/` | python gate `scripts/harness/install-hermes.sh:55-63`; interpreter knob `scripts/harness/install-hermes.sh:19` |
| `scripts/harness/install-codex.sh` | pin `0.166.0` (`scripts/harness/install-codex.sh:49`) | `scripts/harness/` | version row quoted by the battery (`tests/harness-conformance.sh:224-227`) |
| `scripts/harness/install-claude-code.sh` | pin `2.1.318`, integrity-pinned (`scripts/harness/install-claude-code.sh:39-41`) | `scripts/harness/` | provenance refusals at `scripts/harness/install-claude-code.sh:409-434` |
| `scripts/harness/install-opencode.sh` | no pin; adapter marked UNVERIFIED (`scripts/harness/install-opencode.sh:4-5`) | `scripts/harness/` | `--apply` refuses by name (`scripts/harness/install-opencode.sh:31-35`) |
| `scripts/harness_resolve.py` | — | **absent** | §6 names it (`HARNESS-MATRIX.md:145`); `ls` returns no such file, so the resolver cannot be run |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `scripts/lib.sh` | shell, same repo | `ok` prints `  PASS  <id> — <value>`, `bad` prints `  FAIL  …` and increments `FAILED` (`scripts/lib.sh:6-7`) | the battery parses those exact prefixes (`tests/harness-conformance.sh:108-125`); a reformat makes every adapter row unquotable and the leg emits "adapter exited 0 but printed no PASS row to quote" (`tests/harness-conformance.sh:227`) |
| `emit()` guard | battery-internal | an empty `PASS`, an empty `FAIL` or an unnamed `SKIP` is rewritten to `FAIL` (`tests/harness-conformance.sh:67-83`) | a battery that can print `PASS` with no value is decoration; this guard is what makes the counts in §4 mean anything |

### 2c. Service contracts — which artifact binds each invariant

| Invariant | Bound artifact (the "other side") | What the binding actually does | Breaks if |
|---|---|---|---|
| I1 foreman is Hermes (`HARNESS-MATRIX.md:18-21`) | **none found** | `grep -c foreman tests/harness-conformance.sh` → `0`; the harness table has no lane or role column (`tests/harness-conformance.sh:89-95`) | nothing catches a non-hermes foreman; the invariant is prose only |
| I2 harness is a per-lane setting (`HARNESS-MATRIX.md:23-27`) | **UNKNOWN — resolver absent** | the resolution order is specified (`HARNESS-MATRIX.md:94-99`) and `harness_resolve.py --explain` is named (`HARNESS-MATRIX.md:145`), but no such file exists | every run must record `harness_reason` by hand; an unrecorded fallback is undetectable (`HARNESS-MATRIX.md:105-107`) |
| I3 one DuckBrain namespace and record (`HARNESS-MATRIX.md:29-33`) | `scripts/harness/install-claude-code.sh` | the adapter echoes the record fields and states "no DuckBrain write happens here (leg `memory`)" (`scripts/harness/install-claude-code.sh:120`, `scripts/harness/install-claude-code.sh:625`) | a green battery still proves nothing about I3; no leg reads a DuckBrain key back |
| I4 support is five green legs (`HARNESS-MATRIX.md:35-37`) | `tests/harness-conformance.sh` + generated `docs/HARNESS-CONFORMANCE.md` | the battery implements three legs — `leg_check` (`tests/harness-conformance.sh:202`), `leg_smoke` (`:258`), `leg_apply` (`:325`) — and regenerates the matrix with `--write-doc` (`:387-469`) | two of the five legs (`vars`, `memory`, `HARNESS-MATRIX.md:165-167`) have no executor, so they can never fail |
| I5 two kinds of "cannot" (`HARNESS-MATRIX.md:39-42`) | **none found** | `grep -rn "harness_unsupported\|harness_cannot_host"` over the repo returns no match outside the spec | the taxonomy is unimplemented; the battery reports `no adapter at scripts/harness/install-deepseek.sh`, not `harness_unsupported:` (row 33 of the run log in §8) |

The variable contract (`HARNESS-MATRIX.md:119-129`) is honoured by 2 of the 4 shipped adapters:
`scripts/harness/install-codex.sh:66-71` declares the full map and `REQUIRED=(CF_MODEL CF_PROVIDER CF_WORKDIR
CF_NAMESPACE CF_RUN_ID CF_LANE)`; `scripts/harness/install-claude-code.sh:87-101` documents the same set, refuses a
credential *value* at `scripts/harness/install-claude-code.sh:200-206` and an ambient key at
`scripts/harness/install-claude-code.sh:191-195`. `scripts/harness/install-hermes.sh` and `scripts/harness/install-opencode.sh` contain zero `CF_`
references, so the sentence "The same set goes to `scripts/harness/install-<name>.sh --apply`"
(`HARNESS-MATRIX.md:113`) is false for half the adapters that exist.

## 3. Verification

The conformance battery is the executor the spec names: "`tests/harness-conformance.sh` implements
this table; its matrix is the release gate for the word 'supported'" (`HARNESS-MATRIX.md:169-170`).
It was run in the worktree at `6eea792` on 2026-11-05T17:53:18Z, without `--install`.

| Check | Command | Expected by the spec | Measured in this run | Result |
|---|---|---|---|---|
| Conformance battery | `bash tests/harness-conformance.sh` | `check`, `install`, `vars`, `turn`, `memory` all `PASS` (`HARNESS-MATRIX.md:158-159`) | 3 legs exist; 5 PASS, 7 FAIL, 9 SKIP; exit 1 | **FAIL** |
| Leg census | `grep -c '^leg_' tests/harness-conformance.sh` | 5 legs (`HARNESS-MATRIX.md:161-167`) | `3` (`tests/harness-conformance.sh:202`, `:258`, `:325`) | **FAIL: `vars` and `memory` have no leg** |
| Install leg | `bash tests/harness-conformance.sh --install` | idempotent `--apply`, pin measured after install (`HARNESS-MATRIX.md:164`) | not run; the `apply` leg SKIPs by design without the flag (`tests/harness-conformance.sh:332-334`) | **NOT MEASURED** |
| Resolver explain | `harness_resolve.py --explain <model>` | "prints the decision and the reason it won" (`HARNESS-MATRIX.md:145-146`) | file absent — command cannot be run | **FAIL** |
| Adapter checks | `bash scripts/harness/install-<name>.sh --check` | "installed? which pin" (`HARNESS-MATRIX.md:151`) | hermes refused python 3.14.9; codex `0.166.0 (pin 0.166.0)`; claude-code `2.1.318 (pin 2.1.318)`; opencode `1.18.29` | hermes **FAIL**; three others **PASS** |

The battery's own summary, verbatim (last rows of the run log quoted in §8):

```
summary: 5 pass, 7 fail, 9 skip
HARNESS CONFORMANCE: FAIL (7)
```

The spec says three legs run today, not five, and that sentence records the mismatch rather than
resolving it: `specs/HARNESS.md:47` says the battery "runs three legs per harness" — `check`, a smoke
turn, and `--apply` — while `HARNESS-MATRIX.md:158` says "Five legs". The two spec files disagree
about the gate, and the executor follows `HARNESS.md`.

## 4. Metrics emitted

The spec defines record fields, not counters: I3's payload is `run_id, lane, harness,
harness_version, model_requested, model_served, provider_binding, commit, tick`
(`HARNESS-MATRIX.md:29-33`) and the per-run decision fields are `harness_selected, harness_reason
(directive|lane|matrix|fallback), model_requested, model_served, provider_binding`
(`HARNESS-MATRIX.md:105-107`). No dispatch rate, latency or failure counter is specified. What the
matrix does emit is counts:

| Quantity | Count | How measured |
|---|---|---|
| harness rows named by the spec | 7 | `HARNESS-MATRIX.md:48-56` |
| harness ids the battery executes | 7 | `tests/harness-conformance.sh:89-95` |
| legs the spec requires per harness | 5 | `HARNESS-MATRIX.md:158-167` |
| legs the battery implements | 3 | `grep -c '^leg_'` → `3` (`tests/harness-conformance.sh:202`, `:258`, `:325`) |
| cells the spec's gate implies | 35 | `7 × 5` |
| cells the battery can emit | 21 | `7 × 3` |
| cells measured in this run | 21 | `results.tsv` of run `20261105T175318Z-2568151` |
| PASS / FAIL / SKIP / NOTE | 5 / 7 / 9 / 2 | `awk -F'\t' '{c[$3]++} END{…}' results.tsv` |
| adapters on disk | 4 | `ls scripts/harness/install-*.sh | wc -l` |
| spec harnesses with no battery row | 1 (`omh`) | `HARNESS-MATRIX.md:51` has no counterpart in `tests/harness-conformance.sh:89-95` |
| battery ids absent from the spec's seven | 1 (`opencode-v2`) | `tests/harness-conformance.sh:93`; the spec lists only `opencode` (`HARNESS-MATRIX.md:52`) |
| DuckBrain records written by the run | 0 | the adapter states memory is not written (`scripts/harness/install-claude-code.sh:625`) |
| `harness_unsupported` / `harness_cannot_host` emitted | 0 | `grep -rn` over the repo finds neither string outside the spec |

Six of the spec's seven harnesses appear in the battery (hermes, claude-code, codex, opencode, plus
`omp`→`pi-agent` and `dsh`→`deepseek`, `HARNESS-MATRIX.md:53-56`); `omh` appears nowhere in the
battery table (`tests/harness-conformance.sh:89-95`), so it has no cell and no verdict in either direction.

## 5. Log lines it can generate

The battery's rows, verbatim from the run (timestamped log path in §8):

```
hermes
  FAIL  hermes:check — adapter exit 1 — python — hermes-agent 0.19.0 requires python >=3.11,<3.14; found 3.14.9
  ..    hermes: the adapter refused `python3` (Python 3.14.9); python3.12 is on PATH, so HERMES_PYTHON_BIN=python3.12 reaches the binary/version/port rows
  SKIP  hermes:apply — not attempted: --install was not requested (this battery installs nothing without it)
  PASS  hermes:smoke — smoke.txt contains CF-CONF-hermes-539373 (21 B, sha256 5556e4ac7d8e…, exit 0; token sha256 5556e4ac7d8e…)

claude-code
  PASS  claude-code:check — adapter exit 0 — version — 2.1.318 (pin 2.1.318)
  SKIP  claude-code:apply — not attempted: --install was not requested (this battery installs nothing without it)
  SKIP  claude-code:smoke — binary `claude` absent from PATH

codex
  PASS  codex:check — adapter exit 0 — version — 0.166.0 (pin 0.166.0)
  SKIP  codex:apply — not attempted: --install was not requested (this battery installs nothing without it)
  FAIL  codex:smoke — turn exited 124 and wrote no smoke.txt after 1 attempt(s) — ERROR: Reconnecting... waiting for network

opencode
  PASS  opencode:check — adapter exit 0 — version — 1.18.29
  ..    opencode: the adapter warned non_interactive could not be confirmed while `opencode run --help` exits 0 — its probe greps stdout and opencode writes help to stderr
  SKIP  opencode:apply — not attempted: --install was not requested (this battery installs nothing without it)
  PASS  opencode:smoke — smoke.txt contains CF-CONF-opencode-e67517 (24 B, sha256 8821ba76b069…, exit 0; token sha256 ed43897d9416…)

opencode-v2
  FAIL  opencode-v2:check — adapter passes on opencode 1.18.29 but this harness is the v2 generation — the adapter has no generation gate
  SKIP  opencode-v2:apply — not attempted: --install was not requested (this battery installs nothing without it)
  SKIP  opencode-v2:smoke — no opencode 2.x binary on PATH (measured 1.18.29 is v1); a v1 binary cannot smoke a v2 harness

deepseek
  FAIL  deepseek:check — no adapter at scripts/harness/install-deepseek.sh — the harness is named and cannot be certified
  FAIL  deepseek:apply — no adapter at scripts/harness/install-deepseek.sh — nothing can install this harness
  SKIP  deepseek:smoke — binary `deepseek` absent from PATH

pi-agent
  FAIL  pi-agent:check — no adapter at scripts/harness/install-pi-agent.sh — the harness is named and cannot be certified
  FAIL  pi-agent:apply — no adapter at scripts/harness/install-pi-agent.sh — nothing can install this harness
  SKIP  pi-agent:smoke — a provider pi auth check accepts (~/.pi/agent/auth.json names deepseek,openrouter, all report `invalid`)
```

The spec's two refusal strings are the only log lines it defines, and neither was emitted in this
run because neither has an emitter:

- `harness_unsupported: <name>; node has: <set>` (`HARNESS-MATRIX.md:39-41`)
- `harness_cannot_host: <harness> <family>` (`HARNESS-MATRIX.md:41-42`)

The `SKIP` rows are the battery's honest substitute: each names the credential, binary or capability
that was missing (`tests/harness-conformance.sh:258-290`), and the battery treats an unnamed `SKIP` as a
`FAIL` (`tests/harness-conformance.sh:73-75`).

## 6. Failure modes

| Failure | Presents as | Caught by | Recovery |
|---|---|---|---|
| A foreman lane resolves to a non-hermes harness (violates I1) | a lane that grades work but cannot write the board; no refusal string exists | **nothing**: `grep -c foreman tests/harness-conformance.sh` → `0`, and the harness table has no lane column (`tests/harness-conformance.sh:89-95`) | refuse at resolution time — requires the absent resolver (`HARNESS-MATRIX.md:101-103`) |
| Harness chosen as a property of the model rather than the lane (violates I2) | a run whose `harness_reason` no one can audit | **nothing executable**; `harness_resolve.py` does not exist (`HARNESS-MATRIX.md:145`) | implement `--explain`, then record `harness_reason` on every run (`HARNESS-MATRIX.md:105-107`) |
| "Supported" claimed from `--check` alone (violates I4) | a green `check` row next to a harness that cannot complete a turn | partly — the smoke leg catches a harness that produces no artifact: `codex:smoke — turn exited 124 and wrote no smoke.txt` (row 19 of the run log in §8) | read the whole row, not the `check` cell (`HARNESS-MATRIX.md:35-37`) |
| A run never writes the I3 record | a green battery with zero DuckBrain provenance | **nothing**: the adapter says "no DuckBrain write happens here (leg `memory`)" (`scripts/harness/install-claude-code.sh:120`) and the `memory` leg has no implementation (`tests/harness-conformance.sh:202-384`) | implement the `memory` leg; until then I3 is unverified by construction |
| Unknown/uninstallable harness named | `FAIL … no adapter at scripts/harness/install-deepseek.sh — the harness is named and cannot be certified` (row 33 of the run log in §8) | the battery, but with its own message, not the spec's taxonomy | install an adapter; the spec's `harness_unsupported:` string (`HARNESS-MATRIX.md:40`) is unimplemented |
| Harness installed where the smoke leg cannot see it | `claude-code:check PASS` quoting `2.1.318 (pin 2.1.318)` beside `claude-code:smoke SKIP — binary claude absent from PATH` (rows 12-14 of the run log in §8) | the two rows together; they are two different lookups — the adapter checks its own prefix binary (`scripts/harness/install-claude-code.sh:347-359`), the battery looks on `PATH` (`tests/harness-conformance.sh:261-265`) | put the adapter prefix on `PATH`, or teach the battery the adapter's binary path |
| A harness hangs instead of failing | `FAIL … exit 124` after one attempt; the battery retries a soft failure but refuses to retry a hang (`tests/harness-conformance.sh:297-306`) | the battery | fix the harness's network path; a second 300 s window proves nothing |
| The gate the doc cites is the wrong arm | `docs/HARNESS-CONFORMANCE.md:90` claims "`tests/selftest.sh` §44", but the arm is numbered 45 (`tests/selftest.sh:2587`) | a reader who follows the pointer | fix the pointer when the battery is next regenerated |

## 7. Environment and settings it reads

| Variable / knob | Default or pin | Enforced at | Effect if unset |
|---|---|---|---|
| `HERMES_PIN` | `0.19.0` | `scripts/harness/install-hermes.sh:17` | pin defaults to 0.19.0 |
| `HERMES_PYTHON_BIN` | `python3` | `scripts/harness/install-hermes.sh:19`; range `>=3.11,<3.14` at `scripts/harness/install-hermes.sh:55-63` | the run fails the `python` row on this host: "found 3.14.9" (row 6 of the run log in §8); the battery notes `python3.12` is on PATH (row 7) |
| `CF_CODEX_PIN` | `0.166.0` | `scripts/harness/install-codex.sh:49` | pin defaults to 0.166.0 |
| `CLAUDE_CODE_PIN` | `2.1.318` with registry integrity | `scripts/harness/install-claude-code.sh:39-41` | a pin mismatch is refused, not warned (`scripts/harness/install-claude-code.sh:422-434`) |
| `CF_MODEL`, `CF_PROVIDER`, `CF_WORKDIR`, `CF_NAMESPACE`, `CF_RUN_ID`, `CF_LANE` | none — required | `scripts/harness/install-codex.sh:71`; `scripts/harness/install-claude-code.sh:87-101` | the adapter refuses the contract; hermes and opencode do not read these at all (zero `CF_` references) |
| `CF_API_KEY_FILE` | no default; a **path** to a mode-600 file | `scripts/harness/install-claude-code.sh:199-215`; rule at `HARNESS-MATRIX.md:122` | `--turn` is skipped with a named note (`scripts/harness/install-claude-code.sh:219`); a value instead of a path is refused (`fact: FACT-05`) |
| `CF_HARNESS_OPTS` | optional, recorded | `scripts/harness/install-claude-code.sh:278-284` | no options; an options bag that looks like a credential is refused |
| `CF_MAX_TURNS` / `CF_TIMEOUT_S` | `40` / `1800` | `scripts/harness/install-claude-code.sh:289-292` | the spec's defaults apply (`HARNESS-MATRIX.md:129`) |
| `HC_TIMEOUT` / `HC_APPLY_TIMEOUT` | `300` / `600` | `tests/harness-conformance.sh:34-35` | the smoke turn is cut at 300 s (codex hit it, row 19 of the run log in §8) |
| `HC_WORK_ROOT` | `$HOME/.harness-conformance` | `tests/harness-conformance.sh:54` | artifacts land under the home directory, never a system temp dir |
| `HC_KEEP_APPLY` | `0` | `tests/harness-conformance.sh:382` | the scratch install HOME is removed after the apply leg |

The switching model's settings do not exist yet: the spec puts `harness.default`,
`harness.by_family{…}` and `harness.shims{…}` in a node file "the same shape as
`config/node.env.example`" (`HARNESS-MATRIX.md:141-142`), but `grep -n harness config/node.env.example`
matches only comments (`config/node.env.example:5`, `config/node.env.example:31`), and `lane.harness`
(`HARNESS-MATRIX.md:143`) appears in no config reader — only the spec and an unrelated prose mention
(`docs/LOOP-CODEX.md:87`). This project's own lanes are xkiro and DeepSeek PAYG (`fact: FACT-06`), so
the 13-provider setup the spec describes for `omh` (`HARNESS-MATRIX.md:51`) is not a lane this repo
runs today.

## 8. Evidence of record

- Run: `bash tests/harness-conformance.sh`, cwd `/home/kara/proj-wt-md-38f` at `6eea792`,
  2026-11-05T17:53:18Z, work root
  `/home/kara/.harness-conformance/run-20261105T175318Z-2568151`. Full stdout log:
  `/home/kara/.hermes/cache/scratch/md38/battery.log` (45 lines; row numbers in this document are
  its line numbers). Summary: `5 pass, 7 fail, 9 skip`; `HARNESS CONFORMANCE: FAIL (7)`; exit `1`.
- Counts recomputed from `results.tsv`: `PASS=5 FAIL=7 SKIP=9 NOTE=2 total=21`.
- Leg census: `grep -c '^leg_' tests/harness-conformance.sh` → `3`; the spec requires five
  (`HARNESS-MATRIX.md:158-167`).
- Adapters on disk: `ls scripts/harness/install-*.sh | wc -l` → `4` for seven named harnesses
  (`HARNESS-MATRIX.md:48-56`).
- `harness_resolve.py` does not exist (`ls` → no such file), so the §6 management surface
  (`HARNESS-MATRIX.md:145-152`) is unbuildable today, and `grep -rn
  "harness_unsupported\|harness_cannot_host"` returns no emitter for the I5 taxonomy
  (`HARNESS-MATRIX.md:39-42`).
- The committed baseline matrix was generated earlier, on another host state and at commit
  `10a796f` (`docs/HARNESS-CONFORMANCE.md:3`); it lists the same harness ids but different
  binaries (for example `hermes:check FAIL` on python 3.14.9, `codex:smoke FAIL` on exit 124), so it
  cannot be quoted as today's measurement. This document's measurement is the run above.
- Facts cited: `fact: FACT-01` (foreman on the project's bunker node), `fact: FACT-05` (credentials
  are paths at mode 600), `fact: FACT-06` (this project's lanes), `fact: FACT-08` (support means the
  battery's legs pass on a real node).
- Gap, stated plainly: the spec claims **7 harnesses × 5 legs = 35 gate cells**; the executor can
  emit **21**, and this run measured **5 PASS / 7 FAIL / 9 SKIP** with the install leg entirely
  unrequested. No harness satisfies I4 as written — not because all of them fail, but because the
  `vars` and `memory` legs that I4 counts do not exist. Moving this module to VERIFIED requires, in
  order: implement the `vars` and `memory` legs, implement `harness_resolve.py`, then run
  `tests/harness-conformance.sh --install` on a real node and record five green rows per harness.
