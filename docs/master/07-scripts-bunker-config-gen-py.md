# 07. scripts/bunker_config_gen.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/bunker_config_gen.py` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **RED — no verification recorded** |

## 1. Purpose and why it matters

- What breaks if this module is absent:
  `scripts/bunker-provision.sh` takes a config file that names a project, its repo, its namespace and the files its credentials live in. This module generates one config per project from the scheduler sqlite `projects` table. Without it, configs must be hand-written, and the source states: `Hand-writing one config per project invites drift: a typo in a repo URL, the same agent name on two projects, a namespace that stopped matching the registry.`
- What breaks if it lies:
  A generated config that names the wrong repo, namespace, agent, or token-file path would provision the wrong clone or wrong lane memory; the source explicitly warns `a half-guessed config provisions the wrong clone` and `Everything else is refused, never guessed`.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| Python standard library modules listed in 2b (`__future__`, `argparse`, `hashlib`, `os`, `re`, `sqlite3`, `sys`, `typing`) | UNKNOWN | UNKNOWN | UNKNOWN |

Source note: the module docstring says `stdlib + sqlite3 only. Never opens the database for writing.`

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `__future__` | Python standard library | Enables `annotations` feature: source line `from __future__ import annotations` | UNKNOWN |
| `argparse` | Python standard library | `ArgumentParser`, `add_argument`, `parse_args`; options defined by source literal strings `"--db"`, `"--projects"`, `"--project"`, `"--prefix"`, `"--server"`, `"--harness"`, `"--ref"`, `"--ttl"`, `"--repo-url"`, `"--force"`, `"--check"`, `"--dry-run"` in `build(argv)` | UNKNOWN |
| `hashlib` | Python standard library | Source expression `hashlib.sha256(text.encode("utf-8")).hexdigest()[:12]` | UNKNOWN |
| `os` | Python standard library | Path/env/process operations used: `os.path.abspath`, `os.path.expanduser`, `os.path.exists`, `os.path.isfile`, `os.path.isdir`, `os.makedirs`, `os.access`, `os.replace`, `os.getpid`, `os.environ` | UNKNOWN |
| `re` | Python standard library | `re.compile`, `re.match`, `re.sub`; definitions include `SLUG_RE = re.compile(r"^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$")` and `URL_RE = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*://")` | UNKNOWN |
| `sqlite3` | Python standard library | Read-only SQLite access: `sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=15)`; reads `pragma table_info(projects)` and `select name, repo_url, workdir, namespace_id, enabled from projects order by name` | UNKNOWN |
| `sys` | Python standard library | `sys.stdout`, `sys.stderr`, `sys.exit` | UNKNOWN |
| `typing` | Python standard library | `Optional` (`Optional[list]`) | UNKNOWN |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| `scripts/bunker-provision.sh` | `bunker_config_gen.py` writes config; provisioner consumes it | local file `<outdir>/<project>.conf` | `KEY=VALUE` lines, sorted by key, with comment headers | `scripts/bunker-provision.sh` (named in source docstring: `scripts/bunker-provision.sh takes a config file that names a project, its repo, its namespace and the files its credentials live in`) |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| Source-defined drift check | `scripts/bunker_config_gen.py --server <s> --prefix code-factory --check` | On no drift, `BUNKER-CONFIG: PASS — {counts(len(configs), 'config')} checked, no drift` and exit 0 | UNKNOWN | UNKNOWN |

## 4. Metrics emitted

**No telemetry/metrics subsystem found.** The source emits human-readable status rows and summary counts to stdout/stderr, not service metrics. Examples from the source:

- `"BUNKER-CONFIG: DRIFT ({drifted} of {len(configs)} mismatched)"`
- `"BUNKER-CONFIG: PASS — {counts(len(configs), 'config')} checked, no drift"`
- `"BUNKER-CONFIG: REFUSED ({len(refusals)}) — nothing written"`

There are no rate, latency, or liveness metrics in the code.

## 5. Log lines it can generate

The script prints status rows and summaries to `sys.stdout`, except `--dry-run` moves rows to `sys.stderr`:

