# code-factory docs lane — the public-bind auth gate is parsed, not text presence (CF-197)

- Lane: `code-factory-docs`, tick `code-factory-docs-2026-11-04-10-01-07`
- Reviewed tip: `4295860e661f15ccf14fff81ff57e018a2b6bbf4` (`gh/main`, 2026-11-04T05:01:18-05:00); the
  work was rebased twice before publication, onto `bf3cdc03162b4cdd6519f9ef8e7e383cb829581a` and then
  `24916c54f3d9ed84af10aad7221e95fcc7b0f75b`, because a sibling landed board rows mid-tick. Every arm
  reading below is unchanged by those rebases — none of the amended files is touched by either tip.
- Transport: throwaway `git clone` of `4295860` under tick scratch. The registered checkout
  `/home/kara/code-factory` was **not touched**: a live sibling `hermes` process (pid 2971297,
  started 04:54:53 local) held uncommitted work there (`M docs/PRD-code-factory.md`,
  `M tests/selftest.sh`, staged `.coding-hermes/board/tasks.jsonl`, `M events.jsonl`), which is an
  ownership barrier, not a stale checkout.
- Row: **CF-197** (filed and closed by this tick). The id churned three times on this board: minted
  as `CF-193` at `4295860`, renumbered to `CF-195` when the QA lane took `CF-193`/`CF-194` at
  `7510b79`, and renumbered again when the same lane took `CF-195` at `24916c5` and the sync lane
  took `CF-196` at `e9cd7d8` ("duplicate event id when two lanes mint from one tip"). Landed rows keep
  their ids, so this row is `CF-197`, past the tip's max (196), carried through the `task_created`
  event id and `task_id`, this file's `ch:trace` line, the GitReins task id (`CF-197-DOC3`) and the
  commit subjects. The siblings' rows are *code* and *board* defects — `CF-193` (ordinary YAML
  constructs refuse as `block absent`), `CF-194` (`$HOME/.hermes/config.yaml` by path vs the
  gateway's `HERMES_HOME`), `CF-195` (nothing re-measures the docs' line-number pins) and `CF-196`
  (duplicate event ids) — and this row is the *documentation* claim that no longer matched the gate.
  The corrected prose names the first two; the pins this row writes were verified at the correction
  commit rather than assumed, which is the mitigation `CF-195` asks for at row scope.

## Claim class selected

Four sentences in three documents stated that `scripts/harness/install-hermes.sh` authorizes a public
bind from the **presence of `basic_auth` text**. At `3e6ac40^:127` that was literally true:

```
$ git show 3e6ac40^:scripts/harness/install-hermes.sh | grep -n "grep -q 'basic_auth'"
127:    if grep -q 'basic_auth' "$HOME/.hermes/config.yaml" 2>/dev/null; then
```

