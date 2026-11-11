# 30. scripts/node_identity.py

| Field | Value |
|---|---|
| Path | `~/proj-wt-md-30d/scripts/node_identity.py` — 111 lines, two functions, `set_path` and `main` [scripts/node_identity.py:26] [scripts/node_identity.py:50] |
| Repository | `code-factory` |
| Revision | `d8c7796` — the `origin/main` tip every locator below was measured against on 2026-11-05 |
| Status | **VERIFIED — 18 measured checks in scratch directories; one defect proven by execution (§6 row 8: a merge that lands and then exits 1), and nine input shapes measured byte-for-byte** |

## 1. Purpose and why it matters

- **What it is:** the only code in this repo that ADDS fields to an existing `$HOME/.node/node.json` instead of writing it whole [scripts/node_identity.py:2]. The manifest itself is created by the node provisioner [scripts/project-node.sh:807] and is "the node's identity: a scheduler target names `node_id`" [specs/NODE.md:24]. This module exists because a second provisioner (`bunker-provision.sh`) also wants to record something in that file — the namespaces a node serves, and who provisioned it — and a wholesale rewrite there "would silently delete those fields and break every consumer" [scripts/bunker-provision.sh:516]. So the merge, not the manifest, is the module: dotted keys create nested objects, `key[]=` builds a JSON array, and existing keys are left alone [scripts/node_identity.py:26-47].
- **Who calls it, and how the call is shaped:** exactly one production caller. `bunker-provision.sh` stages the file onto the node and runs it over `bash -lc "python3 $HOME/node_identity.py $HOME/.node/node.json namespace=… 'duckbrain.namespaces[]=…' provisioned_by=… provisioned_at=… bus.base=…"` [scripts/bunker-provision.sh:522], then wraps the output in `sed 's/^/  ..    /'` [scripts/bunker-provision.sh:524] and reduces the result to a **status test only** — `if [ "$ident_rc" -eq 0 ]` [scripts/bunker-provision.sh:525]. The row text is for a human; the exit code is the contract. The repo's own battery also invokes it directly [tests/selftest.sh:2065] and *does* parse the text [tests/selftest.sh:2068].
- **What breaks if it is absent:** the identity stage cannot run, so `bunker-provision.sh` prints `  FAIL  node_json — could not stage node_identity.py` and returns 1 [scripts/bunker-provision.sh:531]. The node still has its manifest (written earlier by the provisioner) and still serves its project, but it cannot declare a *set* of DuckBrain namespaces, and `provisioned_by`/`provisioned_at` are never recorded — so a node's provenance is unanswerable from the node itself.
- **What breaks if it LIES:** the whole trust in its row. Every success line is the module's own claim about a file it just wrote [scripts/node_identity.py:103-106]; nothing re-reads the manifest to confirm the keys are there before printing. Two lies are reachable and both are measured: the docstring promises "existing keys keep their type" [scripts/node_identity.py:13], and §3 row 9 shows an existing integer `node_id` coming back as the **string** `"8"`; the docstring promises "nothing is removed" [scripts/node_identity.py:14], and §3 row 11 shows a scalar silently replaced by an object. A third failure is structural: the module cannot rotate or invalidate a key because it never touches key material (§2c) — so "an identity that silently rotates" is not this module's key failure mode, but "an *agent name* that silently changes" is (§6 row 1).
- **The brief's premise, corrected.** This script is not a keypair generator. A scan of all 111 lines for `ed25519`, `seed`, `private`, `public`, `openssl` and `sign` returns **nothing** (§3 row 14). The per-agent ed25519 key that crier verifies lives in a different file, is written by a different tool, and is described in §2c. What this module writes is the **JSON identity document** at mode 600 — no secret, no key, no signature.
- **Blast radius:** one node's manifest, plus every consumer that reads it — the bus worker resolves `agent`, `project`, `bus.base`, `repo.path` and `harness.cmd` out of this exact file [scripts/node-bus-worker.py:347], and the disk reclaim pass treats `.node/node.json` as protected [scripts/reclaim_disk.py:22].

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `python3` | any CPython 3 with f-strings (3.6+); the annotations are bare `dict`/`list`/`str`/`bool`, never subscripted [scripts/node_identity.py:26] [scripts/node_identity.py:50], so nothing here needs 3.9 | the node's `PATH`; the caller invokes it as a bare `python3` inside `bash -lc` [scripts/bunker-provision.sh:522] | **not detected by this module** — a missing interpreter means the `bash -lc` never reaches line 1. The caller sees a non-zero `$ident_rc` and prints `  FAIL  node_json — merge refused by the node (exit N)` [scripts/bunker-provision.sh:528]. Fails closed, with a message that blames the merge rather than the interpreter |
| POSIX filesystem with atomic same-directory `rename` | — | the manifest's own directory | `os.replace` raising; the module unlinks its temp file and re-raises [scripts/node_identity.py:95] |
| standard library only — `json`, `os`, `sys`, `tempfile` [scripts/node_identity.py:20-23] | bundled with the interpreter | — | cannot be absent on a CPython build |
| No network, no shell, no subprocess | — | — | nothing to detect: the module imports no socket and calls no `subprocess` |

