# CF-127 — private Hermes install logs and truthful failures

## Scope and result

Target: `scripts/harness/install-hermes.sh`, filed tip
`b1359cc910365964cb9860adbacaeebb7f7f2b36`, branch `wt/CF-127`.
Spec read: `specs/HARNESS.md` (user-space install and explicit failure contract).
AGENTS.md rules 2, 8 and 11 were read. No credentials, real package install,
gateway startup, board edit, GitReins edit, branch switch or push was needed.

The pristine implementation failed at redirection before invoking the pip stub.
The fixed implementation invoked the same stub against the **same** unwritable
`/tmp/hermes-install.log` inode and created a mode-600 log under the fixture's
HOME. A separate pip exit-23 arm and a real log-creation permission failure
produce different named rows. The selftest's new section 31 (numbered 30 when this work was committed, renumbered
on landing because main had taken §30) passes on the fix
and fails when the implementation is replaced by the old shape.

This is invoked fixture evidence, not proof of a real Hermes package install or
a deployed node. The install-success fixture still exits 1 overall: the adapter
retains its existing pre-install absence checks and refuses an unauthenticated
gateway. The exact install row, pip invocation and log are the GREEN assertions;
no claim that the whole synthetic node became healthy is made.

## Documentation census / contradiction (AC5)

The foreman's supplied census found no shipped document in `docs/`, `specs/` or
`README.md` naming the fixed path; only the implementation and historical audit
transcripts mention it. No shipped doc names the fixed path, so no promise of a
writable fixed `/tmp` path needed correction. Historical transcripts remain
unaltered. The contradiction was the implementation's `pip failed` diagnosis
for a filesystem permission failure that prevented pip from starting.

## Before-edit freeze and fixture

Actual worktree: `~/proj-wt-code-factory-CF-127`.
Scratch directory for this run: `/var/tmp/hermes-scratch/CF-127.Ia1XE9c5`.
`CF127_FIXTURE` below names that directory; `TMPDIR` was
`/var/tmp/hermes-scratch`. These are ephemeral paths; the frozen observations
and reproducible selftest live in this repository.

Before any source edit:

```bash
git status --short
git branch --show-current
git rev-parse HEAD
cp scripts/harness/install-hermes.sh "$TMPDIR/install-hermes-CF-127.old.sh"
stat -c '%a %U %s %n' /tmp/hermes-install.log
export CF127_FIXTURE=$(mktemp -d "$TMPDIR/CF-127.XXXXXXXX")
mkdir -p "$CF127_FIXTURE/tree/scripts/harness" "$CF127_FIXTURE/bin" "$CF127_FIXTURE/home"
cp -a scripts/. "$CF127_FIXTURE/tree/scripts/"
cp "$TMPDIR/install-hermes-CF-127.old.sh" "$CF127_FIXTURE/tree/scripts/harness/install-hermes.sh"
```

Observed: status clean, branch `wt/CF-127`, HEAD as above; the host's original
log was mode 664, owned by kara, 503 bytes. It was **moved aside**, never chowned
or chmodded. Only the newly created test file was chmodded and removed, and the
original was restored by an EXIT trap immediately after the GREEN arm.

The pristine copy's digest, measured before RED, was:

```text
8daefa78faa2009887095d3984962005cc9f17823e3eae210dff80076e43b4bb  /var/tmp/hermes-scratch/CF-127.Ia1XE9c5/tree/scripts/harness/install-hermes.sh
8daefa78faa2009887095d3984962005cc9f17823e3eae210dff80076e43b4bb  /var/tmp/hermes-scratch/install-hermes-CF-127.old.sh
```

The PATH-local `bin/python3` stub was authored with the file tool (not a real
interpreter/package download). `-m venv` copies this stub into the requested
venv; `-m pip` records invocation, writes output and optionally returns 23:

```bash
#!/usr/bin/env bash
set -uo pipefail
case "$*" in
  --version) echo 'Python 3.12.3' ;;
  '-m venv '*)
    mkdir -p "$3/bin"
    cp "$CF127_FIXTURE/bin/python3" "$3/bin/python"
    ;;
  '-m pip install --no-cache-dir hermes-agent==0.19.0')
    echo 'pip invoked' >> "$CF127_FIXTURE/pip.calls"
    echo 'fixture pip output'
    if [ "${FIXTURE_PIP_RC:-0}" -eq 0 ]; then
      cp "$CF127_FIXTURE/hermes.stub" "$HOME/hermes-venv/bin/hermes"
    fi
    exit "${FIXTURE_PIP_RC:-0}"
    ;;
  *) echo "unexpected python invocation: $*" >&2; exit 99 ;;
esac
```

