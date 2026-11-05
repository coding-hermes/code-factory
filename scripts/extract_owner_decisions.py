#!/usr/bin/env python3
"""extract_owner_decisions.py — enumerate every owner message that could contain a requirement.

The audit that produced CF-335..CF-343 worked by relevance search, which cannot tell you what it
MISSED. This produces the denominator instead: every owner (role='user') message in every session that
mentions the project, written to JSONL so classifiers can work through a fixed, countable set.

Read-only: opens state.db with mode=ro and never writes to it.

    python3 scripts/extract_owner_decisions.py --days 45 --out /tmp/cf-owner-msgs.jsonl
"""

import argparse
import json
import sqlite3
import sys
import time

# Tight on purpose. A first pass with scheduler/harness/foreman matched 56,741 of 64,788 sessions —
# 87% — because every session in this fleet mentions them. That is a corpus, not a filter.
TERMS = (
    "code-factory",
    "code factory",
    "codefactory",
    "bunker",
    "crier",
    "gitreins",
    "node-create",
)

# A message shorter than this is a reply, not a requirement.
SIGNALS = (
    "we need",
    "we should",
    "i want",
    "make sure",
    "dont ",
    "don't ",
    "must ",
    "should ",
    "the goal",
    "remember",
    "always ",
    "never ",
    "instead of",
    "so that",
)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default="/home/kara/.hermes/state.db")
    ap.add_argument("--days", type=int, default=45)
    ap.add_argument("--out", default="/tmp/cf-owner-msgs.jsonl")
    ap.add_argument("--max-chars", type=int, default=2000)
    ap.add_argument(
        "--title-only",
        action="store_true",
        help="candidate sessions must carry a project term in their TITLE (3270 of 64788 in 45d, "
        "versus 47421 by message-content match)",
    )
    a = ap.parse_args()

    con = sqlite3.connect("file:%s?mode=ro" % a.db, uri=True, timeout=30)
    con.execute("PRAGMA busy_timeout=30000")
    since = time.time() - a.days * 86400

    # Enumerate candidates by TIME (indexed), then test each session's messages through the session
    # index. A LIKE join across the whole messages table does not finish in useful time — measured:
    # the direct query timed out at 300 s against 214,879 sessions.
    if a.title_only:
        tlike = " OR ".join("lower(coalesce(title,'')) LIKE ?" for _ in TERMS)
        cand = [
            r[0]
            for r in con.execute(
                "SELECT id FROM sessions WHERE started_at > ? AND (%s) ORDER BY started_at DESC"
                % tlike,
                (since, *["%%%s%%" % t for t in TERMS]),
            )
        ]
    else:
        cand = [
            r[0]
            for r in con.execute(
                "SELECT id FROM sessions WHERE started_at > ? ORDER BY started_at DESC",
                (since,),
            )
        ]
    print(
        "sessions in the last %dd: %d (testing each for project terms)"
        % (a.days, len(cand))
    )

    sessions = []
    pats = ["%%%s%%" % t for t in TERMS]
    probe = (
        "SELECT 1 FROM messages WHERE session_id=? AND ("
        + " OR ".join("lower(coalesce(content,'')) LIKE ?" for _ in TERMS)
        + ") LIMIT 1"
    )
    for sid in cand:
        if con.execute(probe, (sid, *pats)).fetchone():
            sessions.append(sid)
    print("sessions mentioning the project: %d" % len(sessions))

    out = open(a.out, "w", encoding="utf-8")
    n = 0
    for sid in sessions:
        row = con.execute(
            "SELECT title, source, started_at FROM sessions WHERE id=?", (sid,)
        ).fetchone()
        title, source, started = row if row else ("", "", 0)
        for mid, content, ts in con.execute(
            "SELECT id, content, timestamp FROM messages WHERE session_id=? AND role='user' "
            "ORDER BY timestamp, id",
            (sid,),
        ):
            text = (content or "").strip()
            if len(text) < 80:  # greetings and one-word replies carry no requirement
                continue
            low = text.lower()
            signal = any(sig in low for sig in SIGNALS)
            out.write(
                json.dumps(
                    {
                        "session_id": sid,
                        "session_title": title,
                        "session_source": source,
                        "session_started": started,
                        "message_id": mid,
                        "timestamp": ts,
                        "signal": signal,
                        "text": text[: a.max_chars],
                    },
                    ensure_ascii=False,
                )
                + "\n"
            )
            n += 1
    out.close()
    print("owner messages written: %d -> %s" % (n, a.out))
    print(
        "classify in slices of ~60 messages; each slice must return decision|requirement|correction|question|chatter"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
