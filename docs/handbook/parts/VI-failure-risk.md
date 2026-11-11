# Part VI — Failure and risk

One subsection per failure class. Each names what fails, the observable signal,
containment, the recovery command where one exists, and the contract that guards the
wire involved. The classes are built from three sources: the contract register's RED and
UNVERIFIED sides (Part IV), the WARNING-class hazards the chapters carry (off-loopback
binding, memory-lost-on-restart), and each chapter's own "what breaks if it lies" record.

The canonical register contains CT-01 through CT-30 plus CT-06R. The former 23-row
state census is a historical snapshot, not the current inventory. Current measured
states are read from Part IV; new target cards do not imply newly proven wires. Every UNVERIFIED row
carries at least one RED side — a guarantee no `file:line` in the model states — so a
failure on those wires has no measured early warning. Where no canonical contract covers
a failure, the subsection says so; an unguarded failure is a risk entry, not a hidden one.

## 0. Stable risk identifiers, the notice convention and the recovery chain

**Stable risk IDs (V2-RSK-05).** Every class in this part carries a stable identifier
`R-nn`, assigned by section number and never reused or renumbered. A class that must be
split continues its identifier with a letter suffix (R-08a, R-08b). The identifier, not
the page number, is what other sections, settings cards and the disposition log cite:

| ID | Class | § | ID | Class | § |
|---|---|---|---|---|---|
| R-01 | A failed run settles as a pass | 1 | R-18 | Wrong served route and truncation | 18 |
| R-02 | Custody lost on restart | 2 | R-19 | Proxy streaming completion | 19 |
| R-03 | Custody lost on crash | 3 | R-20 | Shared-memory consistency | 20 |
| R-04 | Deadline kill misses the harness's children | 4 | R-21 | Restore | 21 |
| R-05 | An untrusted directive reaches a node | 5 | R-22 | Upgrade drift | 22 |
| R-06 | Provisioning admits what it must refuse | 6 | R-23 | Bunker protections, qualified | 23 |
| R-07 | A credential is exposed, or the mode claim lies | 7 | R-25 | Divergent configuration generations | 25 |
| R-08 | Work lands without proof | 8 | R-26 | Partial propagation | 26 |
| R-09 | The control plane is exposed by binding | 9 | R-27 | Stale dual ownership — partitioned host | 27 |
| R-10 | Evidence destroyed, or never written | 10 | R-28 | Failed rebind after replacement | 28 |
| R-11 | The record that lies | 11 | R-29 | Budget exhaustion or silent reset | 29 |
| R-12 | Unproven wires | 12 | R-30 | Local memory loss vs HTTP outage | 30 |
| R-13 | Stale boards and stale claims | 13 | R-31 | Memory synchronization conflicts | 31 |
| R-14 | Unknown verdicts | 14 | R-32 | Unavailable verifier or model | 32 |
| R-15 | Publication and memory projections fail | 15 | R-33 | Resource pressure and unsafe cleanup | 33 |
| R-16 | Replay, uncertain starts and orphans | 16 | R-34 | Durable recovery accounting and fencing | 34 |
| R-17 | Authentication, scope and expiry | 17 | R-35 | Backup, restore and recovery boundary | 35 |

NOTE: the former summary section §24 carried no risk identifier (it indexes classes, it
is not one); the summary is now §36. No R-id
was dropped or reassigned.

**Notice convention.** This document defines its own accepted scheme, used deliberately:
**NOTE** is informational — a fact the operator should know, no action implied;
**CAUTION** flags a hazard to data or equipment — a procedure that can lose custody,
evidence or availability if skipped; **WARNING** flags a hazard an operator must not
proceed past. This book carries no personnel hazards, so WARNING is reserved for the
stopping-grade hazards (custody loss, exposed control planes) — the reader should expect
CAUTION for most operational risks and treat WARNING as the rarer, harder stop.

**The recovery chain (V2-RSK-03).** Managed repair follows one ordered chain, and every
class section after §25 names where its recovery sits on it. Each step is classified
**automatic** (the management layer or owning component does it), **operator-invoked**
(a documented runbook command an operator or authorized agent runs), or **unsupported**
(named, with the gap recorded):

| Step | What happens | Typical class |
|---|---|---|
| 1. Detection | the deviation or failure is observed through its signal/metric | automatic (where the metric exists — many are TARGET) |
| 2. Classification | the failure is attributed to component, principal and scope; severity/priority assigned | automatic, with operator confirmation on ambiguous attribution |
| 3. Desired/observed status | the affected scope is marked degraded/blocked/retrying against its desired generation | automatic |
| 4. Authorized scoped repair | the configured repair runs under its declared authority — credential renewal, config correction, service restart, route/registration repair, memory fallback/sync, or full replacement only when needed | automatic for scoped repairs; operator-invoked for unqualified or cross-domain actions |
| 5. Readback / end-to-end readiness | the failed operation is re-proven and end-to-end readiness verified — not just liveness | automatic |
| 6. Routing/admission resume | Crier/scheduler bindings and admission re-enabled; recovery evidence retained | automatic |

Two repair rules bound every class. A permission denial is never repaired by silently
increasing access — revocation or a denied permission is not authority to expand a grant
(V2-OPS-01). And not every service failure justifies recreating the host: the scoped
repair is the first authority tried, and full replacement (F2/F8) is the fallback, not the
default. Repair and test evidence is recorded separately from approved target policy — a
drill record proves the drill, not the deployment.

## 1. A failed run settles as a pass

**What fails.** The settlement reader `dispatchReplyVerdict`
(`internal/scheduler/dispatch_leg.go:713-726`) reads only `payload["ok"]` and treats the
absence of a verdict as success (`:709-712`). A node reply carrying `status:"failed"` —
the field `node-bus-worker.py:1180` actually sends — and no `ok` is scored a success: the
control-plane half of the silent-success defect, CF-355 open (M9 §2). The node-side
mirror: a worker that replies with a false `ok` records a pass for work that never
happened (M2 §2). One reconciliation before either transport claim is used (V2-RSK-04):
the dispatcher leg always sends `ok` — including its documented failed-result reporting,
which writes `ok: false` with error detail (M11 §6) — so that leg *does* carry verdict
information and the reader's ok-only policy happens to score it correctly. What the
dispatcher leg never carries is the node worker's `status` verdict field; the defect is
the reader ignoring that field on the leg that sends it, not the dispatcher's own failed
reporting.

**Signal.** A board row closes complete while the worker's reply body says
`status:"failed"`; a scheduler pass row whose correlated reply carries no `ok` field.

**Containment.** Read the reply body, not the verdict bit. The reply carries `status`,
`dispatch_id`, `corr_id`, `branch`, `commit` and artifacts (CT-04); the settlement defect
is confined to the reader, not the transport.

**Recovery.** No automated recovery — CF-355 is open on both halves. Closing it requires
the scheduler to read `status` at `dispatch_leg.go:713-726`.

**Contract that guards it.** CT-04 (node → crier, PARTIAL — both sides RED), CT-06
(crier → scheduler, PROVEN on the dispatcher leg that always sends `ok`).

## 2. Custody lost on restart — the memory registry backend

**What fails.** The crier's `memory` registry backend is process-local and demo-only:
held deliveries and inboxes are lost on restart (`config.go:550-551`). The backend is
resolved by `ResolvedRegistryBackend()` (`config/config.go:113-123`) in this precedence:
an explicit `CR_REGISTRY_BACKEND` → a `sqlite:` `Database.URL` → any non-empty
`Database.URL` (postgres) → `memory` — so a deployment that sets nothing runs on memory
by default. Custody is not durable under it.

> WARNING: any deployment that must survive a daemon restart requires a `sqlite:` or
> `postgres` backend (`config.go:550-551`, M10 §5).

**Signal.** Empty inboxes after a restart on a bus that held deliveries; the selftest
prints `EMPTY - inboxes are empty after restart (WARNING: memory custody is not
durable)`. No runtime readback proves which backend is serving custody — that procedure
is a named RED on M10 §5.

**Containment.** Set `CR_REGISTRY_BACKEND` explicitly on every deployment that holds
real work. The resolution chain ends at `memory`, so absence of configuration is itself
the hazard.

**Recovery.** Configure a durable backend and restart; messages held only in memory are
gone — redelivery from the sender (CT-02 envelope, CT-06 completion event) is the only
path back.

**Contract that guards it.** CT-03 (crier → node, lease and inbox semantics, PROVEN);
CT-02 (envelope delivery, PROVEN) — the durable halves exist, the memory backend bypasses
them.

## 3. Custody lost on crash — the ledger and seen-cache

**What fails.** Two crash windows survive the transport's durability. The dispatcher:
a crash between task execution (`dispatcher.py:479`) and `ledger_put` (`:481`) leaves no
replay record — redelivery re-runs a task whose result was lost; a ledger write failure
is swallowed and only the in-memory copy survives (`:397`) (F11-3, both execution modes).
The node: the seen-cache is written only after delivery succeeds, `save_seen` failure
only warns (`node-bus-worker.py:1398-1403`), and two previously-unseen messages sharing
one dispatch key in a single batch both execute before either result enters the cache —
the idempotency window deduplicates across batches, not within one (M2 §11).

**Signal.** `ledger write failed …` in the dispatcher log; `could not record the
seen-cache` (`:1402`) from the node; a redelivered dispatch that executes twice.

**Containment.** Redelivery is the chosen safer outcome: the node acks last and skips
the ack when delivery failed (`:1407-1414`), so an unacked message returns.

**Recovery.** Treat a re-execution as possible after any crash: check the ledger and the
seen-cache before assuming a result is unique. No command repairs the window.

