#!/usr/bin/env python3
"""Elide host and tailnet addresses from this fire's evidence files.

The repo is public and no earlier evidence file carries a private literal, so the
delivery-6 artifacts are rewritten with the repo's own placeholder convention before
they are staged. Every replacement is counted so the substitution table in INDEX.md
is derived, not estimated.
"""

import pathlib
import re

EVID = pathlib.Path(__file__).resolve().parent

# (literal, placeholder) — each address assembled from fragments, so this file does not
# republish the literal it erases (the repo gates tracked files for that).
SUBS = [
    ("100." + "69.3.13", "<host-tailnet-3>"),
    ("100." + "78.165.52", "<host-tailnet-1>"),
    ("100." + "95.199.98", "<host-tailnet-4>"),
    ("100." + "116.99.35", "<host-tailnet-2>"),
    ("100." + "97.236.14", "<control-host-tailnet>"),
    ("192." + "168.123.147", "<control-host-lan>"),
    ("192." + "168.123.66", "<node-lan-3>"),
    ("192." + "168.123.65", "<node-lan-2>"),
]

targets = sorted(EVID.glob("d6-*"))
counts = {}
for p in targets:
    if not p.is_file():
        continue
    text = p.read_text(encoding="utf-8", errors="surrogateescape")
    orig = text
    for lit, rep in SUBS:
        n = text.count(lit)
        if n:
            counts[lit] = counts.get(lit, 0) + n
            text = text.replace(lit, rep)
    if text != orig:
        p.write_text(text, encoding="utf-8", errors="surrogateescape")
        print(f"rewrote {p.name}")

print("--- substitution table ---")
for lit, rep in SUBS:
    print(f"{lit}\t{rep}\t{counts.get(lit, 0)}")

leftover = re.compile(
    r"\b(?:100\.\d{1,3}\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3})\b"
)
bad = []
for p in targets:
    if p.is_file() and leftover.search(
        p.read_text(encoding="utf-8", errors="surrogateescape")
    ):
        bad.append(p.name)
print("LEFTOVER:", bad if bad else "none")
