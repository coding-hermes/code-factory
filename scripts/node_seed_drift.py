#!/usr/bin/env python3
"""node_seed_drift.py — prove a node's seeded prompts and skills still match the digests recorded.

scripts/node_seed.py (CF-220) can REFUSE a drifted seed: its check subcommand
prints the drifted path and exits 1. But nothing on the control host ever ran
it, and provisioning deletes the node-side copy of the seeder after it applies.
So a hand-edited prompt or skill on a node passed every arm verify-node.sh had
(no seed leg existed for CF-250, the same gap CF-244 closed for the checkout).

This probe runs that check where the node is, and folds one row named
`seed_drift` into the verifier:

  --agent ID --server NAME   a node's seed, probed through the agent. ONE
                             `bunker exec` round trip: the control host's
                             node_seed.py is staged to a temp path on the node,
                             its `check` subcommand runs with the record the
                             seed left ($HOME/.hermes/seed-applied.json) and
                             home $HOME, and the staged file is removed — all
                             inside that same round trip.
  --home DIR                 a local seed directory. No bunker, no network, no
                             database: this is the mode fixtures and the
                             selftest drive both ways offline.

The verdict is the seeder's own verdict — the wrapper does not reimplement the
digest comparison, it delegates to scripts/node_seed.py and parses its rows, so
the two cannot drift apart.

Exit codes: 0 matched, 1 drifted (or an absent record under --strict-seed),
2 usage, 3 could not measure — no record, a record that does not parse, an exec
that would not answer, or no transport. "Could not measure" is not drift, on
purpose: a node still being provisioned has no seed record yet, and telling an
operator a copy is broken when it was never applied is a false FAIL. The
default verdict for it is WARN; --strict-seed refuses the unknown instead
(same doctrine as the checkout freshness leg).

Usage:
  scripts/node_seed_drift.py --agent cf-node --server bunker-las-03
  scripts/node_seed_drift.py --agent cf-node --server bunker-las-03 --strict-seed
  scripts/node_seed_drift.py --home /tmp/fixture-home
  scripts/node_seed_drift.py --home /tmp/fixture-home --json

stdlib only.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from typing import Optional

BUNKER_BIN = shutil.which("bunker") or "bunker"

EXIT_OK = 0
EXIT_DRIFT = 1
EXIT_USAGE = 2
EXIT_UNMEASURABLE = 3

# The record the seeder leaves behind, relative to the seed's home.
RECORD_REL = os.path.join(".hermes", "seed-applied.json")

# A drifted seed can name many paths; show enough to act on and point at
# --json for the rest.
MAX_SHOWN = 20

# The sibling seeder: the same script provisioning applies on the node, so the
# verdict is the instrument's own, not a wrapper's reimplementation.
SEED_SIBLING_NAME = "node_seed.py"


def run(cmd: list, timeout: int):
    """One command's result. A timeout and a missing binary are results too."""
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return -9, "", f"timeout after {timeout}s: {' '.join(str(c) for c in cmd[:4])}"
    except OSError as exc:
        return -1, "", f"{type(exc).__name__}: {exc}"
    return proc.returncode, proc.stdout, proc.stderr


def shq(value: str) -> str:
    """One value quoted for a remote POSIX shell, apostrophes included."""
    return "'" + value.replace("'", "'\\''") + "'"


# ------------------------------------------------------------- remote script

# ONE round trip on the node. The seeder arrives as a heredoc (the exec stream
# does not forward stdin), the record is validated before anything is staged,
# the check's output is captured verbatim between SEED_BEGIN/SEED_END, and both
# temp files are removed inside the same exec — the node keeps no copy after
# provisioning, and this leg must not leave a second one.
REMOTE_TEMPLATE = r"""
set -u
echo "HOME=$HOME"
REC="$HOME/__RECORD_REL__"
if [ ! -f "$REC" ]; then echo "RECORD=0"; exit 0; fi
if ! python3 - "$REC" -c 'import json,sys; json.load(open(sys.argv[1]))' >/dev/null 2>&1; then
  echo "RECORD=2"
  exit 0
fi
echo "RECORD=1"
STAGED="$(mktemp /tmp/node-seed-check-XXXXXX)"
SEED_OUT="$(mktemp /tmp/node-seed-check-out-XXXXXX)"
cat > "$STAGED" <<'SEED_PY_STAGED_EOF'
__SEED_SOURCE__
SEED_PY_STAGED_EOF
python3 -B "$STAGED" check --record "$REC" --home "$HOME" > "$SEED_OUT" 2>&1
SEED_RC=$?
echo "SEED_RC=$SEED_RC"
echo "SEED_BEGIN"
cat "$SEED_OUT"
echo "SEED_END"
rm -f "$STAGED" "$SEED_OUT"
exit 0
""".lstrip("\n")


