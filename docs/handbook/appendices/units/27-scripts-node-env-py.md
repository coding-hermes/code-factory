# 27. scripts/node_env.py

| Field | Value |
|---|---|
| Path | `~/code-factory/scripts/node_env.py` — 589 lines [scripts/node_env.py:1] |
| Repository | `code-factory` [scripts/node_env.py:1] |
| Revision | `e7cf075` — the `origin/main` tip every locator below was measured against; the file's own last-touching commit is `a05667c` ("feat(node): a node's environment becomes declared data — env profile + config patches, diffed before applied") |
| Status | **VERIFIED — 271 locators, all resolve; facts cited** |

## 1. Purpose and why it matters

- What it is: the **applier** of a declared environment profile onto one node. One profile in, two files out — the variables in `~/.hermes/.env` and five scalars in `~/.hermes/config.yaml` [scripts/node_env.py:2-8]. It is a line-editor, not a renderer: it rewrites the lines it owns and copies every other line through byte for byte [scripts/node_env.py:301] [scripts/node_env.py:382-383].
- Why it exists: the node's environment was hand-edited state — "it cannot be reviewed, diffed or re-applied, so a rebuilt node is a different node" [scripts/node_env.py:6-8]. The fix is to make it declared data: a profile with one declaration per line, comments with `#`, and nothing else accepted [scripts/node_env.py:10-16].
- The three outcomes are distinct by exit code, and this is the module's whole contract: `0` the node matches, `1` it drifts, `2` the declaration itself is refused — "unreadable profile, a non-ENV line, a literal secret, an unknown config path, a value out of range" [scripts/node_env.py:24-28].
- What it refuses, and why a refusal is the point: a secret-named key carrying a literal value [scripts/node_env.py:179-186]; a profile line that is not `ENV_<NAME>=<value>` [scripts/node_env.py:225-230]; a duplicate declaration [scripts/node_env.py:232-237]; a non-existent, empty, multi-line or unreadable `@<path>` [scripts/node_env.py:187-206]; a `--config-set` path outside the five the harness reads [scripts/node_env.py:252-256]; an integer outside its bounds [scripts/node_env.py:259-268]. The refusal messages never echo a value for a secret-named key, because the value is scrubbed before printing [scripts/node_env.py:82-87] [scripts/node_env.py:90-92].
- The secret rule is a credential rule, not a formatting preference: "A literal secret in a file that is committed, copied and logged is a credential leak with a friendly name (AGENTS.md rule 8, CF-002)" [scripts/node_env.py:15-17], which is the fleet's standing rule that credentials travel as file paths at mode 600, never as argv values [docs/master/_facts.md:16] (fact: FACT-05). The applier implements the file half of it: `@<path>` reads the value off the node [scripts/node_env.py:192-199], and both target files are forced to mode 600 [scripts/node_env.py:433] [scripts/node_env.py:441].
- What breaks if this module is ABSENT: provisioning cannot declare a node's environment at all. `bunker-provision.sh` copies it to the node immediately before the apply step and, if the copy fails, prints `  FAIL  env_profile — could not stage node_env.py` and marks the run failed [scripts/bunker-provision.sh:424-436]. On the control host the same absence kills the pre-flight lint, which shells it against an empty `HOME` before any host is touched [scripts/bunker-provision.sh:141-155]. The behaviour the README promises — the environment a node runs with is "declared in `config/node.env.example` and applied by `scripts/node_env.py` before the harness layer starts" [README.md:101-102] — would simply not happen. Only one other script writes that file — `install-gitreins.sh` appends its own single key `CODING_HERMES_CO_AUTHOR` at mode 600 [scripts/install-gitreins.sh:150-157] — and a line like that is precisely what this module reports as `WARN unmanaged:` instead of deleting [scripts/node_env.py:547-555].
- What breaks if it LIES: the caller trusts the exit code and nothing more. A zero exit produces `  PASS  env_profile — declared environment applied (a second run reports no change)` [scripts/bunker-provision.sh:428-430]; no later step re-reads `~/.hermes/.env` or `config.yaml` to confirm what landed. An applier that silently skipped a key, or wrote it into the wrong file, would be reported as applied, and the only evidence to the contrary would be a gateway that starts with the old model.
- Blast radius: one node's `$HOME`. That node then runs every lane of its project — one bunker serves one project and every lane of that project enters it [docs/master/_facts.md:13] (fact: FACT-02) — so a wrong `gateway.bind` or a missing proxy key is not one process's problem, it is the project's.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `python3` | 3.14.9 measured here; the file imports only stdlib and uses no syntax newer than f-strings, so the floor is 3.6 — nothing below 3.14.9 was exercised | On the node, executed as `python3 $HOME/node_env.py` by the provisioner [scripts/bunker-provision.sh:426] | The suite compiles the file explicitly and FAILs the run if it does not [tests/selftest.sh:2396-2397]; the caller's `case` on the exit code marks anything but 0/1/2 as `node_env.py --check exited $rc on the declaration` [scripts/bunker-provision.sh:152] |
| A readable profile file (optional) | n/a — one `ENV_<NAME>=<value>` per line | Anywhere on the node; the caller stages the operator's copy as `$HOME/node.env` [scripts/bunker-provision.sh:416-417] | A missing file is a named refusal, not a crash: `cannot read the profile <path> (<strerror>)`, exit 2 [scripts/node_env.py:211-217] |
| `$HOME` | n/a | The environment of the process | Unset `HOME` is refused before anything is opened: `HOME is unset — the paths this applies to are unknown`, exit 2 [scripts/node_env.py:495-499] |
| No network, no socket, no subprocess, no database | — | — | Measured by reading the whole file: `grep -c` returns `0` for `socket`, `subprocess`, `urllib` and `import time`; the only I/O is four reads [scripts/node_env.py:193] [scripts/node_env.py:212] [scripts/node_env.py:282] [scripts/node_env.py:333] and the atomic rewrite [scripts/node_env.py:426-441] |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `json` [scripts/node_env.py:39] | stdlib | `json.dumps` as the quoting function for a value that has to be escaped in `.env` or YAML [scripts/node_env.py:143] [scripts/node_env.py:155], and as the *rendering* of a value in a diff row [scripts/node_env.py:113] [scripts/node_env.py:122]; `json.loads` to un-double-quote an existing `.env` value [scripts/node_env.py:129] | A different quoting rule silently changes the bytes written into a file the shell and the YAML reader must both parse; the failure would surface as a harness that cannot read its own `.env`, not as an exception here |
| `os` [scripts/node_env.py:40] | stdlib | `environ.get("HOME")` [scripts/node_env.py:495]; `path.join` for the two target paths [scripts/node_env.py:500-501]; `path.expanduser` for a leading `~/` in an `@<path>` [scripts/node_env.py:190-191]; `path.lexists` to decide whether a write is needed [scripts/node_env.py:566] [scripts/node_env.py:571]; `makedirs(mode=0o700)`, `fdopen`, `chmod`, `replace`, `unlink`, `stat` [scripts/node_env.py:426-452] | Any one of these is the atomicity story: `os.replace` is what makes a half-written `.env` impossible [scripts/node_env.py:434] |
| `re` [scripts/node_env.py:41] | stdlib | Eight compiled patterns, each a closed grammar: secret *names* `KEY\|TOKEN\|SECRET\|PASS` [scripts/node_env.py:50]; profile lines [scripts/node_env.py:51]; `.env` lines, with an optional `export ` prefix [scripts/node_env.py:52]; a YAML section and its children [scripts/node_env.py:53-54]; the safe-to-write-unquoted alphabets for `.env` and YAML [scripts/node_env.py:55-56]; an unsigned integer [scripts/node_env.py:57] | Widening `PROFILE_LINE` admits script syntax into a data file [scripts/node_env.py:229]; widening `SECRET_NAME` refuses more names; widening `SAFE_ENV` writes values a shell would mis-split |
| `sys` [scripts/node_env.py:42] | stdlib | `argv[1:]` as the whole input surface [scripts/node_env.py:588]; `sys.stdout` as the default row stream and `sys.stderr` for refusals [scripts/node_env.py:90-96] | The caller captures `2>&1` and reads both together [scripts/bunker-provision.sh:147], so a stream swap would be invisible there while breaking any operator who separates them |
| `tempfile` [scripts/node_env.py:43] | stdlib | `mkstemp(dir=<target dir>, prefix=".node-env-")` — a sibling temp file, so the `os.replace` at [scripts/node_env.py:434] stays on one filesystem and therefore atomic | A temp file on another filesystem turns `os.replace` into a non-atomic copy, and the cleanup branch [scripts/node_env.py:435-440] would leave `.node-env-*` litter in `~/.hermes` |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| `scripts/bunker-provision.sh` pre-flight lint | caller → applier | argv + captured `stdout`/`stderr` + exit status, run locally against a `mktemp -d` home [scripts/bunker-provision.sh:147] | `--env-file <profile> --config-set k=v ... --check` [scripts/bunker-provision.sh:145] | `env_lint()` in the caller [scripts/bunker-provision.sh:141-155]; `parse_args` / `main` in the applier [scripts/node_env.py:459-506]. The caller treats `0` **and** `1` as a good declaration (drift is what an empty home is) and `2` as a config error [scripts/bunker-provision.sh:149-153] |
| `scripts/bunker-provision.sh` on-node apply | caller → applier | `bunker cp` then `bunker exec -- bash -lc "python3 $HOME/node_env.py --apply …"`, output folded into rows [scripts/bunker-provision.sh:416-436] | the staged profile as `$HOME/node.env` plus `--config-set` pairs quoted by `shq` | same applier, `main` [scripts/node_env.py:490-584]. Success is asserted purely from the exit code [scripts/bunker-provision.sh:428-430] |
| The declaration format itself | operator → profile file | plain text, one line per declaration, `#` comments [scripts/node_env.py:10-16] | `ENV_<NAME>=<value>` or `ENV_<NAME>=@<path>`; and `CONFIG_SET_*` keys that the caller maps to the five dotted paths [scripts/bunker-provision.sh:126-136] | The shipped template documents the same grammar and the same allow-list and is what an operator copies [config/node.env.example:8-13] [config/node.env.example:25-32] |
| `~/.hermes/config.yaml` | applier → harness | line edit of one leaf scalar at a time [scripts/node_env.py:393-403] | only `model.provider`, `model.name`, `gateway.bind`, `gateway.port`, `agent.max_iterations` [scripts/node_env.py:61-67] | The harness reads those keys at gateway start; the applier's own docstring is explicit that "any other path is refused by name rather than invented" [scripts/node_env.py:19-22] |
| `tests/selftest.sh` §43 | test → applier | subprocess with `env -i HOME=<scratch> PATH=$PATH` [tests/selftest.sh:2403] | the nine refusal/apply/idempotence legs | The suite, which asserts exit codes, the masked secret, mode 600 and sha256 equality across two runs [tests/selftest.sh:2428-2516] |

