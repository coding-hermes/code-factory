#!/usr/bin/env python3
"""handbook_lint.py — fail the build on markdown debris that leaks into the rendered handbook.

The vision audit of the rendered PDF found the source markdown's own escape
artifacts printed verbatim: a backslash left at the end of a table cell that a
naive pipe-splitter tore apart (`grep -rn 'add_family_lanes\\` …`), shell pipes
markdown-escaped inside code spans (`curl \\| sh`), and quote characters the
prose never needed escaped (`\\"works\\"`). This gate fails the build on those
classes so they cannot ship again:

  1. stray backslash-newline  — a line ending in `\\` outside a fenced block
  2. unbalanced backticks     — an odd backtick count outside fenced blocks
  3. markdown pipes in code spans — `\\|` inside a code span. Two documented
     exemptions, both true command text: a quoted grep pattern (BRE alternation
     `\\|` is what the operator really types) and a span that only names the
     escape sequence itself (`\\|` as a meta-reference).
  4. stray quote escapes      — `\\"` in prose outside code spans

Scope: the markdown files BOOK.yaml actually renders (chapters, parts). The
_panel/ and _quorum*/ session archives are not book sources and are not gated.

    python3 scripts/handbook_lint.py            # lint the manifest files
"""
from __future__ import annotations

import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
HB = ROOT / "docs/handbook"
BOOK = HB / "BOOK.yaml"

# A span of nothing but backslashes and pipes is naming the escape sequence
# itself, not leaking one; a span that quotes grep may genuinely contain BRE
# `\|` alternation.
_META_REFERENCE = re.compile(r"^[\\|]+$")
_GREP_SPAN = re.compile(r"\bgrep\b")


def manifest_files() -> list[pathlib.Path]:
    import yaml

    book = yaml.safe_load(BOOK.read_text())
    files = []
    for part in book.get("parts", []):
        for rel in part.get("files", []):
            files.append(HB / rel)
    return files


def lint_file(path: pathlib.Path) -> list[tuple[int, str, str]]:
    findings: list[tuple[int, str, str]] = []
    in_fence = False
    ticks = 0
    for i, line in enumerate(path.read_text().splitlines(), 1):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue

        ticks += line.count("`")

        # 1. stray backslash-newline
        if line.endswith("\\"):
            findings.append((i, "stray backslash-newline", line.strip()[-60:]))

        # text outside code spans, for the prose-only rules
        prose = re.sub(r"`[^`]*`", "", line)

        # 3. markdown-escaped pipes inside code spans
        for span in re.finditer(r"`([^`]+)`", line):
            body = span.group(1)
            if "\\|" in body and not (_META_REFERENCE.fullmatch(body) or _GREP_SPAN.search(body)):
                findings.append((i, "markdown pipe inside code span", body.strip()[:70]))

        # 4. stray quote escapes in prose
        if '\\"' in prose:
            findings.append((i, "stray quote escape", prose.strip()[:70]))

    # 2. unbalanced backticks — per file, outside fenced blocks. (Per-line parity
    #    would false-positive on spans that legitimately wrap inside a paragraph;
    #    file-level catches the damaging case: a span opened and never closed that
    #    leaks the rest of the file as code.)
    if ticks % 2:
        findings.append((0, "unbalanced backticks", f"{ticks} backticks outside fences"))

    return findings


def lint() -> list[tuple[str, int, str, str]]:
    problems = []
    for f in manifest_files():
        if not f.exists():  # a missing manifest file is build_book's own error sheet
            continue
        for lineno, kind, snippet in lint_file(f):
            problems.append((str(f.relative_to(ROOT)), lineno, kind, snippet))
    return problems


def main() -> int:
    problems = lint()
    for rel, lineno, kind, snippet in problems:
        print(f"FAIL {rel}:{lineno} — {kind}: {snippet!r}")
    if problems:
        print(f"handbook_lint: {len(problems)} finding(s)")
        return 1
    print("handbook_lint: clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
