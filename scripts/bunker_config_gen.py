#!/usr/bin/env python3
"""bunker_config_gen.py — generate one bunker-provision config per project.

`scripts/bunker-provision.sh` takes a config file that names a project, its repo,
its namespace and the files its credentials live in. Hand-writing one config per
project invites drift: a typo in a repo URL, the same agent name on two projects,
a namespace that stopped matching the registry. The scheduler's sqlite `projects`
table already knows every lane, its repo and its namespace, so the configs are
derived from it instead of typed.

Projects are named by this rule, and nothing else:

  1. **The clone is the project.** Lanes are grouped by their resolved repo
     target: a `local:<path>` row resolves to its real path, any other spelling
     is compared as the URL written. One repo target is one project, one config,
     one bunker — because a bunker is one clone, one harness and one namespace,
     and two configs over one repo would provision the same checkout twice.
  2. **The name has to be a prefix of every lane in the group.** Within a group
     the project is the shortest candidate that is a prefix of the project's
     other lane names — candidates are the lane names themselves plus their
     family keys (the name with one recognized satellite suffix removed), so a
     family whose primary row is called `<project>-foreman` still has a project
     called `<project>`. The fleet spells a satellite lane as
     `<project>-<suffix>`, with the scheduler's nine suffixes — `-qa`, `-pm`,
     `-sync`, `-dogfood`, `-releng`, `-docs`, `-readme`, `-perf`, `-review`.
     When no single name is a prefix of every other name in the group, the group
     is AMBIGUOUS and is refused by name; a half-guessed config provisions the
     wrong clone. A lane whose family key (`<name>` with one suffix removed) is
     another project but whose `repo_url` names a different clone is NOT merged
     into it: it gets its own config and a `WARN repo_disagreement` row naming
     both clones — the CF-091 disagreement between the fleet's naming and the
     registry's repo_url, made visible instead of averaged.
  3. **Everything else is refused, never guessed.** An absent or empty
     `repo_url`, a `local:` path that does not exist (PHANTOM), a project name
     that is not a safe slug, two projects deriving the same AGENT, and an
     output directory that cannot be written each print a named FAIL row and
     exit 2, and a run that refused anything writes nothing — a partial set of
     configs hides the refusal.

Derived keys: `PROJECT` (rule 2), `AGENT` (`cf-` + the project, lowercased with
every run of characters outside `[a-z0-9]` collapsed to `-`; unique across the
run), `SERVER`, `REPO`, `REF` (default `main`), `HARNESS` (default `hermes`),
`NAMESPACE`, `TTL` (default `6h`), and the three token-file keys as PATHS under
`~/.config/code-factory/<project>/`. No secret value is ever written or printed.
The agent normalization is lossy on purpose — `demo--alpha` and `demo-alpha` both
derive `cf-demo-alpha` — so the collision is measured and refused rather than
assumed impossible.

Chat gateways (specs/M13-chat-gateways.md): `--gateways <file>` names a JSON input
carrying the §3 gateways section — `platforms.<platform>.{enabled, token_env,
home_channel{platform, chat_id, thread_id, name}, allowed_chats}` plus an optional
`gateways.loop_watchdog`. Each config in the run gains a SIBLING artifact
`<project>.gateways.json` holding exactly that block, sorted and byte-deterministic,
so the provision path can merge it into the bunker's `~/.hermes/config.yaml` and
`--check` can grade it on every re-sync. The block cannot ride inside the .conf
itself: the provision config grammar is KEY=VALUE and bunker-provision.sh refuses
unknown keys, so a new key would refuse every gateway-configured bunker at provision
time. The input is refused by name when it is not valid JSON, when a platform entry
misses the §3 surface, or when it carries token-shaped bytes anywhere (R2 — tokens
ride as `token_env` references; the config never holds a value). Any platform key is
accepted (R5); telegram is the first proven platform, not a schema constant. No
`--gateways`, no artifact: a scheduler-only lane generates byte-identically (R3).

Idempotence: a generated config is sorted by key, carries no timestamp, and the
bytes are a pure function of the registry row set and the flags. A second run
prints `unchanged` per file and writes nothing; a file whose bytes differ is
never rewritten without `--force`, and the row names the keys that differ.

Usage:
  scripts/bunker_config_gen.py --server <bunker-host> --prefix code-factory
  scripts/bunker_config_gen.py --server <s> --project code-factory --dry-run
  scripts/bunker_config_gen.py --server <s> --prefix code-factory --check
  scripts/bunker_config_gen.py --server <s> --prefix code-factory --force
  scripts/bunker_config_gen.py --server <s> --project demo --gateways gateways.json

Exit codes: 0 configs match or were written, 1 drift (a file differs without
`--force`, or `--check` measured a difference), 2 refused (an unreadable
registry, a bad argument, or any named refusal above).

stdlib + sqlite3 only. Never opens the database for writing.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sqlite3
import sys
from typing import Optional

# The scheduler's nine satellite families (docs/SCHEDULER-ADMISSION.md).
SATELLITE_SUFFIXES = (
    "-qa",
    "-pm",
    "-sync",
    "-dogfood",
    "-releng",
    "-docs",
    "-readme",
    "-perf",
    "-review",
)
SLUG_RE = re.compile(r"^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$")
URL_RE = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*://")
# Keys the provisioner parses, in the order they are written (sorted).
CONFIG_KEYS = (
    "AGENT",
    "DUCKBRAIN_TOKEN_FILE",
    "GITHUB_TOKEN_FILE",
    "HARNESS",
    "NAMESPACE",
    "PROJECT",
    "REF",
    "REPO",
    "S3_ENV_FILE",
    "SERVER",
    "TTL",
)
AGENT_PREFIX = "cf-"
DEFAULT_REF = "main"
DEFAULT_HARNESS = "hermes"
DEFAULT_TTL = "6h"
DEFAULT_DB = os.path.join("~", ".hermes", "coding-hermes", "scheduler.db")
DEFAULT_PROJECTS_DIR = os.path.join("~", ".config", "code-factory")
TOKEN_DIR = os.path.join("~", ".config", "code-factory")
TOKEN_FILES = {
    "GITHUB_TOKEN_FILE": "github.token",
    "DUCKBRAIN_TOKEN_FILE": "duckbrain.token",
    "S3_ENV_FILE": "s3.env",
}

EXIT_OK = 0
EXIT_DRIFT = 1
EXIT_REFUSED = 2


class Refused(Exception):
    """A named refusal: printed as a FAIL row, exit 2, nothing written."""


# Rows go to stdout so an operator reads one stream. `--dry-run` is the exception:
# it moves every row to stderr, so the config bodies on stdout can be redirected
# into files without a row landing in a config.
ROW_STREAM = sys.stdout


def row(status: str, name: str, detail: str) -> None:
    """Print one row in the repo's house style: `  PASS  <name> — <value>`."""
    print(f"  {status}  {name} — {detail}", file=ROW_STREAM)