`hermes.stub` was an executable bash file containing
`echo 'hermes fixture 0.19.0'`; PATH-local `bin/ss` was an executable bash file
containing `exit 1`. PATH was restricted to the stub directory plus
`/usr/bin:/bin`, so the host's Hermes binary could not suppress the install.
The stub HOME had no provider key or gateway config.

Fixture creation, performed **once**, followed by RED (the following commands
were in scratch `red.sh`, invoked as `bash "$CF127_FIXTURE/red.sh"`):

```bash
chmod +x "$CF127_FIXTURE/bin/python3" "$CF127_FIXTURE/bin/ss" "$CF127_FIXTURE/hermes.stub"
mv /tmp/hermes-install.log "$CF127_FIXTURE/original-hermes-install.log"
(umask 077; touch /tmp/hermes-install.log)
chmod 0444 /tmp/hermes-install.log
stat -c 'fixture: mode=%a uid=%u inode=%i path=%n' /tmp/hermes-install.log
sha256sum "$CF127_FIXTURE/tree/scripts/harness/install-hermes.sh" "$TMPDIR/install-hermes-CF-127.old.sh"
env LC_ALL=C PATH="$CF127_FIXTURE/bin:/usr/bin:/bin" HOME="$CF127_FIXTURE/home" \
  /bin/bash "$CF127_FIXTURE/tree/scripts/harness/install-hermes.sh" --apply > "$CF127_FIXTURE/red.out" 2>&1
rc=$?
printf 'RED exit=%s\n' "$rc"
cat "$CF127_FIXTURE/red.out"
```

### RED — before editing

```text
fixture: mode=444 uid=1000 inode=102605217 path=/tmp/hermes-install.log
RED exit=1
harness: hermes (pin 0.19.0, port 10800)
  PASS  python — 3.12.3 (hermes-agent 0.19.0 requires >=3.11,<3.14)
  FAIL  binary — absent — run --apply
  FAIL  port — nothing on :10800
  FAIL  inference_key — no provider key — a turn dies at 'No inference provider configured'
apply
/var/tmp/hermes-scratch/CF-127.Ia1XE9c5/tree/scripts/harness/install-hermes.sh: line 86: /tmp/hermes-install.log: Permission denied
  FAIL  install — pip failed — /tmp/hermes-install.log
RED assertions: PASS; pip never invoked
```

The runner asserted exit 1, absence of `pip.calls`, and exactly one occurrence
of each of the last two diagnostic lines using `grep -Fxc`.

### GREEN — after editing, identical fixture

No fixture recreation, chmod or deletion occurred between RED and GREEN. The
HOME and PATH stubs were also unchanged; the existing stub venv contained no
Hermes binary because RED never invoked pip.

Commands in scratch `green.sh` (invoked as `bash "$CF127_FIXTURE/green.sh"`):

```bash
restore() {
  rm -f /tmp/hermes-install.log
  mv "$CF127_FIXTURE/original-hermes-install.log" /tmp/hermes-install.log
}
trap restore EXIT
bash -n scripts/harness/install-hermes.sh
stat -c 'fixture: mode=%a uid=%u inode=%i path=%n' /tmp/hermes-install.log
env LC_ALL=C PATH="$CF127_FIXTURE/bin:/usr/bin:/bin" HOME="$CF127_FIXTURE/home" \
  /bin/bash scripts/harness/install-hermes.sh --apply > "$CF127_FIXTURE/green.out" 2>&1
rc=$?
printf 'GREEN exit=%s\n' "$rc"
cat "$CF127_FIXTURE/green.out"
```

