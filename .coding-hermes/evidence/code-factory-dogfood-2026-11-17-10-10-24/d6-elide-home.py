#!/usr/bin/env python3
"""Elide absolute host-home paths from this fire's evidence files (CF-050 gate, section 61).

Replaces the operator's home prefix with `~`, which is the convention every earlier evidence file in
this directory uses. Counts every replacement so INDEX.md's table is derived, and re-checks that no
`/home/<name>/` literal survives.
"""

import pathlib
import re

EVID = pathlib.Path(__file__).resolve().parent
HOME_PREFIX = "/home/" + "kara/"
pat = re.compile(r"(^|[^A-Za-z0-9])/home/[a-z][a-z0-9_-]*/")

total = 0
for p in sorted(EVID.glob("d6-*")):
    if not p.is_file() or p.suffix == ".py":
        continue
    text = p.read_text(encoding="utf-8", errors="surrogateescape")
    n = text.count(HOME_PREFIX)
    if n:
        text = text.replace(HOME_PREFIX, "~/")
        p.write_text(text, encoding="utf-8", errors="surrogateescape")
        total += n
        print(f"{p.name}: {n} home prefix(es) elided")
print(f"TOTAL={total}")

left = []
for p in sorted(EVID.glob("d6-*")):
    if not p.is_file() or p.suffix == ".py":
        continue
    hits = pat.findall(p.read_text(encoding="utf-8", errors="surrogateescape"))
    if hits:
        left.append((p.name, len(hits)))
print("LEFTOVER:", left if left else "none")
