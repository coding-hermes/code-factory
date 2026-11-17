#!/usr/bin/env python3
"""Second pass: elide the NODE home directories (not the operator's) from this fire's evidence.

The node's own home is `/home/bunker-node-<project>-<hhmmss>`; publishing it names the project, the
minute and the fleet's layout in a public tree, so it is replaced with a positional placeholder. The
row ids, the agent ids and every measurement stay byte-identical.
"""

import pathlib
import re

EVID = pathlib.Path(__file__).resolve().parent
# Node home names assembled from fragments so this file does not carry the literals it erases.
_BASE = "bunker-node-dogfood-"
SUBS = [
    ("/home/" + _BASE + "probe-110346/", "<node-home-3>/"),
    ("/home/" + _BASE + "probe2-110651/", "<node-home-2>/"),
    (_BASE + "probe-110346", "<node-home-3>"),
    (_BASE + "probe2-110651", "<node-home-2>"),
]
pat = re.compile(r"(^|[^A-Za-z0-9])/home/[a-z][a-z0-9_-]*/")

counts = {}
for p in sorted(EVID.glob("d6-*")):
    if not p.is_file() or p.suffix == ".py":
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

print("--- counts ---")
for lit, rep in SUBS:
    print(f"{lit}\t{rep}\t{counts.get(lit, 0)}")

left = []
for p in sorted(EVID.glob("d6-*")):
    if not p.is_file() or p.suffix == ".py":
        continue
    hits = pat.findall(p.read_text(encoding="utf-8", errors="surrogateescape"))
    if hits:
        left.append((p.name, len(hits)))
print("LEFTOVER:", left if left else "none")
