# CF-005 verification evidence — 2026-10-30

Implementation commit: `9a04a4a50f76e9eb33ccea0cf16f5eeca6bde664`
Published merged commit: `840d49a6687567fab71972c2ce7e87cc5e5a0d68`
Worker branch: `wt/CF-005` (pushed; remote parity verified at zero)

Commands run on the merged tree:

- `bash tests/selftest.sh` — exit 0, `SELFTEST: PASS`; all 8 sections passed, including the empty-PATH checker failure, contract assertions, hermetic verifier good/open-auth/bad-digest arms, hermetic creator/provision-failure arms, digest rejection, credential scan, board parse, and board entrypoint failure.
- `bash -n scripts/*.sh scripts/harness/*.sh tests/*.sh` — exit 0.
- `git diff --check` — exit 0.
- `gitreins guard --full` — Tier 1 PASS: secrets, lint, and full tests.
- `git push origin feat/code-factory-bankai-20261030` followed by fetch and `git rev-list --count origin/feat/code-factory-bankai-20261030..HEAD` — `0`.

The source contract now documents the three script boundaries and manifest mapping, the node checker has a falsifiable failure arm, and control-host creator/verifier behavior is covered by hermetic success and failure fixtures. No bunker server, Crier identity/worker, inference credential, or live gateway was available; production node creation and a live artifact round trip remain NOT VERIFIED/BLOCKED and are not claimed here.

ch:trace row=CF-005 spec=specs/NODE.md#script-boundary-and-manifest-mapping wave=none:serial-tick-no-wave test=tests/selftest.sh::selftest doc=docs/DESIGN.md prompt=none:worker-brief-transient evidence=docs/audits/code-factory-CF-005-20261030.md witness=none:no-live-bunker-crier-gateway verdict=none:foreman-judges-after-board-closeout commit=840d49a6687567fab71972c2ce7e87cc5e5a0d68 memory=none:worker-does-not-write-durable-memory
STATUS: complete
TIER: T1 — local source, hermetic fixtures, selftest, and full guard observed; live infrastructure remains blocked.
EVIDENCE: docs/audits/code-factory-CF-005-20261030.md; commit 840d49a6687567fab71972c2ce7e87cc5e5a0d68
