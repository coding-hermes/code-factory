# AGENTS.md — code-factory

Guidance for any agent (Hermes, opencode, claude-code, codex, aider, goose, pi-agent) working
in this repo.

## What this repo is

The build system for the distributed coding workforce. It owns:

- the **specs** that define a node, the dispatch envelope and the harness contract;
- the **board** that tracks the build (`.coding-hermes/board/`);
- the **scripts** that turn a bare bunker agent into a working node.

It does **not** own the scheduler, crier or the task-router. It consumes them. A change here
must not require a change in those repos unless the board row says so.

## The model in one paragraph

A Hermes foreman on the control host designs work; the scheduler decides whose turn it is; crier
carries the directive as a message; a node — one bunker agent, one repo, one harness — executes
it and returns evidence; the foreman verifies the evidence on the control host. Compute is the
constraint, tokens are not, so work is moved to nodes rather than queued on this box.

## Rules

1. **Specs are the design authority.** A script that contradicts `specs/` is a bug in one of them.
   Fix the spec first, then the script, in the same change.
2. **Every check must be able to fail.** A `--check` that cannot print `FAIL` is decoration.
   `tests/selftest.sh` must contain a fixture that proves the failure path, and that fixture must
   itself be able to go green.
3. **Nothing is installed until `--check` says PASS and names the value it measured** (`/api/status
   -> 200`, `sha256 abc123…`, `4.3 GB free`). "Installed" without a probe is a claim.
4. **A version string is not evidence.** The proof a node works is a round trip whose artifact
   digest is recomputed on the control host.
5. **Idempotence is a requirement.** Running any script twice must change nothing and exit 0.
   Anything that appends must be guarded by a sentinel or a check.
6. **No root, ever.** Agents have no passwordless sudo and no apt. If a step needs root, the step
   is wrong: use a user-space artifact under `$HOME`.
7. **Downloads are pinned and digest-checked before use** (`fetch_verified`). Never `curl | sh`.
8. **Credentials never travel as arguments** and never appear in a log, a board row, a spec or a
   test. A node gets one bundle file, mode 600, deleted after provisioning (`CF-002`).
9. **Bus before workspace.** A node that can receive a command but has no repo is diagnosable; a
   node with a repo and no bus is invisible.
10. **Do not grade your own homework.** The node reports what it did; the control host decides
    whether it is true.
11. **Respect the envelope's reserved names** (`specs/ENVELOPE.md`): crier's guard rejects JSON
    keys matching `system|instructions|prompt|tools|schema` with `403 GUARD_BLOCKED`. Rename the
    field by amending the spec, never by inventing an opaque key.
12. **Disk is shared.** One repo node costs ~1.5 GB. Refuse to install below the floor and say the
    number; reap build caches and job dirs before you fill the host.

## The board

- Canonical file: `.coding-hermes/board/tasks.jsonl` — one JSON object per line, git-tracked.
- Append only. Never rewrite the file wholesale; after any write, assert the line count.
- Row ids: `CF-00N`. Fields: `id`, `title`, `status`, `priority`, `complexity`, `reasoning`,
  `acceptance_criteria`, `created_at`, `updated_at`.
- `status`: `pending` | `in_progress` | `blocked` | `complete`. A row is only `complete` when its
  acceptance criteria are demonstrated by a command someone else can re-run — not by a commit
  message that says so.
- `reasoning` carries the measurement that justifies the row (numbers, file:line, error text).
  `acceptance_criteria` is a numbered list of falsifiable statements.

## Commands

```bash
tests/selftest.sh                       # parse every script, prove the checkers fail
scripts/bunker-server-install.sh --check   # can this host run the factory?
scripts/node-create.sh --project P --repo URL --harness hermes
scripts/verify-node.sh --agent ID --artifact PATH
```

Inside a node the entry point is `project-node.sh --check|--apply`.

## Conventions

- Shell: `bash`, `set -uo pipefail`, `bash -n` clean, no `eval`, no `curl | sh`.
- Output: `PASS`/`FAIL`/`WARN` with the measured value; `note` for context. Never a bare "ok".
- Commit style: `<type>: <what> — <why>. Addresses CF-00N.`
- Stage specific paths; no `git add -A`.
- When a measurement contradicts a document, the document is corrected in the same commit and the
  contradiction is named in the message.

## Harness support

Only **Hermes** has a measured install ladder here (`scripts/harness/install-hermes.sh`). The other
adapters ship a real `--check` and a documented method, and their `--apply` **refuses** until
someone runs it and records the ladder in `specs/HARNESS.md`. An unverified installer must say so
out loud — the alternative is a fleet that believes it supports six harnesses when it supports one.
