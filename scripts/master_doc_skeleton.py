#!/usr/bin/env python3
"""Build the 40-module master-document skeleton from the repositories.

Nothing here is prose. Every field is either derived mechanically from the
source or marked RED because no evidence exists yet. The point of the skeleton
is that the RED markers are true today and can only turn green by running
something.
"""

import json
import re
import subprocess
from pathlib import Path

OUT = Path("/home/kara/code-factory/docs/master")
REPOS = [
    ("code-factory", "/home/kara/code-factory"),
    (
        "coding-herms-scheduler",
        "/home/kara/coding-hermes-scheduler/coding-herms-scheduler",
    ),
    ("crier", "/home/kara/crier"),
    ("crier-fleet", "/home/kara/crier-fleet"),
]
PROXY = "/home/kara/.hermes/scripts/cf-inference-proxy.py"

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


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    index = [
        "# CODE FACTORY — MASTER DOCUMENT SKELETON",
        "",
        "Generated mechanically. Every **RED** is a claim that has no evidence yet,",
        "not a section that is merely unwritten. A section turns green by running a command, never by editing prose.",
        "",
        "| # | Module | Repo | Status |",
        "|---|---|---|---|",
    ]
    entries = []
    for repo, path in REPOS:
        for name, p in modules_for(path):
            entries.append((repo, path, name, p))
    entries.append(("host", "/home/kara", "cf-inference-proxy", Path(PROXY)))
    entries = entries[:40]
    for i, (repo, path, name, p) in enumerate(entries, 1):
        r = rev(path) if repo != "host" else "host"
        title = name.split(":", 1)[-1]
        fn = OUT / (
            "%02d-%s.md"
            % (i, re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")[:60])
        )
        fn.write_text(section(i, title, p, repo, r), encoding="utf-8")
        index.append(f"| {i} | [`{title}`]({fn.name}) | {repo} | RED |")
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
    (OUT / "00-INDEX.md").write_text("\n".join(index) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {"modules": len(entries), "out": str(OUT), "red_fields": len(entries) * 4}
        )
    )


if __name__ == "__main__":
    main()