## 3. Verification

Run on 2026-11-05 in a clean worktree of `e7cf075` (`~/proj-wt-md-27b`), Python 3.14.9, entirely under `$TMPDIR/ne27-canon` with `HOME` pointed at a scratch directory — no real node environment and no `~/.node` was touched. `$W` below is `$TMPDIR/ne27-canon`, `$N` is `$W/node`.

| # | Check | Command | Expected | Last run | Result |
|---|---|---|---|---|---|
| 1 | The gate itself | `python3 scripts/master_doc_check.py docs/master --only 27- --strict` [scripts/master_doc_check.py:110-144] | `MASTER-DOC: PASS`, exit 0 | 2026-11-05 | **PASS** |
| 2 | The suite's own legs for this module (9 of them) | extracted §43 verbatim, `tests/selftest.sh:2396-2516`, run standalone with the suite's `say`/`fails` stubs | every line `  PASS  …`, `FAILS=0` | 2026-11-05 | **PASS** |
| 3 | Absent profile | `run --env-file $W/absent.env --check` [scripts/node_env.py:211-217] | named `FAIL  env — cannot read the profile …`, exit 2 | 2026-11-05 | **PASS** |
| 4 | Inline secret is refused and never echoed | `run --env-file $W/inline.env --check` [scripts/node_env.py:179-186] | `looks secret and carries a literal value`, names the key, does not contain the value, exit 2 | 2026-11-05 | **PASS** |
| 5 | Unknown `--config-set` path | `run --config-set logging.level=debug --check` [scripts/node_env.py:252-256] | names the path and the five allowed ones, exit 2 | 2026-11-05 | **PASS** |
| 6 | `--check` is read-only | `run --env-file … --config-set … --check` [scripts/node_env.py:558-563] | `ENV: DRIFT (4)`, exit 1, `$N/.hermes` still absent | 2026-11-05 | **PASS** |
| 7 | `--apply` writes both files at mode 600 and keeps unowned lines | same declaration with `--apply` [scripts/node_env.py:565-575] | `ENV: APPLIED (5 change(s))`, exit 0, `600`/`600`, comment and unmanaged line still present | 2026-11-05 | **PASS** |
| 8 | Second `--apply` is a byte-identical no-op | same command again [scripts/node_env.py:580-584] | `ENV: PASS — already matches (no change)`, exit 0, both sha256 unchanged | 2026-11-05 | **PASS** |
| 9 | A mode of 644 is corrected without touching content | `chmod 644` then `--apply` [scripts/node_env.py:444-453] [scripts/node_env.py:569-575] | `  ..    corrected ~/.hermes/.env to mode 600`, exit 0, `600` after | 2026-11-05 | **PASS** (with the wording defect in §8) |
| 10 | A `config.yaml` this editor cannot model | `--config-set gateway.port=10800 --check` against `gateway: something` [scripts/node_env.py:352-356] | a named refusal and exit 2 | 2026-11-11 | **PASS — named refusal, exit 2; CF-239 fixed** |

