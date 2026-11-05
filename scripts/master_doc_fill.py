#!/usr/bin/env python3
"""Fill master-document sections from the source, one module at a time.

Rule: the model may only write what it can point at. Every claim it makes must
carry a file:line or a command it actually ran. Anything it cannot support must
stay RED. A filled section that is still RED is a valid outcome; a filled
section that is green without evidence is a lie the next reviewer will find.

Usage:
  ./master_doc_fill.py --limit 3            # prove the loop on three modules
  ./master_doc_fill.py                     # fill everything still RED
  ./master_doc_fill.py --workers 4         # parallel
"""

import argparse
import json
import re
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
import pathlib
from pathlib import Path

MASTER = Path("/home/kara/code-factory/docs/master")
STATE = Path("/home/kara/.hermes/logs/master-doc-fill.jsonl")
ENV = Path("/home/kara/.hermes/.env")

# Self-talk at the start of a line. Kept narrow on purpose: a document may say "We" in
# prose, but a construction note ("Let's create rows", "Maybe keep status RED") is not
# part of the document and must be refused, not published.
NARRATION = re.compile(
    r"^(?:Let's |Let\u2019s |Maybe |We need |We should |We can |I'll |I\u2019ll |Good\.|Hmm|So we |Alternatively)",
    re.MULTILINE,
)

# This project runs on xkiro and DeepSeek PAYG only. Ollama's monthly credits are not spent on
# code-factory, and `deepseek-v4-pro` is not the better writer here — flash is (owner, 2026-11-05).
PROVIDERS = {
    "deepseek": (
        "https://api.deepseek.com/v1/chat/completions",
        "DEEPSEEK_API_KEY",
        "deepseek-v4-flash",
    ),
    "xkiro": (
        "https://api.xkiro.com/v1/chat/completions",
        "XKIRO_API_KEY",
        "openai/gpt-6.1-sol",
    ),
}

SYSTEM = """You are writing part of an operations master document for a real system.

You will receive (a) the section template and (b) the source file. Fill ONLY the
parts the source supports. Rules, strictly:

1. Every factual claim carries a locator: `file:line` or a literal string from the file.
2. If the source does not show something, write `UNKNOWN` and leave the section RED.
   Never invent a metric, a timeout value, a version, or a contract peer.
3. Log lines must be quoted VERBATIM from the source, with the level if visible.
4. Service contracts require BOTH sides named. One side named stays RED.
5. Keep the markdown structure exactly as given; replace `UNKNOWN`/`RED` only where
   the source proves the answer.
6. Output only the markdown document. No preamble, no code fences around it.
"""


def env():
    out = {}
    for line in ENV.read_text().splitlines():
        if "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1)
            out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def call(provider, prompt, timeout=300, max_tokens=None):
    url, keyname, model = PROVIDERS[provider]
    key = env().get(keyname, "")
    if not key:
        raise RuntimeError("no key for %s" % provider)
    payload = json.dumps(
        {
            "model": model,
            "stream": False,
            "messages": [
                {"role": "system", "content": SYSTEM},
                {"role": "user", "content": prompt},
            ],
            "max_tokens": max_tokens or 12000,
        }
    ).encode()
    req = urllib.request.Request(
        url,
        data=payload,
        headers={"Content-Type": "application/json", "Authorization": "Bearer " + key},
    )
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=timeout) as r:
        j = json.loads(r.read())
    msg = (j.get("choices") or [{}])[0].get("message", {}) or {}
    # NEVER fall back to reasoning_content: it is the model's thinking, not the
    # document. Accepting it wrote 46KB of "We need answer from template..."
    # into three sections before this was caught (2026-11-04).
    txt = msg.get("content") or ""
    fin = (j.get("choices") or [{}])[0].get("finish_reason")
    if not txt and fin == "length":
        # deepseek-v4-flash is a reasoning model: the budget can be spent entirely on reasoning,
        # leaving no document at all. Three of ten modules died this way on 2026-11-05 (02, 05, 09).
        # One retry with double the budget, then give up honestly rather than write nothing.
        usage = (j.get("usage") or {}).get("completion_tokens_details") or {}
        if (max_tokens or 12000) < 48000:
            return call(provider, prompt, timeout=timeout, max_tokens=(max_tokens or 12000) * 2)
        raise RuntimeError(
            "empty reply after retry; finish=%s reasoning_tokens=%s"
            % (fin, usage.get("reasoning_tokens"))
        )
    if not txt:
        raise RuntimeError("empty reply; finish=%s" % fin)
    return txt, time.time() - t0



def census(text):
    """Section headings and table rows — the shape a rewrite must not lose."""
    return {
        "h2": len(re.findall(r"^## ", text, re.M)),
        "lines": len(text.splitlines()),
        "locators": len(re.findall(r"\b[\w./-]+\.(?:py|sh|md|go|yaml|jsonl|json):\d+", text)),
    }


