# 11. scripts/disk_floor.py

| Field | Value |
|---|---|
| Path | `~/code-factory/scripts/disk_floor.py` — 175 lines [scripts/disk_floor.py:1] |
| Repository | `code-factory` [scripts/disk_floor.py:1] |
| Revision | `f63acd3` — the `origin/main` tip every locator below was measured against; the file's own last-touching commit is `3b2c81e` (2026-11-03, ruff-format sweep) and it was introduced by `222a8b0` ("feat: lane workdir targets and configurable node disk floors") |
| Status | **VERIFIED — 113 distinct locators (212 citations), all resolve; facts cited** |

## 1. Purpose and why it matters

- What it is: a **resolver**, not a checker. It measures nothing; it returns the pair `(gib, source)` from an ordered chain [scripts/disk_floor.py:115-141]. The measurement lives in the caller: `free_gb` shells out to `df -Pk` [scripts/lib.sh:32] and `require_disk` compares free space against the returned floor [scripts/lib.sh:35-44].
- Why a resolver and not a constant: the floor is operator policy — roles differ in footprint, hardware differs in capacity, and the module's own docstring argues a fixed 5 GiB is wrong on both a small worker and a full builder [scripts/disk_floor.py:4-8]. The requirement and its measured rationale sit on board row **CF-007**: "4.3 GB free inside an agent on a host at 97%, while one repo node costs ~1.5 GB". The board is append-only [docs/master/_facts.md:20] (fact: FACT-09), so rows are cited by id and not by line number; the id lookup and its verbatim output are in §8.
- The rule it serves: **N-5** — a node refuses to start work below the disk floor, and says the number [specs/NODE.md:107].
- What breaks if this module is ABSENT: every admission path that needs a number fails closed, before any install. The ladder refuses a missing or unreadable resolver with a named row and exit 1 [scripts/project-node.sh:166-170], and the control host refuses to stage a manifest that omits it (`missing scripts/disk_floor.py`) [scripts/node-create.sh:25-26]. The suite's negative control deletes the file from a staged copy and asserts exactly one `  FAIL  disk_floor — resolver missing or unreadable:` row plus `NODE: FAIL (1)` [tests/selftest.sh:685-694].
- Absence has already been paid for once: row **CF-075** (now closed) records that `node-create.sh` staged `project-node.sh` **without** `scripts/disk_floor.py`, so every documented node creation died on its first line; the fix is the staged-set validator at [scripts/node-create.sh:25-26].
- What breaks if it LIES: nothing downstream re-derives the number. The ladder parses `floor_gib` and `source` from the resolver's JSON, checks only that `floor_gib` is non-empty, and prints `PASS disk_floor — <N> GiB from <source>` [scripts/project-node.sh:178-185]. `FLOOR_SRC` is never validated against the rung that actually won [scripts/project-node.sh:171-185], and the built-in role table is consulted **only** when `python3` is absent [scripts/project-node.sh:161-164]. A resolver answering `1` for `--disk-floor 20` would therefore be reported as `1 GiB from cli`, and the refusal path compares the host against that same number [scripts/project-node.sh:203-228].
- Blast radius: the floor is per node, and one bunker serves one project's every lane [docs/master/_facts.md:13] (fact: FACT-02), so a lowered floor admits every lane of that project onto the same disk. The foreman runs on that node, never on the control host [docs/master/_facts.md:12] (fact: FACT-01), which is why the floor is measured in the node's `$HOME` rather than the operator's [scripts/project-node.sh:3].

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `python3` | 3.14.9 measured here; ≥3.11 gets full TOML support | Beside the ladder inside the node — the staged manifest carries it [scripts/node-create.sh:23] | **Detected and degraded, not fatal**, by the caller: `command -v python3` fails → `WARN ... using built-in <role> default` and `source=role-default(no-python3)` [scripts/project-node.sh:161-164]. Inside the resolver, `import tomllib` is guarded and falls back to a hand-rolled reader [scripts/disk_floor.py:81-84] [scripts/disk_floor.py:93-108] |
| A readable `$HOME/.node/floor.toml` (optional) | n/a — TOML | `~/.node/floor.toml`, or the path in `--config` / `NODE_DISK_FLOOR_CONFIG` [scripts/disk_floor.py:111-112] | Absent or unset is **not** an error: `load_config` returns `{}` and the chain falls through rungs 3-4 [scripts/disk_floor.py:76-80]. Indistinguishable from a mistyped path — see §6 |
| No network, no socket, no database | — | — | Verified by reading the whole file: the only I/O is one optional config read [scripts/disk_floor.py:85-86] and stdout/stderr [scripts/disk_floor.py:161-170] |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `__future__` [scripts/disk_floor.py:27] | stdlib | `annotations` only — annotations stay unevaluated strings | Nothing at runtime; the module still imports |
| `argparse` [scripts/disk_floor.py:29] | stdlib | Two required sub-commands via `add_subparsers(dest="cmd", required=True)` [scripts/disk_floor.py:146]; three option defaults read from the environment at parse time [scripts/disk_floor.py:149-152]; `--explain` is `store_true` [scripts/disk_floor.py:153] | A bare `disk_floor.py` invocation stops exiting 2 with a usage error, and the ladder's `bad` row changes shape [scripts/project-node.sh:173-177] |
| `json` [scripts/disk_floor.py:30] | stdlib | One `json.dumps` of a three-key dict under `--explain` [scripts/disk_floor.py:165]. The *other* side of this contract is the caller's parse of `["floor_gib"]` and `["source"]` [scripts/project-node.sh:178-179] | Key rename is silent to the library and loud to the caller: both keys fall to empty and the ladder reports `resolver returned no number` [scripts/project-node.sh:180-184] |
| `os` [scripts/disk_floor.py:31] | stdlib | `path.exists` for the config probe [scripts/disk_floor.py:79], `path.expanduser` for `~/.node/floor.toml` [scripts/disk_floor.py:112], `environ.get` for the three rung defaults [scripts/disk_floor.py:149-152] | `--role`/`--env`/`--config` defaults vanish, silently changing which rung wins |
| `re` [scripts/disk_floor.py:32] | stdlib | One compiled pattern, `^(?P<num>\d+(?:\.\d+)?)\s*(?:G|GiB|g|gib)?$` [scripts/disk_floor.py:40], applied once [scripts/disk_floor.py:61] | Loosening it admits nonsense into a floor; tightening it rejects documented forms [specs/NODE.md:141] |
| `sys` [scripts/disk_floor.py:33] | stdlib | The failure line goes to **stderr** and `exit` carries status 2 [scripts/disk_floor.py:170] [scripts/disk_floor.py:175] | The ladder captures `2>&1` regardless [scripts/project-node.sh:173], so only a human reading the resolver alone would notice |
| `tomllib` [scripts/disk_floor.py:82] | stdlib ≥3.11 | `load(binary file)` returning a mapping [scripts/disk_floor.py:85-86], then `data.get("disk")` [scripts/disk_floor.py:87] with a `dict` type guard [scripts/disk_floor.py:88-89] | Its `TOMLDecodeError` is **not** a `FloorError`, so a corrupt file escapes the handler at [scripts/disk_floor.py:169-171] — measured, §6 |
| `typing` [scripts/disk_floor.py:34] | stdlib | `Optional[...]` annotations only [scripts/disk_floor.py:47] | Cosmetic under `from __future__ import annotations` |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| `scripts/project-node.sh` layer-00 ladder | caller → resolver | argv, then captured stdout/exit status — no socket [scripts/project-node.sh:171-177] | `resolve --role <r> [--cli <v>] --explain` → `{"role":…,"floor_gib":…,"source":…}` [scripts/disk_floor.py:163-165] | `main()` / `resolve()` in the resolver [scripts/disk_floor.py:144-171]; caller side is `project-node.sh` top-level, no function [scripts/project-node.sh:166-185] |
| `scripts/node-create.sh` staging manifest | control host → node | file copy into `~/node-scripts/` [scripts/node-create.sh:110-113] | `disk_floor.py` itself | `staged_files()` builds the set [scripts/node-create.sh:23], refuses a missing member [scripts/node-create.sh:25-26], and refuses a `$HERE` reference it did not stage [scripts/node-create.sh:43] |
| Operator `[disk]` config | operator → resolver | TOML file read [scripts/disk_floor.py:85-86] | `worker_gib` / `builder_gib` / `full_gib` / `default` / `default_gib` [scripts/disk_floor.py:131-140] | Template ships at [examples/floor.toml.example:7-11] and is documented at [specs/NODE.md:144] |
| Built-in role table (duplicate policy) | resolver ↔ ladder | none — two copies of the same numbers | worker 5 / builder 10 / full 20 | bash `case` in the ladder [scripts/project-node.sh:157-160] vs `ROLE_DEFAULTS` in the resolver [scripts/disk_floor.py:40]. **Byte-equality is not a property these two can have** — one side is a Python dict literal, the other a bash `case` body. What holds is **pair parity**: the same three `(role, GiB)` pairs and the same accepted role set. The parser in `scripts/check_role_parity.py` compares both maps; `tests/selftest.sh` section 65 is the gate and covers clean, ladder mutation, resolver mutation and marker-renamed fixtures. |