def note(text: str) -> None:
    print(f"  ..    {text}", file=ROW_STREAM)


def headline(text: str) -> None:
    print(text, file=ROW_STREAM)


def digest(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:12]


def expand(path: str) -> str:
    return os.path.abspath(os.path.expanduser(path))


def counts(number: int, word: str) -> str:
    """`1 config` / `2 configs` — the summaries are read by people."""
    return f"{number} {word}{'' if number == 1 else 's'}"


# --- registry ------------------------------------------------------------------


def load_rows(db_path: str) -> list:
    """Every registry row, read-only, ordered by lane name."""
    path = expand(db_path)
    if not os.path.exists(path):
        raise Refused(f"scheduler database not found: {path}")
    if not os.path.isfile(path):
        raise Refused(f"scheduler database is not a file: {path}")
    try:
        con = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=15)
    except sqlite3.Error as exc:
        raise Refused(f"cannot open {path} read-only: {exc}") from exc
    try:
        cols = {r[1] for r in con.execute("pragma table_info(projects)")}
        if not cols:
            raise Refused(f"{path} has no `projects` table")
        for needed in ("name", "repo_url", "workdir", "namespace_id", "enabled"):
            if needed not in cols:
                raise Refused(f"{path} `projects` table has no `{needed}` column")
        query = (
            "select name, repo_url, workdir, namespace_id, enabled from projects "
            "order by name"
        )
        return [
            {
                "name": r[0] or "",
                "repo_url": r[1] or "",
                "workdir": r[2] or "",
                "namespace": r[3] or "",
                "enabled": int(r[4] or 0),
            }
            for r in con.execute(query)
        ]
    except sqlite3.Error as exc:
        raise Refused(f"cannot read projects from {path}: {exc}") from exc
    finally:
        con.close()


def selected(row_: dict, selectors: list, prefixes: list) -> bool:
    """A row is in scope when it is a selector, a selector's lane, or in a prefix."""
    if not selectors and not prefixes:
        return True
    name = row_["name"]
    for wanted in selectors + prefixes:
        if name == wanted or name.startswith(wanted + "-"):
            return True
    return False


