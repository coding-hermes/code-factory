"""CF-531 / M13: the bunker config generator emits per-bunker chat gateways.

specs/M13-chat-gateways.md is the design authority; the law these arms grade:

  R2   tokens ride by REFERENCE: the config names a token_env, never token bytes. The
       generator refuses any gateways input that carries the token shape anywhere, and
       nothing it writes may match it. The token-shaped literal the refusal arms use is
       assembled from characters at runtime and lives only in a throwaway fixture —
       never in this tree.
  R3   a bunker with no gateways provisions exactly as today: no extra key in the .conf,
       no artifact, byte-identical output.
  R5   the platform key is data, not a schema constant: signal provisions exactly like
       telegram, through the same code path, without bunker-side special-casing.
  AC5  a --check run prints the emitted platform keys.
  leg  verify-node.sh's gateway leg grades a merged node: ~/.hermes/config.yaml parses
       under python3+yaml, zero token-shaped bytes over the node home, and every
       platform's token_env resolves — an unresolved reference is the M13 §5 WARNING
       GATEWAY_TOKEN_REF_UNRESOLVED, never a failure (the lane stays scheduler-only).

The platforms block travels as a sibling <project>.gateways.json beside the .conf: the
provision config grammar is KEY=VALUE and bunker-provision.sh refuses unknown keys
(CF-002 data-not-code law), so the block cannot ride inside the .conf without refusing
every gateway-configured bunker at provision time.

Every arm drives the REAL scripts with throwaway fixtures: a sqlite registry, a JSON
gateways input, a stub bunker transport and a fixture node home. No network, no node,
no credential.
"""

from __future__ import annotations

import json
import re
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GEN = ROOT / "scripts" / "bunker_config_gen.py"
VERIFY = ROOT / "scripts" / "verify-node.sh"
SERVER = "fixture-server"
AGENT = "cf-demo"

# The R2 detector: what a bot-token literal looks like. Used only to prove emitted
# files and verifier logs are free of the shape, and to build the refusal fixture.
TOKEN_RE = re.compile(r"[0-9]{8,10}:[A-Za-z0-9_-]{35}")

# Assembled, never written as a literal: the poison the R2 refusal arm feeds the
# generator and the R2 scan arm plants in a fixture home.
POISON = "1234567890:" + "A" * 35

TELEGRAM_TOKEN_ENV = "CF_M13_FIXTURE_TELEGRAM_TOKEN"
SIGNAL_TOKEN_ENV = "CF_M13_FIXTURE_SIGNAL_TOKEN"

GATEWAYS_TELEGRAM = {
    "platforms": {
        "telegram": {
            "enabled": True,
            "token_env": TELEGRAM_TOKEN_ENV,
            "home_channel": {
                "platform": "telegram",
                "chat_id": "-1000000000000",
                "thread_id": "42",
                "name": "fixture chat",
            },
            "allowed_chats": ["-1000000000000"],
        }
    }
}

GATEWAYS_SIGNAL = {
    "platforms": {
        "signal": {
            "enabled": True,
            "token_env": SIGNAL_TOKEN_ENV,
            "home_channel": {
                "platform": "signal",
                "chat_id": "+15550000000",
                "thread_id": "",
                "name": "signal fixture",
            },
            "allowed_chats": ["+15550000000"],
        }
    }
}

# The merged node config the gateway leg grades — the spec §3 surface plus the
# dashboard block a real provisioned home carries.
CONFIG_YAML = """dashboard:
  basic_auth:
    username: fixture
    password: fixture-value
platforms:
  telegram:
    enabled: true
    token_env: {token_env}
    home_channel:
      platform: telegram
      chat_id: "-1000000000000"
      thread_id: "42"
      name: fixture chat
    allowed_chats:
      - "-1000000000000"
""".format(token_env=TELEGRAM_TOKEN_ENV)

CONFIG_YAML_NO_PLATFORMS = """dashboard:
  basic_auth:
    username: fixture
    password: fixture-value
"""


# --- fixtures --------------------------------------------------------------------