**Contract that guards it.** CT-03 (PROVEN — the lease and redelivery machinery is
measured); CT-04 (PARTIAL — the reply's durability is not).

## 4. The deadline kill misses the harness's children

**What fails.** The runner template starts the harness as
`timeout {limit} … hermes chat -q … &` (`dispatcher.py:260`); GNU timeout puts the
command in its own process group (`:246-249`). The deadline kill at `:329` sends
`kill -TERM -$(cat {d}/pid)` — `pid` is run.sh's own `$$` (`:291` runs `setsid sh
run.sh`) — so it kills run.sh's group (run.sh, the heartbeat subshell, the `timeout`
wrapper) and not the separate timeout group holding `hermes` and its children. An
independent disposable execution measured `timeout_still_live=True` after the runner
group was terminated; the "kill the process GROUP so nothing keeps spending" guarantee is
withdrawn (F11-8, B01). Two adjacent defects: `DISPATCH_EXEC_TIMEOUT` is inert — assigned
at `:47`, never read (B22) — and `task_seconds` does not refuse a caller budget too small
for its own 30 s floor (`task_seconds(10)` returns 30, F11-4).

**Signal.** `DONE:124` with surviving `hermes` processes on the node after the deadline;
a node still consuming inference tokens after its job is killed.

**Containment.** Check for surviving harness processes after every deadline kill; do not
assume automatic descendant termination (M11 §10).

**Recovery.** Kill the surviving process group by hand. No tested automatic path exists.

**Contract that guards it.** CT-23 (provisioner → bunker, UNVERIFIED — the exec surface
that runs the job is itself uncited on the daemon side); no canonical contract covers
process-group semantics, a named gap.

## 5. An untrusted directive reaches a node

**What fails.** The guard's error path defaults to fail-open: `errorResult`
(`guard.go:318-361`) allows with the `errored` flag unless the policy sets `FailClosed`
(M10 §10). An oversized payload skips the LLM and branches on deterministic evidence —
a low-confidence prematch allows (errored), no prematch allows "oversize" (errored)
(`guard.go:198-234`). Signature enforcement is conditional: `RequireAgentSig` false →
`requireAgent` returns true without a signature (`agentsig.go:364-368`). And the bus has
no versioned refusal: an old node silently accepts a new control host's envelope —
CF-369 open (M10 §10).

**Signal.** Verdicts carrying the `errored` flag; `crier_guard_saturated_total`
incremented (`internal/guard/metrics.go:22`); a read succeeding without a signature; a
node acting on an envelope version it was never built for.

**Containment.** Set `FailClosed` on the policy; keep `RequireAgentSig` true (default);
the `CR_GUARD_*` env bounds refuse non-numeric and `<= 0` values at startup with a named
error (`config.go:1139-1187`), so mis-tuning cannot silently disable the guard.

**Recovery.** Re-enable `RequireAgentSig` (`config.go:629`) or set `FailClosed` on the
policy and re-deliver; the deterministic pre-scan result is always carried on
`Result.Patterns`, so the skipped verdict is auditable after the fact.

**Contract that guards it.** CT-02 (PROVEN — the envelope reaches the guard intact);
CT-03 (PROVEN — the signed read is measured); CT-05 (foreman → scheduler, UNVERIFIED —
the prompt-text wire upstream of the guard is uncited on both sides).

## 6. Provisioning admits what it must refuse

**What fails.** Four measured lies let a host or credential past admission:

- `fetch_verified` (`lib.sh:19-42`) is the pinned-download primitive every installer
  relies on; a false digest match installs a wrong or tampered binary and reports PASS
  (M0 §2).
- `require_disk` (`lib.sh:48-57`) is the disk floor; a false "enough space" lets the
  provisioner proceed onto a host it must refuse (M0 §2). A missing `df` yields an empty
  `free` and the awk admission mis-decides the floor (M0 §4a).
- `bunker-provision.sh --check` reports a credential "mode 600" while testing only file
  non-emptiness (`:214` probes `[ -s … ]`, `:233` prints `token file installed, mode 600
  (value not read)`) — F1-1.
- `verify-node.sh` can finish `VERIFY: PASS` (exit 0) with an unmeasured checkout: the
  checkout leg's unmeasurable case prints WARN without calling `unverified()` (`:177`),
  unlike the seed leg (`:225`) — the asymmetry is a false-green path when freshness is an
  acceptance condition and `--strict-freshness` was not passed (B05, M1 §11).

**Signal.** `FAIL disk-floor …` absent where it should fire; a `PASS` credential row
whose probe never read the mode; `VERIFY: PASS` with a checkout WARN in the same output.

**Containment.** The refusals that do work are named and fail before side effects: a
deploy key at mode 0644 is refused before any agent is spawned; an unknown explicit role
is refused, not defaulted (F1-2); `node-create.sh --gomodcache` refuses a relative path.

**Recovery.** `chmod 600` the credential and re-run; pass `--strict-freshness` to promote
unmeasurable to FAIL; `gomodcache.py seal` on the prewarm host when the cache check
fails; re-run `project-node.sh --apply` when the gateway-auth gate fails.

**Contract that guards it.** CT-23 (provisioner → bunker, UNVERIFIED — the daemon accept
side is uncited); CT-21 (github → node, UNVERIFIED — the credential the provisioner
installs is minted on an unmeasured wire).

## 7. A credential is exposed, or the mode claim lies

**What fails.** The fleet's law is that credentials travel as file paths, never argv
values (FACT-05) — a mint that prints the token value is a leak, and a refresh that
serves a stale token while reporting fresh silently pushes with an expired credential
(M7 §2). The mode predicates themselves partially lie: `harness-vars.sh:203` accepts any
mode `[0-7]00` (000..700) while its refusal message claims "a key file must be 600", and
the ambient-key check tests non-emptiness, so `CF_API_KEY=""` is accepted (F0-6). A
silent acceptance of a credential value lets two lanes on one node contaminate each
other (M5 §2).

**Signal.** `bad "mode" … expected 600` before a store rewrite (`:127-130`, CF-320);
`… is mode %04o; a private key must be 0600` (`github-app-token.py:344-348`); a token
file younger than `MIN_AGE` (2400 s) serving as fresh.

**Containment.** The mode check exits 1 before the credential-store rewrite; the key file
must be exactly 0600; `github-app-refresh.sh --dry-run` exits before mint or write
(`:106`, `:154`) — distinct from `--quiet`, which suppresses output only (B16).

**Recovery.** `chmod 600` the token or key file and re-run; the mint refuses and exits
before writing anything on a wrong mode.

**Contract that guards it.** CT-21 (github → node, UNVERIFIED — the mint has never been
run on this host for lack of App creds); CT-19 (node → proxy, UNVERIFIED — the node
bearer token's client half is config-wired only).

## 8. Work lands without proof

**What fails.** The landing path can publish ungraded, and a record can close with
insufficiently verified evidence. One clarification first (V2-RSK-04): the board store
does not both accept and refuse an absent evidence ID — `boardctl update --status
complete` **refuses** a completion with no bound run id (TR-251), unconditionally. The
gap is not ID presence but evidence completeness: the store requires that *an* id be
named, and does not verify that the id resolves to a real run, that the run's verdict is
passing, or that the evidence ties to the exact merged tree and the published
destination — the verification/provenance/exact-tree/publication completeness gap the
review names. `land-node-branch.sh` initialises `GATE=""` and `run_gate` returns 0 on an
empty gate (`:74-75`), so a landing with no `--gate-cmd` runs no project gate (F3-3); the
pre-commit hook exits 0 when `.gitreins/config.yaml` is absent (`install-gitreins.sh:
130-131`) — a bypass that is by design but must be disclosed when used (M3 §10). Nothing
in-repo invokes the lander at all (F3-5): the result envelope names `branch` and `commit`
(`node-bus-worker.py:1187-1188`) but does not call it — the landing step is
operator-triggered. On the record side, the node worker writes no board rows — no
in-repo producer exists (CT-10, BROKEN).

**Signal.** `refuse descendant … rebase the branch` (`:202`) or a missing gate row in the
landing log; a closed row with no evidence run id (which boardctl refuses); a landing
that reports success is trustworthy only with the `LAND:` proof rows.

**Containment.** The lander's own proof: it pushes an explicit object, re-fetches, and
proves `git merge-base --is-ancestor` (`:278-300`); the PASS row belongs to the proof,
never to the merge (`:23`). A post-push fetch failure falls back to the tracking ref and
an `ls-remote` disagreement only warns (`:288-299`).

**Recovery.** Pass `--gate-cmd` on every landing that needs a project gate; rebase the
node branch onto remote main on a descendant refusal; close rows with `boardctl update
--status complete --evidence-run-id <id>` or not at all.

**Contract that guards it.** CT-10 (node → board, BROKEN); CT-12 (node → gitreins,
UNVERIFIED — the hook is installed, hook enforcement is unproven); CT-13 (gitreins →
board, UNVERIFIED); CT-14 (foreman → board, UNVERIFIED).

## 9. The control plane is exposed by binding

**What fails.** Two daemons carry an explicit WARNING-class hazard: binding off-loopback.

> WARNING: the scheduler's HTTP surface is loopback by construction — `listen` defaults
> to `127.0.0.1:9090` (`cmd/schedulerd/main.go:96`). Binding it off-loopback exposes the
> API beyond the host it runs on (M9 §5).

The crier front's `defaultListen` is `127.0.0.1:8770` (`crier-front/main.go:39`) and
binding it off-loopback exposes the front (M10 §5). The inference proxy is the deliberate
counter-case: `LISTEN = ("0.0.0.0", 8775)` is a hardcoded constant with no override, so
the tailnet can reach it (M12 §5) — its admission is the token allowlist (401 without a
node token) and the model allowlist (403 with the `allowed` list), both measured on the
proxy side (M12 §6). No canonical contract covers the scheduler or front listen surfaces
— a named gap.

**Signal.** The scheduler API answering on a non-loopback interface; the proxy's
`unauth_refused` leg failing — `/api/system/stats` returning 200 where 401/302/403 is
required (`verify-node.sh:116-129`).

**Containment.** Keep `listen` on `127.0.0.1` unless an authenticating front end sits in
front of it (M9 §5 WARNING). The gateway-auth gate refuses a public bind without
`dashboard.basic_auth`: layer 20 stages the block (`node_gateway_auth.py`) before the
adapter runs, and an occupied port with no block is a counted FAIL row (CF-150, CF-192).

**Recovery.** Re-point `listen` at loopback or add the front end; write the
`dashboard.basic_auth` block (`scripts/node_gateway_auth.py <config.yaml>
<password-file>`) and re-run `project-node.sh --apply`; the port row turns PASS on the
next run.

**Contract that guards it.** CT-19 (node → proxy, UNVERIFIED — the token admission is
proxy-verified, the client half is not); CT-08 (crier → gateway, PROVEN — the session
delivery the front exposes); no CT for the scheduler listen surface.

## 10. Evidence is destroyed, or never written

**What fails.** The reaper can delete a directory a module cites as evidence: since
CF-290 the cache branch carries an age gate (`--cache-ttl-hours`, measured on the newest
mtime anywhere in the subtree; `scripts/reclaim_disk.py:66-84`, `:154`), but the TTL
governs age, not citation, and the two are still conflated at the citation end — CF-368
open (M8 §2).
Dispatcher jobs under `.cf-jobs` are not a reap target of `AGED_PARENTS`, so the
dispatcher-job retention path has no reaper at all (F8-3). The node worker writes no
board rows (CT-10, BROKEN) and makes zero DuckBrain calls (CT-09, MISSING, CF-329) — the
run record has no in-repo producer on either sink. In the proxy, request-capture loss is
silent (`capture_request` swallows every exception) while a usage-sink failure raises
into the request path (F12-6) — the audit sink fails quietly and the billing sink fails
loudly.

**Signal.** A job dir cited as evidence disappears after a reap; `FAIL audit-scope:
<path> …` from the scan-scope gate (which never prints a green it did not measure,
CF-307); `FAIL orphans — N orphan(s) would be reaped` from the hygiene check.

**Containment.** `PROTECTED` (`repo`, `.node/node.json`, `.node/crier.json`,
`.node/floor.toml`) is refused via `safety_reason` before inspection; `--dry-run`
deletes nothing and prints projected bytes only (B15); `reap --registry` refuses to run
without a live-id registry.

**Recovery.** `node_hygiene.py reap --min-age-minutes 60 --registry <ids>` for orphans
inside the default grace; `reclaim_disk.py run` for caches; a reaped evidence directory
is unrecoverable — the still-open exclusion rule (CF-368) is the only real fix.

**Contract that guards it.** CT-10 (BROKEN), CT-09 (MISSING) — both record sinks lack a
measured producer; CT-14 (foreman → board, UNVERIFIED).

## 11. The record that lies — registers and gates

**What fails.** A register can point an operator at files that do not exist: an earlier
proxy register revision carried two invented sink paths (`~/.hermes/logs/cf-usage.jsonl`,
`cf-capture.jsonl`) — neither is written (F12-8) — and the proxy's startup error
hardcodes `API_SERVER_KEY` in its message even when a different credential name is
configured, so the diagnostic lies about which variable it checked (F12-3). The
documentation gate is structural, not a truth verifier: it imposes citation requirements
on the document's supplied status and re-emits that status without verifying that cited
code supports the prose (F6-2); the live result showed 37 unit sections stamped VERIFIED
alongside 50 errors. The spine gate checks the presence of a `file:line` pattern, not
that the line exists at that number in that file (B6). And `ok`/`bad` PASS/FAIL rows are
descriptive, not evidentiary — printed unconditionally from two arguments (F0-4).

**Signal.** `MASTER-DOC: FAIL` beside 37 VERIFIED stamps; an operator opening a sink
path that is never written; a PASS row with no measurement behind it.

**Containment.** The empty-selection PASS is fixed — a root with zero `NN-*.md` modules
is a named failure (`master_doc_check.py:191-209`); the spine compares the normalized
contract state for internal contracts, so two chapters citing one CT with different
state words can no longer both pass; a chapter that measures a contract state different
from Part IV amends the register row in the same commit (BOOK.yaml rules).

**Recovery.** Re-point the stale locators to the real root (open); re-pin invented paths
to the measured ones (F12-8's correction is recorded in M12 §5 and Part V of this book).

**Contract that guards it.** CT-16 (docsgate → handbook, UNVERIFIED — the handbook build
reads no MASTER-DOC output); CT-18 (handbook → owner, UNVERIFIED — the legacy renderer
hardcodes `docs/master` and does not select the M*.md chapters).

## 12. Unproven wires — the register's RED and UNVERIFIED sides

**What fails.** Sixteen of 23 contracts are UNVERIFIED, one PARTIAL (CT-04), one BROKEN
(CT-10), one MISSING (CT-09). Each UNVERIFIED row carries at least one RED side —
"no `file:line` in the model states what X commits to" — meaning the sender's guarantee
or the receiver's requirement is asserted without a citation. A failure on such a wire
produces no measured signal, because no measurement of the wire exists. The four PROVEN
rows (CT-02, CT-03, CT-06, CT-08) are the transport and settlement spine; everything
hanging off them — memory, records, verdicts, credentials — is uncited on at least one
side.

**Signal.** The register row itself. The generator enforces the self-contradiction: a
PROVEN state with an uncited side prints as UNVERIFIED (Part IV caution).

**Containment.** The five-state vocabulary
(`PROVEN | PARTIAL | BROKEN | MISSING | UNVERIFIED`) is the only state language; a
chapter that measures a different state than the register amends the row in the same
commit; the spine gate compares chapter §6 states against register rows and fails on
disagreement or an absent `CT-nn`.

**Recovery.** For each row, quote the encode site and the decode/validate site and
replace the RED line with those citations — the register's "To close" lines name the two
ends per row. CT-10 and CT-09 additionally need a producer to exist before either can be
cited.

**Contract that guards it.** The register itself (Part IV) and the spine gate (M6 §5);
CT-17 (conformance → harness, UNVERIFIED) is the wire that would grade harness claims and
was not run this round (needs a live node; CF-328).

## 13. Stale boards and stale claims

**What fails.** The board is two stores in git, `origin/main` is the canonical copy, and
the working copy is a cache other writers are allowed to dirty (VII §2). Three stale-state
failures follow: a node claims or works a row from a copy another actor already closed; a
workdir is stale relative to its remote and the tolerance is configured wide
(`repo_freshness --bound`, default 0, M3 §5); and an unreadable board is mistaken for an
empty one — the review requires the work/no-work/unreadable distinction to be explicit
(M4 review), and the current read path never refuses, it only reports its source.

**Affected invariant.** One row, one claim, one current copy: eligibility is decided
against the canonical revision.

**Detection / metric.** Required (TARGET-UNIMPLEMENTED): work age, backlog depth,
cross-copy drift and failed transitions with collection/readout (M4 review). Today:
`repo_freshness` behind-counts and `board_read.py load`'s source report are the only
measured signals.

**Visible state.** A dispatch executes against a row already closed; a tick reports no
work on a board whose canonical copy holds dispatchable rows.

**Containment.** `board_lock.py adjudicate` returns ERROR when the lock state is unknown —
exit 3, never permission to write (M4 §3, CF-259); the read path reports which ref it
resolved, so a stale-source read is at least visible.

**Owner.** The foreman owns claims through Boardctl's canonical CAS; Scheduler owns
lane admission only. The foreman owns refresh-before-work
(Figure 2.1 requirement, TARGET).

**Retry / recovery.** Re-fetch `origin/main`, re-evaluate eligibility, re-derive the
claim; a claim made on a stale copy is re-derived, never resumed.

**Proof.** The tick line names the board revision it worked from (required; not yet
produced by any in-repo actor — a named gap). Contracts: CT-01 (UNVERIFIED side), CT-14
(UNVERIFIED).

## 14. Unknown verdicts

**What fails.** The settlement reader treats the absence of a verdict as success (§1), and
the legacy reply path accepts missing verdicts (M9 review). A dispatch that never settles
leaves the run neither pass nor fail; a judge session that times out returns MISSING seats;
a replayed ledger entry can carry a result whose verdict field is empty. Unknown is a
distinct outcome class and today no counter separates it from success.

**Affected invariant.** Every execution settles to a named outcome: pass, fail or unknown —
never silence.

**Detection / metric.** Required (TARGET-UNIMPLEMENTED): a settlement-outcome counter with
`unknown` as a distinct class, built on the availability-aware scheduler telemetry (M9
review). Today: no signal — the silence is the defect.

**Visible state.** Rows held `in_progress` past their deadline; a scheduler pass row with
no verdict in the correlated reply.

**Containment.** The typed settlement/verification/quiescence records exist in the newer
path; the open defect is that data structures alone do not prove every runtime path uses
them (M9 review).

**Owner.** The scheduler owns settlement; gitreins owns the grade.

**Retry / recovery.** Re-grade, never infer: a missing verdict is re-run through the judge,
not defaulted to pass (CF-355 open on both halves, §1).

**Proof.** A verdict that names its criteria and whose exit matches its rows (VII §6).
Contracts: CT-04 (PARTIAL), CT-13 (UNVERIFIED).

## 15. Publication and memory projections fail after the work is done

**What fails.** Execution, independent verification, publication, board close and memory
projection are separate stages with separate owners, and the later stages fail silently
today: the node worker writes no board rows (CT-10, BROKEN) and makes zero DuckBrain calls
(CT-09, MISSING, CF-329), so a landed commit can be invisible to the next cadence and to
shared memory. Crier delivery alone is not task acceptance, and a transport worker's lack
of direct writes does not prove the foreman path lacks them (M2 review) — the projection
path must be specified, not inferred absent.

**Affected invariant.** Published work is projected to every record sink — board and shared
memory — before the run is done; no sink is optional.

**Detection / metric.** Required (TARGET-UNIMPLEMENTED): per-sink projection success/failure
counters and backlog age. Today: absence of rows is the only signal, and nothing counts it.

**Visible state.** `LANDED:` proof rows with the board row still `in_progress`; a completed
tree with no memory record.

**Containment.** Closeout verbs refuse incomplete evidence (`--evidence-run-id`, TR-251);
the landing proves ancestry before it pushes (§8).

**Owner.** The foreman owns closeout and projections; the register reassigns memory/board
producers to the foreman projection path, not the transport worker (Part IV review).

**Retry / recovery.** Closeout verbs are idempotent re-runs: re-close with the same
evidence run id; re-write the memory projection from the run record.

**Proof.** One new event line per closure bound to the exact tree, plus a memory readback
naming the run (required; producers do not exist yet). Contracts: CT-10 (BROKEN), CT-09
(MISSING), CT-14 (UNVERIFIED).

## 16. Replay, uncertain starts and orphans

**What fails.** The dispatcher's replay ledger is written after the task runs
(`dispatcher.py:479` vs `:481`, F11-3) and a failed ledger write is swallowed (`:397`) — a
crash in the window re-runs work whose result was lost. A detached start whose ledger row
never lands is an uncertain start: the node may be executing with no record anywhere.
Orphaned node agents — created, never registered — accumulate until the hygiene reaper
removes them after the age grace. The review requires durable intent and a native run
identity before execution; a post-execution replay ledger is insufficient for crash-safe
execution (M11 review).

**Affected invariant.** Every start is recorded before it executes; every result is
recorded before it is acknowledged.

**Detection / metric.** Required (TARGET-UNIMPLEMENTED): `replayed_results`,
`uncertain_starts`, `reconciled_starts`, orphan counts and quiescence latency (M11 review).
Today: `ledger write failed …` and the hygiene `FAIL orphans` row.

**Visible state.** A job with no ledger row; `DONE:124` with processes still alive (§4);
`FAIL orphans — N orphan(s) would be reaped`.

**Containment.** Redelivery is the chosen safer outcome (ack last, §3); the reaper runs
only against a supplied live-id registry after the grace (`reap --min-age-minutes`,
default 60).

**Owner.** The dispatcher owns jobs and receipts; node hygiene owns orphans.

**Retry / recovery.** Reconcile at startup against the bus inbox and the ledger; reap
orphans after the grace; treat re-execution as possible after any crash (§3).

**Proof.** A ledger row keyed by a preassigned `launch_id` and native run identity,
written before execution (required target behavior). The Crier launch envelope carries
that identity through the foreman Bunker; after a lost acknowledgement, reconciliation
queries the Bunker by `launch_id` and `idempotency_key` before any retry. Contract:
CT-23 (UNVERIFIED).

## 17. Authentication, scope and expiry

**What fails.** Credentials expire while their files persist: token-file age alone is not
validity, and expiry proof is different from explicit revocation (M7 review). A mint can
serve a token whose scope exceeds the required repositories — checking installation
coverage does not narrow the token (M7 review). A refresh that serves a stale token while
reporting fresh silently pushes with an expired credential (§7).

**Affected invariant.** Every credential in use is unexpired, minimally scoped, and
provably revoked when retired.

**Detection / metric.** Required (TARGET-UNIMPLEMENTED): expiry headroom, expired/unknown
credential counts, refused scope/permission mismatches, renewal lag and revocation
completion (M7 review). Today: mode checks and `--min-age` windows only.

**Visible state.** Git authentication failing mid-landing; a mint refusing a scope; a token
file younger than `MIN_AGE` serving as fresh.

**Containment.** The mode-600 check exits 1 before the credential-store rewrite (CF-320);
`--dry-run` exits before mint or write; the scoped minter (`FLEET_GH_SCOPE`) narrows at
issuance.

**Owner.** The M7 credential issuer owns forge credentials; the M12 proxy owner owns node
tokens — the domains are distinct (M7 review).

**Retry / recovery.** Re-mint on expiry; revocation is always explicit, never implied by
age; decommissioning removes the delivered credential, not just the mapping.

**Proof.** Mint/refresh outcome records carrying scope and expiry metadata (required).
Contracts: CT-21, CT-19 (both UNVERIFIED).

## 18. Wrong served route and truncation

**What fails.** The proxy rewrites the requested model when `CF_PROXY_UPSTREAM_MODEL` is
set (`:166-170`), so the served model can differ from the requested one, and no
requested-versus-served identity contract is yet written (M12 review). The 300 s upstream
timeout on both stream and buffered legs truncates long generations; a body over `MAX_BODY`
is refused with 400. A client can receive a completion that names a model it did not ask
for, or a partial answer that looks whole.

**Affected invariant.** The served response is the requested route, complete, or a named
error — never a silent substitution or a silent cut.

**Detection / metric.** Required (TARGET-UNIMPLEMENTED): requested-vs-served model
mismatch counter and partial/completion/error classification per response (M12 review).
Today: usage-log records exist; the mismatch is not counted.

**Visible state.** A usage record whose served model differs from the request; a
completion cut at the timeout boundary.

**Containment.** The model allowlist (403 outside `CF_PROXY_ALLOWED_MODELS`) and the body
ceiling are measured on the proxy side (M12 §6); the timeout is configuration, not policy.

**Owner.** The M12 proxy owner owns the route; the router policy owner owns the effective
model mapping.

**Retry / recovery.** Client retry within its budget; no automatic completion resume —
a truncated stream is a named failure, not a shorter answer.

**Proof.** Buffered and streamed schemas with framing/completion/partial/error behavior,
conformed on the actual path (required; CT-19/CT-20 evidence, not stale local IDs — M12
review). Contracts: CT-19, CT-20 (UNVERIFIED).

## 19. Proxy streaming completion

**What fails.** The reported healthy-stream completion defect: a stream that reports
healthy at its first byte can still fail at completion. A first-byte-only flight card
cannot close the defect (M12 review). The local proxy source/runtime was not supplied for
independent validation, so the defect is retained with that qualification, not closed and
not dismissed (handoff, M12).

**Affected invariant.** Stream completion framing is proved on the actual path, not
inferred from connection health.

**Detection / metric.** Required (TARGET-UNIMPLEMENTED): per-stream completion outcome with
error/cancel classes, distinguished from connection-establishment outcomes.

**Visible state.** A client-side truncated stream recorded as successful upstream.

**Containment.** None measured. The defect stays open.

**Owner.** The proxy maintainer, once versioned source lands (handoff §6).

**Retry / recovery.** The client observes the truncation; recovery is the same named
failure as §18.

**Proof.** Actual-path conformance evidence with maintained versioned source (required
before the defect can close). Contracts: CT-19, CT-20 (UNVERIFIED).

## 20. Shared-memory consistency

**What fails.** DuckBrain must be installed in every Bunker and expose the same logical
project memory view as the controller (user decision, handoff §1.2) — but installing
identical software does not itself provide the same data view (handoff §6). Until the
shared topology is specified, the failure modes are unbounded: a Bunker reading a
namespace the controller has not written, divergent bidirectional projections, offline
edits conflicting on reconnect.

**Affected invariant.** One logical memory view across control host and Bunkers, with
defined authority, consistency and conflict behavior.

**Detection / metric.** Required target metrics are `memory_view_freshness_seconds`,
`memory_sync_pending_total`, `memory_sync_conflicts_total` and `memory_sync_replays_total`,
with namespace/project and outcome labels bounded to configured values. The controller
reads the local Git-backed namespace and the last acknowledged remote commit; stale or
partial quality is visible and cannot establish convergence.

**Visible state.** A Bunker foreman reasoning over memory the controller cannot see, or the
reverse; the result is `MEMORY_VIEW_STALE`, never an empty successful view.

**Containment.** The supported profile keeps a local Git-backed namespace in every
Bunker and controller. The namespace path and remote ref are configured per project;
local writes remain valid during HTTP outage when the local store is durable, and each
unpublished record is `pending-sync`. A local-only configuration is valid only for a
single-host project or when all participants mount the same shared Git-backed view;
otherwise it is refused as `MEMORY_TOPOLOGY_UNSUPPORTED`.

**Owner.** The project foreman owns the local record and pending queue; the memory sync
owner authenticates the same namespace on the controller and Bunkers. Authorization
binds `(project_id, namespace, writer_identity, generation)` and rejects cross-project
writes.

**Retry / recovery.** Reconnect exchanges namespace commits and record manifests. A
same `record_id` and digest is an idempotent acknowledgement; the same id with a
different digest is `MEMORY_CONFLICT` and is retained for explicit resolution. The
sync owner merges independent records without dropping either, deduplicates replay by
record id, verifies the resulting commit and reports freshness. Namespace loss is
restored only from a validated backup; missing pending entries are reported as loss.

**Proof.** Cross-host readback shows both offline entries exactly once, then the
controller and Bunker expose the same namespace commit and freshness. Contract: CT-09
(MISSING) covers the node-side producer only; the sync profile remains target behavior
until its live wire is measured.

## 21. Restore

**What fails.** A restore that loses lease, idempotency or identity state re-executes held
messages or orphans in-flight custody. The review requires the restore procedure for every
configured registry/session store — consistent snapshots, retained identities and
idempotency state, service drain/restart and restored-delivery verification — and keeps
backup-created, backup-validated and restore-drill-passed distinct: a skipped drill is not
a proven restore (M10 review). Existing scripts, units and historical drills do not prove
fleet deployment or off-host recovery (M10 review).

**Affected invariant.** Durable custody survives a full host loss: every held delivery and
identity is recoverable, and nothing is re-executed that was already acknowledged.

**Detection / metric.** Required (TARGET-UNIMPLEMENTED): backup age and last-verified-restore
age, per store (M10 review).

**Visible state.** After a restore: inboxes empty, idempotency window reset, duplicate
executions.

**Containment.** A durable backend is a deployment requirement (§2); the memory backend's
data loss on restart is a negative control, not production readiness (M10 review).

**Owner.** The Crier store owner, with M8 owning the cross-store backup boundary.

**Retry / recovery.** Follow the restore procedure for the configured backend; verify by
restored-delivery checks, not by daemon liveness. The supported backup profile is
`schema: cf.backup.v1`: a scheduler/Crier durable backend, the per-project board and
events, evidence objects, configuration generations, and pending Git-backed memory
entries are captured only after writers checkpoint at one consistency marker. The
manifest records `backup_id`, source repository/ref commits, board revision, custody
transaction boundary, memory commit, marker time, destination, artifact digests,
retention, encryption-key reference, revocation snapshot and excluded/loss windows.
RPO/RTO and schedule are declared per store; a target policy may be daily with a
24-hour RPO and 4-hour RTO, but an unsupported deployment must state its actual bound.
A board-drift comparison is validation evidence, not a backup creator or checkpoint.

Capture fails closed if any store cannot checkpoint or if a digest/readback fails; the
backup is `CAPTURE_FAILED` and is not published. Validation re-hashes every artifact,
checks the marker and source revisions, and records `VALIDATED` separately from
`CREATED`. Restore runs in an isolated project scope, verifies key and revocation
metadata before admission, reconciles claim/fence/custody/memory identities, and
returns `RESTORE_RESULT` with restored revisions, actual loss per store, duplicate
suppression and readiness status. Pending unsynchronized entries are reported as loss
or pending-sync, never reconstructed from partial history. A revocation remains
revoked after restore; no work resumes until stale owners are fenced and readiness
passes.

**Proof.** A restore-drill record naming the store revision, snapshot and verification
result, with an isolated mid-round case covering a pending memory entry and an
acknowledged Crier message. Contracts: CT-02, CT-03 (PROVEN on the transport — the
store is outside their measured sides).

## 22. Upgrade drift

**What fails.** Pins exist so drift is measurable: `GITREINS_PIN` 0.17.1, `HERMES_PIN`
0.19.0, `CF_CODEX_PIN`, `CLAUDE_CODE_PIN`, `NODE_PIN`, `GO_PIN` (Part V rows). A deployed
version that drifts from its pin is an unmeasured build serving production; a config
drift (`bunker_config_gen.py --check`) is the same defect in settings form. The review
requires reconcile between configured installer pins, current upstream upgrades and
deployed versions (M3 review) and continuous version/config-drift metrics (M5 review).

**Affected invariant.** Every deployed binary and config matches a named pin, and every
pin change is a deliberate recorded act.

**Detection / metric.** Required (TARGET-UNIMPLEMENTED): version/config drift counters and
conformance-leg age (M5 review). Today: installer version checks
(`bad "gitreins" "version … != pin"`) and `--check` runs only at install or on demand.

**Visible state.** An installer FAIL row; a node whose binary is newer than the pin;
`node_freshness` reporting a checkout behind its ref.

**Containment.** Refusal on mismatch at install; `--check` modes are read-only drift
probes.

**Owner.** Harness lifecycle (M5) owns the harness pins; M3 owns the gitreins pin; M1 owns
node image pins.

**Retry / recovery.** Re-run the installer `--apply` to re-pin; an intentional upgrade is a
pin change with its digest re-pinned, never silent drift.

**Proof.** A recorded `--check` exit 0 at the pinned version, dated. Contract: CT-17
(UNVERIFIED — the conformance leg that would grade harness claims was not run, CF-328).

## 23. Bunker protections, qualified by effective profile

Bunker provides baseline protection for normal operation independently of Terminal Jail
(user decision, handoff §1.3), but its guarantees are path-dependent: the host-user, fresh
image-backed, persistent-container and detached-unit paths differ in default capabilities
and provisioning prerequisites (handoff §4). Egress defaults open, network defaults
shared, and disk size is per-file, not an aggregate quota — "Bunker limits disk" is false
until the profile says otherwise. Every claim of Bunker containment in this part (§4
process kills, §5 directive filtering, §6 admission) therefore reads *Bunker contains X
under the effective profile, proven by readback* — never bare *Bunker contains X*.
Deployment mode/profile and live conformance remain to be verified; source availability
does not close that question (handoff §1.3). Terminal Jail is optional and disabled by
default; when enabled, Hermes execution uses the guarded path with no unguarded fallback —
and observer-plugin presence alone proves no enforcement (M8 review).

## 25. Divergent desired and effective configuration generations

**What fails.** The management layer's desired state advances a generation, but the
effective state of a participating system never reaches it: an adapter change failed, a
node was unreachable during propagation, or the observed inventory recorded a readback
that was stale on arrival. The system then runs on an old generation while reporting the
new one — divergent generations, the configuration form of R-01.

**Affected invariant.** Every scope's effective state carries the generation it was
reconciled from; desired, observed and effective agree or the divergence is visible.

**Detection / metric.** Required (TARGET-UNIMPLEMENTED): per-scope
`config_generation{desired, effective}` gauges and a divergence counter, collected by the
manager's readback (V.6 step 7). Today: no manager exists; per-system drift probes
(`bunker_config_gen.py --check`, M1 §5) are the partial predecessor.

**Visible state.** A Bunker serving settings from generation N-1 while the store holds
generation N; a diff/plan that reports no changes against an out-of-date observation.

**Containment.** Generation compare-and-swap on every update (V.6 step 5); a generation
whose reconciliation is incomplete is degraded, never silently current.

**Owner / repair.** The management service owns reconciliation; repair is the scoped
re-apply of the lagging adapter (recovery chain step 4, automatic), with rollback or
forward repair per F13 on a failed apply.

**Recoverability limit / residual exposure.** A scope whose effective readback is RED
(V.3 card 2) cannot prove which generation it serves — the divergence is detectable only
on the surfaces that have readback.

**Verification case.** Apply generation N to a two-Bunker scope with one node drained;
assert the divergence is reported, the drained node converges after rejoin, and no
surface reports converged until readback agrees.

## 26. Partial propagation of configuration

**What fails.** A configuration change reaches some participants and not others: the
per-node acknowledgements of V.6 step 6 are incomplete, and no operator looks. Distinct
from R-25 — there the store and a node disagree about generations; here the change is
half-applied with no generation tracking to even name it.

**Affected invariant.** A configuration change is all-or-recorded: every participant
acknowledges, and the unacknowledged set is visible.

**Detection / metric.** Required (TARGET-UNIMPLEMENTED): `config_propagation_pending`
gauge with per-node acknowledgement ages. Today: nothing counts propagation.

**Visible state.** Two Bunkers in one project running different mount or memory
configurations; a retry loop that stops on the first success.

**Containment.** Idempotent adapter applies with retry/backoff (V.6 step 6); a node that
did not acknowledge is degraded, not converged.

**Owner / repair.** The management service; scoped repair is re-apply to the
unacknowledged nodes only.

**Verification case.** Drop one node's acknowledgement during a settings apply; assert
the scope reports degraded, the retry converges it, and the audit event names both
attempts.

> CAUTION: re-running a destructive adapter step against an already-converged node to
> "make propagation even" violates idempotency expectations — re-apply must be the
> idempotent declared apply, never a manual replay of side effects.

## 27. Stale dual ownership — the partitioned old host

**What fails.** A Bunker host is partitioned, presumed lost, and replaced (F2/F8). The
old host was not dead: it keeps running its foreman, holding claims and answering Crier
on a stale route. Two owners now act for one project identity — the failure the fencing
rule exists for. Unreachability did not prove termination, and replay by the replacement
is not automatically safe.

**Affected invariant.** One active owner per project/Bunker identity at a time,
enforced by lease and fencing, not by reachability assumptions.

**Detection / metric.** Required (TARGET-UNIMPLEMENTED): dual-ownership detector — two
live claimants for one identity within a lease window; lease-expiry vs heartbeat metrics.
Today: nothing fences at the Factory level.

**Visible state.** Both old and new Bunkers writing the board; a claim honored on two
hosts; duplicate workers on one task.

**Containment.** Explicit active-owner/lease semantics: the replacement acquires the
lease, the old holder's writes are fenced by identity (claim/lease tokens carried on
board writes and Crier registration), and a partitioned host whose lease expired is
refused on reconnect rather than re-admitted silently.

**Owner / repair.** The management service owns the lease and fencing decision;
operator-invoked quarantine of the partitioned host if it cannot be reached to drain.

**Recoverability limit / residual exposure.** A partitioned host holding unsynchronized
local memory may lose the unsynchronized portion on quarantine (R-30's loss limit).

**Verification case.** Partition a Bunker mid-round, replace it, heal the partition;
assert the old host's post-partition writes are refused by fence check and the audit log
names both identities.

## 28. Failed Crier/scheduler rebind after replacement

**What fails.** A replacement Bunker is provisioned and ready (F2), but the rebind
fails or is incomplete: Crier registration not updated, scheduler target still pointing
at the old endpoint, or the two views disagree. A later foreman round is delivered to a
dead route or never delivered — readiness without reachability.

**Affected invariant.** Crier routing and scheduler knowledge are updated as one
coordinated step, verified together before admission resumes.

**Detection / metric.** Required (TARGET-UNIMPLEMENTED): rebind-success counter and a
binding-consistency check across both views (V2-ARCH-01's "verification of both
controller views"). Today: none — F8's binding update is target behavior.

**Visible state.** A ready Bunker that receives no rounds; delivery timeouts to a stale
endpoint; the scheduler showing readiness the bus cannot reach.

**Containment.** F2's step 6 — confirm matching identity/readiness before enabling
admission; the consistency check is the negative control that keeps a half-rebind from
admitting.

**Owner / repair.** The management service owns the coordinated update; scoped repair
re-runs registration and scheduler update, then readback (recovery chain steps 4–6).

**Verification case.** Break the scheduler half of a rebind; assert admission stays
disabled, the inconsistency is named by both views, and the repair re-enables only after
readback agrees.

## 29. Round worker-budget exhaustion or silent reset

**What fails.** Two opposite failures of the round budget (V2-Q-02): exhaustion without
a named stop reason — the round ends with spent allowance and unreported remaining work —
or a silent reset, where a wave boundary, retry or crash recovery replenishes an
allowance that should stay consumed, and the round regains workers it no longer owns.

**Affected invariant.** The total-worker allowance is fixed at round admission,
monotonically consumed across waves, and never replenished — not by a new wave, not by a
retry, not by a restart.

**Detection / metric.** Required (TARGET-UNIMPLEMENTED): `worker_budget{round, used,
remaining}` observable per round and per wave (Part I §6; VII §14's budget metric);
a replenishment is a counted anomaly. Today: no budget accounting exists in the measured
scheduler/foreman surfaces.

**Visible state.** A round report missing budget use; waves totalling more workers than
the allowance; a crash-resumed round with its full allowance back.

**Containment.** Durable reservation/consumption/release accounting (VII §16): the
allowance is recorded before the first wave and updated before each next wave; crash
recovery reads the ledger, never re-derives it.

**Owner / repair.** The foreman owns allocation within the round; the scheduler owns
admission and the allowance grant; repair after a silent reset is to fence the round
(R-27) and re-account from the durable ledger — never to "top up" silently.

**Verification case.** Run a round whose waves sum past a mis-set allowance; assert
admission refuses; crash a round after two waves and assert the resumed round reports the
consumed remainder, not the full grant.

## 30. Local memory loss versus HTTP outage — distinct classes

> CAUTION: treating these two as one failure mode produces both false alarms (an outage
> declared as data loss) and silent loss (data loss excused as an outage).

**What fails.** Two different things, and conflating them is itself a defect. An **HTTP
outage** is the DuckBrain service path being unavailable while the local Git-backed
namespace repositories remain intact and usable — queries and supported local persistence
continue against the same namespace/data root (V2-Q-04), with synchronization pending.
**Local memory loss** is damage to the namespace data itself — a lost host, a corrupted
store, an unsynchronized Bunker destroyed before sync. The first is a transport state;
the second is unrecoverable loss of the unsynchronized portion.

**Affected invariant.** Memory unavailability never implies memory loss; local
persistence, Git commit and remote synchronization remain distinct acknowledgement
states (V2-FLW-05).

**Detection / metric.** Required (TARGET-UNIMPLEMENTED): distinct counters —
`memory_http_unavailable`, `memory_pending_sync`, `memory_local_write_failures` — plus
sync freshness per namespace. Today: a board note when DuckBrain is down (which is not a
memory write, VII §14) and nothing else.

**Visible state.** A foreman continuing to work with pending-sync entries during an
outage (correct); a lost Bunker whose worker entries existed nowhere else (loss).

**Containment.** On outage: continue useful work; durable pending entries at every
required worker/wave/round level; local persistence as the durable record. On loss: the
unsynchronized portion is unrecoverable — say so in the recovery record rather than
reconstructing it from scheduler notes and Git history, which retain only parts of the
trail.

**Owner / repair.** The foreman owns pending-entry durability; the sync owner (V.9
Memory.sync_owner, default factory-memory-sync) owns reconciliation; repair after HTTP recovery is the scheduled
synchronization with conflict handling (R-31).

**Recoverability limit / residual exposure.** An unsynchronized host lost takes its
unsynchronized entries with it; that limit is stated in every backup/restore claim
(F15).

**Verification case.** Stop the DuckBrain HTTP service mid-round; assert local
persistence succeeds, pending sync is reported, and the round continues; then destroy the
namespace store and assert the recovery record names the lost unsynchronized entries
instead of claiming restoration.

## 31. Memory synchronization conflicts

**What fails.** The controller and Bunker copies of a project namespace accept
divergent writes while disconnected (R-30's outage path), and on reconnect the
synchronization must merge them. The supported profile uses explicit record identity and a Git-backed namespace merge;
same-id/different-digest records are conflicts, never last-writer-wins. Independent
record ids are retained once each, so a conflict cannot silently drop one side or
duplicate a replay.

**Affected invariant.** Synchronization has a declared owner, merge/conflict rule and
duplicate handling; freshness is visible to subsequent readers (F3 step 6).

**Detection / metric.** Required target metrics are `memory_sync_conflicts_total`,
`memory_sync_duplicates_total` and `memory_view_freshness_seconds`, with bounded
project/namespace and outcome labels. A same-id/different-digest conflict is visible
and cannot be counted as a successful merge.

**Visible state.** A worker entry present on the controller copy and absent on the
Bunker copy is `MEMORY_VIEW_STALE`; the same entry twice is `memory_sync_duplicates`.

**Containment.** A remote copy is a cache until its commit is acknowledged by the
sync owner; the local Git-backed namespace remains the durable record. During an HTTP
outage, local writes continue and are marked `pending-sync`; a namespace that cannot
provide a shared view is refused for multi-host use.

**Owner / repair.** The project foreman owns pending local records; the sync owner
performs the authenticated namespace merge and explicit conflict resolution. Replays
are deduplicated by record id and digest; conflicts remain retained evidence until
resolved, and freshness is read back after the resulting commit.

**Verification case.** Diverge two copies by one worker entry each, synchronize, and
assert both entries survive once each with correlation intact; repeat one id with a
changed digest and assert `MEMORY_CONFLICT` without overwrite.

## 32. Unavailable verifier or model

**What fails.** The independent acceptance judge, the GitReins guard, or the model
behind a worker is unreachable — work stalls at verification, not at execution. Two
wrong responses: grading the work anyway (a verdict without its verifier — the R-01
family in a new coat), or declaring the *work* failed when the *verifier* failed.

**Affected invariant.** Verification is a named dependency: an unavailable verifier
makes outcomes **unknown**, never pass and never silently failed.

**Detection / metric.** Required (TARGET-UNIMPLEMENTED): `verifier_unavailable_total`
and verdict-latency per verifier, with the F9 degraded-mode classification. Today:
MISSING seats from a timed-out judge session (VII §6) are the only measured signal.

**Visible state.** Rows held ungraded with live workers; a round report claiming
completion with no verdicts; a proxy outage surfacing as "worker failure".

**Containment.** F9's classification: record the selected degraded mode, defer verdict-
dependent closure, preserve partial work and evidence with stable identities; a
verification outage does not fail the underlying execution record.

**Owner / repair.** The scheduler owns degraded-mode policy; gitreins owns the grade;
the proxy owner owns model availability (R-18/R-19). Repair is verifier recovery, then
re-grade — never inference of a verdict (VI §14's rule).

**Verification case.** Stop the judge mid-round; assert outcomes record `unknown`,
closure verbs refuse, and the resumed round re-grades rather than accepting the gap.

## 33. Resource pressure and unsafe cleanup ordering

**What fails.** Disk or memory pressure on a Bunker triggers cleanup before ownership
and evidence checks run: the reaper takes a directory a module cites as evidence (R-10),
a live worker's checkout, or pending memory sync data (R-30) — pressure converts into
silent loss. The unsafe ordering is the defect: protection after selection.

**Affected invariant.** Cleanup resolves live ownership, protected paths, evidence
retention and pending synchronization *before* selecting destructive actions (F6 step 2).

**Detection / metric.** Required (TARGET-UNIMPLEMENTED): pressure gauges per Bunker with
cleanup-refusal counters. Today: `disk_floor` admission rows and the hygiene footprint
measured at admission only (M1 §5) — nothing watches mid-round pressure.

**Visible state.** A cited evidence dir gone after a pressure-driven reap; a worker
killed by an OOM while its claim stays held; pending-sync data deleted with its host.

**Containment.** The measured refusals hold: `PROTECTED` paths refused before
inspection, `--dry-run` projected bytes, `reap --registry` required (M8 §5). The target
adds the ordering rule: pressure escalates through events/metrics (V2-OPS-02) and the
F6 sequence, never through an unordered local sweep.

**Owner / repair.** The safety owner (M8) owns cleanup authority; the management
service owns pressure observation; repair of an unsafe cleanup is the R-10 recovery
(a reaped evidence directory is unrecoverable — prevention is the only real fix).

**Verification case.** Fill a Bunker past its floor mid-round with a protected evidence
dir present; assert the cleanup refuses protected paths, reports the pressure, and no
cited directory disappears.

## 34. Durable recovery accounting and fencing (P3-08)

**What fails.** A round can reserve capacity, launch a worker, lose the acknowledgement, publish a result or replace a Bunker between two durable writes. Without one ledger for round, wave, worker and attempt identities, a retry can double-debit the total-worker allowance, publish twice or let a partitioned owner write after replacement.

**Normative contract.** M9.17 is the authoritative typed ledger and transaction model;
its worker state reserved/charged/refunded replaces the former independent boolean
flags. The supervisor preallocates launch_id and native identity as M11.16 specifies.
Resource writes use VI.35.2's serialized authority/broker effect protocol, not a
check-then-write fence test. Each attempt, result, projection, outbox and event retains
its exact identity and digest; the round allowance never resets on recovery.

**Crash-point recovery.** Intent without start is released or retried by idempotency key. Start without acknowledgement is reconciled against native identity before any retry. Publication without record is adopted by digest and recorded once. A replacement acquires a new generation and fences the old owner; lease expiry alone is not sufficient. A late result is evidence only when its generation is stale. Recovery states are `RESERVED`, `START_UNKNOWN`, `RUNNING`, `RECONCILE_REQUIRED`, `PUBLISHED_UNRECORDED`, `FENCED` and `SETTLED`.

**Signal and proof.** The ledger exposes reservation, charge, refund, fence and reconciliation events with bounded metrics. A verification case crashes at each boundary and partitions the old owner; it proves one active owner, no silent budget reset or double debit, and no duplicate accepted publication. This is target behavior until the selected manager/foreman implementation supplies the cited durable store.

## 35. Backup, restore and recovery boundary (P3-20, P3-22)

**What fails.** Independent copies of configuration, board/events, evidence, scheduler/Crier custody and local pending memory can restore to mutually inconsistent states. A backup-created artifact is not a validated backup, and a restore drill is not proved by service liveness.

**Normative contract.** A backup manifest is `schema: cf.backup.v1` with `backup_id`, source revisions, consistency marker, capture time, destination, artifact digests, included stores, excluded/loss windows, retention, encryption-key reference and revocation snapshot. Capture drains or checkpoints writers, records the board/git revision, scheduler transaction boundary, Crier custody boundary, evidence manifest and pending memory entries, then validates every artifact digest before off-host publication. Secrets are references, not plaintext; key recovery and revocation state are included.

Restore occurs in an isolated scope: restore artifacts, verify manifests and key/revocation state, reconcile board/claims/custody/memory identities, fence stale owners, then run readiness and admission checks. A missing unsynchronized entry is reported at the actual recovery boundary and is never reconstructed from partial scheduler or Git history. Recovery objectives state RPO/RTO per store and name unsupported windows.

**Signal and proof.** Metrics expose backup age, validation failures, last successful restore drill and per-store recovery lag. A restore case loses the controller or Bunker mid-round and verifies the round/task/claim/budget/custody/memory view without resurrecting acknowledged work or revoked credentials. Until this drill is run on the selected deployment, the recovery state remains `UNVERIFIED`.

### 35.1 One coordinated-cut lifecycle and manifest (P5-C-26; P6-06; SC-08)

Backup is a manager operation with one authority-owned barrier and one manifest. The closed
state relation is `REQUESTED → FROZEN → CAPTURED → VALIDATED → PUBLISHED → RELEASED`;
`REQUESTED|FROZEN|CAPTURED|VALIDATED|PUBLISHED → ABORTED` is the failure relation, and
`FROZEN|CAPTURED|VALIDATED → INCOMPLETE` is available only under an explicitly selected
partial-offline policy. `PUBLISHED` means the encrypted archive and manifest have been
uploaded and read back off-host. `RELEASED` means every participant has acknowledged the
release after that readback. `ABORTED` and `INCOMPLETE` can never transition to a complete
or published state, and a replay with changed state/digest is `BACKUP_CONFLICT`.

The manager closes new admissions, asks supervisors to quiesce rounds, and creates
`{backup_id,barrier_seq,authority_id,config_generation,operation_id,idempotency_key}`.
The authority issues a 300-second barrier lease, renewable every 60 seconds by the same
coordinator identity through `POST /v1/backups/{backup_id}/renew`. Every registered writer
acknowledges `{backup_id,barrier_seq,store_id,last_transaction,root_digest,capture_ref}`
only after draining writes and fsync. The barrier prevents new broker effects, claims,
custody transitions and canonical memory merges; disconnected Bunkers cannot publish.
Renewal carries the current barrier sequence and manifest pre-digest, not a new backup ID.

Capture, local validation and off-host publication are three distinct commit points:

1. `CAPTURED`: every required store has an immutable local snapshot and acknowledgement.
   Writers remain frozen; local capture is not permission to release.
2. `VALIDATED`: native readers, hashes, object closure and watermarks pass and the signed
   manifest is immutable. Writers remain frozen while upload/readback proceeds.
3. `PUBLISHED`: conditional-create upload finishes and an independent off-host readback
   returns the same manifest and artifact digests. Only now does the coordinator call
   `POST /v1/backups/{backup_id}/release`; each writer resumes on the same barrier release
   receipt and returns a final acknowledgement, producing `RELEASED`.

The overall backup deadline is Part V's 3600-second default. Coordinator restart first
reads `GET /v1/backups/{backup_id}` and resumes the recorded stage with the same identity.
If the barrier remains valid, it renews and continues. If a participant cannot be contacted,
the upload fails, the deadline passes, or the 300-second lease expires without renewal,
the authority marks the operation `ABORTED` and issues an abort release that unfreezes
writers. The 301-second unrenewed case therefore aborts and unfreezes exactly once; it
cannot later become `PUBLISHED`. Upload outage may be retried under the same backup ID
while the coordinator keeps the barrier alive, but never beyond the overall deadline.
A missing Bunker under default `offline_policy=refuse` aborts the complete cut. Under the
owner-selected `partial` option it produces `INCOMPLETE`, names the loss window, unfreezes
reachable writers after local validation, and cannot certify project readiness or a full
restore.

|| Required store | Frozen capture / validation |
||---|---|
|| manager config, operations, bindings, effect receipts | committed JSONL segments and durable commit markers; replay through recorded sequence, validate row digests and active generation |
|| canonical code, board, events and memory Git refs | `git bundle create` of every declared managed ref while fenced; `git bundle verify`; restore into an empty bare repository and compare every ref OID and object closure |
|| scheduler SQLite and local Crier SQLite | writer checkpoint `PRAGMA wal_checkpoint(FULL)` then SQLite backup API; `PRAGMA integrity_check=ok`, empty foreign-key check, and transaction watermark equal to acknowledgement |
|| PostgreSQL Crier | custody writers paused; `pg_dump --format=custom` under one repeatable-read snapshot; isolated restore, constraints, custody/lease/outbox counts and digests equal to acknowledgement |
|| evidence/artifacts and supervisor result spools | immutable digest-addressed objects, manifests and active holds; every referenced object hashed; a missing object fails validation |
|| each Bunker pending memory/local journal | supervisor freezes the local writer and bundles all pending branches and launch/result ledgers; absence is an explicit exclusion, never an empty store |
|| independent authority | signed checkpoint reference only; backup never replaces the live epoch/revocation store |

The canonical `cf.backup.v1` manifest is a closed object with these required members:
`schema_version`, `backup_id:ID`, `operation_id:ID`, `barrier_seq:PosInt`,
`authority_id:ID`, `authority_checkpoint_digest:SHA`, `config_generation:PosInt`,
`consistency_marker:{authority_seq:PosInt,writer_watermarks:[{store_id,last_transaction,root_digest}]}`,
`captured_at:Time`, `validated_at:Time|null`, `published_at:Time|null`,
`released_at:Time|null`, `destination_ref:ID`, `key_ref:SecretRef`,
`stores:Store[1..1024]`, `inventory:Artifact[1..1048576]`,
`exclusions:Exclusion[]`, `retention_until:Time`, `rpo_s:PosInt`, `rto_s:PosInt`,
`revocation_snapshot_ref:EvidenceRef`, `state:REQUESTED|FROZEN|CAPTURED|VALIDATED|PUBLISHED|RELEASED|ABORTED|INCOMPLETE`,
`offhost_readback_ref:EvidenceRef|null`, `release_receipts:ReleaseReceipt[]`,
`manifest_digest:SHA`, and `signature:Base64url64`. Nullable timestamps and off-host ref
are null until their named commit point. `PUBLISHED` requires nonnull published time and
readback ref; `RELEASED` additionally requires every writer's release receipt.

Store is `{store_id:ID,kind:jsonl|git|sqlite|postgres|objects|local-journal,
source_revision:Text,last_transaction:Text,artifact_path:relative-path,sha256:SHA,
bytes:UInt,root_digest:SHA,validated:boolean}`. Artifact is `{path:relative-path,
sha256:SHA,bytes:UInt,store_id:ID}` and inventory is sorted by path bytes with unique
paths. Exclusion is `{store_id:ID,reason:ErrorCode,last_synced_at:Time|null,
loss_start:Time|null,loss_end:Time|null}`; null time means unknown loss, never zero loss.
ReleaseReceipt is `{store_id,barrier_seq,state:released|aborted,receipt_digest:SHA,
acknowledged_at:Time}`. `manifest_digest` hashes RFC8785 JSON of the complete object
excluding only `manifest_digest` and `signature`; the offline-enrolled backup signer signs
`CF2A-BACKUP-1\n` plus that digest's lowercase hex bytes. Unknown keys, a missing store,
changed bytes or invalid state/refusal combination is `BACKUP_MANIFEST_INVALID`.

The archive uses authenticated encryption to the backup public-key recipient; the recovery
private key remains with the offline custodian. Secret-free archives contain credential
references and revocation metadata, never credential values. Publication uses a unique
backup-ID object, conditional create, then remote hash readback and a signature/schema
validation receipt. Partial uploads are not listed as validated backups. Defaults are
hourly capture, 30-day retention, RPO 3600 seconds, RTO 7200 seconds and overall deadline
3600 seconds. Destination and key remain required owner inputs. Retention deletes only
validated expired generations with no hold and always retains the latest validated
generation.

DECISION SLOT C-BACKUP offers `refuse` (the fail-closed default) or `partial`; no silent
partial capture is permitted. Restore decrypts in an isolated network, verifies signature,
hashes, schema, object closure and store watermarks, restores with native readers,
reconciles identities, then executes §35.2 before enabling credentials, writes or dispatch.
A timed restore drill reports actual per-store loss/recovery time; declared objectives are
not measured results. Current-authority revocation preservation and revoke-all recovery
remain mandatory. Shared SC-08 vectors cover coordinator loss at every stage, the
301-second pause, upload outage, missing Bunker, corrupt snapshot and post-revocation
restore; no local artifact or service-liveness claim substitutes for that drill.

### 35.2 Non-rollback authority and resource enforcement (P5-C-17/27)

The independent operator-owned authority in Part I §1.9.3 lives outside the manager
backup/failure domain. Its durable monotonic sequence covers authority_id, project
epoch/owner, credential revocations and enrolled principal serials. A restore never
imports older authority records. It obtains an authenticated live checkpoint and
requires its sequence >= the backup checkpoint under the SAME authority_id; each
project receives a newly advanced epoch before any restored writer is enabled.
All restored token/capability material is disabled, reissued against that epoch, and
old provider credentials are revoked or observed expired. Authority outages refuse
restore activation. A missing/replaced authority cannot be treated as sequence zero.

DECISION SLOT C-LOST-AUTHORITY permits only default REFUSE, or operator-authorized
revoke-all/new-authority recovery: fence network access, revoke all forge App/project
credentials and proxy/admin tokens at their issuers, prove old credential denial and
quiescence of old broker executions, create a new random authority_id and keys,
re-enroll every resource and issue new credentials. Old authority IDs are permanently
denied by resources. A provider that cannot confirm revocation/expiry keeps recovery
blocked. No backup-local watermark can prove later revocations; that shortcut is
explicitly forbidden. [M7.16; M12.16; F12/F15]

Resource mutations use one effect protocol, not caller-side check-then-write. The
broker submits `(effect_id, resource_ref, input_digest, owner_fence)` to the authority;
begin validates owner/lease and inserts an in-flight intent atomically with epoch
serialization. Only a begin receipt permits downstream mutation. Advance/revoke waits
for ALL earlier in-flight effects to finish/read back or for credential denial AND
old executor quiescence; an unknown effect blocks replacement indefinitely and emits
EFFECT_UNRESOLVED. Therefore a write accepted before replacement may finish before
replacement is declared, but cannot race after its completion. New effects from a
partitioned former owner fail STALE_OWNER or AUTHORITY_UNAVAILABLE without mutation.

| Resource | Actual effect and atomic resource boundary |
|---|---|
| Git branch/main publication | only broker holds write token; receives object bundle, expected remote OID, target OID and evidence; performs provider compare-and-swap ref update or Git push with explicit expected OID, reads remote OID, finishes effect. Protected refs deny all non-broker identities. A provider lacking enforceable sole-writer/ref-CAS support is unsupported |
| Board | broker constructs row/event/claim blobs in one candidate Git tree and publishes its canonical ref with expected old OID under M4 transaction. Concurrent CAS loser returns CLAIM_CONFLICT; stale Fence returns STALE_OWNER. Staging failure retains operation receipt and marks board UNAVAILABLE until repair |
| Memory | sync owner submits canonical namespace tree and expected OID through broker; canonical ref is CAS-published only under current Fence. Bunker local commits are drafts, not authorized remote writes; old drafts are quarantined and may be adopted only by a current-owner reviewed resolution |
| Crier binding/custody write | Crier service begins effect as an enrolled broker delegate, then commits binding generation, consumed grant, custody record and effect ID in one native store transaction. Same effect ID/digest replays; mismatch refuses. It finishes after durable readback; an unavailable authority denies mutation, not a cached allow |

The effect receipt itself is not an offline reusable capability: only its enrolled
broker executor can finish it, and its completed effect ID is deduplicated forever
within the retained resource history. Authority recovery never drops an unresolved
intent. API ACLs, read-only Bunker credentials and protected resource refs prevent
bypass; direct human writes are UNMANAGED_WRITER and invalidate readiness. Tests must
partition an old owner, advance only after effect resolution, then attempt all four
writes with old credentials/Fence; every canonical OID/row digest remains unchanged.
These are required target tests, not executed conformance claims.

## 36. Risk summary — prioritized, with the review's mapping

The classes are ordered by consequence, not by uncited-line counts: a class that can close
work that never happened, spend after death, or lose custody outranks one that only
delays or degrades. The mapping columns are the review's: affected invariant, detection
metric, visible state, containment, owner, retry/recovery, proof — split across two
tables to hold the page.

| Pri | Class | Affected invariant | Detection / metric | Visible state |
|---|---|---|---|---|
| 1 | Silent success (§1) | no execution settles as success without a verdict | settlement outcomes incl. `unknown` (TARGET) | a failed reply closes a row |
| 2 | Untrusted directive reaches a node (§5) | no untrusted prompt executes on a node | guard verdicts, `crier_guard_saturated_total` | `errored`-flagged allows |
| 3 | Provisioning admits what it must refuse (§6) | admission refuses tampered and under-floor inputs | admission FAIL rows (measured); conformance legs (TARGET) | PASS rows that never probed |
| 4 | Custody lost on restart (§2) | durable custody across restarts | backend readback (RED) | empty inboxes after restart |
| 5 | Custody lost on crash (§3, §16) | recorded-before-ack; durable intent before start | `uncertain_starts`, replay counters (TARGET) | duplicate execution |
| 6 | Deadline kill misses children (§4) | a killed job stops spending | quiescence latency, survivors (TARGET) | tokens spent after kill |
| 7 | Credential exposed / expired / over-scoped (§7, §17) | credentials unexpired, minimal, revocable | expiry headroom, refused scopes (TARGET) | auth failures mid-landing |
| 8 | Work lands without proof (§8) | publication carries gate and evidence proof | landing proof rows (measured) | ungraded diff on main |
| 9 | Stale boards and claims (§13) | eligibility on the canonical revision | work age, drift (TARGET) | work on closed rows |
| 10 | Unknown verdicts (§14) | every run settles to a named outcome | settlement `unknown` class (TARGET) | rows past deadline |
| 11 | Failed publication / projections (§15) | published work reaches every record sink | per-sink projection counters (TARGET) | landed commit, open row |
| 12 | Control plane exposed by binding (§9) | daemons bind to their intended surface | admission legs (measured) | API off-host |
| 13 | Wrong served route / truncation (§18) | served equals requested, complete or error | mismatch, partial classes (TARGET) | silent model substitution |
| 14 | Proxy streaming completion (§19) | completion framing proved on the path | per-stream outcomes (TARGET) | truncated "success" |
| 15 | Evidence destroyed or never written (§10) | retained evidence outlives reaping | reap/refusal counters (measured) | cited dir vanishes |
| 16 | The record that lies (§11) | registers point at real files, real states | spine/doc gates (measured) | invented sink paths |
| 17 | Shared-memory consistency (§20) | one logical memory view | freshness, pending-sync and conflict counters (TARGET) | divergent namespaces |
| 18 | Restore (§21) | custody survives host loss | backup/restore ages (TARGET) | duplicates after restore |
| 19 | Upgrade drift (§22) | deployed equals pinned | drift counters (TARGET) | unmeasured build serving |
| 20 | Unproven wires (§12) | every guarantee cited on both sides | the register itself | RED sides, no signal |

| Pri | Class | Containment | Owner | Retry / recovery | Proof of recovery |
|---|---|---|---|---|---|
| 1 | Silent success | read the reply body, not the verdict bit | scheduler settlement owner | close CF-355 on both halves | reply `status` and `ok` agree on every settlement |
| 2 | Untrusted directive | `FailClosed`, `RequireAgentSig` on | Crier guard owner | re-enable, re-deliver, audit `Result.Patterns` | no unsigned read; policy verdicts recorded |
| 3 | Admission refusals | named fail-before-side-effect refusals | provisioning owner | re-run with correct inputs | refusal rows present where they must fire |
| 4 | Custody on restart | explicit durable backend | Crier store owner | configure, restart, redeliver | restart drill with redelivery |
| 5 | Custody on crash | ack last; redelivery over loss | dispatcher owner | startup reconciliation | ledger keyed by native run id, pre-execution |
| 6 | Surviving children | check survivors after every kill | dispatcher owner | manual group kill | zero survivors after deadline |
| 7 | Credentials | mode checks, `--dry-run`, scoped mint | credential issuer owner | re-mint, explicit revoke | outcome records with scope/expiry |
| 8 | Landing proof | `--gate-cmd`, ancestry proof | landing owner | rebase, re-land | `LANDED:` rows with gate rows |
| 9 | Stale boards | lock ERROR never writes | scheduler + foreman | re-fetch, re-derive | tick names its board revision |
| 10 | Unknown verdicts | typed settlement records | scheduler + judge | re-grade, never infer | verdict with named criteria |
| 11 | Failed projections | evidence-bound closeout verbs | foreman | idempotent re-close, re-project | one event + memory readback per run |
| 12 | Exposed binding | loopback default, auth gates | daemon owners | re-point, add front end | admission legs pass |
| 13 | Route/truncation | allowlists, body ceiling | proxy owner | named failure to client | requested = served in usage log |
| 14 | Streaming | none measured | proxy maintainer | client retry | actual-path conformance evidence |
| 15 | Evidence loss | `PROTECTED` set, dry-run | safety owner | reaper rule fix (CF-368) | cited evidence survives a reap |
| 16 | Lying record | spine comparison, same-commit amend | documentation owner | re-pin locators | register matches disk |
| 17 | Memory consistency | local Git is durable; remote acknowledgement is separate | foreman + sync owner | VII.18.1 deterministic union/conflict resolution | matching index digest across hosts |
| 18 | Restore | durable backend requirement | Crier store owner | restore procedure + drill | restore-drill record |
| 19 | Drift | refuse-on-mismatch install | pin owners | re-apply the pin | dated `--check` exit 0 |
| 20 | Unproven wires | five-state vocabulary, same-commit amend | contract owners | cite both ends | register row leaves UNVERIFIED |

The manager and state-store classes added this wave, on the same columns:

| Pri | Class | Containment | Owner | Retry / recovery | Proof of recovery |
|---|---|---|---|---|---|
| 21 | Divergent config generations (R-25) | generation CAS; incomplete reconciliation is degraded | management service | scoped adapter re-apply, rollback/forward per F13 | desired/effective gauges agree |
| 22 | Partial propagation (R-26) | per-node acks, retry/backoff | management service | re-apply to unacknowledged nodes only | ack set complete, audit names attempts |
| 23 | Stale dual ownership (R-27) | lease + fencing by identity | management service | fence, quarantine, re-account | post-partition writes refused |
| 24 | Failed rebind (R-28) | binding-consistency check before admission | management service | re-run registration + scheduler update | both views agree at readback |
| 25 | Budget exhaustion/reset (R-29) | durable reservation ledger, monotonic spend | foreman + scheduler | fence and re-account from ledger | resumed round reports consumed remainder |
| 26 | Memory loss vs outage (R-30) | distinct ack states; local record durable | foreman + sync owner | sync on recovery; name lost portion | pending-sync converges; loss record honest |
| 27 | Memory sync conflicts (R-31) | preserve all conflicting digests, no last-writer-wins | foreman + sync owner | VII.18.1 explicit resolution record | both diverged entries survive once |
| 28 | Unavailable verifier/model (R-32) | outcomes `unknown`, closure defers | scheduler + gitreins + proxy | verifier recovery, re-grade | re-grade replaces the gap |
| 29 | Pressure/unsafe cleanup (R-33) | protection before selection | safety owner (M8) | prevention (recovery is R-10) | cited evidence survives pressure |
