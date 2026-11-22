"""CF-336 — public-template boundary for tracked docs.

code-factory is published as a public BASE TEMPLATE (a reader clones it to run
their own fleet of coding agents), so a tracked document must not read as
configuration that only works on one machine. This check enforces the boundary
stated in `docs/00-INDEX.md` ("Audience and the template boundary"):

- every tracked `docs/**/*.md` and `README.md` is scanned for `/home/<name>/…`
  spellings; an unwaived hit fails, listed as `file:line`;
- quoted measured output (log lines, probe transcripts, audit records) keeps the
  path the run really touched — each survivor is an explicit WAIVERS entry with a
  reason, and a waiver whose anchor no longer matches the tree fails, so the list
  cannot rot into a silent allowlist.

Detector pattern: the board row states the regex `/home/[A-Za-z0-9._-]+/` (with a
trailing slash). This check drops the trailing-slash requirement so a bare
`HOME=/home/<user>` — the most common real spelling, and the one the row's AC2
names — also fails. The pattern is therefore a strict superset of the row's
regex: every match the row's regex makes is still matched here. Template
placeholders (`/home/<uid>/…`) do not match, because `<` is outside the character
class; a placeholder with a literal leading component (`/home/bunker-<id>`) does
match and is carried as a documented waiver, like any other survivor.
"""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

PATTERN = re.compile(r"/home/[A-Za-z0-9._-]+")

