#!/usr/bin/env python3
"""harness_resolve.py — one place decides which harness runs a model.

Design authority: `specs/HARNESS-MATRIX.md` §4 (the resolution rule). Nothing else in
this repo resolves a harness from a model: provisioning decides which harness a node
*happens to have*, and this module decides which harness a *run* should use, so that
"why did this run in Codex?" is answerable with `--explain` instead of by reading code.

Resolution order — first hit wins and the reason is recorded (spec §4):

  1. --directive-harness        -> harness_reason=directive
  2. --lane-harness             -> harness_reason=lane
  3. matrix by_family[<family>] -> harness_reason=matrix
  4. matrix "default"           -> harness_reason=fallback   (never silent: it prints;
                                 the shipped default is "hermes")

Model id -> family (case-insensitive; a provider-qualified id keeps its last
`/`-separated segment, so `anthropic/claude-sonnet-4` is still `claude`):

  claude*                            -> claude
  gpt* | o1* | o3* | o4* | codex*    -> openai   (also any id containing "codex")
  deepseek*                          -> deepseek
  glm* | zai*                        -> zai
  qwen*                              -> qwen
  kimi* | moonshot*                  -> kimi
  mistral*                           -> mistral
  llama*                             -> llama
  gemini*                            -> gemini
  grok*                              -> grok
  minimax*                           -> minimax
  pi* | omp*                         -> pi
  anything else                      -> unknown

Lane class (spec I1 — "the foreman is always Hermes"): a lane whose final
`-`-separated segment is one of qa, pm, sync, dogfood, releng, docs, readme, perf,
review is a `satellite`; every other lane name is a `foreman`. `--lane-class`
overrides that derivation, and with neither `--lane` nor `--lane-class` the class is
`foreman` — an unknown lane is treated conservatively.

I1's refusal is bound to a lane: with neither `--lane` nor `--lane-class` the resolver
still *reports* `lane_class=foreman`, but it does not refuse, because no lane was
bound — that invocation is `--explain` as a planning query (every run carries
`CF_LANE`, spec §5, so a run always binds one). Pass `--lane`, or `--lane-class
foreman`, to assert the refusal without a lane name.

Refusals — one `FAIL <named reason>` line on stdout, exit 2 (a green path exits 0).
They are evaluated in this order, which is the order an operator can act on:

  harness_directive_unknown: <name>          --directive-harness names an unknown harness
  harness_lane_unknown: <name>               --lane-harness names an unknown harness
  harness_unsupported: <h>; node has: <set>  the selection is not in --node-harnesses
  harness_foreman_requires_hermes: lane=<L> harness=<H>
                                             a bound foreman lane selected non-hermes
  harness_cannot_host: <harness> <family>    no native host and no shim for the pair
  harness_matrix_invalid: <path>: <detail>   the table itself is unusable
  harness_shim_unparseable: <item>           --shims is not `family=name` / `harness:family=name`

"not installed" is checked before "foreman lanes need hermes" on purpose: installing
the harness is the action, and the refusal names the node set that is missing it.

Recorded on every green path (spec §4/I3): `harness_selected`, `harness_reason`
(directive|lane|matrix|fallback), `model_requested`, `model_served`,
`provider_family`, `provider_binding`, plus `lane` and `lane_class`. `model_served`
is null here because resolution happens *before* a run; it is the run that fills it.

Usage:
  harness_resolve.py --explain <model> [--lane L] [--lane-class foreman|satellite]
      [--directive-harness H] [--lane-harness H] [--node-harnesses h1,h2]
      [--shims family=name,...] [--matrix-file PATH] [--json]
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import asdict, dataclass
from typing import Dict, List, Optional

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(HERE)
DEFAULT_MATRIX_FILE = os.path.join(REPO_ROOT, "config", "harness-matrix.json")

SATELLITE_SUFFIXES = (
    "qa",
    "pm",
    "sync",
    "dogfood",
    "releng",
    "docs",
    "readme",
    "perf",
    "review",
)

# Ordered, first match wins. Named families come before the generic `pi`/`omp`
# rung so a specific spelling can never be swallowed by a shorter prefix.
FAMILY_PREFIXES = (
    ("claude", "claude"),
    ("gpt", "openai"),
    ("o1", "openai"),
    ("o3", "openai"),
    ("o4", "openai"),
    ("codex", "openai"),
    ("deepseek", "deepseek"),
    ("glm", "zai"),
    ("zai", "zai"),
    ("qwen", "qwen"),
    ("kimi", "kimi"),
    ("moonshot", "kimi"),
    ("mistral", "mistral"),
    ("llama", "llama"),
    ("gemini", "gemini"),
    ("grok", "grok"),
    ("minimax", "minimax"),
    ("omp", "pi"),
    ("pi", "pi"),
)


class ResolveError(ValueError):
    """A refusal with a named reason. `str(exc)` is the text after `FAIL `."""


@dataclass
class Decision:
    harness_selected: str
    harness_reason: str
    model_requested: str
    model_served: Optional[str]
    provider_family: str
    provider_binding: str
    lane: Optional[str]
    lane_class: str


def model_family(model: str) -> str:
    """Derive the provider family from a model id (see the module docstring)."""
    ident = (model or "").strip().lower()
    if "/" in ident:
        ident = ident.rsplit("/", 1)[-1].strip()
    if not ident:
        return "unknown"
    for prefix, family in FAMILY_PREFIXES:
        if ident.startswith(prefix):
            return family
    if "codex" in ident:
        return "openai"
    return "unknown"


def lane_class(lane: Optional[str], override: Optional[str] = None) -> str:
    """`satellite` when the lane's final segment is a satellite suffix, else `foreman`."""
    if override:
        return override
    if not lane:
        return "foreman"
    tail = lane.strip().split("-")[-1].strip().lower()
    return "satellite" if tail in SATELLITE_SUFFIXES else "foreman"