def resolve_repo(raw: str) -> dict:
    """Resolve a repo_url to a comparable target, or refuse it by name."""
    spelling = raw.strip()
    if not spelling:
        raise Refused("repo_url is absent or empty in the registry")
    if spelling.startswith("local:") or spelling.startswith("file:"):
        rest = spelling.split(":", 1)[1]
        if rest.startswith("//"):
            rest = rest[2:]
        path = expand(rest)
        if not os.path.isdir(path):
            raise Refused(
                f"PHANTOM — repo_url names {spelling}, and {path} does not exist"
            )
        return {"kind": "local", "value": path, "spelling": spelling}
    if URL_RE.match(spelling):
        return {"kind": "remote", "value": spelling.rstrip("/"), "spelling": spelling}
    path = expand(spelling)
    if not os.path.isdir(path):
        raise Refused(
            f"PHANTOM — repo_url names {spelling}, and {path} is not a directory"
        )
    return {"kind": "local", "value": path, "spelling": spelling}


def base_name(name: str) -> str:
    """The fleet's family key for a lane: its name with ONE recognized suffix removed."""
    for suffix in SATELLITE_SUFFIXES:
        if name.endswith(suffix):
            return name[: -len(suffix)]
    return name


def derive_project(names: list) -> str:
    """The shortest name that is a prefix of every lane name in the group.

    The candidates are the lane names themselves plus their family keys, because
    the fleet names a project's lanes `<project>-<suffix>`: a family whose primary
    row is called `<project>-foreman` still has a project called `<project>`, and
    inventing nothing else keeps the name derivable from the lanes alone.
    """
    ordered = sorted(names)
    pool = set(ordered) | {base_name(n) for n in ordered}
    candidates = [
        n
        for n in sorted(pool)
        if n and all(m == n or m.startswith(n + "-") for m in ordered)
    ]
    if not candidates:
        raise Refused(
            "AMBIGUOUS — no lane name or family key is a prefix of every lane in the "
            f"group ({', '.join(ordered[:6])}{', …' if len(ordered) > 6 else ''})"
        )
    shortest = min(len(n) for n in candidates)
    winners = [n for n in candidates if len(n) == shortest]
    if len(winners) > 1:
        raise Refused(f"AMBIGUOUS — {', '.join(winners)} both qualify as the name")
    return winners[0]


def derive_agent(project: str) -> str:
    """`cf-` + the project, normalized to the bunker's id alphabet."""
    body = re.sub(r"[^a-z0-9]+", "-", project.lower()).strip("-")
    return AGENT_PREFIX + body


def namespace_for(project: str, rows: list) -> tuple:
    """(namespace, WARN detail or "") — the registry's agreement, or the project name.

    The registry is the fact: when every lane of the project carries the same
    `namespace_id`, that is the namespace. When they disagree (or carry none) the
    project name is used and the disagreement is named, because a config that
    silently picked one of two values would move a lane's memory.
    """
    spelled: dict = {}
    for item in rows:
        if item["namespace"]:
            spelled[item["namespace"]] = spelled.get(item["namespace"], 0) + 1
    if len(spelled) == 1:
        ((only, how_many),) = spelled.items()
        if only == project:
            return only, ""
        return only, (
            f"registry namespace_id={only} ({counts(how_many, 'lane')}) differs "
            f"from the project name {project} — using the registry value"
        )
    if not spelled:
        return project, (
            f"no namespace_id on {counts(len(rows), 'lane')} — using {project}"
        )
    tally = ", ".join(
        f"{name} ({counts(how_many, 'lane')})"
        for name, how_many in sorted(spelled.items())
    )
    return project, (
        f"lanes disagree: {tally} — using the project name {project}; "
        "set one namespace in the registry before provisioning"
    )


# --- chat gateways (specs/M13-chat-gateways.md) ---------------------------------

# What a bot-token literal looks like. The R2 law: a config names a token_env, never a
# token — so this shape is refused in any gateways input, and nothing this tool writes
# may match it.
GATEWAY_TOKEN_RE = re.compile(r"[0-9]{8,10}:[A-Za-z0-9_-]{35}")
# A platform key is data (R5 — telegram, signal, discord, whatever the control host
# accepts), but it becomes a config.yaml key, so its SHAPE is still law.
GATEWAY_PLATFORM_RE = re.compile(r"^[a-z][a-z0-9_-]*$")
# token_env names an environment variable: uppercase with underscores, never empty.
TOKEN_ENV_RE = re.compile(r"^[A-Z][A-Z0-9_]*$")
GATEWAYS_SUFFIX = ".gateways.json"