def locators_resolve(text, repo_root):
    """Every file:line the document cites must exist. A claim that cannot be pointed at is not one."""
    bad = []
    for m in re.finditer(r"\b([\w./-]+\.(?:py|sh|md|go|yaml|jsonl|json)):(\d+)", text):
        path, line = m.group(1), int(m.group(2))
        cand = [pathlib.Path(repo_root) / path, pathlib.Path(path)]
        f = next((c for c in cand if c.is_file()), None)
        if f is None:
            bad.append("%s (no such file)" % path)
            continue
        try:
            n = sum(1 for _ in f.open("r", encoding="utf-8", errors="replace"))
        except OSError:
            bad.append("%s (unreadable)" % path)
            continue
        if line > n:
            bad.append("%s:%d (file has %d lines)" % (path, line, n))
    return bad


def gate(before, after, out, repo_root):
    """Refuse a rewrite that loses structure, or that claims VERIFIED without resolvable locators.

    Returns (verdict, note) where verdict is 'ok' or 'rejected:<reason>'.
    """
    b, a = census(before), census(out)
    if a["h2"] < b["h2"]:
        return "rejected", "lost %d of %d sections" % (b["h2"] - a["h2"], b["h2"])
    if a["lines"] < b["lines"] * 0.70:
        return "rejected", "shrank %d -> %d lines (>30%% deleted)" % (b["lines"], a["lines"])
    if a["locators"] == 0:
        return "rejected", "no file:line locator anywhere"
    bad = locators_resolve(out, repo_root)
    if bad:
        return "rejected", "unresolvable locator(s): " + ", ".join(bad[:3])
    # VERIFIED is computed here, never taken from the model's own header.
    if "VERIFIED" in out:
        out = out.replace("| Status | **VERIFIED — source reviewed; key claims carry `file:line` locators** |",
                          "| Status | **VERIFIED — %d locators, all resolve; %d sections kept** |" % (a["locators"], a["h2"]))
    return "ok", "%d sections, %d locators" % (a["h2"], a["locators"])


REPO_ROOT = pathlib.Path("/home/kara/code-factory")

def resolve(path_field, repo):
    p = Path(path_field)
    if p.exists():
        return p
    for base in (
        "/home/kara/code-factory",
        "/home/kara/coding-hermes-scheduler/coding-herms-scheduler",
        "/home/kara/crier",
        "/home/kara/crier-fleet",
        "/home/kara",
    ):
        cand = Path(base) / path_field
        if cand.exists():
            return cand
    return None


def fill_one(md, provider):
    text = md.read_text(encoding="utf-8")
    m = re.search(r"\| Path \| `([^`]+)` \|", text)
    if not m:
        return md.name, "skip", "no path field"
    src = resolve(m.group(1), "")
    if not src or not src.is_file():
        return md.name, "skip", "source not found: %s" % m.group(1)
    body = src.read_text(encoding="utf-8", errors="replace")
    if len(body) > 60000:
        body = body[:60000] + "\n... (truncated)"
    prompt = "## SECTION TEMPLATE\n\n%s\n\n## SOURCE: %s\n\n```\n%s\n```\n" % (
        text,
        m.group(1),
        body,
    )
    try:
        out, secs = call(provider, prompt)
    except Exception as e:
        return md.name, "error", str(e)[:160]
    out = out.strip()
    # Models often prepend a sentence or wrap the doc in a fence. Find the
    # document, do not reject it for having a preamble — that threw away four
    # 46KB replies before this was measured (2026-11-04).
    i = out.find("\n# ")
    if not out.startswith("# ") and i > 0:
        out = out[i + 1 :]
    elif out.startswith("```"):
        out = re.sub(r"^```[a-z]*\n", "", out)
        out = re.sub(r"\n```$", "", out)
    if not out.startswith("# "):
        return md.name, "rejected", "not a document: starts %r" % out[:60]
    if len(out) < 400:
        return md.name, "rejected", "reply too short (%d chars)" % len(out)
    # Self-talk arrives inside `content` too, not only in reasoning_content: module 05
    # shipped six lines of "Maybe too many rows; okay." / "Let's create rows." before
    # this was measured (2026-11-05). A document does not narrate its own construction,
    # so the reply is refused and reported rather than written.
    verdict, note = gate(text, text, out, REPO_ROOT)
    if verdict != "ok":
        return md.name, "rejected", note
    hits = sorted({m.group(0).strip() for m in NARRATION.finditer(out)})
    if hits:
        return (
            md.name,
            "rejected",
            "narration in the document: %s" % ", ".join(hits)[:120],
        )
    md.write_text(out.strip() + "\n", encoding="utf-8")
    rec = {
        "ts": time.time(),
        "module": md.name,
        "provider": provider,
        "chars": len(out),
        "secs": round(secs, 1),
    }
    with STATE.open("a") as fh:
        fh.write(json.dumps(rec) + "\n")
    return md.name, "filled", "%d chars in %.0fs" % (len(out), secs)



