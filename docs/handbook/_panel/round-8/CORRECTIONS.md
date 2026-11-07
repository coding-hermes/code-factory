# CORRECTIONS — round 8

Generated 2026-11-06T19:30:42-0500.

## Verdicts

- **deepseek** — FAIL, blocking 3, 7188 bytes, complete=True
- **glm** — FAIL, blocking 5, 11696 bytes, complete=True
- **grok** — FAIL, blocking 7, 24978 bytes, complete=True
- **kimi** — FAIL, blocking 6, 10516 bytes, complete=True
- **sol** — FAIL, blocking 19, 25380 bytes, complete=True

## Verdict text (verbatim, per seat)

### deepseek

```
I've read the brief, the outline, the schema, all 13 chapters, and the spine script; I ran the spine (0 findings) and re-verified the load-bearing claims against the live code. Verdict below.

```
VERDICT: FAIL
BLOCKING: 3
NON-BLOCKING: 0

FINDINGS:

[1] FALSE CLAIM — M4 — §7 records the board verification as current and green, but
    re-running the chapter's own commands at judge time contradicts it.

    Claim quoted: "drift | ... | 2026-11-06 | PASS — RESULT: OK; tasks.jsonl/events.jsonl
    byte-identical; 357 vs 357 rows, 0 divergent ids; HEAD=226ae37 == origin/main=226ae37"
    and the §1 identity stamp "Revision 226ae37e7... (code-factory HEAD, 2026-11-06)".

    Evidence (measured): `git log -1` = 47d68b4, `git rev-parse origin/main` = 4dc0ef0 —
    the stamp 226ae37 is one commit behind HEAD and two behind origin/main.
    `python3 scripts/board_drift.py check --workdir /home/kara/code-factory --ref origin/main`
    → "RESULT: DRIFT (4 failed)" — "byte parity tasks.jsonl — bytes differ", "byte parity
    events.jsonl — bytes differ", "board rows — 357 vs 357; 1 divergent ids: CF-270
    (workdir=pending published=complete)". The events census is also stale: §12/§13 say
    "515 events" but `boardctl validate` now reports "518 events".

    Fix: restamp every chapter to the current HEAD, re-run board_drift and boardctl validate,
    and either (a) update §7 to the new DRIFT result and file the CF-270 workdir/published
    divergence as a row, or (b) reconcile the working-tree board with origin/main before the
    merge so byte parity holds again. The chapter's own F4-4 warning ("re-run board_drift
    after the merge that carries this chapter") was not honoured before this round was
    presented for judging.

[2] CONTRADICTION — M2 vs M10 — the canonical contract CT-03 ("crier → node — inbox message
    + lease") names a different crier producer function in each owning chapter.

    M2 §6: producer "crier internal/registry/handler.go:990 HandleDeliver (POST /agents/{id}/inbox)"
    M10 §6: producer "handler.go:1690 HandleRetrieve (lease)".

    Evidence (measured): `grep -n 'func (h *Handler) Handle...' internal/registry/handler.go`
    confirms HandleDeliver at :990 and HandleRetrieve at :1690 — two distinct handlers.
    The contract's discriminator is the LEASE, which is granted on retrieve; HandleDeliver is
    the CT-02 consumer (scheduler POSTing the envelope into the inbox), not the crier→node
    read side. M2's producer is the wrong endpoint for this contract; the consumer cells also
    disagree (M2: directive_text :977 vs M10: process :1007).

    Fix: make CT-03's producer HandleRetrieve (:1690) in both chapters (M2 is the one to
    correct), and align the consumer to the same node function. One canonical producer, one
    canonical consumer, cited identically in both owning chapters.

[3] CONTRADICTION — M9 vs M11 — the canonical contract CT-06 ("crier → scheduler — completion
    event") names a different producer function in each owning chapter.

    M9 §6: producer "crier internal/registry/handler.go:1690 HandleRetrieve (the scheduler
    polls its own inbox for the reply)".
    M11 §6: producer "dispatcher.py:500-508 builds {in_reply_to, agent, ok, ...} and
    crier.deliver".

    Evidence (measured): dispatcher.py:500-508 is the reply builder (confirmed
    `sed -n '500,508p' dispatcher.py` emits in_reply_to/agent/ok/reply_b64 + crier.deliver);
    HandleRetrieve at :1690 is the transport/poll side. The two chapters disagree on whether
    the producer of the completion event is the semantic sender (dispatcher) or the transport
    handler (HandleRetrieve).

    Fix: pick one convention for the "producer" column (semantic event producer vs transport
    side) and apply it identically across M9/M11 — or split the row so the event producer and
    the transport hop are named separately, then cite the same pair in both chapters.

DEFECT CLASSES:
- Measured-state staleness (a §7 verification row that no longer reproduces, driven by a
  board that moved and a revision stamp two commits stale)
- Cross-chapter contract-producer disagreement (same canonical CT id, different file:function
  in each owning chapter)
- Spine coverage gap (contributing cause, not a chapter defect): handbook_spine.py's own
  docstring (lines 10-11) promises the two sides of a contract "must name the same
  producer/consumer pair", but the implementation only runs has_fq (lines 115-117), which
  checks that a file:line pattern EXISTS, not that the two chapters AGREE on which function.
  That is why findings [2] and [3] report "findings=0" from the spine yet are real.

CHAPTER SCORECARD:
- M0 PARTIAL — metrics "none" RED; content verified (lib.sh 78 lines, all helpers match).
- M1 PARTIAL — node_env/node_seed_drift/node_freshness/bunker_config_gen bodies not read
  line-by-line; certification ladder not run on a live node; metrics RED.
- M2 PARTIAL — metrics RED; live bus-worker ladder not repeatable from this host; CT-03
  producer disagreement (finding [2]).
- M3 PARTIAL — metrics RED; repo_freshness.py body unread; S2 operator-invoked.
- M4 PARTIAL — metrics RED; CT-13/CT-14 UNVERIFIED; §7 verification now stale (finding [1]).
- M5 PARTIAL — metrics RED; conformance battery not run; M5-C2 state UNVERIFIED.
- M6 PARTIAL — own gate reads FAIL (44 modules / 37 VERIFIED / 50 errors, reproduced); the
  fill/render pipeline does not select M-numbered chapters (self-flagged UNBUILDABLE).
- M7 PARTIAL — metrics RED; mint UNVERIFIED (no App creds); M7-C1 consumer external.
- M8 PARTIAL — metrics RED; dispatcher .cf-jobs not a reap target.
- M9 PARTIAL — 43 routes / 10 LoadRootConfig / 379 log.Printf / 57 flags / 30 tables / no
  verdicts table all reproduced; §9 log inventory 2-of-379 and remaining RED fields as stated;
  CT-06 producer disagreement (finding [3]).
- M10 PARTIAL — port 8767 / 3 slog sites / 91 test files / metrics.go:2 "opt-in" comment all
  reproduced; 1895-line handler body not read line-by-line; guard log surface not tabulated.
- M11 PARTIAL — metrics RED; live-job tests are decoration (no assert); the deadline-kill
  does not reach the harness process group (F11-8, self-flagged and correctly withdrawn).
- M12 PARTIAL — metrics RED; node-client half UNVERIFIED; stream completion UNVERIFIED (F12-7).

No chapter is WRITTEN; none is SKELETON (all 13 carry real, source-cited content). That is
the writer's own honest label and it stands up to spot-verification.