Measured interpreter: `Python 3.14.4`. Nothing in the file probes its own version or refuses to run on an old one.

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `json.load` | stdlib | the file must parse as JSON **and** the top level must be a `dict`; anything else is refused by an explicit `isinstance` test, not by a parse error [scripts/node_identity.py:66] | a top-level array is already exercised: `FAIL  identity — … is not a readable JSON object (top level is not an object); left untouched`, rc 1 (§3 row 5). Duplicate keys inside one object collapse to the last occurrence, silently — the module never sees them |
| `json.dump` | stdlib | writes with `indent=1, sort_keys=True` [scripts/node_identity.py:92], so the output is key-sorted, one-space-indented, ASCII-escaped (`ensure_ascii` default), and a single trailing newline is appended by hand [scripts/node_identity.py:93] | the byte shape is the *only* thing that changes; every consumer parses JSON. Measured output is ASCII even for a `café` input, which arrives back as `caf\u00e9` (§3 row 13) |
| `open(path)` for the read | stdlib | **no `encoding=` argument** [scripts/node_identity.py:66] — decoding is the process locale's, which is the module's sharpest hidden dependency (§7) | under `LC_ALL=C` a UTF-8 manifest raises `'ascii' codec can't decode byte 0xc3 …`, is refused with rc 1, and is left untouched (§3 row 13). ASCII manifests are unaffected on the read side but not on the print side |
| `os.path.exists` / `os.path.abspath` / `os.makedirs` | stdlib | "absent" is decided by `exists` before the open [scripts/node_identity.py:64]; the temp file is placed in `dirname(abspath(path))` so the final rename never crosses a filesystem [scripts/node_identity.py:87] | the read-side `exists`→`open` pair is a TOCTOU window (§6 row 7). `makedirs(…, exist_ok=True)` creates missing parents at the process umask: measured `775` under `umask 002`, `755` under `022` |
| `os.chmod(tmp, 0o600)` then `os.replace(tmp, path)` | stdlib | mode 600 is set on the temp file **before** the rename [scripts/node_identity.py:94], so the manifest is never briefly world-readable, and replacing over an existing file carries the new mode, not the old one | measured: a `644` manifest becomes `600`, and so does a `640` one (§3 rows 1, 12). Nothing in the module ever relaxes the mode |
| `tempfile.mkstemp(dir=directory)` | stdlib | the temp file is created **next to the target**, not in `$TMPDIR` [scripts/node_identity.py:89] | measured with `TMPDIR=/nonexistent`: the merge still succeeds, because `TMPDIR` is never consulted (§3 row 12) |
| `sys.argv` / `print(…, file=sys.stderr)` / `sys.exit` | stdlib | the whole interface is positional argv; rows go to stdout [scripts/node_identity.py:104] and refusals to stderr [scripts/node_identity.py:53] | stderr's handler is `backslashreplace`, so under a non-UTF-8 locale the em dash in a refusal is escaped to `\u2014` — the row no longer matches its own shape (§7) |

### 2c. Service contracts — both sides of the signing contract named

This module signs nothing and verifies nothing. The contract it participates in is a **three-party** one, and the module owns the middle term only: the identity *string*.

