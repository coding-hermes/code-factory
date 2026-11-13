#!/usr/bin/env python3
"""github-app-token.py — mint a GitHub App installation token, or refuse naming the missing piece.

A GitHub App installation token lives ONE HOUR. Anything that keeps a credential on a node
must therefore be able to mint a fresh one on demand, and must be able to say exactly which
piece of the hand-made App is wrong when it cannot. This program does both with the standard
library only: RS256 JWT signing is done here (no `cryptography`, no `jwt`, no `curl | sh`).

Usage
  github-app-token.py --check   [--repo OWNER/NAME] [--slug SLUG]
        Verify every piece a human had to create and name each one that is missing: app id,
        installation id, private key file (mode 600), the installation's coverage of the
        target repo, and that a freshly minted token can READ that repo (status code only).
        Read-only: mints a token in memory, writes nothing.
  github-app-token.py --out PATH [--if-older SECONDS]
        Mint and write the token to PATH at mode 600. --if-older makes it a no-op while the
        existing file is younger than SECONDS (the refresh timer uses this).

Inputs come from an env file (default ~/.config/code-factory/github-app.env) holding
pointers, never secrets:

  GITHUB_APP_ID=123456
  GITHUB_APP_INSTALLATION_ID=12345678
  GITHUB_APP_PRIVATE_KEY_FILE=/home/<you>/.config/code-factory/github-app.private-key.pem
  GITHUB_APP_TOKEN_FILE=/home/<you>/.config/code-factory/github.token    # optional

Nothing secret is ever printed: not the token, not the JWT, not the key. Only status codes,
permission names and file modes reach stdout/stderr.

Exit codes: 0 every row measured and green; 1 a named FAIL; 2 usage error.
"""

import argparse
import base64
import calendar
import hashlib
import json
import os
import stat
import sys
import time
import urllib.error
import urllib.request

DEFAULT_ENV_FILE = "~/.config/code-factory/github-app.env"
DEFAULT_TOKEN_FILE = "~/.config/code-factory/github.token"
DEFAULT_API = "https://api.github.com"
# GitHub rejects an App JWT whose exp is more than 10 minutes out, and iat must not be in
# the future for a clock-skewed box: 60s back, 540s forward leaves ~9 minutes of validity.
JWT_BACKDATE = 60
JWT_LIFETIME = 540
TIMEOUT = 20

# The set this fleet needs, with the reason each one is needed. Used by --check to name a
# permission that is declared but missing, and by --manifest.
REQUIRED_PERMISSIONS = {
    "contents": ("write", "clone and push commits; a push is a contents write"),
    "pull_requests": ("write", "open the PR a protected main requires (CF-163)"),
    "metadata": (
        "read",
        "mandatory for every App; resolves the repo and the installation",
    ),
}


def say(msg=""):
    print(msg)


def fail(piece, detail):
    print("  FAIL  %s — %s" % (piece, detail))


def ok(piece, detail):
    print("  PASS  %s — %s" % (piece, detail))


def warn(piece, detail):
    print("  WARN  %s — %s" % (piece, detail))


def usage_error(msg):
    print("github-app-token: %s" % msg, file=sys.stderr)
    sys.exit(2)


# --- inputs ---------------------------------------------------------------------------------
def read_env_file(path):
    """KEY=VALUE, parsed as data. Never sourced; an unparseable line is refused, not run."""
    vals = {}
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                raise ValueError("line is not KEY=VALUE: %r" % line[:40])
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.strip()
            if value[:1] in ("'", '"') and value[-1:] == value[:1] and len(value) >= 2:
                value = value[1:-1]
            vals[key] = value
    return vals


def base_args(parser):
    parser.add_argument(
        "--env-file",
        default=os.environ.get("GITHUB_APP_ENV_FILE", DEFAULT_ENV_FILE),
        help="env file naming the App (default %s)" % DEFAULT_ENV_FILE,
    )
    parser.add_argument(
        "--api-base",
        default=os.environ.get("GITHUB_API_BASE", DEFAULT_API),
        help="API base URL (default %s; tests point this at a local server)"
        % DEFAULT_API,
    )