# (path, anchor substring, reason). A line of `path` containing `anchor` is waived.
# Reasons state why the survivor is evidence (quoted measured output) or a
# documented placeholder rather than a leak. Line numbers below were measured at
# the CF-336 commit and are kept in the comments only as a reading aid; the
# anchor is the live criterion (test_waivers_are_live fails when it rots).
WAIVERS: list[tuple[str, str, str]] = [
    # --- docs/audits/: an audit's job is to quote what it measured (the same
    # charter tests/selftest.sh check 61 grants docs/audits for addresses) ---
    (
        "docs/audits/code-factory-perf-2026-11-03-PERF-013.md",
        "file://$H/home/repo",
        "quoted probe command of the PERF-013 run: `$H` is that probe's scratch"
        " worktree root and `home/` is a lane subdirectory under it, not a host"
        " home (lines 129, 131)",
    ),
    (
        "docs/audits/code-factory-perf-2026-11-03-PERF-013.md",
        "$H/home/.node/node.json",
        "quoted probe output: the manifest path under the probe's scratch"
        " worktree `$H`; `home/` is a lane subdirectory, not a host home"
        " (lines 154, 155)",
    ),
    (
        "docs/audits/code-factory-releng-2026-11-04-CF-163-AC3.md",
        "git grep -l '/home/kara'",
        "audit evidence: the literal measurement command run at a historical"
        " HEAD and the file count it produced; rewriting it would falsify the"
        " record (line 79)",
    ),
    (
        "docs/audits/code-factory-releng-2026-11-04-CF-163-AC3.md",
        "git grep -Il '/home/kara'",
        "audit evidence: same census family, second measurement at a later HEAD"
        " (line 172)",
    ),
    (
        "docs/audits/code-factory-ops-2026-11-12-18-16-42-CF-007.md",
        '"root": "/home/kara"',
        "quoted OUTPUT line of the reclaim-disk dry run recorded by the CF-007"
        " tick; the JSON names the root it really measured (line 31)",
    ),
    (
        "docs/audits/code-factory-ops-2026-11-12-18-16-42-CF-007.md",
        "MiB reclaimable under `/home/kara`",
        "audit conclusion quoting the live host the dry run measured; audit"
        " records keep the measured reality (line 42)",
    ),
    (
        "docs/audits/code-factory-CF-127-fix-2026-11-03.md",
        "/var/tmp/hermes-scratch/CF-127",
        "quoted install-failure log paths from a /var/tmp hermes-scratch"
        " fixture; the `home` component is a scratch subdirectory, not a host"
        " home (lines 172, 199, 200, 209)",
    ),
    # --- handbook chapters ---
    (
        "docs/handbook/chapters/M8-safety.md",
        "/home/bunker-<agent>/.cf-jobs",
        "documented layout template quoting dispatcher.py's assumed node-home"
        " form; `<agent>` is a placeholder, no real host is named (line 198)",
    ),
    # --- handbook appendices/units: published transcripts; addressing the runs
    # really touched stays verbatim as evidence ---
    (
        "docs/handbook/appendices/units/06-scripts-bunker-server-install-sh.md",
        "floor 5 GB at /home/kara",
        "quoted FAIL row of the disk-floor check naming the host it measured"
        " (line 152)",
    ),
    (
        "docs/handbook/appendices/units/09-scripts-clone-lane-py.md",
        "under `HOME=/home/kara`",
        "verification-table evidence: the HOME the measured lane_target probe"
        " ran under; the quoted transcript beside it already reads"
        " `~/code-factory` (line 80)",
    ),
    (
        "docs/handbook/appendices/units/12-scripts-github-app-refresh-sh.md",
        ".../home/.config/code-factory/github.token",
        "quoted tool output with the probe root elided to `...`; `home/` is a"
        " scratch-fixture directory, not a host home (line 97)",
    ),
    (
        "docs/handbook/appendices/units/12-scripts-github-app-refresh-sh.md",
        "refreshed .../home/.git-credentials",
        "quoted refresh output, probe root elided; scratch-fixture directory"
        " (lines 100, 114)",
    ),
    (
        "docs/handbook/appendices/units/12-scripts-github-app-refresh-sh.md",
        "md32/probe/home/.node/auth/github.token",
        "quoted refresh transcript from a probe fixture under"
        " ~/.hermes/cache/scratch; `home/` is the probe's fixture directory"
        " (line 147)",
    ),
    (
        "docs/handbook/appendices/units/15-scripts-harness-install-claude-code-sh.md",
        "outside $HOME (/home/kara)",
        "quoted refusal emitted by install-claude-code.sh echoing the home it"
        " measured (line 79)",
    ),
    (
        "docs/handbook/appendices/units/16-scripts-harness-install-codex-sh.md",
        "/…/home/work is a git work tree",
        "quoted PASS row; the probe scratch root is elided to `/…` and `home/`"
        " is a fixture directory (line 205)",
    ),
    (
        "docs/handbook/appendices/units/16-scripts-harness-install-codex-sh.md",
        "HOME=/…/probe2/home",
        "replay command of the containment probe; its scratch root is already"
        " elided to `/…/probe2/home` and the `home/../escape` suffix is the"
        " traversal-bypass fixture itself (line 214)",
    ),
    (
        "docs/handbook/appendices/units/16-scripts-harness-install-codex-sh.md",
        "home/../escape is a git work tree",
        "quoted PASS rows and the D-4 defect row transcribing them; elided"
        " probe fixture paths exercising the `$HOME/../` bypass"
        " (lines 217, 280, 329)",
    ),
    (
        "docs/handbook/appendices/units/16-scripts-harness-install-codex-sh.md",
        "/…/home/.cache/cf-codex/../../victim",
        "quoted PASS row of the turn-home escape probe; elided fixture path (line 234)",
    ),
    (
        "docs/handbook/appendices/units/25-scripts-node-bus-worker-py.md",
        "inside $HOME (/home/kara)",
        "quoted FAIL rows of the workdir-containment refusal echoing the home"
        " the run measured (lines 80, 328)",
    ),
    (
        "docs/handbook/appendices/units/27-scripts-node-env-py.md",
        "/home/agent",
        "documented placeholder: the unit states the rows below read"
        " `/home/agent` and the real scratch path is in the transcript; no"
        " real host is named (lines 192, 196)",
    ),
    (
        "docs/handbook/appendices/units/28-scripts-node-freshness-py.md",
        "(home /home/bunker-cf-node)",
        "quoted measured header line from a live node battery run: the node's"
        " real home, kept as evidence (line 189)",
    ),
    (
        "docs/handbook/appendices/units/28-scripts-node-freshness-py.md",
        "never templated as `/home/bunker-<id>`",
        "placeholder spelling documenting what node-freshness must NOT assume;"
        " `<id>` names no real host (line 253)",
    ),
    (
        "docs/handbook/appendices/units/30-scripts-node-identity-py.md",
        "/home/.node/node.json",
        "quoted PASS rows of the identity manifest writes; the `home/`"
        " component is a probe fixture directory under"
        " ~/.hermes/cache/scratch (lines 97, 98, 148, 154)",
    ),
    (
        "docs/handbook/appendices/units/32-scripts-node-seed-drift-py.md",
        "empty/home/.hermes/seed-applied.json",
        "quoted probe rows; `empty` is the probe home fixture directory name"
        " (lines 180, 182)",
    ),
    (
        "docs/handbook/appendices/units/33-scripts-project-node-sh.md",
        "/tmp/…/home/repo @ e15cc9c",
        "quoted probe row; the scratch tmp root is elided to `/tmp/…` and"
        " `home/` is a fixture directory (line 133)",
    ),
    (
        "docs/handbook/appendices/units/35-scripts-repo-freshness-py.md",
        "the 74 /home/kara workdirs",
        "quoted measured-output string of the repo-freshness census naming the"
        " host it counted on; evidence stays verbatim (line 364)",
    ),
]