| Side | Where it lives | What it does | Payload / interface |
|---|---|---|---|
| **The signer** | `scripts/node-bus-worker.py` — key read at [scripts/node-bus-worker.py:214], public half derived at [scripts/node-bus-worker.py:279], headers minted at [scripts/node-bus-worker.py:281] | loads a **PKCS#8 PEM ed25519** private key from `$HOME/.node/agent.key` [scripts/node-bus-worker.py:340], refuses anything that is not PKCS#8 with the ed25519 OID [scripts/node-bus-worker.py:234] [scripts/node-bus-worker.py:247], keeps the 32-byte seed in memory and "never prints or serialises" it [scripts/node-bus-worker.py:273] | `X-Agent-ID`, `X-Agent-Ts`, hex `X-Agent-Sig` over `<method>\n<path>\n<ts>` [scripts/node-bus-worker.py:283], optionally `X-Agent-Body-SHA256` |
| **The verifier** | crier, `internal/registry/agentsig.go`, `(*Handler).authorizeAgent` | verifies the per-agent signature **before** it looks the agent up, and requires the caller's `X-Agent-ID` to equal the target agent in the URL — an agent can only read its own inbox. Measured ladder on a live node: no bearer 401 / wrong bearer 401 / bearer only 401 / bearer+key 200 (fact: FACT-03) | 401 on a missing, empty, malformed or stale signature; 403 when the claimed identity is not the target; the registered public key is looked up from the agent record after the proof |
| **The joining term — this module** | [scripts/node_identity.py:37] | writes whatever `key=value` it is handed, including `agent=…`. The bus worker resolves the agent as `crier.json.agent → node.json.agent → --agent` [scripts/node-bus-worker.py:348] | a plain JSON string. **It is the name the verifier will demand a signature for; it is never the proof.** A wrong `agent=` therefore produces a manifest that is perfectly valid JSON, exits 0, and is rejected by the bus at request time (§6 row 1) |

The crier path carries no `file:line` locator on purpose: the gate resolves in-repo paths only, and an invented line number for an out-of-tree file would be exactly the kind of claim this document set exists to refuse. The verifier claim rests on `fact: FACT-03` and on the in-repo half of the ladder, [scripts/node-bus-worker.py:281].

Three consequences follow, and they are the reason this section is long:

1. **No key material is written here, so no key can be rotated here.** The rotation hazard the brief names is real but lives one file over: `agent.key` is written by the provisioning path, and `node_identity.py` can neither read, rewrite nor validate it. What this module *can* do is move the pointer: `agent=demo` today and `agent=cf-node` tomorrow is a silent identity change with no backup and no refusal (§3 row 10).
2. **The public key is derived, not stored, and printed in two different widths.** The seed is 32 bytes parsed out of the PEM; the public half is `ed25519_public_key(seed).hex()` [scripts/node-bus-worker.py:279] — 64 hex characters, printed in full in the `signing_key` row of `--check` [scripts/node-bus-worker.py:522] and truncated to 16 hex plus an ellipsis in the lighter path [scripts/node-bus-worker.py:1040]. The seed itself is printed by neither path. Not one of those bytes comes from this module.
3. **Mode 600 on the manifest is a policy, not a secret.** The file carries a bus URL, a repo path, a hostname and a namespace list — nothing a reader could authenticate with. The mode matches the repo's rule that credentials travel as files at 600 rather than as argv (fact: FACT-05), and it is a real improvement only in the sense measured in §3 row 12: the *other* writer creates the file at `644`.

## 3. Verification

Measured 2026-11-05 in worktree `~/proj-wt-md-30d` at `d8c7796`, against scratch directories under `$TMPDIR`, with the manifest path passed explicitly (the module reads no `HOME` — §7). Every command below was run as written.