def registry(tmp: Path) -> Path:
    """A one-project scheduler registry: demo -> a real local dir (selftest §46 schema)."""
    repo = tmp / "repo"
    repo.mkdir(exist_ok=True)
    db = tmp / "ok.db"
    con = sqlite3.connect(db)
    con.execute(
        "create table if not exists projects (name text primary key, repo_url text not null, "
        "workdir text not null, enabled integer not null default 1, "
        "namespace_id text, parent text not null default '')"
    )
    con.execute(
        "insert or ignore into projects values (?,?,?,?,?,?)",
        ("demo", "local:" + str(repo), str(repo), 1, "demo", ""),
    )
    con.commit()
    con.close()
    return db


def gen(tmp: Path, outdir: str, *args: str) -> tuple[int, str]:
    """Run the REAL generator against the fixture registry; return (rc, combined output)."""
    home = tmp / "gen-home"
    home.mkdir(exist_ok=True)
    proc = subprocess.run(
        [
            sys.executable,
            "-B",
            str(GEN),
            "--db",
            str(registry(tmp)),
            "--server",
            SERVER,
            "--projects",
            str(tmp / outdir),
            *args,
        ],
        capture_output=True,
        text=True,
        env={
            "PATH": "/usr/bin:/bin",
            "HOME": str(home),
            "PYTHONDONTWRITEBYTECODE": "1",
        },
        timeout=120,
    )
    return proc.returncode, proc.stdout + proc.stderr


def gateways_file(tmp: Path, name: str, doc) -> str:
    path = tmp / name
    if isinstance(doc, str):
        path.write_text(doc)
    else:
        path.write_text(json.dumps(doc))
    return str(path)


# --- verify-node rig -------------------------------------------------------------


BUNKER_STUB = r"""#!/usr/bin/env bash
# fixture transport: exec bodies run HERE against the fixture node home, like the
# harness-node-e2e stub — the only routable address is TEST-NET (never loopback).
set -u
args=("$@")
case "${args[0]:-}" in
  info) exit 0 ;;
  cp) exit 0 ;;
esac
i=0
while [ "$i" -lt "${#args[@]}" ]; do
  case "${args[$i]}" in bash|sh) break ;; esac
  i=$((i + 1))
done
[ "$i" -lt "${#args[@]}" ] || { printf 'stub bunker: no shell in argv\n' >&2; exit 2; }
shell="${args[$i]}"
body="${args[$((i + 2))]:-}"
rest=("${args[@]:$((i + 3))}")
case "$body" in *"hostname -I"*) echo 192.0.2.10; exit 0 ;; esac
exec env HOME="$FIXTURE_NODE" "$shell" -c "$body" "${rest[@]}"
"""

CURL_STUB = r"""#!/usr/bin/env bash
o=""; u=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) o="$2"; shift 2 ;;
    -*) shift ;;
    *) u="$1"; shift ;;
  esac
done
case "$u" in */api/system/stats) c=401 ;; *) c=200 ;; esac
[ -n "$o" ] && [ "$o" != /dev/null ] && printf '%s' '{"status":"ok","auth_required":true}' > "$o"
printf '%s' "$c"
"""