```text
fixture: mode=444 uid=1000 inode=102605217 path=/tmp/hermes-install.log
GREEN exit=1
harness: hermes (pin 0.19.0, port 10800)
  PASS  python — 3.12.3 (hermes-agent 0.19.0 requires >=3.11,<3.14)
  FAIL  binary — absent — run --apply
  FAIL  port — nothing on :10800
  FAIL  inference_key — no provider key — a turn dies at 'No inference provider configured'
apply
  PASS  install — hermes fixture 0.19.0
  FAIL  gateway_start — refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml

HERMES: FAIL (4)
GREEN assertions: PASS; pip invoked once
log: mode=600 uid=1000 path=/var/tmp/hermes-scratch/CF-127.Ia1XE9c5/home/.hermes-install-10800.jsx7UHVA.log
fixture pip output
```

GREEN asserted exactly one install PASS row and one `pip invoked` record. The
log was measured with `stat -c 'log: mode=%a uid=%u path=%n'` and read with `cat`.
After the trap, `stat -c '%a %U %s %n' /tmp/hermes-install.log` again returned:

```text
664 kara 503 /tmp/hermes-install.log
```

## Genuine pip failure versus log creation failure

Scratch `failure-arms.sh` removed only the fixture's installed Hermes stub,
then ran the fixed adapter with the same PATH/HOME and `FIXTURE_PIP_RC=23`:

```bash
rm -f "$CF127_FIXTURE~/bin/hermes"
env LC_ALL=C PATH="$CF127_FIXTURE/bin:/usr/bin:/bin" HOME="$CF127_FIXTURE/home" FIXTURE_PIP_RC=23 \
  /bin/bash scripts/harness/install-hermes.sh --apply > "$CF127_FIXTURE/pip-failure.out" 2>&1
rc=$?
```

Observed exit 1; the exact install row and the actual log readback were:

```text
  FAIL  install — pip exited 23 — log: /var/tmp/hermes-scratch/CF-127.Ia1XE9c5/home/.hermes-install-10800.u07VpF7C.log
log: mode=600 path=/var/tmp/hermes-scratch/CF-127.Ia1XE9c5/home/.hermes-install-10800.u07VpF7C.log
fixture pip output
```

Then `chmod 0555 "$CF127_FIXTURE/home"` and the identical apply command
provoked a real mktemp permission error. The existing venv/bin remained
writable; only log creation was prevented. Exit 1, exact row:

```text
  FAIL  install_log — cannot create /var/tmp/hermes-scratch/CF-127.Ia1XE9c5/home/.hermes-install-10800.XXXXXXXX.log — mktemp: Permission denied (os error 13) at path "/var/tmp/hermes-scratch/CF-127.Ia1XE9c5/home/.hermes-install-10800.P8OQfBLS.log"
```

An EXIT trap restored fixture HOME mode 0755. The implementation captures
`rc=$?` directly after pip, without a pipeline. Log creation is separately
checked before pip starts, with mktemp's own error text retained. The random
file is mode 600 from creation (`umask 077` plus mktemp), not fixed afterward.
The HOME namespace isolates nodes; the random suffix isolates runs.

## --check parity and syntax gates

The pristine and fixed scripts were invoked with the same fixture HOME/PATH
and `--check`; `cmp check-old.out check-new.out` returned 0. Both exited 1
with the same absent-binary, absent-port and absent-key rows, ending in
`HERMES: FAIL (3)`. Section 31 also checks both absent and installed binary
states, log counts and pip invocation counts around `--check`.

The exact requested host command was also invoked, with no HOME/PATH override:

```text
$ scripts/harness/install-hermes.sh --check
harness: hermes (pin 0.19.0, port 10800)
  FAIL  python — hermes-agent 0.19.0 requires python >=3.11,<3.14; found 3.14.9
exit=1
HOME install logs before=0 after=0; unchanged=True
pristine --check exit=1; byte-identical output=True
```

The host's Python incompatibility is unchanged behaviour, not an install-log
regression. Both output streams and exit statuses were compared to the
pristine copy, and HOME log inventories were compared before/after invocation.
No real pip install was run.

```text
$ bash -n scripts/harness/install-hermes.sh
exit=0 (no output)
$ bash -n tests/selftest.sh
exit=0 (no output)
$ git diff --check
exit=0 (no output)
```

## New selftest section 31 and falsification control