| # | Check | Command | Expected | Result |
|---|---|---|---|---|
| 1 | merge into an existing manifest: byte shape and mode | fixture with `node_id/project/repo/harness/bus/created_by/created_at` at mode `644`, then `python3 scripts/node_identity.py <path> agent=cf-node namespace=demo 'duckbrain.namespaces[]=demo,coder' provisioned_by=bunker-provision` | rc 0, all seven original keys preserved, four added, mode 600 | **PASS** — rc 0; `644 271 bytes inode=34350197` → `600 447 bytes inode=34350200`; stdout `PASS  identity — merged agent, namespace, duckbrain.namespaces[], provisioned_by into …/node.json`; stderr empty; 11 keys, `duckbrain.namespaces` = `["demo","coder"]`, `harness.port` still the integer `8767` |
| 2 | **idempotence**, second identical run | same argv again after a 1.1 s pause | rc 0, content unchanged, the "already carries every value" row | **PASS on content, and the file is still rewritten** — `sha256` identical (`659c2744…f830e`), row `PASS  identity — … already carries every value (unchanged)`; **inode `34350200 → 34350207`**, mtime `…18.001 → …19.151`. "Unchanged" is a statement about the JSON, not the inode (§6 row 9) |
| 3 | file and parent absent | empty scratch tree, `python3 scripts/node_identity.py <home>/.node/node.json agent=cf-node repo.path=<home>/repo` | rc 0, parents created, file at 600 | **PASS** — rc 0, `PASS  identity — merged agent, repo.path into …`; `home` and `home/.node` created `775` (umask 002), manifest `600`, 105 bytes |
| 4 | unreadable JSON left untouched | `printf 'not json at all\n' > f`, capture `sha256sum`, run, re-capture | rc 1, identical bytes, message on stderr | **PASS** — rc 1; `FAIL  identity — …/home3.json is not a readable JSON object (Expecting value: line 1 column 1 (char 0)); left untouched`; `sha256` identical → untouched: YES |
| 5 | top-level array | `printf '[]\n' > f`, run | rc 1, named refusal | **PASS** — `FAIL  identity — … is not a readable JSON object (top level is not an object); left untouched`, rc 1 |
| 6 | bad argument, empty list, no arguments | `node_identity.py f noequalsign`; `node_identity.py f 'duckbrain.namespaces[]='`; `node_identity.py` | 2 / 2 / 2, nothing written | **PASS** — `FAIL  identity — argument is not key=value: noequalsign` rc 2; `FAIL  identity — duckbrain.namespaces[] was declared empty` rc 2; `usage: node_identity.py <path> key=value [key=value ...]` rc 2. The argv is validated **before** the manifest is read [scripts/node_identity.py:58], so a typo cannot half-write anything |
| 7 | list syntax: split, trim, duplicates | `'duckbrain.namespaces[]=demo, demo ,coder'` | three items, whitespace trimmed | **PASS, and duplicates survive** — stored `["demo","demo","coder"]`; the split strips each part [scripts/node_identity.py:30] but nothing dedupes (§6 row 6) |
| 8 | scalar values are not trimmed | `'label=  two  spaces  '` | stored verbatim | **PASS** — `label='  two  spaces  '` |
| 9 | **type of an existing key when it is overwritten** | fixture `{"node_id": 7, "harness": {"port": 8767}}`, then `node_id=8` | the docstring's "existing keys keep their type" [scripts/node_identity.py:13] implies an integer stays an integer | **FAIL against the docstring** — rc 0, `PASS  identity — merged node_id`, value now the **string** `"8"` (`type now: str`). Untouched keys keep their type (`harness.port` stayed `8767`); a named key is replaced by the string passed. Cause: `7 == "8"` is false, and the assignment is unconditional [scripts/node_identity.py:44] |
| 10 | re-pointing `agent` | merge `agent=cf-node`, then `agent=demo`, no backup | replaces in place, rc 0 | **PASS (the hazard is real)** — rc 0 both times, file holds the new value, no `.bak` anywhere. This is the identity change this module can perform: the name moves, the key that must sign for it does not |
| 11 | **scalar promoted to an object** | fixture `{"bus": "http://localhost:8767", "node_id": "h1"}`, then `bus.base=http://127.0.0.1:8767` | an existing scalar is preserved, or the collision is refused | **FAIL — silent destruction.** The `isinstance(node.get(part), dict)` test sees a string, assigns `{}` over it and descends [scripts/node_identity.py:40]; result `{"bus": {"base": "http://127.0.0.1:8767"}, "node_id": "h1"}` — `http://localhost:8767` is gone, rc 0, caller's row says "schema preserved" |
| 12 | mode is tightened on an already-loose file; `TMPDIR` is irrelevant | mode `640` manifest, then one merge; separately `HOME=/nonexistent TMPDIR=/nonexistent` with an absolute manifest path | 600 either way, merge still succeeds | **PASS** — `640 → 600`; and under both bogus variables the merge printed `PASS  identity — merged agent into …`, rc 0, mode 600, no temp file left behind |
| 13 | locale: UTF-8 manifest and ASCII manifest under `LC_ALL=C` | `LC_ALL=C LANG=C PYTHONUTF8=0 python3 scripts/node_identity.py u.json agent=cf-node`, then the same with an ASCII manifest | — | **defect, §6 row 8** — with a UTF-8 value the read fails (`'ascii' codec can't decode byte 0xc3 in position 15 …`), the refusal row itself is print-degraded to `FAIL  identity \u2014 …`, rc 1, file untouched. With an ASCII manifest the **merge lands** and the PASS print raises `UnicodeEncodeError: 'ascii' codec can't encode character '\u2014' in position 15` from [scripts/node_identity.py:104]: traceback, **rc 1 over a file that already carries the new key** |
| 14 | no key material in the module | `grep -nE 'ed25519|seed|private|public|openssl|sign' scripts/node_identity.py` | no match | **PASS** — no match (rc 1). Nothing to print, nothing to leak |
| 15 | concurrent merges | two parallel runs (`left=1`, `right=1`) against one manifest, 40 rounds, both keys checked after each `wait` | no lost key | **PASS measured, window real** — `rounds losing a key: 0 / 40`, final `{ "left": "1", "right": "1"}`. The code holds no lock (read at [scripts/node_identity.py:66], write at [scripts/node_identity.py:95]), so the lost-update window exists and simply did not open in 40 tries |
| 16 | durability of the rename | `strace -e trace=fsync,fdatasync,rename,chmod,fchmod` over one merge | — | **no fsync at all** — the syscall log is `chmod("…/tmpgt27ozu7", 0600) = 0` then `rename("…/tmpgt27ozu7", "…/j.json") = 0`. Atomic against process death, not against power loss (§6 row 9) |
| 17 | the repo's own regression arm | the three commands at [tests/selftest.sh:2064]–[tests/selftest.sh:2067], replayed verbatim: fixture, merge, read the list, merge again | `rc 0 / rc2 0`, `listed=demo,coder`, second row "already carries every value" | **PASS** — `rc=0 rc2=0 listed=demo,coder`; rows `PASS  identity — merged duckbrain.namespaces[] into …` and `PASS  identity — … already carries every value (unchanged)`. The arm itself [tests/selftest.sh:2068] was not run inside the full battery (that run is network-dependent); its commands were replayed exactly |
| 18 | syntax and shape | `python3 -m py_compile scripts/node_identity.py`; AST walk | rc 0, two functions | **PASS** — rc 0; `functions: ['set_path', 'main']`; 111 lines |