def stage_checkout(tmp: Path, node: Path) -> None:
    """A real checkout level with its origin, so the freshness leg PASSes (§48 pattern)."""
    origin = tmp / "origin.git"
    git = lambda *args: subprocess.run(  # noqa: E731 — tiny local helper
        ["git", *args],
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert git("init", "-q", "-b", "main", "--bare", str(origin)).returncode == 0
    clone = node / "repo"
    assert git("clone", "-q", str(origin), str(clone)).returncode == 0
    assert (
        git(
            "-C",
            str(clone),
            "-c",
            "user.email=fixture@example.invalid",
            "-c",
            "user.name=fixture",
            "commit",
            "-qm",
            "fixture",
            "--allow-empty",
        ).returncode
        == 0
    )
    assert git("-C", str(clone), "push", "-q", "-u", "origin", "main").returncode == 0
    assert git("-C", str(clone), "fetch", "-q", "origin").returncode == 0


def verify_run(
    tmp: Path,
    config_yaml: str | None,
    *,
    home_files: dict | None = None,
    token_env_value: str | None = None,
) -> tuple[int, str]:
    """Run the REAL verifier against a fixture node home; return (rc, combined output).

    The home carries a checkout level with its origin, so the freshness leg is green and
    the seed leg's WARN is the only pre-existing unverified state — the gateway rows are
    the only thing each arm below can move.
    """
    node = tmp / "node"
    (node / ".hermes").mkdir(parents=True, exist_ok=True)
    if config_yaml is not None:
        (node / ".hermes" / "config.yaml").write_text(config_yaml)
    for rel, content in (home_files or {}).items():
        target = node / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)
    stage_checkout(tmp, node)
    bin_dir = tmp / "bin"
    bin_dir.mkdir(exist_ok=True)
    bunker = bin_dir / "bunker"
    bunker.write_text(BUNKER_STUB)
    bunker.chmod(0o755)
    curl = bin_dir / "curl"
    curl.write_text(CURL_STUB)
    curl.chmod(0o755)
    env = {
        "PATH": f"{bin_dir}:/usr/local/bin:/usr/bin:/bin",
        "HOME": str(node),
        "FIXTURE_NODE": str(node),
        "BUNKER_SERVER": SERVER,
        "TMPDIR": str(tmp),
        "PYTHONDONTWRITEBYTECODE": "1",
    }
    if token_env_value is not None:
        env[TELEGRAM_TOKEN_ENV] = token_env_value
    proc = subprocess.run(
        ["/bin/bash", str(VERIFY), "--agent", AGENT, "--server", SERVER],
        capture_output=True,
        text=True,
        env=env,
        timeout=300,
    )
    return proc.returncode, proc.stdout + proc.stderr


# --- generator arms --------------------------------------------------------------


def test_no_gateways_is_byte_identical_today() -> None:
    """R3: no --gateways, no artifact, no extra key, no new row."""
    with tempfile.TemporaryDirectory(prefix="cf531-") as directory:
        tmp = Path(directory)
        rc, out = gen(tmp, "out", "--project", "demo")
        assert rc == 0, out
        conf = tmp / "out" / "demo.conf"
        assert conf.is_file(), out
        keys = [
            line
            for line in conf.read_text().splitlines()
            if line and not line.startswith("#")
        ]
        assert len(keys) == 11, keys
        assert not (tmp / "out" / "demo.gateways.json").exists(), (
            "a gateway-less run wrote a gateways artifact (R3)"
        )
        assert "gateways" not in out, out


def test_telegram_block_emitted_and_token_free() -> None:
    """AC1/R2: the input section emits a sorted, token-free sibling artifact."""
    with tempfile.TemporaryDirectory(prefix="cf531-") as directory:
        tmp = Path(directory)
        gw = gateways_file(tmp, "gateways.json", GATEWAYS_TELEGRAM)
        rc_plain, _ = gen(tmp, "out-plain", "--project", "demo")
        rc, out = gen(tmp, "out", "--project", "demo", "--gateways", gw)
        assert rc == 0, out
        # the .conf itself is byte-identical: the block cannot ride inside it without
        # the provisioner refusing the whole config (unknown key), so it merges as a
        # sibling artifact and R3's "no gateways, no new keys" holds both ways.
        assert (tmp / "out-plain" / "demo.conf").read_bytes() == (
            tmp / "out" / "demo.conf"
        ).read_bytes(), "the generated .conf grew keys the provisioner would refuse"
        artifact = tmp / "out" / "demo.gateways.json"
        assert artifact.is_file(), out
        block = json.loads(artifact.read_text())
        platform = block["platforms"]["telegram"]
        assert platform["enabled"] is True
        assert platform["token_env"] == TELEGRAM_TOKEN_ENV
        channel = platform["home_channel"]
        assert channel["platform"] == "telegram"
        assert channel["chat_id"] == "-1000000000000"
        assert channel["thread_id"] == "42"
        assert channel["name"] == "fixture chat"
        assert platform["allowed_chats"] == ["-1000000000000"]
        assert block["gateways"]["loop_watchdog"] == {}
        # R2: nothing the generator wrote matches the token shape.
        for path in (tmp / "out" / "demo.conf", artifact):
            assert not TOKEN_RE.search(path.read_text()), path
        assert not TOKEN_RE.search(out), "the generator printed token-shaped bytes"