HERMES_BRIEF = """You are filling ONE section of the code-factory operations master document.

FILE TO EDIT (in place): {md}
SOURCE TO READ: {src}

Read the template first. Read the source with your own tools. Then fill the template in place,
keeping its section structure exactly as it stands.

RULES, and they are gates, not advice:
1. Every factual claim carries a locator that resolves: `path/to/file.py:LINE`. A locator naming a
   line the file does not have is a FAILED section.
2. If the source does not show something, leave it UNKNOWN and leave the section RED. A RED section
   is a valid outcome; an invented one is not.
3. Log lines are quoted VERBATIM from the source.
4. A service contract names BOTH sides, or stays RED.
5. Do NOT drop, merge or renumber sections. The census before and after must match.
6. Do NOT write "VERIFIED" yourself: a gate recomputes the status from your locators.

THE SYSTEM THIS DOCUMENTS (from the project's own decisions, not from guesswork):
- The Hermes foreman runs ON the project's bunker node, never on the control host
  (specs/HARNESS-MATRIX.md I1). One bunker per project; every lane of that project enters it.
- Support is measured, never claimed: a harness counts only when the conformance battery's legs are
  green on a real node (specs/HARNESS-MATRIX.md I4).
- Credentials travel as file paths at mode 600, never as argv values (AGENTS.md r8, and a quorum
  caught a token in curl's argv on 2026-11-05).
- The board is .coding-hermes/board/tasks.jsonl; a row closes only with a re-runnable command.

When you are done, print one line: FILLED {md_name} <n> sections <m> locators.
"""


def fill_one_hermes(md, provider, model, max_turns=40):
    """Dispatch the section to a real Hermes seat, then gate what it wrote and revert on failure.

    The point of this mode over fill_one(): a seat can read the tree, run a command, recall the
    project's memory and refuse a section it cannot support. fill_one() cannot do any of those.
    """
    import subprocess, tempfile

    text = md.read_text(encoding="utf-8")
    m = re.search(r"\| Path \| `([^`]+)` \|", text)
    if not m:
        return md.name, "skip", "no path field"
    src = resolve(m.group(1), "")
    if not src or not src.is_file():
        return md.name, "skip", "source not found: %s" % m.group(1)
    brief = HERMES_BRIEF.format(md=md, src=src, md_name=md.name)
    with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as fh:
        fh.write(brief)
        bpath = fh.name
    try:
        run = subprocess.run(
            ["hermes", "chat", "-q", open(bpath).read(), "-m", model, "--provider", provider,
             "-Q", "--max-turns", str(max_turns)],
            capture_output=True, text=True, timeout=1800,
        )
    except subprocess.TimeoutExpired:
        return md.name, "error", "hermes seat timed out"
    finally:
        pathlib.Path(bpath).unlink(missing_ok=True)
    if run.returncode != 0:
        return md.name, "error", (run.stderr or run.stdout).strip()[:160]
    now = md.read_text(encoding="utf-8")
    verdict, note = gate(text, text, now, REPO_ROOT)
    if verdict != "ok":
        md.write_text(text, encoding="utf-8")          # revert: the gate is why this mode is safe
        return md.name, "rejected", note
    return md.name, "filled", note

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--workers", type=int, default=2)
    ap.add_argument("--provider", default="deepseek", choices=sorted(PROVIDERS))
    ap.add_argument(
        "--force", action="store_true", help="refill modules that are no longer RED"
    )
    ap.add_argument(
        "--only",
        default="",
        help="comma-separated module filename prefixes, e.g. 05-,07-",
    )
    ap.add_argument(
        "--engine",
        choices=["api", "hermes"],
        default="api",
        help="api = one completions call; hermes = a real seat that can read the tree, run commands and recall memory",
    )
    ap.add_argument("--model", default="", help="model id for --engine hermes")
    a = ap.parse_args()

    files = sorted(MASTER.glob("[0-9][0-9]-*.md"))
    only = tuple(p.strip() for p in a.only.split(",") if p.strip())
    todo = []
    for f in files:
        if only and not f.name.startswith(only):
            continue
        t = f.read_text(encoding="utf-8")
        if a.force or "RED — no verification recorded" in t:
            todo.append(f)
    if a.limit:
        todo = todo[: a.limit]
    print(
        "todo=%d provider=%s workers=%d" % (len(todo), a.provider, a.workers),
        flush=True,
    )
    if not todo:
        return
    with ThreadPoolExecutor(max_workers=a.workers) as ex:
        def run_one(f):
            if a.engine == "hermes":
                return fill_one_hermes(f, a.provider, a.model or "openai/gpt-6.1-sol")
            return fill_one(f, a.provider)
        for name, status, note in ex.map(run_one, todo):
            print("%-52s %-9s %s" % (name[:52], status, note), flush=True)


if __name__ == "__main__":
    main()