## 4. Metrics emitted

**None, and the reason is structural rather than an omission.** The module writes no counter, no metric file and no line protocol. Its entire output vocabulary is eight fixed sentences (§5), and its only persistent effect is the manifest itself. The one aggregate a caller can scrape is `$?` — three values, `0` merged / `1` unreadable / `2` bad argument [scripts/node_identity.py:16]. Its single production caller discards the text and branches on that integer [scripts/bunker-provision.sh:525], so "how many merges ran, and how many changed something" is answerable nowhere: the difference between "merged four keys" and "merged nothing" is two different sentences on stdout, neither persisted, the first consumed by a `sed` prefixer [scripts/bunker-provision.sh:524].

## 5. Log lines it can generate

Every line has a two-space gap after the tag, the word `identity` as the row name, and U+2014 as the separator — lib.sh's row *look* without lib.sh's counter [scripts/node_identity.py:60] [scripts/node_identity.py:106]. Success rows go to **stdout**, refusals to **stderr**.

| Level | Line (verbatim, as measured) | Format site | Emitted when | Kind |
|---|---|---|---|---|
| `PASS` | `PASS  identity — merged agent, namespace, duckbrain.namespaces[], provisioned_by into ~/.hermes/cache/scratch/md25b/p30/home/.node/node.json` | [scripts/node_identity.py:104] | at least one `key=value` differed from what the file held. The key list is in **argv order**, `[]` suffix included | evidentiary — the list is falsifiable: re-read the manifest and every named key holds the value that was passed |
| `PASS` | `PASS  identity — ~/.hermes/cache/scratch/md25b/p30/home/.node/node.json already carries every value (unchanged)` | [scripts/node_identity.py:106] | every `key=value` compared equal [scripts/node_identity.py:44] | evidentiary for its narrow claim, with a trap: "unchanged" describes the **JSON**, not the file — inode and mtime both move (§3 row 2) |
| `FAIL` (stderr) | `FAIL  identity — ~/.hermes/cache/scratch/md25b/p30b/z.json is not a readable JSON object (Expecting value: line 1 column 1 (char 0)); left untouched` | [scripts/node_identity.py:71] | the existing file did not parse, including the zero-byte case. The exception text is interpolated, so the tail varies by cause | evidentiary — "left untouched" is checkable with a hash, and was: identical before and after |
| `FAIL` (stderr) | `FAIL  identity — ~/.hermes/cache/scratch/md25b/p30b/home4.json is not a readable JSON object (top level is not an object); left untouched` | [scripts/node_identity.py:69] | the file parsed but was not a JSON object | evidentiary — same checkable claim |
| `FAIL` (stderr) | `FAIL  identity — ~/.hermes/cache/scratch/md25b/p30b/adir is not a readable JSON object ([Errno 21] Is a directory: '~/.hermes/cache/scratch/md25b/p30b/adir'); left untouched` | [scripts/node_identity.py:70] | the path is a directory or otherwise unreadable — one bare `except Exception` catches everything the `open`/`load` pair raises | evidentiary — the reason string is the OS's, which is why four different failures share one shape |
| `FAIL` (stderr) | `FAIL  identity — argument is not key=value: noequalsign` | [scripts/node_identity.py:60] | an argv has no `=`, or an empty key. Printed **before** the manifest is read | descriptive — a fact about the caller's argv, nothing about the node |
| `FAIL` (stderr) | `FAIL  identity — duckbrain.namespaces[] was declared empty` | [scripts/node_identity.py:32] | a `key[]=` value contained no non-blank items | descriptive |
| `usage` (stderr) | `usage: node_identity.py <path> key=value [key=value ...]` | [scripts/node_identity.py:52] | fewer than two arguments | descriptive |
| `Traceback` (stderr) | `UnicodeEncodeError: 'ascii' codec can't encode character '\u2014' in position 15: ordinal not in range(128)` | [scripts/node_identity.py:104] | a non-UTF-8 stdout encoding — the row cannot be encoded *after* the file was replaced (§3 row 13) | **anti-evidence** — the only line here that reports failure for work that succeeded |