def validate_platform(name, entry) -> None:
    """One platform entry against the M13 §3 surface; a Refused names the key.

    Extra keys are passed through untouched (the control-host surface carries fields
    like `user_id` this fleet has no opinion on); the required surface is enforced.
    """
    if not GATEWAY_PLATFORM_RE.match(name):
        raise Refused(
            f"platform key {name!r} is not a config key (lowercase [a-z0-9_-], "
            "leading letter) — any platform is accepted (M13 R5), the key is still data"
        )
    if not isinstance(entry, dict):
        raise Refused(f"platforms.{name} must be an object")
    for key in ("enabled", "token_env", "home_channel", "allowed_chats"):
        if key not in entry:
            raise Refused(
                f"platforms.{name} has no {key} — the M13 §3 surface needs it"
            )
    if not isinstance(entry["enabled"], bool):
        raise Refused(f"platforms.{name}.enabled must be true or false")
    token_env = entry["token_env"]
    if not isinstance(token_env, str) or not TOKEN_ENV_RE.match(token_env):
        raise Refused(
            f"platforms.{name}.token_env must name an environment variable "
            f"(UPPERCASE), got {token_env!r} — tokens ride by reference (M13 R2)"
        )
    channel = entry["home_channel"]
    if not isinstance(channel, dict):
        raise Refused(f"platforms.{name}.home_channel must be an object")
    for key in ("platform", "chat_id", "thread_id", "name"):
        if not isinstance(channel.get(key), str):
            raise Refused(f"platforms.{name}.home_channel.{key} must be a string")
    if channel["platform"] != name:
        raise Refused(
            f"platforms.{name}.home_channel.platform is {channel['platform']!r} — "
            "it names the platform the channel lives on"
        )
    if not channel["chat_id"]:
        raise Refused(f"platforms.{name}.home_channel.chat_id is empty")
    chats = entry["allowed_chats"]
    if not isinstance(chats, list) or not chats:
        raise Refused(
            f"platforms.{name}.allowed_chats must be a non-empty list of chat ids"
        )
    for chat in chats:
        if not isinstance(chat, str) or not chat:
            raise Refused(
                f"platforms.{name}.allowed_chats carries a non-string or empty id"
            )


def load_gateways(path: str) -> dict:
    """The validated M13 §3 gateways block, or a named refusal. Never guessed."""
    path = expand(path)
    try:
        with open(path, encoding="utf-8") as handle:
            raw = handle.read()
    except OSError as exc:
        raise Refused(f"gateways input unreadable: {path} — {exc}") from exc
    if GATEWAY_TOKEN_RE.search(raw):
        raise Refused(
            "gateways input carries token bytes (M13 R2) — name a token_env instead; "
            "the config never holds a value"
        )
    try:
        doc = json.loads(raw)
    except ValueError as exc:
        raise Refused(f"gateways input is not JSON: {path} — {exc}") from exc
    if not isinstance(doc, dict):
        raise Refused(f"gateways input must be a JSON object: {path}")
    platforms = doc.get("platforms")
    if not isinstance(platforms, dict) or not platforms:
        raise Refused(
            "gateways input declares no platforms object — omit --gateways for a "
            "scheduler-only lane (M13 R3)"
        )
    for name, entry in platforms.items():
        validate_platform(name, entry)
    gateways = doc.get("gateways", {"loop_watchdog": {}})
    if not isinstance(gateways, dict):
        raise Refused("gateways must be an object when present")
    return {"platforms": platforms, "gateways": gateways}


def gateways_path(outdir: str, project: str) -> str:
    return os.path.join(outdir, project + GATEWAYS_SUFFIX)


def render_gateways(block: dict) -> str:
    """The emitted artifact bytes: sorted keys, two-space indent, no timestamp."""
    return json.dumps(block, indent=2, sort_keys=True) + "\n"


def gateways_keys(block: dict) -> str:
    """The platform keys the block carries, in the order they are reported."""
    return ", ".join(sorted(block.get("platforms", {})))


def gateways_differences(existing: str, wanted: str) -> list:
    """Named reasons an emitted artifact drifted, in a deterministic order."""
    try:
        have = json.loads(existing)
    except ValueError:
        return ["artifact is not JSON"]
    try:
        want = json.loads(wanted)
    except ValueError:
        return ["expected artifact is not JSON"]
    if not isinstance(have, dict) or not isinstance(want, dict):
        return ["artifact is not a JSON object"]
    out = []
    for key in sorted(set(have) | set(want)):
        if have.get(key) == want.get(key):
            continue
        if key not in want:
            out.append(f"obsolete key {key}")
        elif key not in have:
            out.append(f"missing key {key}")
        else:
            out.append(f"{key} differs")
    return out or ["byte difference only (whitespace or key order)"]


