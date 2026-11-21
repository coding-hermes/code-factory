#!/usr/bin/env python3
"""gitleaks_scope.py — the tier-1 "secrets" scope, DERIVED from git, never hand-listed.

GitReins' tier-1 secrets step runs ``gitleaks detect --no-git``, so it grades the
WORKING TREE: artifact content git can never commit is graded as if it were source.
CF-383 fixed exactly one instance by hand-adding bytecode to ``[allowlist].paths``,
and a hand-maintained set is what fails next — on HEAD ``cfe075c9`` tier-1 reported
**38 findings, 100% under the gitignored roots ``.tmp/`` and ``.node/`` and 0 under
any tracked path**, which reds every verdict in the repository even when lint, tests
and tier-2 all pass.

This script is the single declared scope. Its source of truth is git itself:

* ``--write`` runs ``git status --ignored --porcelain -z``, collapses every ignored
  instance to the deepest ancestor git still ignores that holds no tracked file
  (so ``patches/__pycache__/x.pyc`` becomes ``patches/__pycache__/`` and a root-level
  ignored file stays itself, while ``.coding-hermes/board/.lock`` cannot collapse
  into a directory that carries tracked content), regex-escapes the path, and
  rewrites ONLY the block in ``.gitleaks.toml`` between
  ``# BEGIN gitleaks-scope (generated)`` and ``# END gitleaks-scope (generated)``.
  The order is sorted, the write is atomic, and a second run is a byte-identical
  no-op.
* ``--check`` is the drift gate: it re-derives the same set and exits non-zero,
  naming every MISSING root (ignored content in the tree that the block does not
  cover — this is the failure that re-reds tier-1) and every STALE entry (the
  path exists here and git no longer ignores it, so the entry could hide
  committable content). An entry whose path does not exist in this working tree
  is reported DORMANT, not stale: a fresh checkout has no ``.tmp``/``.node``
  artifacts yet, and failing there would teach operators to skip the gate.

No path is hard-coded here. Any file under an ignored root is proven uncommittable
by git before it is ever excluded, so the exclusion cannot hide a key that could
land in a commit; a canary in a TRACKED file is still reported (tests/selftest.sh
section 34 drives both directions, on a root this script has never seen).

Usage:
  python3 scripts/gitleaks_scope.py --write [--repo <root>] [--config <file>]
  python3 scripts/gitleaks_scope.py --check [--repo <root>] [--config <file>]

Exit codes: 0 in sync (check) or written (write); 1 drift (check); 2 the tree or
the config cannot be used (not a git worktree, no generated block, unreadable).
"""

from __future__ import annotations

import argparse
import os
import posixpath
import re
import subprocess
import sys
import tempfile
from pathlib import Path

BEGIN = "# BEGIN gitleaks-scope (generated)"
END = "# END gitleaks-scope (generated)"
NOTE = (
    "  # Derived from `git status --ignored` by scripts/gitleaks_scope.py --write."
    " Regenerate, never hand-edit."
)
# Go (RE2) metacharacters. `\x` for any other punctuation is a no-op in RE2, but
# escaping only what is special keeps the emitted entries readable.
_META = set("\\.^$*+?()[]{}|")
_ENTRY = re.compile(r"'''(.+)''',")


class ScopeError(Exception):
    """The tree or the config cannot be used for scope derivation."""


def _git(root: Path, *args: str, stdin: bytes | None = None) -> bytes:
    try:
        proc = subprocess.run(
            ["git", "-C", str(root), *args],
            input=stdin,
            capture_output=True,
        )
    except OSError as exc:  # git not installed / not executable
        raise ScopeError(f"cannot run git in {root} ({exc.strerror or exc})") from exc
    if proc.returncode not in (0, 1):
        detail = proc.stderr.decode("utf-8", "replace").strip().splitlines()
        raise ScopeError(
            f"git {' '.join(args)} failed in {root}"
            + (f" ({detail[-1]})" if detail else "")
        )
    return proc.stdout


def _tracked(root: Path) -> tuple[set[str], set[str]]:
    """Return (tracked files, every parent directory of a tracked file)."""
    raw = _git(root, "ls-files", "-z").decode("utf-8", "surrogateescape")
    files = {p for p in raw.split("\0") if p}
    dirs: set[str] = set()
    for path in files:
        parent = posixpath.dirname(path)
        while parent and parent not in dirs:
            dirs.add(parent)
            parent = posixpath.dirname(parent)
    return files, dirs


def _ignored_instances(root: Path) -> list[tuple[str, bool]]:
    """Every ignored path in the working tree and whether it is a directory."""
    raw = _git(root, "status", "--ignored", "--porcelain", "-z")
    instances: list[tuple[str, bool]] = []
    fields = raw.decode("utf-8", "surrogateescape").split("\0")
    index = 0
    while index < len(fields):
        entry = fields[index]
        index += 1
        if not entry.startswith("!! "):
            continue
        path = entry[3:]
        if path.endswith("/"):
            instances.append((path.rstrip("/"), True))
        elif path:
            instances.append((path, False))
    return instances


