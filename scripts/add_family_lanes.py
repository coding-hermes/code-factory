#!/usr/bin/env python3
"""Create and configure the code-factory lane family through the scheduler API."""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from urllib.parse import quote

API = "http://127.0.0.1:9090"
H = os.path.expanduser("~/.hermes")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class UsageParser(argparse.ArgumentParser):
    def error(self, message):
        self.print_usage(sys.stderr)
        self.exit(64, f"{self.prog}: error: {message}\n")


def parser():
    p = UsageParser(description="Create and configure the code-factory lane family.")
    p.add_argument("--api-base", default=API, help=f"scheduler API base (default: {API})")
    p.add_argument("--namespace", default=None, help="namespace override for every lane")
    p.add_argument("--token-file", default="", help="read the bearer token from this file")
    return p


def token_from_proc():
    pid = (
        os.popen("systemctl --user show -p MainPID --value coding-hermes-scheduler")
        .read()
        .strip()
        or "0"
    )
    try:
        values = (
            open(f"/proc/{pid}/environ", "rb")
            .read()
            .decode(errors="replace")
            .split("\0")
        )
    except OSError as exc:
        raise RuntimeError("scheduler token is unavailable") from exc
    for value in values:
        if value.startswith("SCHEDULER_OPERATOR_TOKEN="):
            return value.split("=", 1)[1]
    raise RuntimeError("scheduler token is unavailable")


def read_token(args):
    if args.token_file:
        try:
            token = open(args.token_file, encoding="utf-8").read().strip()
        except OSError as exc:
            raise RuntimeError("token file is unreadable") from exc
    else:
        token = os.environ.get("CODER_API_TOKEN") or token_from_proc()
    if not token:
        raise RuntimeError("scheduler token is empty")
    return token


def api(api_base, token, method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        api_base.rstrip("/") + path,
        data=data,
        method=method,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read().decode()
            return response.status, json.loads(raw or "{}")
    except urllib.error.HTTPError as exc:
        # Never relay an API response body: it could contain credential material.
        return exc.code, {}
    except (urllib.error.URLError, TimeoutError):
        return 599, {}


def project_from_response(data):
    project = data.get("project") if isinstance(data, dict) else None
    return project if isinstance(project, dict) else data if isinstance(data, dict) else {}


def project_path(name):
    return "/api/v1/projects/" + quote(name, safe="")


LANES = [
    # name, workdir, namespace, prompt
    ("code-factory-docs", f"{H}/stand-in/docs/code-factory", "docs", "docs"),
    ("code-factory-docs-qa", f"{H}/stand-in/pm/code-factory-docs", "qa", "qa"),
    ("code-factory-readme", f"{H}/stand-in/readme/code-factory", "docs", "readme"),
    ("code-factory-readme-qa", f"{H}/stand-in/pm/code-factory-readme", "qa", "qa"),
    (
        "code-factory-releng",
        f"{H}/stand-in/releng-lane/code-factory",
        "releases",
        "releng",
    ),
    ("code-factory-releng-qa", f"{H}/stand-in/pm/code-factory-releng", "qa", "qa"),
    ("code-factory-perf", f"{H}/stand-in/perf/code-factory", "perf", "perf"),
    ("code-factory-review", f"{H}/stand-in/review/code-factory", "review", "review"),
]


def desired_namespace(args, namespace):
    return args.namespace if args.namespace is not None else namespace


def phase2_body(prompt_name, current):
    prompt_path = os.path.join(ROOT, "prompts", f"{prompt_name}.md")
    try:
        prompt = open(prompt_path, encoding="utf-8").read()
    except OSError as exc:
        raise RuntimeError(f"prompt file is unreadable: {prompt_path}") from exc
    # These are the documented pointer fields on ProjectUpdates. Keep this
    # body deliberately narrow so the API's validation and admission law run.
    return {
        "prompt": prompt,
        "prompt_mode": "append",
        "parent": "code-factory",
        "admission_mode": "cooldown",
        "model": current.get("model") or "",
        "provider": current.get("provider") or "",
    }


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        token = read_token(args)
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 64

    created = 0
    present = 0
    refused = 0
    accepted = []
    failures = []

    for name, workdir, namespace, prompt_name in LANES:
        path = project_path(name)
        status, data = api(args.api_base, token, "GET", path)
        current = project_from_response(data) if status == 200 else {}
        if status == 404:
            os.makedirs(workdir, exist_ok=True)
            status, data = api(
                args.api_base,
                token,
                "POST",
                "/api/v1/projects",
                {
                    "name": name,
                    "repo_url": f"local:{ROOT}",
                    "workdir": workdir,
                    "namespace_id": desired_namespace(args, namespace),
                },
            )
            if status == 201:
                created += 1
                current = project_from_response(data)
            else:
                refused += 1
                failures.append(f"{name}: POST {status}")
                continue
        elif status == 200:
            present += 1
            if not isinstance(current, dict) or current.get("name") != name:
                refused += 1
                failures.append(f"{name}: GET response did not identify the requested project")
                continue
        else:
            refused += 1
            failures.append(f"{name}: GET {status}")
            continue

        accepted.append((name, prompt_name, current, desired_namespace(args, namespace)))

    # A refusal in phase 1 must not be hidden by a later phase. Still finish
    # the independent GET/POST pass so the summary accounts for every lane.
    if refused:
        print(f"summary created={created} present={present} refused={refused}")
        for failure in failures:
            print(f"refused: {failure}", file=sys.stderr)
        return 2

    for name, prompt_name, current, namespace in accepted:
        try:
            desired = phase2_body(prompt_name, current)
        except RuntimeError as exc:
            refused += 1
            failures.append(f"{name}: phase-2 preparation failed")
            print(f"refused: {name}: {exc}", file=sys.stderr)
            continue
        if all(current.get(field) == value for field, value in desired.items()):
            continue
        status, _ = api(args.api_base, token, "PUT", project_path(name), desired)
        if status not in (200, 204):
            refused += 1
            failures.append(f"{name}: phase-2 PUT {status}")
            continue
        status, data = api(args.api_base, token, "GET", project_path(name))
        verified = project_from_response(data) if status == 200 else {}
        if status != 200 or any(verified.get(field) != value for field, value in desired.items()):
            refused += 1
            failures.append(f"{name}: phase-2 readback failed")

    print(f"summary created={created} present={present} refused={refused}")
    for failure in failures:
        print(f"refused: {failure}", file=sys.stderr)
    return 2 if refused else 0


if __name__ == "__main__":
    raise SystemExit(main())