def test_signal_provisions_like_telegram() -> None:
    """R5/AC3: a signal-configured bunker generates without error, platform-agnostically."""
    with tempfile.TemporaryDirectory(prefix="cf531-") as directory:
        tmp = Path(directory)
        gw = gateways_file(tmp, "gateways.json", GATEWAYS_SIGNAL)
        rc, out = gen(tmp, "out", "--project", "demo", "--gateways", gw)
        assert rc == 0, f"signal refused — R5 wants any platform key accepted: {out}"
        block = json.loads((tmp / "out" / "demo.gateways.json").read_text())
        assert "signal" in block["platforms"], block
        assert block["platforms"]["signal"]["home_channel"]["platform"] == "signal"
        assert not TOKEN_RE.search((tmp / "out" / "demo.gateways.json").read_text())


def test_token_bytes_in_input_are_refused_and_nothing_is_written() -> None:
    """R2 at the boundary: token bytes anywhere in the input refuse the whole run."""
    with tempfile.TemporaryDirectory(prefix="cf531-") as directory:
        tmp = Path(directory)
        poisoned = json.loads(json.dumps(GATEWAYS_TELEGRAM))
        poisoned["platforms"]["telegram"]["note"] = POISON
        gw = gateways_file(tmp, "gateways.json", poisoned)
        rc, out = gen(tmp, "out", "--project", "demo", "--gateways", gw)
        assert rc == 2, f"token-shaped input was accepted (rc {rc}): {out}"
        assert "R2" in out and "token bytes" in out, out
        assert not (tmp / "out" / "demo.conf").exists(), "a refused run wrote a config"
        assert not (tmp / "out" / "demo.gateways.json").exists()


def test_malformed_inputs_are_refused_by_name() -> None:
    """Refuse, never guess: each broken shape names its defect and writes nothing."""
    cases = {
        "not-json": "{",
        "no-platforms": {"gateways": {}},
        "empty-platforms": {"platforms": {}},
        "bad-platform-key": {
            "platforms": {"Telegram": GATEWAYS_TELEGRAM["platforms"]["telegram"]}
        },
        "lowercase-token-env": {
            "platforms": {
                "telegram": {
                    **GATEWAYS_TELEGRAM["platforms"]["telegram"],
                    "token_env": "cf_bot_token",
                },
            }
        },
        "channel-platform-mismatch": {
            "platforms": {
                "telegram": {
                    **GATEWAYS_TELEGRAM["platforms"]["telegram"],
                    "home_channel": {
                        **GATEWAYS_TELEGRAM["platforms"]["telegram"]["home_channel"],
                        "platform": "signal",
                    },
                },
            }
        },
        "empty-chat-id": {
            "platforms": {
                "telegram": {
                    **GATEWAYS_TELEGRAM["platforms"]["telegram"],
                    "home_channel": {
                        **GATEWAYS_TELEGRAM["platforms"]["telegram"]["home_channel"],
                        "chat_id": "",
                    },
                },
            }
        },
        "empty-allowed-chats": {
            "platforms": {
                "telegram": {
                    **GATEWAYS_TELEGRAM["platforms"]["telegram"],
                    "allowed_chats": [],
                },
            }
        },
        "enabled-not-bool": {
            "platforms": {
                "telegram": {
                    **GATEWAYS_TELEGRAM["platforms"]["telegram"],
                    "enabled": "yes",
                },
            }
        },
    }
    for name, doc in cases.items():
        with tempfile.TemporaryDirectory(prefix="cf531-") as directory:
            tmp = Path(directory)
            gw = gateways_file(tmp, "gateways.json", doc)
            rc, out = gen(tmp, "out", "--project", "demo", "--gateways", gw)
            assert rc == 2, f"{name}: rc {rc} — {out}"
            assert "  FAIL  gateways" in out, f"{name}: no named refusal — {out}"
            assert not (tmp / "out" / "demo.conf").exists(), f"{name}: wrote a config"
            assert not (tmp / "out" / "demo.gateways.json").exists(), (
                f"{name}: wrote an artifact"
            )