# --- config text ---------------------------------------------------------------


def build_config(project: str, group: dict, opts: argparse.Namespace) -> dict:
    """The KEY=VALUE mapping for one project — a pure function of the group."""
    namespace, ns_note = namespace_for(project, group["rows"])
    token_root = os.path.join(TOKEN_DIR, project)
    values = {
        "PROJECT": project,
        "AGENT": derive_agent(project),
        "SERVER": opts.server,
        "REPO": opts.repo_url or group["repo"],
        "REF": opts.ref,
        "HARNESS": opts.harness,
        "NAMESPACE": namespace,
        "TTL": opts.ttl,
    }
    for key, leaf in TOKEN_FILES.items():
        values[key] = os.path.join(token_root, leaf)
    group["namespace"] = namespace
    group["namespace_note"] = ns_note
    return values


def render(values: dict) -> str:
    lines = [
        "# bunker-provision config — generated from the scheduler registry by",
        "# scripts/bunker_config_gen.py. Regenerate it; do not hand-edit.",
    ]
    for key in sorted(values):
        lines.append(f"{key}={values[key]}")
    return "\n".join(lines) + "\n"


def parse_config(text: str) -> tuple:
    """(mapping, shape problem) for an existing config, using the provisioner's grammar."""
    values = {}
    for number, line in enumerate(text.splitlines(), start=1):
        if not line or line.startswith("#"):
            continue
        match = re.match(r"^([A-Z_][A-Z0-9_]*)=(.*)$", line)
        if not match:
            return values, f"line {number} is not KEY=VALUE"
        values[match.group(1)] = match.group(2)
    return values, ""


def differences(existing: dict, expected: dict) -> list:
    """Every key that differs, from either side, in a deterministic order."""
    out = []
    for key in sorted(set(existing) | set(expected)):
        have, want = existing.get(key), expected.get(key)
        if have == want:
            continue
        if key not in expected:
            out.append(f"obsolete key {key}")
        elif key not in existing:
            out.append(f"missing key {key}")
        else:
            out.append(f"{key}: file '{have}' ≠ registry '{want}'")
    return out


def atomic_write(path: str, text: str) -> None:
    tmp = f"{path}.tmp-{os.getpid()}"
    with open(tmp, "w", encoding="utf-8") as handle:
        handle.write(text)
    os.replace(tmp, path)


# --- modes ---------------------------------------------------------------------


def check_mode(configs: list, opts: argparse.Namespace) -> int:
    drifted = 0
    for project, values, path, gateways in configs:
        wanted = render(values)
        if not os.path.exists(path):
            row("FAIL", "missing", f"{path} — no config; run without --check")
            drifted += 1
            continue
        try:
            with open(path, encoding="utf-8") as handle:
                text = handle.read()
        except OSError as exc:
            row("FAIL", "unreadable", f"{path} — {exc}")
            drifted += 1
            continue
        existing, shape = parse_config(text)
        reasons = ([shape] if shape else []) + differences(existing, values)
        if text != wanted and not reasons:
            reasons = ["byte difference only (comments or key order)"]
        if reasons:
            row("FAIL", "drift", f"{path} — {'; '.join(reasons)}")
            drifted += 1
        else:
            row(
                "PASS",
                "match",
                f"{path} — {len(values)} keys agree, sha256 {digest(text)}",
            )
        drifted += gateways_check(project, path, gateways)
    if drifted:
        headline(f"BUNKER-CONFIG: DRIFT ({drifted} of {len(configs)} mismatched)")
        return EXIT_DRIFT
    headline(
        f"BUNKER-CONFIG: PASS — {counts(len(configs), 'config')} checked, no drift"
    )
    return EXIT_OK