def parse_harness_set(raw: Optional[str]) -> Optional[List[str]]:
    if raw is None:
        return None
    return [item.strip() for item in raw.split(",") if item.strip()]


def parse_shims(raw: Optional[str]) -> Dict[str, str]:
    """Parse `family=name` or `harness:family=name` pairs into one lookup."""
    out: Dict[str, str] = {}
    if not raw:
        return out
    for item in raw.split(","):
        item = item.strip()
        if not item:
            continue
        key, sep, value = item.partition("=")
        key, value = key.strip(), value.strip()
        if not sep or not key or not value:
            raise ResolveError(
                f"harness_shim_unparseable: {item!r}; use family=name or harness:family=name"
            )
        out[key] = value
    return out


def load_matrix(path: Optional[str] = None) -> dict:
    """Read the harness table. Data, not code: the resolver never hardcodes it."""
    path = path or DEFAULT_MATRIX_FILE
    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except OSError as exc:
        raise ResolveError(
            f"harness_matrix_invalid: {path}: {exc.strerror or exc}"
        ) from None
    except ValueError as exc:
        raise ResolveError(f"harness_matrix_invalid: {path}: {exc}") from None
    if not isinstance(data, dict):
        raise ResolveError(
            f"harness_matrix_invalid: {path}: expected a JSON object, got {type(data).__name__}"
        )
    for key in ("by_family", "hosts"):
        if not isinstance(data.get(key), dict):
            raise ResolveError(
                f"harness_matrix_invalid: {path}: `{key}` must be an object"
            )
    if not isinstance(data.get("shims", {}), dict):
        raise ResolveError(f"harness_matrix_invalid: {path}: `shims` must be an object")
    default = data.get("default", "hermes")
    if not isinstance(default, str) or not default.strip():
        raise ResolveError(
            f"harness_matrix_invalid: {path}: `default` must be a harness name"
        )
    return data


def select(
    family: str,
    matrix: dict,
    directive_harness: Optional[str] = None,
    lane_harness: Optional[str] = None,
) -> tuple:
    """Apply §4's order. Returns (harness, reason). No validation here."""
    if directive_harness:
        return directive_harness, "directive"
    if lane_harness:
        return lane_harness, "lane"
    by_family = matrix.get("by_family") or {}
    if isinstance(by_family.get(family), str) and by_family[family].strip():
        return by_family[family].strip(), "matrix"
    return (matrix.get("default") or "hermes"), "fallback"


def binding_for(harness: str, family: str, hosts: dict, shims: dict) -> Optional[str]:
    """`native`, `shim/<name>`, or None when the pair cannot run."""
    native = hosts.get(harness) or []
    if isinstance(native, str):
        native = [native]
    if "*" in native or family in native:
        return "native"
    shim = shims.get(f"{harness}:{family}") or shims.get(family)
    if shim:
        return f"shim/{shim}"
    return None


