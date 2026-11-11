#!/usr/bin/env python3
"""node_env.py — apply a declared environment profile to a node, and nothing else.

  node_env.py --env-file <profile> [--config-set <dotted.key>=<value> ...] --check|--apply

A node's environment — the variables in ~/.hermes/.env plus a few scalar keys in
~/.hermes/config.yaml — is currently hand-edited state: it cannot be reviewed, diffed or
re-applied, so a rebuilt node is a different node. This makes it declared data.

Profile grammar: one declaration per line, comments with '#', nothing else is accepted.

  ENV_<NAME>=<value>     the literal value goes into ~/.hermes/.env
  ENV_<NAME>=@<path>     the value is READ FROM <path> on the node

The second form is the only way a secret may be expressed, and a name that looks secret
(KEY|TOKEN|SECRET|PASS) MUST use it. A literal secret in a file that is committed, copied
and logged is a credential leak with a friendly name (AGENTS.md rule 8, CF-002).

--config-set patches one of the five scalars this node's harness actually reads; any other
path is refused by name rather than invented:

  model.provider  model.name  gateway.bind  gateway.port  agent.max_iterations

--check prints the diff and writes nothing: exit 0 when the node matches, 1 when it drifts,
2 when the declaration itself is refused (unreadable profile, a non-ENV line, a literal
secret, an unknown config path, a value out of range). --apply writes both files atomically
at mode 600, keeps every line it does not own, and is idempotent: a second run reports no
change and exits 0.

Variables present in ~/.hermes/.env that the profile does not declare are reported as
unmanaged — with masked values — so an operator can see what a re-provision carries forward.
They are a WARN, never a drift: --apply must not delete state it does not own, and a check
that went red on them could never go green without hand-editing the node.

No secret is ever printed. A row describing a secret-named key renders '***', and any
secret value that would otherwise reach a row is scrubbed first.
"""

import json
import os
import re
import sys
import tempfile

USAGE = (
    "usage: node_env.py --env-file <profile> [--config-set <dotted.key>=<value> ...] "
    "--check|--apply"
)

SECRET_NAME = re.compile(r"KEY|TOKEN|SECRET|PASS", re.IGNORECASE)
PROFILE_LINE = re.compile(r"^ENV_([A-Za-z_][A-Za-z0-9_]*)=(.*)$")
ENV_LINE = re.compile(r"^(?:export[ \t]+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$")
SECTION = re.compile(r"^([A-Za-z_][A-Za-z0-9_.-]*):(.*)$")
CHILD = re.compile(r"^([ \t]+)([A-Za-z_][A-Za-z0-9_.-]*):(.*)$")
SAFE_ENV = re.compile(r"^[A-Za-z0-9_./:@+~%,=-]+$")
SAFE_YAML = re.compile(r"^[A-Za-z0-9_./:@+=,-]+$")
INTEGER = re.compile(r"^[0-9]+$")

# The only config.yaml scalars a node profile may own. Anything else is a path the harness
# does not read, or one whose shape (a list, a nested map) a line editor cannot own safely.
ALLOWED_CONFIG = {
    "agent.max_iterations": (1, 100000),
    "gateway.bind": None,
    "gateway.port": (1, 65535),
    "model.name": None,
    "model.provider": None,
}
ALLOWED_LIST = ", ".join(sorted(ALLOWED_CONFIG))

_SECRET_VALUES = set()


class Refusal(Exception):
    """A declaration this script will not apply; carries the row it prints."""

    def __init__(self, subject, detail):
        super().__init__(detail)
        self.subject = subject
        self.detail = detail


def redact(text):
    """Scrub every secret value this run learned, in case one reached a message."""
    for value in _SECRET_VALUES:
        if len(value) >= 4:
            text = text.replace(value, "***")
    return text


def row(kind, subject, detail, stream=None):
    stream = sys.stdout if stream is None else stream
    print(redact(f"  {kind}  {subject} — {detail}"), file=stream)


def fail(subject, detail):
    row("FAIL", subject, detail, sys.stderr)


def note(detail):
    print(redact(f"  ..    {detail}"))


def is_secret(name):
    return bool(SECRET_NAME.search(name))


def describe(name, value):
    """How one side of a diff is allowed to appear in a row."""
    if value is None:
        return "<absent>"
    if is_secret(name):
        return "***"
    return json.dumps(value)


def describe_config(path, value):
    """A config scalar: integers read without quotes, everything else quoted."""
    if value is None:
        return "<absent>"
    if ALLOWED_CONFIG.get(path) is not None:
        return value
    return json.dumps(value)