```
$ python3 scripts/master_doc_check.py docs/master --only 27- --strict
27-scripts-node-env-py.md                      VERIFIED   ok

1 module(s): 1 VERIFIED, 0 error(s), 0 warning(s), 10 fact(s) in the ledger
MASTER-DOC: PASS

$ run --env-file "$W/absent.env" --check
  FAIL  env — cannot read the profile ~/.hermes/cache/scratch/md25b/ne27-canon/absent.env (No such file or directory)
rc=2

$ printf "ENV_CF_PROXY_API_KEY=scratch-inline-0001\n" > inline.env; run --env-file inline.env --check
  FAIL  env — inline.env:1: ENV_CF_PROXY_API_KEY looks secret and carries a literal value — declare ENV_CF_PROXY_API_KEY=@<path-on-the-node> instead
rc=2

$ run --config-set logging.level=debug --check
  FAIL  config — unknown config path 'logging.level' — allowed: agent.max_iterations, gateway.bind, gateway.port, model.name, model.provider
rc=2

$ run --env-file node.env --config-set model.provider=cf-proxy --config-set gateway.port=10800 --check
node-env --check — home=~/.hermes/cache/scratch/md25b/ne27-canon/node
  ..    env ~/.hermes/cache/scratch/md25b/ne27-canon/node/.hermes/.env, config ~/.hermes/cache/scratch/md25b/ne27-canon/node/.hermes/config.yaml
  ..    declared 2 env var(s), 2 config key(s)
  DIFF  env:CF_PROXY_API_KEY — <absent> -> *** (masked)
  DIFF  env:MODEL_NAME — <absent> -> "scratch-model"
  DIFF  config:model.provider — <absent> -> "cf-proxy"
  DIFF  config:gateway.port — <absent> -> 10800
ENV: DRIFT (4)
rc=1
[ -d $N/.hermes ] -> absent

$ run --env-file node.env --config-set model.provider=cf-proxy --config-set gateway.port=10800 --config-set gateway.bind=0.0.0.0 --apply
node-env --apply — home=~/.hermes/cache/scratch/md25b/ne27-canon/node
  ..    env ~/.hermes/cache/scratch/md25b/ne27-canon/node/.hermes/.env, config ~/.hermes/cache/scratch/md25b/ne27-canon/node/.hermes/config.yaml
  ..    declared 2 env var(s), 3 config key(s)
  DIFF  env:CF_PROXY_API_KEY — <absent> -> *** (masked)
  DIFF  env:MODEL_NAME — <absent> -> "scratch-model"
  DIFF  config:model.provider — "openrouter" -> "cf-proxy"
  DIFF  config:gateway.port — <absent> -> 10800
  DIFF  config:gateway.bind — <absent> -> "0.0.0.0"
  WARN  unmanaged:LEFTOVER_VAR — present in the node's .env, not declared here (value masked)
  ..    1 unmanaged var(s) would carry forward on a re-provision
  ..    wrote ~/.hermes/cache/scratch/md25b/ne27-canon/node/.hermes/.env (2 change(s), mode 600)
  ..    wrote ~/.hermes/cache/scratch/md25b/ne27-canon/node/.hermes/config.yaml (3 change(s), mode 600)
ENV: APPLIED (5 change(s))
rc=0
[mode] .env=600 config.yaml=600
$ cat .env
  # operator notes
  LEFTOVER_VAR=carry-forward
  CF_PROXY_API_KEY=scratch-secret-0001
  MODEL_NAME=scratch-model
$ cat config.yaml
  agent:
    max_iterations: 40
  model:
    provider: cf-proxy
    name: old-model

  gateway:
    port: 10800
    bind: 0.0.0.0

$ run ... --apply   # second time
node-env --apply — home=~/.hermes/cache/scratch/md25b/ne27-canon/node
  ..    env ~/.hermes/cache/scratch/md25b/ne27-canon/node/.hermes/.env, config ~/.hermes/cache/scratch/md25b/ne27-canon/node/.hermes/config.yaml
  ..    declared 2 env var(s), 3 config key(s)
  PASS  env:CF_PROXY_API_KEY — matches (***)
  PASS  env:MODEL_NAME — matches ("scratch-model")
  PASS  config:model.provider — matches ("cf-proxy")
  PASS  config:gateway.port — matches (10800)
  PASS  config:gateway.bind — matches ("0.0.0.0")
  WARN  unmanaged:LEFTOVER_VAR — present in the node's .env, not declared here (value masked)
  ..    1 unmanaged var(s) would carry forward on a re-provision
ENV: PASS — already matches (no change)
rc=0
[sha256 run1]
5bb014a836a51f4444e41934bf88e769de4a888c2af3b0bf1d8a1a43b13d9150  ~/.hermes/cache/scratch/md25b/ne27-canon/node/.hermes/.env
882b375760df22a8740d7a5335e950c031b98fe4467eb6c3ef592523c1055165  ~/.hermes/cache/scratch/md25b/ne27-canon/node/.hermes/config.yaml
[sha256 run2]
5bb014a836a51f4444e41934bf88e769de4a888c2af3b0bf1d8a1a43b13d9150  ~/.hermes/cache/scratch/md25b/ne27-canon/node/.hermes/.env
882b375760df22a8740d7a5335e950c031b98fe4467eb6c3ef592523c1055165  ~/.hermes/cache/scratch/md25b/ne27-canon/node/.hermes/config.yaml
[identical] yes

$ chmod 644 .env; run ... --apply   # content already matches
  ..    1 unmanaged var(s) would carry forward on a re-provision
  ..    corrected ~/.hermes/cache/scratch/md25b/ne27-canon/node/.hermes/.env to mode 600
ENV: PASS — already matches (no change)
rc=0
[mode now] 600

$ printf "gateway: something\n" > bad/.hermes/config.yaml; run --config-set gateway.port=10800 --check
Traceback (most recent call last):
  File "~/proj-wt-md-27b/scripts/node_env.py", line 589, in <module>
    sys.exit(main(sys.argv[1:]))
             ~~~~^^^^^^^^^^^^^^
  File "~/proj-wt-md-27b/scripts/node_env.py", line 509, in main
    config_out, config_changes = plan_config(config_lines, assigns)
                                 ~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^
  File "~/proj-wt-md-27b/scripts/node_env.py", line 417, in plan_config
    out, current, changed = set_scalar(out, path, value)
                            ~~~~~~~~~~^^^^^^^^^^^^^^^^^^
  File "~/proj-wt-md-27b/scripts/node_env.py", line 385, in set_scalar
    start, end = section_span(lines, section)
                 ~~~~~~~~~~~~^^^^^^^^^^^^^^^^
  File "~/proj-wt-md-27b/scripts/node_env.py", line 352, in section_span
    raise Refusal(
    ...<3 lines>...
    )
Refusal: gateway: at line 1 carries an inline value this editor does not model — reconcile it by hand
rc=1
```