def resolve(
    model: str,
    lane: Optional[str] = None,
    lane_override: Optional[str] = None,
    directive_harness: Optional[str] = None,
    lane_harness: Optional[str] = None,
    node_harnesses: Optional[List[str]] = None,
    shims: Optional[Dict[str, str]] = None,
    matrix: Optional[dict] = None,
) -> Decision:
    """Resolve one run's harness, or raise ResolveError with a named reason."""
    matrix = load_matrix() if matrix is None else matrix
    family = model_family(model)
    klass = lane_class(lane, lane_override)
    harness, reason = select(family, matrix, directive_harness, lane_harness)

    hosts = matrix.get("hosts") or {}
    if harness not in hosts:
        if reason == "directive":
            raise ResolveError(f"harness_directive_unknown: {harness}")
        if reason == "lane":
            raise ResolveError(f"harness_lane_unknown: {harness}")
        raise ResolveError(
            f"harness_unsupported: {harness}; node has: "
            f"{', '.join(sorted(node_harnesses or [])) or 'none'}"
        )

    if node_harnesses is not None and harness not in node_harnesses:
        raise ResolveError(
            f"harness_unsupported: {harness}; node has: "
            f"{', '.join(sorted(node_harnesses)) or 'none'}"
        )

    if klass == "foreman" and harness != "hermes" and (lane or lane_override):
        raise ResolveError(
            f"harness_foreman_requires_hermes: lane={lane or '-'} harness={harness}"
        )

    merged_shims: Dict[str, str] = {}
    for key, value in (matrix.get("shims") or {}).items():
        merged_shims[str(key)] = str(value)
    merged_shims.update(shims or {})

    binding = binding_for(harness, family, hosts, merged_shims)
    if binding is None:
        raise ResolveError(f"harness_cannot_host: {harness} {family}")

    return Decision(
        harness_selected=harness,
        harness_reason=reason,
        model_requested=model,
        model_served=None,
        provider_family=family,
        provider_binding=binding,
        lane=lane,
        lane_class=klass,
    )


def render_text(decision: Decision) -> str:
    return (
        f"PASS harness_selected={decision.harness_selected}"
        f" harness_reason={decision.harness_reason}"
        f" model_requested={decision.model_requested}"
        f" provider_family={decision.provider_family}"
        f" model_served=<null-until-a-run>"
        f" provider_binding={decision.provider_binding}"
    )


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(
        prog="harness_resolve.py",
        description=(
            "Resolve which harness runs a model (specs/HARNESS-MATRIX.md §4): "
            "directive > lane > matrix > fallback, with named refusals."
        ),
    )
    ap.add_argument(
        "--explain",
        metavar="MODEL",
        required=True,
        help="model id to resolve a harness for (e.g. claude-sonnet-4)",
    )
    ap.add_argument("--lane", default=None, help="lane name, e.g. code-factory-qa")
    ap.add_argument(
        "--lane-class",
        dest="lane_class",
        choices=("foreman", "satellite"),
        default=None,
        help="override the lane-class derivation (default: derived, else foreman)",
    )
    ap.add_argument(
        "--directive-harness",
        default=None,
        help="harness pinned by the directive (wins over everything)",
    )
    ap.add_argument(
        "--lane-harness",
        default=None,
        help="harness pinned by the lane config (wins over the matrix)",
    )
    ap.add_argument(
        "--node-harnesses",
        default=None,
        help="comma-separated harnesses installed on the node; when given, the "
        "selection must be one of them",
    )
    ap.add_argument(
        "--shims",
        default=None,
        help="comma-separated family=name (or harness:family=name) shim bindings",
    )
    ap.add_argument(
        "--matrix-file",
        default=None,
        help=f"harness table to read (default: {DEFAULT_MATRIX_FILE})",
    )
    ap.add_argument(
        "--json",
        dest="as_json",
        action="store_true",
        help="print the record as one JSON object instead of a PASS row",
    )
    args = ap.parse_args(argv)

    try:
        matrix = load_matrix(args.matrix_file)
        decision = resolve(
            args.explain,
            lane=args.lane,
            lane_override=args.lane_class,
            directive_harness=args.directive_harness,
            lane_harness=args.lane_harness,
            node_harnesses=parse_harness_set(args.node_harnesses),
            shims=parse_shims(args.shims),
            matrix=matrix,
        )
    except ResolveError as exc:
        print(f"FAIL {exc}")
        return 2

    print(
        json.dumps(asdict(decision), sort_keys=True)
        if args.as_json
        else render_text(decision)
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