Two shape facts are load-bearing. The battery greps the substring `already carries every value` [tests/selftest.sh:2068] and `declared empty` [tests/selftest.sh:2074], so the *sentences* matter in tests even though the production caller ignores them. And under `LC_ALL=C` the refusals' em dash is rewritten to the six ASCII bytes `\u2014` by stderr's `backslashreplace`, so a `grep '^FAIL  identity — '` over a collected log silently misses exactly the runs that happened under a cron locale.

## 6. Failure modes

Direction is stated as **does the run end up green when it should not** (fails OPEN) or **red when the work was fine** (fails CLOSED).

| Failure | Presents as | Direction | Distinguished from / recovery |
|---|---|---|---|
| 1. A wrong or changed `agent=` | rc 0, `PASS  identity — merged agent`, a manifest that parses and looks complete | **fails OPEN** — the merge is green and the node is deaf: the bus verifier requires `X-Agent-ID` to be the target agent and to match the registered key, and refuses before any lookup (fact: FACT-03). The failure surfaces later, at the first signed read, as 401/403 with nothing pointing back at this merge | distinguish by comparing the manifest's `agent` with the agent the bus holds a key for — the module will never say. Recovery: rewrite with `agent=` and re-verify through the worker's `--check`, whose `signing_key` row prints the public key [scripts/node-bus-worker.py:522] |
| 2. `project-node.sh --apply` runs **after** this merge | its own `  PASS  manifest …/node.json` row [scripts/project-node.sh:817], rc 0; the merged keys are simply gone | **fails OPEN, and measured** — the manifest writer dumps a fresh dict of seven keys [scripts/project-node.sh:807] and does not merge. Replayed on a merged manifest: keys went from `[agent, bus, created_at, created_by, duckbrain, harness, namespace, node_id, project, provisioned_by, repo]` to `[bus, created_at, created_by, freshness, harness, node_id, project, repo]` — `agent`, `namespace`, `duckbrain`, `provisioned_by` deleted, mode still 600 | the two writers are ordered by the provisioning sequence, not by any code. Distinguish by grepping the manifest for `duckbrain` after a re-provision. Recovery: run the identity stage last, or re-run it; a node whose `agent` vanished falls back to `crier.json.agent` [scripts/node-bus-worker.py:348] and may still answer, which is why this can hide for weeks |
| 3. An existing key of another type is overwritten | rc 0, `merged node_id`, the value now `"8"` where `7` was | **fails OPEN on type** — JSON consumers that compare numerically (`harness.port`, a `node_id` counter) get a string and either coerce silently or raise far away | measured §3 row 9. Untouched keys keep their type; only named keys are coerced. Recovery: do not pass keys the provisioner owns — the module has no notion of ownership |
| 4. A dotted key collides with an existing scalar | rc 0, `merged bus.base`, the scalar silently replaced by an object | **fails OPEN, destructive** — measured: `"bus": "http://localhost:8767"` became `{"bus":{"base":"…"}}` (§3 row 11), no warning, no backup | only a before/after diff notices; the row says nothing. Recovery: keep dotted keys on paths the provisioner does not also write as scalars — never `bus.base=` on a manifest whose `bus` is a string |
| 5. Manifest is unparseable, a directory, or empty | rc 1, one `FAIL  identity — … is not a readable JSON object (…); left untouched` | **fails CLOSED, correctly** — measured with bytes unchanged (§3 rows 4-5) | distinguish "refused" from "wrote nothing for another reason" by re-reading the file: this refusal is the only path that guarantees untouched bytes. The caller relays it as `  FAIL  node_json — merge refused by the node (exit 1)` [scripts/bunker-provision.sh:528] |
| 6. Duplicate items in a `[]` list | stored twice: `["demo","demo","coder"]` | **fails OPEN on content** — a namespace list is a set semantically; anything counting entries over-counts, and the caller passes `NAMESPACES` through unchecked [scripts/bunker-provision.sh:522] | measured §3 row 7. Recovery: dedupe where the comma list is composed |
| 7. Two merges at once | both rc 0, one key missing from the final file | **fails OPEN if it happens** — read [scripts/node_identity.py:66], modify in memory, replace [scripts/node_identity.py:95], with no lock and no compare-and-swap; the read is also an `exists`→`open` TOCTOU [scripts/node_identity.py:64] | measured 0 losses in 40 rounds (§3 row 15), so the window is narrow rather than absent. Distinguish by the absence of a key another provisioner claims to have written. Recovery: serialise the callers — the module offers no lease |
| 8. Non-UTF-8 locale with an ASCII manifest | `Traceback … UnicodeEncodeError: 'ascii' codec can't encode character '\u2014'`, **rc 1**, manifest already carrying the new key | **fails CLOSED over a landed write — a false failure.** The replace happens at [scripts/node_identity.py:95], the row is encoded at [scripts/node_identity.py:104], and the exception exits 1 | measured §3 row 13: the traceback, rc 1, and `{ "agent": "cf-node", "node_id": "h1"}` on disk. The caller turns it into `node_json — merge refused (exit 1)` and fails the run for a merge that succeeded. Recovery: re-run under a UTF-8 locale — the second run is idempotent and prints the honest row |
| 9. Power loss after the write, before or after the rename | no file change, or a manifest whose bytes are newer than the disk | **fails OPEN on durability** — `strace` shows `chmod`, `rename`, and no `fsync`/`fdatasync` anywhere (§3 row 16) [scripts/node_identity.py:91]. Atomic against *process* death (the temp file is unlinked on exception [scripts/node_identity.py:96]) but not against an unclean host | distinguish a lost write from a refused one: a refusal leaves the old bytes *and* prints `left untouched`; a lost write leaves the old bytes and says nothing, because the process died before printing. Recovery: re-provision; nothing detects this |
| 10. A key with an empty path segment | rc 0, `merged a..b`, and the manifest gains `{"a": {"": {"b": "1"}}}` | **fails OPEN** — nothing validates key grammar; `.x=1`, `x.=1` and `a..b=1` all succeed and create empty-string field names (§3 row 7, same probe) | the manifest is valid JSON, so every consumer parses it and none finds what it asked for. Distinguished only by knowing the intended key shape. Recovery: fix the argv; there is no dry-run to catch it first |
| 11. `path` is a symlink into a repo or a backup | rc 0; the symlink is replaced by a regular file, the target untouched | **fails OPEN on topology** — `os.replace` replaces the directory entry, it does not follow it [scripts/node_identity.py:95]. Measured: `link still a symlink: NO`, target unchanged | a manifest meant to be a link to a checked-in file stops being one, and the next reader gets a stale copy. Recovery: re-create the link; chmod is already 600 on the real file |

