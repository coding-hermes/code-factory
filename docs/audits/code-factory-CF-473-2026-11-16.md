# CF-473 — the python pin FAIL row now names its own remedy

Date: 2026-11-16 · Ran in a git worktree of this repository (branch `wt/CF-473`, base `1a580d91`)

## What the dogfood walk found

Following README "Quick start" literally from a clean state, step 2
(`./scripts/project-node.sh --check --project myproject`) ends in a hard FAIL whose remedy this
repository already knows and never printed:

```
FAIL  python — hermes-agent 0.19.0 requires python >=3.11,<3.14; found 3.14.9
```

The remedy is one environment variable, and it is documented only inside README *Status* table
cells about `scripts/harness/install-hermes.sh --check` — a command Quick start never tells a
reader to run. README line 35-37 promises "every message tells you which value to supply"; this
row was the counter-example.

## Fix

- `scripts/harness/install-hermes.sh:114` — the pin-violation row appends the escape hatch:
  `— set HERMES_PYTHON_BIN to an in-range interpreter, e.g. HERMES_PYTHON_BIN=python3.12`.
  The measured-value sentence before it is unchanged, because `tests/selftest.sh:666` greps it
  literally.
- `README.md` — Quick start step 2 carries the working command inline, as comments inside the
  existing fenced block, so the failing step and its remedy are on the same screen. No step is
  renumbered and no Status cell is touched (section 30 of the suite binds those).
- `tests/selftest.sh` — new arm block `cf473-python-remedy`: (a) the row must name the variable,
  (b) a copy with the remedy stripped must stop naming it (red control), (c) the README Quick
  start must still name it.

## Evidence (re-runnable)

Host interpreter: `Python 3.14.9`; in-range interpreter used for the second direction:
`python3.12` → `3.12.13`.

Direction 1 — host default (AC1, and AC2's FAIL arm):

```
$ bash ./scripts/project-node.sh --check --project p 2>&1 | grep 'FAIL  python'
  FAIL  python — hermes-agent 0.19.0 requires python >=3.11,<3.14; found 3.14.9 — set HERMES_PYTHON_BIN to an in-range interpreter, e.g. HERMES_PYTHON_BIN=python3.12
```

Direction 2 — same command, explicit interpreter (AC2's PASS arm):

```
$ HERMES_PYTHON_BIN=python3.12 bash ./scripts/project-node.sh --check --project p 2>&1 | grep 'python —'
  PASS  python — 3.12.13 (hermes-agent 0.19.0 requires >=3.11,<3.14)
```

README (AC4):

```
$ awk '/^## Quick start/,/^## Provisioning/' README.md | grep -c HERMES_PYTHON_BIN
1        # was 0 at base 1a580d91
$ grep -c HERMES_PYTHON_BIN README.md
3        # was 2, both inside Status table cells
```

The new arm, run in isolation — extracted between its `BEGIN`/`END` markers with `awk` and driven
by a `say`/`fails` shim, so the code under test is byte-identical to the committed block:

```
$ bash /tmp/cf473/arm.sh
  PASS  a. the out-of-range python row names HERMES_PYTHON_BIN=python3.12
  PASS  b. with the remedy stripped the FAIL row no longer names it (red control)
  PASS  c. README Quick start names HERMES_PYTHON_BIN (1 occurrence)
ARM_FAILS=0
```

Red direction proved two ways.

(i) The arm's own leg (b): a copy of the whole `scripts/` tree whose remedy clause is removed with
`sed -i 's/found \$version[^"]*"/found $version"/'` prints the same FAIL row without the token, so
the assertion in (a) goes red against it.

(ii) The brief's suggested control — the base revision itself, on the same fixture:

```
$ git show 1a580d91:scripts/harness/install-hermes.sh > $D/scripts/harness/install-hermes.sh   # plus lib.sh, harness-vars.sh at 1a580d91
$ env HOME=$D/fakeroot HERMES_PYTHON_BIN=$D/python-3.14 bash $D/scripts/harness/install-hermes.sh --apply 2>&1 | grep 'FAIL  python'
  FAIL  python — hermes-agent 0.19.0 requires python >=3.11,<3.14; found 3.14.9
$ env HOME=$D/fakeroot HERMES_PYTHON_BIN=$D/python-3.14 bash $D/scripts/harness/install-hermes.sh --apply 2>&1 | grep -c 'HERMES_PYTHON_BIN=python3.12'
0
```

At base the row carries no remedy (count 0); on the fixed tree the same fixture prints it (arm (a)
green). Neither direction is argued from a diff — both are printed rows.

`bash -n` clean on `scripts/harness/install-hermes.sh`, `scripts/project-node.sh` and
`tests/selftest.sh`. The full `bash tests/selftest.sh` was not run from this shell: this
repository's pre-commit guard runs it (`test_command: bash tests/selftest.sh`,
`test_timeout: 900`) at the commit, so the whole-suite verdict belongs to the guard on this
change rather than to a partial run reported as green.

## Where the brief and the repository's own apparatus disagreed

The brief asked for "one new numbered arm appended at the end". A numbered section 76 would move
the arm census the plan side binds: `docs/audits/cf198-section-mapping.sh` derives `arms_tree`
from the `say "N.` headers in `tests/selftest.sh`, compares it with the mapping table in
`docs/ACCEPTANCE-PLAN.md`, and section 39 of the suite grades that command. Measured at this
tree with the arm in place:

```
$ bash docs/audits/cf198-section-mapping.sh | tail -2
arms_plan=75 arms_tree=75
RESULT: OK
```

A section 76 with no plan row would report `arms_plan=75 arms_tree=76` and red section 39, and the
plan file is outside this row's file list. So the arm is an add-on block riding the last numbered
section — the file's existing `# BEGIN …` / "part of section N" shape, as used by
`public-bind-auth` under section 10 — and the census stays green. The block is still one new
self-checking arm with its own green and red legs.

## Residual (not fixed here, outside the row's file list)

The pre-fix row text is quoted verbatim in documentation this change therefore makes stale:
`docs/HARNESS-CONFORMANCE.md:17,46`, `docs/handbook/chapters/M5-harness.md:205`, and
`docs/handbook/appendices/units/17-scripts-harness-install-hermes-sh.md:31,87,142` (that unit also
cites `install-hermes.sh:19` for `PYTHON_BIN`, which is line 28 in the tree). Those pages record
measurements taken at earlier tips, so they are left as they are rather than silently rewritten; a
follow-up row should decide whether the appendix unit is regenerated or re-stamped.

## Note on the row's recorded versions

The board text records `found 3.14.4`-style values from the host that raised it; this host
measures `3.14.9` and `3.12.13`. The acceptance criteria are version-agnostic and both directions
reproduce, but the row's prose should not be read as this host's numbers.
