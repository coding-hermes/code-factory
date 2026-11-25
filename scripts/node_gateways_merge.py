#!/usr/bin/env python3
"""node_gateways_merge.py — merge a bunker's chat-gateways block into ~/.hermes/config.yaml.

  node_gateways_merge.py <gateways.json> --check | --apply
  node_gateways_merge.py --validate <gateways.json>

specs/M13-chat-gateways.md §4: scripts/bunker_config_gen.py --gateways emits a
byte-deterministic sibling <project>.gateways.json beside every provision config, and
bunker-provision.sh stages that artifact onto the node and runs THIS merge, so the
bunker's ~/.hermes/config.yaml carries the §3 platforms block at provision and at every
re-sync (--apply is the re-sync: it is idempotent). The tool is staged, run and removed
the same way node_env.py and node_gateway_auth.py are; --validate is the control-host
side of the same validator, used to refuse a bad artifact before anything is staged.

Laws the merge enforces. The generator refuses these upstream; the node does not trust
the transport and refuses again:

  R2   the artifact NAMES tokens, never carries them: any token-shaped literal anywhere
       in the artifact refuses the merge. The merged config carries token_env NAMES
       only, so a token scan over the node home stays empty while the gateway is live.
  R3   a scheduler-only lane has no artifact at all and bunker-provision.sh never
       stages this tool for one; an artifact that declares no platforms object is
       refused here rather than half-applied.
  R5   any platform key is data and merges verbatim; only the key SHAPE (lowercase
       [a-z0-9_-], leading letter) is law, because it becomes a config.yaml key.

Merge contract:

  * The merge owns exactly two top-level keys — platforms and gateways. Their blocks
    (when present) are REPLACED wholesale by the artifact's rendering: they are
    generated data, not hand-editable state. Every other line of the config, including
    dashboard.basic_auth, is preserved byte for byte.
  * Rendered blocks are deterministic: keys sorted at every level, strings JSON-quoted,
    two-space indent. A second merge of the same artifact is byte-identical, and
    --apply says "already merged" instead of rewriting.
  * A top-level `platforms:`/`gateways:` carrying an inline value (`platforms: {}`) or
    spelled twice is refused — that shape is not modeled here and a human must
    reconcile it. Nothing is written on any refusal.
  * An absent config.yaml is created (mode 600, parent 700) carrying the merged
    blocks: a fresh node can meet this merge before any other config writer runs.

Token references (M13 §5): every platform's token_env is probed against this node's
environment on --check and --apply. An unresolved reference prints
GATEWAY_TOKEN_REF_UNRESOLVED as a WARNING — never a failure, never a nonzero exit: the
gateway starts disabled and the lane runs scheduler-only until the variable lands.

Exit codes: 0 merged or already matching (unresolved references still warn), 1 drift
(--check measured a difference), 2 refused (artifact or config rejected; nothing
written). FAIL rows go to stderr, every other row and the `gateway_*` markers to
stdout, so a caller can grade the run from one stream and match markers from both.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import sys

# The R2 detector — the same shape the generator refuses and verify-node scans for.
TOKEN_RE = re.compile(r"[0-9]{8,10}:[A-Za-z0-9_-]{35}")
# A platform key becomes a config.yaml key: data (R5), but its shape is still law.
PLATFORM_RE = re.compile(r"^[a-z][a-z0-9_-]*$")
# token_env names an environment variable: uppercase with underscores, never empty.
TOKEN_ENV_RE = re.compile(r"^[A-Z][A-Z0-9_]*$")
SECTION_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_.-]*):(.*)$")
USAGE = (
    "usage: node_gateways_merge.py <gateways.json> --check | --apply"
    " | node_gateways_merge.py --validate <gateways.json>"
)
UNRESOLVED_MARKER = "GATEWAY_TOKEN_REF_UNRESOLVED"
# The keys this merge owns, in the order they are written (spec §3 order).
OWNED_KEYS = ("platforms", "gateways")


class Refused(Exception):
    """A named refusal: one FAIL row on stderr, exit 2, nothing written."""


def row(kind: str, detail: str, label: str = "gateways") -> None:
    stream = sys.stderr if kind == "FAIL" else sys.stdout
    print(f"  {kind}  {label} — {detail}", file=stream)


def note(text: str) -> None:
    print(f"  ..    {text}")


def digest(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:12]


# --- artifact validation (the generator's law, restated node-side) -----------------


def validate_platform(name: str, entry) -> None:
    if not PLATFORM_RE.match(name):
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


def load_artifact(path: str) -> dict:
    """The validated M13 §3 block, or a named refusal. The artifact is never trusted."""
    try:
        with open(path, encoding="utf-8") as handle:
            raw = handle.read()
    except OSError as exc:
        raise Refused(f"gateways artifact unreadable: {path} — {exc}") from exc
    if TOKEN_RE.search(raw):
        raise Refused(
            "gateways artifact carries token bytes (M13 R2) — it may only name a "
            "token_env; refusing to merge, and nothing was written"
        )
    try:
        doc = json.loads(raw)
    except ValueError as exc:
        raise Refused(f"gateways artifact is not JSON: {path} — {exc}") from exc
    if TOKEN_RE.search(json.dumps(doc, ensure_ascii=False)):
        raise Refused("gateways artifact carries token bytes (M13 R2); nothing was written")
    if not isinstance(doc, dict):
        raise Refused(f"gateways artifact must be a JSON object: {path}")
    platforms = doc.get("platforms")
    if not isinstance(platforms, dict) or not platforms:
        raise Refused(
            "gateways artifact declares no platforms object — a scheduler-only lane "
            "carries no artifact at all (M13 R3)"
        )
    for name, entry in platforms.items():
        validate_platform(name, entry)
    gateways = doc.get("gateways", {"loop_watchdog": {}})
    if not isinstance(gateways, dict):
        raise Refused("gateways must be an object when present")
    return {"platforms": platforms, "gateways": gateways}


def platform_keys(doc: dict) -> str:
    return ", ".join(sorted(doc.get("platforms", {})))


# --- deterministic rendering -------------------------------------------------------


def yaml_scalar(value) -> str:
    """One scalar as YAML. Strings are JSON-quoted: unambiguous and deterministic."""
    if value is True:
        return "true"
    if value is False:
        return "false"
    if value is None:
        return "null"
    if isinstance(value, int):
        return str(value)
    return json.dumps(value, ensure_ascii=False)


def render_value(key: str, value, depth: int) -> list:
    """The lines for one key at a given depth; empty containers render inline."""
    pad = "  " * depth
    if isinstance(value, dict):
        if not value:
            return [f"{pad}{key}: {{}}\n"]
        lines = [f"{pad}{key}:\n"]
        for child in sorted(value):
            lines += render_value(str(child), value[child], depth + 1)
        return lines
    if isinstance(value, list):
        if not value:
            return [f"{pad}{key}: []\n"]
        lines = [f"{pad}{key}:\n"]
        for item in value:
            lines.append(f"{pad}  - {yaml_scalar(item)}\n")
        return lines
    return [f"{pad}{key}: {yaml_scalar(value)}\n"]


def render_block(doc: dict) -> dict:
    """{key: lines} — the deterministic YAML for each owned top-level block."""
    return {key: render_value(key, doc[key], 0) for key in OWNED_KEYS}


# --- config.yaml splicing ----------------------------------------------------------


def top_span(lines: list, key: str) -> tuple:
    """(start, end) of the top-level block for key, or (None, None).

    Mirrors node_env.py's section reader: comments and blank lines never end a block,
    the next non-blank column-0 line does. An inline value (`platforms: {}`) or a
    duplicate key is refused — a shape this editor does not model is a human's call.
    """
    start = None
    for index, line in enumerate(lines):
        raw = line.rstrip("\r\n")
        if not raw.strip() or raw.lstrip().startswith("#") or raw[0].isspace():
            continue
        match = SECTION_RE.match(raw)
        if not match or match.group(1) != key:
            continue
        tail = match.group(2).strip()
        if tail and not tail.startswith("#"):
            raise Refused(
                f"{key}: at line {index + 1} carries an inline value this editor does "
                "not model — reconcile it by hand; nothing was written"
            )
        if start is not None:
            raise Refused(
                f"{key}: appears twice (lines {start + 1} and {index + 1}) — reconcile "
                "it by hand; nothing was written"
            )
        start = index
    if start is None:
        return None, None
    end = len(lines)
    for index in range(start + 1, len(lines)):
        raw = lines[index].rstrip("\r\n")
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        if not raw[0].isspace():
            end = index
            break
    return start, end


def plan(lines: list, doc: dict) -> tuple:
    """(new lines, changed keys). Existing owned blocks are replaced IN PLACE, so a
    re-merge lands byte-identically wherever the previous merge left them. Missing
    blocks are appended together at the end of the document as one chunk — the
    separator between blocks is the document's, not the merge's, so nothing lands
    between two blocks this merge owns."""
    out = list(lines)
    changed = []
    appended: list = []
    blocks = render_block(doc)
    for key in OWNED_KEYS:
        rendered = blocks[key]
        start, end = top_span(out, key)
        if start is not None:
            # The merge owns the block's CONTENT, not the whitespace between blocks:
            # trailing blank lines are separators the document keeps, so they are
            # trimmed off the span before it is compared (and replaced). Without
            # this a re-merge never byte-compares equal against its own output.
            content_end = end
            while content_end > start + 1 and not out[content_end - 1].strip():
                content_end -= 1
            if out[start:content_end] == rendered:
                continue
            out[start:content_end] = rendered
            changed.append(key)
        else:
            appended += rendered
            changed.append(key)
    if appended:
        if out and not out[-1].endswith("\n"):
            out[-1] += "\n"
        if out and out[-1].strip():
            out.append("\n")
        out += appended
    return out, changed


def read_config(path: str) -> list:
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read().splitlines(keepends=True)
    except FileNotFoundError:
        return []
    except OSError as exc:
        raise Refused(f"cannot read {path} ({exc.strerror})") from None


def write_atomic(path: str, lines: list) -> None:
    directory = os.path.dirname(os.path.abspath(path)) or "."
    os.makedirs(directory, mode=0o700, exist_ok=True)
    tmp = f"{path}.cf-gateways-tmp-{os.getpid()}"
    try:
        with open(tmp, "w", encoding="utf-8") as handle:
            handle.writelines(lines)
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    except OSError:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def unresolved_refs(doc: dict) -> list:
    """platform:VAR for every token_env this node's environment does not answer."""
    out = []
    for name in sorted(doc["platforms"]):
        ref = doc["platforms"][name].get("token_env")
        if isinstance(ref, str) and ref and not os.environ.get(ref):
            out.append(f"{name}:{ref}")
    return out


