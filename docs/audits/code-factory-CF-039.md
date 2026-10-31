# CF-039 verification audit

Row: CF-039 — prove the resolved-ref clone-failure branch is distinct from missing-ref and repository-access failures.

## Baseline and red control

The pre-CF-034 baseline is commit `792e687cd68db4f60f795752894ce0cd66db5069`. A scratch archive of that tree received the CF-039 selftest fixture without any other source changes. Command:

    bash tests/selftest.sh

Observed on the baseline-plus-fixture tree:

    4. clone errors distinguish missing refs from repository access
      FAIL  resolved main ref was not distinguished from clone failure
    SELFTEST: FAIL (4)

The fixture uses a fake `git` executable. Its `ls-remote --exit-code` returns `refs/heads/main`, while its `clone` command fails with `fatal: simulated clone failure for fixture`. This is network-free and proves the ref-resolution branch is exercised.

## Fixed control

Fixed commit: `fa48e14349ae468fe1cfc6cf2d0943fcac1922f3`.

Commands:

    bash -n tests/selftest.sh scripts/project-node.sh
    bash tests/selftest.sh

Observed:

    4. clone errors distinguish missing refs from repository access
      PASS  resolved main ref is distinguished from clone and private-repo failures
    SELFTEST: PASS

The fixture asserts all of the following:

- `ls-remote` was called for `refs/heads/main` and returned success.
- `clone --depth 1 --branch main` was called and failed.
- Output contains `clone failed after ref 'main' resolved`.
- Output does not claim `ref 'main' was not found`.
- Output does not claim `private repos need a deploy key`.

## Scope and traceability

The production classification already exists in `scripts/project-node.sh`: after clone fails, a successful `ls-remote` produces the resolved-ref message; exit code 2 identifies a missing ref; other failures retain the deploy-key hint. CF-039 adds the previously missing regression fixture in `tests/selftest.sh`.

ch:trace row=CF-039 spec=scripts/project-node.sh#clone-error-classification wave=none:serial test=tests/selftest.sh::clone-error-classification doc=docs/audits/code-factory-CF-039.md prompt=prompts/qa.md evidence=docs/audits/code-factory-CF-039.md witness=none:local-fixture verdict=7daf0f06 commit=fa48e14349ae468fe1cfc6cf2d0943fcac1922f3 memory=none:unresolved-namespace

No network, credentials, private endpoints, or live infrastructure are required.