# --- RSA + JWT (stdlib) ---------------------------------------------------------------------
def _tlv(buf, i):
    if i + 2 > len(buf):
        raise ValueError("truncated DER")
    tag = buf[i]
    i += 1
    length = buf[i]
    i += 1
    if length & 0x80:
        nbytes = length & 0x7F
        if nbytes == 0 or nbytes > 4 or i + nbytes > len(buf):
            raise ValueError("bad DER length")
        length = int.from_bytes(buf[i : i + nbytes], "big")
        i += nbytes
    end = i + length
    if end > len(buf):
        raise ValueError("truncated DER value")
    return tag, buf[i:end], end


def _seq_ints(der):
    """Yield each INTEGER of a DER SEQUENCE, in order."""
    tag, body, _ = _tlv(der, 0)
    if tag != 0x30:
        raise ValueError("expected a SEQUENCE")
    i = 0
    while i < len(body):
        tag, value, i = _tlv(body, i)
        if tag == 0x02:
            yield int.from_bytes(value, "big")


def load_rsa_key(path):
    """Parse a PEM RSA private key (PKCS#1 or PKCS#8) into (n, e, d). Stdlib only."""
    with open(path, "rb") as fh:
        pem = fh.read()
    text = pem.decode("ascii", "replace")
    if "-----BEGIN" not in text:
        raise ValueError("not a PEM file")
    if "ENCRYPTED" in text:
        raise ValueError(
            "the key is passphrase-protected; an unattended mint cannot unlock it"
        )
    label = ""
    body = []
    inside = False
    for line in text.splitlines():
        if line.startswith("-----BEGIN"):
            label = line.strip("- ").replace("BEGIN ", "")
            inside = True
            continue
        if line.startswith("-----END"):
            break
        if inside:
            body.append(line.strip())
    if not body:
        raise ValueError("no PEM body")
    der = base64.b64decode("".join(body))
    if label != "RSA PRIVATE KEY":
        # PKCS#8 (OpenSSL 3 writes "PRIVATE KEY" for RSA too): SEQUENCE { INTEGER 0,
        # AlgorithmIdentifier, OCTET STRING PrivateKey }. Unwrap the OCTET STRING.
        tag, seq_body, _ = _tlv(der, 0)
        if tag != 0x30:
            raise ValueError("expected a SEQUENCE")
        i = 0
        _, _, i = _tlv(seq_body, i)  # version
        _, _, i = _tlv(seq_body, i)  # AlgorithmIdentifier
        tag, inner, _ = _tlv(seq_body, i)  # PrivateKey
        if tag != 0x04:
            raise ValueError("PKCS#8 without an OCTET STRING key")
        der = inner
    ints = list(_seq_ints(der))
    if len(ints) < 9:
        raise ValueError("unexpected RSA key structure (%d integers)" % len(ints))
    n, e, d = ints[1], ints[2], ints[3]
    if n.bit_length() < 2048:
        raise ValueError(
            "key is %d bits; GitHub Apps require at least 2048" % n.bit_length()
        )
    return n, e, d


def b64url(raw):
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def sign_rs256(private_key, message):
    """RSASSA-PKCS1-v1_5 over SHA-256, computed with pow(). No third-party crypto."""
    n, _e, d = private_key
    digest = hashlib.sha256(message).digest()
    # DigestInfo prefix for SHA-256 (RFC 8017 §9.2, note 1).
    digest_info = bytes.fromhex("3031300d060960864801650304020105000420") + digest
    k = (n.bit_length() + 7) // 8
    if k < len(digest_info) + 11:
        raise ValueError("key too small to sign")
    em = b"\x00\x01" + b"\xff" * (k - len(digest_info) - 3) + b"\x00" + digest_info
    sig = pow(int.from_bytes(em, "big"), d, n).to_bytes(k, "big")
    return sig


def make_jwt(private_key, app_id, now=None):
    now = int(time.time() if now is None else now)
    header = {"alg": "RS256", "typ": "JWT"}
    claims = {"iat": now - JWT_BACKDATE, "exp": now + JWT_LIFETIME, "iss": str(app_id)}
    signing_input = (
        b64url(json.dumps(header, separators=(",", ":")).encode())
        + "."
        + b64url(json.dumps(claims, separators=(",", ":")).encode())
    )
    sig = sign_rs256(private_key, signing_input.encode("ascii"))
    return signing_input + "." + b64url(sig), claims


