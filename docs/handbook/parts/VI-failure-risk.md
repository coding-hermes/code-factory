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

## 13. Risk summary

| # | Failure class | Worst case | Open guard |
|---|---|---|---|
| 1 | Silent success | Work that never happened closes a row and spends the lane's cadence | CF-355 |
| 2 | Custody lost on restart | Every held delivery and inbox vanishes with the daemon | backend selection default; readback RED |
| 3 | Custody lost on crash | A redelivered task executes twice | F11-3, seen-cache warns only |
| 4 | Deadline kill misses children | A killed job keeps spending inference | F11-8 (guarantee withdrawn), `DISPATCH_EXEC_TIMEOUT` inert |
| 5 | Untrusted directive reaches a node | Guard fail-open delivers an untrusted prompt to a node | `FailClosed` opt-in; CF-369 |
| 6 | Provisioning admits what it must refuse | A tampered binary or an under-floor host passes admission | F1-1, B05 |
| 7 | Credential exposed or mode claim lies | A token in argv, a 0644 key accepted by a lying predicate | F0-6, CF-347 |
| 8 | Work lands without proof | An ungraded diff on main; a closeout with no evidence | CT-10 BROKEN; gate off by default |
| 9 | Control plane exposed by binding | The scheduler API reachable off-host | no CT — named gap |
| 10 | Evidence destroyed or never written | The record of a run is unrecoverable | CF-290/368, CT-09, CT-10 |
| 11 | The record that lies | An operator acts on invented paths or re-emitted stamps | F6-2, B6 blind spots |
| 12 | Unproven wires | A failure with no measured signal | 16 UNVERIFIED rows |