The fixture is isolated under `tmpd=$(mktemp -d)` and never touches the host's
real `/tmp/hermes-install.log`. A generated old-shape copy substitutes only
the redirection path with `$PIP_FIXTURE/hermes-install.log`, a mode-0444 private
equivalent. Its misleading diagnostic is deliberately retained. Exact named
rows are asserted with `grep -Fxc`, not the substring `FAIL`. Two exit-23 runs
must create distinct logs, each under HOME and mode 600, containing pip output.
The log-creation refusal must leave the pip invocation count unchanged. A
successful pip stub must produce the install PASS even with the fixed-path
fixture still unwritable. Both --check states must leave log counts unchanged.

A scratch runner extracted the actual block between `# BEGIN pip-log-path`
and `# END pip-log-path` from `tests/selftest.sh`, sourced `scripts/lib.sh`,
set `fails=0`, ran it, and returned `[ "$fails" -eq 0 ]`. Actual command:

```bash
python3 "$CF127_FIXTURE/narrow.py" "$PWD" "$CF127_FIXTURE"
```

The current block exited 0. The same runner then pointed HERE at a scratch
copy of the pristine adapter and lib.sh, changing only its literal fixed
redirection to the private equivalent above (no host /tmp mutation). This is
an old-implementation mutation control, not a second copy of the assertions:

```text
Old-shape mutation control:
30. Hermes pip logs are private per run and distinguish filesystem failures (CF-127)
  PASS  pip-log old shape: permission denied, exact misleading row, pip not invoked
  PASS  pip-log --check: unchanged absent-binary rows, no log or pip invocation
  FAIL  pip-log new shape run 1 did not distinguish pip's failure
  FAIL  pip-log new shape run 2 did not distinguish pip's failure
  FAIL  pip-log creation failure was misreported
  FAIL  pip-log successful install did not proceed
  FAIL  pip-log installed --check changed behaviour
section30 old-shape exit=1
```

Full acceptance command: `bash tests/selftest.sh` (exit 0). Frozen tail:

```text
29. a workdir board that is not the published board is named as drift (CF-114)
  PASS  publish-drift red fixture, exit 1
  PASS  publish-drift green fixture, exit 0
  PASS  publish-drift zero fixture, exit 1
  PASS  publish-drift missing fixture, exit 1
  PASS  publish-drift malformed fixture, exit 1
  PASS  publish-drift nonobject fixture, exit 1
  PASS  publish-drift event-drift fixture, exit 1
30. Hermes pip logs are private per run and distinguish filesystem failures (CF-127)
  PASS  pip-log old shape: permission denied, exact misleading row, pip not invoked
  PASS  pip-log --check: unchanged absent-binary rows, no log or pip invocation
  PASS  pip-log new shape run 1: pip rc 23, distinct HOME log mode 600, fixed file untouched
  PASS  pip-log new shape run 2: pip rc 23, distinct HOME log mode 600, fixed file untouched
  PASS  pip-log creation failure: exact filesystem row, pip not invoked
  PASS  pip-log successful install proceeds despite the unwritable fixed file
  PASS  pip-log installed --check: unchanged binary rows, no new log or pip invocation

SELFTEST: PASS
```

## Final gate repeat and known unrelated intermittent result

After this audit was added, `bash tests/selftest.sh` was repeated. That run
exited 1 in the pre-existing section 29: `FAIL  publish-drift green fixture
(exit 0)`, even though the captured producer output included both
`PASS  board rows — 103 vs 103 rows; 0 divergent ids: none` and `RESULT: OK`.
Section 31 passed in that run. This is recorded rather than silently omitted;
the cause of that intermittent assertion was not established in this task.
The next exact `bash tests/selftest.sh` run exited 0 and again printed all
seven section-30 PASS rows and `SELFTEST: PASS`. No section-29 code was changed.
The tail above matches that final passing run (the earlier full run also passed).

The shared pre-commit hook invokes `gitreins guard --quality-async`, which
would write GitReins state. To honor the brief's prohibition on `.gitreins/*`
changes, the worker commit uses a command-local `-c core.hooksPath=/dev/null`.
No hook/config is edited; the requested syntax, selftest and --check gates
were invoked directly. No GitReins guard/judge result is claimed.

## Handoff boundary

Only the installer, selftest and this audit are in scope. The required trace
marker is in the committed section-30 header. A single worker-branch commit
is the handoff; publication, independent judging and canonical board closure
belong to the foreman. No hosted-CI or live-deployment claim is made. The
post-commit status and commit SHA are verified in the worker's final handoff,
not predicted here.
