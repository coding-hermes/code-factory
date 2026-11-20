#!/usr/bin/env python3
"""node_gateway_auth.py — make a public bind legal on a node: ensure dashboard.basic_auth.

A Hermes gateway refuses to bind 0.0.0.0 without dashboard.basic_auth in ~/.hermes/config.yaml,
and no stage in the create path writes it (CF-150), so NODE: PASS is unreachable on a fresh
node. This adds the block when it is absent and leaves an existing one untouched.

  node_gateway_auth.py <config.yaml> <password-file> [<username>]
  node_gateway_auth.py --check <config.yaml>

The password is generated on the node, written to <password-file> at mode 600, and NEVER
printed — stdout carries the fact and the paths, not the secret. A freshly created node has no
~/.hermes yet (the adapter that owns it runs later in the same layer), so the config's parent
directory is created here, mode 700, when it is absent.

Exit 0 = the block is present (added now or already there); 1 = the config could not be read, or
its directory could not be created / the file could not be written; 2 = the file carries no usable
dashboard.basic_auth — no direct-child block, an empty value, or YAML whose indentation
disagrees — left untouched and named on stderr. `--check` is the same decision read-only: one
`gateway_auth: <verdict>` line on stdout, exit 0 when protection is present, 2 when it is not,
1 when the config cannot be read.

THE CONTRACT (CF-395): one indentation rule, three readers
----------------------------------------------------------
`dashboard.basic_auth` is protection only when ALL of these hold:

  1. a `dashboard:` key on its own line at column 0, and the block it opens is the run of indented,
     blank and comment lines that follows it — it ends at the first non-blank, non-comment
     column-0 line, so comments and blank lines never end it;
  2. that block's indentation is consistent: a line indented deeper than the mapping in force may
     only follow a key that opened a block (`key:` with no inline value), siblings that share a
     mapping share one indent, and nothing in the block is shallower than its first child. A block
     whose children disagree on indentation is invalid YAML, not a pass;
  3. `basic_auth:` sits at the block's DIRECT-child indent. `dashboard.child.basic_auth` is a
     different path and is not protection, a sibling top-level key's `basic_auth:` lies outside the
     block entirely, and a column-0 `basic_auth:` is a top-level key of its own — while a direct
     one passes however deep in the block it sits;
  4. `basic_auth` is a block mapping whose `username` and `password` are both non-empty string
     scalars. A valueless `basic_auth:`, a scalar value, and an empty (or non-string, or quoted
     empty) username/password are the consumer gate's "empty value".

The three parties that read this contract are: THIS MODULE (the producer, and the verdict its
`--check` mode reports), `scripts/project-node.sh --check` (whose `gateway_auth` row delegates to
`--check`, with a tightened shell fallback that implements the same four rules when python3 or this
module is unavailable), and `scripts/harness/install-hermes.sh`'s `check_public_bind_auth` (the
consumer gate that authorises the public bind, and the authority whenever the three disagree). The
gate's YAML reader models a WIDER document than this contract states — duplicate keys, scalars
outside the block, unsupported node syntax — so a file can satisfy this contract and still be
refused there; the shapes the contract names are held identical by `tests/gateway_auth_parity.sh`,
and each rule is pinned by `tests/test_node_gateway_auth.py`.
"""

import json
import os
import re
import secrets
import sys

# The consumer gate's vocabulary, verbatim (scripts/harness/install-hermes.sh,
# check_public_bind_auth). One string per verdict, so a caller can match the same token from all
# three parties instead of translating three dialects.
PRESENT = "present"
ABSENT = "block absent"
INVALID = "block absent (invalid YAML)"
UNREADABLE = "block absent (config unreadable)"
COMMENTED = "commented"
EMPTY = "empty value (username and password must both be non-empty)"

USAGE = (
    "usage: node_gateway_auth.py <config.yaml> <password-file> [username]"
    " | --check <config.yaml>"
)

