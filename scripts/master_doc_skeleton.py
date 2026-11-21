#!/usr/bin/env python3
"""Build the 40-module master-document skeleton from the repositories.

Nothing here is prose. Every field is either derived mechanically from the
source or marked RED because no evidence exists yet. The point of the skeleton
is that the RED markers are true today and can only turn green by running
something.
"""

import argparse
import difflib
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

MANIFEST = Path(__file__).with_name("master_doc_manifest.json")
MARKER = "<!-- master-doc-skeleton sha256:"

OUT = Path(os.path.expanduser("~/code-factory/docs/master"))
REPOS = [
    ("code-factory", os.path.expanduser("~/code-factory")),
    (
        "coding-herms-scheduler",
        os.path.expanduser("~/coding-hermes-scheduler/coding-hermes-scheduler"),
    ),
    ("crier", os.path.expanduser("~/crier")),
    ("crier-fleet", os.path.expanduser("~/crier-fleet")),
]
PROXY = os.path.expanduser("~/.hermes/scripts/cf-inference-proxy.py")

SKIP = re.compile(
    r"(^|/)(\.git|node_modules|venv|\.venv|vendor|dist|build|__pycache__|\.gitreins|docs/master)(/|$)"
)


def rev(repo):
    try:
        r = subprocess.run(
            ["git", "-C", repo, "rev-parse", "--short", "HEAD"],
            capture_output=True,
            text=True,
            errors="replace",
            timeout=20,
        )
        return r.stdout.strip() or "unknown"
    except Exception:
        return "unknown"


def modules_for(repo):
    """Real components: scripts, Go packages, Python entry points, specs."""
    found = []
    root = Path(repo)
    for p in sorted(root.rglob("*")):
        if not p.is_file() or SKIP.search(str(p)):
            continue
        rel = p.relative_to(root).as_posix()
        if (
            p.suffix == ".go"
            and not p.name.endswith("_test.go")
            and "/internal/" in "/" + rel
        ):
            found.append((f"go:{rel}", p))
        elif p.suffix in (".sh", ".py") and rel.startswith(
            ("scripts/", "tests/", "bin/")
        ):
            found.append((f"code:{rel}", p))
        elif p.suffix == ".md" and rel.startswith("specs/"):
            found.append((f"spec:{rel}", p))
    return found


def derive(path):
    txt = path.read_text(encoding="utf-8", errors="replace")
    deps = sorted(
        set(re.findall(r"^\s*(?:import|from)\s+([A-Za-z0-9_.\-]+)", txt, re.M))
    )[:12]
    envs = sorted(set(re.findall(r"\b([A-Z][A-Z0-9_]{3,})\b", txt)))
    envs = [
        e
        for e in envs
        if e.startswith(("CF_", "HERMES_", "CRIER_", "DISPATCH_", "API_", "GITREINS_"))
    ][:12]
    logs = sorted(
        set(
            re.findall(
                r'(?:log|print|echo|info|warn|error)\w*\(?\s*["\']([^"\']{12,90})["\']',
                txt,
            )
        )
    )[:10]
    cmds = sorted(set(re.findall(r"subprocess\.run\(\[?\s*[\"']([a-z0-9\-_]+)", txt)))[
        :6
    ]
    return deps, envs, logs, cmds


def section(idx, name, path, repo, revision):
    deps, envs, logs, cmds = derive(path) if path.exists() else ([], [], [], [])
    rel = (
        path.relative_to(Path(repo)).as_posix()
        if path.exists() and str(path).startswith(repo)
        else str(path)
    )
    lines = [
        f"# {idx:02d}. {name}",
        "",
        "| Field | Value |",
        "|---|---|",
        f"| Path | `{rel}` |",
        f"| Repository | `{repo}` |",
        f"| Revision | `{revision}` |",
        "| Status | **RED — no verification recorded** |",
        "",
        "## 1. Purpose and why it matters",
        "",
        "- What breaks if this module is absent: **UNKNOWN** (fill from behaviour, prove it).",
        "- What breaks if it lies: **UNKNOWN** (every self-reporting component has this failure mode).",
        "",
        "## 2. Dependencies and library contracts",
        "",
        "### 2a. Runtime dependencies",
        "",
        "| Dependency | Version | Where it must exist | Absence detected by |",
        "|---|---|---|---|",
    ]
    if cmds:
        for c in cmds:
            lines.append(f"| `{c}` | unknown | unknown | **RED** |")
    else:
        lines.append("| — | — | — | **RED: none identified mechanically** |")
    lines += [
        "",
        "### 2b. Library contracts",
        "",
        "| Import | Provider | Contract relied on | If it changes |",
        "|---|---|---|---|",
    ]
    if deps:
        for d in deps:
            lines.append(f"| `{d}` | — | **UNKNOWN** | **UNKNOWN** |")
    else:
        lines.append("| — | — | **RED: no imports detected** | — |")
    lines += [
        "",
        "### 2c. Service contracts (both sides must be named)",
        "",
        "| Peer | Direction | Transport | Payload | Other side (file:function) |",
        "|---|---|---|---|---|",
        "| **UNKNOWN** | — | — | — | **RED** |",
        "",
    ]
    lines += [
        "## 3. Verification",
        "",
        "| Check | Command | Expected | Last run | Result |",
        "|---|---|---|---|---|",
        "| — | **no check exists** | — | — | **RED** |",
        "",
    ]
    lines += ["## 4. Metrics emitted", ""]
    lines += [
        "**NONE FOUND** — this is a RED field. Dispatch rate, latency, failure counts and liveness are all unanswerable without reading code or grepping logs.",
        "",
    ]
    lines += ["## 5. Log lines it can generate", ""]
    if logs:
        lines += [
            "| Level | Line (verbatim) | Emitted when | Kind |",
            "|---|---|---|---|",
        ]
        for lg in logs:
            lines.append(
                f"| ? | `{lg}` | **UNKNOWN** | descriptive (**unverified as evidence**) |"
            )
    else:
        lines.append(
            "**NONE DETECTED** — RED: an operator has nothing to read when this fails."
        )
    lines += [
        "",
        "## 6. Failure modes",
        "",
        "| Failure | Presents as | Distinguished from | Recovery |",
        "|---|---|---|---|",
        "| **UNKNOWN** | — | — | — |",
        "",
    ]
    lines += ["## 7. Environment and settings it reads", ""]
    if envs:
        lines += ["| Variable | Default | Effect if unset |", "|---|---|---|"]
        for e in envs:
            lines.append(f"| `{e}` | unknown | **UNKNOWN** |")
    else:
        lines.append("**NONE DETECTED**")
    lines += ["", "## 8. Evidence of record", "", "- none yet"]
    return "\n".join(lines) + "\n"


