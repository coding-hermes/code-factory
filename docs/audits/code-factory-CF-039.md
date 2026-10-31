# CF-039 verification audit

Task: add a falsifiable QA regression for the evidence-pointer gap found in completed row
CF-038 — the README's first-named evidence artifact (`docs/audits/code-factory-readme-2026-10-30-20-29-25.md`)
did not contain the tokens the current README's claims rest on, so the first-named evidence
could not independently support the README.

Baseline before this change: `8a6b7e3` (origin/main). Implemented and verified in worktree
branch `wt/CF-039-20261031-154958`; the shared checkout was mid-rebase and its README predates
the evidence line, so it could not host this change. This file is committed with the fix and is
the fixed-tip evidence artifact.

## The gap, measured on the pre-fix tree

Case-sensitive `grep -c` of each required token in the two artifacts the README cited:

| token | 20-29-25.md | 23-28-00.md |
|---|---|---|
| repo_clone | 4 | 3 |
| 9402f6a | 2 | 1 |
| Prompt | 0 | 1 |
| eleven | 0 | 2 |

The first-named artifact carried zero `Prompt` and zero `eleven` counts — CF-038's finding.

## Red arm — pre-fix tree (test added, README unchanged)

Command:

    bash tests/selftest.sh

Section 11 output (exact):

    11. the README's first evidence artifact carries the claims it is cited for
      FAIL  first README evidence artifact cannot support the README: docs/audits/code-factory-readme-2026-10-30-20-29-25.md lacks: Prompt eleven
      PASS  token-stripped artifact refused (docs/audits/code-factory-readme-2026-10-30-20-29-25.md lacks: repo_clone 9402f6a Prompt eleven)

    SELFTEST: FAIL (1)

Exit code: 1. Sections 1–10 (the existing negative controls) all PASS on this run; only the new
section fails, and it names the deficient artifact and the missing tokens.

## The fix

The README evidence line is reordered so the first-named artifact is the one that carries every
claim token (`…23-28-00.md`, the latest command-by-command re-run). Both citations are kept; no
artifact content was altered.

## Green arm — fixed tree

Commands:

    bash -n tests/selftest.sh        # exit 0, no output
    bash tests/selftest.sh

Section 11 output (exact):

    11. the README's first evidence artifact carries the claims it is cited for
      PASS  docs/audits/code-factory-readme-2026-10-30-23-28-00.md exists and carries every claim token
      PASS  token-stripped artifact refused (docs/audits/code-factory-readme-2026-10-30-23-28-00.md lacks: repo_clone 9402f6a Prompt eleven)

    SELFTEST: PASS

Exit code: 0. 26 PASS rows, 0 FAIL rows. The negative fixture proves the check can fail: a copy
of the cited artifact with the claim tokens stripped is refused.

## Fresh-archive determinism

The staged tree was exported with `git write-tree` → `git archive b82feead6fec314890683b6af60f02c5e1c73608`
and extracted to a scratch directory; the selftest there uses only repository files (no network,
no private endpoints, no absolute home paths — `grep -rn '/home/kara' tests/selftest.sh` is empty
for the new section).

- Archive of the fixed tree: `SELFTEST: PASS`, exit 0.
- Same archive with the README evidence line restored to the pre-fix order: section 11
  `FAIL  first README evidence artifact cannot support the README: docs/audits/code-factory-readme-2026-10-30-20-29-25.md lacks: Prompt eleven`,
  `SELFTEST: FAIL (1)`, exit 1.

## Scope

- `tests/selftest.sh`: new section 11 (helper `evidence_first`, checker `evidence_deficiency`,
  positive assertion, token-stripped negative fixture). Existing sections and the final
  `SELFTEST: PASS`/`FAIL` output are unchanged.
- `README.md`: evidence line reordered only (first-named artifact now `…23-28-00.md`).
- `docs/audits/code-factory-CF-039.md`: this artifact.
- Board files untouched; nothing pushed.
