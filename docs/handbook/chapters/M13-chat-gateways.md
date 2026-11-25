# M13 — CHAT GATEWAYS

Status: **SPEC-DERIVED / TARGET-UNIMPLEMENTED.** The design authority is
`specs/M13-chat-gateways.md` (owner directive, verbatim, 2026-11-22: "Update specs and
boardctl so that each bunker Hermes can also be in telegram correctly so it's not just a
scheduler routing but telegram and other chat gateway options"). This chapter renders that
spec into the book's module-chapter shape. **Nothing on this page is measured runtime
behavior**: the provisioning surface does not exist yet (`scripts/bunker_config_gen.py`
carries no `gateways`, `token_env` or `platforms` content — grep, 0 matches, 2026-11-24),
and boardctl has no `--deliver` support. Every check in §7 is NOT-RUN against the target
except the one this render itself ran (the handbook lint). A later implementation row
re-grades this chapter with evidence.

## 1. Identity

| Field | Value |
|---|---|
| Module name | CHAT GATEWAYS (bunker Hermes `platforms.*` / `gateways.*` surface) |
| Path | target: each bunker's `~/.hermes/config.yaml`, generated/merged by the provisioner; no runtime process of its own — the gateway legs are the Hermes gateway's own |
| Revision | none to stamp — the module is a configuration surface of the Hermes runtime; its authority is the spec, `specs/M13-chat-gateways.md` |
| Language / runtime | Hermes gateway configuration; schema is platform-agnostic (R5), Telegram first |
| Owner lane | code-factory (per-bunker surface; consumed by provisioning M1, verification M1 §11, and the scheduler's deliver law M9) |
| Status | **SPEC-DERIVED / TARGET-UNIMPLEMENTED** — spec-only capability; implementation wiring (§4) is absent on the current tree; no fabricated measurements anywhere on this page |

## 2. Purpose, authority and position

Today a bunker Hermes has no chat presence: it receives work through Crier (M10) and the
scheduler, and its reports surface only through the control host's scheduler routing. The
capability gives every bunker Hermes its own chat-gateway connections so a bunker can
(a) hold a chat identity of its own, (b) deliver tick reports directly into configured
chat threads, and (c) remain fully operable when chat is absent. It sits **inside the
Bunker execution boundary** alongside the foreman and the node, and it deliberately does
not move any authority: the Crier launch/return boundary (M10) is unchanged, the
scheduler's admission and settlement (M9) are unchanged, and node inference (M12) is
untouched.

**What breaks if this module is absent.** Nothing structural — this is the point of R3:
a bunker with no gateways configured is a fully valid lane, and every lane in the fleet
runs that way today. Absence costs chat reachability only.

**What breaks if it lies.** A config that inlines a token instead of referencing it puts
credential bytes on disk inside the Bunker, where any code the node executes could read
them (R2's grep is the standing proof this did not happen). A delivery path that gates
task acceptance on chat success turns a platform outage into stalled ticks — the exact
coupling R3 forbids. And a chapter or register row claiming the wiring exists when the
provisioner emits no gateway content would send an operator looking for a `--deliver`
flag that boardctl does not have; this chapter therefore carries the absence, not a
promise.

**Required behavior (normative).** The spec's law, R1–R6, rendered with each law's own
check:

- **R1 — Per-bunker gateway identity.** Each bunker Hermes MAY run its own gateway
  connections (`platforms.*` in its `~/.hermes/config.yaml`, mirroring the control host's
  verified surface: `platforms.telegram.{enabled, home_channel{platform, chat_id, name,
  thread_id, user_id}}`). Each bunker uses its OWN bot token — never the control host's
  token. Check: two bunkers configured with distinct tokens answer to distinct bot
  identities.
- **R2 — Token custody is by reference.** Tokens are referenced, never inlined: the
  generated config names an env var or secret file (`token_env: TELEGRAM_BOT_TOKEN`), and
  generated files on disk contain zero token bytes. Check:
  `grep -rEo '[0-9]{8,10}:[A-Za-z0-9_-]{35}'` over a provisioned bunker home returns
  nothing while the gateway is live.
- **R3 — Scheduler routing and chat delivery are independent.** A bunker with no
  gateways configured remains a fully valid lane (scheduler-only). Chat delivery never
  gates task acceptance; the Crier boundary (M10) is unchanged. Check: a bunker lane with
  empty `platforms` completes ticks and delivers to the scheduler exactly as today.
- **R4 — Report law is identical on bunkers.** When a bunker lane carries a delivery
  target (`deliver: telegram:<chat_id>:<thread_id>` in the scheduler project row), every
  tick attempt delivers its report link to that thread — success or failure — exactly as
  control-host lanes do (M9 deliver law).
- **R5 — Gateway-platform agnostic.** The config schema and provisioning code must
  accept any platform key the control-host Hermes accepts (`telegram`, `signal`,
  `discord`, …) without bunker-side special-casing. Telegram is the first proven
  platform, not a schema constant. Check: a config with
  `platforms.signal.enabled: true` provisions without error even before any signal
  gateway is exercised.
- **R6 — Fail fast on dead credentials.** An invalid or revoked token must fail the
  gateway within seconds with a named error in the bunker's own log — never a silent
  hang that stalls ticks. Check: revoked-token probe logs an auth error and the lane's
  tick latency is unchanged.

## 3. Config surface

Generated/merged into each bunker's `~/.hermes/config.yaml` — the same keys the control
host uses, verified against the local Hermes config surface on 2026-11-22 (spec §3).
The exact block the provisioner is to emit:

```yaml
platforms:
  telegram:
    enabled: true
    token_env: TELEGRAM_BOT_TOKEN        # R2: reference, not a token
    home_channel:
      platform: telegram
      chat_id: "<chat_id>"
      thread_id: "<thread_id>"
      name: "<chat name>"
    allowed_chats: ["<chat_id>"]
gateways:
  loop_watchdog: {}                      # inherit Hermes defaults; bunkers may override
```

| Key | Meaning | Law it carries |
|---|---|---|
| `platforms.telegram.enabled` | the bunker's own gateway identity, on/off | R1 — per-bunker identity; never the control host's token |
| `platforms.telegram.token_env` | NAME of the env var / secret file holding the bot token | R2 — custody by reference; zero token bytes in generated files |
| `platforms.telegram.home_channel.{platform, chat_id, thread_id, name}` | where the bunker's chat presence lives | R1 — mirrors the control host's verified surface shape |
| `platforms.telegram.allowed_chats` | chat ids the bunker accepts commands from | Hermes `allowed_chats` enforcement — control-host behavior, no bunker-specific path |
| `gateways.loop_watchdog` | gateway loop watchdog overrides | R5 — inherit Hermes defaults; any platform key provisions without special-casing |

Scheduler project row (control host, already supported): `deliver =
"telegram:<chat>:<thread>"`, `deliver_mode = "link"` (owner ruling 2026-11-16: link
mode, into this thread). The full settings rows, with the SPEC-DERIVED marking, live in
Part V's M13 section.

## 4. Wiring

| Leg | Target behavior | Current state (measured, 2026-11-24) |
|---|---|---|
| Provisioning | `scripts/bunker_config_gen.py` gains a `gateways` input section; it emits the §3 block with `token_env` references and merges it into the bunker config at provision and re-sync | **ABSENT** — the script contains no `gateways`, `token_env` or `platforms` content (grep, 0 matches) |
| Verification | `scripts/verify-node.sh` gains a gateway leg: config parses; no token bytes on disk; `token_env` var resolves on the bunker | **ABSENT** — no gateway leg exists |
| boardctl | rows carry optional delivery metadata: `boardctl create --deliver telegram:<chat>:<thread>` (`--deliver-mode link|full`), stored as row keys `deliver` / `deliver_mode`, read back by `boardctl show` — a routing hint, not a delivery engine; the board stays platform-agnostic | **ABSENT** — boardctl has no `--deliver` support |
| Scheduler | no schema change: `deliver` / `deliver_mode` already exist; the bunker lane profile documentation (M9/M13) records the deliver law for bunker lanes | present on the control host; nothing to build |
| Secrets | bunker tokens live in each bunker's own env/secret store; provisioning copies only the REFERENCE; the control host never holds bunker bot tokens | law, not code — no reference-copy path exists yet |

## 5. Error catalog

| Condition | Behavior |
|---|---|
| token missing on bunker | gateway disabled at startup, lane runs scheduler-only, provisioning reports `GATEWAY_TOKEN_REF_UNRESOLVED` (warning, not fatal) |
| token invalid/revoked | gateway auth error within seconds (R6), tick pipeline unaffected |
| chat delivery fails (network/platform) | report delivery retries per Hermes gateway defaults; tick completion is NOT blocked (R3) |
| disallowed chat attempts command | Hermes `allowed_chats` enforcement (control-host behavior), no bunker-specific path |

Out of scope (spec §6, explicit): bunker-to-bunker chat, group-chat moderation, media
ingestion on bunkers; any change to Crier transport or task-acceptance semantics (M10
stays authoritative); making chat delivery a dependency of any gate or judge.

## 6. Contracts in and out

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| CT-31 | bunker Hermes config | in (config envelope) | **TARGET** — the provisioner's gateway emitter (`scripts/bunker_config_gen.py`, §4 leg absent) | **TARGET** — the bunker Hermes config loader (out-of-repo runtime) | **SPEC-DERIVED** — registered in Part IV as the gateway config envelope; no in-repo producer or consumer exists to cite |

CT-31 carries the §3 envelope: `platforms.<platform>.{enabled, token_env,
home_channel{...}, allowed_chats}` plus `gateways.loop_watchdog`, and pairs with the
scheduler row keys `deliver` / `deliver_mode` as the routing hint. It is registered in
Part IV's registry and its five register surfaces; it is **not yet registered in
`docs/SYSTEM-MODEL.yaml`**, so the system map and the auto-generated captions continue
to derive their contract count from the model and legitimately still read
`31 typed contracts` until the model row lands. The nearer wires this module touches are
M9's deliver law on the scheduler row (deliver/deliver_mode, already supported) and
M10's boundary, which R3 forbids changing; node inference stays M12's CT-19/CT-20.

## 7. Verification

The spec's runnable acceptance checks (spec §7), pinned as the chapter's check ids
M13-1 through M13-5. None of the capability checks has ever been run: the surface they
exercise does not exist.

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| M13-1 | `python3 scripts/bunker_config_gen.py --check --config <cfg>` | exit 0 on a config with a `gateways` section; prints the emitted platform keys | never | **NOT-RUN** — target check; the script has no gateways surface |
| M13-2 | token-pattern grep over a provisioned bunker home (R2's pattern, quoted in §2) | no matches while the gateway is configured | never | **NOT-RUN** — target check; no bunker home is provisioned with a gateway config |
| M13-3 | `boardctl create --deliver telegram:<chat>:<thread> …` then `boardctl show <id>` | `show` prints the `deliver` value | never | **NOT-RUN** — target check; boardctl has no `--deliver` |
| M13-4 | `python3 scripts/handbook_lint.py` | `handbook_lint: clean` after this render row adds the chapter to BOOK.yaml with its register syncs | 2026-11-24 (this render) | **PASS** — the one check this chapter could honestly run, and it ran |
| M13-5 | bunker lane tick with gateways disabled | tick completes and delivers to the scheduler (R3) | never | **NOT-RUN** — target check; it is also today's standing behavior for every scheduler-only lane, but the check itself has not been executed as written |

## 8. Cross-references

- **M9 scheduler** — the deliver law R4 inherits: `deliver` / `deliver_mode` already
  exist on control-host scheduler project rows; bunkers adopt the identical law once a
  lane carries a delivery target. No scheduler schema change.
- **M10 crier** — the launch/return boundary R3 forbids changing: chat delivery is never
  a dependency of task acceptance, and Crier custody semantics are untouched.
- **M12 inference proxy** — the adjacent credential-custody precedent: M12 holds the
  provider key on the control host so no node ever sees it; M13 applies the same
  discipline per bunker, with the token referenced (`token_env`) rather than inlined, and
  never the control host's bot token (R1/R2).
- **CT-31** — the register row (Part IV) and its five synced surfaces; model
  registration pending, per §6.
- **Part V, M13 section** — the settings rows for this surface, marked SPEC-DERIVED.
- Owner directive and design authority: `specs/M13-chat-gateways.md`.

## 9. Evidence of record

- Spec read: `specs/M13-chat-gateways.md` (112 lines, read in full) — the design
  authority for R1–R6, the §3 config surface, §4 wiring, §5 error catalog and §7 checks.
- Implementation-absence greps (2026-11-24, this render): `gateways|token_env|platforms`
  in `scripts/bunker_config_gen.py` → 0 matches; `deliver` in boardctl → 0 matches.
- Board row: CF-529 (render row); spec owner directive dated 2026-11-22.
- **Findings:**
  - **F13-1** — the capability is spec-only: no provisioning, verification or boardctl
    leg exists on the current tree (§4). This chapter must not be cited as evidence that
    any bunker carries a chat gateway.
  - **F13-2** — CT-31 is registered in Part IV but not in `docs/SYSTEM-MODEL.yaml`; the
    map and auto-captions keep the model-derived contract count until the model row
    lands (§6).

ch:trace row=CF-529 spec=specs/M13-chat-gateways.md wave=none:serial-worker test=docs/handbook/chapters/M13-chat-gateways.md#7-verification doc=docs/handbook/chapters/M13-chat-gateways.md evidence=docs/handbook/chapters/M13-chat-gateways.md witness=none:spec-only-render-no-live-capability verdict=none:foreman-runs-gitreins commit=none:worker-commit memory=none:foreman-writes
STATUS: complete
TIER: T1
EVIDENCE: docs/handbook/chapters/M13-chat-gateways.md

## RED field count: 4 (§4 all three target wiring legs ABSENT — provisioner gateway section, verify-node gateway leg, boardctl --deliver; §7 capability checks M13-1/M13-2/M13-3/M13-5 NOT-RUN — only the document-level lint ran; §6 CT-31 SPEC-DERIVED with no in-repo producer/consumer and no model registration; the whole module is SPEC-DERIVED — zero measured runtime evidence exists)

## FLIGHT DATA FILE - M13 CHAT GATEWAYS

```checklist
TITLE: M13 CHAT GATEWAYS
WHO: EACH BUNKER
NO TOKEN - reference a token_env var that is unset on the bunker
! GATEWAY_TOKEN_REF_UNRESOLVED - provisioning warns, lane runs scheduler-only (R3)
  TARGET - not flown; the provisioner leg does not exist yet (F13-1)
TOKEN BYTES - grep the R2 pattern over the provisioned bunker home
√ ZERO MATCHES while the gateway is live - custody by reference
  TARGET - not flown (M13-2)
DEAD TOKEN - revoke the bunker bot token
! named auth error within seconds, tick latency unchanged (R6)
  TARGET - not flown
DELIVERY - tick closes on a lane with deliver: telegram:<chat>:<thread>
√ report link lands in the thread, success or failure (R4, M9 law)
  TARGET - not flown; scheduler-only lanes deliver exactly as before (R3)
```