_KEY = re.compile(r"^([A-Za-z_][A-Za-z0-9_.-]*):(?:\s+(.*))?$")
_COMMENTED_KEY = re.compile(r"^\s*#\s*basic_auth\s*:")
# Plain YAML scalars that are not strings: the gate's own `scalar()` refuses them, so a
# `password: 1234` there and an empty value here must be the same verdict.
_NUMBER = re.compile(
    r"[-+]?(?:[0-9][0-9_]*(?:\.[0-9_]*)?(?:[eE][-+]?[0-9]+)?"
    r"|\.[0-9_]+(?:[eE][-+]?[0-9]+)?|0[xX][0-9a-fA-F_]+"
    r"|0[bBoO][0-9_]+|[0-9_]+(?::[0-9_]+)+(?:\.[0-9_]*)?"
    r"|\.(?:inf|Inf|INF|nan|NaN|NAN))"
)
_TIMESTAMP = re.compile(r"[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}(?:$|[Tt\s])")
_NOT_STRING = {"null", "~", "true", "false", "yes", "no", "on", "off"}
# Leading characters of YAML syntax this line-based contract does not model; the gate's scalar()
# raises on them, which refuses the whole document as invalid YAML.
_UNSUPPORTED = "[]{}&*!|>@`%"


def content(raw: str) -> str:
    """The line with any trailing comment removed; quotes protect a `#`.

    A `#` starts a comment only at the start of the line or after whitespace, and a quoted
    section is copied through untouched. Mirrors the consumer gate's own `content()`, so a value
    with a trailing `# note` reads the same in both parties. An unterminated quote raises
    ValueError — the gate reads that as invalid YAML.
    """
    text = raw.rstrip("\n")
    quote = None
    i = 0
    while i < len(text):
        char = text[i]
        if quote == '"' and char == "\\":
            i += 2
            continue
        if quote == "'" and text[i : i + 2] == "''":
            i += 2
            continue
        if quote:
            if char == quote:
                quote = None
        elif char == "#" and (i == 0 or text[i - 1].isspace()):
            return text[:i].rstrip()
        elif char in "\"'" and (i == 0 or text[i - 1].isspace()):
            quote = char
        i += 1
    if quote:
        raise ValueError("unterminated quote")
    return text.rstrip()


def find_dashboard(lines: list) -> int:
    for i, line in enumerate(lines):
        if line.rstrip("\n") == "dashboard:" or line.startswith("dashboard:"):
            return i
    return -1


def dashboard_block_end(lines: list, idx: int) -> int:
    """Index just past the `dashboard:` block: its indented, blank and comment lines.

    A block ends at the first line that is non-blank, not a comment, and starts at column 0 — that
    line is a sibling (or the next) top-level key, not a child of `dashboard:`. Comments and blank
    lines never end it: the consumer gate strips comments before it parses, so a comment between
    the last key and the next top-level key is not a block boundary.
    """
    end = idx + 1
    while end < len(lines):
        content_line = lines[end].rstrip("\n")
        stripped = content_line.strip()
        if not stripped or stripped.startswith("#") or content_line[0] in " \t":
            end += 1
            continue
        break
    return end


def dashboard_children(lines: list, idx: int):
    """[(indent, text)] for the block's non-blank, non-comment lines, or None when unreadable.

    Comment and blank lines are excluded for the same reason they do not end the block: the gate
    strips them before it parses. A trailing comment is stripped from each key line, so
    `basic_auth:  # credentials` is the block-shaped key the gate sees.
    """
    items = []
    for raw in lines[idx + 1 : dashboard_block_end(lines, idx)]:
        try:
            text = content(raw)
        except ValueError:
            return None
        if not text.strip():
            continue
        items.append((len(text) - len(text.lstrip(" ")), text.strip()))
    return items


def indentation_is_consistent(items: list) -> bool:
    """True when the block's indentation is a well-formed mapping tree.

    The gate's parser requires every key of one mapping to share an indent, and lets a deeper line
    open a nested mapping only directly after a key that carries no inline value. This walks the
    same rule, so `dashboard:` with one child at two spaces and another at four is invalid YAML
    instead of a pass — and nothing may be shallower than the block's first child.
    """
    if not items:
        return True
    base = items[0][0]
    stack = []
    opened = False
    for indent, text in items:
        if indent < base:
            return False
        if text.startswith("- ") or text == "-":
            # A sequence item is not a key: it cannot open a mapping, and it closes none.
            opened = False
            continue
        while stack and indent < stack[-1]:
            stack.pop()
        if not stack:
            stack.append(indent)
        elif indent > stack[-1]:
            if not opened:
                return False
            stack.append(indent)
        elif indent != stack[-1]:
            return False
        match = _KEY.match(text)
        if not match:
            return False
        opened = not match.group(2)
    return True