def test_check_prints_the_emitted_platform_keys() -> None:
    """AC5: --check exits 0 on a matching run and prints the platform keys."""
    with tempfile.TemporaryDirectory(prefix="cf531-") as directory:
        tmp = Path(directory)
        gw = gateways_file(tmp, "gateways.json", GATEWAYS_TELEGRAM)
        rc, out = gen(tmp, "out", "--project", "demo", "--gateways", gw)
        assert rc == 0, out
        rc, out = gen(tmp, "out", "--project", "demo", "--gateways", gw, "--check")
        assert rc == 0, f"--check went red on a fresh write: {out}"
        rows = [
            line for line in out.splitlines() if line.startswith("  PASS  gateways")
        ]
        assert rows, f"no gateways row on --check: {out}"
        assert "platforms: telegram" in rows[0], rows[0]
        # drift arm: mutate the artifact and --check must name it
        artifact = tmp / "out" / "demo.gateways.json"
        artifact.write_text(json.dumps({"platforms": {}}))
        rc, out = gen(tmp, "out", "--project", "demo", "--gateways", gw, "--check")
        assert rc == 1, f"--check passed on a mutated artifact (rc {rc}): {out}"
        assert "  FAIL  gateways" in out, out


def test_write_mode_is_idempotent() -> None:
    """A second identical run changes nothing and says so, for both artifacts."""
    with tempfile.TemporaryDirectory(prefix="cf531-") as directory:
        tmp = Path(directory)
        gw = gateways_file(tmp, "gateways.json", GATEWAYS_TELEGRAM)
        rc, _ = gen(tmp, "out", "--project", "demo", "--gateways", gw)
        assert rc == 0
        artifact = tmp / "out" / "demo.gateways.json"
        before = artifact.read_bytes()
        rc, out = gen(tmp, "out", "--project", "demo", "--gateways", gw)
        assert rc == 0, out
        assert artifact.read_bytes() == before, "a rerun rewrote the artifact"
        unchanged = [
            line for line in out.splitlines() if line.startswith("  PASS  unchanged")
        ]
        assert any("demo.gateways.json" in line for line in unchanged), out


def test_orphan_artifact_without_input_warns() -> None:
    """A gateways artifact with no --gateways input this run is named, not ignored."""
    with tempfile.TemporaryDirectory(prefix="cf531-") as directory:
        tmp = Path(directory)
        gw = gateways_file(tmp, "gateways.json", GATEWAYS_TELEGRAM)
        rc, _ = gen(tmp, "out", "--project", "demo", "--gateways", gw)
        assert rc == 0
        rc, out = gen(tmp, "out", "--project", "demo")
        assert rc == 0, out
        assert "  WARN  gateways" in out, f"orphan artifact went unnamed: {out}"


# --- verify-node gateway leg arms -------------------------------------------------


def rows(output: str, verdict: str, label: str) -> list[str]:
    prefix = f"  {verdict}  {label} — "
    return [line for line in output.splitlines() if line.startswith(prefix)]


def test_gateway_leg_green_on_a_configured_node() -> None:
    """A merged platforms block: parses, zero token bytes, token_env resolves."""
    with tempfile.TemporaryDirectory(prefix="cf531-") as directory:
        tmp = Path(directory)
        rc, out = verify_run(
            tmp, CONFIG_YAML, token_env_value="fixture-reference-not-a-token"
        )
        assert rc in (0, 3), (
            f"expected green-or-unverified (other legs), got rc {rc}:\n{out}"
        )
        assert "  FAIL  " not in out, out
        config_rows = rows(out, "PASS", "gateway_config")
        assert config_rows and "telegram" in config_rows[0], out
        token_rows = rows(out, "PASS", "gateway_tokens")
        assert token_rows and "0 token-shaped" in token_rows[0], out
        ref_rows = rows(out, "PASS", "gateway_token_env")
        assert ref_rows and TELEGRAM_TOKEN_ENV in ref_rows[0], out
        assert not TOKEN_RE.search(out), "the verifier log carries token-shaped bytes"