def gateways_check(project: str, conf_path: str, gateways) -> int:
    """Grade one project's emitted gateways artifact; returns its drift count.

    No gateways input, no row — unless an artifact from an earlier gated run is still
    on disk, which is named as an orphan rather than silently ignored.
    """
    gw_path = gateways_path(os.path.dirname(conf_path), project)
    if gateways is None:
        if not os.path.exists(gw_path):
            return 0
        row(
            "WARN",
            "gateways",
            f"{gw_path} exists but this run passed no --gateways input — "
            "pass the input or remove the artifact",
        )
        return 0
    wanted = render_gateways(gateways)
    if not os.path.exists(gw_path):
        row("FAIL", "gateways", f"{gw_path} — no artifact; run without --check")
        return 1
    try:
        with open(gw_path, encoding="utf-8") as handle:
            text = handle.read()
    except OSError as exc:
        row("FAIL", "gateways", f"{gw_path} — {exc}")
        return 1
    if text != wanted:
        reasons = gateways_differences(text, wanted)
        row("FAIL", "gateways", f"{gw_path} — {'; '.join(reasons)}")
        return 1
    row(
        "PASS",
        "gateways",
        f"{gw_path} — platforms: {gateways_keys(gateways)} — sha256 {digest(text)}",
    )
    return 0


def print_configs(configs: list) -> None:
    for project, values, path, gateways in configs:
        print(f"# --- {path}")
        print(render(values), end="")
        if gateways is not None:
            print(f"# --- {gateways_path(os.path.dirname(path), project)}")
            print(render_gateways(gateways), end="")


def write_mode(configs: list, opts: argparse.Namespace) -> int:
    written = unchanged = drifted = 0
    for project, values, path, gateways in configs:
        wanted = render(values)
        try:
            with open(path, encoding="utf-8") as handle:
                text = handle.read()
        except FileNotFoundError:
            text = None
        except OSError as exc:
            row("FAIL", "unreadable", f"{path} — {exc}")
            drifted += 1
            continue
        if text == wanted:
            row("PASS", "unchanged", f"{path} — byte-identical, sha256 {digest(text)}")
            unchanged += 1
        elif text is not None and not opts.force:
            existing, shape = parse_config(text)
            reasons = ([shape] if shape else []) + differences(existing, values)
            if not reasons:
                reasons = ["byte difference only (comments or key order)"]
            row(
                "FAIL",
                "drift",
                f"{path} — {'; '.join(reasons)} — pass --force to rewrite",
            )
            drifted += 1
        else:
            try:
                atomic_write(path, wanted)
            except OSError as exc:
                row("FAIL", "unwritable", f"{path} — {exc}")
                drifted += 1
                continue
            verb = "rewrote" if text is not None else "wrote"
            row("PASS", verb, f"{path} — {len(values)} keys, sha256 {digest(wanted)}")
            written += 1
        gw_written, gw_drifted = gateways_write(project, path, gateways, opts)
        written += gw_written
        drifted += gw_drifted
    if drifted:
        headline(f"BUNKER-CONFIG: DRIFT ({drifted} of {len(configs)} mismatched)")
        return EXIT_DRIFT
    headline(
        f"BUNKER-CONFIG: PASS — {counts(len(configs), 'config')} "
        f"({written} written, {unchanged} unchanged), 0 refused"
    )
    return EXIT_OK


def gateways_write(
    project: str, conf_path: str, gateways, opts: argparse.Namespace
) -> tuple:
    """Write or grade one project's gateways artifact; returns (written, drifted)."""
    gw_path = gateways_path(os.path.dirname(conf_path), project)
    if gateways is None:
        if not os.path.exists(gw_path):
            return 0, 0
        row(
            "WARN",
            "gateways",
            f"{gw_path} exists but this run passed no --gateways input — "
            "pass the input or remove the artifact",
        )
        return 0, 0
    wanted = render_gateways(gateways)
    try:
        with open(gw_path, encoding="utf-8") as handle:
            text = handle.read()
    except FileNotFoundError:
        text = None
    except OSError as exc:
        row("FAIL", "gateways", f"{gw_path} — {exc}")
        return 0, 1
    if text == wanted:
        row(
            "PASS",
            "unchanged",
            f"{gw_path} — byte-identical ({gateways_keys(gateways)}), sha256 {digest(text)}",
        )
        return 0, 0
    if text is not None and not opts.force:
        reasons = gateways_differences(text, wanted)
        row(
            "FAIL",
            "drift",
            f"{gw_path} — {'; '.join(reasons)} — pass --force to rewrite",
        )
        return 0, 1
    try:
        atomic_write(gw_path, wanted)
    except OSError as exc:
        row("FAIL", "unwritable", f"{gw_path} — {exc}")
        return 0, 1
    verb = "rewrote" if text is not None else "wrote"
    row(
        "PASS",
        verb,
        f"{gw_path} — platforms: {gateways_keys(gateways)}, sha256 {digest(wanted)}",
    )
    return 1, 0


# --- main ----------------------------------------------------------------------