def direct_basic_auth(items: list):
    """The block's direct-child `basic_auth`, as ("inline", value) / ("block", children) / None.

    Membership is indentation, and it has to be the child indent exactly: a `basic_auth:` at
    column 0 is a top-level key of its own, one belonging to a sibling top-level key lies outside
    the block, and one hanging off a CHILD key (`dashboard: > child: > basic_auth:`) is a
    different path — `dashboard.child.basic_auth`, which the consumer gate refuses.
    """
    if not items:
        return None
    base = items[0][0]
    for pos, (indent, text) in enumerate(items):
        if indent != base:
            continue
        match = _KEY.match(text)
        if not match or match.group(1) != "basic_auth":
            continue
        if match.group(2):
            return "inline", match.group(2)
        children = []
        for child_indent, child_text in items[pos + 1 :]:
            if child_indent <= base:
                break
            children.append((child_indent, child_text))
        return "block", children
    return None


def string_value(raw: str) -> str:
    """The non-empty string a scalar spells, or "" when it is not one.

    Mirrors the gate's `scalar()` for the two values that matter here: quoted scalars are
    unquoted, and a plain YAML null, boolean, number or timestamp is not a string — so
    `password: 1234` is an empty value on both sides.
    """
    value = raw.strip()
    if not value:
        return ""
    if value.startswith('"'):
        try:
            parsed = json.loads(value)
        except ValueError:
            return ""
        if isinstance(parsed, str) and parsed.strip():
            return parsed.strip()
        return ""
    if value.startswith("'"):
        if not re.fullmatch(r"'(?:[^']|'')*'", value):
            return ""
        parsed = value[1:-1].replace("''", "'")
        return parsed.strip()
    if value[0] in _UNSUPPORTED:
        return ""
    if re.match(r"[-?:](?:\s|$)", value) or re.search(r":(?:\s|$)", value):
        return ""
    if value.lower() in _NOT_STRING:
        return ""
    if _NUMBER.fullmatch(value) or _TIMESTAMP.match(value):
        return ""
    return value


def credentials_present(children: list) -> bool:
    """True when `username` and `password` are both non-empty string scalars at one indent."""
    if not children:
        return False
    child_indent = children[0][0]
    values = {}
    for indent, text in children:
        if indent != child_indent:
            continue
        match = _KEY.match(text)
        if match and match.group(1) in ("username", "password"):
            values[match.group(1)] = match.group(2) or ""
    return bool(string_value(values.get("username", ""))) and bool(
        string_value(values.get("password", ""))
    )


def absent_reason(lines: list) -> str:
    """`commented` when the file carries a commented-out basic_auth, else `block absent`."""
    for raw in lines:
        if _COMMENTED_KEY.search(raw.rstrip("\n")):
            return COMMENTED
    return ABSENT


def dashboard_auth_verdict(lines: list):
    """(protected, reason) for one config's lines; reason is the consumer gate's vocabulary.

    This is the single structural decision: the write path acts on it, `--check` prints it, and
    `scripts/project-node.sh --check` delegates to that print.
    """
    for raw in lines:
        body = raw.rstrip("\n")
        # The gate's reader refuses tabs and control characters outright: YAML indentation is
        # spaces, and a tab is not a column that rule can count.
        if "\t" in body or any(ord(char) < 32 for char in body):
            return False, INVALID
    idx = find_dashboard(lines)
    if idx < 0:
        return False, absent_reason(lines)
    try:
        header = content(lines[idx])
    except ValueError:
        return False, INVALID
    if header.strip() != "dashboard:":
        # `dashboard: <scalar>` is not a mapping, so nothing under it is dashboard.basic_auth.
        return False, absent_reason(lines)
    items = dashboard_children(lines, idx)
    if items is None or not indentation_is_consistent(items):
        return False, INVALID
    found = direct_basic_auth(items)
    if found is None:
        return False, absent_reason(lines)
    kind, payload = found
    if kind == "inline":
        value = payload.strip()
        if value and value[0] in _UNSUPPORTED:
            return False, INVALID
        return False, EMPTY
    return (True, PRESENT) if credentials_present(payload) else (False, EMPTY)