def tracked_docs() -> list[str]:
    """Tracked docs/**/*.md plus README.md, from git's index (the publish truth)."""
    proc = subprocess.run(
        ["git", "-C", str(REPO), "ls-files", "-z"],
        check=True,
        capture_output=True,
    )
    names = proc.stdout.decode("utf-8").split("\0")
    return sorted(
        n
        for n in names
        if n and (n == "README.md" or (n.startswith("docs/") and n.endswith(".md")))
    )


def scan_entries(
    entries: list[tuple[str, str]], waivers: list[tuple[str, str, str]] | None = WAIVERS
) -> list[tuple[str, int, str]]:
    """Scan (path, text) pairs; return unwaived (path, lineno, line) offenders."""
    offenders: list[tuple[str, int, str]] = []
    for rel, text in entries:
        for lineno, line in enumerate(text.splitlines(), start=1):
            if not PATTERN.search(line):
                continue
            if any(rel == w_path and anchor in line for w_path, anchor, _ in waivers):
                continue
            offenders.append((rel, lineno, line))
    return offenders


def format_offenders(offenders: list[tuple[str, int, str]]) -> str:
    return "\n".join(f"  {p}:{n}: {line.strip()[:160]}" for p, n, line in offenders)


def test_no_unwaived_host_home_paths_in_tracked_docs() -> None:
    entries = [
        (rel, (REPO / rel).read_text(encoding="utf-8", errors="replace"))
        for rel in tracked_docs()
    ]
    offenders = scan_entries(entries)
    assert not offenders, (
        "tracked docs name a host home path without a waiver"
        " (waive quoted evidence in WAIVERS, or rewrite the spelling to"
        " $HOME/~/<path> for instructions):\n" + format_offenders(offenders)
    )


def test_waivers_are_live() -> None:
    """A waiver whose anchor no longer matches its file is stale: fail, don't skip."""
    stale: list[str] = []
    known = {rel for rel in tracked_docs()}
    for w_path, anchor, reason in WAIVERS:
        if w_path not in known:
            stale.append(f"{w_path}: waived file is not a tracked doc")
            continue
        text = (REPO / w_path).read_text(encoding="utf-8", errors="replace")
        if anchor not in text:
            stale.append(
                f"{w_path}: anchor {anchor!r} matches nothing — remove the waiver or fix the doc ({reason})"
            )
    assert not stale, "stale waiver entries:\n" + "\n".join(f"  {s}" for s in stale)


def test_detector_flags_a_real_home_path() -> None:
    """AC2 red-proof: a doc naming a real home path fails, bare spelling included."""
    offenders = scan_entries(
        [
            (
                "docs/example.md",
                "run: HOME=/home/kara bash scripts/node-create.sh --check\n",
            )
        ]
    )
    assert [(p, n) for p, n, _ in offenders] == [("docs/example.md", 1)]


def test_detector_flags_the_row_regex_form() -> None:
    # The fixture path is assembled from pieces — the same discipline as the
    # CF-050 fixture in tests/selftest.sh: this file must not itself carry the
    # contiguous `/home/<user>/` literal, or selftest check 61's publish gate
    # (which grades tests/ too) would flag this test.
    leaked = "/home/" + "kara" + "/worktrees/scratch"
    offenders = scan_entries([("docs/example.md", f"see {leaked} for the tree\n")])
    assert [(p, n) for p, n, _ in offenders] == [("docs/example.md", 1)]


def test_detector_accepts_template_spellings() -> None:
    clean = [
        "edit $HOME/.hermes/config.yaml\n",
        "the create path stages it into ~/.hermes/config.yaml\n",
        "manifest at /home/<uid>/.node/node.json\n",
        "an absolute host-home path — /home/<user>/… — is refused\n",
        "run it on a throwaway HOME\n",
    ]
    assert scan_entries([("docs/example.md", t) for t in clean]) == []


def test_placeholder_with_literal_component_is_flagged_and_waivable() -> None:
    """`/home/bunker-<id>` matches (leading component is in the class) — the same
    shape the M8 waiver carries; show the waiver mechanism covers it."""
    text = "dispatcher jobs under /home/bunker-<agent>/.cf-jobs are not a reap target\n"
    assert scan_entries([("docs/handbook/chapters/M8-safety.md", text)]) == []
    assert scan_entries([("docs/other.md", text)]) != []


def test_index_declares_audience_and_template_boundary() -> None:
    idx = REPO / "docs" / "00-INDEX.md"
    assert idx.exists(), (
        "docs/00-INDEX.md must state the audience and the template boundary (AC1)"
    )
    text = idx.read_text(encoding="utf-8")
    assert re.search(r"(?m)^## .*Audience", text), (
        "00-INDEX must carry a dedicated audience/boundary section"
    )
    assert "template boundary" in text.lower()
    assert "tests/test_docs_template_boundary.py" in text, (
        "the boundary section must name its enforcing check"
    )