Note on fairness: the code-level citations are unusually accurate. Every mechanical claim I
re-checked reproduced exactly (lib.sh helpers, text_b64 decode and reply shape, the scheduler's
43/10/379/57/30, crier's 8767/3/91/67, master_doc_check 44/37/50, check_scan_scope 15). The
blocking findings are the two contract-register producer disagreements and the board-state
staleness — all of which are exactly the kind of thing the loop is meant to catch, and two of
which the spine currently cannot.

PANEL REVIEW COMPLETE
```

session_id: local-14a9b027930d808b88031ff37f1e69908e908f91f66770666f9ab6338f3ef1ec

EXIT=0
```

### glm

```
All verification is done. The M0 fail-closed probe reproduced (connection refused, no artifact left; the empty rc= in my output is my own shell-quoting artifact, not the chapter's). Full verdict:

════════════════════════════════════════════════════════════════════

VERDICT: FAIL

BLOCKING: 5 — findings that must be fixed before these chapters can be called written
NON-BLOCKING: 5

FINDINGS:

BLOCKING

1. FALSE CLAIM — M3-repository — "land-node-branch.sh (295 lines)" and every locator into it
   are false at the chapter's own stamped revision (226ae37).
   Evidence: `git show 226ae37e:scripts/land-node-branch.sh | wc -l` = 308 (not 295);
   `git log 226ae37e..HEAD -- scripts/land-node-branch.sh` is empty — no drift after stamp.
   Measured at the stamp: `LANDED:` is :304 (cited :291 — :291 is `remote_tip=$(git rev-parse…)`);
   `LAND: FAIL ($FAILED)` is :307 (cited :294); `LAND: DRY-RUN — 0 commands…` is :244 (cited :231);
   `LAND: REFUSED` is :58 (cited :56 — :56 is `bad "$1" "$2"`); refuse-descendant is :202 (cited
   :167, a comment); no_ff_local is :223/:227 (cited :214); `REMOTE/MAIN/GATE=""` defaults are
   :38 (cited :36, which is `. "$HERE/lib.sh"`); `--gate-cmd` is :108 (cited :76, the dry-run
   branch); the push/proof block is :276-292 (cited :265-283). Also "selftest.sh is 4,591
   lines" (measured 4737) and the cf244 arm ":3413-3650" (measured BEGIN :3433 / END :3670).
   The claims' *content* is true — I re-ran the entire battery: `SELFTEST: PASS`, rc 0, landing
   arm green — but the evidence column is wrong at the stamp, which rule 1 makes blocking.
   Fix: re-derive every land-node-branch.sh and selftest.sh locator at the stamped revision
   (or re-stamp at the measured HEAD), and correct the two line-count claims.

2. FALSE CLAIM — M2-dispatch — the settlement-ordering locators point at the wrong code.
   Claim quoted: "Settlement ordering (B10…) node-bus-worker.py:1300-1367: execute (process) →
   deliver each result → write the seen-cache only after delivery succeeds → ack last".
   Evidence: :1300-1367 is the `--check` ladder plus the start of the message loop. The real
   settlement block is :1389-1421 (deliver :1392, `seen[key]` :1394-1395, `save_seen` :1398,
   its OSError warn :1399-1403 — cited ":1352-1354"; ack skip :1407-1414 — cited ":1358-1365").
   The same-batch duplicate loop cited ":1304-1331"/":1341-1347" is actually :1361-1396.
   Settings constants are off by one: DEFAULT_INBOX_LIMIT :80→81, DEFAULT_LEASE_SECONDS
   :81→82, SEEN_LIMIT :84→85, CF_MAX_TURNS :112→113, CF_TIMEOUT_S :113→114. §1 "reply shape
   :1128-1144" is the dry-run "WOULD" rows; the reply dict is :1176-1192 — which M2's own §6
   cites correctly, so the chapter contradicts itself. File is byte-identical 226ae37..HEAD
   (`git diff` empty) — not post-stamp drift. Fix: re-pin the settlement block, the constants,
   and §1 to the measured lines.

3. CONTRADICTION — M3 / M5 / M9 vs M2 (and vs the file) on node-bus-worker.py locators.
   Claim quoted (M3 M3-C2): "node-bus-worker.py:1139-1140 builds branch/commit"; (M9 §2):
   "status:\"failed\" (the field node-bus-worker.py:1132 actually sends)"; (M5 F5-2): "reads
   node.json's harness.cmd/harness.name (node-bus-worker.py:407-409)".
   Evidence: branch/commit are built at :1187-1188; the reply `status` field is :1179 (:1132
   is a dry-run `say`); the harness read is :412-414 (:407-409 is crier-URL handling). M2 §6
   correctly cites the reply envelope at :1176-1192. Four chapters cite one file with
   mutually inconsistent anchors; a reader cannot tell which is right without re-deriving.
   Fix: adopt M2 §6's anchors as canonical and re-derive M3/M5/M9.

4. FALSE CLAIM (count) — M4-board — "events.jsonl (515 lines)" re-measured "2026-11-06 at
   HEAD 226ae37".
   Evidence: `git show 226ae37e:.coding-hermes/board/events.jsonl | wc -l` = 518; working
   tree = 518. The count was false at its own stamp (the 357-tasks figure IS correct).
   Related, not a defect: board_drift now reads `RESULT: DRIFT (4 failed)` with 1 divergent
   id (CF-270) because origin/main moved to 4dc0ef0 — the chapter explicitly predicts this
   and instructs a re-run after merge, so only the 515 is wrong. Fix: re-count, re-stamp.

5. FALSE CLAIM — M10-crier — the Guard settings rows are shifted one line up.
   Evidence (cited → measured in config/config.go): Guard.Enabled :644→645 (:644 is
   `Guard: GuardConfig{`), Timeout :645→646, MaxConcurrent :646→647, CircuitThreshold
   :647→648, CircuitCooldown :648→649, MaxPayloadBytes :649→650, RenderMaxBytes :650→651,
   DeepSeekBaseURL/Model :651-652→652-653, KanbanQueueSize :653→654. All values are correct
   and the Webhook rows (:636-642) are exact, so the shift is confined to the Guard block —
   nine rows of a load-bearing register, each one line off. Fix: shift the nine rows.

NON-BLOCKING

1. CONTRADICTION (disclosed) — OUTLINE Part IV row "node → crier — reply: in_reply_to,
   corr_id, run_id, outcome · broken" carries no supersession annotation while its two
   siblings do. M2 CT-04 measures works (transport) and shows the real reply fields (no
   run_id/outcome exist); M2 §6 flags the row as stale and the README declares the whole
   register stale until Part IV is re-rendered. Fix: annotate the row like its siblings.

2. M1-provisioning — "Five flags were assigned during parsing and then overwritten by
   load_config (:604-608)": six assignments follow (:604-609 — DUCKBRAIN_URL,
   GITHUB_TOKEN_FILE, DUCKBRAIN_TOKEN_FILE, CRIER_AGENT_KEY_FILE, CRIER_AUTH_TOKEN_FILE,
   S3_ENV_FILE). The chapter inherited the code comment's "five" without counting. Fix: six.

3. M12-inference-proxy — grep site "scripts/panel_loop.py:136" is actually :145 (the other
   three sites are exact and the count of four is correct). Fix: re-pin.

4. M5-harness / structural — UNIT-MAP.yaml lists 3 submodules for M5, OUTLINE lists 5
   (F5-4, disclosed in-chapter). Two structure maps disagree; the fix belongs to the maps,
   not the chapter.

5. README — "Chapter completeness | … (round 5)" carries a stale round tag in the round-8
   document. Cosmetic.

DEFECT CLASSES:
LOCATOR-ROT (citations false at the chapter's own stamped revision — the dominant class,
M2/M3/M4/M10/M12); COUNT-DRIFT (counts false at own stamp); OFF-BY-ONE citation families
(M2 constants, M10 Guard block); INTERNAL-CONTRADICTION (chapters disagreeing on the same
file's anchors); DISCLOSED-STALE register rows (outline Part IV, README tags — disclosed,
so non-blocking).

Spine: `python3 scripts/handbook_spine.py` → findings=0 (repeated by me; chapters=13,
canonical contracts=18). That clean result is not evidence against the above: the spine
checks document-internal consistency only (canonical ids, duplicate setting defaults,
dangling M/F refs, document-level totals). It cannot validate file:line targets or
repo-level counts, which is where every blocking defect lives.

Repeatability (rule 4) — repeated by me this round: lib.sh helper/line audit and the 11/17
sourcing greps; fetch_verified fail-closed probe (connection refused, no artifact left);
disk-floor 12/12; lane-target 40/40; harness-resolve 28/28; reclaim 9/9; scan-scope "15
claims" RESULT OK; boardctl validate `RESULT: OK (7 warning(s))` with the exact named
warnings; 357-task census; boardctl 20-verb surface; M6 doc gate `44 module(s): 37
VERIFIED, 50 error(s)` / `MASTER-DOC: FAIL` rc 1 (exact); verify-patch `4 stages, 3
patches, f393a681…` PASS (exact); full `tests/selftest.sh` PASS rc 0 (landing arm green);
scheduler `go build` rc 0 + the three env-sensitive tests PASS; crier `go build` rc 0 +
`internal/registry` test ok, 91 test files, 3-site slog surface, 67-string metric census;
dispatcher.py compile, 538 lines, no-assert test check, 25 log( lines; proxy sha256
b12a0ac5… exact, live 401 reproduced, systemd unit active with the 10-upstream.conf
drop-in. NOT repeated by me: scheduler full `go test ./...` (25 pkgs) and crier full
`go test ./...` beyond internal/registry — chapter claims both green, I verified builds and
subsets; the cf-node bus-worker ladder (chapter itself marks it not repeatable from this
host); the M7 mint (no App creds — chapter marks UNVERIFIED). Claims that verified exactly
with zero drift: M0 (all), M6 (all), M7 (all), M8 (all), M11 (all ~50 sampled locators),
M9 (all 40+ sampled locators incl. 43 routes / 57 flags / 10× LoadRootConfig / 379 log
sites / 30 tables / flag defaults / admission / migrations), M1's B05 false-green asymmetry
(:150 warn-without-unverified vs :198 seed-with-unverified — true).

CHAPTER SCORECARD:

M0 SHARED CONTRACT — PARTIAL. Every locator and grep re-verified exact; PARTIAL only
because Metrics is a proven-RED field (schema §5, round-2 B03 ruling).
M1 PROVISIONING — PARTIAL. Sampled locators exact (mode-600 lie, floor precedence, TTL
fallback, ladder asymmetry all real); four unit bodies declared unread; five-vs-six count
nit.
M2 DISPATCH — PARTIAL. Content true (reply shape, PID hardcode, lane_target caller,
crier cap, 40/40 tests), but settlement/constants/§1 locator rot is blocking.
M3 REPOSITORY — PARTIAL. Behaviorally the strongest (full selftest PASS re-run; gate-empty
default, no-invoker grep, rmtree-with-report all true), but the evidence column for
land-node-branch.sh and selftest.sh is false at the stamp — blocking.
M4 BOARD — PARTIAL. Validate/lock/admission-board locators exact and the 7 warnings
reproduce verbatim; events count false at stamp — blocking.
M5 HARNESS — PARTIAL. Declared UNVERIFIED; installer/pin/flag registers exact; rides the
node-bus-worker locator contradiction.
M6 DOCUMENTATION — PARTIAL. Everything reproduced exactly, including its own gate's FAIL
(44/37/50) and the honest UNBUILDABLE finding against the M*-blind fill/render pipeline
(`[0-9][0-9]-*.md` globs confirmed at :188/:422/:253-259).
M7 GITHUB — PARTIAL. Exact throughout; mint honestly UNVERIFIED (no creds on host).
M8 SAFETY — PARTIAL. Exact throughout (targets, TTL semantics, 15-claim scan); Metrics RED.
M9 SCHEDULER — PARTIAL. Measured counts all reproduce (43/57/10/379/30, every flag default,
admission ladder, store keys, env-contamination correction confirmed by my clean-env test
run); one drifted node-bus-worker anchor rides finding 3; declared REDs are honest.
M10 CRIER — PARTIAL. Nearly everything exact (revision, 43 routes region, ports, custody
bounds, 3-site slog, 91 files, 67 census, policy/guard/client locators); the Guard settings
block is uniformly off by one — blocking.
M11 DISPATCHER — PARTIAL. The cleanest chapter: every sampled locator exact, revision and
line counts exact, decoration-test finding true; PARTIAL for RED metrics and the
cannot-fail test row, both declared.
M12 INFERENCE PROXY — PARTIAL. sha256/401/systemd/locators reproduced; one drifted grep
site; REDs (node-client half, stream completion) declared.

The set is closer than round 7's: false factual claims of the old kind (fabricated
callers, invented filenames, wrong verb surfaces) are gone, and the honest-UNVERIFIED
discipline is real. What remains is a citation-hygiene defect: one file's locators
(node-bus-worker.py) and two chapters' registers were never re-derived against the
revision they stamp. That is cheap to fix and exactly what rule 1 exists for.

PANEL REVIEW COMPLETE

session_id: local-14a96dcabf58df74991ec0cb64b803c74925f75d2665642688b51f888c3588a1

EXIT=0
```

### grok

```
⚠️  Primary auth failed — switching to fallback: fireworks / accounts/fireworks/models/deepseek-v4p1-flash-1017
│ cache/scratch/citecheck.py
│ @@ -0,0 +1,50 @@
│ +import re, os, sys
│ +
│ +CH = '/home/kara/code-factory/docs/handbook/chapters'
│ +roots = ['/home/kara/code-factory',
│ +         '/home/kara/coding-hermes-scheduler/coding-herms-scheduler',
│ +         '/home/kara/crier', '/home/kara/crier-fleet', '/home/kara/.hermes/scripts']
│ +index = {}
│ +for r in roots:
│ +    for dp, dn, fn in os.walk(r):
│ +        if '/.git' in dp or 'node_modules' in dp:
│ +            continue
│ +        for f in fn:
│ +            index.setdefault(f, []).append(os.path.join(dp, f))
│ +lens = {}
│ +def resolve(name):
│ +    base = os.path.basename(name)
│ +    cands = index.get(base, [])
│ +    if '/' in name:
│ +        sub = [c for c in cands if c.endswith(name)]
│ +        if sub:
│ +            return sub[0]
│ +    return cands[0] if cands else None
│ +def nlines(p):
│ +    if p not in lens:
│ +        try:
│ +            lens[p] = sum(1 for _ in open(p, errors='replace'))
│ +        except Exception:
│ +            lens[p] = None
│ +    return lens[p]
│ +cite = re.compile(r'([A-Za-z0-9_./-]+\.(?:py|go|sh|ts|js|yaml|toml)):(\d+)(?:[-–](\d+))?')
│ +bad = []
│ +for f in sorted(os.listdir(CH)):
│ +    if not f.endswith('.md'):
│ +        continue
│ +    text = open(os.path.join(CH, f)).read()
│ +    for m in cite.finditer(text):
│ +        name, a, b = m.group(1), int(m.group(2)), m.group(3)
│ +        p = resolve(name)
│ +        if not p:
│ +            bad.append((f, name, a, 'FILE NOT FOUND'))
│ +            continue
│ +        n = nlines(p)
│ +        if n is None:
│ +            continue
│ +        hi = int(b) if b else a
│ +        if hi > n or a < 1:
│ +            bad.append((f, name, '%d-%s' % (a, b or a), 'file has %d lines (%s)' % (n, p)))
│ +print('out-of-range citations:', len(bad))
│ +for x in bad:
│ +    print(' | '.join(str(y) for y in x))
│ cache/scratch/citecheck2.py
│ @@ -0,0 +1,51 @@
│ +import re, os
│ +
│ +CH = '/home/kara/code-factory/docs/handbook/chapters'
│ +roots = ['/home/kara/code-factory',
│ +         '/home/kara/coding-hermes-scheduler/coding-herms-scheduler',
│ +         '/home/kara/crier', '/home/kara/crier-fleet', '/home/kara/.hermes/scripts']
│ +index = {}
│ +for r in roots:
│ +    for dp, dn, fn in os.walk(r):
│ +        if '/.git' in dp or 'node_modules' in dp:
│ +            continue
│ +        for f in fn:
│ +            index.setdefault(f, []).append(os.path.join(dp, f))
│ +_lens = {}
│ +def nlines(p):
│ +    if p not in _lens:
│ +        try:
│ +            _lens[p] = sum(1 for _ in open(p, errors='replace'))
│ +        except Exception:
│ +            _lens[p] = None
│ +    return _lens[p]
│ +
│ +def resolves(name, lo, hi):
│ +    base = os.path.basename(name)
│ +    cands = index.get(base, [])
│ +    if '/' in name:
│ +        cands = [c for c in cands if c.endswith('/' + name)] or cands
│ +    return [c for c in cands if (nlines(c) or 0) >= hi]
│ +
│ +cite = re.compile(r'([A-Za-z0-9_./-]+\.(?:py|go|sh|ts|js|yaml|toml)):(\d+)(?:[-\u2013](\d+))?')
│ +nofile, outrange = [], []
│ +total = 0
│ +for f in sorted(os.listdir(CH)):
│ +    if not f.endswith('.md'):
│ +        continue
│ +    text = open(os.path.join(CH, f)).read()
│ +    for m in cite.finditer(text):
│ +        total += 1
│ +        name, a, b = m.group(1), int(m.group(2)), m.group(3)
│ +        hi = int(b) if b else a
│ +        if not index.get(os.path.basename(name)):
│ +            nofile.append((f, name, a))
│ +        elif not resolves(name, a, hi):
│ +            outrange.append((f, name, '%d-%s' % (a, b or a)))
│ +print('total citations:', total)
│ +print('file-not-found:', len(nofile))
│ +for x in nofile:
│ +    print('  ', x)
│ +print('out-of-range:', len(outrange))
│ +for x in outrange:
│ +    print('  ', x)
│ cache/scratch/spine_mutate.py
│ @@ -0,0 +1,43 @@
│ +import os, re, shutil, subprocess, sys, pathlib
│ +
│ +src = pathlib.Path('/home/kara/code-factory/docs/handbook/chapters')
│ +work = pathlib.Path('/home/kara/.hermes/cache/scratch/spine-mut')
│ +if work.exists():
│ +    shutil.rmtree(work)
│ +(work / 'chapters').mkdir(parents=True)
│ +for p in src.glob('M*.md'):
│ +    shutil.copy(p, work / 'chapters' / p.name)
│ +
│ +script = pathlib.Path('/home/kara/code-factory/scripts/handbook_spine.py').read_text()
│ +script = script.replace('HB = Path("/home/kara/code-factory/docs/handbook")',
│ +                        'HB = Path("%s")' % work)
│ +(work / 'spine.py').write_text(script)
│ +
│ +def run(tag):
│ +    r = subprocess.run([sys.executable, str(work / 'spine.py')], capture_output=True, text=True)
│ +    print('---', tag, 'rc=', r.returncode)
│ +    print(r.stdout.strip()[:600])
│ +
│ +run('baseline')
│ +
│ +# mutation 1: drop every CT-09 mention
│ +for p in (work / 'chapters').glob('M*.md'):
│ +    t = p.read_text().replace('CT-09', 'CT-99')
│ +    p.write_text(t)
│ +run('drop CT-09 / invent CT-99')
│ +
│ +# reset
│ +shutil.rmtree(work / 'chapters')
│ +(work / 'chapters').mkdir()
│ +for p in src.glob('M*.md'):
│ +    shutil.copy(p, work / 'chapters' / p.name)
│ +
│ +# mutation 2: change CF_MAX_TURNS default in M5 from 40 to 99
│ +p = work / 'chapters' / 'M5-harness.md'
│ +p.write_text(p.read_text().replace('| `CF_MAX_TURNS` | 40 (`:276`)', '| `CF_MAX_TURNS` | 99 (`:276`)'))
│ +run('default conflict 40 vs 99')
│ +
│ +# mutation 3: dangling module + flow + count
│ +p = work / 'chapters' / 'M8-safety.md'
│ +p.write_text(p.read_text() + '\nSee M77 and F99. The document has 17 contracts.\n')
│ +run('dangling + count')
│ cache/scratch/linescheck.py
│ @@ -0,0 +1,33 @@
│ +import re, os
│ +
│ +CH = '/home/kara/code-factory/docs/handbook/chapters'
│ +roots = ['/home/kara/code-factory',
│ +         '/home/kara/coding-hermes-scheduler/coding-herms-scheduler',
│ +         '/home/kara/crier', '/home/kara/crier-fleet', '/home/kara/.hermes/scripts',
│ +         '/home/kara/code-factory/scripts']
│ +_lens = {}
│ +def nlines(p):
│ +    if p not in _lens:
│ +        try:
│ +            _lens[p] = sum(1 for _ in open(p, errors='replace'))
│ +        except Exception:
│ +            _lens[p] = None
│ +    return _lens[p]
│ +
│ +pat = re.compile(r'`?([A-Za-z0-9_./-]+\.(?:py|go|sh|ts|js|md|yaml|toml))`?\s*\((\d{2,5})\s+lines?\)')
│ +for f in sorted(os.listdir(CH)):
│ +    if not f.endswith('.md'):
│ +        continue
│ +    text = open(os.path.join(CH, f)).read()
│ +    for m in pat.finditer(text):
│ +        name, claim = m.group(1), int(m.group(2))
│ +        hits = []
│ +        for r in roots:
│ +            p = os.path.join(r, name)
│ +            if os.path.isfile(p):
│ +                hits.append(p)
│ +        if not hits:
│ +            continue
│ +        actual = {nlines(p) for p in hits}
│ +        if claim not in actual:
│ +            print('%-22s %-38s claim=%-5d actual=%s' % (f, name, claim, sorted(x for x in actual if x)))
│ cache/scratch/tokencite.py
│ @@ -0,0 +1,41 @@
│ +import re, os
│ +
│ +CH = '/home/kara/code-factory/docs/handbook/chapters'
│ +roots = ['/home/kara/code-factory',
│ +         '/home/kara/coding-hermes-scheduler/coding-herms-scheduler',
│ +         '/home/kara/crier', '/home/kara/crier-fleet', '/home/kara/.hermes/scripts']
│ +index = {}
│ +for r in roots:
│ +    for dp, dn, fn in os.walk(r):
│ +        if '/.git' in dp or 'node_modules' in dp:
│ +            continue
│ +        for f in fn:
│ +            index.setdefault(f, []).append(os.path.join(dp, f))
│ +
│ +cache = {}
│ +def lines(p):
│ +    if p not in cache:
│ +        cache[p] = open(p, errors='replace').read().splitlines()
│ +    return cache[p]
│ +
│ +# `TOKEN` ... (`:123`) or (`:123-130`)
│ +pat = re.compile(r'`([^`\n]{3,60})`[^`\n]{0,40}\(`:?(\d+)(?:[-\u2013](\d+))?`?\)')
│ +misses = 0
│ +for f in sorted(os.listdir(CH)):
│ +    if not f.endswith('.md'):
│ +        continue
│ +    text = open(os.path.join(CH, f)).read()
│ +    for m in pat.finditer(text):
│ +        token, a, b = m.group(1), int(m.group(2)), m.group(3)
│ +        lo, hi = a, int(b) if b else a
│ +        hits = []
│ +        for base, cands in index.items():
│ +            for p in cands:
│ +                L = lines(p)
│ +                if len(L) >= hi:
│ +                    if any(token[:24].split('.')[-1] in ln or token[:24] in ln for ln in L[lo-1:hi]):
│ +                        hits.append(p)
│ +        if not hits:
│ +            misses += 1
│ +            print('%-22s %-46s -> :%s-%s' % (f, token[:46], lo, hi))
│ +print('total suspicious:', misses)
│ cache/scratch/spine_pair.py
│ @@ -0,0 +1,25 @@
│ +import shutil, subprocess, sys, pathlib
│ +
│ +src = pathlib.Path('/home/kara/code-factory/docs/handbook/chapters')
│ +work = pathlib.Path('/home/kara/.hermes/cache/scratch/spine-pair')
│ +if work.exists():
│ +    shutil.rmtree(work)
│ +(work / 'chapters').mkdir(parents=True)
│ +for p in src.glob('M*.md'):
│ +    shutil.copy(p, work / 'chapters' / p.name)
│ +script = pathlib.Path('/home/kara/code-factory/scripts/handbook_spine.py').read_text()
│ +script = script.replace('HB = Path("/home/kara/code-factory/docs/handbook")', 'HB = Path("%s")' % work)
│ +(work / 'spine.py').write_text(script)
│ +
│ +# Make the two chapters cite DIFFERENT producer functions for CT-03.
│ +m2 = work / 'chapters' / 'M2-dispatch.md'
│ +t = m2.read_text().replace('internal/registry/handler.go:990` `HandleDeliver` (POST `/agents/{id}/inbox`)',
│ +                           'internal/registry/handler.go:123` `SomeOtherFunc`')
│ +m2.write_text(t)
│ +m10 = work / 'chapters' / 'M10-crier.md'
│ +t = m10.read_text().replace('`handler.go:1690` `HandleRetrieve` (lease)', '`handler.go:999` `TotallyDifferent`')
│ +m10.write_text(t)
│ +
│ +r = subprocess.run([sys.executable, str(work / 'spine.py')], capture_output=True, text=True)
│ +print('rc=', r.returncode)
│ +print(r.stdout)
VERDICT: FAIL
BLOCKING: 7 — findings that must be fixed before this chapter can be called written
NON-BLOCKING: 5

FINDINGS:

B1. FALSE CLAIM — M2 (DISPATCH).
Claim: "`DEFAULT_INBOX_LIMIT` 10 (`:80`)", "`DEFAULT_LEASE_SECONDS` 30 (`:81`)", "`SEEN_LIMIT` 200 (`:84`)", "`  FAIL  identity — …; refusing` (`:603`)", "reply shape `:1128-1144`", "`dispatch_wall` `:1152-1157`", "`--reply-to` `\"scheduler\"` (`:1432`)", "`--wait-seconds` 0 (`:1438`)", "`--interval` 15 (`:1441`)", "`could not record the seen-cache` (`:1355`)", settlement "`node-bus-worker.py:1300-1367`".
Evidence (all at the chapter's own stamp 226ae37; file unchanged since 1f1c0fe, 1546 lines): `sed -n '81p'` = `DEFAULT_INBOX_LIMIT = 10` (not :80); :82 = `DEFAULT_LEASE_SECONDS`; :85 = `SEEN_LIMIT`; :603 = `nonlocal failures` (the identity refusal is :608); reply dict spans 1176-1193 (`"status": …`); `def dispatch_wall` is :1200; `--reply-to` is :1479-1482; `--wait-seconds` is :1486; `--interval` is :1490; seen-cache warning is :1402; the settle loop is :1390-1406. Eleven locators, none of which contain the claimed text.
Fix: re-derive every M2 locator against 226ae37 and re-run the §7 ladder; do not stamp a revision whose file shape you did not read.

B2. FALSE CLAIM — M3 (REPOSITORY).
Claim: "`land-node-branch.sh` (295 lines)" (§1, §13); "`land-node-branch.sh:36` initialises `GATE=\"\"`"; "`LAND: REFUSED — %s` (`:56`)". "`LAND: DRY-RUN …` (`:231`)"; "`LANDED: …` (`:291`)"; "`LAND: FAIL (%d)` (`:294`)"; push at "`:265`"; ancestry proof "`:265-283`"; "`refuse workdir \"not a git worktree\"` (`:91-93`)"; "`refuse descendant` (`:167`)"; "`refuse no_ff_local` (`:214`)"; "M3-C2 producer `scripts/node-bus-worker.py:1139-1140` builds `branch`/`commit`"; `repo_freshness --bound` "(`:558`)"; hook write "`install-gitreins.sh:120-138`"; "`selftest.sh` is 4,591 lines"; arm `cf244-node-freshness` "(`:3413-3650`)".
Evidence: `wc -l scripts/land-node-branch.sh` = 308 (295 is the pre-da9001f file, f996376, which is an ancestor of the stamp). `sed -n '38p'` holds the `GATE=""` assignment; `LAND: REFUSED` is :58; `LAND: DRY-RUN — 0 commands run…` is :244; `LANDED:` is :304; `LAND: FAIL ($FAILED)` is :307; `git push` is :278; the ancestry proof is :293-298; `refuse workdir` is :124; `refuse descendant` is :202; `refuse no_ff_local` is :223/:227. `grep -n '"branch"\|"commit"' scripts/node-bus-worker.py` → 1187-1188 (1139-1140 is the dry-run WOULD block). `--bound` is repo_freshness.py:559 (and --gate 565, --strict 570, --no-fetch 575, --max-fetch-age 581, --jobs 588, --timeout 591 — the whole block is off by one). Hook heredoc is install-gitreins.sh:124-136. `wc -l tests/selftest.sh` = 4737; `cf244-node-freshness` arms are :3433-3670. Fifteen-plus locators wrong.
Fix: re-cite against 226ae37; the "shipped landing arm PASS" row is unverifiable while its range points at a different arm.

B3. FALSE CLAIM — M4 (BOARD).
Claim: "**VERIFIED** (357 rows / 515 events …)"; "`wc -l .coding-hermes/board/events.jsonl` | 515 lines | PASS (515)"; and the quoted gate output "`357 tasks, 515 events, 0 fixtures`".
Evidence: `wc -l .coding-hermes/board/events.jsonl` = 518; `grep -c .` = 518; `jq -c . | wc -l` = 518; `git show 226ae37:.coding-hermes/board/events.jsonl | wc -l` = 518. The command the chapter claims to have run prints `rows: 357 tasks, 518 events, 0 fixtures`. Tasks = 357 is correct, and `RESULT: OK (7 warning(s))` reproduces.
Fix: 518 in all three places, and re-quote the gate output verbatim rather than from memory.

B4. CONTRADICTION — M2 §6 vs M10 §6 (CT-03), and M9 §6 vs M11 §6 (CT-06); plus the spine cannot see it.
Claim: M2 CT-03 producer is "`internal/registry/handler.go:990` `HandleDeliver`"; M10 CT-03 producer is "`handler.go:1690` `HandleRetrieve` (lease)". M9 CT-06 producer is "crier … `HandleRetrieve`", while M11 CT-06 producer is "`dispatcher.py:500-508` builds `{in_reply_to, agent, ok, …}`".
Evidence: one canonical id, two different producer/consumer pairs, both presented as the register of record. `scripts/handbook_spine.py`'s docstring says the two sides "must name the same producer/consumer pair", but `has_fq()` only requires *some* `file.ext` token in each cell. Proof: on a scratch copy of the 13 chapters I replaced M2's CT-03 producer with `handler.go:123 SomeOtherFunc` and M10's with `handler.go:999 TotallyDifferent`; the spine still returned `findings=0`, rc 0.
Fix: CT-03 = HandleRetrieve (lease) → node consumer; CT-06 = dispatcher → crier → scheduler with both hops named; and make the spine compare the pair across chapters, not merely for presence of a filename.

B5. FALSE CLAIM — README §IV vs M9 §6 (CT-01).
Claim: "Five contracts (CT-01, CT-02, CT-03, CT-04, CT-06) are *internal* — both ends are files in the five covered systems, and each row names both `file:function`."
Evidence: M9's CT-01 producer cell is "**operator config** — `fleet.toml` + `scheduler.db` project rows … the load path is `config.LoadRootConfig` (`internal/config/loader.go` …)" — that is the consumer's loader, not a producer implementation, and the actual producer is a human writing `fleet.toml`. The row's own state says UNVERIFIED. So CT-01 is a boundary contract misfiled as internal, and the honest count is at most 4 of 18 both-sided, not 5. The spine passes it because any `.go` filename satisfies `has_fq()`.
Fix: move CT-01 to BOUNDARY, name the producer as operator config (no function), recount README:111-113 and 162.

B6. OMISSION — document (Parts I, IV–VIII; 11 of 16 flows).
Claim: the outline is "the structure the document must satisfy"; README:52-56 states "Parts I (beyond the rendered sheets), II.6–II.10, IV (as a re-derived register), V, VI, VII and VIII have no chapters", and README:165 says "Can a task list be derived? **Not yet** — Part VII unwritten."
Evidence: OUTLINE.md:54-93 specifies 16 flows with 13 mandatory fields each (5 RENDERED, 11 MISSING), and OUTLINE.md:239-244 requires VII.3 "acceptance gate per chapter". No flow chapter exists in `docs/handbook/chapters/` (13 files, all `M*`), and there is no acceptance-gate section anywhere in the tree. Disclosure of a gap is honesty, not completion: the document is 13 of 47 submodule sections and 0 of 16 flows.
Fix: either bring the outline's scope into line with a declared, owner-approved Part III-only deliverable, or write the flows/parts; a document whose own status table says no task list can be derived cannot be called written.

B7. CONTRADICTION — MASTER-DOC-SCHEMA §5/§8 vs OUTLINE VII.3 (the WRITTEN gate is unsatisfiable).
Claim: OUTLINE VII.3 requires "what makes a chapter WRITTEN rather than merely present"; README:64 defines WRITTEN as "every field filled with evidence, no false claim".
Evidence: MASTER-DOC-SCHEMA.md:77-79 says "If the module emits none, write \"none\" — and that is a RED field"; README:67-71 adds "a chapter with a RED metrics field stays PARTIAL until the system emits metrics or an explicit schema exception is approved". Ten of thirteen modules emit no metrics (M0, M1, M2, M3, M5, M6, M7, M8, M11, M12 — each absence-proved by the chapter's own grep, which I re-ran on M0 and M8: 0 matches). Therefore no honest chapter in those ten can reach WRITTEN, in this round or any future round, until ten modules ship metrics. The loop has no reachable exit condition, which is the structural reason every round returns FAIL.
Fix: decide the doctrine — either an explicit schema exception ("node-side script, no metrics surface; absence is a filed system defect, not a chapter defect") or redefine WRITTEN to exclude §8 for non-service units, and record the ruling at MASTER-DOC-SCHEMA §8 and OUTLINE VII.3.

N1. CONTRADICTION (non-blocking) — M2 §6 vs §13: CF-354 is "fixed and closed (commit `1f1c0fe`)" in §6 and "closed in commit `6184e52`" in §13; M9 §6 repeats `1f1c0fe`. Both commits exist (1f1c0fe = the decode fix, 6184e52 = the board close), so name them as two facts rather than one.

N2. CONTRADICTION (non-blocking) — OUTLINE Part IV still declares "**0 of 18** name both implementations" (:204) and "10 works, 6 broken, 2 missing" (:46) while the delivered chapters achieve 4–5 both-sided rows and CT-02 is now "works". README discloses that the sheet-4 count is stale; the structure document itself still carries the false numbers.

N3. CONTRADICTION (non-blocking) — M5 F5-4: `docs/UNIT-MAP.yaml` lists M5 as 3 submodules, OUTLINE as 5. Two structure maps still disagree; the chapter says the 5-reading is authoritative but neither map was corrected.

N4. PADDING (non-blocking) — roughly 40 passages are round-history rather than operational content ("Round-4's … was **false**", "Round-6 said … — false", "the round-3 draft's literal source-count commands were over-escaped"). Corrections belong in a change log (Appendix D); in the chapter body they are narration an operator cannot act on and they push real content out of the page.

N5. OMISSION (non-blocking) — no shipped path renders these chapters: `gen_nasa_handbook.py:18` hardcodes `docs/master` and `:253-259` selects `[0-9][0-9]-*.md`; `master_doc_fill.py:422` and `master_doc_check.py:188` use the same glob, so CT-18 (`handbook → owner`) is UNVERIFIED. M6 files this as F6-1/B13 honestly; the defect is real (there is no artifact to send the owner), it is just disclosed.

DEFECT CLASSES:
- stale locator block (citations from a prior file revision: M2, M3)
- count drift quoted as command output (M4 515/518; M3 295/4591)
- cross-chapter pair disagreement under one canonical id (CT-03, CT-06)
- register misclassification (CT-01 boundary sold as internal)
- checker under-implementation (spine passes pair mismatch; passes a fourth bad locator class)
- skeleton parts (11 of 16 flows, 7 of 8 parts absent; no acceptance gate)
- unsatisfiable acceptance gate (metrics RED blocks WRITTEN for 10 of 13)
- disclosure-as-mitigation (gaps named instead of closed, then carried)

WHAT I RE-RAN (repeatable, this seat, 2026-11-06):
`handbook_spine.py` → chapters=13, canonical=18, findings=0, rc 0; and four mutation trials proved it detects an unregistered CT id, a duplicated setting default, a dangling M/F ref and a wrong contract count (it is a real check, but see B4/B5 for what it cannot see).
M0: `bash -n`, greps 11/17, lib.sh 78 lines, all helper lines. M1: `python3 tests/test_disk_floor.py` 12/12; provision/destroy/verify-node lines. M3: `bash -n`, all greps, 308-line truth. M4: `jq | wc -l` 357, events 518, `boardctl validate` OK+7 warnings, duplicate-id refusal, `boardctl version dev`, 20 subcommands. M5: 28/28 harness-resolve tests; pins and CF_* bounds. M6: gate `44 module(s): 37 VERIFIED, 50 error(s)`, `MASTER-DOC: FAIL`; `verify-patch.sh` PASS (4 stages, 3 patches, f393a681…). M7: bare invocation rc 2. M8: 9/9 reclaim tests, `audit-scope: 15 gitleaks claim(s)`, reclaim targets. M9: 30 tables, 43 routes, 57 flags, 379 `log.Printf`, 10 `LoadRootConfig` sites — every measured count in the chapter reproduces. M10: 1895 lines, 91 test files, 3 slog sites, 67 `crier_[a-z_]+` strings, crier has no board admission. M11: 538 lines, 25 `log(` lines (23 calls), 0 asserts in its test. M12: sha256 b12a0ac5… matches, 273 lines, sinks `cf-inference-usage.jsonl`/`cf-inference-requests.jsonl`, live 401, systemd active PID 2603939.

NOT REPEATED (rule 4, stated): M1 certification ladder and probe (no live node); M2 bus-worker ladder (not this host); M3 shipped landing arm and M9/M10 `go build`/`go test` (left unrun in a judge slot; the chapters' own PASS rows are therefore UNVERIFIED by me); M5 conformance battery; M11 live-job tests; M4 lock adjudication.

CHAPTER SCORECARD:
M0  PARTIAL — every field present, every claim I re-ran reproduced (78 lines, 11/17 sources, rc 1 probe); held below WRITTEN only by Metrics-RED (schema §5) and by B7.
M1  PARTIAL — §1 Status is honest (four unit bodies unread), ladder unrun, Metrics RED; the locators I checked are exact.
M2  PARTIAL — content is strong and several corrections are real, but 11 locators cite the wrong line at its own stamp; Metrics RED; its "VERIFIED" status cannot stand while the evidence pointers do not resolve (B1).
M3  PARTIAL — 15 locators, two file counts and one arm range wrong against the stamp; the "shipped landing arm PASS" row I did not repeat; Metrics RED (B2).
M4  PARTIAL — board truth is 357/518, not 357/515, and the quoted gate output is not the gate's output; lock adjudication UNVERIFIED; Metrics RED (B3).
M5  PARTIAL — pins, bounds and predicate all check out; conformance unrun; Metrics RED.
M6  PARTIAL — the strongest honest chapter (it reports its own gate FAIL); but its §5 fill switches, render path and panel selection are unwritten or wrong for this chapter set; Metrics RED.
M7  PARTIAL — CLI surface, key-mode predicate and credential-domain separation verified; mint never run; Metrics RED.
M8  PARTIAL — both units read, targets exact, 9/9 tests, 15 claims; Metrics RED.
M9  PARTIAL — the best-measured chapter in the set (30/43/57/379/10 all reproduce); but 377 of 379 log sites unwritten, auxiliary-flag consequences unexpanded, per-route contracts absent, S3 write authorities absent.
M10 PARTIAL — metrics real and default-ON, custody and guard semantics exact; 1895-line body unread, per-metric table absent, guard log surface untabulated.
M11 PARTIAL — full read, 23 log lines, kill-group guarantee correctly withdrawn; its tests cannot fail and its metrics are absent.
M12 PARTIAL — hash-and-behaviour exact (401, PID, sinks, 273 lines); two boundary halves UNVERIFIED and the healthy-stream framing defect (F12-7) open.

No chapter is WRITTEN; the spine's clean run is true for its four checks but not for the four rules in the brief, and the two chapters that carry the most claims (M2, M3) are the two whose evidence pointers do not survive a `sed` at the stamped revision. That is the same defect class the owner has now rejected repeatedly, and it is fixable mechanically: add a locator-content check to the spine (line must contain the quoted token) and a cross-chapter pair comparison, then re-stamp.

PANEL REVIEW COMPLETE

session_id: local-986782d8a228ec09ff1038169adf40d9e652f26f4bbf684b91f4995b8809346a

EXIT=0
```

### kimi

```
VERDICT: FAIL

BLOCKING: 6 — findings that must be fixed before the affected chapters can be called written
NON-BLOCKING: 6

Method note: `python3 scripts/handbook_spine.py` was run first — `chapters=13 canonical contracts=18 findings=0` — so no tool-reported CONTRADICTION findings. Everything below is from judging the chapters against the code directly: 100+ spot checks across all five systems, both Go builds (`go build ./...` PASS in scheduler @1771d3aa and crier @691f0c78), both full Go test suites reproduced green (scheduler 25/25 packages incl. `internal/scheduler` 240.4s with the env var unset; the three operator-restart tests 0.395s; crier `internal/registry` 8.6s over 91 test files), the four Python unit suites re-run (lane_target, disk_floor, harness_resolve, reclaim — all OK), `master_doc_check.py` reproduced (`44 module(s): 37 VERIFIED, 50 error(s)` / `MASTER-DOC: FAIL`), `verify-patch.sh` PASS, `check_scan_scope.py` (15 claims), `boardctl validate` (`RESULT: OK (7 warning(s))`), the M12 content sha256 and the live 401 admission reproduced, and the systemd unit confirmed `active (running)` Main PID 2603939.

FINDINGS:

1. kind: UNVERIFIED (rule 1 — evidence does not support the claims) — chapter M2 — claims (quoted): "`dispatch_wall` `:1152-1157`", "CLI (`:1430-1478`): `--reply-to` (`:1432`)", "`--wait-seconds` … (`:1438`) … (`:1463`)", "`--interval` … (`:1441`)", "`--harness-wall` / `--timeout` (`:1446-1449`)", "Settlement … `:1300-1367` … (`:1341-1347`)", "`SEEN_LIMIT` | 200 (`:84`)", "`CF_TIMEOUT_S` | 1800 (`:113`)", "`bad(\"identity\" … refusing)` (`:603`)". Evidence (measured): the file is byte-identical to the stamped revision (`git diff 226ae37..HEAD -- scripts/node-bus-worker.py` is empty), and the actual lines are: `def dispatch_wall` :1200, return :1205; `def main` :1425, `--reply-to` :1479, `--wait-seconds` :1486, range check :1511-1513, `--interval` :1489, `--harness-wall` :1492, `--timeout` :1498; settlement `delivered_ok` :1389, `seen[key] = result` :1394-1395, ack logic :1408-1418; `SEEN_LIMIT` :85; `CF_TIMEOUT_S` :114; `:603` is the text `nonlocal failures` (the identity refusal is at :608). The locators were wrong at derivation, so every claim resting on them is unevidenced. Fix: re-pin every M2 §5/§11 locator against the current file and re-derive the two affected rows (the §6 contract rows at :977/:989-1003/:1176-1192/:1208 verified correct — keep those).

2. kind: FALSE CLAIM — chapter M3 — claims: "`land-node-branch.sh` (295 lines)" and "`selftest.sh` is 4,591 lines", plus log-line locators "`LANDED:` (`:291`)", "`LAND: FAIL (%d)` (`:294`)", "`LAND: DRY-RUN …` (`:231`)", "`REMOTE` / `MAIN` … (`:36`)", "set only by `--gate-cmd` (`:76`)", arm "`cf244-node-freshness` (`:3413-3650`)". Evidence: both files are byte-identical at the stamp (`git show 226ae37:<f> | wc -l` = 308 and 4737 respectively, same as now); actual lines: `LANDED:` :304, `LAND: FAIL` :281 and :307, DRY-RUN :190/:244, `WORKDIR="" … REMOTE=origin MAIN=main GATE=""` :38, `--gate-cmd)` :108, arm cf244 :3433-3670. Fix: correct the counts (308 / 4737) and re-pin the lander locators.

3. kind: FALSE CLAIM — chapter M3 — claim (§10 failure-mode row, repeated in F3-4): "a tracked `.py` with an unused variable is committed — `scripts/panel_loop.py:114` assigns `rc` and never reads it (F841)". Evidence: no `rc =` assignment exists in `panel_loop.py` at the stamp or at HEAD (`git show 226ae37:scripts/panel_loop.py | grep -n 'rc =\|rc='` → 0 matches); `ruff check --select F841 scripts/panel_loop.py` → "All checks passed!". The defect the row teaches from does not exist at the cited location. Fix: remove the row or re-point it at a real, reproduced F841.

4. kind: CONTRADICTION — chapters M4 vs M2/M9/M10/M12 — M4 (F4-3) rules: "a 'works' verdict attached to an unnamed side is a rumour with a verdict" and on that basis corrects CT-13/CT-14 to UNVERIFIED; yet M2 CT-11, M9 CT-15, M10 CT-08 and M12 CT-07 each carry the state "works (external, client-side only)" with no in-repo `file:function` on either side. Two admissibility standards for the same contract class inside one document. Fix: pick one standard (the M4 one is the defensible one) and re-grade the four "works (external)" rows.

5. kind: OMISSION — chapter M11 — the settings register must cover every env var; `DISPATCH_EXEC_TIMEOUT` (`dispatcher.py:47`, default `"400s"`) appears nowhere in §5 — not even as NAME ONLY. Evidence: `sed -n '47p' dispatcher.py` → `EXEC_TIMEOUT = os.environ.get("DISPATCH_EXEC_TIMEOUT", "400s")`; the chapter's register runs from `DISPATCH_POLL_S` to `FLEET_AGENTS` without it. Fix: add the row with default, range and consequence.

6. kind: UNVERIFIED (rule 4 — not repeatable) — chapter M4 — §1/§7 claim "byte parity, `RESULT: OK`; … 0 divergent ids; HEAD=`226ae37` == `origin/main=226ae37`" and "events count … 515 lines". Evidence (measured this review): `python3 scripts/board_drift.py check --workdir /home/kara/code-factory --ref origin/main` → `RESULT: DRIFT (4 failed)`, `1 divergent ids: CF-270`, HEAD `47d68b4d` vs origin/main `4dc0ef0b`; `wc -l events.jsonl` → 518. True at the stamp, false now; the chapter's own F4-4 says the honest row is the current measurement re-taken each round, so the Status line and §7 rows must be re-measured and re-stamped (and the chapter text itself is currently uncommitted in the working tree). Fix: re-run, re-stamp, and annotate the CF-270 divergence.

NON-BLOCKING:
1. UNVERIFIED (locator) — M12 — M12-C1 cites "`scripts/panel_loop.py:136`"; actual match is `panel_loop.py:145` (the four-site grep count is correct). Fix: re-pin.
2. UNVERIFIED (locator) — M10 — "`Guard.KanbanQueueSize` | 100 (`:653`)"; actual `KanbanQueueSize: 100,` is :654 (:653 is the `Model` line). Fix: re-pin.
3. UNVERIFIED (locator) — M6 — "empty falls back to `openai/gpt-6.1-sol` (`:445`)"; actual fallback expression is `master_doc_fill.py:454`. Fix: re-pin.
4. CONTRADICTION (minor count) — M1 — "Five flags were … applied again after the config (`:604-608`)"; the re-apply block holds six assignments (`:604-609`: DUCKBRAIN_URL, GITHUB_TOKEN_FILE, DUCKBRAIN_TOKEN_FILE, CRIER_AGENT_KEY_FILE, CRIER_AUTH_TOKEN_FILE, S3_ENV_FILE). Fix: correct the count or name the five.
5. PADDING (staleness) — README — the measured-status row reads "0 WRITTEN, 13 PARTIAL, 0 SKELETON (round 5)" inside the round-8 document. Fix: re-tag.
6. Not-a-finding disclosure: the M3 shipped landing arm (`SHIPPED_LANDING_ARM_RC=0`) was NOT re-run by this judge (fixture cost), and the M1/M5 live-node ladders were not run (no live node) — the chapters mark both honestly; I repeat their UNVERIFIED status rather than inherit the PASS.

DEFECT CLASSES: stale/wrong locators at a fixed revision (file:line drift) · false count claims · premise-on-a-nonexistent-defect · point-in-time verification gone stale · cross-chapter admissibility-standard inconsistency · settings-register omission · stale round tags.

What verified cleanly (so the FAIL is scoped): M0 in full (78-line `lib.sh`, every helper cite, 11/17 sourcer counts, fail-closed code path); M1's provisioning/disk-floor/seed/verify-node claims incl. crier `HandleRegister` :598 / `HandleRegisterByID` :613 and `project-node.sh:173,212`; M5 in full (all pins, the >=3.11,<3.14 gate, the three `--apply` refusals, computed dispatch `project-node.sh:440/:449-452`, resolver :284/:388, no-caller greps); M6's gate behaviour and the `docs/master` + `[0-9][0-9]-*.md` unbuildability; M7's CLI exit 2 and lifecycle settings; M8 in full; M9's admission chain (`admission_mode.go:98/112/143/177/230-242/266`), `dispatchReplyVerdict` :709-726 reading only `payload["ok"]`, `bus/dispatch.go:202` `text_b64` + `board`, 43 routes, 57 flags with every spot-checked default, `LoadRootConfig` ×10, 30 tables (no `verdicts`), 379 `log.Printf` sites, metrics semantics; M10's handler functions (:598/:613/:990/:1690/:1812), 3-site slog surface, 67-metric census, guard pipeline/oversize/errorResult, custody aliases and the 100-cap, config defaults incl. default-ON metrics with the contradicting `metrics.go:2` "opt-in" comment; M11's 538-line read (kill :329 vs GNU-timeout group :260/:291 — F11-8 consistent with the code), decoration tests (0 asserts), ledger ordering :470-483; M12's sha256, admission 401 (live), settings, and the hardcoded `API_SERVER_KEY` message at :269.

CHAPTER SCORECARD:
- M0 — WRITTEN: every cited line re-verified by this judge; the RED metrics field is absence-proved evidence of a system gap, not a writing defect.
- M1 — PARTIAL: all spot checks passed; four unit bodies read at settings surface only and the live certification ladder unrun (self-declared).
- M2 — PARTIAL (blocking finding 1): §6 contract rows verified; §5/§11 locator rot makes the run-time claims unevidenced.
- M3 — PARTIAL (blocking findings 2, 3): false line counts, wrong lander locators, a failure-mode row premised on a defect that does not exist.
- M4 — PARTIAL (blocking finding 6): lock classifier and `boardctl validate` reproduced; parity/HEAD claims measurably false at judgment time.
- M5 — PARTIAL: no false claims found; self-declared unread installer bodies and unrun conformance battery.
- M6 — PARTIAL: gate FAIL reproduced exactly; one wrong locator; own-gate FAIL honestly carried.
- M7 — PARTIAL: mint unrun (honest UNVERIFIED); everything read was verified.
- M8 — WRITTEN: both files fully read; TTL boundary, target sets, dry-run projection and scan-scope surface all reproduced.
- M9 — PARTIAL: the heaviest verification load of the round passed (build, 25/25 tests, admission, settlement, flags, tables, routes); named REDs stand (377 uncovered log sites, grep-level S1 units, unexpanded aux-flag consequences, per-route contract).
- M10 — PARTIAL: build and full test suite reproduced; named REDs stand (handler body, per-metric contract, guard log tabulation, storage custody proof); one off-by-one locator.
- M11 — PARTIAL (blocking finding 5): full-file read verified incl. the withdrawn kill guarantee; settings register incomplete; live-job tests confirmed decoration.
- M12 — PARTIAL: content hash, live 401, systemd unit and settings reproduced; one wrong locator; node-client half and stream completion honestly UNVERIFIED.

PANEL REVIEW COMPLETE

session_id: local-d0494c0a87a66903c6cca944af74f276d0592e397a89811fd1b8c66f30cae483

EXIT=0
```

### sol

```
│ cache/scratch/round8_judge_probe.py
│ @@ -0,0 +1,113 @@
│ +import ast
│ +import hashlib
│ +import http.client
│ +import importlib.util
│ +import json
│ +from pathlib import Path
│ +import subprocess
│ +import threading
│ +from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
│ +from types import SimpleNamespace
│ +
│ +ROOT = Path('/home/kara/code-factory')
│ +def load(name, path):
│ +    spec = importlib.util.spec_from_file_location(name, path)
│ +    mod = importlib.util.module_from_spec(spec)
│ +    spec.loader.exec_module(mod)
│ +    return mod
│ +
│ +spine = load('r8spine', ROOT / 'scripts/handbook_spine.py')
│ +print('SPINE_DETECTS_BARE_FILE_AS_FUNCTION=' + str(spine.has_fq('config.yaml')))
│ +print('SPINE_BACKTICK_DEFAULTS=' + repr([spine.norm_default(x) for x in ['`origin` (`:36`)', '`upstream` (`:38`)']]))
│ +node = load('r8node', ROOT / 'scripts/node-bus-worker.py')
│ +print('DISPATCH_WALL_FRACTION=' + str(node.dispatch_wall({'limits': {'wall_s': 0.5}}, SimpleNamespace(harness_wall=1800))))
│ +
│ +chapters = list((ROOT / 'docs/handbook/chapters').glob('M*.md'))
│ +reds = {}
│ +for p in chapters:
│ +    text = p.read_text()
│ +    import re
│ +    m = re.search(r'## RED field count: (\d+)', text)
│ +    reds[p.name.split('-')[0]] = int(m.group(1))
│ +print('DECLARED_RED_COUNTS=' + json.dumps(reds, sort_keys=True))
│ +print('DECLARED_RED_TOTAL=' + str(sum(reds.values())))
│ +
│ +for p in [ROOT / 'scripts/lib.sh', ROOT / 'scripts/node-bus-worker.py', ROOT / 'scripts/land-node-branch.sh']:
│ +    revision = subprocess.check_output(['git','-C',str(ROOT),'show',f'226ae37:{p.relative_to(ROOT)}'], text=True)
│ +    print('PINNED_LINES_' + p.name + '=' + str(len(revision.splitlines())))
│ +
│ +proxy = load('r8proxy', '/home/kara/.hermes/scripts/cf-inference-proxy.py')
│ +sse = b'data: {"done": true}\n\ndata: [DONE]\n\n'
│ +class Upstream(BaseHTTPRequestHandler):
│ +    def do_GET(self):
│ +        body = json.dumps({'data':[{'id':'hermes'}, {'id':'not-allowed'}]}).encode()
│ +        self.send_response(200)
│ +        self.send_header('Content-Length', str(len(body)))
│ +        self.end_headers()
│ +        self.wfile.write(body)
│ +    def do_POST(self):
│ +        self.rfile.read(int(self.headers['Content-Length']))
│ +        self.send_response(200)
│ +        self.send_header('Content-Type', 'text/event-stream')
│ +        self.send_header('Content-Length', str(len(sse)))
│ +        self.end_headers()
│ +        self.wfile.write(sse)
│ +        self.wfile.flush()
│ +    def log_message(self, *args):
│ +        pass
│ +up = ThreadingHTTPServer(('127.0.0.1',0), Upstream)
│ +px = ThreadingHTTPServer(('127.0.0.1',0), proxy.Handler)
│ +proxy.UPSTREAM = 'http://127.0.0.1:%d' % up.server_port
│ +proxy.UPSTREAM_MODEL = ''
│ +proxy.ALLOWED_MODELS = {'hermes'}
│ +proxy.upstream_key = lambda: 'dummy-local-test-only'
│ +proxy.load_tokens = lambda: {'fixture-node':'dummy-local-test-only'}
│ +proxy.log_usage = lambda rec: None
│ +proxy.capture_request = lambda *args: None
│ +for server in (up,px):
│ +    threading.Thread(target=server.serve_forever, daemon=True).start()
│ +try:
│ +    c = http.client.HTTPConnection('127.0.0.1', px.server_port, timeout=1)
│ +    c.request('GET', '/v1/models', headers={'Authorization':'Bearer dummy-local-test-only'})
│ +    r = c.getresponse()
│ +    print('HERMETIC_MODELS_STATUS=' + str(r.status))
│ +    print('HERMETIC_MODELS_BODY=' + r.read().decode())
│ +    c.close()
│ +    c = http.client.HTTPConnection('127.0.0.1',px.server_port,timeout=1)
│ +    c.request('POST','/v1/chat/completions',body=json.dumps({'model':'hermes','stream':True}),headers={'Authorization':'Bearer dummy-local-test-only','Content-Type':'application/json'})
│ +    r = c.getresponse()
│ … omitted 35 diff line(s) across 1 additional file(s)/section(s)
│ cache/scratch/round8_finding_manifest.json
│ @@ -0,0 +1 @@
│ +{"blocking":["B01-metrics-red","B02-boundary-contract-exemption","B03-ct08-covered-producer","B04-ct05-covered-prompt-path","B05-stale-locators","B06-tasks-waiver-vs-admission","B07-spine-false-negatives","B08-unbuildable-document-pipeline","B09-provisioning-settings","B10-node-dispatch-settings","B11-harness-settings","B12-scheduler-settings","B13-crier-storage-settings","B14-dispatcher-settings","B15-github-mint-unverified","B16-nonrepeatable-behavioral-probes","B17-incomplete-log-registers","B18-missing-recovery-indications","B19-control-plane-submodule-incompleteness"],"non_blocking":["N01-live-board-drift-snapshot"]}
VERDICT: FAIL
BLOCKING: 19 — grouped findings that must be fixed before the affected chapters can be called written
NON-BLOCKING: 1

FINDINGS:

Review basis: all 13 chapters, OUTLINE.md, MASTER-DOC-SCHEMA.md, and implementation evidence from all five named systems. References below are relative to the relevant repository unless an absolute path is given.

The mandated command, python3 scripts/handbook_spine.py, returned exit 0:
    chapters=13  canonical contracts=18
    findings=0

That result contributes no checker-reported blocking findings. It does not establish correctness: the checker missed deliberately introduced inconsistencies in independent, in-memory tests described in B07.

The chapters themselves declare 34 RED fields. Acknowledging a RED field is honest, but does not satisfy the schema’s completion gate.

B01 — OMISSION — M0–M8, M11, M12
Claim quoted: “RED — none” in the metrics sections.
Evidence: these chapters explicitly lack the metrics required by MASTER-DOC-SCHEMA.md:72–79. Source inspection confirms, for example, that scripts/lib.sh:5–11 emits print rows and a failure counter, dispatcher.py:112–120 writes logs, and cf-inference-proxy.py:83–101 writes capture/usage logs, not a metric contract.
Fix: retain these chapters as PARTIAL until the required observable metrics and their type, labels, question answered, and scrape location exist and are documented. Logging is not a substitute under this schema. Do not remove the RED designation merely because absence was documented.

B02 — UNVERIFIED — M0, M2, M3, M4, M5, M6, M9, M10, M12
Claim quoted: boundary contracts are the “honest terminal state, not a chapter defect”; several are nevertheless marked “works (external, client-side only).”
Evidence: examples include M2:89–96, M9:199–203, M10:131–134 and M12:95. Their support is an OUTLINE assertion or an unnamed external actor, not both implementations or a quoted verification result. The brief’s rules 1 and 2 provide no boundary exemption. scripts/handbook_spine.py:55–77 and :165–169 introduce one independently.
Fix: name each covered implementation, document the external evidence actually available, and leave unproven contracts UNVERIFIED and blocking. An acceptance exception must be authorized explicitly; chapters and their checker cannot grant it to themselves.

B03 — FALSE CLAIM — M10
Claim quoted: CT-08’s producer is “external — crier’s hermes-session forward … (out of scope)” and “neither side has an in-repo file:function” (M10:131).
Evidence: crier/internal/registry/dispatch.go:348–377 calls h.hermes.Deliver. crier/internal/hermesession/hermesession.go:353–405 implements Client.Deliver, including token acquisition, session selection, chat execution, and replay recording. This producer is inside a specifically covered repository.
Fix: name and describe the crier implementation. Keep only the gateway implementation beyond the boundary. Document that this transport bypasses the durable inbox, its session policies, replay behavior, and named failures; internal/registry/hermes_delivery.go:7–18 expressly defines that distinction.

B04 — OMISSION — M2, M9
Claim quoted: CT-05’s scheduler prompt consumer has “no in-repo file:function established for the prompt text” (M9:198).
Evidence: code-factory/scripts/load_lane_config.py:31–37 reads prompts/*.md and writes projects.prompt and prompt_mode. Scheduler internal/scheduler/spawn.go:1233–1260 implements buildForemanPrompt: namespace default or built-in base, project replace/append, then the dynamic footer.
Fix: trace the existing producer-to-store-to-consumer path. Document snapshot-versus-live-file semantics, append/replace precedence, and how an operator proves that changed prompt text reached a dispatch. “External” is not an adequate description of this covered path.

B05 — UNVERIFIED — M2, M3, M9
Claim quoted: M2 locates dispatch_wall at “:1152–1157”; M3 identifies land-node-branch.sh as “295 lines” and its push at “:265.”
Evidence: at the chapters’ own pinned code-factory revision 226ae37, node-bus-worker.py has 1,546 lines and land-node-branch.sh has 308. dispatch_wall is at node-bus-worker.py:1200–1205; :1152–1157 handles a harness refusal. The explicit push is land-node-branch.sh:278; :265 removes the merge log. M9:26 similarly locates the node’s status field at :1132, which is now dry-run output; the field is at :1180.
Fix: rebind locators to the stamped revision and verify what each cited range actually contains. These are not merely changes after the stated revision: the pinned files already have the newer layout.

B06 — FALSE CLAIM — M9
Claim quoted: “for a tasks-mode lane, admission requires an owned, readable, workable board … an empty workdir or non-owned board is a refusal” (M9:68–70).
Evidence: internal/scheduler/admission_mode.go:222–228 says this predicate controls the cooldown waiver; a non-owned or unreadable board falls back to cooldown pacing. packer_select.go:376–420 branches on that waiver, and :420–488 performs additional gates and the cooldown decision rather than unconditionally refusing the lane.
Fix: distinguish waiver denial from dispatch denial. Write the composed procedure, including builder/reporter exceptions, no-work gates, failure backoff, pacing, and cooldown fallback. The present wording leads an operator to expect a fail-closed admission boundary that this predicate does not provide.

B07 — UNBUILDABLE — M6
Claim quoted: the documentation gate “checks the structure” (M6:16), while the required spine claims that contract ends must agree and dangling references must be detected.
Evidence: scripts/handbook_spine.py accepts a bare filename as an implementation reference (:115–117), checks only whether some row has two file-looking cells (:170), and predeclares every M0–M12 reference valid regardless of chapter existence (:195). Independent in-memory mutations produced:
    unknown CT-99 contract: exit 0, findings=[]
    removed M8 chapter: exit 0, findings=[]
    substituted unrelated CT-03 implementation: exit 0, findings=[]
Its default normalizer also maps both backticked “origin” and “upstream” defaults to an empty string (:127).
Fix: document the spine in M6 and give it rejecting regression tests for unknown IDs, mismatched implementation pairs, missing referenced chapters, and distinct string defaults. Derive existence from actual documents rather than fixed valid-ID sets.

B08 — UNBUILDABLE — M6
Claim quoted: “The fill/render/panel pipeline is UNBUILDABLE against these M-numbered chapters” (M6:12).
Evidence: confirmed. master_doc_check.py:186–209 selects NN-*.md; master_doc_fill.py:422 does the same; gen_nasa_handbook.py:253–260 rejects an empty legacy selection; master_doc_panel.py:67–72 selects docs/master. Running the documented gate selected appendices/units and returned:
    44 module(s): 37 VERIFIED, 50 error(s), 0 warning(s), 10 fact(s)
    MASTER-DOC: FAIL
Fix: provide and exercise the chapter-aware selection, validation, fill, panel, and render path. An accurately described broken delivery mechanism remains a blocking delivery defect.

B09 — OMISSION — M1
Claim quoted: the settings register’s provisioning “config keys” row combines PROJECT, AGENT, SERVER, REPO, REF, HARNESS, credentials and other controls into one row (M1:102).
Evidence: that row supplies neither individual defaults nor individual consequences. Entire owned settings surfaces are missing from the register. For example, scripts/node_env.py:61–67 constrains agent.max_iterations to 1–100000 and gateway.port to 1–65535; :508–584 implements check/apply, unmanaged-variable handling, and file writes.
Fix: register each provisioning and environment control separately, including default/unset behavior, accepted values, precedence, reader, and operational consequence. A list of names plus “KEY=VALUE” does not satisfy rule 3.

B10 — OMISSION — M2
Claim quoted: “--harness-wall / --timeout” defaults are given only as DEFAULT_HARNESS_WALL / DEFAULT_TIMEOUT (M2:77).
Evidence: scripts/node-bus-worker.py:83–84 gives the actual defaults, 10 and 1800 seconds; :1491–1499 binds them to the CLI. Other controls, including --gateway-port at :1472–1476, are absent. scripts/load_lane_config.py:13–18 also reads SCHEDULER_DB and CODE_FACTORY_ROOT, neither registered.
Fix: publish resolved defaults and the complete CLI/environment surface. Distinguish enforced ranges from suggested safe values: several integer flags are parsed without a positive-value guard. Cross-referencing a fallback explanation is not a replacement for the default.

B11 — OMISSION — M5
Claim quoted: the Go dependency is simply “pinned” (M5:66); S3 includes install-go.sh and project-node.sh.
Evidence: scripts/install-go.sh:7–16 defines go1.26.5, architecture-specific digests, a 1 GiB disk floor, probe module/version, and GO_INSTALL_ROOT. These controls do not appear in M5’s settings register. The resolver also has a substantial CLI surface at harness_resolve.py:327–367 that the register does not describe.
Fix: complete the toolchain, node-entry, resolver, and adapter registers. Identify fixed constants separately from operator overrides, with their consequences. The shared CF_* table is not the whole module.

B12 — OMISSION — M9
Claim quoted: “Remaining 32 of the 57” controls have a consequence “not expanded per row” (M9:157–177).
Evidence: the chapter admits that these include execution-affecting controls. cmd/schedulerd/main.go:174–200 defines verification, session reaping, simulation, gateway routing, pricing, and auto-disable controls. Several defaults remain unresolved symbols, such as peer-freshness-window at M9:148.
Fix: give every control an individual default, accepted range, reader, and consequence. Cover the effective CLI/environment/TOML precedence and cross-field constraints, not just flag declarations. These entries remain NAME ONLY under the brief.

B13 — OMISSION — M10
Claim quoted: storage selection is described as controls whose custody proof “is not yet written” (M10:114–119).
Evidence: config/config.go:732–767 defines URL precedence, backend selection, SQLite-path precedence, and startup refusals. :770–808 defines pool controls and the min-connections ≤ max-connections constraint. None is presented as a complete settings register. Several existing rows give only “int,” “bytes,” or “duration” as their range.
Fix: write the backend/default/override decision table, startup prerequisites, pool constraints, and a readback proving which store actually owns custody. Specify real bounds and distinguish validation from recommendations.

B14 — OMISSION — M11
Claim quoted: the settings register ends with fleet-agent configuration (M11:68–80).
Evidence: dispatcher.py:38–40 additionally selects CRIER_URL, the bearer-token path, and the signing-key directory. These determine which bus is contacted and which identity authenticates. They are missing from the register, despite client construction at :130–132 and permanent per-agent exclusion after a construction failure at :417–433.
Fix: document endpoint and identity-source defaults, override/reload behavior, failure detection, and recovery. Explain how an operator restores polling for an agent whose client failed during startup.

B15 — UNVERIFIED — M7
Claim quoted: “mint not run” and the verification command “python3 scripts/github-app-token.py token …” (M7:12, :91).
Evidence: usage and compilation do not exercise mint, expiry, file installation, refresh/no-op behavior, or insecure-file rejection. The ellipsis is not an executable verification command. Relevant production behavior is implemented in github-app-token.py:362 onward, write_private at :636–653, and github-app-refresh.sh:104–174.
Fix: supply a complete secret-safe invocation and reproducible assertions. Separate local fake-API tests from an explicitly authorized real installation-token check. Until that evidence exists, keep the lifecycle UNVERIFIED and the chapter PARTIAL. I did not mint or rotate a real credential during this review.

B16 — UNVERIFIED — M1, M2, M3, M5, M11, M12
Claim quoted: “SHIPPED_LANDING_ARM_RC=0” (M3:119); “live-job tests … cannot fail” (M11:97); an “independent verifier” measured the SSE failure (M12:179–182).
Evidence: M3 does not provide the exact isolated-arm invocation that produced its custom result markers; tests/selftest.sh is a whole-suite script, not the documented named-arm selector. M11’s tests/test_durable_job.py:7–11 prints ok/output without checking them. M1/M2/M5 leave their live certification ladders unexecuted or host-specific. M12 cites a verifier but supplies no runnable verifier.
Fix: ship and reference executable probes with assertions and prerequisites. Record exact command, revision/hash, output, and result. My independent local proxy probe reproduced HTTP 200, absent framing headers, and an EOF TimeoutError; that confirms the defect, not the repeatability of the chapter’s cited evidence.

B17 — OMISSION — M1, M2, M5, M6, M7, M9, M10
Claim quoted: “remaining 377 sites are uncovered” (M9:238); guard logs “not yet tabulated” (M10:202).
Evidence: the schema requires every operator-visible line, verbatim, with its condition and classification. The omissions are explicitly admitted in M9/M10 and visible elsewhere: M1’s seed state machine describes “preserved …” messages absent from its log table, and M7’s table omits the minter’s terminal “GITHUB APP TOKEN: PASS” emitted at github-app-token.py:616–619.
Fix: derive the module-wide emitter inventory, not one-file samples or generic PASS/FAIL templates. Include structured fields, conditions, and operator action. Explicitly scoped incompleteness is still incompleteness.

B18 — OMISSION — M0–M12
Claim quoted: recovery entries such as “restore scripts/lib.sh” (M1:171), “re-run; investigate remote branch movement” (M3:151), and “check the upstream gateway” (M12:150).
Evidence: OUTLINE.md:125–127 requires an operator action and expected indication after each step. These entries provide neither executable diagnostic steps nor the readback distinguishing successful recovery from another self-report. Numerous entries merely name an OPEN defect.
Fix: turn failure rows into bounded procedures: symptom, discriminating check, safe action, expected observation, and escalation/stop condition. Retain unresolved defects as RED instead of treating their identifiers as recovery instructions.

B19 — OMISSION — M9
Claim quoted: “write authorities and recovery queries per table are not yet written” (M9:102), and “per-route request/response shapes and write-authority readbacks are not written” (M9:53–54).
Evidence: migrations.go establishes schema, not the complete durable-state protocol. internal/api/server.go:289–370 registers routes, not their methods, authorization requirements, payload validation, persistence, idempotency, or readback. These are core S3/S4 responsibilities, not optional package-level detail.
Fix: document the run-state writers, transitions, transaction/recovery boundaries and authoritative queries; then provide the operator API contracts and mutation readbacks. A table-name census and route-name census do not make these submodules written.

N01 — NON-BLOCKING — M4 — CONTRADICTION requiring snapshot reconciliation
Claim quoted: the stamped board measurement reports “357 rows / 515 events” and byte parity (M4:12, :106–117).
Evidence: this review measured 357 tasks and 518 events. boardctl validate returned RESULT: OK (7 warning(s)); board_drift returned RESULT: DRIFT (4 failed), with CF-270 pending locally versus complete in origin/main. The chapter explicitly describes its earlier result as point-in-time and requires remeasurement after merging, so this is not evidence that its historical observation was fabricated.
Fix: attach the final publication measurement with exact local and remote revisions. Do not carry the older PASS forward as current state.

Independent checks completed:
    Disk-floor tests: 12 passed.
    Reclaim tests: 9 passed.
    Harness-resolution tests: 28 passed.
    Lane-target tests: 40 passed, with global Git configuration isolated.
    Patch-chain verification: PASS.
    Scan-scope check: RESULT: OK, 15 claims.
    Legacy master-document gate: FAIL, 50 errors.
    Proxy source hash: matched the chapter.
    Live proxy unauthenticated POST: HTTP 401.
    Proxy service: active/running.
    Hermetic finite-SSE probe using the actual Handler: bytes forwarded, EOF timed out.
    Spine inconsistency probes: three incorrect clean results.

Verification limits: I did not rerun the full Go builds/test suites, provision or destroy nodes, run paid remote harness jobs, or mint credentials. Those historical PASS claims are not independently re-certified here. An additional staged shell-probe attempt was blocked by tool approval policy and is not counted as successful evidence. No reviewed repository or service was modified.

DEFECT CLASSES:
    Self-granted acceptance exemptions
    Unsupported contract-state claims
    Covered implementations mislabeled external
    Stale evidence locators
    Cooldown waiver confused with admission
    False-green consistency checking
    Disconnected document delivery pipeline
    NAME ONLY settings
    Nonrepeatable behavioral evidence
    Incomplete observability contracts
    Missing recovery readbacks
    Control-plane censuses substituted for protocols
    Moving-state snapshot drift

CHAPTER SCORECARD:

M0 — PARTIAL
    Useful helper inventory and source evidence; metrics remain RED and the one-sided external contract is not exempt from the stated gate.

M1 — PARTIAL
    Seed and certification behavior has substance; environment/provisioning settings, repeatable live certification, logs, and recovery procedures remain incomplete.

M2 — PARTIAL
    Directive decoding and settlement defects are described; stale locators, missing controls, unverified boundaries, and host-specific verification prevent WRITTEN.

M3 — PARTIAL
    Landing behavior has meaningful source and fixture coverage; locators are stale, isolated verification is not fully reproducible as cited, and metrics/recovery remain RED or incomplete.

M4 — PARTIAL
    Store validation and lock classification are useful; contract evidence remains incomplete, metrics are RED, and the final publication snapshot needs reconciliation.

M5 — PARTIAL
    Adapter differences and CF_* validation are documented; toolchain/resolver/node-entry settings and live conformance evidence are incomplete.

M6 — PARTIAL
    It honestly identifies broken legacy selection, but does not provide a working chapter delivery path or a consistency checker that rejects the required defect classes.

M7 — PARTIAL
    Credential domains and refresh controls are clearer; the mint lifecycle lacks executable verification, complete log coverage, metrics, and operational recovery evidence.

M8 — PARTIAL
    Fixed targets, TTL behavior, safety checks, and hermetic tests are substantial; mandatory metrics and recovery indications are still missing.

M9 — PARTIAL
    Settlement and several controls are well sourced; the admission procedure contains a material false claim, and settings, logs, durable-state authority, and API contracts remain incomplete.

M10 — PARTIAL
    Custody and guard behavior have useful detail; a covered session-delivery producer is wrongly excluded, while storage settings, metric contracts, and module-wide logs remain unfinished.

M11 — PARTIAL
    The main execution and replay paths are described in depth; behavioral tests lack a failure oracle, identity configuration is incomplete, and metrics/recovery remain insufficient.

M12 — PARTIAL
    Source hash and unauthenticated admission are reproducible, and the streaming defect is real; client/upstream contracts and the cited behavioral verification remain UNVERIFIED, with no metrics contract.

No chapter qualifies as WRITTEN under the supplied rules. None is merely a SKELETON: all contain substantive implementation-derived material. The failure is completion and evidence integrity, not absence of prose.

PANEL REVIEW COMPLETE

session_id: local-bd6bfeb522bb408abf6eab026252591f6241ff18800866224054ed924a349704

EXIT=0
```

