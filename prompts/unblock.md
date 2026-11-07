# Unblocking — the procedure a lane runs BEFORE it writes a blocked receipt

There is one question here: **is this actually a block, or is it something I can resolve?**

Most "blocked" ticks in this project were not blocked. They were a lane meeting state it
had not been told how to interpret, writing a receipt, and stopping. Twenty-two of them
were the same 2,354 files, and the correct action the whole time was disposal.

## Step 1 — classify, do not assume

```bash
python3 scripts/ownership.py status
```

It answers with exactly one state:

| State | What it means | What you do |
|---|---|---|
| `clean` | nothing untracked | proceed |
| `held-by-live-worker` | a live pid holds `.coding-hermes/panel.lock` and owns these paths | **stand down.** This is not a block. |
| `residue` | nothing alive owns these paths; a producer wrote them and exited | **dispose** (step 2), then proceed |
| `unowned-changes` | untracked work with no live owner | **attribute** it (step 3), then commit or revert |

## Step 2 — disposition of residue

Residue is evidence nothing is using. Do not delete it blind, and do not block on it.

```bash
# 1. prove what is unique, by content hash, not by name
#    (a file with the same name is not necessarily the same file)
# 2. publish anything whose sha256 matches nothing already tracked
# 3. delete only what is byte-identical to a tracked copy
# 4. add the producer's output directory to .gitignore so it cannot re-arm the barrier
```

The rule that makes this safe: **delete only on proof of duplication.** If a file's
content exists nowhere else, it is published, not deleted — even if that means keeping
something worthless.

## Step 3 — attribution

`unowned-changes` with no live pid has three honest endings, in this order:

1. **It is mine** — a previous turn of this session wrote it. Commit it or revert it.
2. **It is a sibling's** — find the writer by `state.db` session log or by a unique symbol
   in the diff. Then stand down; do not touch a live sibling's tree.
3. **Nobody owns it and it is not needed** — revert, and say so in the tick report.

## Step 4 — when a block is real

Write a blocked receipt only when all four are true:

- ownership is genuinely ambiguous (two live candidates, or a lock whose pid is alive but
  the process is not in this workdir), **and**
- the required action is owner-only (a credential, a policy decision, a spending decision), **and**
- you have already tried the non-owner paths above, **and**
- you can name the single command or decision that would unblock it.

A receipt that cannot name its own unblocking action is a status report, not a block.

## Step 5 — record it so the next tick does not repeat it

Append to `.coding-hermes/blockers.jsonl`:

```json
{"at":"<iso>","lane":"<lane>","state":"residue|unowned-changes|owner-only",
 "paths":<n>,"resolved_by":"<command you ran|owner action needed>","round":<n>}
```

If the same state recurs with the same resolution, it is not a new block — it is a missing
automation, and it belongs in a board row as one.

## The failure this prevents

Twenty-two consecutive code-factory ticks blocked on the same evidence. Each wrote a
correct, validated receipt. None of them asked whether the barrier could be *resolved*,
because no prompt told them to. The barrier was real; the response was wrong. That is what
this procedure exists to fix.