def _ignored_set(root: Path, paths: list[str]) -> set[str]:
    """The subset of `paths` git reports as ignored (trailing slashes normalized).

    The trailing slash is what makes the question correct for a directory: a cache
    directory can be ignored only because of the `.gitignore` it carries itself
    (`.ruff_cache/.gitignore` matching `*`), and git answers that for `dir/` but not
    for `dir`.
    """
    if not paths:
        return set()
    raw = _git(
        root,
        "check-ignore",
        "-z",
        "--stdin",
        stdin=("\0".join(paths) + "\0").encode("utf-8", "surrogateescape"),
    )
    return {
        p.rstrip("/") for p in raw.decode("utf-8", "surrogateescape").split("\0") if p
    }


def escape(root_path: str) -> str:
    """Regex-escape a repo-relative path for a gitleaks [allowlist].paths entry."""
    return "".join(("\\" + char) if char in _META else char for char in root_path)


def derive_paths(root: Path) -> list[tuple[str, bool]]:
    """The ignored roots that exist in this tree, as (path, is_dir), sorted."""
    tracked_files, tracked_dirs = _tracked(root)
    instances = _ignored_instances(root)

    # Ancestors of an ignored instance: a directory with no tracked file beneath it
    # can be widened to the ignored ancestor git owns, which keeps the entry stable
    # when the instance that happened to exist changes (a new .pyc, a new cache file).
    candidates: set[str] = set()
    for path, _ in instances:
        parent = posixpath.dirname(path)
        while parent:
            candidates.add(parent)
            parent = posixpath.dirname(parent)
    ignored_dirs = _ignored_set(root, sorted(p + "/" for p in candidates))

    roots: dict[str, bool] = {}
    for path, is_dir in instances:
        current, current_is_dir = path, is_dir
        while True:
            parent = posixpath.dirname(current)
            if not parent or parent not in ignored_dirs or parent in tracked_dirs:
                break
            current, current_is_dir = parent, True
        if current in tracked_files:  # cannot happen: git never reports it ignored
            continue
        roots[current] = roots.get(current, False) or current_is_dir

    return sorted(roots.items())


def entries(paths: list[tuple[str, bool]]) -> list[str]:
    """Regex-escaped gitleaks [allowlist].paths entries for the derived roots."""
    return sorted(escape(path) + ("/" if is_dir else "") for path, is_dir in paths)


def _split_config(text: str) -> tuple[list[str], int, int]:
    """Return (lines, begin index, end index); ScopeError when the block is absent."""
    lines = text.splitlines(keepends=True)
    begin = end = -1
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped == BEGIN:
            begin = i
        elif stripped == END:
            end = i
            break
    if begin < 0 or end < 0 or end < begin:
        raise ScopeError(
            f"no generated block: expected '{BEGIN}' .. '{END}' in the config"
            " (run --write once to create it)"
        )
    return lines, begin, end


def read_block(text: str) -> list[str]:
    lines, begin, end = _split_config(text)
    entries: list[str] = []
    for line in lines[begin + 1 : end]:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        match = _ENTRY.fullmatch(stripped)
        if not match:
            raise ScopeError(
                f"unparsable line inside the generated block: {stripped!r}"
            )
        entries.append(match.group(1))
    return entries


def static_entries(text: str) -> list[str]:
    """Every [allowlist].paths entry that is NOT part of the generated block.

    A config that carries no generated block yet has all of its entries static,
    which is what a first ``--write`` needs.
    """
    try:
        lines, begin, end = _split_config(text)
    except ScopeError:
        lines, begin, end = text.splitlines(keepends=True), -1, -1
    entries: list[str] = []
    for i, line in enumerate(lines):
        if begin <= i <= end:
            continue
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        match = _ENTRY.fullmatch(stripped)
        if match:
            entries.append(match.group(1))
    return entries


def uncovered(
    paths: list[tuple[str, bool]], static: list[str]
) -> list[tuple[str, bool]]:
    """Drop roots an existing hand-maintained entry already covers.

    An entry that is already allowlisted by the config's own paths (``docs/``,
    ``.*\\.md``, ``__pycache__/``, …) does not need a second generated line, and
    leaving it out keeps the block limited to what would otherwise re-red tier-1.
    """
    compiled = []
    for pattern in static:
        try:
            compiled.append(re.compile(pattern))
        except re.error:
            continue  # a Go-only construct; the derived entry keeps the scope honest
    kept = []
    for path, is_dir in paths:
        probe = path + ("/" if is_dir else "")
        if any(rx.search(probe) for rx in compiled):
            continue
        kept.append((path, is_dir))
    return kept


def render(roots: list[str]) -> list[str]:
    body = [f"  '''{root}''',\n" for root in roots]
    return [f"  {BEGIN}\n", NOTE + "\n", *body, f"  {END}\n"]


def rewrite(text: str, roots: list[str]) -> str:
    try:
        lines, begin, end = _split_config(text)
    except ScopeError:
        lines = text.splitlines(keepends=True)
        at = _insertion_point(lines)
        block = render(roots)
        return "".join(lines[:at] + block + lines[at:])
    # lines[begin] and lines[end] are the markers themselves; render() re-emits both.
    return "".join(lines[: begin + 1] + render(roots)[1:] + lines[end + 1 :])


