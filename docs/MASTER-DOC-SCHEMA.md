# MASTER DOCUMENT SCHEMA — what every module section must contain

A section of this handbook is not prose about a component. It is a **claim with
its evidence attached**, in a fixed order, so that a reader can (a) understand
it, (b) reproduce it, and (c) see whether it is currently true.

A module section that cannot fill a required field is not "incomplete" — it is
**RED**, and the empty field is the finding.

---

## 1. Identity

| Field | Rule |
|---|---|
| Module name | The file or service as it is named on disk, not a nickname |
| Path | Absolute, at the revision the section is stamped with |
| Revision | The commit the section was derived from. One revision per document issue |
| Language / runtime | Measured, not assumed (`python3`, `bash 5.x`, `go1.26`) |
| Owner lane | Which scheduler lane or human is responsible for changing it |
| Status | `VERIFIED` / `UNVERIFIED` / `FAILING` — never blank, never "done" |

## 2. Purpose and why it matters

Two paragraphs maximum.

- **What breaks if this module is absent.** Not what it does — what fails.
- **What breaks if it lies.** Every component that reports on itself has a
  failure mode where it reports success. Name it here.

## 3. Dependencies and library contracts

Split into three tables, because they fail differently.

**3a. Runtime dependencies (what must be installed on the host)**

| Dependency | Version constraint | Where it must exist | How absence is detected |
|---|---|---|---|

A dependency whose absence produces a confusing error instead of a refusal is a
defect in this module.

**3b. Library contracts (imports and their pinned expectations)**

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|

Only name a contract the module actually relies on — a function it calls, a
field it reads, a behaviour it depends on. "Uses requests" is not a contract.

**3c. Service contracts (the wire, to other modules)**

| Peer | Direction | Transport | Payload shape | Version / compatibility rule |
|---|---|---|---|---|

Every wire contract names **both sides' file and function** that implement it.
A contract with one side named is a rumour.

## 4. Verification — what proves this works

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|

Rules:
- A check that cannot be run by someone who did not write the module is not a
  check.
- Prefer a command that **fails loudly** over one that prints PASS. If the check
  cannot fail, it is decoration.
- Record the date and the revision of the last run. A check that passed three
  revisions ago is `UNVERIFIED`.

## 5. Metrics it emits

| Metric | Type | Labels | What it answers | Where scraped |
|---|---|---|---|---|

**If the module emits none, write "none" — and that is a RED field.** A module
on the critical path with no metrics cannot be observed, which means every
question about it is answered by reading code or guessing.

## 6. Log lines it can generate

Every operator-visible line, verbatim, with its level and the condition that
triggers it.

| Level | Line (verbatim, format placeholders intact) | Emitted when | Actionable? |
|---|---|---|---|

The rule the quorum taught: **a log line that says something happened is not
evidence that it happened.** Each line here is annotated with whether it is
*descriptive* (reports) or *evidentiary* (can be cited as proof).

## 7. Failure modes

| Failure | How it presents | How an operator distinguishes it from the one above | Recovery |
|---|---|---|---|

## 8. Evidence of record

Links to the artefacts that prove the status: board rows, verdict files, job
directories, log excerpts with timestamps.

---

## Worked example — `crier-fleet/dispatcher.py`, revision `283bca91`

This section exists to demonstrate the shape with real values, including the
places where the honest answer is "none".

**1. Identity.** `dispatcher.py` · `/home/kara/crier-fleet/dispatcher.py` ·
rev `283bca9` · Python 3.14.9 (host interpreter; the file pins no version — `#!/usr/bin/env python3`) · owner: the fleet dispatcher service
(`fleet-dispatcher.service`) · status **VERIFIED** for the job model,
**FAILING** for metrics and for the completion dialect (see 7).

**2. Purpose.** Absent, no task leaves the bus: every dispatch sits in the inbox
until it expires. If it lies, a task is recorded as done that never ran — which
is exactly what happened for 86 consecutive dispatches.

**3a. Runtime dependencies.**