# --- HTTP -----------------------------------------------------------------------------------
def api(method, url, token=None, jwt=None, body=None):
    """Return (status, parsed_json_or_None). Status 0 means no answer at all."""
    data = None
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "code-factory-github-app",
    }
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    if jwt:
        headers["Authorization"] = "Bearer " + jwt
    elif token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            raw = resp.read()
            status = resp.getcode()
    except urllib.error.HTTPError as exc:
        return exc.code, _maybe_json(exc.read())
    except (urllib.error.URLError, OSError):
        return 0, None
    return status, _maybe_json(raw)


def _maybe_json(raw):
    try:
        return json.loads(raw.decode("utf-8", "replace"))
    except (ValueError, AttributeError):
        return None


def _message(payload):
    if isinstance(payload, dict):
        return str(payload.get("message", ""))[:120]
    return ""


# --- commands -------------------------------------------------------------------------------
def load_inputs(env_file):
    """Return (vals, problems). problems is a list of (piece, detail) to name as FAILs."""
    problems = []
    path = os.path.expanduser(env_file)
    if not os.path.isfile(path):
        return {}, [
            (
                "env_file",
                "%s is absent — run scripts/github-app-setup.sh --apply once the App "
                "exists (creating it is a browser step a human must do)" % path,
            )
        ]
    try:
        vals = read_env_file(path)
    except (OSError, ValueError) as exc:
        return {}, [
            ("env_file", "%s is unreadable as KEY=VALUE data (%s)" % (path, exc))
        ]

    app_id = vals.get("GITHUB_APP_ID", "")
    if not app_id:
        problems.append(
            (
                "app_id",
                "GITHUB_APP_ID is unset — copy the App id from the App's "
                "settings page (App settings -> About -> App ID)",
            )
        )
    elif not app_id.isdigit():
        problems.append(("app_id", "GITHUB_APP_ID=%r is not numeric" % app_id[:20]))

    inst_id = vals.get("GITHUB_APP_INSTALLATION_ID", "")
    if not inst_id:
        problems.append(
            (
                "installation_id",
                "GITHUB_APP_INSTALLATION_ID is unset — the id in the URL after "
                "installing the App on the org (Settings -> Installations -> Configure)",
            )
        )
    elif not inst_id.isdigit():
        problems.append(
            (
                "installation_id",
                "GITHUB_APP_INSTALLATION_ID=%r is not numeric" % inst_id[:20],
            )
        )
    return vals, problems


def check_key_file(vals):
    """(problem_or_None, private_key_or_None). Names the mode, never the contents."""
    raw = vals.get("GITHUB_APP_PRIVATE_KEY_FILE", "")
    if not raw:
        return (
            "private_key_file",
            "GITHUB_APP_PRIVATE_KEY_FILE is unset — download the .pem from the App's "
            "settings page (Private keys -> Generate a private key); the download is the "
            "only copy GitHub will ever offer",
        ), None
    path = os.path.expanduser(raw)
    if not os.path.isfile(path):
        return (
            "private_key_file",
            "%s does not exist — move the downloaded .pem there" % path,
        ), None
    try:
        mode = stat.S_IMODE(os.stat(path).st_mode)
    except OSError as exc:
        return ("private_key_file", "%s cannot be stat'ed (%s)" % (path, exc)), None
    if mode != 0o600:
        return (
            "private_key_file",
            "%s is mode %04o; a private key must be 0600 (chmod 600 %s)"
            % (path, mode, path),
        ), None
    try:
        key = load_rsa_key(path)
    except (OSError, ValueError) as exc:
        return (
            "private_key_file",
            "%s does not parse as an RSA private key (%s)" % (path, exc),
        ), None
    return None, key