- `row()` format: `print(f"  {status}  {name} — {detail}", file=ROW_STREAM)`; status labels in source include `PASS`, `FAIL`, `WARN`.
- `note()` format: `print(f"  ..    {text}", file=ROW_STREAM)`
- `headline()` prints plain text; examples:
  - `headline(f"bunker-config-gen — db={expand(opts.db)} out={outdir} harness={opts.harness} ref={opts.ref}")`
  - `headline(f"BUNKER-CONFIG: DRIFT ({drifted} of {len(configs)} mismatched)")`
  - `headline(f"BUNKER-CONFIG: PASS — {counts(len(configs), 'config')} checked, no drift")`
  - `headline(f"BUNKER-CONFIG: PASS — {counts(len(configs), 'config')} ({written} written, {unchanged} unchanged), 0 refused")`
  - `headline(f"BUNKER-CONFIG: REFUSED ({len(refusals)}) — nothing written")`
  - `headline(f"BUNKER-CONFIG: DRY-RUN — {len(configs)} config(s) predicted")`
  - `headline("BUNKER-CONFIG: REFUSED (1) — nothing written")`

No traditional log levels are emitted; the visible status labels are `PASS`, `FAIL`, `WARN`, and `..` for notes.

## 6. Failure modes

Source constants: `EXIT_OK = 0`, `EXIT_DRIFT = 1`, `EXIT_REFUSED = 2`.

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Scheduler DB missing or not a file | `FAIL db` row with `scheduler database not found: {path}` or `scheduler database is not a file: {path}`; summary `BUNKER-CONFIG: REFUSED (1)`; exit 2 | Refused before scope selection | UNKNOWN |
| DB cannot be opened read-only or read | `FAIL db` row with `cannot open {path} read-only: {exc}` or `cannot read projects from {path}: {exc}`; exit 2 | Refusal before any config is written | UNKNOWN |
| Missing `projects` table or required columns | `FAIL db` row with `{path} has no \`projects\` table` or `{path} \`projects\` table has no \`{needed}\` column`; exit 2 | Named refusal from `load_rows` | UNKNOWN |
| No `--server` | `FAIL server` row with `SERVER unset — a config names no host to provision on`; exit 2 | Refused before DB read/scope selection | Run with `--server <bunker-host>`; source usage line: `scripts/bunker_config_gen.py --server <bunker-host> --prefix code-factory` |
| No scope matches `--project`/`--prefix` | `FAIL scope` row with `no registry row matches --project/--prefix`; exit 2 | No registry row selected, but DB was readable | UNKNOWN |
| Empty `repo_url` | `FAIL <lane>` row with `repo_url is absent or empty in the registry`; run writes nothing and exits 2 | Per-row refusal during `resolve_repo` | UNKNOWN |
| PHANTOM local repo path | `FAIL <lane>` row with `PHANTOM — repo_url names {spelling}, and {path} does not exist` or `PHANTOM — repo_url names {spelling}, and {path} is not a directory`; exit 2 | Per-row refusal during `resolve_repo` | UNKNOWN |
| Ambiguous project name | `FAIL group[...]` row containing `AMBIGUOUS — ...`; exit 2 | Group refused rather than guessed | UNKNOWN |
| Unsafe or overlong project slug | `FAIL <project>` row with `not a safe slug ([a-z0-9-], no edge hyphen, <=63 chars)`; exit 2 | Refusal after project derivation | UNKNOWN |
| Two repo targets derive same project name/agent | `FAIL project` row with `two repo targets derive this name ...`; `FAIL agent` row with `'{agent}' derived by {' and '.join(owners)} — refusing to guess`; exit 2 | Collision is measured and refused, not merged | UNKNOWN |
| Output directory cannot be created or is not writable | `FAIL output_dir` with `cannot create the config directory {path}: {exc}` or `the config directory {path} is not writable`; exit 2 | Refusal before writing configs | UNKNOWN |
| Existing config drift without `--force` | `FAIL drift` row with key differences; summary `BUNKER-CONFIG: DRIFT (...)`, exit 1 | Not a refusal; files are not rewritten | Source row says `pass --force to rewrite`; source usage includes `--force` |
| Config missing during `--check` | `FAIL missing` row with `{path} — no config; run without --check`; drift count increments; exit 1 | Check mode only | Source row says `run without --check` |

## 7. Environment and settings it reads

| Variable | Default | Effect if unset |
|---|---|---|
| `CRIER_URL` | N/A — not read by this script | No effect on this script. Source note: `CRIER_URL, DUCKBRAIN_URL and NODE_ENV_FILE are host facts — add them per environment, not here` |

The environment variable actually read by this module is `SCHEDULER_DB`, used only as the default for `--db`: `default=os.environ.get("SCHEDULER_DB", DEFAULT_DB)`. Source default: `DEFAULT_DB = os.path.join("~", ".hermes", "coding-hermes", "scheduler.db")`.

## 8. Evidence of record

- Source provided at `/home/kara/code-factory/scripts/bunker_config_gen.py` and reviewed.
- Claims above cite literal source strings from that file; no external verification record exists yet.
