# patches/ — the versioned home of the fleet ops census script

The fleet operations census (`fleet_ops_check.py`) runs from
`~/.hermes/scripts/fleet_ops_check.py`. That directory is not a git repository, so the script
itself is tracked in no commit anywhere. This directory is therefore its **only** version
history, and it is the only thing that makes a change to it auditable:

```
patches/base/fleet_ops_check.py.orig   the PRISTINE module every patch applies to
patches/fleet-ops-<name>.patch         one patch per landed change, in chain order
patches/fleet-ops-<name>.test.py       the regression arms for that change
patches/fleet-ops-chain.sha256         the digest of the module after every stage
scripts/verify-patch.sh                the drift gate: rebuild the chain, compare with live
```

## Base

`patches/base/fleet_ops_check.py.orig` — sha256
`b0054326771850a85e2240a00f89935a3817ab864d445779740a92c2de3f2e9d`, 347 lines. Its suffix is
`.orig`, not `.py`, on purpose: the module is a pristine input, not tree source, and a `.py`
suffix would put it in the path of the Python lint lane for no benefit.

## Applying a patch

Each patch's own header names its target. The target path **exists at `HEAD`**, so the check
runs from the repository root against the shipped base:

```bash
git apply --check patches/fleet-ops-shell-toolkit.patch     # rc 0 against the tracked base
```

To materialise the patched module, apply into a scratch tree — never in place, because the
shipped base must stay pristine:

```bash
work=$(mktemp -d); mkdir -p "$work/patches/base"
cp patches/base/fleet_ops_check.py.orig "$work/patches/base/"
( cd "$work" && git apply "$OLDPWD/patches/fleet-ops-shell-toolkit.patch" )
# the result is "$work/patches/base/fleet_ops_check.py.orig"
```

The patches apply in chain order. `fleet-ops-backup-heuristic.patch` and
`fleet-ops-ci-markers.patch` name a bare `fleet_ops_check.py` (the filename the live script has),
so carry the previous stage's output into that name before applying them:

```bash
cp "$work/patches/base/fleet_ops_check.py.orig" "$work/fleet_ops_check.py"
( cd "$work" && git apply "$OLDPWD/patches/fleet-ops-backup-heuristic.patch" \
                        && git apply "$OLDPWD/patches/fleet-ops-ci-markers.patch" )
```

## Chain digests

Reproduce the chain stage by stage and compare each result with
`patches/fleet-ops-chain.sha256`:

| stage | patch | sha256 after the stage |
|---|---|---|
| base | — | `b0054326771850a85e2240a00f89935a3817ab864d445779740a92c2de3f2e9d` |
| shell-toolkit | `fleet-ops-shell-toolkit.patch` | `82a3bf3418f1f521e3941334d796e09e1088512eb0f75ddd89d468d36f81d976` |
| backup-heuristic | `fleet-ops-backup-heuristic.patch` | `77d1deb2bd97e61f88b90497590f9d6601003584e380ac9fbc97ccc8d6cd7829` |
| ci-markers | `fleet-ops-ci-markers.patch` | `f393a681a59ef80d8386d00dd15074e78701d8244f5cd447544322785b2ef6e6` |
| deploy-doc | `fleet-ops-deploy-doc.patch` | `57432007b324f382a90bf7405a8bb50735a87a145ed95f5e0e5b782b964e7687` |

The `ci-markers` digest was the module live on 2026-11-05; `deploy-doc` is the module live from
2026-11-07 (SCHED-GAP-16989 — the arm graded filename spelling, not the deploy path).

## The drift gate

```bash
bash scripts/verify-patch.sh                          # compares with the live script
bash scripts/verify-patch.sh /path/to/a/copy          # compares with that copy
FLEET_OPS_SCRIPT=/path/to/script bash scripts/verify-patch.sh
```

It rebuilds the module from the shipped base through every patch, checks each stage against the
recorded digest, and then compares the final stage with the live file. It prints a named
`PASS` / `FAIL` / `SKIP` row per arm and exits 1 if any arm fails. It never writes to the live
script; a checkout without the fleet prints `SKIP` for the live arm and still verifies the chain
against the recorded digests.

When the gate reports live drift, the live script has been edited without a patch here. Do not
"fix" the gate: capture the edit as a new patch (pristine = the previous stage, patched = the new
live content), append its stage digest to `fleet-ops-chain.sha256`, and add its regression arms.

## Regression arms

`patches/fleet-ops-*.test.py` take the script path as `argv[1]` (default: the live path) and
print `PASS`/`FAIL` per arm, exiting 1 on any failure. They are the only executable proof for a
change, because the module is not in the tree and `tests/selftest.sh` cannot import it.