def prepare_dir(path: str, dry: bool) -> None:
    """The output directory must be creatable and writable, or the run refuses."""
    if dry:
        return
    try:
        os.makedirs(path, exist_ok=True)
    except OSError as exc:
        raise Refused(f"cannot create the config directory {path}: {exc}") from exc
    if not os.access(path, os.W_OK):
        raise Refused(f"the config directory {path} is not writable")


def build(argv: Optional[list] = None) -> tuple:
    ap = argparse.ArgumentParser(
        description="generate one bunker-provision config per project from the registry"
    )
    ap.add_argument("--db", default=os.environ.get("SCHEDULER_DB", DEFAULT_DB))
    ap.add_argument(
        "--projects",
        default=DEFAULT_PROJECTS_DIR,
        help="output directory for <project>.conf",
    )
    ap.add_argument(
        "--project",
        action="append",
        default=[],
        metavar="NAME",
        help="one project (repeatable); its lanes name it as a prefix",
    )
    ap.add_argument(
        "--prefix",
        action="append",
        default=[],
        metavar="NAME",
        help="a lane-name prefix to scope the run (repeatable)",
    )
    ap.add_argument("--server", default="", help="bunker server for every config")
    ap.add_argument("--harness", default=DEFAULT_HARNESS)
    ap.add_argument("--ref", default=DEFAULT_REF)
    ap.add_argument("--ttl", default=DEFAULT_TTL)
    ap.add_argument(
        "--repo-url",
        default="",
        help="override REPO (the registry's local: paths do not clone remotely)",
    )
    ap.add_argument(
        "--gateways",
        default="",
        metavar="FILE",
        help="M13 §3 gateways input (JSON): platforms.<platform>.{enabled, token_env, "
        "home_channel, allowed_chats} — emits <project>.gateways.json beside every "
        "config in the run; tokens ride as token_env references (R2), never as bytes",
    )
    ap.add_argument("--force", action="store_true", help="rewrite a differing config")
    ap.add_argument("--check", action="store_true", help="read-only drift check")
    ap.add_argument(
        "--dry-run", action="store_true", help="print the configs, write nothing"
    )
    return ap.parse_args(argv)


