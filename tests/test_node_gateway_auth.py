#!/usr/bin/env python3
"""Hermetic tests for scripts/node_gateway_auth.py — the dashboard.basic_auth presence check.

CF-292. The module used to decide presence by scanning a fixed eight-line window after
`dashboard:`, which produced two measured false verdicts, both of them confirmed against the real
consumer gate (`scripts/harness/install-hermes.sh`, `check_public_bind_auth`):

  * a `basic_auth:` belonging to a SIBLING top-level key that happened to fall inside the window
    was certified as protection — false PASS, exit 0, while the gate refused the same file;
  * a genuine `dashboard.basic_auth:` more than seven lines below `dashboard:` was refused —
    false FAIL, exit 2, aborting a provisioning run on a node the gate accepts.

Presence is now read structurally: the block is the run of indented, blank and comment lines after
`dashboard:` and it ends at the first non-blank, non-comment column-0 line; only a `basic_auth:` that
is a DIRECT child of `dashboard:` counts — its indentation equals the block's child indent, which is
what the consumer gate's YAML parse reads at depth 1. A sibling top-level key's `basic_auth:`, a
`basic_auth:` under one of dashboard's own child keys, and a column-0 `basic_auth:` of its own are
all not protection. The two measured arms are regressions here: each one must keep the verdict the
consumer gate already gave the same file.

Everything runs in a tempfile home — no network, no gateway, no real `~/.hermes`.
"""

from __future__ import annotations

import contextlib
import hashlib
import io
import os
import stat
import sys
import tempfile
import unittest

sys.path.insert(
    0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts")
)
import node_gateway_auth  # noqa: E402