## 7. Environment and settings it reads

- **argv, and nothing else.** One path plus one or more `key=value`. There is no flag, no `--dry-run`, no config file, no default path: the module never constructs `$HOME/.node/node.json` itself — the *caller* does [scripts/bunker-provision.sh:522]. Measured: `HOME=/nonexistent TMPDIR=/nonexistent` with an absolute path merged normally (§3 row 12). The scratch `HOME` in these probes was therefore only a place to put fixtures; `HOME` is not an input to this program.
- **The manifest path as given, echoed back verbatim.** The PASS row prints `path` — the argv string — while the temp file and rename use `abspath` [scripts/node_identity.py:87]. Measured: a relative `n.json` printed `PASS  identity — merged project into n.json`; an unterminated path (`new/deep/n.json`) created both missing directories at `775`. Two different strings for one file appear in the same run if the caller passes a relative path.
- **`umask`** — it does not touch the manifest (mode is `chmod`ed explicitly, `0o600` [scripts/node_identity.py:94]) but it governs every directory the module creates: measured `775` under the host's `umask 002`. The writer that creates the manifest *file* [scripts/project-node.sh:807] leaves it at `644` (measured), which the first merge then tightens to `600`.
- **`TMPDIR`** — not read. `tempfile.mkstemp(dir=directory)` places the temp file beside the target [scripts/node_identity.py:89], which is also what makes the rename atomic; measured with `TMPDIR` pointing at a non-existent directory, the merge still succeeded.
- **Locale / `PYTHONUTF8` / `LC_ALL`** — read implicitly by the bare `open(path)` [scripts/node_identity.py:66] and by the stdout encoder at [scripts/node_identity.py:104]. Measured two ways under `LC_ALL=C LANG=C PYTHONUTF8=0`: a UTF-8 manifest is refused (`'ascii' codec can't decode byte 0xc3 …`), and an ASCII manifest merges and then crashes printing the row, leaving rc 1 over a written file (§3 row 13). The least obvious environment dependency and the only one that can invert a result.
- **Streams** — rows to stdout, refusals to stderr (§5). A `2>/dev/null` capture shows `PASS` lines only; the caller's `2>&1` capture [scripts/bunker-provision.sh:522] is the only way to see both, and it then re-prefixes every line with `  ..    ` [scripts/bunker-provision.sh:524].
- **No terminal awareness** — no colour, no `isatty`, no `TERM`. The rows are the same bytes in a log as on a console, apart from the locale caveat above.
- **Filesystem semantics** — same-directory `rename` (atomic replace), plus the ability to `chmod` and `unlink`. A read-only directory fails at `mkstemp` [scripts/node_identity.py:89] and the exception propagates as a traceback, not as a row: that is the one failure this module does not phrase.