def run(opts: argparse.Namespace) -> int:
    global ROW_STREAM
    if opts.dry_run:
        ROW_STREAM = sys.stderr
    outdir = expand(opts.projects)
    headline(
        f"bunker-config-gen — db={expand(opts.db)} out={outdir} "
        f"harness={opts.harness} ref={opts.ref}"
    )

    if not opts.server:
        row("FAIL", "server", "SERVER unset — a config names no host to provision on")
        headline("BUNKER-CONFIG: REFUSED (1)")
        return EXIT_REFUSED

    # the gateways input is validated before the registry is even opened: a bad input
    # refuses the whole run and nothing is written (the tool's all-or-nothing law)
    gateways_block = None
    if opts.gateways:
        try:
            gateways_block = load_gateways(opts.gateways)
        except Refused as exc:
            row("FAIL", "gateways", str(exc))
            headline("BUNKER-CONFIG: REFUSED (1) — nothing written")
            return EXIT_REFUSED
        note(
            f"gateways — platforms: {gateways_keys(gateways_block)} — tokens ride as "
            "token_env references only (M13 R2); no value is read or written"
        )

    refusals = []
    try:
        rows = load_rows(opts.db)
    except Refused as exc:
        row("FAIL", "db", str(exc))
        headline("BUNKER-CONFIG: REFUSED (1)")
        return EXIT_REFUSED
    scope = [r for r in rows if selected(r, opts.project, opts.prefix)]
    note(f"scope — {len(scope)} of {len(rows)} registry rows selected")
    if not scope:
        row("FAIL", "scope", "no registry row matches --project/--prefix")
        headline("BUNKER-CONFIG: REFUSED (1)")
        return EXIT_REFUSED

    # resolve every row's repo target; a phantom is refused by name and excluded
    groups: dict = {}
    remote = set()
    for item in scope:
        try:
            target = resolve_repo(item["repo_url"])
        except Refused as exc:
            row("FAIL", item["name"], str(exc))
            refusals.append(item["name"])
            continue
        key = target["value"]
        entry = groups.setdefault(
            key, {"repo": key, "kind": target["kind"], "rows": [], "names": []}
        )
        entry["rows"].append(item)
        entry["names"].append(item["name"])
        if target["kind"] == "remote":
            remote.add(key)
    if remote:
        note(
            f"{counts(len(remote), 'repo target')} is a remote URL — existence is "
            "not verifiable offline, so REPO is written as the registry spells it"
        )

    # name each group, refusing an ambiguous or unsafe one
    projects = {}
    for key, group in sorted(groups.items()):
        label = ", ".join(sorted(group["names"])[:3])
        try:
            project = derive_project(group["names"])
        except Refused as exc:
            row("FAIL", f"group[{label}]", f"{str(exc)} — refusing to guess")
            refusals.append(f"group[{label}]")
            continue
        if not SLUG_RE.match(project) or len(project) > 63:
            row(
                "FAIL",
                project,
                "not a safe slug ([a-z0-9-], no edge hyphen, <=63 chars)",
            )
            refusals.append(project)
            continue
        if project in projects:
            row(
                "FAIL",
                project,
                f"two repo targets derive this name ({projects[project]['repo']} and "
                f"{key}) — refusing to guess",
            )
            refusals.append(project)
            continue
        group["project"] = project
        projects[project] = group
        enabled = sum(1 for r in group["rows"] if r["enabled"])
        row(
            "PASS",
            "project",
            f"{project} — {counts(len(group['names']), 'lane')}, "
            f"{enabled} enabled, repo target {key}",
        )
        unknown = sorted(
            n
            for n in group["names"]
            if n != project and not any(n.endswith(s) for s in SATELLITE_SUFFIXES)
        )
        if unknown:
            row(
                "WARN",
                "suffix",
                f"{', '.join(unknown)} — lane name carries a word "
                "that is not one of the nine fleet suffixes",
            )
        if group["kind"] == "local":
            row(
                "WARN",
                "local_repo",
                f"REPO is the local path {key} — a remote node "
                "cannot clone it; pass --repo-url to override",
            )

    # A lane whose family key is another project, but whose repo_url names a
    # different clone, is the CF-091 disagreement: the fleet says it belongs to
    # that project, the registry says it clones something else. It gets its own
    # config (one clone, one bunker) and the disagreement is named, not merged.
    for project, group in sorted(projects.items()):
        for item in group["rows"]:
            family = base_name(item["name"])
            if family == project or family not in projects:
                continue
            other = projects[family]["repo"]
            if other != group["repo"]:
                row(
                    "WARN",
                    "repo_disagreement",
                    f"{item['name']} belongs to {family} ({other}) by name but "
                    f"names {group['repo']} — one config per clone (CF-091)",
                )
                break

    # AGENT collisions across the run: the derivation is lossy, so measure it
    users: dict = {}
    for project in sorted(projects):
        agent = derive_agent(project)
        projects[project]["agent"] = agent
        users.setdefault(agent, []).append(project)
    for agent, owners in sorted(users.items()):
        if len(owners) > 1:
            row(
                "FAIL",
                "agent",
                f"'{agent}' derived by {' and '.join(owners)} — refusing to guess",
            )
            refusals.extend(owners)

    configs = []
    for project, group in sorted(projects.items()):
        values = build_config(project, group, opts)
        if group["namespace_note"]:
            row("WARN", "namespace", group["namespace_note"])
        if len(users[group["agent"]]) == 1:
            row("PASS", "agent", f"{values['AGENT']} — unique across the run")
        configs.append(
            (
                project,
                values,
                os.path.join(outdir, f"{project}.conf"),
                gateways_block,
            )
        )

    note(
        "token files are named as paths under ~/.config/code-factory/<project>/; "
        "no value is read or written"
    )
    note(
        "CRIER_URL, DUCKBRAIN_URL and NODE_ENV_FILE are host facts — add them per "
        "environment, not here"
    )

    if refusals:
        headline(f"BUNKER-CONFIG: REFUSED ({len(refusals)}) — nothing written")
        return EXIT_REFUSED

    try:
        prepare_dir(outdir, opts.dry_run or opts.check)
    except Refused as exc:
        row("FAIL", "output_dir", str(exc))
        headline("BUNKER-CONFIG: REFUSED (1) — nothing written")
        return EXIT_REFUSED

    if opts.dry_run:
        note("dry-run — nothing written; rows on stderr, configs on stdout")
        print_configs(configs)
        headline(f"BUNKER-CONFIG: DRY-RUN — {len(configs)} config(s) predicted")
        return EXIT_OK
    if opts.check:
        return check_mode(configs, opts)
    return write_mode(configs, opts)


def main(argv: Optional[list] = None) -> int:
    opts = build(argv)
    try:
        return run(opts)
    except Refused as exc:
        row("FAIL", "refused", str(exc))
        headline("BUNKER-CONFIG: REFUSED (1) — nothing written")
        return EXIT_REFUSED


if __name__ == "__main__":
    sys.exit(main())