def seal(text):
    digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
    return f"{MARKER}{digest} -->\n" + text


def is_skeleton(text):
    marker, separator, body = text.partition("\n")
    match = re.fullmatch(r"<!-- master-doc-skeleton sha256:([0-9a-f]{64}) -->", marker)
    return bool(
        separator
        and match
        and hashlib.sha256(body.encode("utf-8")).hexdigest() == match.group(1)
    )


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Preview the pinned master-document skeleton; use --apply to write."
    )
    parser.add_argument(
        "--repo-root", type=Path, default=Path(__file__).resolve().parent.parent
    )
    parser.add_argument(
        "--output", type=Path, help="output directory (default: REPO_ROOT/docs/master)"
    )
    parser.add_argument(
        "--apply", action="store_true", help="write the previewed changes"
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="allow replacing non-skeleton documents with --apply",
    )
    parser.add_argument(
        "--strict-unlisted",
        action="store_true",
        help="refuse when discovered components are absent from the manifest",
    )
    args = parser.parse_args(argv)
    if args.force and not args.apply:
        parser.error("--force requires --apply")
    root = args.repo_root.resolve()
    out = args.output or root / "docs/master"
    try:
        entries = json.loads(MANIFEST.read_text(encoding="utf-8"))
        numbers = [entry["number"] for entry in entries]
        components = [entry["component"] for entry in entries]
        if (
            any(type(n) is not int or n < 1 for n in numbers)
            or len(set(numbers)) != len(numbers)
            or len(set(components)) != len(components)
        ):
            raise ValueError("duplicate or invalid manifest numbers/components")
        for component in components:
            path = Path(component)
            if path.is_absolute() or ".." in path.parts or not (root / path).is_file():
                raise ValueError(f"missing or invalid component: {component}")
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(f"FAIL manifest: {exc}", file=sys.stderr)
        return 1

    discovered = {path.relative_to(root).as_posix() for _, path in modules_for(root)}
    unlisted = sorted(discovered - set(components))
    if unlisted:
        level = "FAIL" if args.strict_unlisted else "WARN"
        print(
            f"{level} manifest drift: {len(unlisted)} discovered component(s) not pinned: "
            + ", ".join(unlisted),
            file=sys.stderr,
        )
        if args.strict_unlisted:
            return 1

    index = [
        "# CODE FACTORY — MASTER DOCUMENT SKELETON",
        "",
        "Generated mechanically. Every **RED** is a claim that has no evidence yet,",
        "not a section that is merely unwritten. A section turns green by running a command, never by editing prose.",
        "",
        "| # | Module | Repo | Status |",
        "|---|---|---|---|",
    ]
    generated = {}
    revision = rev(str(root))
    for entry in sorted(entries, key=lambda e: e["number"]):
        i, title = entry["number"], entry["component"]
        fn = out / (
            "%02d-%s.md"
            % (i, re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")[:60])
        )
        generated[fn] = seal(section(i, title, root / title, str(root), revision))
        index.append(f"| {i} | [`{title}`]({fn.name}) | code-factory | RED |")
    index += [
        "",
        "## Counts",
        "",
        f"- Modules in skeleton: **{len(entries)}**",
        "- Modules with a verification command: **0**",
        "- Modules emitting metrics: **0**",
        "- Modules with a both-sided service contract: **0**",
        "",
        "The zeros are the finding. They are what the fill pass must move, one command at a time.",
    ]
    generated[out / "00-INDEX.md"] = seal("\n".join(index) + "\n")
    changes = []
    refused = []
    try:
        for path, content in generated.items():
            old = path.read_text(encoding="utf-8") if path.exists() else ""
            if path.is_symlink():
                raise ValueError(f"refusing symlink: {path}")
            if old == content:
                continue
            changes.append((path, content))
            if old and not is_skeleton(old) or path.exists() and not old:
                refused.append(path)
            print(
                "".join(
                    difflib.unified_diff(
                        old.splitlines(keepends=True),
                        content.splitlines(keepends=True),
                        fromfile=str(path),
                        tofile=str(path),
                    )
                ),
                end="",
            )
        if args.apply and refused and not args.force:
            for path in refused:
                print(
                    f"FAIL refusing to overwrite non-skeleton: {path} (use --apply --force)",
                    file=sys.stderr,
                )
            return 1
        if args.apply and changes:
            out.mkdir(parents=True, exist_ok=True)
            for path, content in changes:
                path.write_text(content, encoding="utf-8")
    except (OSError, UnicodeError, ValueError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    print(
        json.dumps(
            {
                "modules": len(entries),
                "out": str(out),
                "changes": len(changes),
                "mode": "apply" if args.apply else "dry-run",
            }
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
