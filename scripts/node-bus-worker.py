#!/usr/bin/env python3
"""node-bus-worker.py — the node side of the crier bus: inbox in, harness, result out, ack.

  node-bus-worker.py --check                 # measure, print one row per measurement, write nothing
  node-bus-worker.py --once [--dry-run]      # one poll -> verify -> run -> reply -> ack
  node-bus-worker.py --loop N [--interval S] # N polls, stopping early only on a refusal

Runs ON the node. Everything it writes lives under $HOME: the clone is the only workdir, the
harness runs with cwd inside it, and no token or signature is ever printed.

The bus verifies TWO credentials on every agent-scoped read: the shared bearer token
(`Authorization: Bearer ...`) and a per-agent ed25519 signature. Neither is optional on a
server with `CR_REQUIRE_AGENT_SIG` on (the default). The signature is, exactly as crier
verifies it (internal/registry/agentsig.go, `verifyAgentSignatureForKey`):

  X-Agent-ID          the agent claiming to act — must equal the agent in the URL
  X-Agent-Ts          unix seconds, must be within +/-30s of server time
  X-Agent-Sig         hex(ed25519_sign(transcript, agent private key))
  X-Agent-Body-SHA256 optional body binding: the lowercase hex sha256 of the exact bytes sent

  transcript = "<METHOD>\\n<path>\\n<unix-seconds>"                    (no body binding)
  transcript = "<METHOD>\\n<path>\\n<unix-seconds>\\nsha256:<hex>"      (body binding)

`<path>` is the raw URL path with the query string EXCLUDED, and the signature is bound to
method and path, so a signature minted for the retrieve cannot be replayed on the ack. The
private key is a PKCS#8 PEM ed25519 key (`openssl genpkey -algorithm ED25519`); this script
reads it, signs with a stdlib-only RFC 8032 implementation, and never prints it. It will not
create a key: a node without key material is a node that is not registered, and a fabricated
key would authenticate nothing.

Refusals (named, non-zero exit, no side effects when possible):
  identity     $HOME/.node/node.json (or the bus identity) is unreadable or not a JSON object
  project      the two identity files disagree on the project
  signing_key  the private key is absent, unreadable, not PKCS#8 PEM, or not ed25519
  bus_bearer   no bearer token (file or CRIER_AUTH_TOKEN) to send with the signature
  bus_health   the bus does not answer /health (000) from this node
  brief_digest a dispatch's brief.digest does not cover every field this node executes (text,
               gate, repo, ref, workdir, vars), or a gate arrives with no digest / a text-only
               legacy digest — refused, not warned; an unbound gate.cmd is never run
  text_b64     a dispatch's `text_b64` does not decode to UTF-8 text — refused, no fallback
  brief_project a dispatch names a project other than this node's
  brief_workdir a dispatch names a workdir that is not inside this node's clone

The RESULT leg, in one line: a dispatch is executed, and the result envelope is POSTed into
`reply_to`'s inbox BEFORE the dispatch is acked anywhere. The envelope carries the scheduler's
verdict field (`ok`), the correlation identity (`corr_id`, plus `in_reply_to` = the relay message
id the dispatch arrived under) and the node's own words in `reply_b64`; `specs/ENVELOPE.md`
§Result is the authority. The delivery body carries an `idempotency_key` derived from the dispatch
alone, so a retry after a lost answer is answered with the FIRST accept instead of storing a
second result — and the seen-cache is written at EXECUTION, so a redelivery re-delivers the
recorded result rather than running the work twice.

--check is read-only: it measures and prints, never runs the harness, never posts, never acks,
and its inbox row reads `/agents/<id>/inbox/stats` (a signed read that leases nothing, so a
check cannot hide a waiting dispatch from the worker for the lease window). `--once --dry-run`
does fetch, so its read DOES lease the batch — for 5 seconds, and it acks nothing, so the
messages come back.

Exit codes: 0 = every row PASS, 1 = at least one FAIL (nothing ran / nothing acked for the
refused unit), 2 = the declaration is unusable (bad argument, unparseable identity).

Identity precedence, so one node can be declared in pieces:
  agent    crier.json.agent   -> node.json.agent   -> --agent
  project  node.json.project  -> crier.json.project -> --project
  url      crier.json.url     -> node.json.bus.base -> --crier
  repo     node.json.repo.path -> --workdir
  harness  node.json.harness.cmd -> $HOME/hermes-venv/bin/hermes -z {prompt}

The §5 variable contract (specs/HARNESS-MATRIX.md §5):
  A dispatch may carry `vars` — an object of CF_* names. This worker exports exactly that set into the
  harness child's environment, and NOTHING about it is read from the worker's own environment: every
  CF_* variable present here is scrubbed before the harness starts, so two lanes on one node cannot
  contaminate each other. A name outside §5, or a credential VALUE where a path belongs, is a named
  refusal — never a guess, and never an echo of the value. Every run's result envelope records which
  names were set and their lengths (never a credential value), so two runs are comparable.
"""

import argparse
import base64
import hashlib
import json
import os
import re
import shlex
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# The worker and the hermetic conformance battery share this exact writer.  The import is
# deliberately relative to this script, never to the caller's current directory.
_HARNESS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "harness")
if _HARNESS_DIR not in sys.path:
    sys.path.insert(0, _HARNESS_DIR)
from harness_memory import MemoryRecordError, MemoryWriter  # noqa: E402

DEFAULT_INBOX_LIMIT = 10
DEFAULT_LEASE_SECONDS = 30
DEFAULT_TIMEOUT = 10
DEFAULT_HARNESS_WALL = 1800
SEEN_LIMIT = 200
# `reply_b64` lands in a scheduler tick row, not in a log file: bound it there rather than shipping
# an unbounded harness transcript through the bus.
REPLY_MAX_CHARS = 4000
# The tail of the harness output that rides in `reply_b64` beside the receipt line.
REPLY_TAIL_CHARS = 1500
# crier caps a delivery's `idempotency_key` at 128 characters (docs/openapi.yaml, inboxDeliver); a
# key the relay would refuse is not a retry key, so the key is built to fit.
IDEMPOTENCY_KEY_MAX = 128

# specs/HARNESS-MATRIX.md §5 — the one set a node passes to a harness. Names are stable; the
# directive is the only source, and nothing here is ever read from the worker's own environment.
SECTION5_VARS = (
    "CF_MODEL",
    "CF_PROVIDER",
    "CF_BASE_URL",
    "CF_API_KEY_FILE",
    "CF_WORKDIR",
    "CF_NAMESPACE",
    "CF_RUN_ID",
    "CF_LANE",
    "CF_SKILLS_DIR",
    "CF_HARNESS_OPTS",
    "CF_MAX_TURNS",
    "CF_TIMEOUT_S",
)
SECTION5_REQUIRED = (
    "CF_MODEL",
    "CF_PROVIDER",
    "CF_WORKDIR",
    "CF_NAMESPACE",
    "CF_RUN_ID",
    "CF_LANE",
)
# name -> (low, high, default): the budget bounds the matrix fixes.
SECTION5_INTS = {
    "CF_MAX_TURNS": (1, 1000, 40),
    "CF_TIMEOUT_S": (1, 86400, 1800),
}

EMPTY_SHA256 = hashlib.sha256(b"").hexdigest()

# The digest scheme `brief.digest` carries (CF-275). It exists so the refusal text can NAME what
# was expected instead of printing two opaque hashes, and so a future scheme cannot collide with
# this one: the name is inside the canonical object that is hashed.
BRIEF_DIGEST_SCHEME = "cf-brief-v1"

# The plain members a dispatch may carry instead of `text_b64`, in the order older senders use
# (docs/MASTER-DOC-SCHEMA.md §3c). Read by directive_text().
DIRECTIVE_MEMBERS = ("task", "text", "prompt", "message", "body")


# --------------------------------------------------------------------------------------------
# rows — one line per measurement, house style: "  PASS  <name> — <value>"
# --------------------------------------------------------------------------------------------


def ok(name, value):
    print(f"  PASS  {name} — {value}")


def bad(name, reason):
    print(f"  FAIL  {name} — {reason}")


def warn(name, reason):
    print(f"  WARN  {name} — {reason}")


def note(line):
    print(f"  ..    {line}")


def say(line=""):
    print(line)


# --------------------------------------------------------------------------------------------
# ed25519 (RFC 8032) — stdlib only, so the node needs no crypto package to sign
# --------------------------------------------------------------------------------------------

_P = 2**255 - 19
_Q = 2**252 + 27742317777372353535851937790883648493


def _expmod(base, power, modulus):
    return pow(base, power, modulus)


def _inv(x):
    return pow(x, _P - 2, _P)


