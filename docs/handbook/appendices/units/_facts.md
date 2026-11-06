# _facts.md — the ledger every claim in this document set must stand on

One row per fact. `how measured` is a command, a path or a store — never "the docs say". Confidence
classes: `measured`, `read-from-code`, `told-by-operator`, `assumed`. An `assumed` fact can never
back a normative statement.

A module section may only cite a fact that exists here (`fact: FACT-nn`), and
`scripts/master_doc_check.py` refuses a VERIFIED section that cites none.

| id | claim | how measured | measured at | confidence |
|---|---|---|---|---|
| FACT-01 | The Hermes foreman runs on the project's bunker node; **some projects still run on the control host** (the rule is the target topology, not a measured fact about every project today) | specs/HARNESS-MATRIX.md I1; owner 2026-11-05, session `20261104_135646_4f6de1` msg 6579783: "ther are some projects that we still run on the control host" | 2026-11-05 | told-by-operator |
| FACT-02 | One bunker serves one project; every lane of that project enters it | specs/HARNESS-MATRIX.md I1; topology sheet 2.2 | 2026-11-05 | told-by-operator |
| FACT-03 | crier verifies a per-agent ed25519 signature BEFORE it looks the agent up, so an unsigned read answers 401 by design | crier internal/registry/agentsig.go; measured ladder: no bearer 401 / wrong bearer 401 / bearer only 401 / bearer+key 200 on cf-node | 2026-11-05 | measured |
| FACT-04 | A node's inbox read is 200 with a valid key+bearer | `python3 ~/node-bus-worker.py --check` on cf-node → "inbox — GET /agents/cf-node/inbox/stats -> 200" | 2026-11-05 | measured |
| FACT-05 | Credentials travel as file paths at mode 600, never as argv values | AGENTS.md r8; a quorum seat found the DuckBrain token in curl's argv and commit 69f2168 moved it to `-K -` on stdin | 2026-11-05 | measured |
| FACT-06 | This project's lanes are xkiro and DeepSeek PAYG only; no Ollama credits are spent here | owner directive 2026-11-05; PROVIDERS in scripts/master_doc_fill.py | 2026-11-05 | told-by-operator |
| FACT-07 | deepseek-v4-flash is preferred over deepseek-v4-pro for this project's writing | owner directive 2026-11-05 | 2026-11-05 | told-by-operator |
| FACT-08 | A harness counts as supported only when the conformance battery's legs pass on a real node | specs/HARNESS-MATRIX.md I4; tests/harness-conformance.sh | 2026-11-05 | read-from-code |
| FACT-09 | The board is .coding-hermes/board/tasks.jsonl, append-only, one JSON object per line | AGENTS.md "The board" | 2026-11-05 | told-by-operator |
| FACT-10 | A row closes only with a re-runnable command in its evidence, never a commit message | AGENTS.md rule 3 and "The board" | 2026-11-05 | told-by-operator |