def mint(vals, key, api_base):
    """Exchange a JWT for an installation token. (status, payload, problem_or_None)."""
    app_id = vals["GITHUB_APP_ID"]
    inst_id = vals["GITHUB_APP_INSTALLATION_ID"]
    try:
        jwt, claims = make_jwt(key, app_id)
    except (ValueError, TypeError) as exc:
        return 0, None, ("jwt", "could not sign a JWT with the App key (%s)" % exc)
    status, payload = api(
        "POST", "%s/app/installations/%s/access_tokens" % (api_base, inst_id), jwt=jwt
    )
    if status == 201 or status == 200:
        token = (payload or {}).get("token")
        if not token:
            return (
                status,
                payload,
                ("token_mint", "%d answered without a token field" % status),
            )
        payload["_jwt_claims"] = claims
        return status, payload, None
    if status == 401:
        return (
            status,
            payload,
            (
                "token_mint",
                "401 — the JWT was rejected: App id %s does not own the key at "
                "GITHUB_APP_PRIVATE_KEY_FILE, or the clock is off" % app_id,
            ),
        )
    if status == 404:
        return (
            status,
            payload,
            (
                "installation_id",
                "404 for installation %s — it does not belong to App %s, or the "
                "App is not installed yet (open the install URL and click Install)"
                % (inst_id, app_id),
            ),
        )
    if status == 403:
        return (
            status,
            payload,
            ("token_mint", "403 — %s" % (_message(payload) or "forbidden")),
        )
    return (
        status,
        payload,
        ("token_mint", "%d — %s" % (status, _message(payload) or "no answer")),
    )


def cmd_check(args):
    failures = 0

    def fail_row(piece, detail):
        nonlocal failures
        failures += 1
        fail(piece, detail)

    vals, problems = load_inputs(args.env_file)
    for piece, detail in problems:
        fail_row(piece, detail)
    if problems:
        say("")
        say(
            "GITHUB APP: FAIL (%d) — nothing was minted; every piece above must be created "
            "before a token can exist" % failures
        )
        return 1

    key_problem, key = check_key_file(vals)
    if key_problem:
        fail_row(*key_problem)
        say("")
        say("GITHUB APP: FAIL (%d)" % failures)
        return 1
    ok(
        "private_key_file",
        "%s, mode 600, parses as RSA %d-bit"
        % (
            os.path.expanduser(vals["GITHUB_APP_PRIVATE_KEY_FILE"]),
            key[0].bit_length(),
        ),
    )

    status, payload, problem = mint(vals, key, args.api_base)
    if problem:
        fail_row(*problem)
        say("")
        say("GITHUB APP: FAIL (%d) — no token was minted" % failures)
        return 1
    token = payload["token"]
    granted = payload.get("permissions") or {}
    expires_at = payload.get("expires_at", "")
    ok(
        "token_mint",
        "installation %s answered %d; token expires %s (permissions read back, "
        "never the token)" % (vals["GITHUB_APP_INSTALLATION_ID"], status, expires_at),
    )

    # Permissions are a fact of the mint response, not a guess from a doc.
    for name, (want, why) in sorted(REQUIRED_PERMISSIONS.items()):
        got = granted.get(name, "none")
        if got == want or (want == "read" and got in ("read", "write")):
            ok("permission:" + name, "%s (need %s — %s)" % (got, want, why))
        else:
            fail_row(
                "permission:" + name,
                "granted %r, need %r — %s. Raise it in App settings -> Permissions and "
                "accept the installation prompt" % (got, want, why),
            )

    slug = args.slug or vals.get("GITHUB_APP_SLUG", "")
    if slug:
        s_status, s_payload = api("GET", "%s/apps/%s" % (args.api_base, slug))
        if s_status == 200:
            declared = (s_payload or {}).get("permissions") or {}
            ok(
                "app_slug",
                "/apps/%s -> 200 (declared permissions: %s)"
                % (
                    slug,
                    ",".join("%s:%s" % (k, declared[k]) for k in sorted(declared))
                    or "none",
                ),
            )
            if declared.get("contents") not in ("write",):
                fail_row(
                    "permission:contents",
                    "the App itself declares contents=%r; fix the App, not the token"
                    % declared.get("contents"),
                )
        else:
            fail_row(
                "app_slug",
                "/apps/%s -> %d (no public App with that slug)" % (slug, s_status),
            )

    # A setup-created env file records GITHUB_APP_REPO, so read that pointer as
    # data rather than requiring the caller to export it into this process.
    target_repo = args.repo or vals.get("GITHUB_APP_REPO", "")
    repo_read_status = None
    if target_repo:
        owner, _, name = target_repo.partition("/")
        cov_status, cov_payload = api(
            "GET",
            "%s/installation/repositories?per_page=100" % args.api_base,
            token=token,
        )
        names = (
            [
                (r or {}).get("full_name")
                for r in ((cov_payload or {}).get("repositories") or [])
            ]
            if isinstance(cov_payload, dict)
            else []
        )
        target = "%s/%s" % (owner, name)
        if cov_status == 200 and target in names:
            ok(
                "installation_covers",
                "installation grants %s (of %d repositories)" % (target, len(names)),
            )
        elif cov_status == 200:
            fail_row(
                "installation_covers",
                "installation does not cover %s (it covers: %s) — add the repo on the App's "
                "installation settings page"
                % (target, ", ".join(filter(None, names)) or "nothing"),
            )
        else:
            fail_row(
                "installation_covers",
                "/installation/repositories -> %d — %s"
                % (cov_status, _message(cov_payload) or "no answer"),
            )

        r_status, r_payload = api(
            "GET", "%s/repos/%s/%s" % (args.api_base, owner, name), token=token
        )
        if r_status == 200:
            ok(
                "repo_read",
                "GET /repos/%s/%s with a fresh token -> 200" % (owner, name),
            )
        elif r_status in (401, 403):
            fail_row(
                "repo_read",
                "GET /repos/%s/%s -> %d — the installation cannot read the repo: either it "
                "does not cover it, or contents is not granted"
                % (owner, name, r_status),
            )
        else:
            fail_row(
                "repo_read",
                "GET /repos/%s/%s -> %d — %s"
                % (owner, name, r_status, _message(r_payload) or "no answer"),
            )

        repo_read_status = r_status
    else:
        fail_row(
            "repo_read",
            "no repository named, so the read was not measured (pass --repo OWNER/NAME "
            "or set GITHUB_APP_REPO)",
        )

    if failures:
        say("")
        say("GITHUB APP: FAIL (%d)" % failures)
        return 1
    say("")
    say(
        "GITHUB APP: PASS — every piece measured, a fresh token reads %s -> %d"
        % (target_repo, repo_read_status)
    )
    return 0