def remote_script(seed_source: str) -> str:
    if not seed_source.endswith("\n"):
        seed_source += "\n"
    script = REMOTE_TEMPLATE.replace("__RECORD_REL__", RECORD_REL)
    return script.replace("__SEED_SOURCE__", seed_source)


def parse_remote(text: str) -> dict:
    """The node's key=value lines plus the verbatim check output between markers."""
    data: dict = {"seed_rows": []}
    inside = False
    for line in text.splitlines():
        if line == "SEED_BEGIN":
            inside = True
            continue
        if line == "SEED_END":
            inside = False
            continue
        if inside:
            data["seed_rows"].append(line)
            continue
        for key in ("HOME", "RECORD", "SEED_RC"):
            if line.startswith(key + "="):
                data[key] = line.split("=", 1)[1]
    return data


# ------------------------------------------------------------------ verdicts

RE_PASS = re.compile(r"^  PASS  seed_check — (\d+) files present and matching$")
RE_DRIFT = re.compile(
    r"^  FAIL  seed_check — (.+?) drifted \(([0-9a-f]+) != ([0-9a-f]+)\)$"
)
RE_ABSENT = re.compile(r"^  FAIL  seed_check — (.+?) absent on the node$")


def rows_from_check(check_lines: list) -> tuple:
    """(count, drifted details, absent paths) as the seeder's own rows name them."""
    count = None
    drifted: list = []
    absent: list = []
    for line in check_lines:
        m = RE_PASS.match(line)
        if m:
            count = int(m.group(1))
            continue
        m = RE_DRIFT.match(line)
        if m:
            path, measured, expected = m.groups()
            drifted.append(
                "%s drifted (expected %s, measured %s)"
                % (path, expected[:12], measured[:12])
            )
            continue
        m = RE_ABSENT.match(line)
        if m:
            absent.append(m.group(1))
    return count, drifted, absent


def finding_ok(record: str, count: int) -> dict:
    row = "  PASS  seed_drift — %s: %d seeded files present and matching" % (
        record,
        count,
    )
    return {
        "status": "PASS",
        "exit_code": EXIT_OK,
        "reason": "",
        "rows": [row],
        "result": "RESULT: PASS",
    }


def finding_drift(record: str, count, drifted: list, absent: list) -> dict:
    details = list(drifted) + ["%s absent on the node" % p for p in absent]
    shown = details[:MAX_SHOWN]
    detail = "; ".join(shown)
    if len(details) > MAX_SHOWN:
        detail += " (+%d more — see --json)" % (len(details) - MAX_SHOWN)
    n_drift = len(details)
    if count is not None:
        scope = "%d of %d seeded paths" % (n_drift, count)
    else:
        scope = "%d seeded path(s)" % n_drift
    row = "  FAIL  seed_drift — %s: %s differ from the record: %s" % (
        record,
        scope,
        detail or "no path named by the check",
    )
    return {
        "status": "FAIL",
        "exit_code": EXIT_DRIFT,
        "reason": "%s differ from the record" % scope,
        "rows": [row],
        "result": "RESULT: FAIL (%s differ from the record)" % scope,
    }


def finding_absent(record: str, strict: bool) -> dict:
    if strict:
        return {
            "status": "FAIL",
            "exit_code": EXIT_DRIFT,
            "reason": "no seed record at %s" % record,
            "rows": [
                "  FAIL  seed_drift — no seed record at %s (--strict-seed: an unknown seed is not a pass)"
                % record
            ],
            "result": "RESULT: FAIL (no seed record at %s)" % record,
        }
    return {
        "status": "WARN",
        "exit_code": EXIT_UNMEASURABLE,
        "reason": "no seed record at %s" % record,
        "rows": [
            "  WARN  seed_drift — no seed record at %s — nothing on this seed's home is digest-recorded; "
            "pass --strict-seed to refuse it" % record
        ],
        "result": "RESULT: WARN (no seed record at %s)" % record,
    }


def finding_unmeasurable(detail: str) -> dict:
    row = (
        "  WARN  seed_drift — %s — the seed could not be measured; pass --strict-seed to refuse it"
        % detail
    )
    return {
        "status": "WARN",
        "exit_code": EXIT_UNMEASURABLE,
        "reason": detail,
        "rows": [row],
        "result": "RESULT: WARN (%s)" % detail,
    }


