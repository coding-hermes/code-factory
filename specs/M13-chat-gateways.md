# M13 (SPEC) — BUNKER CHAT GATEWAYS

Status: DESIGN AUTHORITY for the bunker chat-gateway capability. This file is the spec the
implementation waves build from; the rendered handbook chapter (also `M13-chat-gateways.md`,
same slug) is added by the render row, not by this file.

Owner directive (verbatim, 2026-11-22): "Update specs and boardctl so that each bunker Hermes
can also be in telegram correctly so it's not just a scheduler routing but telegram and other
chat gateway options".

## 1. Purpose

Today a bunker Hermes has no chat presence: it receives work through Crier and the scheduler,
and its reports surface only through the control host's scheduler routing. This spec gives
every bunker Hermes its own chat-gateway connections — Telegram first, gateway-platform
agnostic — so a bunker can (a) hold a chat identity of its own, (b) deliver tick reports
directly into configured chat threads, and (c) remain fully operable when chat is absent.

## 2. Law (normative statements)

- **R1 — Per-bunker gateway identity.** Each bunker Hermes MAY run its own gateway
  connections (`platforms.*` in its `~/.hermes/config.yaml`, mirroring the control host's
  verified surface: `platforms.telegram.{enabled, home_channel{platform, chat_id, name,
  thread_id, user_id}}`). Each bunker uses its OWN bot token — never the control host's token.
  check: two bunkers configured with distinct tokens answer to distinct bot identities.
- **R2 — Token custody is by reference.** Tokens are referenced, never inlined: the generated
  config names an env var or secret file (`token_env: TELEGRAM_BOT_TOKEN`), and generated
  files on disk contain zero token bytes. check: `grep -rEo '[0-9]{8,10}:[A-Za-z0-9_-]{35}'`
  over a provisioned bunker home returns nothing while the gateway is live.
- **R3 — Scheduler routing and chat delivery are independent.** A bunker with no gateways
  configured remains a fully valid lane (scheduler-only). Chat delivery never gates task
  acceptance; the Crier boundary (M10) is unchanged. check: a bunker lane with empty
  `platforms` completes ticks and delivers to the scheduler exactly as today.
- **R4 — Report law is identical on bunkers.** When a bunker lane carries a delivery target
  (`deliver: telegram:<chat_id>:<thread_id>` in the scheduler project row), every tick attempt
  delivers its report link to that thread — success or failure — exactly as control-host lanes
  do (M9 deliver law).
- **R5 — Gateway-platform agnostic.** The config schema and provisioning code must accept any
  platform key the control-host Hermes accepts (`telegram`, `signal`, `discord`, …) without
  bunker-side special-casing. Telegram is the first proven platform, not a schema constant.
  check: a config with `platforms.signal.enabled: true` provisions without error even before
  any signal gateway is exercised.
- **R6 — Fail fast on dead credentials.** An invalid or revoked token must fail the gateway
  within seconds with a named error in the bunker's own log — never a silent hang that stalls
  ticks. check: revoked-token probe logs an auth error and the lane's tick latency is
  unchanged.

## 3. Config surface (exact)

Generated/merged into each bunker's `~/.hermes/config.yaml` (same keys the control host uses;
verified against the local Hermes config surface 2026-11-22):

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

Scheduler project row (control host, already supported): `deliver = "telegram:<chat>:<thread>"`,
`deliver_mode = "link"` (owner ruling 2026-11-16: link mode, into this thread).

## 4. Wiring

- **Provisioning:** `scripts/bunker_config_gen.py` gains a `gateways` input section; it emits
  the §3 block with `token_env` references and merges it into the bunker config at provision
  and re-sync; `scripts/verify-node.sh` gains a gateway leg (config parses; no token bytes on
  disk; `token_env` var resolves on the bunker).
- **boardctl:** rows carry optional delivery metadata so closeout tooling can route evidence
  without chat-specific knowledge: `boardctl create --deliver telegram:<chat>:<thread>`
  (`--deliver-mode link|full`), stored as row keys `deliver` / `deliver_mode`; read back by
  `boardctl show`. The board stays platform-agnostic — the field is a routing hint, not a
  delivery engine.
- **Scheduler:** no schema change (deliver/deliver_mode already exist). The bunker lane
  profile documentation (M9/M13) records the deliver law for bunker lanes.
- **Secrets:** bunker tokens live in each bunker's own env/secret store; provisioning copies
  only the REFERENCE. The control host never holds bunker bot tokens.

## 5. Error catalog

| Condition | Behavior |
|---|---|
| token missing on bunker | gateway disabled at startup, lane runs scheduler-only, provisioning reports `GATEWAY_TOKEN_REF_UNRESOLVED` (warning, not fatal) |
| token invalid/revoked | gateway auth error within seconds (R6), tick pipeline unaffected |
| chat delivery fails (network/platform) | report delivery retries per Hermes gateway defaults; tick completion is NOT blocked (R3) |
| disallowed chat attempts command | Hermes `allowed_chats` enforcement (control-host behavior), no bunker-specific path |

## 6. Out of scope (explicit)

- Bunker-to-bunker chat, group-chat moderation, media ingestion on bunkers.
- Any change to Crier transport or task-acceptance semantics (M10 stays authoritative).
- Making chat delivery a dependency of any gate or judge.

## 7. Acceptance checks (runnable)

1. `python3 scripts/bunker_config_gen.py --check --config <cfg>` exits 0 on a config with a
   `gateways` section and prints the emitted platform keys.
2. `grep -rEo '[0-9]{8,10}:[A-Za-z0-9_-]{35}' <bunker_home>` returns no matches while the
   gateway is configured (R2).
3. `boardctl create --deliver telegram:-1003310984808:196286 …` then `boardctl show <id>`
   prints the `deliver` value (boardctl row).
4. `python3 scripts/handbook_lint.py` → `handbook_lint: clean` after the render row adds the
   chapter to BOOK.yaml with its register syncs.
5. A bunker lane tick completes with gateways disabled and delivers to the scheduler (R3).