## 3. Verification

Run from a clean checkout of this tree (`f63acd3`) with no `NODE_*` variables exported. Every row below was executed on 2026-11-05; the transcripts under the table are the literal terminal output.

| # | Check | Command | Expected | Last run | Result |
|---|---|---|---|---|---|
| 1 | Unit contract (12 tests) | `python3 -B tests/test_disk_floor.py` [tests/test_disk_floor.py:22-92] | `Ran 12 tests`, `OK` | 2026-11-05 | **PASS** |
| 2 | Role table + bare value | `python3 scripts/disk_floor.py roles` [scripts/disk_floor.py:155-162] | three tab-separated rows: builder 10, full 20, worker 5 | 2026-11-05 | **PASS** |
| 3 | Rung 5 (built-in default) | `env -u NODE_DISK_FLOOR -u NODE_ROLE -u NODE_DISK_FLOOR_CONFIG HOME=$(mktemp -d) python3 scripts/disk_floor.py resolve --role worker --explain` [scripts/disk_floor.py:141] | `{"role": "worker", "floor_gib": 5, "source": "role-default"}` | 2026-11-05 | **PASS** |
| 4 | Rungs 3 and 4 (config) | `python3 scripts/disk_floor.py resolve --role worker` / `--role builder` `--config $F/floor.toml --explain` [scripts/disk_floor.py:131-140] | worker → `8`, `config-role`; builder → `6`, `config-default` | 2026-11-05 | **PASS** |
| 5 | Precedence + fail-closed | `NODE_DISK_FLOOR=9 ... --cli 3G --config $F/floor.toml --explain` then `NODE_DISK_FLOOR=plenty ...` [scripts/disk_floor.py:126-129] [scripts/disk_floor.py:169-171] | CLI wins → `3`, `cli`; malformed → `FAIL disk-floor: …`, exit 2 | 2026-11-05 | **PASS** |
| 6 | Duplicate-table parity — **pairs, not bytes** | `python3 scripts/check_role_parity.py` — parses the resolver mapping and the ladder case block [scripts/check_role_parity.py:19-116], sources [scripts/disk_floor.py:40] and [scripts/project-node.sh:157-160] | one PASS line with all pairs, rc 0; any changed pair or role set prints FAIL and rc 1 | 2026-11-09 | **PASS** — section 65 gates clean and mutated copies (ladder, resolver, marker) |
| 7 | Ladder integration, both arms | `NODE_DISK_FLOOR=plenty bash scripts/project-node.sh --check --project fixture --layers 00` and `… --disk-floor 1` [scripts/project-node.sh:173-185] | arm A: named FAIL row, `NODE: FAIL (1)`, rc 1; arm B: `PASS  disk_floor — 1 GiB from cli` | 2026-11-05 | **PASS** (arm B's total rc is 1 for an unrelated `CRIER_URL` FAIL — see note) |

```
$ python3 -B tests/test_disk_floor.py
Ran 12 tests in 0.002s

OK
$ python3 scripts/disk_floor.py roles
builder	10
full	20
worker	5
$ env -u NODE_DISK_FLOOR -u NODE_ROLE -u NODE_DISK_FLOOR_CONFIG HOME=$(mktemp -d) python3 scripts/disk_floor.py resolve --role worker --explain
{"role": "worker", "floor_gib": 5, "source": "role-default"}
$ python3 scripts/disk_floor.py resolve --role worker --config $F/floor.toml --explain
{"role": "worker", "floor_gib": 8, "source": "config-role"}
$ python3 scripts/disk_floor.py resolve --role builder --config $F/floor.toml --explain
{"role": "builder", "floor_gib": 6, "source": "config-default"}
$ NODE_DISK_FLOOR=9 python3 scripts/disk_floor.py resolve --role worker --cli 3G --config $F/floor.toml --explain
{"role": "worker", "floor_gib": 3, "source": "cli"}
$ NODE_DISK_FLOOR=plenty python3 scripts/disk_floor.py resolve --role worker; echo rc=$?
FAIL disk-floor: NODE_DISK_FLOOR: 'plenty' is not a size; use GiB as an integer or '7G' / '7GiB' / '1.5G'
rc=2
```

`$F/floor.toml` above is `[disk]` with `default_gib = "6"` and `worker_gib = "8"` — the same shape the shipped template uses [examples/floor.toml.example:7-11].

Check 6 compares a Python dict literal against bash `case` arms, so the two sources are never equal as text; the command parses the pairs out of both sides and diffs those. Its parity run, and then the same command rerun in two scratch copies with one pair deliberately changed on each side:

```
$ diff <(python3 scripts/disk_floor.py roles | sort) <(sed -n '/^case "\$ROLE" in/,/^esac/p' scripts/project-node.sh | sed -nE 's/^ *(worker|builder|full)\) FLOOR_BUILTIN=([0-9]+) ;;$/\1\t\2/p' | sort); echo rc=$?
rc=0

$ # same command, copy A: ladder changed, builder 10 -> 12
1c1
< builder	10
---
> builder	12
rc=1

$ # same command, copy B: resolver changed, ROLE_DEFAULTS full 20 -> 25
2c2
< full	25
---
> full	20
rc=1
```

`diff` exit status is the assertion: 0 only when both tables carry the same three pairs. The parser is deliberately narrow — it matches `FLOOR_BUILTIN=<n>` inside `case "$ROLE" in … esac`, so a rewrite of that arm (renamed variable, different construct) yields an empty right-hand side and rc 1, or an `IndexError` and rc 1 when the `case` marker itself changes. It fails closed in every direction; it cannot pass while the tables disagree.

```
$ env HOME=$(mktemp -d) NODE_DISK_FLOOR=plenty bash scripts/project-node.sh --check --project fixture --layers 00
  FAIL  disk_floor — FAIL disk-floor: NODE_DISK_FLOOR: 'plenty' is not a size; use GiB as an integer or '7G' / '7GiB' / '1.5G'
NODE: FAIL (1)
rc=1

$ env -u NODE_DISK_FLOOR HOME=$(mktemp -d) bash scripts/project-node.sh --check --project fixture --layers 00 --disk-floor 1
  PASS  disk_floor — 1 GiB from cli
node provisioning — project=fixture harness=hermes host=karaHermes-mde-7840hs
SCOPE: layers 00 (fixture mode — not a node certification)
[00] preflight
  PASS  arch — x86_64 (Linux 7.0.0-38-generic)
  PASS  role — worker (floor 1 GiB from cli)
  PASS  disk — 3190.6 GB free (floor 1 GB)
  PASS  mem — 47281 MB
  FAIL  crier_url — CRIER_URL unset — the node has nothing to connect to (export CRIER_URL=http://crier.example:8767)
  SKIP  layer 10 (out of scope)
  SKIP  layer 20 (out of scope)
  SKIP  layer 30 (out of scope)
  SKIP  layer 40 (out of scope)
  SKIP  layer 90 (fixture mode: no manifest)

NODE: FAIL (1)
rc=1
```

Note on arm B: the module's own row is a PASS and the disk row is a PASS; the run's exit 1 is `crier_url` refusing an unset `CRIER_URL` [scripts/project-node.sh:236-237], which is a different check in the same layer and outside this module's scope. Arm B is therefore asserted **per unit** (the `disk_floor` and `role` rows), not as a whole-ladder pass.

The suite already carries this module as a gate: §12 shells `tests/test_disk_floor.py` and FAILs the suite if it does not exit 0 [tests/selftest.sh:512-517]; §13 proves a malformed floor is refused before any install [tests/selftest.sh:518-526]; §16 proves the staging manifest covers the resolver and that omitting it produces one countable row [tests/selftest.sh:658-701].

## 4. Metrics emitted

**NONE.** There is no counter, histogram, gauge, exporter, span or latency measurement in the file: `grep -c 'logging\|logger\|metric\|counter\|prometheus' scripts/disk_floor.py` returns `0`, and the complete set of outputs is four `print` sites — the tab-separated role list [scripts/disk_floor.py:161], the `--explain` JSON [scripts/disk_floor.py:165], the bare integer [scripts/disk_floor.py:167] and the stderr failure line [scripts/disk_floor.py:170]. Why none is appropriate here: the module is a pure resolver invoked once per provisioning run, so there is no rate, queue or latency to instrument — the only quantity worth counting is whether admission passed, and the caller owns that count in the shell (`bad` increments `FAILED` [scripts/lib.sh:7]) rather than emitting it. Dispatch rate, resolver latency and failure counts are therefore not measurable from this module's own output; they are only reconstructable from the caller's rows, and no store records them [scripts/project-node.sh:185].

## 5. Log lines it can generate

Resolver-side, verbatim from the `print` sites:

- `{"role": "worker", "floor_gib": 5, "source": "role-default"}` — **descriptive**: the `--explain` payload [scripts/disk_floor.py:165]; the field names are the contract the caller parses [scripts/project-node.sh:178-179].
- `builder\t10` / `full\t20` / `worker\t5` — **descriptive**: the `roles` listing, one tab-separated pair per line, sorted by name [scripts/disk_floor.py:160-161].
- `5` (or any bare integer) — **descriptive**: the value when `--explain` is absent [scripts/disk_floor.py:167]; the caller never uses this form [scripts/project-node.sh:173].
- `FAIL disk-floor: NODE_DISK_FLOOR: 'plenty' is not a size; use GiB as an integer or '7G' / '7GiB' / '1.5G'` — **evidentiary**: names the rung that failed, the offending text and the accepted grammar, on stderr, exit 2 [scripts/disk_floor.py:63-66] [scripts/disk_floor.py:169-171].
- `FAIL disk-floor: --disk-floor: 4097 GiB exceeds the maximum of 4096 GiB` — **evidentiary**: the bounds refusal, distinct wording from the grammar refusal [scripts/disk_floor.py:70-71].
- `FAIL disk-floor: unknown role 'toaster'; expected one of builder, full, worker` — **evidentiary**: the role refusal, listing the sorted valid set [scripts/disk_floor.py:122-125].
- `FAIL disk-floor: <path>: [disk] must be a table` — **evidentiary**: a `[disk]` key that is not a table [scripts/disk_floor.py:88-89].

Caller-side rows that quote it (the operator's actual view, format from `lib.sh`):

- `  PASS  disk_floor — 1 GiB from cli` — **evidentiary**: the resolved number *and* its provenance, emitted before any layer runs [scripts/project-node.sh:185] [scripts/lib.sh:6].
- `  PASS  role — worker (floor 1 GiB from cli)` — **evidentiary**: the same pair restated on the layer-00 role row [scripts/project-node.sh:197].
- `  FAIL  disk_floor — FAIL disk-floor: NODE_DISK_FLOOR: 'plenty' is not a size; …` — **evidentiary**: the resolver's stderr folded into one FAIL row by `2>&1` capture [scripts/project-node.sh:173-174] [scripts/lib.sh:7].
- `  FAIL  disk_floor — resolver missing or unreadable: <path>` — **evidentiary**: absence, naming the path that was expected [scripts/project-node.sh:167].
- `  WARN  disk_floor — python3 absent, using built-in worker default 5 GiB` — **evidentiary**: degraded mode, i.e. the number came from the duplicate table rather than the resolver [scripts/project-node.sh:164] [scripts/lib.sh:8].
- `  FAIL  disk_floor — resolver returned no number: <captured payload>` — **evidentiary**: the JSON contract broke; the raw payload is printed, which is the only way an operator sees a key rename [scripts/project-node.sh:180-184].

No log level, logger, file destination or retention policy exists anywhere in this path; every line above is a bare `print` [scripts/disk_floor.py:161-170] or a `printf` from the caller's helpers [scripts/lib.sh:5-8].

## 6. Failure modes

Direction is the module's behaviour, not a preference: `fail closed` means admission stops, `fail open` means a floor is still produced from a weaker source.

| Failure | Presents as | Direction | Distinguished from | Recovery |
|---|---|---|---|---|
| Value violates the grammar | `FAIL disk-floor: <origin>: '<text>' is not a size; use GiB as an integer or '7G' / '7GiB' / '1.5G'`, exit 2 [scripts/disk_floor.py:61-66] | **fail closed** — no fallback to a default, by design [scripts/disk_floor.py:17-19] | Bounds failures use different wording: `0 GiB is below the minimum of 1 GiB` [scripts/disk_floor.py:68-69] | correct the value, or unset the rung that supplied it |
| Value is out of the 1-4096 GiB range | `FAIL disk-floor: --disk-floor: 4097 GiB exceeds the maximum of 4096 GiB`, exit 2 [scripts/disk_floor.py:70-71] | **fail closed** | Grammar failure names the text, not a number [scripts/disk_floor.py:63-66] | pick a value inside the range |
| Role is not `worker\|builder\|full` | `FAIL disk-floor: unknown role 'toaster'; expected one of builder, full, worker`, exit 2 [scripts/disk_floor.py:122-125] | **fail closed** | The ladder refuses an unknown `--role` **earlier**, with its own message and exit 2, before the resolver is invoked [scripts/project-node.sh:157-162] | use a listed role |
| `python3` is absent on the node | `  WARN  disk_floor — python3 absent, using built-in worker default 5 GiB`, and every later row reads `from role-default(no-python3)` [scripts/project-node.sh:161-164] | **fail open (degraded)** — admission proceeds on the duplicate table, so a node can be admitted on a floor the resolver never saw | A resolved run always prints a `source` other than `role-default(no-python3)` [scripts/disk_floor.py:127-141] | install `python3`, then rerun `--check` |
| Resolver file missing or unreadable | `  FAIL  disk_floor — resolver missing or unreadable: <path>`, `NODE: FAIL (1)`, exit 1 [scripts/project-node.sh:166-170] | **fail closed**, before any install | Text names a path, not a value [scripts/project-node.sh:167] vs [scripts/project-node.sh:174] | restage the manifest; the staged-set validator catches the omission at build time [scripts/node-create.sh:43] |
| Config file is corrupt TOML | Python traceback ending `tomllib.TOMLDecodeError: Expected ']' at the end of a table declaration (at line 1, column 6)`, exit **1**; no `FAIL disk-floor:` line [scripts/disk_floor.py:85-89] | **fail closed but degraded** — the ladder still stops (rc ≠ 0) [scripts/project-node.sh:173-177], yet the FAIL row is a multi-line traceback instead of a named refusal | A value error carries the `disk-floor:` prefix and exit 2 [scripts/disk_floor.py:169-171]; this carries neither — **measured defect, §8** | repair or delete the TOML; there is no in-module recovery |
| Config path does not exist | Nothing at all. `load_config` returns `{}` [scripts/disk_floor.py:79-80] and the chain falls to the built-in default with `source: role-default` [scripts/disk_floor.py:141] | **fail open, silently** | Only the `source` field reveals it; an absent file *and* a typo'd path are the same case by construction — **measured defect, §8** | pass an existing `--config`, and read `source` on the caller's PASS row [scripts/project-node.sh:185] |
| Value is fractional (`1.9G`, or a TOML float) | Silent truncation to whole GiB — `1.9G` resolves to `1` [scripts/disk_floor.py:67] [scripts/disk_floor.py:55-56] | **fail open, downwards** — the floor lands *below* what was written, against the module's own "a typo must not lower a floor" [scripts/disk_floor.py:17-19] | No message, no warning; the unit suite pins the truncation as intended [tests/test_disk_floor.py:32] — **measured defect, §8** | write whole GiB |
| `[disk]` is present but not a table | `FAIL disk-floor: <path>: [disk] must be a table`, exit 2 [scripts/disk_floor.py:88-89] | **fail closed** | A missing `[disk]` is not an error at all [scripts/disk_floor.py:87] | fix the TOML |
| JSON contract drifts (`floor_gib`/`source` renamed) | `  FAIL  disk_floor — resolver returned no number: <payload>` [scripts/project-node.sh:180-184] | **fail closed**, with the raw payload printed for diagnosis | A resolver crash produces the traceback case above instead | restore the key names [scripts/disk_floor.py:165] |
| Python <3.11 (no `tomllib`) | Falls back to `_load_config_minimal`, a line-oriented `[disk]` reader [scripts/disk_floor.py:93-108] | **fail open in one narrow way** — the fallback cannot see nested tables and strips everything after `#` [scripts/disk_floor.py:99] [scripts/disk_floor.py:103] | Only reachable on an old interpreter; not exercised on this host — **ASSUMED-not-tested, §8** | use Python ≥3.11 on nodes |

## 7. Environment and settings it reads

| Setting | Where read | Default | Effect of missing |
|---|---|---|---|
| `resolve` sub-command | `add_subparsers(..., required=True)` [scripts/disk_floor.py:146] | none — required | argparse error, exit 2; nothing is printed by this module [scripts/disk_floor.py:157-158] |
| `roles` sub-command | [scripts/disk_floor.py:155] | none — required | same as above |
| `--role <worker\|builder\|full>` | `os.environ.get("NODE_ROLE", DEFAULT_ROLE)` [scripts/disk_floor.py:149] | `worker` [scripts/disk_floor.py:41] | falls to `worker`, i.e. the *smallest* floor of the three [scripts/disk_floor.py:40] |
| `NODE_ROLE` (env, consumer side) | `ROLE="${NODE_ROLE:-worker}"` [scripts/project-node.sh:42], forwarded as `--role` [scripts/project-node.sh:171] | `worker` | same as above |
| `--cli <value>` | `default=None` [scripts/disk_floor.py:150]; supplied by the ladder from `--disk-floor` [scripts/project-node.sh:68-69] [scripts/project-node.sh:172] | `None` | rung 1 is skipped and rung 2 decides [scripts/disk_floor.py:126-129] |
| `--env <value>` | `default=os.environ.get("NODE_DISK_FLOOR")` [scripts/disk_floor.py:151] | `None` | rung 2 is skipped and the config file decides [scripts/disk_floor.py:128-130] |
| `NODE_DISK_FLOOR` (env) | consumed as the `--env` default [scripts/disk_floor.py:151] | unset | the chain drops to rungs 3-4 with no message |
| `--config <path>` | `default=os.environ.get("NODE_DISK_FLOOR_CONFIG")` [scripts/disk_floor.py:152] | unset | falls back to `~/.node/floor.toml` [scripts/disk_floor.py:112] |
| `NODE_DISK_FLOOR_CONFIG` (env) | consumed as the `--config` default [scripts/disk_floor.py:152] | unset | same as above |
| `~/.node/floor.toml` (implicit) | `default_config_path()` [scripts/disk_floor.py:111-112] | the file need not exist | absent file → `{}` → role default, silently [scripts/disk_floor.py:79-80] |
| `[disk] <role>_gib` | `key = f"{role}_gib"` [scripts/disk_floor.py:131-132] | absent | falls to `[disk] default` [scripts/disk_floor.py:136-140] |
| `[disk] default` or `[disk] default_gib` | either key accepted, in that order [scripts/disk_floor.py:136-137] | absent | falls to the built-in role table [scripts/disk_floor.py:141] |
| `--explain` | `store_true` [scripts/disk_floor.py:153] | off | prints a bare integer instead of JSON [scripts/disk_floor.py:164-167]; the ladder always passes it [scripts/project-node.sh:173] |
| Value bounds | `MIN_GIB = 1` / `MAX_GIB = 4096` [scripts/disk_floor.py:38-39] | fixed in code, not configurable | out-of-range is a fail-closed error, not a clamp [scripts/disk_floor.py:68-71] |
| Accepted grammar | `\d+(\.\d+)?` with optional `G\|GiB\|g\|gib` [scripts/disk_floor.py:40] | — | `7`, `7G`, `7GiB`, `7gib`, `7 G`, `1.9G`, ` 12 ` are accepted (measured); `7GIB` is **rejected** because the case alternatives are literal [scripts/disk_floor.py:40], while the spec lists `7`, `7G`, `7GiB`, `1.5G` [specs/NODE.md:141] |

Every one of these settings carries a size or a role name — no credential, token or path-to-secret is ever read here, so the argv-credential rule that governs the rest of the fleet is not in play on this module [docs/master/_facts.md:12].

## 8. Evidence of record

- **Measured 2026-11-05**, in a clean worktree of `f63acd3` (`~/proj-wt-md-11`), on Python 3.14.9 with `tomllib` present: the three transcripts in §3 are the literal terminal output of the eight checks above, run in that order.
- **Parity claim re-measured 2026-11-05** in a second worktree, where `scripts/disk_floor.py`, `scripts/project-node.sh` and `tests/test_disk_floor.py` are byte-identical to `f63acd3` (`git diff --quiet f63acd3 HEAD -- <path>` for each). The command this document previously carried for check 6 — `diff` of `python3 scripts/disk_floor.py roles | sort` against `sed -n '150,155p' scripts/project-node.sh` — exits **1 on the unmodified tree** (3 lines versus 6, `1,3c1,6`), so it could never produce the "identical triples" it claimed: that row had been asserted, not run. The replacement exits 0 here and 1 in each deliberately mutated copy (§3). Same worktree, same day: changing `ROLE_DEFAULTS` from `{"worker": 5, …}` to `{"worker": 7, …}` in a scratch copy leaves `python3 -B tests/test_disk_floor.py` reporting `Ran 12 tests … OK`, because [tests/test_disk_floor.py:85-88] compares the dict against itself through `resolve()`.
- **Unit coverage**: `tests/test_disk_floor.py` carries 12 tests over `parse_value` [tests/test_disk_floor.py:22-37] and `resolve` [tests/test_disk_floor.py:40-92], including the CLI-beats-env-beats-config ordering [tests/test_disk_floor.py:55-73], malformed config and CLI values [tests/test_disk_floor.py:81-88] and an unknown role [tests/test_disk_floor.py:90-92]. The suite gates on it in §12 [tests/selftest.sh:512-517].
- **Integration coverage**: §13 proves a malformed `NODE_DISK_FLOOR` is refused before any install [tests/selftest.sh:518-526]; §16 proves the staged manifest contains the resolver and that its omission yields exactly one countable FAIL row [tests/selftest.sh:658-701].
- **Provenance**: introduced by `222a8b0`, reformatted by `3b2c81e`. Row CF-007's foreman note records the delivery: "scripts/disk_floor.py resolves --disk-floor > NODE_DISK_FLOOR > [disk] config > role default (worker 5 / builder 10 / full 20 GiB) … tests/test_disk_floor.py 12 tests OK; selftest sections 12-13 PASS" [.coding-hermes/board/tasks.jsonl:7]. The row is still `pending` because its AC5 (live bunker residue reap) needs an authorized host — the resolver legs are the delivered part.
- **Spec basis**: N-5 [specs/NODE.md:107], the precedence table [specs/NODE.md:128-141], the fail-closed example [specs/NODE.md:142], the config lookup order [specs/NODE.md:144] and the resolver invocation [specs/NODE.md:146]. The shipped template [examples/floor.toml.example:7-11] and the module's own usage block [scripts/disk_floor.py:21-24] agree with all of it.

Per-unit assertion — what is measured and what is not:

| Unit | Assertion |
|---|---|
| `parse_value` grammar, bounds, bool/None rejection [scripts/disk_floor.py:47-72] | **measured** — §3 check 1, plus the `7GIB`/`1.9G` probes in §5 and §7 |
| Precedence chain, all five rungs [scripts/disk_floor.py:126-141] | **measured** — §3 checks 3-5 |
| `tomllib` config path [scripts/disk_floor.py:85-86] | **measured** — checks 4-5 read a real `[disk]` table on Python 3.14.9 |
| `_load_config_minimal` fallback [scripts/disk_floor.py:93-108] | **ASSUMED-not-tested** — no interpreter below 3.11 exists on this host, so the branch at [scripts/disk_floor.py:83-84] never fires; nothing in the tree exercises it |
| Ladder rows and refusals [scripts/project-node.sh:166-185] | **measured** — §3 check 7, both arms |
| Duplicate role table parity [scripts/project-node.sh:157-160] vs [scripts/disk_floor.py:40] | **measured** — check 6 is now a gate in `tests/selftest.sh` section 65: clean, ladder mutation, resolver mutation and case-marker mutation all run from scratch copies. The independent unit expectation in `test_role_defaults` [tests/test_disk_floor.py:85-88] compares each resolver result against fixed literal pairs, so changing a number cannot make the test pass by changing its own expectation. |
| Reclaim-before-refusal interaction [scripts/project-node.sh:202-231] | **not this module's surface** — the resolver is called once, before the layer at [scripts/project-node.sh:171]; the reclaim path is graded elsewhere per CF-007's note [.coding-hermes/board/tasks.jsonl:7] |

Defects measured while filling this section (filed, **not** fixed — `scripts/` is out of scope for this task):

1. **A corrupt TOML escapes the error boundary.** `tomllib.load` raises `TOMLDecodeError` [scripts/disk_floor.py:85-89], which is not a `FloorError` [scripts/disk_floor.py:43-44], so `main`'s handler [scripts/disk_floor.py:169-171] never runs: exit 1 with a traceback, no `FAIL disk-floor:` line. The ladder still stops, but the operator's row becomes a multi-line traceback instead of a named refusal [scripts/project-node.sh:173-177].
2. **A mistyped `--config` / `NODE_DISK_FLOOR_CONFIG` is silently ignored.** `load_config` returns `{}` for any non-existent path [scripts/disk_floor.py:79-80], so an operator policy file that was never read produces the built-in floor with no warning; only the `source` field betrays it [scripts/disk_floor.py:141].
3. **Fractional values round *down*.** `int(float(...))` [scripts/disk_floor.py:67] turns `1.9G` into 1 GiB, i.e. a value typed above the intended floor lands below it — the opposite of the module's stated intent that "a typo must not lower a floor" [scripts/disk_floor.py:17-19].
4. **Case handling is inconsistent.** The alternatives are literally `G|GiB|g|gib` [scripts/disk_floor.py:40], so `7GiB` and `7gib` are accepted while `7GIB` is a hard failure (measured, §7).
5. **The role table exists twice, with parity enforced by the suite.** The ladder's `case` [scripts/project-node.sh:157-160] duplicates `ROLE_DEFAULTS` [scripts/disk_floor.py:40]. They carry the same three pairs today, but they are **not byte-comparable** — a Python dict literal versus a bash `case` body — so the "byte-equal" wording this document previously used was itself a defect. `scripts/check_role_parity.py` parses both maps, and `tests/selftest.sh` section 65 is the gate: clean, ladder mutation (`builder` 10→12), resolver mutation (`full` 20→25) and case-marker mutation (`worker)`→`wkr)`) must produce the expected PASS/FAIL results. The duplicate remains the fallback admission table when `python3` is missing [scripts/project-node.sh:168-171].