def finding_corrupt(record: str, strict: bool) -> dict:
    row = (
        "  WARN  seed_drift — the seed record at %s does not parse — nothing could be measured"
        % record
    )
    return {
        "status": "WARN",
        "exit_code": EXIT_UNMEASURABLE,
        "reason": "the seed record at %s does not parse" % record,
        "rows": [row],
        "result": "RESULT: WARN (the seed record at %s does not parse)" % record,
    }


# --------------------------------------------------------------- probe modes


def probe_local(home_arg: str, timeout: int, seed_script: str, strict: bool) -> dict:
    """Measure a local seed directory. No bunker, no network."""
    home = os.path.expanduser(home_arg)
    record = os.path.join(home, RECORD_REL)
    out = {
        "mode": "local",
        "agent": "",
        "server": "",
        "home": home,
        "record": record,
        "record_present": None,
        "file_count": None,
        "drifted": [],
        "absent": [],
        "error": "",
    }

    if not os.path.isdir(home):
        out["error"] = "%s is not a directory" % home
        verdict = finding_unmeasurable(out["error"])
    elif not os.path.isfile(record):
        out["record_present"] = False
        verdict = finding_absent(record, strict)
    else:
        out["record_present"] = True
        try:
            with open(record, encoding="utf-8") as fh:
                json.load(fh)
        except (OSError, ValueError) as exc:
            verdict = finding_corrupt(record, strict)
            out["error"] = str(exc)[:200]
        else:
            rc, text, err = run(
                [
                    sys.executable,
                    "-B",
                    seed_script,
                    "check",
                    "--record",
                    record,
                    "--home",
                    home,
                ],
                timeout,
            )
            lines = (text or "").splitlines() + (err or "").splitlines()
            count, drifted, absent = rows_from_check(lines)
            out["drifted"] = drifted
            out["absent"] = absent
            out["file_count"] = count
            if rc == 0 and count is not None:
                verdict = finding_ok(record, count)
            elif rc == 1 and (drifted or absent):
                verdict = finding_drift(record, count, drifted, absent)
            else:
                out["error"] = (
                    (err or text).strip().splitlines()[0][:200]
                    if (err or text).strip()
                    else "exit %d" % rc
                )
                verdict = finding_unmeasurable(
                    "node_seed.py check printed no verdict (exit %d)" % rc
                )
    out.update(verdict)
    return out


def probe_bunker(
    agent: str,
    server: str,
    timeout: int,
    seed_script: str,
    seed_source: str,
    strict: bool,
) -> dict:
    """Measure a node's seed in ONE bunker exec round trip."""
    out = {
        "mode": "bunker",
        "agent": agent,
        "server": server,
        "home": "",
        "record": "$HOME/" + RECORD_REL,
        "record_present": None,
        "file_count": None,
        "drifted": [],
        "absent": [],
        "error": "",
    }
    if not os.path.isfile(seed_script):
        out["error"] = "%s is missing — the check could not be staged" % seed_script
        out.update(finding_unmeasurable(out["error"]))
        return out

    script = remote_script(seed_source)
    rc, text, err = run(
        [BUNKER_BIN, "--server", server, "exec", agent, "--", "sh", "-lc", script],
        timeout,
    )
    if rc != 0:
        first = (err or text).strip().splitlines()
        first = first[0][:200] if first else "exit %d" % rc
        out["error"] = "bunker exec failed: %s" % first
        out.update(finding_unmeasurable(out["error"]))
        return out

    data = parse_remote(text)
    home = data.get("HOME", "")
    out["home"] = home
    record = os.path.join(home, RECORD_REL) if home else "$HOME/" + RECORD_REL
    out["record"] = record
    if not home:
        first = (text or "").strip().splitlines()
        first = first[0][:160] if first else "(empty stream)"
        out["error"] = "bunker exec returned no HOME (first line: %s)" % first
        out.update(finding_unmeasurable(out["error"]))
        return out

    if data.get("RECORD") == "0":
        out["record_present"] = False
        out.update(finding_absent(record, strict))
        return out
    if data.get("RECORD") == "2":
        out["record_present"] = True
        out["error"] = "the seed record at %s does not parse" % record
        out.update(finding_corrupt(record, strict))
        return out
    if data.get("RECORD") != "1":
        out["error"] = (
            "the node's answer carried no RECORD verdict (first line: %s)"
            % (
                (text or "").strip().splitlines()[0][:160]
                if (text or "").strip()
                else "(empty stream)"
            )
        )
        out.update(finding_unmeasurable(out["error"]))
        return out

    out["record_present"] = True
    try:
        seed_rc = int(data.get("SEED_RC", ""))
    except ValueError:
        out["error"] = "the node returned no SEED_RC verdict — the exec stream was cut"
        out.update(finding_unmeasurable(out["error"]))
        return out

    count, drifted, absent = rows_from_check(data["seed_rows"])
    out["drifted"] = drifted
    out["absent"] = absent
    out["file_count"] = count
    if seed_rc == 0 and count is not None:
        verdict = finding_ok(record, count)
    elif seed_rc == 1 and (drifted or absent):
        verdict = finding_drift(record, count, drifted, absent)
    else:
        head = [line for line in data["seed_rows"] if line.strip()]
        out["error"] = (
            head[0][:200]
            if head
            else "node_seed.py check exited %d with no output" % seed_rc
        )
        verdict = finding_unmeasurable(
            "node_seed.py check on the node gave no usable verdict (exit %d)" % seed_rc
        )
    out.update(verdict)
    return out