def _insertion_point(lines: list[str]) -> int:
    """Index just before the closing ']' of [allowlist].paths."""
    in_allowlist = False
    in_paths = False
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("[") and not stripped.startswith("[["):
            in_allowlist = stripped == "[allowlist]"
            in_paths = False
            continue
        if in_allowlist and re.match(r"^paths\s*=\s*\[", stripped):
            in_paths = True
            continue
        if in_paths and stripped == "]":
            return i
    raise ScopeError(
        "no [allowlist] paths = [ ... ] array to attach the generated block to"
    )


def write_config(config: Path, roots: list[str]) -> bool:
    try:
        text = config.read_text(encoding="utf-8")
    except OSError as exc:
        raise ScopeError(f"{config} unreadable ({exc.strerror or exc})") from exc
    updated = rewrite(text, roots)
    if updated == text:
        return False
    temp = tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", dir=str(config.parent), delete=False
    )
    try:
        temp.write(updated)
        temp.flush()
        os.fsync(temp.fileno())
        temp.close()
        os.replace(temp.name, config)
    except BaseException:
        temp.close()
        try:
            os.unlink(temp.name)
        except OSError:
            pass
        raise
    return True


def unescape(entry: str) -> str:
    """The literal repo-relative path a generated entry was derived from."""
    return re.sub(r"\\(.)", r"\1", entry)


def check(roots: list[str], block: list[str], root: Path) -> int:
    missing = [entry for entry in roots if entry not in block]
    extra = [entry for entry in block if entry not in roots]
    stale: list[str] = []
    dormant: list[str] = []
    live: list[str] = []
    for entry in extra:
        path = unescape(entry)
        if not os.path.lexists(root / path):
            dormant.append(entry)  # no content in this tree: nothing to grade or hide
        elif path.rstrip("/") in _ignored_set(root, [path]):
            live.append(entry)  # exists and ignored, but not the derived root
        else:
            stale.append(entry)  # exists and git no longer ignores it
    status = 0
    for entry in missing:
        print(
            f"  FAIL  gitleaks-scope: MISSING  '''{entry}''' — ignored content in the"
            " tree that .gitleaks.toml does not cover (run --write)"
        )
        status = 1
    for entry in stale:
        print(
            f"  FAIL  gitleaks-scope: STALE    '''{entry}''' — the path exists and git"
            " no longer ignores it, so the entry can hide committable content"
            " (run --write)"
        )
        status = 1
    for entry in live:
        print(
            f"  FAIL  gitleaks-scope: STALE    '''{entry}''' — exists and is"
            " gitignored, but it is not the root this tree derives (run --write)"
        )
        status = 1
    for entry in dormant:
        print(
            f"  note  gitleaks-scope: dormant  '''{entry}''' — no such path in this"
            " working tree (a fresh checkout has no artifacts yet); the entry stays"
        )
    if not status and block != roots:
        print(
            "  FAIL  gitleaks-scope: the generated block is not the derived set in"
            " derived order (run --write)"
        )
        status = 1
    if status:
        print(f"RESULT: FAIL ({len(missing)} missing, {len(stale) + len(live)} stale)")
        return 1
    print(
        f"RESULT: OK ({len(roots)} derived ignored root(s) match .gitleaks.toml,"
        f" {len(dormant)} dormant)"
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Derive the tier-1 gitleaks scope from git (never hand-list it) and"
            " rewrite/verify the generated block in .gitleaks.toml."
        )
    )
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--write", action="store_true", help="rewrite the block")
    action.add_argument("--check", action="store_true", help="verify the block")
    parser.add_argument(
        "--repo",
        default=None,
        help="repository root (default: the directory containing scripts/)",
    )
    parser.add_argument(
        "--config",
        default=None,
        help="gitleaks config (default: <repo>/.gitleaks.toml)",
    )
    args = parser.parse_args(argv)

    root = (
        Path(args.repo).resolve()
        if args.repo
        else Path(__file__).resolve().parent.parent
    )
    config = Path(args.config).resolve() if args.config else root / ".gitleaks.toml"
    if not root.is_dir():
        print(f"  FAIL  gitleaks-scope: {root} is not a directory")
        print("RESULT: FAIL (unusable repo root)")
        return 2
    if not config.is_file():
        print(f"  FAIL  gitleaks-scope: {config} is not a file")
        print("RESULT: FAIL (unusable config)")
        return 2

    try:
        text = config.read_text(encoding="utf-8")
        roots = entries(uncovered(derive_paths(root), static_entries(text)))
        if args.write:
            changed = write_config(config, roots)
            state = "rewritten" if changed else "already in sync"
            print(
                f"RESULT: OK ({len(roots)} derived ignored root(s) {state} in {config})"
            )
            return 0
        block = read_block(text)
        return check(roots, block, root)
    except ScopeError as exc:
        print(f"  FAIL  gitleaks-scope: {exc}")
        print("RESULT: FAIL (unusable scope)")
        return 2


if __name__ == "__main__":
    sys.exit(main())
