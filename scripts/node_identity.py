#!/usr/bin/env python3
"""node_identity.py — merge keys into $HOME/.node/node.json without destroying its schema.

  node_identity.py <path> namespace=code-factory bus.base=http://host:8767 provisioned_by=...
  node_identity.py <path> 'duckbrain.namespaces[]=code-factory,coder'

A key ending in [] is written as a JSON ARRAY, split on commas, so a node that serves more than
one DuckBrain namespace can say so without a second file.

project-node.sh owns this file and writes node_id, project, repo{origin,ref,path},
harness{name,port}, bus{base}, created_by, created_at. A provisioner that rewrote the file
with its own flat schema would silently delete those fields and break every consumer, so this
merges: dotted keys create nested objects, existing keys keep their type, and nothing is
removed. Writes atomically at mode 600.

Exit 0 = merged (prints the keys that changed); 1 = unreadable existing file (left untouched);
2 = bad argument.
"""

import json
import os
import sys
import tempfile


def set_path(doc: dict, dotted: str, value: str) -> bool:
    as_list = dotted.endswith("[]")
    if as_list:
        dotted = dotted[:-2]
        items = [part.strip() for part in value.split(",") if part.strip()]
        if not items:
            raise ValueError(f"{dotted}[] was declared empty")
        new_value: object = items
    else:
        new_value = value

    parts = dotted.split(".")
    node = doc
    for part in parts[:-1]:
        if not isinstance(node.get(part), dict):
            node[part] = {}
        node = node[part]
    leaf = parts[-1]
    if node.get(leaf) == new_value:
        return False
    node[leaf] = new_value
    return True


def main(argv: list) -> int:
    if len(argv) < 2:
        print(
            "usage: node_identity.py <path> key=value [key=value ...]", file=sys.stderr
        )
        return 2
    path = argv[0]
    pairs = argv[1:]
    for p in pairs:
        if "=" not in p or not p.split("=", 1)[0]:
            print(f"FAIL  identity — argument is not key=value: {p}", file=sys.stderr)
            return 2

    doc = {}
    if os.path.exists(path):
        try:
            with open(path) as fh:
                doc = json.load(fh)
            if not isinstance(doc, dict):
                raise ValueError("top level is not an object")
        except Exception as exc:  # noqa: BLE001 - the point is to refuse, not to guess
            print(
                f"FAIL  identity — {path} is not a readable JSON object ({exc}); left untouched",
                file=sys.stderr,
            )
            return 1

    changed = []
    for p in pairs:
        key, value = p.split("=", 1)
        try:
            if set_path(doc, key, value):
                changed.append(key)
        except ValueError as exc:
            print(f"FAIL  identity — {exc}", file=sys.stderr)
            return 2

    directory = os.path.dirname(os.path.abspath(path)) or "."
    os.makedirs(directory, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=directory)
    try:
        with os.fdopen(fd, "w") as fh:
            json.dump(doc, fh, indent=1, sort_keys=True)
            fh.write("\n")
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise

    if changed:
        print(f"PASS  identity — merged {', '.join(changed)} into {path}")
    else:
        print(f"PASS  identity — {path} already carries every value (unchanged)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