`3e6ac40` (2026-11-04 04:12, "fix: parse Hermes public-bind auth — reject comments and empty
credentials") and `779ab4f` (04:28, "validate Hermes auth with stdlib only") replaced that grep with a
parser. Every statement below was true before those commits and false at `4295860`. This is the
largest claim the week's commits falsified: it is the threat model's stated residual risk on the
gateway-auth row, and it now understates a shipped control rather than overstating one.

## Before / after

| # | File:line | Was (false at `4295860`) | Now |
|---|---|---|---|
| 1 | `docs/OPERATIONS.md:80` | "It refuses to start a public bind unless `$HOME/.hermes/config.yaml` contains `basic_auth`." | "…parses to a `dashboard.basic_auth` mapping whose `username` and `password` are both non-empty strings (`scripts/harness/install-hermes.sh:66–186`, `check_public_bind_auth`): an unreadable file, unparseable YAML, a commented-out key, a `basic_auth` mention anywhere else in the file and an empty value each refuse with their own reason in the `gateway_start` row (`:258`). The gate runs only on the branch where the adapter starts the gateway itself — when something already listens on `:PORT` that branch is skipped entirely (CF-192). The reader is deliberately narrow and reads that one path: a config whose `dashboard.basic_auth` block is valid but which also carries ordinary YAML the reader does not model (a list item, a flow collection, a block scalar) refuses as `block absent (invalid YAML)` (CF-193), and the block it authorizes is `$HOME/.hermes/config.yaml` by path — a file the launched server may not load (CF-194)." |
| 2 | `docs/OPERATIONS.md:82` | "The current implementation uses a substring check for `basic_auth`; it does not independently validate the strength or correctness of the configured secret." | "The current implementation parses the file and requires non-empty `username`/`password` strings (`scripts/harness/install-hermes.sh:66–186`); it does not test the strength or correctness of that secret, and whether the running gateway serves with the same effective auth configuration is **not measured**." |
| 3 | `docs/THREAT-MODEL.md:46` | "…refuses gateway start without `basic_auth` … A substring `grep basic_auth` is not validation of effective configuration" (evidence cell cited lines 43–48, 61–69) | "…refuses gateway start unless the parsed config carries a non-empty `dashboard.basic_auth` username and password"; evidence cell cites `install-hermes.sh:66–186` and `:258`, records the four fixture arms, and keeps "not measured" for secret strength / effective runtime auth / firewall scope, plus the CF-192 port guard. |
| 4 | `docs/THREAT-MODEL.md:65` | "Hermes installer refuses start unless `basic_auth` text occurs in config (`scripts/harness/install-hermes.sh`, lines 61–69)"; residual "Text presence remains weak config validation"; recommendation "require parsed effective auth config" | "…refuses start unless the config parses to a non-empty `dashboard.basic_auth` username and password (`install-hermes.sh:66–186`, refusal at `:258`)"; residual says a parsed non-empty credential is stronger than text presence but proves nothing about strength or effective runtime config — both **not measured**; recommendation narrowed to runtime auth, firewall and bind scope. |
| 5 | `docs/THREAT-MODEL.md:81` | "the installer substring check is still insufficient" | "the installer's parsed-credential check (`scripts/harness/install-hermes.sh:66–186`) still does not prove a strong or effective secret." |
| 6 | `docs/THREAT-MODEL.md:93` | "a config substring and a self-reported auth marker do not prove effective authentication" | "a parsed config block and a self-reported auth marker do not prove effective authentication." |
| 7 | `specs/NODE.md:28` | "`gateway_start` is a refusal on any node whose `~/.hermes/config.yaml` carries no `dashboard.basic_auth`" | "…does not parse to a non-empty `dashboard.basic_auth` username and password (`scripts/harness/install-hermes.sh:66–186`)" |
| 8 | `specs/NODE.md:38` | "the adapter starts `hermes serve` only when `~/.hermes/config.yaml` already carries `dashboard.basic_auth` (`scripts/harness/install-hermes.sh:93-102`)" | "…only when `~/.hermes/config.yaml` already parses to a non-empty `dashboard.basic_auth` username and password (`scripts/harness/install-hermes.sh:66–186`, gate at `:251–258`)" — the old `93-102` range no longer contains the gate. |

The whole section was walked, not just the cell the defect named, which is where rows 5–8 came from:
the same table kept describing the superseded control in three more places (the reference's
"narrowing stops one row short" rule).

## Code path that proves the new statement

`scripts/harness/install-hermes.sh` at `4295860`:

```
$ grep -n 'check_public_bind_auth\|refuse(' scripts/harness/install-hermes.sh
66:check_public_bind_auth() {
162:    refuse("block absent (config unreadable)")
175:    refuse("block absent (invalid YAML)")
180:    refuse("commented" if commented else "block absent")
186:    refuse("empty value (username and password must both be non-empty)")
252:    if auth_reason=$(check_public_bind_auth); then
258:      bad "gateway_start" "refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml — ${auth_reason:-block absent (config check failed)}"
```

- `:66–186` runs an in-file, indentation-aware YAML reader over `~/.hermes/config.yaml` with the same
  interpreter it launched with (`$PYTHON_BIN`, or `$VENV/bin/python` when present) and no third-party
  parser; `779ab4f` exists precisely so a node without PyYAML still launches.
- `:177–180` distinguishes "the key is only mentioned in a comment" from "no key at all".
- `:181–186` requires `dashboard.basic_auth` to be a mapping whose `username` and `password` are
  non-empty strings.
- `:251–258` is the only caller, and it is inside the branch that also starts `hermes serve`, so an
  occupied port skips the check entirely — the CF-192 defect, which stays open and unfixed here.

## Literal arm output

Fixture `HOME`s, each with a stub `$HOME/hermes-venv/bin/hermes` (`--version` prints
`hermes-agent 0.19.0`, `serve` exits 0) so the adapter reports `already installed` and performs no
install; `HERMES_PYTHON_BIN=python3.12`. Published adapter (`4295860`):

```
new_absent                 rc=1   FAIL  gateway_start — refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml — block absent (config unreadable)
new_commented              rc=1   FAIL  gateway_start — refused: … — commented
new_empty                  rc=1   FAIL  gateway_start — refused: … — empty value (username and password must both be non-empty)
new_textonly               rc=1   FAIL  gateway_start — refused: … — block absent
new_valid                  rc=1   FAIL  gateway_start — -> 000000 (see ~/.node-serve-19781.log)
```

(`000000` is the shipped `curl … || echo 000` doubling a `000`; the point of the arm is that the
valid config produced **no refusal row** and reached the start path. It is quoted as printed.)

Fifth arm — the narrow-reader limit, reproduced independently of the sibling's `CF-193` (a valid
`dashboard.basic_auth` block plus a `tools:` list in the same file):