# -------------------------------------------------------------------- output


def header(d: dict) -> str:
    if d["mode"] == "bunker":
        return "node-seed-drift — agent %s via %s (home %s)" % (
            d["agent"],
            d["server"],
            d["home"] or "(unresolved)",
        )
    return "node-seed-drift — home %s" % d["home"]


def as_json(d: dict) -> str:
    payload = {k: v for k, v in d.items() if k != "rows"}
    payload["rows"] = [
        {"status": status, "value": value}
        for status, value in (
            re.match(r"^  (PASS|FAIL|WARN)  seed_drift — (.*)$", row).groups()
            for row in d["rows"]
        )
    ]
    return json.dumps(payload, indent=2, sort_keys=True)


def main(argv: Optional[list] = None) -> int:
    here = os.path.dirname(os.path.realpath(__file__))
    seed_script = os.path.join(here, SEED_SIBLING_NAME)

    ap = argparse.ArgumentParser(
        description="prove a node's seeded prompts and skills match the digests the seed recorded"
    )
    ap.add_argument("--agent", metavar="ID", help="bunker agent id (bunker mode)")
    ap.add_argument("--server", metavar="NAME", help="bunker server name (bunker mode)")
    ap.add_argument(
        "--home",
        metavar="DIR",
        help="a local seed directory (local mode, no bunker, no network)",
    )
    ap.add_argument(
        "--strict-seed",
        action="store_true",
        help="an unmeasurable or absent seed record is a FAIL, not a WARN",
    )
    ap.add_argument(
        "--timeout",
        type=int,
        default=180,
        help="exec timeout in seconds; the bunker exec stream dies at 300 (default 180)",
    )
    ap.add_argument(
        "--json",
        action="store_true",
        help="emit one JSON object on stdout (rows go to stderr)",
    )
    opts = ap.parse_args(argv)

    def usage_error(message: str) -> int:
        print(message, file=sys.stderr)
        print("RESULT: FAIL (usage: %s)" % message)
        return EXIT_USAGE

    if opts.timeout < 1:
        return usage_error("--timeout must be >= 1, got %d" % opts.timeout)
    local = bool(opts.home)
    bunker = bool(opts.agent or opts.server)
    if local and bunker:
        return usage_error("--home and --agent/--server are exclusive")
    if not local and not bunker:
        return usage_error(
            "one mode is required: --home DIR or --agent ID --server NAME"
        )
    if bunker and not (opts.agent and opts.server):
        return usage_error("bunker mode needs both --agent ID and --server NAME")

    if local:
        d = probe_local(opts.home, opts.timeout, seed_script, opts.strict_seed)
    else:
        seed_source = ""
        if os.path.isfile(seed_script):
            with open(seed_script, encoding="utf-8") as fh:
                seed_source = fh.read()
        d = probe_bunker(
            opts.agent,
            opts.server,
            opts.timeout,
            seed_script,
            seed_source,
            opts.strict_seed,
        )

    stream = sys.stderr if opts.json else sys.stdout
    print(header(d), file=stream)
    for row in d["rows"]:
        print(row, file=stream)
    print(d["result"], file=stream)
    if opts.json:
        print(as_json(d))
    return d["exit_code"]


if __name__ == "__main__":
    sys.exit(main())