def sha256(path: str) -> str:
    with open(path, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def password_in(config: str) -> str:
    with open(config, encoding="utf-8") as fh:
        for line in fh:
            bare = line.strip()
            if bare.startswith("password:"):
                return bare.split(":", 1)[1].strip()
    raise AssertionError("no password line in the config")


class GatewayAuth(unittest.TestCase):
    def setUp(self):
        self.home = tempfile.mkdtemp(prefix="gateway-auth-")
        self.addCleanup(self._cleanup)
        self.config = os.path.join(self.home, ".hermes", "config.yaml")
        self.pass_file = os.path.join(self.home, ".node", "auth", "gateway.pass")

    def _cleanup(self):
        for root, dirs, _ in os.walk(self.home):
            for name in dirs:
                os.chmod(os.path.join(root, name), 0o700)
        os.chmod(self.home, 0o700)
        import shutil

        shutil.rmtree(self.home, ignore_errors=True)

    def write_config(self, body: str) -> str:
        os.makedirs(os.path.dirname(self.config), mode=0o700, exist_ok=True)
        with open(self.config, "w", encoding="utf-8") as fh:
            fh.write(body)
        return self.config

    def run_main(self, argv=None):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            rc = node_gateway_auth.main(
                [self.config, self.pass_file] if argv is None else list(argv)
            )
        return rc, out.getvalue(), err.getvalue()

    # 1. the fresh-node case this module exists for
    def test_absent_config_gets_the_block_at_mode_600(self):
        rc, out, err = self.run_main()
        self.assertEqual(rc, 0, err)
        self.assertIn("added dashboard.basic_auth (user node)", out)
        with open(self.config, encoding="utf-8") as fh:
            text = fh.read()
        for line in (
            "dashboard:\n",
            "  basic_auth:\n",
            "    username: node\n",
            "    password: ",
        ):
            self.assertIn(line, text)
        self.assertEqual(stat.S_IMODE(os.stat(self.config).st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(os.stat(self.pass_file).st_mode), 0o600)
        password = password_in(self.config)
        self.assertEqual(
            len(password), 32, "secrets.token_urlsafe(24) is 32 characters"
        )
        self.assertNotIn(password, out + err, "the password must never be printed")
        with open(self.pass_file, encoding="utf-8") as fh:
            self.assertEqual(fh.read(), password + "\n")

    # 2. a re-run changes nothing
    def test_second_run_is_idempotent(self):
        self.assertEqual(self.run_main()[0], 0)
        before = sha256(self.config)
        rc, out, err = self.run_main()
        self.assertEqual(rc, 0, err)
        self.assertIn("already present", out)
        self.assertEqual(sha256(self.config), before, "the config was rewritten")

    # 3. false PASS (appendix §3 arm 6): a sibling top-level key's basic_auth is not protection
    def test_basic_auth_under_a_sibling_top_level_key_is_refused(self):
        self.write_config(
            "server:\n"
            "  host: 0.0.0.0\n"
            "dashboard:\n"
            "  theme: dark\n"
            "other:\n"
            "  basic_auth:\n"
            "    username: x\n"
            "    password: y\n"
        )
        before = sha256(self.config)
        rc, out, err = self.run_main()
        self.assertEqual(
            rc, 2, f"a sibling key's basic_auth was certified as protection: {out}"
        )
        self.assertEqual(out, "")
        self.assertIn("has a dashboard block without basic_auth", err)
        self.assertEqual(
            sha256(self.config), before, "a refusal must leave the file untouched"
        )
        self.assertFalse(
            os.path.exists(self.pass_file), "a refusal must not write a secret"
        )

    # 4. false FAIL (appendix §3 arm 7): a deep, commented, blank-separated block still counts
    def test_deep_nested_basic_auth_passes(self):
        self.write_config(
            "dashboard:\n"
            "  theme: dark\n"
            "  lang: en\n"
            "  port: 8080\n"
            "  k1: 1\n"
            "  k2: 2\n"
            "  k3: 3\n"
            "  k4: 4\n"
            "  k5: 5\n"
            "\n"
            "  # credentials live here\n"
            "  basic_auth:\n"
            "    username: node\n"
            "    password: secret\n"
        )
        before = sha256(self.config)
        rc, out, err = self.run_main()
        self.assertEqual(rc, 0, f"a real nested basic_auth was refused: {err}")
        self.assertIn("already present", out)
        self.assertEqual(
            sha256(self.config), before, "an existing block must not be rewritten"
        )

    # 4b. review finding 0: a `basic_auth:` hanging off a CHILD key is dashboard.child.basic_auth,
    # which the consumer gate refuses — accepting any indented line certified it as protection
    def test_basic_auth_under_a_child_key_is_refused(self):
        self.write_config(
            "dashboard:\n"
            "  theme: dark\n"
            "  child:\n"
            "    basic_auth:\n"
            "      username: u\n"
            "      password: p\n"
        )
        before = sha256(self.config)
        rc, out, err = self.run_main()
        self.assertEqual(
            rc, 2, f"a basic_auth under a child key was certified as protection: {out}"
        )
        self.assertEqual(out, "")
        self.assertIn("has a dashboard block without basic_auth", err)
        self.assertEqual(
            sha256(self.config), before, "a refusal must leave the file untouched"
        )
        self.assertFalse(
            os.path.exists(self.pass_file), "a refusal must not write a secret"
        )

    # 4c. the child indent is whatever the block uses — the rule is equality, not "two spaces"
    def test_basic_auth_at_a_four_space_child_indent_passes(self):
        self.write_config(
            "dashboard:\n"
            "    theme: dark\n"
            "    basic_auth:\n"
            "        username: node\n"
            "        password: secret\n"
        )
        before = sha256(self.config)
        rc, out, err = self.run_main()
        self.assertEqual(
            rc, 0, f"a direct child at a four-space indent was refused: {err}"
        )
        self.assertIn("already present", out)
        self.assertEqual(sha256(self.config), before)

    # 5. the documented refusal, unchanged
    def test_dashboard_block_without_basic_auth_is_refused(self):
        self.write_config("dashboard:\n  theme: dark\n")
        before = sha256(self.config)
        rc, out, err = self.run_main()
        self.assertEqual(rc, 2, out)
        self.assertEqual(out, "")
        self.assertIn("has a dashboard block without basic_auth", err)
        self.assertIn("left untouched (a human must reconcile it)", err)
        self.assertEqual(sha256(self.config), before)

    # 6. the usage contract
    def test_usage_error(self):
        rc, out, err = self.run_main(argv=[])
        self.assertEqual(rc, 2)
        self.assertEqual(out, "", "usage goes to stderr only")
        self.assertIn(
            "usage: node_gateway_auth.py <config.yaml> <password-file> [username]", err
        )

    # 7. a basic_auth inside a sibling block AFTER the dashboard block ends is outside it
    def test_basic_auth_after_the_block_is_refused(self):
        self.write_config(
            "dashboard:\n"
            "  theme: dark\n"
            "other:\n"
            "  basic_auth:\n"
            "    username: x\n"
            "    password: y\n"
        )
        before = sha256(self.config)
        rc, out, err = self.run_main()
        self.assertEqual(rc, 2, f"a basic_auth outside the block was certified: {out}")
        self.assertEqual(out, "")
        self.assertIn("has a dashboard block without basic_auth", err)
        self.assertEqual(sha256(self.config), before)

    # a top-level `basic_auth:` key of its own is not a child of dashboard
    def test_top_level_basic_auth_key_is_refused(self):
        self.write_config(
            "dashboard:\n  theme: dark\nbasic_auth:\n  username: x\n  password: y\n"
        )
        rc, out, err = self.run_main()
        self.assertEqual(rc, 2, f"a column-0 basic_auth was counted as nested: {out}")
        self.assertIn("has a dashboard block without basic_auth", err)

    # comments never end the block, at any indentation (the consumer gate strips them first)
    def test_column_zero_comment_does_not_end_the_block(self):
        self.write_config(
            "dashboard:\n"
            "  theme: dark\n"
            "# the credential follows\n"
            "  basic_auth:\n"
            "    username: node\n"
            "    password: secret\n"
        )
        rc, out, err = self.run_main()
        self.assertEqual(rc, 0, err)
        self.assertIn("already present", out)

    # review finding 2: a column-0 comment BETWEEN the block and the next top-level key does not
    # extend the block over that key — the sibling's basic_auth stays outside it
    def test_column_zero_comment_before_a_sibling_key_does_not_extend_the_block(self):
        self.write_config(
            "dashboard:\n"
            "  theme: dark\n"
            "# a note between the block and the next top-level key\n"
            "other:\n"
            "  basic_auth:\n"
            "    username: x\n"
            "    password: y\n"
        )
        before = sha256(self.config)
        rc, out, err = self.run_main()
        self.assertEqual(
            rc, 2, f"a sibling key's basic_auth past a comment was certified: {out}"
        )
        self.assertEqual(out, "")
        self.assertIn("has a dashboard block without basic_auth", err)
        self.assertEqual(
            sha256(self.config), before, "a refusal must leave the file untouched"
        )
        self.assertFalse(
            os.path.exists(self.pass_file), "a refusal must not write a secret"
        )

    # 8. a write failure is the module's own exit 1 line, never a traceback
    @unittest.skipIf(
        os.geteuid() == 0, "root ignores the directory mode that makes the write fail"
    )
    def test_unwritable_config_directory_is_a_named_failure(self):
        self.write_config("server:\n  host: 0.0.0.0\n")
        config_dir = os.path.dirname(self.config)
        os.chmod(config_dir, 0o500)
        self.addCleanup(os.chmod, config_dir, 0o700)
        rc, out, err = self.run_main()
        self.assertEqual(rc, 1, out)
        self.assertEqual(out, "")
        self.assertIn("FAIL  gateway_auth — cannot write", err)
        self.assertNotIn("Traceback", err)

    # 9. the password-file branch of the same contract: exit 1, the path named, config untouched.
    # The failure is forced by making the password file's PARENT a regular file, so os.makedirs
    # raises NotADirectoryError for every user — root included, unlike a directory mode.
    def test_unwritable_password_file_is_a_named_failure(self):
        self.write_config("server:\n  host: 0.0.0.0\n")
        blocker = os.path.join(self.home, ".node")
        with open(blocker, "w", encoding="utf-8") as fh:
            fh.write("not a directory\n")
        before = sha256(self.config)
        rc, out, err = self.run_main()
        self.assertEqual(rc, 1, out)
        self.assertEqual(out, "", "a failure must not report success on stdout")
        self.assertIn(f"FAIL  gateway_auth — cannot write {self.pass_file}", err)
        self.assertIn("[Errno 20] Not a directory", err, "the OSError must be named")
        self.assertNotIn("Traceback", err)
        self.assertEqual(
            sha256(self.config), before, "no block may be appended after a failed write"
        )
        with open(blocker, encoding="utf-8") as fh:
            self.assertEqual(
                fh.read(), "not a directory\n", "the blocking file must be left alone"
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