```
FAIL  gateway_start — refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml — block absent (invalid YAML)
```

Pre-fix adapter (`3e6ac40^`, staged beside the same `scripts/lib.sh`), same four fixtures:

```
old_commented              rc=1   FAIL  gateway_start — -> 000000 (see ~/.node-serve-19759.log)
old_empty                  rc=1   FAIL  gateway_start — -> 000000 (see ~/.node-serve-19840.log)
old_textonly               rc=1   FAIL  gateway_start — -> 000000 (see ~/.node-serve-19571.log)
old_valid                  rc=1   FAIL  gateway_start — -> 000000 (see ~/.node-serve-19834.log)
```

Comment-only, empty-credential and stray-text configs all took the start path pre-fix — the behaviour
the corrected prose used to describe. The row's `probe` field reproduces the two refusals with one
paste-runnable line.

## Claims I could not verify

- Whether a running `hermes` gateway actually enforces `basic_auth` — **not measured**. No gateway was
  started (the stub `serve` is not a server) and `/api/status` returned `000`.
- The strength or correctness of any configured secret — **not measured**; the parser checks
  non-emptiness only (`:185-186`).
- Whether `install-hermes.sh` and the gateway read the same effective config (env overlay, includes) —
  **not measured**.
- Whether the parsed path also holds on a real `hermes-agent` 0.19.0 install — the arms stub the
  binary; **not measured**.
- CF-192's occupied-port bypass was observed in the source (`:251`) but not exercised by a fixture in
  this tick; it remains with its own row.

## Gates

```
$ bash tests/selftest.sh   -> SELFTEST: PASS
$ bash scripts/boardctl validate -> RESULT: OK (3 warning(s))   # CF-034's two free-form fields + headerless board, pre-existing
```

ch:trace row=CF-197 spec=specs/NODE.md#layers test=tests/selftest.sh evidence=docs/audits/code-factory-docs-2026-11-04-cf071-auth-prose.md verdict=CF-197-DOC1 commit=pending

STATUS: done
TIER: T3
EVIDENCE: docs/audits/code-factory-docs-2026-11-04-cf071-auth-prose.md; row CF-197; verdict CF-197-DOC1