def unquote(raw):
    value = raw.strip()
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        try:
            parsed = json.loads(value)
        except ValueError:
            return value
        return parsed if isinstance(parsed, str) else value
    if len(value) >= 2 and value[0] == "'" and value[-1] == "'":
        return value[1:-1].replace("''", "'")
    return value


def format_env(value):
    if not value:
        return ""
    if SAFE_ENV.match(value) and not value.startswith("#"):
        return value
    return json.dumps(value)


def format_yaml(path, value):
    if ALLOWED_CONFIG[path] is not None:
        return str(int(value))
    if (
        SAFE_YAML.match(value)
        and value[0] not in "-?:#&*!|>'\"%@`"
        and not value.endswith(":")
    ):
        return value
    return json.dumps(value)


def split_comment(text):
    """Split a YAML scalar from its trailing comment, respecting quotes."""
    body = text.rstrip()
    quote = None
    for index, char in enumerate(body):
        if quote:
            if char == quote:
                quote = None
            continue
        if char in "\"'":
            quote = char
        elif char == "#" and index and body[index - 1].isspace():
            return body[:index].rstrip(), body[index:].strip()
    return body, ""


# --- the profile -----------------------------------------------------------------------------


def read_secret(name, raw, where):
    """Resolve one declaration. A literal value for a secret-named key is refused."""
    if not raw.startswith("@"):
        if is_secret(name):
            raise Refusal(
                "env",
                f"{where}: ENV_{name} looks secret and carries a literal value — "
                f"declare ENV_{name}=@<path-on-the-node> instead",
            )
        return raw
    path = raw[1:]
    if not path:
        raise Refusal("env", f"{where}: ENV_{name}=@ names no file")
    if path.startswith("~/"):
        path = os.path.join(os.path.expanduser("~"), path[2:])
    try:
        with open(path, encoding="utf-8") as handle:
            data = handle.read()
    except OSError as exc:
        raise Refusal(
            "env", f"{where}: ENV_{name}=@{path} cannot be read ({exc.strerror})"
        ) from None
    value = data.rstrip("\r\n")
    if not value.strip():
        raise Refusal("env", f"{where}: ENV_{name}=@{path} is empty")
    if "\n" in value or "\r" in value:
        raise Refusal(
            "env",
            f"{where}: ENV_{name}=@{path} holds more than one line — an env value cannot",
        )
    return value


def read_profile(path):
    try:
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
    except OSError as exc:
        raise Refusal(
            "env", f"cannot read the profile {path} ({exc.strerror})"
        ) from None
    base = os.path.basename(path)
    declared = []
    seen = {}
    for number, raw in enumerate(text.splitlines(), 1):
        line = raw.rstrip("\r")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        match = PROFILE_LINE.match(line)
        if not match:
            raise Refusal(
                "env",
                f"{base}:{number} is not ENV_<NAME>=<value> — a profile is data, never a script",
            )
        name, raw_value = match.group(1), match.group(2)
        if name in seen:
            raise Refusal(
                "env",
                f"{base}:{number} declares ENV_{name} twice (first at line {seen[name]})",
            )
        seen[name] = number
        value = read_secret(name, raw_value, f"{base}:{number}")
        declared.append((name, value))
        if is_secret(name):
            _SECRET_VALUES.add(value)
    return declared


def parse_config_sets(items):
    assigns = {}
    for item in items:
        if "=" not in item:
            raise Refusal(
                "config", f"--config-set needs <dotted.key>=<value>, got: {item!r}"
            )
        path, value = item.split("=", 1)
        if path not in ALLOWED_CONFIG:
            raise Refusal(
                "config", f"unknown config path {path!r} — allowed: {ALLOWED_LIST}"
            )
        if "\n" in value or "\r" in value or "\t" in value:
            raise Refusal("config", f"{path}: value carries a control character")
        bounds = ALLOWED_CONFIG[path]
        if bounds is not None:
            if not INTEGER.match(value.strip()):
                raise Refusal("config", f"{path}: {value!r} is not an integer")
            number = int(value)
            if not bounds[0] <= number <= bounds[1]:
                raise Refusal(
                    "config", f"{path}: {number} is outside {bounds[0]}..{bounds[1]}"
                )
            value = str(number)
        elif not value.strip():
            raise Refusal("config", f"{path}: empty value")
        assigns[path] = (
            value  # a repeated path takes the last value: the command line wins
        )
    return list(assigns.items())


# --- ~/.hermes/.env --------------------------------------------------------------------------