def cmd_out(args):
    vals, problems = load_inputs(args.env_file)
    if problems:
        for piece, detail in problems:
            fail(piece, detail)
        say("")
        say("GITHUB APP TOKEN: FAIL (%d) — nothing written" % len(problems))
        return 1
    out = os.path.expanduser(
        args.out or vals.get("GITHUB_APP_TOKEN_FILE") or DEFAULT_TOKEN_FILE
    )

    if args.if_older and os.path.isfile(out):
        age = time.time() - os.path.getmtime(out)
        if age < args.if_older:
            say(
                "  SKIP  token — %s is %ds old (< %ds), still valid"
                % (out, int(age), int(args.if_older))
            )
            say("GITHUB APP TOKEN: SKIP — nothing to do")
            return 0

    key_problem, key = check_key_file(vals)
    if key_problem:
        fail(*key_problem)
        say("")
        say("GITHUB APP TOKEN: FAIL (1) — nothing written")
        return 1
    status, payload, problem = mint(vals, key, args.api_base)
    if problem:
        fail(*problem)
        say("")
        say("GITHUB APP TOKEN: FAIL (1) — nothing written")
        return 1

    token = payload["token"]
    write_private(out, token + "\n")
    ok(
        "token",
        "written to %s, mode %s, expires %s"
        % (
            out,
            oct(stat.S_IMODE(os.stat(out).st_mode))[2:],
            payload.get("expires_at", "?"),
        ),
    )
    say(
        "GITHUB APP TOKEN: PASS — minted a %ds token (value never printed)"
        % _ttl(payload)
    )
    return 0


def _ttl(payload):
    """Seconds until the minted token expires, from the API's own expires_at."""
    exp = payload.get("expires_at")
    if exp:
        try:
            return int(
                calendar.timegm(time.strptime(exp, "%Y-%m-%dT%H:%M:%SZ")) - time.time()
            )
        except ValueError:
            pass
    return 3600