## 8. Evidence of record

- Revision: worktree `~/proj-wt-md-30d`, branch `wt/md-30d`, based on `origin/main` at `d8c7796`. `scripts/node_identity.py` is byte-identical to that tree (111 lines, `py_compile` rc 0).
- The merge and the byte shape behind §3 rows 1-2, mode and inode included:

  ```
  $ stat -c '%a %s inode=%i' node.json
  644 271 inode=34350197
  $ python3 scripts/node_identity.py node.json agent=cf-node namespace=demo \
        'duckbrain.namespaces[]=demo,coder' provisioned_by=bunker-provision; echo rc=$?
  PASS  identity — merged agent, namespace, duckbrain.namespaces[], provisioned_by into …/home/.node/node.json
  rc=0
  $ stat -c '%a %s inode=%i' node.json
  600 447 inode=34350200
  $ python3 scripts/node_identity.py node.json agent=cf-node namespace=demo \
        'duckbrain.namespaces[]=demo,coder' provisioned_by=bunker-provision; echo rc=$?
  PASS  identity — …/home/.node/node.json already carries every value (unchanged)
  rc=0
  # content identical: YES   inode: 34350200 -> 34350207   mtime: …18.001 -> …19.151
  ```

- The landed-then-failed defect (§3 row 13, §6 row 8), verbatim:

  ```
  $ LC_ALL=C LANG=C PYTHONUTF8=0 python3 scripts/node_identity.py a.json agent=cf-node; echo rc=$?
  Traceback (most recent call last):
    File "…/scripts/node_identity.py", line 111, in <module>
      sys.exit(main(sys.argv[1:]))
    File "…/scripts/node_identity.py", line 104, in main
      print(f"PASS  identity \u2014 merged {', '.join(changed)} into {path}")
  UnicodeEncodeError: 'ascii' codec can't encode character '\u2014' in position 15: ordinal not in range(128)
  rc=1
  $ tr -d '\n' < a.json; echo
  { "agent": "cf-node", "node_id": "h1"}
  ```

- Durability, the whole syscall footprint of one merge (§3 row 16):

  ```
  chmod("…/tmpgt27ozu7", 0600) = 0
  rename("…/tmpgt27ozu7", "…/j.json") = 0
  ```

  No `fsync`, no `fdatasync`, no directory sync.

- The other writer's effect (§6 row 2), keys before and after replaying [scripts/project-node.sh:807]:

  ```
  after the merge:           ['agent','bus','created_at','created_by','duckbrain','harness',
                              'namespace','node_id','project','provisioned_by','repo']  mode 600
  after the manifest writer: ['bus','created_at','created_by','freshness','harness',
                              'node_id','project','repo']                              mode 600
  ```

- Re-run the set: every command is in §3 and each is self-contained — `S=$(mktemp -d)` plus a one-key fixture reproduces rows 1-12 with no network, and row 17 is `tests/selftest.sh`'s own block [tests/selftest.sh:2064].