def read_env(path):
    try:
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
    except FileNotFoundError:
        return []
    except OSError as exc:
        raise Refusal("env", f"cannot read {path} ({exc.strerror})") from None
    return text.splitlines(keepends=True)


def env_values(lines):
    values = {}
    for line in lines:
        match = ENV_LINE.match(line.rstrip("\r\n"))
        if match:
            values[match.group(1)] = unquote(match.group(2))
    return values


def plan_env(lines, declared):
    """Rewrite only the declared keys, in place, keeping every other line byte for byte."""
    index = {}
    for number, line in enumerate(lines):
        match = ENV_LINE.match(line.rstrip("\r\n"))
        if match:
            index[match.group(1)] = number
    current = env_values(lines)
    changes = []
    out = list(lines)
    appended = []
    for name, value in declared:
        old = current.get(name)
        if old == value:
            continue
        changes.append((name, old, value))
        line = f"{name}={format_env(value)}"
        if name in index:
            out[index[name]] = line + "\n"
        else:
            appended.append(line)
    if appended:
        if out and not out[-1].endswith("\n"):
            out[-1] += "\n"
        out.extend(line + "\n" for line in appended)
    return out, changes, current


# --- ~/.hermes/config.yaml -------------------------------------------------------------------


def read_config(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read().splitlines(keepends=True)
    except FileNotFoundError:
        return []
    except OSError as exc:
        raise Refusal("config", f"cannot read {path} ({exc.strerror})") from None


def section_span(lines, section):
    start = None
    for number, line in enumerate(lines):
        raw = line.rstrip("\r\n")
        if not raw.strip() or raw.lstrip().startswith("#") or raw[0].isspace():
            continue
        match = SECTION.match(raw)
        if not match or match.group(1) != section:
            continue
        tail = match.group(2).strip()
        if tail and not tail.startswith("#"):
            raise Refusal(
                "config",
                f"{section}: at line {number + 1} carries an inline value this editor "
                "does not model — reconcile it by hand",
            )
        if start is not None:
            raise Refusal(
                "config",
                f"{section}: appears twice (lines {start + 1} and {number + 1})",
            )
        start = number
    if start is None:
        return None, None
    end = len(lines)
    for number in range(start + 1, len(lines)):
        raw = lines[number].rstrip("\r\n")
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        if not raw[0].isspace():
            end = number
            break
    return start, end


def same_value(path, current, value):
    if ALLOWED_CONFIG[path] is not None:
        return current.strip() == str(int(value))
    return current == value


def set_scalar(lines, path, value):
    """-> (lines, current, changed). Only the one leaf line is rewritten."""
    section, leaf = path.split(".", 1)
    start, end = section_span(lines, section)
    formatted = format_yaml(path, value)
    if start is None:
        if lines and not lines[-1].endswith("\n"):
            lines = lines[:-1] + [lines[-1] + "\n"]
        if lines and lines[-1].strip():
            lines = lines + ["\n"]
        return lines + [f"{section}:\n", f"  {leaf}: {formatted}\n"], None, True
    for number in range(start + 1, end):
        match = CHILD.match(lines[number].rstrip("\r\n"))
        if not match or match.group(2) != leaf:
            continue
        indent, body = match.group(1), match.group(3)
        text, comment = split_comment(body)
        current = unquote(text)
        if current and same_value(path, current, value):
            return lines, current, False
        rewritten = f"{indent}{leaf}: {formatted}{' ' + comment if comment else ''}\n"
        return lines[:number] + [rewritten] + lines[number + 1 :], current, True
    insert_at, indent = start + 1, "  "
    for number in range(start + 1, end):
        match = CHILD.match(lines[number].rstrip("\r\n"))
        if match:
            insert_at, indent = number + 1, match.group(1)
    new = lines[:insert_at] + [f"{indent}{leaf}: {formatted}\n"] + lines[insert_at:]
    return new, None, True


def plan_config(lines, assigns):
    changes = []
    out = list(lines)
    for path, value in assigns:
        out, current, changed = set_scalar(out, path, value)
        if changed:
            changes.append((path, current, value))
    return out, changes


# --- writes ----------------------------------------------------------------------------------


def write_atomic(path, lines):
    directory = os.path.dirname(os.path.abspath(path)) or "."
    os.makedirs(directory, mode=0o700, exist_ok=True)
    handle, temporary = tempfile.mkstemp(dir=directory, prefix=".node-env-")
    try:
        with os.fdopen(handle, "w", encoding="utf-8") as stream:
            stream.writelines(lines)
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    except Exception:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise
    os.chmod(path, 0o600)


def ensure_mode(path):
    """-> True when the mode had to be corrected."""
    try:
        current = os.stat(path).st_mode & 0o777
    except OSError:
        return False
    if current == 0o600:
        return False
    os.chmod(path, 0o600)
    return True


# --- main ------------------------------------------------------------------------------------


def parse_args(argv):
    env_file, mode = "", ""
    config_sets = []
    index = 0
    while index < len(argv):
        arg = argv[index]
        if arg in ("-h", "--help"):
            print(USAGE)
            raise SystemExit(0)
        if arg in ("--check", "--apply"):
            if mode:
                raise Refusal("env", "only one of --check and --apply")
            mode = arg[2:]
            index += 1
        elif arg in ("--env-file", "--config-set"):
            if index + 1 >= len(argv):
                raise Refusal("env", f"{arg} needs a value")
            if arg == "--env-file":
                env_file = argv[index + 1]
            else:
                config_sets.append(argv[index + 1])
            index += 2
        else:
            raise Refusal("env", f"unknown argument: {arg}")
    if not mode:
        raise Refusal("env", "one of --check or --apply is required")
    if not env_file and not config_sets:
        raise Refusal("env", "nothing declared — pass --env-file and/or --config-set")
    return env_file, config_sets, mode


def main(argv):
    try:
        env_file, config_sets, mode = parse_args(argv)
        declared = read_profile(env_file) if env_file else []
        assigns = parse_config_sets(config_sets)
        home = os.environ.get("HOME", "")
        if not home:
            raise Refusal(
                "env", "HOME is unset — the paths this applies to are unknown"
            )
        env_path = os.path.join(home, ".hermes", ".env")
        config_path = os.path.join(home, ".hermes", "config.yaml")
        env_lines = read_env(env_path)
        config_lines = read_config(config_path)
        env_out, env_changes, current_env = plan_env(env_lines, declared)
        config_out, config_changes = plan_config(config_lines, assigns)
    except Refusal as exc:
        fail(exc.subject, exc.detail)
        return 2

    print(redact(f"node-env --{mode} — home={home}"))
    note(f"env {env_path}, config {config_path}")
    note(f"declared {len(declared)} env var(s), {len(assigns)} config key(s)")

    declared_names = {name for name, _ in declared}
    pending = {name: (old, value) for name, old, value in env_changes}
    for name, value in declared:
        if name in pending:
            old = pending[name][0]
            if is_secret(name):
                where = "<absent>" if old is None else "<present>"
                row("DIFF", f"env:{name}", f"{where} -> *** (masked)")
            else:
                row(
                    "DIFF",
                    f"env:{name}",
                    f"{describe(name, old)} -> {json.dumps(value)}",
                )
        else:
            row(
                "PASS",
                f"env:{name}",
                f"matches ({describe(name, current_env.get(name))})",
            )

    pending_config = {path: (current, value) for path, current, value in config_changes}
    for path, value in assigns:
        if path in pending_config:
            current = pending_config[path][0]
            row(
                "DIFF",
                f"config:{path}",
                f"{describe_config(path, current)} -> {describe_config(path, value)}",
            )
        else:
            row("PASS", f"config:{path}", f"matches ({describe_config(path, value)})")

    unmanaged = [name for name in current_env if name not in declared_names]
    for name in unmanaged:
        row(
            "WARN",
            f"unmanaged:{name}",
            "present in the node's .env, not declared here (value masked)",
        )
    if unmanaged:
        note(f"{len(unmanaged)} unmanaged var(s) would carry forward on a re-provision")

    drift = len(env_changes) + len(config_changes)
    if mode == "check":
        if drift:
            print(f"ENV: DRIFT ({drift})")
            return 1
        print("ENV: PASS — declared environment matches")
        return 0

    try:
        if declared and (env_changes or not os.path.lexists(env_path)):
            write_atomic(env_path, env_out)
            note(f"wrote {env_path} ({len(env_changes)} change(s), mode 600)")
        elif declared and ensure_mode(env_path):
            note(f"corrected {env_path} to mode 600")
        if assigns and (config_changes or not os.path.lexists(config_path)):
            write_atomic(config_path, config_out)
            note(f"wrote {config_path} ({len(config_changes)} change(s), mode 600)")
        elif assigns and ensure_mode(config_path):
            note(f"corrected {config_path} to mode 600")
    except OSError as exc:
        fail("env", f"cannot write the node's environment ({exc.strerror})")
        return 2

    if drift:
        print(f"ENV: APPLIED ({drift} change(s))")
    else:
        print("ENV: PASS — already matches (no change)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
