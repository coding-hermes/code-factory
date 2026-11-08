# Part VI — Failure and risk

One subsection per failure class. Each names what fails, the observable signal,
containment, the recovery command where one exists, and the contract that guards the
wire involved. The classes are built from three sources: the contract register's RED and
UNVERIFIED sides (Part IV), the WARNING-class hazards the chapters carry (off-loopback
binding, memory-lost-on-restart), and each chapter's own "what breaks if it lies" record.

The register counts 23 contracts: 4 PROVEN (CT-02, CT-03, CT-06, CT-08), 1 PARTIAL
(CT-04), 1 BROKEN (CT-10), 1 MISSING (CT-09) and 16 UNVERIFIED. Every UNVERIFIED row
carries at least one RED side — a guarantee no `file:line` in the model states — so a
failure on those wires has no measured early warning. Where no canonical contract covers
a failure, the subsection says so; an unguarded failure is a risk entry, not a hidden one.

## 1. A failed run settles as a pass

**What fails.** The settlement reader `dispatchReplyVerdict`
(`internal/scheduler/dispatch_leg.go:713-726`) reads only `payload["ok"]` and treats the
absence of a verdict as success (`:709-712`). A node reply carrying `status:"failed"` —
the field `node-bus-worker.py:1180` actually sends — and no `ok` is scored a success: the
control-plane half of the silent-success defect, CF-355 open (M9 §11). The node-side
mirror: a worker that replies with a false `ok` records a pass for work that never
happened (M2 §2). The dispatcher leg always sends `ok` (CT-06's measured defect, M11 §6),
so the one settlement wire that works is the one that carries no verdict information.

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

**What fails.** The landing path can publish ungraded and the record can close without
evidence. `land-node-branch.sh` initialises `GATE=""` and `run_gate` returns 0 on an
empty gate (`:74-75`), so a landing with no `--gate-cmd` runs no project gate (F3-3); the
pre-commit hook exits 0 when `.gitreins/config.yaml` is absent (`install-gitreins.sh:
130-131`) — a bypass that is by design but must be disclosed when used (M3 §10). Nothing
in-repo invokes the lander at all (F3-5): the result envelope names `branch` and `commit`
(`node-bus-worker.py:1187-1188`) but does not call it — the landing step is
operator-triggered. On the record side, the node worker writes no board rows — no
in-repo producer exists (CT-10, BROKEN), and a completion without a bound run id is
refused by `boardctl update` (TR-251).

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

**What fails.** The reaper can delete a directory a module cites as evidence: the TTL
governs age, not citation, and the two are conflated — CF-290 and CF-368 open (M8 §2).
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
is unrecoverable — the open exclusion rule (CF-290/368) is the only real fix.

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

**Owner.** The scheduler owns claim exclusivity; the foreman owns refresh-before-work
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

**Proof.** A ledger row keyed by the native run identity, written before execution
(required, not yet implemented). Contract: CT-23 (UNVERIFIED).

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

**Detection / metric.** Undefined — the topology itself is UNRESOLVED (Part V matrix).

**Visible state.** A Bunker foreman reasoning over memory the controller cannot see, or the
reverse.

**Containment.** None specified. Until then, Bunker-local memory reads are treated the way
the board treats a dirty worktree: a cache, never authority (VII §2's rule applied to
memory).

**Owner.** Unresolved — assigned when the topology decision lands (handoff §6, carried).

**Retry / recovery.** Unspecified; the offline/reconnect and replication-conflict behaviors
are named follow-ups, not designed semantics.

**Proof.** Cross-host readback showing the same logical row from both sides (required).
Contract: none — a named gap; CT-09 (MISSING) covers the node-side producer only.

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

**Owner.** The Crier store owner.

**Retry / recovery.** Follow the restore procedure for the configured backend; verify by
restored-delivery checks, not by daemon liveness.

**Proof.** A restore-drill record naming the store revision, snapshot and verification
result. Contracts: CT-02, CT-03 (PROVEN on the transport — the store is outside their
measured sides).

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

## 24. Risk summary — prioritized, with the review's mapping

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
| 17 | Shared-memory consistency (§20) | one logical memory view | undefined — UNRESOLVED | divergent namespaces |
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
| 15 | Evidence loss | `PROTECTED` set, dry-run | safety owner | reaper rule fix (CF-290/368) | cited evidence survives a reap |
| 16 | Lying record | spine comparison, same-commit amend | documentation owner | re-pin locators | register matches disk |
| 17 | Memory consistency | treat local reads as cache | unresolved | unspecified | cross-host readback |
| 18 | Restore | durable backend requirement | Crier store owner | restore procedure + drill | restore-drill record |
| 19 | Drift | refuse-on-mismatch install | pin owners | re-apply the pin | dated `--check` exit 0 |
| 20 | Unproven wires | five-state vocabulary, same-commit amend | contract owners | cite both ends | register row leaves UNVERIFIED |
