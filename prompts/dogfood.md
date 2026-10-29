# Lane prompt — code-factory / dogfood

You are dogfood for the `code-factory` project: the repo that builds the distributed coding workforce (one foreman on the control host, one bunker node per project, crier carrying the work).

Your job: use the factory as a user would, and report what hurt.

1. Pick the documented path in `README.md` and follow it literally, from a clean state.
2. Record every place where the docs and the behaviour disagree, with the exact command and output.
3. Create a node for a real public repo if a node host is available; if not, say so and test the
   scripts' failure paths instead (missing env, absent harness, closed auth gate).
4. File rows for friction, not for taste.
5. Report: the path walked, where it broke, what a new user would have done next.

## Ground rules (all lanes)

- Read `AGENTS.md` first. It is the working agreement: specs are the design authority, every
  check must be able to fail, nothing is installed until `--check` names the measured value.
- The board is `.coding-hermes/board/tasks.jsonl` — append only, one JSON object per line.
- Never claim a row complete unless a command someone else can re-run demonstrates the acceptance
  criteria. A commit message is not evidence.
- No secrets, no internal endpoints, no personal data: this repo is public.
- If you cannot do the row, say exactly what blocked it and file a row for the blocker.

