CF-435 evidence: the hosted self-test gate exists and is green on the exact main head

What was missing
Command: gh api repos/coding-hermes/code-factory/actions/workflows --jq .total_count
Result: 0
Command: git ls-tree -r --name-only gh/main | grep -c '^\.github/'
Result: 0
Command: ls -d .github
Result: ls: cannot access '.github': No such file or directory (exit 2)

So every merge relied on a human running tests/selftest.sh on the control host.
Nothing bound a verdict to a commit SHA, which is how CF-434's red tests stage and
CF-439's red section 67 could reach main unquestioned (CF-440).

What was added
.github/workflows/selftest.yml, merged to main as e51daff34e0bc44a932df0f04876dec258d3aa71
(PR #13, squash). Two jobs, triggered by push to main, pull_request and
workflow_dispatch:

  secrets  - gitleaks 8.30.1 `dir` scan under the repository .gitleaks.toml
  selftest - bash tests/selftest.sh (68 numbered sections plus 4 lettered arms)

Checkout uses fetch-depth 0 because several arms read git history and ancestry.
The job installs the two pins that grade the host rather than skipping those
arms: actions/setup-go 1.26.5 for section 50 (scripts/install-go.sh --check must
read back the pin it finds on PATH) and ruff 0.15.22 for section 51 (the python
lint lane).

Run history on this defect
Run 43660331457 (head 4bbdf0640ddc3696457b5be672ff8278d95b5291, event
pull_request) concluded failure with both jobs red. That run is what named the
host-graded arms instead of leaving them assumed:

  FAIL  install-go positive: host toolchain did not read back go1.26.5 (exit 1)
  FAIL  ruff is not on PATH, so the lint lane cannot be graded on this host
  SELFTEST: FAIL (2)

Every other section and arm passed on the runner, so the divergence was
environment, not code.

Run 43661953998 (head 2034221e042a41930a25b5aac32bcf6ec897ce17, event
pull_request) concluded success - selftest success, secrets (gitleaks) success -
after the workflow provisioned the two pins.

Run 43662222185 (head e51daff34e0bc44a932df0f04876dec258d3aa71, event push)
concluded success. This is the run bound to the exact main head that carries the
workflow, which is the acceptance condition for this row.

Read-back at the tip
Command: gh api repos/coding-hermes/code-factory/actions/workflows --jq '.total_count, (.workflows[]|[.name,.state,.path]|join(" "))'
Result:
  1
  selftest active .github/workflows/selftest.yml

Command: gh run list --limit 3 --json databaseId,headSha,event,status,conclusion
Result:
  43662222185 e51daff3 push         completed success
  43661953998 2034221e pull_request completed success
  43660331457 4bbdf064 pull_request completed failure

How to reproduce
  gh run view 43662222185 --repo coding-hermes/code-factory --json headSha,conclusion,jobs
  bash tests/selftest.sh                      # same suite, on the control host
  gitleaks dir --no-banner --redact --config .gitleaks.toml .

Local pre-flight recorded before the first push, at base e4174252: SELFTEST: PASS,
EXIT=0, 745 log lines; gitleaks scanned 4.69 MB and reported no leaks.

Scope boundary
This gate proves the suite is green on a clean GitHub-hosted runner. It does not
provision a node, reach a bunker server or call a model; arms that need those
print their own named SKIP. CF-440 states the same missing-CI finding as this row
and is left open so a later tick can decide whether to keep it as the umbrella.