def warn_unresolved(refs: list) -> None:
    row(
        "WARN",
        f"{UNRESOLVED_MARKER}: {' '.join(refs)} — the platform token_env has no value "
        "in this node's environment (M13 §5: warning, not fatal — the gateway starts "
        "disabled and the lane runs scheduler-only until the variable lands)",
        label="gateway_token_env",
    )
    print(f"gateway_unresolved={' '.join(refs)}")


# --- modes -------------------------------------------------------------------------


def run(path: str, mode: str) -> int:
    home = os.environ.get("HOME", "")
    if not home:
        raise Refused("HOME is unset — the config path this merge owns is unknown")
    config_path = os.path.join(home, ".hermes", "config.yaml")
    doc = load_artifact(path)
    lines = read_config(config_path)
    try:
        out, changed = plan(lines, doc)
    except Refused:
        raise
    refs = unresolved_refs(doc)

    if mode == "check":
        if refs:
            warn_unresolved(refs)
        if changed:
            row(
                "FAIL",
                f"{config_path} drifts: {' and '.join(changed)} block(s) differ from "
                f"the artifact (platforms: {platform_keys(doc)})",
            )
            print("GATEWAYS: DRIFT (1)")
            return 1
        row(
            "PASS",
            f"{config_path} matches the artifact byte for byte "
            f"(platforms: {platform_keys(doc)}, sha256 {digest(''.join(out))})",
        )
        print("GATEWAYS: PASS — no drift")
        return 0

    if changed:
        write_atomic(config_path, out)
        row(
            "PASS",
            f"merged {' and '.join(changed)} into {config_path} "
            f"(platforms: {platform_keys(doc)}, mode 600, tokens by reference — M13 R2)",
        )
        print("GATEWAYS: APPLIED (1 change)")
    else:
        row(
            "PASS",
            f"{config_path} already carries the artifact's blocks byte for byte "
            f"(platforms: {platform_keys(doc)}) — re-sync is a no-op (M13 R3)",
        )
        print("GATEWAYS: PASS — already merged (no change)")
    if refs:
        warn_unresolved(refs)
    return 0


def validate(path: str) -> int:
    doc = load_artifact(path)
    row(
        "PASS",
        f"{path} parses and carries the M13 §3 surface (platforms: "
        f"{platform_keys(doc)}) — tokens ride as token_env references, no value is "
        "read or merged (M13 R2)",
    )
    print(f"gateway_platforms={','.join(sorted(doc['platforms']))}")
    return 0


def main(argv: list) -> int:
    if argv and argv[0] in ("-h", "--help"):
        print(USAGE)
        return 0
    if argv and argv[0] == "--validate":
        if len(argv) != 2:
            print(USAGE, file=sys.stderr)
            return 2
        try:
            return validate(argv[1])
        except Refused as exc:
            row("FAIL", str(exc))
            return 2
    if len(argv) != 2 or argv[1] not in ("--check", "--apply"):
        print(USAGE, file=sys.stderr)
        return 2
    try:
        return run(argv[0], argv[1][2:])
    except Refused as exc:
        row("FAIL", str(exc))
        return 2
    except OSError as exc:
        row("FAIL", f"cannot write the merged config ({exc})")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