def test_gateway_leg_fails_on_token_bytes_in_the_home() -> None:
    """R2: a poisoned home is a FAIL that names the path, never the bytes."""
    with tempfile.TemporaryDirectory(prefix="cf531-") as directory:
        tmp = Path(directory)
        rc, out = verify_run(
            tmp,
            CONFIG_YAML,
            home_files={"leak-fixture.txt": POISON + "\n"},
            token_env_value="fixture-reference-not-a-token",
        )
        assert rc == 1, f"a poisoned home verified green (rc {rc}):\n{out}"
        fails = rows(out, "FAIL", "gateway_tokens")
        assert fails, out
        assert "leak-fixture.txt" in fails[0], fails[0]
        assert POISON not in out, "the verifier printed the bytes it forbids"


def test_gateway_leg_fails_on_an_unparseable_config() -> None:
    with tempfile.TemporaryDirectory(prefix="cf531-") as directory:
        tmp = Path(directory)
        rc, out = verify_run(tmp, "platforms: [", token_env_value="x")
        assert rc == 1, f"an unparseable config verified green (rc {rc}):\n{out}"
        fails = rows(out, "FAIL", "gateway_config")
        assert fails and "does not parse" in fails[0], out


def test_gateway_leg_warns_on_unresolved_token_env() -> None:
    """M13 §5: unresolved token_env is GATEWAY_TOKEN_REF_UNRESOLVED — warn, not fail."""
    with tempfile.TemporaryDirectory(prefix="cf531-") as directory:
        tmp = Path(directory)
        rc, out = verify_run(tmp, CONFIG_YAML, token_env_value=None)
        assert rc != 1, (
            f"an unresolved reference failed the run (M13 §5 says warn):\n{out}"
        )
        warns = rows(out, "WARN", "gateway_token_env")
        assert warns, out
        assert "GATEWAY_TOKEN_REF_UNRESOLVED" in warns[0], warns[0]
        assert not rows(out, "FAIL", "gateway_config"), out
        assert not rows(out, "FAIL", "gateway_tokens"), out


def test_gateway_leg_is_silent_without_platforms() -> None:
    """R3: no platforms block — a note, no rows, no token scan, nothing unverified."""
    with tempfile.TemporaryDirectory(prefix="cf531-") as directory:
        tmp = Path(directory)
        rc, out = verify_run(tmp, CONFIG_YAML_NO_PLATFORMS)
        assert not rows(out, "FAIL", "gateway_config"), out
        assert not rows(out, "WARN", "gateway_config"), out
        assert not rows(out, "FAIL", "gateway_tokens"), out
        assert not rows(out, "PASS", "gateway_tokens"), out
        assert not rows(out, "WARN", "gateway_token_env"), out
        notes = [line for line in out.splitlines() if "gateway_config" in line]
        assert notes and "no platforms block" in notes[0], out
        unverified = [
            line for line in out.splitlines() if line.startswith("VERIFY: UNVERIFIED")
        ]
        for line in unverified:
            assert "gateway" not in line, f"the R3 note leaked into UNVERIFIED: {line}"


def test_gateway_leg_silent_without_a_config() -> None:
    """Nothing provisioned yet: the leg notes and measures nothing."""
    with tempfile.TemporaryDirectory(prefix="cf531-") as directory:
        tmp = Path(directory)
        rc, out = verify_run(tmp, None)
        assert not rows(out, "FAIL", "gateway_config"), out
        assert not rows(out, "WARN", "gateway_config"), out
        notes = [line for line in out.splitlines() if "gateway_config" in line]
        assert notes and "no ~/.hermes/config.yaml" in notes[0], out


# --- runner (house style: no pytest required) --------------------------------------


def main() -> int:
    import traceback

    tests = [
        (name, fn)
        for name, fn in globals().items()
        if name.startswith("test_") and callable(fn)
    ]
    failures = 0
    for name, fn in tests:
        try:
            fn()
        except Exception:  # noqa: BLE001 — report every failed arm
            failures += 1
            print(f"FAIL  {name}")
            traceback.print_exc()
        else:
            print(f"PASS  {name}")
    print(f"{len(tests) - failures}/{len(tests)} passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
