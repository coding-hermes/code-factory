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

PROVIDERS = {
    "ollama-cloud": (
        "https://ollama.com/v1/chat/completions",
        "OLLAMA_API_KEY",
        "glm-5.3-flash",
    ),
    "deepseek": (
        "https://api.deepseek.com/v1/chat/completions",
        "DEEPSEEK_API_KEY",
        "deepseek-v4-pro",
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


def call(provider, prompt, timeout=240):
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
            "max_tokens": 12000,
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
    if not txt:
        raise RuntimeError(
            "empty reply; finish=%s"
            % (j.get("choices") or [{}])[0].get("finish_reason")
        )
    return txt, time.time() - t0


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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--workers", type=int, default=2)
    ap.add_argument("--provider", default="ollama-cloud")
    ap.add_argument(
        "--force", action="store_true", help="refill modules that are no longer RED"
    )
    ap.add_argument(
        "--only",
        default="",
        help="comma-separated module filename prefixes, e.g. 05-,07-",
    )
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
        for name, status, note in ex.map(lambda f: fill_one(f, a.provider), todo):
            print("%-52s %-9s %s" % (name[:52], status, note), flush=True)


if __name__ == "__main__":
    main()
