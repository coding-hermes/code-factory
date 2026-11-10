# CF-412: ownership residue classification

Git's default porcelain can collapse an untracked directory to `.gitreins/`,
which obscured rescue patches and caused an unowned-changes classification.
The status query now asks Git for all untracked paths, and only root-relative
`.gitreins/rescued-` prefixes qualify as residue. Unrelated untracked paths and
tracked changes remain unowned. Expanded paths are also used in ownership
coverage and path counts; CF-413 lock matching is not changed by this work.

The focused hermetic CLI tests and pre-fix and substring negative controls are
recorded in [the command evidence](cf412-residue-evidence.txt). The foreman owns
independent judging and board closeout.

ch:trace row=CF-412 spec=docs/handbook/chapters/M6-documentation.md#3-submodule-inventory wave=none:serial test=tests/test_ownership_residue.py doc=docs/handbook/chapters/M6-documentation.md evidence=docs/audits/cf412-residue-evidence.txt witness=none:hermetic-cli-fixtures verdict=none:foreman-judge-pending commit=none:self-referential-worker-commit memory=none:foreman-writes