The two runs in check 8 are the idempotence evidence: the applier rewrites only a line whose value actually differs [scripts/node_env.py:313-315] and only the leaf it was told to own [scripts/node_env.py:393-403], so the second pass produces an empty change list and the final line is `ENV: PASS — already matches (no change)` rather than `ENV: APPLIED (0 change(s))` [scripts/node_env.py:580-584].

## 4. Metrics emitted

**NONE.** The file has no counter, histogram, gauge, timer, exporter or span: `grep -c` returns `0` for `logging`, `logger`, `metric`, `prometheus` and `import time`, and the complete output surface is eight `print` sites — two row printers [scripts/node_env.py:90-100], the usage block [scripts/node_env.py:466], the header [scripts/node_env.py:510], and the four terminal verdict lines [scripts/node_env.py:560-583]. No log level, destination or retention exists anywhere in this path.

Why none is appropriate: the module runs twice per node lifetime (once in the caller's pre-flight lint on the control host, once as the apply on the node) [scripts/bunker-provision.sh:147] [scripts/bunker-provision.sh:426], so there is no rate, queue depth or latency to instrument. The only quantity worth counting — how many declarations were refused, how often a node drifted — is not knowable from the applier's own output, because nothing persists it: the verdict goes to the caller's captured buffer and then to a terminal [scripts/bunker-provision.sh:426-432]. An operator answering "how often does this refuse?" has to re-derive it from provisioning transcripts; there is no store this document can point at.

## 5. Log lines it can generate

Paths in the rows below read `/home/agent`; the measured instance of each — with the real scratch path — is in the §3 transcript. Every line is emitted through three printers — `row()` for `PASS`/`DIFF`/`WARN`/`FAIL` rows [scripts/node_env.py:90-92], `note()` for the `..` lines [scripts/node_env.py:99-100], and bare `print` for the verdict [scripts/node_env.py:560-583]. All of them pass through `redact()` except the four terminal verdicts [scripts/node_env.py:82-87].

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| header | `node-env --apply — home=/home/agent` | first line of every successful run, after parsing [scripts/node_env.py:510] | descriptive — names the mode and the home the two paths are derived from |
| note | `  ..    env ~/.hermes/.env, config ~/.hermes/config.yaml` | always, immediately after the header [scripts/node_env.py:511] | descriptive — the two exact paths, which is how an operator sees a wrong `HOME` |
| note | `  ..    declared 2 env var(s), 3 config key(s)` | always [scripts/node_env.py:512] | descriptive — the input's size; the caller greps this exact shape with `sed -n 's/^  \.\.    declared /declared /p'` [scripts/bunker-provision.sh:150] |
| PASS | `  PASS  env:CF_PROXY_API_KEY — matches (***)` | a declared key already holds the declared value; a secret-named key renders `***` [scripts/node_env.py:529-533] [scripts/node_env.py:107-113] | evidentiary — per-key, and the only positive proof that the key was compared rather than skipped |
| PASS | `  PASS  config:gateway.port — matches (10800)` | a config scalar already matches; an integer renders unquoted [scripts/node_env.py:116-122] [scripts/node_env.py:545] | evidentiary |
| DIFF | `  DIFF  env:MODEL_NAME — <absent> -> "scratch-model"` | a declared env key is absent or differs [scripts/node_env.py:523-527] | evidentiary — `describe()` prints `<absent>` for a key that is not in the file, so "missing" and "different" are distinguishable |
| DIFF | `  DIFF  env:CF_PROXY_API_KEY — <absent> -> *** (masked)` | a secret-named key drifts; the row says only present/absent, never the value [scripts/node_env.py:519-521] | evidentiary — deliberately weaker than the other rows |
| DIFF | `  DIFF  config:model.provider — "openrouter" -> "cf-proxy"` | a config scalar differs [scripts/node_env.py:535-543] | evidentiary |
| WARN | `  WARN  unmanaged:LEFTOVER_VAR — present in the node's .env, not declared here (value masked)` | a key exists in `~/.hermes/.env` that the profile does not declare [scripts/node_env.py:547-553] | descriptive — a warning about carry-forward, explicitly **not** drift [scripts/node_env.py:30-33]; the value is always masked, even for a non-secret name — `install-gitreins.sh`'s `CODING_HERMES_CO_AUTHOR` is the live example of such a key [scripts/install-gitreins.sh:150-157] |
| note | `  ..    1 unmanaged var(s) would carry forward on a re-provision` | once, when the unmanaged set is non-empty [scripts/node_env.py:554-555] | descriptive |
| note | `  ..    wrote ~/.hermes/.env (2 change(s), mode 600)` | `--apply` rewrote a file [scripts/node_env.py:568] | evidentiary — names the file, the change count and the mode |
| note | `  ..    corrected ~/.hermes/.env to mode 600` | `--apply` found the content already correct but the mode not 600 [scripts/node_env.py:569-570] [scripts/node_env.py:444-453] | evidentiary |
| verdict | `ENV: DRIFT (4)` | `--check` found any drift, exit 1 [scripts/node_env.py:558-561] | evidentiary — the count, on stdout |
| verdict | `ENV: APPLIED (5 change(s))` | `--apply` closed drift, exit 0 [scripts/node_env.py:580-581] | evidentiary |
| verdict | `ENV: PASS — already matches (no change)` | `--apply` found nothing to change, exit 0 [scripts/node_env.py:582-583] | evidentiary — this is the idempotence signal; note it is printed even when the mode was just corrected, §8 |
| verdict | `ENV: PASS — declared environment matches` | `--check` found no drift, exit 0 [scripts/node_env.py:562-563] | evidentiary |
| FAIL | `  FAIL  env — cannot read the profile /tmp/x/absent.env (No such file or directory)` | the profile cannot be opened [scripts/node_env.py:211-217], printed to **stderr** [scripts/node_env.py:95-96] | evidentiary — the caller lifts it into a row with `sed -e 's/^  FAIL  env — //'` [scripts/bunker-provision.sh:151] |
| FAIL | `  FAIL  env — inline.env:1: ENV_CF_PROXY_API_KEY looks secret and carries a literal value — declare ENV_CF_PROXY_API_KEY=@<path-on-the-node> instead` | a secret-named key with a literal value [scripts/node_env.py:179-186] | evidentiary — names the file and line, and states the fix |
| FAIL | `  FAIL  config — unknown config path 'logging.level' — allowed: agent.max_iterations, gateway.bind, gateway.port, model.name, model.provider` | a `--config-set` path outside the five [scripts/node_env.py:252-256] | evidentiary — the allow-list is generated from the table, so it cannot go stale by hand [scripts/node_env.py:68] |
| FAIL | `  FAIL  config — gateway.port: 70000 is outside 1..65535` | an integer outside its bounds [scripts/node_env.py:262-267] | evidentiary |
| usage | `usage: node_env.py --env-file <profile> [--config-set <dotted.key>=<value> ...] --check\|--apply` | `-h`/`--help`, exit 0 [scripts/node_env.py:465-467] | descriptive |

## 6. Failure modes

Direction is the module's own behaviour: **fail closed** means the run stops with exit 2 and neither file is written (both writes happen after every check [scripts/node_env.py:565-575]); **drift** means exit 1 because the declaration was valid and the node disagreed.

| Failure | Presents as | Direction | Distinguished from | Recovery |
|---|---|---|---|---|
| A secret-named key carries a literal value | `  FAIL  env — inline.env:1: ENV_CF_PROXY_API_KEY looks secret and carries a literal value — declare ENV_CF_PROXY_API_KEY=@<path-on-the-node> instead`, exit 2 [scripts/node_env.py:179-186] | **fail closed** — raised while the profile is parsed, before the two target files are even read [scripts/node_env.py:493] [scripts/node_env.py:502-503] | The `@`-form's own failures name a path, not a value [scripts/node_env.py:195-201] | put the value in a file on the node at mode 600 and declare `@<path>` — the fleet rule for credentials [docs/master/_facts.md:16] (fact: FACT-05) |
| A profile line is not `ENV_<NAME>=<value>` (e.g. `export FOO=bar`) | `  FAIL  env — script.env:1 is not ENV_<NAME>=<value> — a profile is data, never a script`, exit 2 [scripts/node_env.py:225-230] | **fail closed** — the profile is refused whole, not line by line | The node's own `.env` **does** tolerate an `export ` prefix [scripts/node_env.py:52]; only the profile grammar [scripts/node_env.py:51] is strict, so a working `.env` copied into a profile is refused | drop the `export` and any shell syntax |
| The same name is declared twice | `  FAIL  env — dup.env:2 declares ENV_A twice (first at line 1)`, exit 2 [scripts/node_env.py:232-237] | **fail closed** — no last-wins here, deliberately unlike `--config-set` [scripts/node_env.py:271-273] | `--config-set` repeats silently take the last value [scripts/bunker-provision.sh:126-127] | delete the earlier line |
| `@<path>` names nothing, an empty file, a directory or a multi-line file | `… ENV_TOK=@/tmp/x/nope cannot be read (No such file or directory)` / `… is empty` / `… cannot be read (Is a directory)` / `… holds more than one line — an env value cannot`, each exit 2 [scripts/node_env.py:192-206] | **fail closed** — an `@<path>` whose file is empty is refused, so a secret never lands as an empty variable (a *literal* empty value is allowed and written as `NAME=`, measured) | Four distinct messages, all prefixed with `<profile>:<line>` [scripts/node_env.py:177-207] | place the file at mode 600 on the node; the value must be exactly one line |
| `--config-set` names a path outside the five | `  FAIL  config — unknown config path 'logging.level' — allowed: …`, exit 2 [scripts/node_env.py:252-256] | **fail closed** — the key is refused by name rather than invented, which is the module's stated rule [scripts/node_env.py:19-22] | A syntactically invalid *value* for an allowed path has its own wording [scripts/node_env.py:257-270] | use one of the five [scripts/node_env.py:61-67] |
| An integer is out of range or not an integer | `gateway.port: 70000 is outside 1..65535` / `gateway.port: 'abc' is not an integer` / `gateway.port: '+5' is not an integer`, exit 2 [scripts/node_env.py:261-267] | **fail closed, and never clamped** — the bounds are a refusal, not a trim | The grammar is `^[0-9]+$` [scripts/node_env.py:57], so a leading `+` or `1e3` is a syntax error, while `0100` is accepted and written as `100` (measured) | pass a plain decimal inside the bounds |
| The node drifts from a valid declaration | `ENV: DRIFT (4)`, rows for each key, exit 1, nothing written [scripts/node_env.py:558-561] | **fail closed for the check** (non-zero) but *not* a refusal — exit 1 is the valid-and-different code | Exit 2 means the declaration was refused; the two must not be conflated [scripts/node_env.py:24-28] | rerun with `--apply`, or run `--apply` twice and compare |
| A `config.yaml` section is unmodellable (`gateway: value`) or appears twice | `  FAIL  config — gateway: at line 1 carries an inline value this editor does not model — reconcile it by hand` or `  FAIL  config — gateway: appears twice (lines 1 and 3)`, both exit 2; the plan phase is inside the shared `Refusal` handler [scripts/node_env.py:352-361] [scripts/node_env.py:504-509] | **fixed** — the run stops with a named row and exit 2, distinct from `--check` drift exit 1 | Every refusal is a single `  FAIL` row on stderr with exit 2 [scripts/node_env.py:95-96] [scripts/node_env.py:504-509] | fix or delete the offending section by hand; CF-239 is closed by the handler placement |
| The two target files are not mode 600 | `--check` prints `ENV: PASS — declared environment matches` and exits 0 with no mention of mode; only `--apply` corrects it and then says `  ..    corrected ~/.hermes/.env to mode 600` [scripts/node_env.py:444-453] [scripts/node_env.py:569-575] | **silently permissive on `--check`** — a read-only run cannot report the permission state it is asked about, because `--check` returns at [scripts/node_env.py:558-563] before any `stat` | Content is the only node state `--check` compares; permissions are never examined | run `--apply`; the correction rewrites mode only, never content |
| An existing `.env` line is duplicated (`A=1` then `A=2`) | Only the **last** occurrence is rewritten; the earlier line survives untouched (measured: declaring `A=3` yielded `A=1` then `A=3`) [scripts/node_env.py:303-320] | **fail open, silently** — the applier reports one change and leaves a shadowed stale line behind | `env_values` reads last-wins [scripts/node_env.py:291-297], so `--check` stays green whatever the consumer does with the first occurrence | de-duplicate `~/.hermes/.env` by hand; the applier will not delete a line it does not own [scripts/node_env.py:30-33] |
| `HOME` is unset | `  FAIL  env — HOME is unset — the paths this applies to are unknown`, exit 2 [scripts/node_env.py:495-499] | **fail closed** — no default home is guessed | Every other path failure names the path it tried [scripts/node_env.py:216] | export `HOME`; the caller always sets it explicitly [scripts/bunker-provision.sh:147] [scripts/bunker-provision.sh:426] |
| A write fails (permissions, full disk) | `  FAIL  env — cannot write the node's environment (<strerror>)`, exit 2 [scripts/node_env.py:576-578] | **fail closed**, and the temp file is unlinked so no partial file is left [scripts/node_env.py:435-440] | A refusal before the write never mentions writing | fix the directory; a partially written target is impossible because the write is `mkstemp` + `os.replace` [scripts/node_env.py:429-434] |

## 7. Environment and settings it reads

The module has **no configuration file of its own** and no compiled-in defaults for any value it writes: every setting arrives as an argument or as `$HOME`. What it *reads* as settings is therefore short and total.

| Setting | Where read | Default | Validation / refusal rule |
|---|---|---|---|
| `HOME` (env) | `os.environ.get("HOME", "")` [scripts/node_env.py:495] | none — absence is fatal | Empty is refused with a named row and exit 2 [scripts/node_env.py:496-499] |
| `$HOME/.hermes/.env` (derived) | `os.path.join(home, ".hermes", ".env")` [scripts/node_env.py:500] | file need not exist | Absent → `[]` and every declared key is a `DIFF` from `<absent>` [scripts/node_env.py:284-285]; unreadable → exit 2 [scripts/node_env.py:286-287] |
| `$HOME/.hermes/config.yaml` (derived) | `os.path.join(home, ".hermes", "config.yaml")` [scripts/node_env.py:501] | file need not exist | Absent → `[]` and a declared section is appended [scripts/node_env.py:335-336] [scripts/node_env.py:387-392] |
| `--env-file <path>` | `parse_args` [scripts/node_env.py:473-478] | empty, i.e. no env declarations | Unreadable, a directory, or absent → exit 2 [scripts/node_env.py:211-217]; a profile must contain only `ENV_<NAME>=<value>` lines and `#` comments [scripts/node_env.py:221-230] |
| `--config-set <dotted.key>=<value>` | `parse_args`, repeatable [scripts/node_env.py:473-480] | empty | No `=` → exit 2 [scripts/node_env.py:248-251]; a repeated path takes the **last** value [scripts/node_env.py:271-273] |
| `--check` / `--apply` | [scripts/node_env.py:468-472] | none — one is required | Both together → `only one of --check and --apply` [scripts/node_env.py:469-471]; neither → exit 2 [scripts/node_env.py:483-484]; `-h` prints usage and exits 0 [scripts/node_env.py:465-467] |
| At least one of the two inputs | [scripts/node_env.py:485-486] | — | `nothing declared — pass --env-file and/or --config-set`, exit 2 |
| Any other argument | [scripts/node_env.py:481-482] | — | `unknown argument: <arg>`, exit 2 |
| `agent.max_iterations` | the allow-list [scripts/node_env.py:62] | no default written | integer, `1..100000` [scripts/node_env.py:62]; out of range → exit 2 [scripts/node_env.py:264-267]; written unquoted as an integer [scripts/node_env.py:147-148] |
| `gateway.bind` | [scripts/node_env.py:63] | no default written | any non-empty string without a control character [scripts/node_env.py:257-258] [scripts/node_env.py:269-270]; quoted only when it is not a safe YAML scalar [scripts/node_env.py:146-155] |
| `gateway.port` | [scripts/node_env.py:64] | no default written | integer `1..65535` [scripts/node_env.py:64] |
| `model.name` | [scripts/node_env.py:65] | no default written | non-empty, no control character |
| `model.provider` | [scripts/node_env.py:66] | no default written | non-empty, no control character |
| Env names it will accept | `PROFILE_LINE` [scripts/node_env.py:51] | — | `[A-Za-z_][A-Za-z0-9_]*`, declared as `ENV_<NAME>`; anything else is not a profile line [scripts/node_env.py:225-230] |
| Names that must use `@<path>` | `SECRET_NAME` = `KEY\|TOKEN\|SECRET\|PASS`, case-insensitive [scripts/node_env.py:50] | — | A literal value for such a name is refused [scripts/node_env.py:179-186]; `_SECRET_VALUES` then scrubs that value from every subsequent row [scripts/node_env.py:70] [scripts/node_env.py:82-87] |
| Values that get quoted in `.env` | `SAFE_ENV` [scripts/node_env.py:55] | unquoted when safe | Anything outside `[A-Za-z0-9_./:@+~%,=-]`, empty, or starting with `#` is `json.dumps`-quoted [scripts/node_env.py:138-143] — measured: `hello world # not a comment` landed as `GREETING="hello world # not a comment"` |
| Values that get quoted in YAML | `SAFE_YAML` [scripts/node_env.py:56] | unquoted when safe | Also refused unquoted if it starts with a YAML indicator or ends with `:` [scripts/node_env.py:149-155] |
| File mode it lands with | `write_atomic` [scripts/node_env.py:426-441] | — | temp file `chmod 600` before replace [scripts/node_env.py:433] and the target `chmod 600` after [scripts/node_env.py:441]; the containing directory is created `0o700` [scripts/node_env.py:428]; an existing file that is not 600 is corrected on `--apply` [scripts/node_env.py:444-453] |
| Lines it may touch | `plan_env` / `set_scalar` [scripts/node_env.py:300-325] [scripts/node_env.py:382-410] | — | only declared keys and declared leaves; a trailing comment on a YAML leaf is preserved but re-spaced to one space [scripts/node_env.py:398-403] (measured); nothing is deleted, ever [scripts/node_env.py:30-33] |

## 8. Evidence of record

- **Measured 2026-11-05**, in a clean worktree of `e7cf075` (`~/proj-wt-md-27b`), Python 3.14.9. Every run used `env -i HOME=<scratch> PATH=$PATH`, so no real node environment existed in the process and no `~/.node` path was read [scripts/node_env.py:495-501]. The transcripts in §3 are literal output; `$W` is `$TMPDIR/ne27-canon`.
- **Suite coverage**: §43 of `tests/selftest.sh` is this module's gate — it compiles the file [tests/selftest.sh:2396-2397], builds a `mktemp -d` node with a mode-600 secret file [tests/selftest.sh:2399-2401], and asserts, in order: absent profile refused by name [tests/selftest.sh:2405-2411]; inline secret refused **and not echoed** [tests/selftest.sh:2413-2421]; inline and duplicated config sections refused by named rows with line numbers; unknown `CONFIG_SET` path refused with the allow-list named [tests/selftest.sh:2423-2428]; `--check` diagnostic, masked and strictly read-only — the suite even asserts `~/.hermes` was never created [tests/selftest.sh:2430-2440]; `--apply` leaves the operator's own lines intact and both files at 600 [tests/selftest.sh:2442-2469]; a second `--apply` with identical sha256 and a `WARN unmanaged:` line [tests/selftest.sh:2471-2480]; `--check` green afterwards with unmanaged vars alone not counting as drift [tests/selftest.sh:2482-2487]; and the provisioner folding an inline secret into a named `env_profile` FAIL [tests/selftest.sh:2489-2514]. Extracted verbatim and run standalone, all eleven legs print `  PASS  …` with `FAILS=0`.
- **Contract coverage from the caller**: the pre-flight lint runs the applier against a `mktemp -d` home *before any host is touched*, and treats `0` and `1` as an acceptable declaration because an empty home must drift [scripts/bunker-provision.sh:143-153]; the on-node apply stages the profile and the script, runs `python3 $HOME/node_env.py --apply`, folds the rows into the transcript and then deletes both staged files whatever the outcome [scripts/bunker-provision.sh:437-441].
- **Defects measured while filling this section:** CF-239 is fixed in this revision; the plan phase now shares the CLI's `Refusal` handler, so the two config-section refusals produce named rows and exit 2. The remaining observations below are unchanged and not part of this fix.

  1. **A plan-phase refusal was previously outside the CLI handler.** Before CF-239, `plan_config` sat after the `try` and the refusals at [scripts/node_env.py:352-361] escaped as a traceback with exit 1. The handler now encloses both planning calls [scripts/node_env.py:504-509], preserving the distinct refusal/ drift/clean outcomes and the provisioner's named failure path [scripts/bunker-provision.sh:432].
  2. **`--check` cannot see a wrong mode, and `--apply` calls the correction "no change".** `--check` returns at [scripts/node_env.py:558-563] before any `stat`, so a `.env` at 644 is reported `ENV: PASS — declared environment matches` with exit 0 (measured). `--apply` then corrects the mode [scripts/node_env.py:569-570] and still prints `ENV: PASS — already matches (no change)` [scripts/node_env.py:582-583], while the note two lines above says it changed something — a file whose content is identical but whose permissions were just rewritten is not "no change", and the idempotence claim the caller repeats back to the operator [scripts/bunker-provision.sh:430] inherits the imprecision. **Not yet filed.**
  3. **A duplicated pre-existing `.env` line is left half-rewritten.** Only the last occurrence of a key is indexed [scripts/node_env.py:303-306], so declaring `A=3` over a file holding `A=1` then `A=2` produced `A=1` then `A=3`; `env_values` reads last-wins [scripts/node_env.py:291-297], so `--check` is green and the stale first line is invisible to the tool from then on. It is consistent with the "never delete state it does not own" rule [scripts/node_env.py:30-33], but it means the applier cannot guarantee the file has one value per key. **Not yet filed.**
  4. **Grammar asymmetry between the profile and the node's `.env`.** `ENV_LINE` strips an optional `export ` prefix [scripts/node_env.py:52], `PROFILE_LINE` does not [scripts/node_env.py:51]; a working `.env` pasted into a profile is refused at [scripts/node_env.py:225-230]. Defensible (the profile is data), but undocumented in the template, which says only "one declaration per line" [config/node.env.example:8-9]. **Not yet filed.**

- **Per-unit assertion — what is measured and what is not:**

| Unit | Assertion |
|---|---|
| `parse_args`, all argument refusals [scripts/node_env.py:459-487] | **measured** — probe run: no mode → `one of --check or --apply is required`, exit 2; both modes → `only one of --check and --apply`, exit 2; `--bogus` → `unknown argument: --bogus`, exit 2; `--check` alone → `nothing declared — pass --env-file and/or --config-set`, exit 2; `-h` → the usage line, exit 0 |
| `read_profile` / `read_secret` refusals [scripts/node_env.py:177-242] | **measured** — absent profile, inline secret, non-ENV line, duplicate declaration, missing / empty / two-line / directory `@path` |
| `parse_config_sets` bounds [scripts/node_env.py:245-274] | **measured** — `70000` out of range, `abc`, `+5`, `1e3`, missing `=`, control character, repeat-last-wins, `0100` → `100` |
| `plan_env` in-place rewrite and append [scripts/node_env.py:300-325] | **measured** — unowned lines preserved, appended lines newline-safe, no-trailing-newline file repaired, `export` form rewritten without the prefix, empty value written as `NAME=` |
| `plan_config` / `set_scalar` leaf edit [scripts/node_env.py:382-420] | **measured** — leaf rewritten with its comment preserved, section appended when absent, unrelated sections byte-identical across a re-apply |
| `write_atomic` and `ensure_mode` [scripts/node_env.py:426-453] | **measured** — mode 600 on both files, directory 700 on first creation, sha256 unchanged on the second apply, 644 corrected without a content write |
| Idempotence, the headline property | **measured** — two consecutive `--apply` runs, `sha256sum` equal on both files, exit 0, `ENV: PASS — already matches (no change)`; independently asserted by the suite at [tests/selftest.sh:2471-2480] |
| `config.yaml` shapes this editor cannot model [scripts/node_env.py:341-373] | **measured as broken** — traceback and exit 1, defect 1 above |
| Behaviour when the harness itself races the applier (a gateway holding an open `config.yaml`) | **not measured** — the rewrite is atomic but nothing was run against a live gateway; the caller applies this *before* the harness layer starts, by design [scripts/bunker-provision.sh:406-411] |
| Windows / non-POSIX path semantics | **not measured** — the module targets a Linux bunker node [scripts/node_env.py:2] and nothing was run off Linux |
