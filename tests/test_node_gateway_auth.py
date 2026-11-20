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

CF-395 closed the rest of the contract, and each rule has its own arms below: a valueless
`basic_auth:` (or one whose `username`/`password` is empty, quoted-empty or not a string) is the
gate's "empty value" rather than protection, and a `dashboard:` block whose children disagree on
indentation is "invalid YAML" rather than a pass or an absent block. `--check` is the read-only
verdict `scripts/project-node.sh --check` delegates to, and it is tested both for the vocabulary it
speaks and for the fact that it writes nothing.

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

    def run_check(self, path=None):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            rc = node_gateway_auth.main(["--check", path or self.config])
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

    # 10. CF-395 arm (b): a valueless `basic_auth:` is an EMPTY VALUE, not protection. Before this
    # arm the module tested membership of the key and never its two strings, so it certified a node
    # the consumer gate refuses with "empty value (username and password must both be non-empty)".
    def test_empty_basic_auth_is_refused_as_an_empty_value(self):
        self.write_config("dashboard:\n  basic_auth:\n")
        before = sha256(self.config)
        rc, out, err = self.run_main()
        self.assertEqual(rc, 2, f"a valueless basic_auth was certified: {out}")
        self.assertEqual(out, "", "a refusal must not report success")
        self.assertIn("empty value", err)
        self.assertIn("username and password must both be non-empty", err)
        self.assertNotIn("without basic_auth", err)
        self.assertEqual(sha256(self.config), before)
        self.assertFalse(os.path.exists(self.pass_file))

    # 10b. the same rule where the children exist but spell nothing: quoted-empty is empty.
    def test_basic_auth_with_quoted_empty_children_is_refused(self):
        self.write_config(
            'dashboard:\n  basic_auth:\n    username: ""\n    password: ""\n'
        )
        before = sha256(self.config)
        rc, out, err = self.run_main()
        self.assertEqual(rc, 2, f"empty-valued children were certified: {out}")
        self.assertIn("empty value", err)
        self.assertEqual(sha256(self.config), before)

    # 10c. the gate refuses a non-string scalar too (`password: 1234` is not a string), so the
    # module must give the same file the same verdict.
    def test_basic_auth_with_a_non_string_password_is_refused(self):
        self.write_config(
            "dashboard:\n  basic_auth:\n    username: node\n    password: 1234\n"
        )
        rc, out, err = self.run_main()
        self.assertEqual(rc, 2, f"a numeric password was certified: {out}")
        self.assertIn("empty value", err)

    # 10d. ...while a real credential still passes, so the empty-value rule is not a blanket refusal
    def test_basic_auth_with_both_strings_passes(self):
        self.write_config(
            "dashboard:\n  basic_auth:\n    username: node\n    password: secret\n"
        )
        before = sha256(self.config)
        rc, out, err = self.run_main()
        self.assertEqual(rc, 0, err)
        self.assertIn("already present", out)
        self.assertEqual(sha256(self.config), before)

    # 11. CF-395 arm (c): a `dashboard:` whose children disagree on indentation is INVALID YAML.
    # The consumer gate refuses that document outright; the module used to read it as a block and
    # answer "without basic_auth" — a different verdict for the same file.
    def test_mixed_indent_block_is_invalid_yaml(self):
        self.write_config("dashboard:\n  theme: dark\n    lang: en\n")
        before = sha256(self.config)
        rc, out, err = self.run_main()
        self.assertEqual(rc, 2, out)
        self.assertEqual(out, "")
        self.assertIn("invalid YAML", err)
        self.assertNotIn("without basic_auth", err)
        self.assertEqual(sha256(self.config), before)

    # 11b. the mixed-indent shape that used to be a false PASS: `basic_auth:` sat at the block's
    # MINIMUM indent, which the round-2 rule took as the child indent, while the gate pinned the
    # FIRST child and refused the file.
    def test_mixed_indent_block_with_basic_auth_at_the_minimum_is_invalid_yaml(self):
        self.write_config(
            "dashboard:\n"
            "    theme: dark\n"
            "  basic_auth:\n"
            "    username: node\n"
            "    password: secret\n"
        )
        before = sha256(self.config)
        rc, out, err = self.run_main()
        self.assertEqual(rc, 2, f"a mixed-indent block was certified: {out}")
        self.assertIn("invalid YAML", err)
        self.assertEqual(sha256(self.config), before)
        self.assertFalse(os.path.exists(self.pass_file))

    # 11c. the other direction: consistent indentation at a non-default step is still a pass, so
    # the consistency rule does not reject well-formed blocks that merely indent by four.
    def test_consistent_four_space_block_is_not_invalid_yaml(self):
        self.write_config(
            "dashboard:\n"
            "    theme: dark\n"
            "    basic_auth:\n"
            "        username: node\n"
            "        password: secret\n"
        )
        rc, out, err = self.run_main()
        self.assertEqual(rc, 0, err)
        self.assertIn("already present", out)

    # 12. CF-395: `--check` is the read-only verdict scripts/project-node.sh --check delegates to.
    # It speaks the same vocabulary, in one line on stdout, and it changes nothing on disk.
    def test_check_mode_speaks_the_gate_vocabulary(self):
        self.write_config(
            "dashboard:\n  basic_auth:\n    username: node\n    password: secret\n"
        )
        before = sha256(self.config)
        rc, out, err = self.run_check()
        self.assertEqual(rc, 0, err)
        self.assertEqual(out, "gateway_auth: present\n")
        self.assertEqual(err, "")
        self.assertEqual(sha256(self.config), before)

    def test_check_mode_reports_each_refusal_reason(self):
        cases = (
            ("dashboard:\n  theme: dark\n", "gateway_auth: block absent\n", 2),
            ("dashboard:\n  basic_auth:\n", None, 2),
            ("dashboard:\n  theme: dark\n    lang: en\n", None, 2),
            ("", "gateway_auth: block absent\n", 2),
        )
        for body, exact, want_rc in cases:
            with self.subTest(body=body):
                self.write_config(body)
                rc, out, err = self.run_check()
                self.assertEqual(rc, want_rc, err)
                self.assertEqual(err, "", "the verdict is not an error")
                if exact is not None:
                    self.assertEqual(out, exact)
                else:
                    self.assertTrue(out.startswith("gateway_auth: "), out)
                    self.assertIn(
                        out.strip(),
                        (
                            "gateway_auth: empty value (username and password must both be "
                            "non-empty)",
                            "gateway_auth: block absent (invalid YAML)",
                        ),
                    )

    def test_check_mode_writes_nothing(self):
        self.write_config("dashboard:\n  theme: dark\n")
        before = sha256(self.config)
        rc, out, err = self.run_check()
        self.assertEqual(rc, 2, out)
        self.assertEqual(sha256(self.config), before)
        self.assertFalse(
            os.path.exists(self.pass_file), "--check must never write a secret"
        )
        self.assertFalse(
            os.path.exists(os.path.join(self.home, ".node")),
            "--check must not create the state dir",
        )

    def test_check_mode_on_a_missing_config_is_unreadable(self):
        missing = os.path.join(self.home, "absent", "config.yaml")
        rc, out, err = self.run_check(missing)
        self.assertEqual(rc, 1, out)
        self.assertEqual(out, "gateway_auth: block absent (config unreadable)\n")
        self.assertFalse(os.path.exists(os.path.dirname(missing)))

    def test_check_mode_usage_error(self):
        rc, out, err = self.run_main(argv=["--check"])
        self.assertEqual(rc, 2)
        self.assertEqual(out, "")
        self.assertIn("usage: node_gateway_auth.py <config.yaml>", err)


if __name__ == "__main__":
    unittest.main(verbosity=2)