def write_private(path, text):
    """Write at mode 600 atomically: the file is never world-readable, not even briefly."""
    d = os.path.dirname(os.path.abspath(path))
    if d:
        os.makedirs(d, exist_ok=True)
    tmp = "%s.tmp.%d" % (path, os.getpid())
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(text)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise
    os.chmod(path, 0o600)


def cmd_manifest(args):
    """Print the exact manifest a human pastes into the browser App-creation flow."""
    manifest = {
        "name": args.name,
        "url": args.url,
        "description": "code-factory node credentials: 1h installation tokens, no PAT",
        "public": False,
        "request_oauth_on_install": False,
        "default_permissions": {k: v[0] for k, v in REQUIRED_PERMISSIONS.items()},
        "default_events": [],
        # The manifest schema requires a redirect_url; nothing has to listen on it for an
        # App that only uses installation tokens, but GitHub will not accept the manifest
        # without one.
        "redirect_url": args.redirect_url or "https://github.com/%s" % args.name,
        "hook_attributes": {"active": False},
    }
    print(json.dumps(manifest, indent=2))
    return 0


def cmd_jwt(args):
    """Print ONLY the claims of a signed JWT. Used by the selftest; never prints the JWT."""
    vals, problems = load_inputs(args.env_file)
    if problems:
        for piece, detail in problems:
            fail(piece, detail)
        return 1
    key_problem, key = check_key_file(vals)
    if key_problem:
        fail(*key_problem)
        return 1
    jwt, claims = make_jwt(key, vals["GITHUB_APP_ID"])
    if args.jwt_out:
        write_private(os.path.expanduser(args.jwt_out), jwt + "\n")
    print(
        json.dumps(
            {"claims": claims, "segments": len(jwt.split(".")), "length": len(jwt)},
            sort_keys=True,
        )
    )
    return 0


def main(argv):
    parser = argparse.ArgumentParser(add_help=True, description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="cmd")
    p_check = sub.add_parser(
        "check", help="verify every hand-made piece; write nothing"
    )
    base_args(p_check)
    p_check.add_argument(
        "--repo",
        default=os.environ.get("GITHUB_APP_REPO", ""),
        help="OWNER/NAME the installation must cover and a token must read",
    )
    p_check.add_argument(
        "--slug", default="", help="App slug, verified against /apps/<slug>"
    )
    p_out = sub.add_parser("token", help="mint and write the token at mode 600")
    base_args(p_out)
    p_out.add_argument(
        "--out", default="", help="destination (default %s)" % DEFAULT_TOKEN_FILE
    )
    p_out.add_argument(
        "--if-older",
        type=int,
        default=0,
        help="no-op while the destination is younger than N seconds",
    )
    p_man = sub.add_parser("manifest", help="print the App manifest JSON")
    p_man.add_argument("--name", default="code-factory")
    p_man.add_argument("--url", default="https://github.com/coding-hermes")
    p_man.add_argument("--org", default="")
    p_man.add_argument("--redirect-url", default="")
    p_jwt = sub.add_parser("jwt", help="print JWT CLAIMS only (selftest aid)")
    base_args(p_jwt)
    p_jwt.add_argument(
        "--jwt-out", default="", help="write the JWT here at 600 (selftest only)"
    )

    # Back-compat flags: --check / --out keep the documented one-flag spelling.
    argv = list(argv)
    if argv and argv[0].startswith("-"):
        if "--out" in argv or "--if-older" in argv:
            argv = ["token"] + argv
        elif "--manifest" in argv:
            argv = ["manifest"] + argv
        elif "--jwt" in argv:
            argv = ["jwt"] + [a for a in argv if a != "--jwt"]
        else:
            argv = ["check"] + argv

    args = parser.parse_args(argv)
    if not args.cmd:
        parser.print_help()
        return 2
    if args.cmd == "check":
        return cmd_check(args)
    if args.cmd == "token":
        return cmd_out(args)
    if args.cmd == "manifest":
        return cmd_manifest(args)
    if args.cmd == "jwt":
        return cmd_jwt(args)
    usage_error("unknown command %r" % args.cmd)
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        sys.exit(130)