| Dependency | Constraint | Where | Absence detected by |
|---|---|---|---|
| `bunker` CLI | 0.1.4+ (cert pinning) | `/home/kara/.local/bin/bunker` — **absolute path in code**, because two binaries exist on this host and PATH order silently picks the wrong one | exit 127 from `subprocess`, logged |
| `hermes` CLI | on the node | `$HOME/.local/bin/hermes` inside the container | `DONE:127` in the job status file |
| crier bus | reachable | `http://<crier-host>:8767` | `client for <agent> failed` log line |

The crier bus endpoint in this worked example is a placeholder: the real value lives in the
operator's own config on the control host, never in a published document.

**3b. Library contracts.** `crier_client.Crier` — path-injected from
`/home/kara/crier/clients/python`; the module relies on
`Crier.send/retrieve/complete` and on `msg.payload` being a dict **or** a JSON
string (both are handled at `payload_task`). If the client renames `retrieve`,
the dispatcher stops polling and tasks expire silently.

**3c. Service contracts.**

| Peer | Direction | Transport | Shape | Compatibility |
|---|---|---|---|---|
| crier | in | HTTP long-poll | `payload.text_b64` (base64 of the directive), `limits.wall_s` | Falls back to `task/text/prompt/message/body` for older senders |
| scheduler | out | crier complete | `in_reply_to, agent, ok, seconds, task_len, reply_b64, reply_len` | Scheduler decodes `reply_b64` (`dispatch_leg.go`) |
| node | out | `bunker exec` | short calls only: start / poll / kill | **Each call must finish < 300s** — the measured stream ceiling |

**4. Verification.**

| Check | Command | Expected | Last run |
|---|---|---|---|
| fast job | `python3 tests/test_durable_job.py` | `DURABLE-OK`, rc=0 | 2026-11-04, rev `98eb5ce`, PASS |
| kill arm | `python3 tests/test_job_kill.py` | rc=124, 0 survivors | 2026-11-04, PASS |
| boundary | `python3 tests/test_job_boundary.py` | `>300s`, `BOUNDARY-CROSSED` | 2026-11-04, 402s, PASS |

**5. Metrics. — NONE.** The module emits no counters, gauges or histograms.
This is RED: dispatch rate, job duration, kill count and redelivery count are
all currently answered by grepping the log.

**6. Log lines (verbatim).**

| Level | Line | When | Kind |
|---|---|---|---|
| info | `dispatcher up: %d agents, bus=%s, poll=%ss, lease=%ss` | start | descriptive |
| info | `dispatch ledger: %d recorded result(s) — redeliveries replay instead of re-running` | start | evidentiary |
| info | `job %s started on %s (limit %ss, wall %ss)` | job start | evidentiary |
| info | `job %s finished rc=%s after %.0fs` | job end | evidentiary |
| warn | `scoped token mint failed for %s (%s) — dispatching without GH_TOKEN` | token scope unreachable | descriptive |
| warn | `text_b64 did not decode: %s` | malformed dispatch | descriptive |
| warn | `ledger write failed for %s: %s` | disk/permission | descriptive |
| error | `client for %s failed: %s` | bus unreachable | descriptive |
| error | `retrieve failed for %s: %s` | poll error | descriptive |
| error | `dispatcher already running as pid %s — exiting this copy` | double start | evidentiary |

**7. Failure modes.**

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Harness overruns deadline | `DONE:124`, job killed | a crash (`DONE:1` + traceback) | automatic; check the `rc=` log |
| Node unreachable | `client for … failed`, no job dir | a killed job | check bunker, not the harness |
| Reply refused by guard | task runs, answer lost | a timeout | base64 on both legs; see CF-133 |
| **Silent success** | scheduler records a pass for a `status:"failed"` reply | a real pass | **OPEN** (CF-355): `dispatchReplyVerdict` at `internal/scheduler/dispatch_leg.go:713–726` reads only `payload["ok"]`; a node reply carrying `status:"failed"` and no `ok` field is scored a success |

**8. Evidence of record.** Board rows CF-138, CF-204; job dirs
`~/.cf-jobs/job-1793880806-316410e1` (boundary), `…-dde03817` (kill);
`crier-fleet/logs/dispatcher.log`.