_D = -121665 * _inv(121666) % _P
_I = pow(2, (_P - 1) // 4, _P)


def _xrecover(y):
    xx = (y * y - 1) * _inv(_D * y * y + 1)
    x = _expmod(xx, (_P + 3) // 8, _P)
    if (x * x - xx) % _P != 0:
        x = (x * _I) % _P
    if x % 2 != 0:
        x = _P - x
    return x


_BY = 4 * _inv(5) % _P
_BX = _xrecover(_BY)
_B = (_BX % _P, _BY % _P)


def _edwards_add(p, q):
    x1, y1 = p
    x2, y2 = q
    k = _D * x1 * x2 * y1 * y2
    x3 = (x1 * y2 + x2 * y1) * _inv(1 + k)
    y3 = (y1 * y2 + x1 * x2) * _inv(1 - k)
    return (x3 % _P, y3 % _P)


def _scalar_mult(point, scalar):
    result = (0, 1)
    addend = point
    while scalar > 0:
        if scalar & 1:
            result = _edwards_add(result, addend)
        addend = _edwards_add(addend, addend)
        scalar >>= 1
    return result


def _encode_point(point):
    x, y = point
    return (y | ((x & 1) << 255)).to_bytes(32, "little")


def _hash_int(*chunks):
    digest = hashlib.sha512()
    for chunk in chunks:
        digest.update(chunk)
    return int.from_bytes(digest.digest(), "little")


def ed25519_public_key(seed):
    """The 32-byte public key for a 32-byte ed25519 seed."""
    expand = hashlib.sha512(seed).digest()
    scalar = 2**254 + sum(
        2**i * ((expand[i // 8] >> (i % 8)) & 1) for i in range(3, 254)
    )
    return _encode_point(_scalar_mult(_B, scalar))


def ed25519_sign(message, seed):
    """A 64-byte RFC 8032 signature over `message` (deterministic, as the spec requires)."""
    expand = hashlib.sha512(seed).digest()
    prefix = expand[32:64]
    scalar = 2**254 + sum(
        2**i * ((expand[i // 8] >> (i % 8)) & 1) for i in range(3, 254)
    )
    public_key = _encode_point(_scalar_mult(_B, scalar))
    nonce = _hash_int(prefix, message) % _Q
    encoded_r = _encode_point(_scalar_mult(_B, nonce))
    challenge = _hash_int(encoded_r, public_key, message) % _Q
    s = (nonce + challenge * scalar) % _Q
    return encoded_r + s.to_bytes(32, "little")


def _read_tlv(buf, offset):
    if offset + 2 > len(buf):
        raise ValueError("truncated DER")
    tag = buf[offset]
    offset += 1
    length = buf[offset]
    offset += 1
    if length & 0x80:
        count = length & 0x7F
        if count == 0 or offset + count > len(buf):
            raise ValueError("unsupported DER length")
        length = int.from_bytes(buf[offset : offset + count], "big")
        offset += count
    if offset + length > len(buf):
        raise ValueError("truncated DER value")
    return tag, buf[offset : offset + length], offset + length


OID_ED25519 = bytes.fromhex("06032b6570")


def load_seed(path):
    """Read a PKCS#8 PEM ed25519 private key and return its 32-byte seed.

    Raises ValueError with a printable reason; never returns partial material, and the caller
    never logs the bytes. An encrypted PEM is refused by name rather than prompting: a node
    has no operator to type a passphrase.
    """
    if not os.path.exists(path):
        raise FileNotFoundError(path)
    with open(path, "rb") as handle:
        raw = handle.read(65536)
    if b"ENCRYPTED" in raw[:200]:
        raise ValueError(
            "the PEM is passphrase-encrypted; a node cannot answer a prompt"
        )
    match = re.search(rb"-----BEGIN ([A-Z ]+)-----(.*?)-----END \1-----", raw, re.S)
    if not match:
        raise ValueError("not a PEM block")
    label = match.group(1).decode()
    if label not in ("PRIVATE KEY",):
        raise ValueError(f"PEM block is {label!r}, expected 'PRIVATE KEY' (PKCS#8)")
    try:
        der = base64.b64decode(re.sub(rb"\s+", b"", match.group(2)), validate=True)
    except Exception as exc:  # noqa: BLE001 - any decode failure is the same refusal
        raise ValueError(f"PEM body is not base64 ({exc})") from exc
    tag, body, _ = _read_tlv(der, 0)
    if tag != 0x30:
        raise ValueError("PKCS#8 must be a SEQUENCE")
    tag, _version, offset = _read_tlv(body, 0)
    if tag != 0x02:
        raise ValueError("PKCS#8 is missing its version INTEGER")
    tag, algorithm, offset = _read_tlv(body, offset)
    if tag != 0x30 or OID_ED25519 not in algorithm:
        raise ValueError("PKCS#8 algorithm is not ed25519 (OID 1.3.101.112)")
    tag, private, _ = _read_tlv(body, offset)
    if tag != 0x04:
        raise ValueError("PKCS#8 is missing its privateKey OCTET STRING")
    if len(private) == 32:
        return private
    inner_tag, inner, _ = _read_tlv(private, 0)
    if inner_tag == 0x04 and len(inner) == 32:
        return inner
    raise ValueError(
        f"ed25519 privateKey is {len(private)} bytes, expected a 32-byte seed"
    )


# --------------------------------------------------------------------------------------------
# the signed transcript — the ONE canonical string the bus verifies
# --------------------------------------------------------------------------------------------


def transcript(method, path, timestamp, body_digest):
    if not body_digest:
        return f"{method}\n{path}\n{timestamp}".encode()
    return f"{method}\n{path}\n{timestamp}\nsha256:{body_digest}".encode()


class Signer:
    """Holds the seed in memory and mints headers. It never prints or serialises the seed."""

    def __init__(self, agent, seed, bearer=None):
        self.agent = agent
        self._seed = seed
        self._bearer = bearer
        self.public_key_hex = ed25519_public_key(seed).hex()

    def headers(self, method, path, body=None, bind_body=True):
        timestamp = str(int(time.time()))
        headers = {"X-Agent-ID": self.agent, "X-Agent-Ts": timestamp}
        digest = ""
        if body is not None and bind_body:
            digest = hashlib.sha256(body).hexdigest()
            headers["X-Agent-Body-SHA256"] = digest
        signature = ed25519_sign(
            transcript(method, path, timestamp, digest), self._seed
        )
        headers["X-Agent-Sig"] = signature.hex()
        if self._bearer:
            headers["Authorization"] = f"Bearer {self._bearer}"
        if body is not None:
            headers["Content-Type"] = "application/json"
        return headers


# --------------------------------------------------------------------------------------------
# HTTP — GET is read-only; a POST only ever goes to an agent inbox (/inbox or /inbox/ack)
# --------------------------------------------------------------------------------------------


def request(method, url, body=None, headers=None, timeout=DEFAULT_TIMEOUT):
    """Return (status, body bytes). status 0 means the node could not reach the host at all."""
    req = urllib.request.Request(url, data=body, method=method, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as exc:
        try:
            return exc.code, exc.read()
        except Exception:  # noqa: BLE001 - the code is the measurement, not the body
            return exc.code, b""
    except (urllib.error.URLError, OSError) as exc:
        reason = getattr(exc, "reason", exc)
        return 0, str(reason).encode()


def one_line(payload, limit=200):
    text = (
        payload.decode("utf-8", "replace")
        if isinstance(payload, bytes)
        else str(payload)
    )
    return " ".join(text.split())[:limit]


# --------------------------------------------------------------------------------------------
# identity
# --------------------------------------------------------------------------------------------


class Identity:
    def __init__(self, home, args):
        self.home = home
        self.error = ""
        self.node_path = args.identity or os.path.join(home, ".node", "node.json")
        self.bus_path = args.bus_identity or os.path.join(home, ".node", "crier.json")
        self.key_path = args.key or os.path.join(home, ".node", "agent.key")
        self.token_path = args.token_file or os.path.join(
            home, ".node", "auth", "crier.token"
        )
        self.seen_path = os.path.join(home, ".node", "bus-seen.json")
        self.node_doc = self._read(self.node_path, required=False)
        self.bus_doc = self._read(self.bus_path, required=False)
        self.agent = (
            args.agent or self.bus_doc.get("agent") or self.node_doc.get("agent") or ""
        )
        self.project = (
            args.project
            or self.node_doc.get("project")
            or self.bus_doc.get("project")
            or ""
        )
        self.url = (
            args.crier
            or self.bus_doc.get("url")
            or (self.node_doc.get("bus") or {}).get("base")
            or ""
        )
        self.url = self.url.rstrip("/")
        repo = self.node_doc.get("repo") or {}
        self.repo_path = args.workdir or repo.get("path") or ""
        harness = self.node_doc.get("harness") or {}
        self.harness_cmd = args.harness_cmd or harness.get("cmd") or ""
        self.harness_name = harness.get("name") or "hermes"
        self.port = args.gateway_port

    def _read(self, path, required):
        if not os.path.exists(path):
            if required:
                raise FileNotFoundError(path)
            return {}
        try:
            with open(path, encoding="utf-8") as handle:
                doc = json.load(handle)
        except Exception as exc:  # noqa: BLE001 - a refusal that names the reason, not a traceback
            self.error = (
                self.error or f"{path} is not readable JSON ({one_line(str(exc), 120)})"
            )
            return {}
        if not isinstance(doc, dict):
            self.error = self.error or f"{path} is not a JSON object"
            return {}
        return doc

    def identity_files(self):
        return [
            (p, d)
            for p, d in ((self.node_path, self.node_doc), (self.bus_path, self.bus_doc))
            if d
        ]

    def mode_of(self, path):
        return oct(os.stat(path).st_mode & 0o777)

    def bearer(self):
        """(token, source) — a token value only ever leaves this method to become a header."""
        if os.path.exists(self.token_path):
            try:
                with open(self.token_path, encoding="utf-8") as handle:
                    token = handle.read().strip()
            except OSError:
                return "", f"{self.token_path} unreadable"
            if token:
                return (
                    token,
                    f"{self.token_path} (mode {self.mode_of(self.token_path)})",
                )
            return "", f"{self.token_path} is empty"
        env_token = os.environ.get("CRIER_AUTH_TOKEN", "").strip()
        if env_token:
            return env_token, "env CRIER_AUTH_TOKEN ***"
        return "", f"{self.token_path} absent and CRIER_AUTH_TOKEN unset"

    def harness_argv(self, prompt):
        """The harness command, as argv, with {prompt} substituted (never through a shell)."""
        if self.harness_cmd:
            if isinstance(self.harness_cmd, list):
                parts = [str(part) for part in self.harness_cmd]
            else:
                parts = shlex.split(str(self.harness_cmd))
        else:
            venv = os.path.join(self.home, "hermes-venv", "bin", "hermes")
            parts = [venv, "-z", "{prompt}"]
        return [str(part).replace("{prompt}", prompt) for part in parts]


# --------------------------------------------------------------------------------------------
# the §5 variable contract — read from the directive, exported to the harness child, recorded
# --------------------------------------------------------------------------------------------


def secret_shaped(value):
    """True for a credential VALUE (a known key prefix, or a bare opaque token). Never echoed."""
    text = str(value)
    if text.startswith(
        ("sk-", "sk_", "ghp_", "gho_", "AIza", "xoxa-", "xoxb-", "xoxp-")
    ):
        return True
    if "/" in text or " " in text:
        return False
    return len(text) >= 20 and re.fullmatch(r"[A-Za-z0-9_+=.-]+", text) is not None


def directive_vars(dispatch, home):
    """The §5 set a dispatch carries, validated. Returns (values, problems).

    The directive is the ONLY source: this reads `dispatch["vars"]`, or the same object inside
    `dispatch["payload"]`, and nothing else. A problem becomes a named refusal, and no value is
    ever copied into a message — only its name and its length.
    """
    raw = dispatch.get("vars")
    if raw is None and isinstance(dispatch.get("payload"), dict):
        raw = dispatch["payload"].get("vars")
    if raw is None:
        return {}, []
    if not isinstance(raw, dict):
        return {}, ["`vars` is not an object"]

    values, problems = {}, []
    for name, value in raw.items():
        key = str(name)
        if key not in SECTION5_VARS:
            problems.append(f"{key} is not a §5 variable (specs/HARNESS-MATRIX.md §5)")
            continue
        if isinstance(value, bool) or not isinstance(value, (str, int)):
            problems.append(f"{key} is not a string or an integer")
            continue
        values[key] = str(value)

    for key, text in list(values.items()):
        if key in SECTION5_INTS:
            low, high, _default = SECTION5_INTS[key]
            if not text.isdigit() or not low <= int(text) <= high:
                problems.append(f"{key} is not an integer in {low}..{high}: {text!r}")
        elif key == "CF_API_KEY_FILE":
            if secret_shaped(text):
                problems.append(
                    "CF_API_KEY_FILE carries a credential VALUE, not a path "
                    f"({len(text)} chars; the value is not printed)"
                )
            elif "/" not in text:
                problems.append(
                    "CF_API_KEY_FILE is not a path (expected /abs/path or ~/path)"
                )
        elif key == "CF_WORKDIR":
            real = os.path.realpath(os.path.expanduser(text))
            if not os.path.isdir(real):
                problems.append(f"CF_WORKDIR is not an existing directory: {text}")
            elif not inside_clone(real, home):
                problems.append(
                    f"CF_WORKDIR {real} is outside this node's $HOME ({home})"
                )
        elif key == "CF_HARNESS_OPTS":
            if re.search(
                r"sk-|api[_-]?key=|token=|secret=|password=", text, re.IGNORECASE
            ):
                problems.append(
                    "CF_HARNESS_OPTS looks like it carries a credential; it is recorded, so it is public"
                )
            elif not re.fullmatch(
                r"[A-Za-z0-9_.-]+=[^,]+(,[A-Za-z0-9_.-]+=[^,]+)*", text
            ):
                problems.append("CF_HARNESS_OPTS is not a key=value[,key=value] bag")
        elif key == "CF_BASE_URL":
            if not re.match(r"^https?://", text):
                problems.append(f"CF_BASE_URL is not an http(s) URL: {text}")
            elif "@" in text.split("://", 1)[1]:
                problems.append(
                    "CF_BASE_URL carries userinfo; a credential in a URL is a credential as a value"
                )
    return values, problems


def section5_receipt(values):
    """name -> {set, len} for every declared variable: comparable across runs, never a value."""
    return {
        name: (
            {"set": True, "len": len(values[name])}
            if name in values
            else {"set": False, "len": 0}
        )
        for name in SECTION5_VARS
    }


def harness_env(ident, values):
    """The harness child's environment: the directive's set, with every ambient CF_* scrubbed."""
    env = {key: value for key, value in os.environ.items() if not key.startswith("CF_")}
    env["HOME"] = ident.home
    env.update(values)
    return env


def inside_clone(path, clone):
    """True only when `path` resolves to the clone or something below it."""
    if not clone:
        return False
    real_clone = os.path.realpath(clone)
    real_path = os.path.realpath(path)
    return real_path == real_clone or real_path.startswith(real_clone + os.sep)


# --------------------------------------------------------------------------------------------
# --check
# --------------------------------------------------------------------------------------------


def check(ident, args):
    say(f"node-bus-worker --check — agent={ident.agent or '?'} bus={ident.url or '?'}")
    failures = 0

    def failed():
        nonlocal failures
        failures += 1

    # identity
    if ident.error:
        bad("identity", f"{ident.error}; refusing")
        failed()
    elif not ident.node_doc and not ident.bus_doc:
        bad("identity", f"{ident.node_path} and {ident.bus_path} are both absent")
        failed()
    else:
        parts = []
        for path, doc in ident.identity_files():
            parts.append(
                f"{path} mode {ident.mode_of(path)} project={doc.get('project', '?')}"
            )
        if not ident.node_doc:
            bad(
                "identity",
                f"{ident.node_path} absent (the repo/harness declaration); "
                f"{ident.bus_path} is present and supplies project+agent only",
            )
            failed()
        else:
            ok("identity", "; ".join(parts))

    # the two files must not disagree about the project
    if ident.node_doc and ident.bus_doc:
        left = ident.node_doc.get("project")
        right = ident.bus_doc.get("project")
        if left and right and left != right:
            bad(
                "project",
                f"{ident.node_path} says {left!r}, {ident.bus_path} says {right!r}",
            )
            failed()
        else:
            ok("project", f"{ident.project or '?'} (the two identity files agree)")
    elif ident.project:
        ok(
            "project",
            f"{ident.project!r} from {ident.bus_path if ident.bus_doc else ident.node_path} "
            f"(the other identity file is absent)",
        )

    # signing key — presence, mode, and that it is a PKCS#8 ed25519 key
    seed = None
    if not os.path.exists(ident.key_path):
        bad(
            "signing_key",
            f"{ident.key_path} absent — the bus verifies a per-agent ed25519 "
            f"signature; this node holds no key, and a made-up key would "
            f"authenticate nothing",
        )
        failed()
    else:
        mode = os.stat(ident.key_path).st_mode & 0o777
        try:
            seed = load_seed(ident.key_path)
        except (ValueError, OSError) as exc:
            bad("signing_key", f"{ident.key_path} mode {oct(mode)}: {exc}")
            failed()
        else:
            if mode & 0o077:
                bad(
                    "signing_key",
                    f"{ident.key_path} is mode {oct(mode)} — group/other can read a "
                    f"private key; chmod 600",
                )
                failed()
            else:
                ok(
                    "signing_key",
                    f"{ident.key_path} mode {oct(mode)} — PKCS#8 ed25519, "
                    f"public {ed25519_public_key(seed).hex()}",
                )

    # bearer — the other half of the ladder
    token, source = ident.bearer()
    if not token:
        bad("bus_bearer", f"{source} — a signed read still needs the shared bearer")
        failed()
    else:
        ok("bus_bearer", source)

    # bus health
    if not ident.url:
        bad("bus_health", "no bus url (crier.json url / node.json bus.base / --crier)")
        failed()
        health = 0
    else:
        health, _ = request("GET", f"{ident.url}/health", timeout=args.timeout)
        if health == 200:
            ok("bus_health", f"{ident.url}/health -> 200")
        else:
            bad(
                "bus_health",
                f"{ident.url}/health -> {health:03d} (the bus is not answering this node)",
            )
            failed()

    # the inbox row is the one that names the whole ladder
    signer = None
    if seed is not None and token:
        signer = Signer(ident.agent or "?", seed, token)
    inbox_meaning = {
        200: "signed read accepted",
        401: "auth or per-agent signature refused — crier checks the signer BEFORE it looks the "
        "agent up, so 401 is not proof the id is unknown",
        403: "owner mismatch — the signature names an agent other than the target",
        404: "the agent id is genuinely not registered on this bus",
        0: "the bus could not be reached from this node",
    }
    if not ident.agent:
        bad("inbox", "no agent id (crier.json agent / --agent)")
        failed()
    elif signer is None:
        bad("inbox", "unmeasured — no key/bearer pair to sign with")
        failed()
    else:
        # /inbox/stats is the read-only inbox row: same authorize path, and it leases nothing
        # (a --check that leased a message would hide it from the worker for the lease window).
        path = f"/agents/{ident.agent}/inbox/stats"
        status, body = request(
            "GET",
            f"{ident.url}{path}",
            headers=signer.headers("GET", path),
            timeout=args.timeout,
        )
        meaning = inbox_meaning.get(status, f"unexpected status {status}")
        if status == 200:
            try:
                stats = json.loads(body)
            except Exception:  # noqa: BLE001 - the status is the measurement
                stats = {}
            ok(
                "inbox",
                f"GET {path} -> 200 ({meaning}; queue_depth "
                f"{stats.get('queue_depth', '?')}, leased_count "
                f"{stats.get('leased_count', '?')})",
            )
        else:
            bad("inbox", f"GET {path} -> {status:03d} ({meaning})")
            failed()

    # the private key must be the one the bus has on file, or every signature is a 401
    if signer is not None:
        status, body = request(
            "GET",
            f"{ident.url}/agents/{ident.agent}",
            headers={"Authorization": f"Bearer {token}"},
            timeout=args.timeout,
        )
        if status == 200:
            try:
                registered = (json.loads(body) or {}).get("public_key") or ""
            except Exception:  # noqa: BLE001 - an unparsable registry answer is unmeasured
                registered = ""
            if not registered:
                warn(
                    "key_registry",
                    "the bus holds no public key for this agent — signed reads "
                    "cannot verify",
                )
            elif registered.lower() == signer.public_key_hex:
                ok(
                    "key_registry",
                    f"the node's key is the registered cf identity ({registered[:16]}…)",
                )
            else:
                bad(
                    "key_registry",
                    f"the node's public key {signer.public_key_hex[:16]}… is NOT the "
                    f"registered {registered[:16]}… — every signature would 401",
                )
                failed()
        else:
            warn(
                "key_registry",
                f"GET /agents/{ident.agent} -> {status:03d}; key match unmeasured",
            )

    # harness
    argv = ident.harness_argv("{prompt}")
    binary = argv[0]
    if not os.path.exists(binary):
        bad("harness", f"{binary} absent")
        failed()
    elif not os.access(binary, os.X_OK):
        bad("harness", f"{binary} is not executable")
        failed()
    else:
        version = ""
        try:
            completed = subprocess.run(
                [binary, "--version"],
                capture_output=True,
                text=True,
                timeout=args.timeout,
                stdin=subprocess.DEVNULL,
            )
            version = one_line(completed.stdout or completed.stderr, 80)
        except (OSError, subprocess.SubprocessError) as exc:
            version = f"--version failed: {one_line(str(exc), 80)}"
        ok("harness", f"{binary} — {version or 'no version output'}")

    # the §5 set this worker would pass: resolved from the directive, never from this environment
    for name in SECTION5_VARS:
        required = " (required)" if name in SECTION5_REQUIRED else " (optional)"
        note(f"contract:{name} — from the directive's `vars`{required}")
    ambient = sorted(name for name in SECTION5_VARS if os.environ.get(name))
    if ambient:
        bad(
            "vars_ambient",
            f"{', '.join(ambient)} set in this worker's environment — every CF_* is scrubbed "
            f"before the harness runs; the directive is the only source",
        )
        failed()
    else:
        ok(
            "vars_ambient",
            "no CF_* variable is set in this worker's environment, so no lane can inherit another's",
        )
    ok(
        "vars",
        f"{len(SECTION5_VARS)} declared ({len(SECTION5_REQUIRED)} required) and {len(SECTION5_VARS) - len(SECTION5_REQUIRED)} optional "
        f"(specs/HARNESS-MATRIX.md §5); the harness child env is the directive's `vars` and nothing else",
    )

    # gateway
    gateway = f"http://127.0.0.1:{ident.port}/api/status"
    status, _ = request("GET", gateway, timeout=args.timeout)
    if status == 200:
        ok("gateway", f"{gateway} -> 200")
    else:
        bad(
            "gateway",
            f"{gateway} -> {status:03d} (the harness gateway is not serving on this node)",
        )
        failed()

    say("")
    if failures:
        say(f"BUS WORKER: FAIL ({failures})")
        return 1
    say("BUS WORKER: READY")
    return 0


# --------------------------------------------------------------------------------------------
# --once
# --------------------------------------------------------------------------------------------


def load_seen(path):
    try:
        with open(path, encoding="utf-8") as handle:
            doc = json.load(handle)
        return doc if isinstance(doc, dict) else {}
    except Exception:  # noqa: BLE001 - a corrupt cache is not a reason to refuse work
        return {}


def save_seen(path, doc):
    items = list(doc.items())[-SEEN_LIMIT:]
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        json.dump(dict(items), handle, indent=1, sort_keys=True)
        handle.write("\n")
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)


def dispatch_key(doc):
    return str(
        doc.get("idempotency_key") or doc.get("dispatch_id") or doc.get("corr_id") or ""
    )


def delivery_key(dispatch, result):
    """The relay's dedupe key for ONE dispatch's result, stable across every retry.

    crier answers a second delivery carrying the same key for the same agent inside its
    deduplication window (`CR_IDEMPOTENCY_WINDOW_S`, 24h by default) with the FIRST accept — same
    message id, nothing stored (docs/openapi.yaml, inboxDeliver). That is what makes a retry after
    a lost answer a retry and not a second result, so the key is derived from the DISPATCH alone:
    never from the run's timing and never from the attempt count.
    """
    base = dispatch_key(dispatch) or str(result.get("dispatch_id") or "")
    if not base:
        base = str(result.get("corr_id") or "") or "no-id"
    return f"{base}:result"[:IDEMPOTENCY_KEY_MAX]


def result_reply(status, summary, tail=""):
    """`reply_b64`: the text the scheduler records on the tick, base64 of UTF-8.

    It travels base64 for the same reason the directive does — the relay's control-key pre-match
    refuses prose that quotes JSON (`stringified_json`) and a harness report routinely does — and
    the scheduler decodes `reply_b64` first (`dispatchReplyText`), so this is the one field that
    reaches the tick row as the node's own words.
    """
    text = f"node result: {status} — {summary}"
    tail = (tail or "").strip()
    if tail:
        text += "\n" + tail
    return base64.b64encode(text[:REPLY_MAX_CHARS].encode("utf-8")).decode("ascii")


def run_harness(ident, prompt, timeout_s, values=None):
    """Run the harness once. Returns (exit_code, seconds, stdout, stderr, note).

    `values` is the §5 set from the directive. It is the only source: harness_env() strips every
    CF_* variable this worker's own environment carries, so a lane cannot inherit another lane's
    model, key or endpoint.
    """
    argv = ident.harness_argv(prompt)
    workdir = ident.repo_path or ident.home
    started = time.time()
    env = harness_env(ident, values or {})
    try:
        completed = subprocess.run(
            argv,
            cwd=workdir,
            capture_output=True,
            text=True,
            timeout=timeout_s,
            stdin=subprocess.DEVNULL,
            env=env,
        )
    except subprocess.TimeoutExpired:
        return None, time.time() - started, "", "", f"wall limit {timeout_s}s exceeded"
    except OSError as exc:
        return (
            None,
            time.time() - started,
            "",
            "",
            f"could not start the harness: {exc}",
        )
    return (
        completed.returncode,
        time.time() - started,
        completed.stdout,
        completed.stderr,
        "",
    )


def git_field(clone, *argv):
    try:
        completed = subprocess.run(
            ["git", "-C", clone, *argv],
            capture_output=True,
            text=True,
            timeout=10,
            stdin=subprocess.DEVNULL,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    return completed.stdout.strip() if completed.returncode == 0 else ""


def run_gate(clone, gate, timeout_s):
    """Run the dispatch's gate command in the clone. Returns (exit_code, seconds, note)."""
    command = gate.get("cmd")
    if not isinstance(command, str) or not command.strip():
        return None, 0.0, "gate has no cmd string"
    budget = gate.get("timeout_s") or timeout_s
    started = time.time()
    try:
        completed = subprocess.run(
            ["/bin/sh", "-lc", command],
            cwd=clone,
            capture_output=True,
            text=True,
            timeout=budget,
            stdin=subprocess.DEVNULL,
        )
    except (subprocess.TimeoutExpired, OSError) as exc:
        return None, time.time() - started, f"gate could not run: {exc}"
    return completed.returncode, time.time() - started, ""


def refusal(ident, dispatch, reason, detail, in_reply_to=""):
    """Build a refusal result for a dispatch this node will not execute."""
    summary = f"refused by {reason}: {detail}"
    return {
        "env_version": 1,
        "dispatch_id": str(dispatch.get("dispatch_id") or ""),
        "corr_id": str(dispatch.get("corr_id") or ""),
        # The scheduler's PRIMARY correlation key: the relay message id this dispatch arrived
        # under. corr_id is the join key the scheduler mints; both are echoed verbatim.
        "in_reply_to": str(in_reply_to or ""),
        "status": "refused",
        # `ok` is the SCHEDULER'S verdict field, not a restatement of this envelope's status:
        # dispatchReplyVerdict() reads `ok` and treats its ABSENCE as success, so a refusal that
        # only said status=refused would close the tick as completed (specs/ENVELOPE.md
        # §Correlation and idempotency).
        "ok": False,
        "error": summary,
        "reply_b64": result_reply("refused", summary),
        "host_identity": socket.gethostname(),
        "harness": {"name": ident.harness_name},
        "exit_codes": [],
        "branch": git_field(ident.repo_path, "rev-parse", "--abbrev-ref", "HEAD"),
        "commit": git_field(ident.repo_path, "rev-parse", "HEAD"),
        "artifacts": [],
        "wall_s": 0.0,
        "finished_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "refused_by": reason,
        "refusal": detail,
    }


def _memory_values(dispatch, ident, stdout, commit, outcome):
    """Build I3 provenance from directive data and measured harness output.

    The directive is authoritative for requested model/provider/namespace/run/lane.  A served
    model must be emitted by the harness; the worker never promotes the request to served.
    """
    values, problems = directive_vars(dispatch, ident.home)
    required = {
        "CF_NAMESPACE": "namespace",
        "CF_RUN_ID": "run_id",
        "CF_LANE": "lane",
        "CF_MODEL": "model_requested",
    }
    for key, field in required.items():
        if not values.get(key):
            problems.append(f"{field} is unavailable from the directive")
    provider_binding = str(dispatch.get("provider_binding") or "")
    if not provider_binding:
        problems.append("provider_binding is unavailable from the directive")
    served = ""
    version = str(dispatch.get("harness_version") or "")
    for line in (stdout or "").splitlines():
        if line.startswith("model_served="):
            served = line.partition("=")[2].strip()
        elif line.startswith("harness_version="):
            version = line.partition("=")[2].strip()
    if not served:
        problems.append("model_served was not emitted by the harness")
    if not version:
        problems.append("harness_version was not supplied by the directive or harness")
    tick = str(dispatch.get("tick") or "")
    if not tick:
        problems.append("tick is unavailable from the dispatch")
    commit = str(commit or "")
    if not commit:
        problems.append("commit could not be measured from the clone")
    record = {
        "namespace": values.get("CF_NAMESPACE", ""),
        "run_id": values.get("CF_RUN_ID", ""),
        "lane": values.get("CF_LANE", ""),
        "harness": ident.harness_name,
        "harness_version": version,
        "model_requested": values.get("CF_MODEL", ""),
        "model_served": served,
        "provider_binding": provider_binding,
        "commit": commit,
        "tick": tick,
    }
    return record, problems, outcome


def export_memory(dispatch, ident, stdout, commit, outcome):
    """Write a local evidence artifact through the canonical I3 writer.

    This is intentionally not a DuckBrain transport: the path is a node-local artifact and the
    result says so.  Missing provenance is unsupported/refused, never filled from host state.
    """
    record, problems, outcome = _memory_values(dispatch, ident, stdout, commit, outcome)
    if problems:
        return {"status": "unsupported", "reason": "; ".join(problems)}, False
    backend = os.path.join(ident.home, ".node", "harness-memory", f"{record['run_id']}.json")
    try:
        payload = MemoryWriter(backend).write(record, record["namespace"])
        MemoryWriter(backend).read(record["namespace"])
    except (MemoryRecordError, OSError) as exc:
        return {"status": "unsupported", "reason": f"I3 exporter refused: {exc}"}, False
    return {
        "status": "written",
        "artifact": backend,
        "bytes": len(payload),
        "transport": "local-evidence-artifact; DuckBrain unverified",
        "outcome": outcome,
    }, True


def directive_text(dispatch):
    """(text, reason) — the directive a dispatch carries, and the refusal reason if it has none.

    The scheduler sends the directive as `text_b64` (base64 of the UTF-8 text) because the reply
    relay's control-key guard refuses prose that quotes JSON key names (`specs/ENVELOPE.md`
    §Reserved field names). Decode it FIRST: a `text_b64` that does not decode is a named refusal,
    never a silent fallback to another member — a corrupted dispatch must not run a different
    instruction than the one that was sent.

    The legacy plain members stay supported for older senders, in the order
    `docs/MASTER-DOC-SCHEMA.md` §3c lists: `task`, `text`, `prompt`, `message`, `body`.
    """
    if "text_b64" in dispatch:
        encoded = dispatch["text_b64"]
        if not isinstance(encoded, str):
            return "", "text_b64"
        try:
            decoded = base64.b64decode(encoded, validate=True).decode("utf-8")
        except (ValueError, UnicodeDecodeError):
            return "", "text_b64"
        if not decoded.strip():
            return "", "text_b64"
        return decoded, ""
    for name in DIRECTIVE_MEMBERS:
        candidate = dispatch.get(name)
        if isinstance(candidate, str) and candidate.strip():
            return candidate, ""
    return "", "brief"


def brief_canonical(dispatch, text):
    """The cf-brief-v1 object `brief.digest` is sha256 over — every member that can change what
    this node EXECUTES, and nothing else (`specs/ENVELOPE.md`, CF-275).

    `text` is the decoded directive; `gate` is the command `run_gate()` hands to `/bin/sh -lc` in
    the clone; `workdir`/`repo`/`ref` are the declared identity (the node still executes only
    inside its own clone, but a rewritten member must be detectable); `vars` is the §5 set the
    harness child inherits, so a swapped model, provider or key path is an alteration too.

    Equivalent spellings collapse to one digest, because the digest binds the EFFECT: a gate with
    no `expect_exit` hashes exactly like `expect_exit: 0` (that is the value the node compares
    against), and member order is irrelevant. Without this, two senders that mean the same thing
    would disagree with the node over nothing.
    """
    gate = dispatch.get("gate")
    if isinstance(gate, dict):
        canonical_gate = {
            "cmd": gate.get("cmd"),
            "expect_exit": gate.get("expect_exit", 0),
            # `run_gate()` treats a falsy timeout as "fall back to the wall limit", so a 0 and an
            # absent value are the same effect and must hash the same.
            "timeout_s": gate.get("timeout_s") or None,
        }
    else:
        canonical_gate = None
    declared_vars = dispatch.get("vars")
    return {
        "scheme": BRIEF_DIGEST_SCHEME,
        "text": text,
        "gate": canonical_gate,
        "repo": dispatch.get("repo"),
        "ref": dispatch.get("ref"),
        "workdir": dispatch.get("workdir"),
        "vars": declared_vars if isinstance(declared_vars, dict) else None,
    }


def brief_canonical_bytes(dispatch, text):
    """The exact bytes a sender hashes: canonical JSON, UTF-8, sorted keys, no whitespace.

    A sender in another language reproduces this by emitting the members in sorted order with
    `,`/`:` separators and no insignificant spaces, UTF-8 encoded — non-ASCII is NOT \\u-escaped.
    `--print-brief-digest` prints the value this helper computes, so a sender never has to guess.
    """
    return json.dumps(
        brief_canonical(dispatch, text),
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")


def brief_digest(dispatch, text):
    """The cf-brief-v1 digest: sha256 over `brief_canonical_bytes()`. Sender and node share it."""
    return hashlib.sha256(brief_canonical_bytes(dispatch, text)).hexdigest()


def legacy_brief_digest(text):
    """sha256 over the directive text ALONE — the pre-CF-275 digest, blind to gate.cmd."""
    return hashlib.sha256(text.encode()).hexdigest()


def brief_digest_verdict(dispatch, text):
    """Classify a dispatch's `brief.digest` against what this node would execute.

    Returns (verdict, detail) with verdict one of:
      "bound"   the cf-brief-v1 digest over text+gate+repo+ref+workdir+vars (detail = the digest)
      "legacy"  a text-only digest, accepted ONLY because the brief carries no gate (detail = it)
      "absent"  no digest and no executable field — nothing outside the text could be unbound
      "refuse"  the digest does not cover what the node would run (detail names why)

    A legacy digest is never silently upgraded: beside a `gate` it is refused by name, because
    accepting it would execute an executable the digest does not bind. A `gate` with no digest at
    all is refused for the same reason — an integrity check that covers nothing is not one.
    """
    brief = dispatch.get("brief")
    expected = ""
    if isinstance(brief, dict) and brief.get("digest"):
        expected = str(brief["digest"]).strip().lower()
    gate_present = isinstance(dispatch.get("gate"), dict)
    bound = brief_digest(dispatch, text)
    legacy = legacy_brief_digest(text)
    if not expected:
        if gate_present:
            return "refuse", (
                "the brief carries gate.cmd but no brief.digest — an executable the digest does "
                f"not bind is never run; send the {BRIEF_DIGEST_SCHEME} digest over "
                "text+gate+repo+ref+workdir+vars"
            )
        return "absent", ""
    if expected == bound:
        return "bound", bound
    if expected == legacy:
        if gate_present:
            return "refuse", (
                f"brief.digest is a legacy text-only digest (sha256 of the text alone) but the "
                f"brief carries gate.cmd — the executable is unbound; send the "
                f"{BRIEF_DIGEST_SCHEME} digest over text+gate+repo+ref+workdir+vars instead"
            )
        return "legacy", legacy
    return "refuse", (
        f"brief.digest {expected[:16]}… != {BRIEF_DIGEST_SCHEME} {bound[:16]}… and != legacy "
        f"sha256(text) {legacy[:16]}… — the brief was altered in flight; refused, not run"
    )


def print_brief_digest(path):
    """Sender helper: print the digest a dispatch's `brief.digest` must carry (cf-brief-v1).

    It reads the dispatch exactly as the node will — `text_b64` decoded, a defaulted
    `gate.expect_exit` normalised — so a sender cannot hash a form the node does not apply.
    `-` reads stdin.
    """
    try:
        if path == "-":
            raw = sys.stdin.read()
        else:
            with open(path, "r", encoding="utf-8") as handle:
                raw = handle.read()
        dispatch = json.loads(raw)
    except (OSError, ValueError) as exc:
        print(f"FAIL  brief_digest — {path}: {exc}", file=sys.stderr)
        return 2
    if not isinstance(dispatch, dict):
        print(f"FAIL  brief_digest — {path} is not a JSON object", file=sys.stderr)
        return 2
    text, reason = directive_text(dispatch)
    if reason:
        print(
            f"FAIL  {reason} — the dispatch carries no decodable instruction to digest",
            file=sys.stderr,
        )
        return 2
    print(brief_digest(dispatch, text))
    return 0


def process(dispatch, ident, signer, args, seen, in_reply_to=""):
    """Handle ONE dispatch. Returns (rows_ok, result_dict or None, message_ids_to_ack).

    `in_reply_to` is the relay message id the dispatch arrived under. It is echoed on the result
    so the scheduler can correlate on its PRIMARY key (`payload["in_reply_to"] == receipt
    .MessageID`) as well as on `corr_id` — a result that names neither is residue, and residue
    never completes a tick.
    """
    dispatch_id = str(dispatch.get("dispatch_id") or "")
    corr_id = str(dispatch.get("corr_id") or "")
    key = dispatch_key(dispatch)
    label = f"{dispatch_id or corr_id or 'dispatch'} (corr {corr_id or '?'})"

    if key and key in seen:
        ok(
            "idempotent",
            f"{label} was already executed — returning the recorded result, not re-running",
        )
        return True, seen[key], True

    text, reason = directive_text(dispatch)
    if reason == "text_b64":
        bad(
            "text_b64",
            f"{label} `text_b64` does not decode to UTF-8 text — a corrupted dispatch is "
            f"refused, not run against another member",
        )
        result = refusal(
            ident,
            dispatch,
            "text_b64",
            "dispatch carries a `text_b64` that does not decode to UTF-8 text",
            in_reply_to=in_reply_to,
        )
        return False, result, True
    if not text:
        bad(
            "brief",
            f"{label} carries no `text` — a dispatch without an instruction is a bug, "
            f"refusing rather than inventing one",
        )
        result = refusal(
            ident,
            dispatch,
            "brief",
            "dispatch carries no `text`",
            in_reply_to=in_reply_to,
        )
        return False, result, True

    # The digest is the node's only in-flight integrity check, so it must cover what the node will
    # EXECUTE, not just the prose it will read: `gate.cmd` runs through a shell in the clone, and a
    # text-only digest would let a rewritten gate pass verification and then run (CF-275).
    verdict, detail = brief_digest_verdict(dispatch, text)
    if verdict == "refuse":
        bad("brief_digest", f"{label} {detail}")
        result = refusal(
            ident, dispatch, "brief_digest", detail, in_reply_to=in_reply_to
        )
        return False, result, True
    if verdict == "bound":
        ok(
            "brief_digest",
            f"{label} {BRIEF_DIGEST_SCHEME} {detail[:16]}… binds text+gate+repo+ref+workdir+vars "
            f"({len(text.encode())} bytes of text)",
        )
    elif verdict == "legacy":
        ok(
            "brief_digest",
            f"{label} legacy sha256(text) {detail[:16]}… matches, and the brief carries no gate — "
            f"nothing outside the text executes",
        )
    else:
        ok(
            "brief_digest",
            f"{label} carries no brief.digest and no gate — nothing outside the text could run",
        )

    claimed_project = dispatch.get("project")
    if not claimed_project and isinstance(dispatch.get("payload"), dict):
        claimed_project = dispatch["payload"].get("project")
    if claimed_project and claimed_project != ident.project:
        bad(
            "brief_project",
            f"{label} names project {claimed_project!r}, this node is "
            f"{ident.project!r}; refused",
        )
        result = refusal(
            ident,
            dispatch,
            "brief_project",
            f"dispatch project {claimed_project!r} != node project {ident.project!r}",
            in_reply_to=in_reply_to,
        )
        return False, result, True
    ok("brief_project", f"{label} {ident.project or '?'} is this node's project")

    workdir = dispatch.get("workdir")
    if workdir:
        if not inside_clone(workdir, ident.repo_path):
            bad(
                "brief_workdir",
                f"{label} names workdir {workdir!r}, which is not inside the clone "
                f"{ident.repo_path or '(no clone declared)'}; refused",
            )
            result = refusal(
                ident,
                dispatch,
                "brief_workdir",
                f"workdir {workdir!r} is not inside {ident.repo_path!r}",
                in_reply_to=in_reply_to,
            )
            return False, result, True
        ok("brief_workdir", f"{workdir} is inside the clone")

    # The §5 set comes from the directive and from nowhere else. A problem is a refusal, because a
    # variable that is dropped silently makes two runs incomparable and a lane unreproducible.
    values, var_problems = directive_vars(dispatch, ident.home)
    if var_problems:
        for problem in var_problems:
            bad("vars", f"{label} {problem}")
        result = refusal(
            ident,
            dispatch,
            "vars",
            "; ".join(var_problems)[:500],
            in_reply_to=in_reply_to,
        )
        result["vars"] = section5_receipt(values)
        result["memory"] = {
            "status": "unsupported",
            "reason": "; ".join(var_problems)[:500],
        }
        return False, result, True
    if values:
        ok(
            "vars",
            f"{label} {len(values)} §5 variable(s) from the directive: "
            f"{', '.join(sorted(values))} (nothing read from this worker's environment)",
        )
    else:
        ok(
            "vars",
            f"{label} carries no `vars` object — nothing is exported, and nothing is taken from "
            f"this worker's environment",
        )

    argv = ident.harness_argv(text)
    if args.dry_run:
        say(
            f"  WOULD  harness — {' '.join(argv[:2])} <{len(text)} chars of prompt> in {ident.repo_path or ident.home} "
            f"(wall limit {dispatch_wall(dispatch, args)}s)"
        )
        say(
            "  WOULD  vars — the harness child env carries: "
            + (
                ", ".join(f"{k}({len(v)})" for k, v in sorted(values.items()))
                or "(none)"
            )
            + "; every CF_* in this worker's environment is scrubbed first"
        )
        if isinstance(dispatch.get("gate"), dict):
            say(
                f"  WOULD  gate — sh -lc {dispatch['gate'].get('cmd')!r} in {ident.repo_path}"
            )
        say(
            "  WOULD  reply — POST the result envelope to the scheduler inbox, then ack"
        )
        return True, None, False

    wall = dispatch_wall(dispatch, args)
    code, seconds, stdout, stderr, note = run_harness(ident, text, wall, values)
    if note:
        bad("harness", f"{label} {note}")
        result = refusal(ident, dispatch, "harness", note, in_reply_to=in_reply_to)
        # A harness that could not run is a FAILED result, not a refusal of the brief: the
        # dispatch was accepted and the work did not happen. `ok` stays false so the scheduler
        # closes the tick as FAILED with this reason instead of as a success.
        result["status"] = "failed"
        result["ok"] = False
        result["error"] = note
        result["reply_b64"] = result_reply(
            "failed", f"harness did not complete — {note}"
        )
        result["wall_s"] = round(seconds, 1)
        result["vars"] = section5_receipt(values)
        memory, _ = export_memory(dispatch, ident, stdout, result.get("commit"), "FAIL")
        result["memory"] = memory
        return False, result, True
    ok("harness", f"{label} exit {code} in {seconds:.1f}s (wall limit {wall}s)")

    gate_exit = None
    gate_note = ""
    gate_expect = 0
    gate = dispatch.get("gate")
    if isinstance(gate, dict):
        gate_exit, gate_seconds, gate_note = run_gate(ident.repo_path, gate, wall)
        if gate_note:
            bad("gate", f"{label} {gate_note}")
        else:
            gate_expect = gate.get("expect_exit", 0)
            row = ok if gate_exit == gate_expect else bad
            row(
                "gate",
                f"{label} `{gate['cmd']}` exit {gate_exit} (expected {gate_expect}) in {gate_seconds:.1f}s",
            )

    # The node's own reasons, in the node's own words: this is what the scheduler records as the
    # tick's failure text when `ok` is false, and what an operator reads instead of guessing at an
    # exit code. A gate that could NOT run is one of them: the row above already says FAIL, and a
    # result that called that "completed" would complete a tick on work nobody gated.
    reasons = []
    if code != 0:
        reasons.append(f"harness exit {code}")
    if gate_note:
        reasons.append(f"gate did not run: {gate_note}")
    elif gate_exit is not None and gate_exit != gate_expect:
        reasons.append(
            f"gate `{gate.get('cmd')}` exit {gate_exit}, expected {gate_expect}"
        )
    failed_status = bool(reasons)
    reason_text = "; ".join(reasons)
    status = "failed" if failed_status else "completed"

    branch = git_field(ident.repo_path, "rev-parse", "--abbrev-ref", "HEAD")
    commit = git_field(ident.repo_path, "rev-parse", "HEAD")
    summary = (
        f"dispatch={dispatch_id or '?'} corr={corr_id or '?'} host={socket.gethostname()} "
        f"harness={ident.harness_name} exit={code} "
        f"gate={gate_exit if gate_exit is not None else '-'} "
        f"branch={branch or '-'} commit={(commit or '-')[:12]} wall={seconds:.1f}s"
    )
    if reason_text:
        summary += f" — {reason_text}"
    result = {
        "env_version": 1,
        "dispatch_id": dispatch_id,
        "corr_id": corr_id,
        # The relay message id the dispatch arrived under — the scheduler's PRIMARY correlation
        # key. corr_id is the join key it mints; both travel verbatim so a result that names
        # either one is an answer to this hand-out and nothing else is.
        "in_reply_to": str(in_reply_to or ""),
        "status": status,
        # `ok` is the scheduler's verdict (`dispatchReplyVerdict`). Its ABSENCE reads as success,
        # so a failed run must say so HERE and not only in `status` — a status-only failure would
        # complete the tick as a success (CF-211).
        "ok": not failed_status,
        "reply_b64": result_reply(
            status, summary, one_line(stdout or stderr, REPLY_TAIL_CHARS)
        ),
        "host_identity": socket.gethostname(),
        "harness": {"name": ident.harness_name},
        # The §5 run receipt: name + set/unset + length, never a value, so two runs compare.
        "vars": section5_receipt(values),
        "exit_codes": [code],
        "gate_exit": gate_exit,
        "branch": branch,
        "commit": commit,
        "artifacts": [],
        "wall_s": round(seconds, 1),
        "finished_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    memory, memory_ok = export_memory(dispatch, ident, stdout, commit, "FAIL" if failed_status else "PASS")
    result["memory"] = memory
    if not memory_ok:
        result["memory"]["status"] = "unsupported"
        result["memory"]["reason"] = memory.get("reason", "I3 exporter refused")
    if reason_text:
        # Read by the scheduler's verdict BEFORE `reply_b64`, so the reason is the short one
        # rather than the whole transcript.
        result["error"] = reason_text
    tail = one_line(stderr or stdout, 300)
    if tail:
        say(f"  NOTE  harness output — {tail}")
    return not failed_status, result, True


def dispatch_wall(dispatch, args):
    limits = dispatch.get("limits") or {}
    wall = limits.get("wall_s") if isinstance(limits, dict) else None
    if isinstance(wall, (int, float)) and 0 < wall <= 86400:
        return int(wall)
    return args.harness_wall or DEFAULT_HARNESS_WALL


def deliver(signer, ident, target, result, args, in_reply_to="", idempotency_key=""):
    """POST one result envelope into `target`'s inbox. True only on an accepted delivery.

    The body is the documented deliver shape (crier `docs/openapi.yaml` → `inboxDeliver`): the
    envelope under `payload` (REQUIRED, and a JSON object), `sender` naming the agent that produced
    it, `request_id` as the correlation passthrough, and `idempotency_key` as the retry key.

    A blank target is never posted: `/agents//inbox` addresses nobody, and a result addressed to
    nobody is a silent loss — so that is a named row here instead of a request.
    """
    target = str(target or "").strip()
    if not target:
        bad(
            "reply",
            "the dispatch names no reply_to and --reply-to is empty — a result addressed to "
            "nobody is dropped, so nothing was posted",
        )
        return False
    envelope = dict(result)
    if in_reply_to and not envelope.get("in_reply_to"):
        envelope["in_reply_to"] = str(in_reply_to)
    key = (idempotency_key or delivery_key({}, envelope))[:IDEMPOTENCY_KEY_MAX]
    body = json.dumps(
        {
            "payload": envelope,
            "sender": ident.agent,
            "request_id": str(envelope.get("corr_id") or ""),
            "idempotency_key": key,
        },
        separators=(",", ":"),
    ).encode()
    path = f"/agents/{urllib.parse.quote(target, safe='')}/inbox"
    status, answer = request(
        "POST",
        f"{ident.url}{path}",
        body=body,
        headers=signer.headers("POST", path, body),
        timeout=args.timeout,
    )
    if status in (200, 201):
        try:
            accepted = (json.loads(answer) or {}).get("id", "?")
        except Exception:  # noqa: BLE001 - the status is the measurement
            accepted = "?"
        ok(
            "reply",
            f"POST {path} -> {status:03d} (message {accepted}, corr_id "
            f"{envelope.get('corr_id') or '?'} preserved, status "
            f"{envelope.get('status') or '?'}, key {key})",
        )
        return True
    bad(
        "reply",
        f"POST {path} -> {status:03d} ({one_line(answer, 120) or 'no body'}) — the dispatch "
        f"stays unacked so the result is retried (key {key})",
    )
    return False


def ack(signer, ident, lease_id, message_ids, args):
    body = json.dumps(
        {"lease_id": lease_id, "message_ids": message_ids}, separators=(",", ":")
    ).encode()
    path = f"/agents/{ident.agent}/inbox/ack"
    status, answer = request(
        "POST",
        f"{ident.url}{path}",
        body=body,
        headers=signer.headers("POST", path, body),
        timeout=args.timeout,
    )
    if status in (200, 204):
        ok("ack", f"POST {path} -> {status:03d} ({len(message_ids)} message(s))")
        return True
    bad("ack", f"POST {path} -> {status:03d} ({one_line(answer, 120) or 'no body'})")
    return False


def once(ident, args):
    say(
        f"node-bus-worker --{'dry-run' if args.dry_run else 'once'} — agent={ident.agent or '?'} "
        f"bus={ident.url or '?'} project={ident.project or '?'}"
    )

    # refusals, in the order that names the real cause first — none of them touch the network
    if ident.error:
        bad("identity", f"{ident.error}; refusing")
        return 1
    if not ident.agent or not ident.url:
        bad(
            "bus_identity",
            f"agent={ident.agent or '(absent)'} url={ident.url or '(absent)'} — "
            f"{ident.bus_path} must carry both",
        )
        return 1
    if ident.node_doc and ident.bus_doc:
        left = ident.node_doc.get("project")
        right = ident.bus_doc.get("project")
        if left and right and left != right:
            bad(
                "project",
                f"{ident.node_path} says {left!r}, {ident.bus_path} says {right!r}; refusing",
            )
            return 1
    try:
        seed = load_seed(ident.key_path)
    except FileNotFoundError:
        bad(
            "signing_key",
            f"{ident.key_path} absent — the bus verifies a per-agent ed25519 "
            f"signature; this node holds no key, and a made-up one would "
            f"authenticate nothing",
        )
        return 1
    except (ValueError, OSError) as exc:
        bad("signing_key", f"{ident.key_path}: {exc}")
        return 1
    token, source = ident.bearer()
    if not token:
        bad("bus_bearer", f"{source} — a signed read still needs the shared bearer")
        return 1
    ok(
        "signing_key",
        f"{ident.key_path} — PKCS#8 ed25519, public "
        f"{ed25519_public_key(seed).hex()[:16]}…",
    )
    ok("bus_bearer", source)

    status, _ = request("GET", f"{ident.url}/health", timeout=args.timeout)
    if status != 200:
        bad(
            "bus_health",
            f"{ident.url}/health -> {status:03d} (unreachable from this node)",
        )
        return 1
    ok("bus_health", f"{ident.url}/health -> 200")

    signer = Signer(ident.agent, seed, token)
    lease = 5 if args.dry_run else args.lease_seconds
    path = f"/agents/{ident.agent}/inbox"
    query = f"?limit={args.limit}&lease_seconds={lease}"
    if args.wait_seconds:
        query += f"&wait_seconds={args.wait_seconds}"
    status, body = request(
        "GET",
        f"{ident.url}{path}{query}",
        headers=signer.headers("GET", path),
        timeout=max(args.timeout, args.wait_seconds + args.timeout),
    )
    if status != 200:
        meaning = {
            401: "refused — wrong/missing signature or bearer",
            403: "owner mismatch",
            404: "agent not registered on this bus",
            0: "bus unreachable",
        }.get(status, "unexpected status")
        bad("inbox", f"GET {path} -> {status:03d} ({meaning}): {one_line(body, 160)}")
        return 1
    try:
        envelope = json.loads(body)
    except Exception as exc:  # noqa: BLE001 - the answer is not ours to guess at
        bad(
            "inbox",
            f"GET {path} -> 200 but the body is not JSON ({one_line(str(exc), 120)})",
        )
        return 1
    messages = envelope.get("messages") or []
    lease_id = envelope.get("lease_id") or ""
    ok(
        "inbox",
        f"GET {path} -> 200, {len(messages)} message(s), lease {lease_id or '(none)'}, "
        f"queue_depth {envelope.get('queue_depth', '?')}",
    )
    if not messages:
        say("")
        say("BUS WORKER: IDLE")
        return 0

    seen = {} if args.dry_run else load_seen(ident.seen_path)
    results, all_ok = [], True
    for message in messages:
        raw = message.get("payload") or ""
        message_id = str(message.get("id") or "")
        try:
            decoded = base64.b64decode(raw) if isinstance(raw, str) else bytes(raw)
            dispatch = json.loads(decoded)
        except Exception as exc:  # noqa: BLE001 - a payload we cannot parse is a refusal
            bad(
                "payload",
                f"message {message.get('id')} payload is not base64 JSON "
                f"({one_line(str(exc), 120)}); left unacked",
            )
            all_ok = False
            continue
        if not isinstance(dispatch, dict):
            bad(
                "payload",
                f"message {message.get('id')} payload is not an object; left unacked",
            )
            all_ok = False
            continue
        good, result, should_ack = process(
            dispatch, ident, signer, args, seen, in_reply_to=message_id
        )
        all_ok = all_ok and good
        if result is not None and should_ack:
            key = dispatch_key(dispatch)
            if key:
                # Recorded at EXECUTION, not at delivery: a crash — or an answer lost between
                # here and the relay — must re-DELIVER this result, never re-run the work
                # (specs/ENVELOPE.md §Correlation and idempotency).
                seen[key] = result
            results.append((dispatch, result, message_id))

    if args.dry_run:
        say("")
        say(
            f"BUS WORKER: DRY RUN — nothing executed, nothing posted, nothing acked "
            f"({len(messages)} message(s) leased for {lease}s and left to expire)"
        )
        return 0 if all_ok else 1

    # The result cache is written BEFORE the first delivery, so the execution is on disk even if
    # the process dies mid-delivery and the message comes back.
    if results:
        try:
            save_seen(ident.seen_path, seen)
        except OSError as exc:
            warn(
                "idempotency",
                f"could not record the seen-cache at {ident.seen_path} ({exc})",
            )

    # Delivered FIRST, acked second, and each message is judged on ITS OWN delivery: one failed
    # result must not leave an unrelated message unacked, and one accepted result must not ack a
    # message whose delivery never landed.
    delivered_ok = True
    ackable = []
    for dispatch, result, message_id in results:
        target = dispatch.get("reply_to") or args.reply_to
        delivered = deliver(
            signer,
            ident,
            target,
            result,
            args,
            in_reply_to=message_id,
            idempotency_key=delivery_key(dispatch, result),
        )
        delivered_ok = delivered and delivered_ok
        if delivered and message_id:
            ackable.append(message_id)

    # acking is the last step on purpose: a crash between execution and delivery causes
    # redelivery, and the seen-cache plus the relay's idempotency key make that redelivery
    # deliver the SAME result instead of running the work again.
    acked_ok = True
    undelivered = [mid for _, _, mid in results if mid and mid not in ackable]
    if ackable:
        acked_ok = ack(signer, ident, lease_id, ackable, args)
    if undelivered:
        warn(
            "ack",
            f"{len(undelivered)} message(s) left unacked — their result did not reach the bus, "
            f"so redelivery is the safer outcome",
        )
    elif results:
        for message_id in (mid for _, _, mid in results if not mid):
            warn(
                "ack",
                f"a message with no id cannot be acked (result for {message_id!r})",
            )

    say("")
    if all_ok and delivered_ok and acked_ok:
        say("BUS WORKER: OK")
        return 0
    say("BUS WORKER: FAIL")
    return 1


def main(argv):
    parser = argparse.ArgumentParser(description="the node side of the crier bus")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--check", action="store_true", help="measure and print rows; writes nothing"
    )
    mode.add_argument(
        "--once", action="store_true", help="one poll: fetch, verify, run, reply, ack"
    )
    mode.add_argument(
        "--loop", type=int, metavar="N", help="N polls, sleeping --interval between"
    )
    mode.add_argument(
        "--print-brief-digest",
        metavar="DISPATCH.json",
        help=(
            "sender helper: print the cf-brief-v1 digest a dispatch's brief.digest must carry "
            "('-', or no value, reads stdin)"
        ),
        nargs="?",
        const="-",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="fetch and print the plan; run/post/ack nothing",
    )
    parser.add_argument(
        "--home",
        default=os.environ.get("HOME", ""),
        help="the node's HOME (default $HOME)",
    )
    parser.add_argument(
        "--identity", default="", help="node.json (default $HOME/.node/node.json)"
    )
    parser.add_argument(
        "--bus-identity", default="", help="crier.json (default $HOME/.node/crier.json)"
    )
    parser.add_argument(
        "--key", default="", help="PKCS#8 PEM key (default $HOME/.node/agent.key)"
    )
    parser.add_argument(
        "--token-file",
        default="",
        help="bearer file (default $HOME/.node/auth/crier.token)",
    )
    parser.add_argument("--agent", default="", help="override the agent id")
    parser.add_argument("--project", default="", help="override the project")
    parser.add_argument("--crier", default="", help="override the bus base url")
    parser.add_argument(
        "--workdir", default="", help="override the clone path (must be inside $HOME)"
    )
    parser.add_argument(
        "--harness-cmd",
        default="",
        help="argv template with {prompt}, e.g. '/path/hermes -z {prompt}'",
    )
    parser.add_argument(
        "--gateway-port",
        type=int,
        default=10800,
        help="harness gateway port (default 10800)",
    )
    parser.add_argument(
        "--reply-to",
        default="scheduler",
        help="result recipient when the dispatch names none",
    )
    parser.add_argument("--limit", type=int, default=DEFAULT_INBOX_LIMIT)
    parser.add_argument("--lease-seconds", type=int, default=DEFAULT_LEASE_SECONDS)
    parser.add_argument(
        "--wait-seconds", type=int, default=0, help="inbox long-poll budget (0..120)"
    )
    parser.add_argument(
        "--interval", type=int, default=15, help="seconds between polls in --loop"
    )
    parser.add_argument(
        "--harness-wall",
        type=int,
        default=DEFAULT_HARNESS_WALL,
        help="harness wall limit",
    )
    parser.add_argument(
        "--timeout", type=int, default=DEFAULT_TIMEOUT, help="per-request timeout"
    )
    args = parser.parse_args(argv)

    # Sender-side helper: no identity, no HOME, no network — it only hashes what the node will.
    if args.print_brief_digest:
        return print_brief_digest(args.print_brief_digest)

    if not (args.check or args.once or args.loop is not None or args.dry_run):
        parser.error(
            "one of --check, --once, --loop N is required (--dry-run plans a --once)"
        )
    if not args.home or not os.path.isdir(args.home):
        print(
            f"FAIL  home — {args.home or '(unset)'} is not a directory", file=sys.stderr
        )
        return 2
    if not 0 <= args.wait_seconds <= 120:
        print(
            "FAIL  wait_seconds — must be 0..120 (the bus answers 400 outside it)",
            file=sys.stderr,
        )
        return 2
    if args.loop is not None and args.loop < 1:
        print("FAIL  loop — must be at least 1", file=sys.stderr)
        return 2
    if args.workdir and not inside_clone(args.workdir, args.home):
        print(
            f"FAIL  workdir — {args.workdir} is not inside $HOME ({args.home}); this worker "
            f"never writes outside it",
            file=sys.stderr,
        )
        return 2

    ident = Identity(args.home, args)
    if args.check:
        return check(ident, args)
    if args.once or args.dry_run:
        return once(ident, args)

    worst = 0
    for index in range(args.loop):
        if index:
            time.sleep(args.interval)
        say(f"--- poll {index + 1}/{args.loop} ---")
        worst = max(worst, once(ident, args))
        if not os.path.exists(ident.key_path) or ident.error:
            break
    return worst


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