def check_config(config: str) -> int:
    """Read-only verdict for one config: 0 protected, 2 not protected, 1 unreadable.

    One `gateway_auth: <verdict>` line on stdout, in the consumer gate's own words. Nothing is
    written, no secret is generated, and the config's directory is never created.
    """
    try:
        with open(config) as fh:
            lines = fh.readlines()
    except OSError:
        print(f"gateway_auth: {UNREADABLE}")
        return 1
    protected, reason = dashboard_auth_verdict(lines)
    if protected:
        print(f"gateway_auth: {PRESENT}")
        return 0
    print(f"gateway_auth: {reason}")
    return 2


def main(argv: list) -> int:
    if argv and argv[0] == "--check":
        if len(argv) != 2:
            print(USAGE, file=sys.stderr)
            return 2
        return check_config(argv[1])
    if len(argv) < 2:
        print(USAGE, file=sys.stderr)
        return 2
    config, password_file = argv[0], argv[1]
    username = argv[2] if len(argv) > 2 else "node"

    try:
        with open(config) as fh:
            lines = fh.readlines()
    except FileNotFoundError:
        lines = []
    except OSError as exc:
        print(f"FAIL  gateway_auth — cannot read {config} ({exc})", file=sys.stderr)
        return 1

    idx = find_dashboard(lines)
    if idx >= 0:
        protected, reason = dashboard_auth_verdict(lines)
        if protected:
            print(
                f"PASS  gateway_auth — dashboard.basic_auth already present in {config}"
            )
            return 0
        if reason == EMPTY:
            print(
                f"FAIL  gateway_auth — {config}:{idx + 1} has a dashboard.basic_auth with an "
                "empty value (username and password must both be non-empty); left untouched "
                "(a human must reconcile it)",
                file=sys.stderr,
            )
        elif reason == INVALID:
            print(
                f"FAIL  gateway_auth — {config}:{idx + 1} has a dashboard block whose "
                "indentation is invalid YAML; left untouched (a human must reconcile it)",
                file=sys.stderr,
            )
        else:
            print(
                f"FAIL  gateway_auth — {config}:{idx + 1} has a dashboard block without "
                "basic_auth; left untouched (a human must reconcile it)",
                file=sys.stderr,
            )
        return 2

    # CF-388: on a freshly created node ~/.hermes does not exist yet — the harness adapter that
    # creates it runs LATER in the same layer — so the config's parent is this writer's
    # precondition, not the caller's. 0700 because that directory holds the gateway credential.
    # Nothing is created when the block is already present (the early return above), so a re-run
    # still changes nothing; a failure here is named and exits nonzero rather than escaping as a
    # traceback, because the caller's row would then report a staging failure with no reason.
    config_dir = os.path.dirname(config)
    if config_dir:
        try:
            os.makedirs(config_dir, mode=0o700, exist_ok=True)
        except OSError as exc:
            print(
                f"FAIL  gateway_auth — cannot create {config_dir} ({exc})",
                file=sys.stderr,
            )
            return 1

    password = secrets.token_urlsafe(24)
    try:
        os.makedirs(os.path.dirname(password_file) or ".", exist_ok=True)
        fd = os.open(password_file, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as fh:
            fh.write(password + "\n")
        os.chmod(password_file, 0o600)
    except OSError as exc:
        print(
            f"FAIL  gateway_auth — cannot write {password_file} ({exc})",
            file=sys.stderr,
        )
        return 1

    if lines and not lines[-1].endswith("\n"):
        lines[-1] += "\n"
    lines += [
        "\n",
        "dashboard:\n",
        "  basic_auth:\n",
        f"    username: {username}\n",
        f"    password: {password}\n",
    ]
    tmp = config + ".cf-tmp"
    try:
        with open(tmp, "w") as fh:
            fh.writelines(lines)
        os.chmod(tmp, 0o600)
        os.replace(tmp, config)
    except OSError as exc:
        print(
            f"FAIL  gateway_auth — cannot write {config} ({exc})",
            file=sys.stderr,
        )
        return 1

    print(
        f"PASS  gateway_auth — added dashboard.basic_auth (user {username}) to {config}"
    )
    print(
        f"PASS  gateway_auth — password stored at {password_file}, mode 600 (not printed)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
