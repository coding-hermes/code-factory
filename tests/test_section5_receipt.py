#!/usr/bin/env python3
"""Hermetic tests for the §5 variable contract on the receiving side (CF-229, AC4).

`specs/HARNESS-MATRIX.md` §5 fixes the set of names a dispatch may carry. The installers are held
to it by `tests/harness-conformance.sh`; the *bus worker* is held to it here — it must take the
directive's `vars` object, hand exactly that set to the harness child, and record WHICH values it
passed (name -> {set, len}) without ever recording a value. The last two tests are the failure
path, so this file can go red: a name outside §5 and a credential smuggled in as a value are both
refused by name.

Run directly: `python3 tests/test_section5_receipt.py` — exit 0 on success, 1 on failure.
No network, no credential, no install.
"""

from __future__ import annotations

import importlib.util
import os
import shutil
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
WORKER = os.path.join(HERE, os.pardir, "scripts", "node-bus-worker.py")


def load_worker():
    """Import scripts/node-bus-worker.py, whose filename is not a valid module name."""
    spec = importlib.util.spec_from_file_location("cf_bus_worker", WORKER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


WORKER_MOD = load_worker()


class Ident:
    """The slice of the node identity `harness_env` reads."""

    def __init__(self, home):
        self.home = home


class Section5ReceiptTest(unittest.TestCase):
    def setUp(self):
        self.home = tempfile.mkdtemp(prefix="cf229-section5-")
        self.addCleanup(shutil.rmtree, self.home, ignore_errors=True)
        self.repo = os.path.join(self.home, "repo")
        self.skills = os.path.join(self.home, "skills")
        self.keyfile = os.path.join(self.home, "api.key")
        os.makedirs(self.repo)
        os.makedirs(self.skills)
        with open(self.keyfile, "w", encoding="utf-8") as fh:
            fh.write("fixture-not-a-real-credential\n")
        os.chmod(self.keyfile, 0o600)

    def full_set(self):
        return {
            "CF_MODEL": "fixture-model-1",
            "CF_PROVIDER": "fixture",
            "CF_BASE_URL": "http://127.0.0.1:9/v1",
            "CF_API_KEY_FILE": self.keyfile,
            "CF_WORKDIR": self.repo,
            "CF_NAMESPACE": "code-factory",
            "CF_RUN_ID": "cf229-section5-run",
            "CF_LANE": "code-factory",
            "CF_SKILLS_DIR": self.skills,
            "CF_HARNESS_OPTS": "temperature=0",
            "CF_MAX_TURNS": "7",
            "CF_TIMEOUT_S": "120",
        }

    def test_every_declared_name_is_accepted_from_the_directive(self):
        values, problems = WORKER_MOD.directive_vars({"vars": self.full_set()}, self.home)
        self.assertEqual([], problems, f"the full §5 set was refused: {problems}")
        missing = [n for n in WORKER_MOD.SECTION5_VARS if n not in values]
        self.assertEqual([], missing, f"declared names dropped on the way in: {missing}")

    def test_receipt_records_which_values_were_passed_without_recording_them(self):
        values, _ = WORKER_MOD.directive_vars({"vars": self.full_set()}, self.home)
        receipt = WORKER_MOD.section5_receipt(values)
        self.assertEqual(
            set(WORKER_MOD.SECTION5_VARS), set(receipt),
            "the receipt does not cover the declared set",
        )
        for name in WORKER_MOD.SECTION5_VARS:
            with self.subTest(name=name):
                self.assertTrue(receipt[name]["set"], f"{name} passed but not recorded as set")
                self.assertEqual({"set", "len"}, set(receipt[name]),
                                 f"{name} receipt entry carries more than set/len")
        self.assertNotIn(self.keyfile, repr(receipt),
                         "the receipt recorded the credential path's value")

    def test_partial_set_is_still_reported_name_by_name(self):
        values, problems = WORKER_MOD.directive_vars(
            {"vars": {"CF_MODEL": "m", "CF_PROVIDER": "p"}}, self.home)
        self.assertEqual([], problems)
        receipt = WORKER_MOD.section5_receipt(values)
        self.assertTrue(receipt["CF_MODEL"]["set"])
        self.assertFalse(receipt["CF_LANE"]["set"],
                         "a name the directive did not carry must read as unset, not vanish")

    def test_harness_env_carries_the_directive_set_and_scrubs_ambient_cf(self):
        values, _ = WORKER_MOD.directive_vars({"vars": self.full_set()}, self.home)
        ambient = {"CF_LANE": "ambient-lane", "CF_SMUGGLED": "nope"}
        saved = {k: os.environ.get(k) for k in ambient}
        os.environ.update(ambient)
        try:
            env = WORKER_MOD.harness_env(Ident(self.home), values)
        finally:
            for key, prior in saved.items():
                if prior is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = prior
        self.assertEqual("code-factory", env.get("CF_LANE"),
                         "the directive's CF_LANE lost to the ambient environment")
        self.assertNotIn("CF_SMUGGLED", env,
                         "an ambient CF_* the directive never named reached the harness")

    def test_a_name_outside_section5_is_refused_by_name(self):
        _, problems = WORKER_MOD.directive_vars(
            {"vars": dict(self.full_set(), CF_NOT_DECLARED="x")}, self.home)
        self.assertTrue(any("CF_NOT_DECLARED" in p for p in problems),
                        f"an undeclared name was accepted silently: {problems}")

    def test_a_credential_as_a_value_is_refused_by_name(self):
        secret = "sk-" + "fixture-not-real"
        _, problems = WORKER_MOD.directive_vars(
            {"vars": dict(self.full_set(), CF_API_KEY_FILE=secret)}, self.home)
        self.assertTrue(any("CF_API_KEY_FILE" in p for p in problems),
                        f"a credential VALUE was accepted as a path: {problems}")
        self.assertFalse(any(secret in p for p in problems),
                         "the refusal echoed the credential it refused")


if __name__ == "__main__":
    unittest.main(verbosity=2)
