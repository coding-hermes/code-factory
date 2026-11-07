#!/usr/bin/env python3
"""Hermetic coverage for the scan-scope gate's surface resolution (CF-307).

``check_scan_scope.py`` is a posture gate, so its own failure path has to be
falsifiable: the pre-CF-307 code resolved its surface with ``Path.glob()`` and
``candidate.exists()``, which turn an unreadable directory and a dangling
symlink into an empty selection and print ``OK  audit-scope: no posture docs
found`` — a green the tool never measured. Every arm below builds its own
``tempfile.mkdtemp()`` tree and asserts the exact return code AND that the
output line names the reason, so "surface read and empty" can never be
confused with "surface could not be read".

Arms: (a) unreadable ``docs/audits`` -> 2, (b) dangling fixed-file symlink -> 2,
(c) root one level off -> 2, (d) readable but empty surface -> 0 and it says so,
(e) an unscoped claim -> 1, (f) a scoped claim -> 0.
"""

from __future__ import annotations

import contextlib
import io
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import check_scan_scope  # noqa: E402

UNSCOPED = "| Secrets | `gitleaks detect -c .gitleaks.toml --redact` | clean |"
SCOPED = '| Secrets | `gitleaks detect --log-opts="--all"` | clean |'


class ScanScopeSurface(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp(prefix="scan-scope-"))
        self.restore: list[Path] = []
        self.addCleanup(self.cleanup)

    def cleanup(self):
        # A mode-000 fixture cannot be traversed or removed: restore it first.
        for path in self.restore:
            try:
                os.chmod(path, 0o755)
            except OSError:
                pass
        for dirpath, dirnames, _ in os.walk(self.root):
            for name in dirnames:
                try:
                    os.chmod(os.path.join(dirpath, name), 0o755)
                except OSError:
                    pass
        try:
            os.chmod(self.root, 0o755)
        except OSError:
            pass
        shutil.rmtree(self.root, ignore_errors=True)

    def tree(self, name: str) -> Path:
        """A fixture root with a readable gap under docs/audits."""
        root = self.root / name
        (root / "docs" / "audits").mkdir(parents=True)
        return root

    def run_gate(self, root: Path) -> tuple[int, str]:
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            rc = check_scan_scope.main([str(root)])
        return rc, buffer.getvalue()

    def doc(self, root: Path, line: str) -> Path:
        path = root / "docs" / "audits" / "code-factory-releng-fixture.md"
        path.write_text(line + "\n", encoding="utf-8")
        return path

    def test_a_unreadable_audit_dir(self):
        if os.geteuid() == 0:
            self.fail(
                "arm (a) cannot be measured as root: mode 000 does not deny root,"
                " so a green here would be unearned"
            )
        root = self.tree("a")
        audits = root / "docs" / "audits"
        os.chmod(audits, 0o000)
        self.restore.append(audits)
        rc, out = self.run_gate(root)
        self.assertEqual(rc, 2, out)
        self.assertIn(str(audits), out)
        self.assertIn("unreadable", out)
        self.assertIn("RESULT: FAIL (unreadable path)", out)
        self.assertNotIn("no posture docs found", out)

    def test_b_dangling_fixed_file_symlink(self):
        root = self.tree("b")
        link = root / "docs" / "SECURITY-TRIAGE.md"
        target = root / "docs" / "absent-triage.md"
        link.symlink_to(target)
        rc, out = self.run_gate(root)
        self.assertEqual(rc, 2, out)
        self.assertIn("docs/SECURITY-TRIAGE.md", out)
        self.assertIn("dangling symlink", out)
        self.assertIn(str(target), out)
        self.assertIn("RESULT: FAIL (unreadable path)", out)
        self.assertNotIn("no posture docs found", out)

    def test_c_root_one_level_off(self):
        root = self.tree("c")
        self.doc(root, SCOPED)
        passed = root / "docs"
        rc, out = self.run_gate(passed)
        self.assertEqual(rc, 2, out)
        # The message names the exact path the gate looked for under that root.
        self.assertIn(str(passed / "docs" / "audits"), out)
        self.assertIn("missing", out)
        self.assertIn("RESULT: FAIL (unreadable path)", out)
        self.assertNotIn("no posture docs found", out)

    def test_d_empty_surface_is_read_not_green_by_accident(self):
        root = self.tree("d")
        rc, out = self.run_gate(root)
        self.assertEqual(rc, 0, out)
        self.assertIn("audit surface read, 0 posture docs", out)
        self.assertIn("RESULT: OK", out)
        # The empty-but-read green must be distinguishable from the arm (a) red.
        broken = self.tree("d-unreadable")
        broken_audits = broken / "docs" / "audits"
        os.chmod(broken_audits, 0o000)
        self.restore.append(broken_audits)
        broken_rc, broken_out = self.run_gate(broken)
        self.assertEqual(broken_rc, 2, broken_out)
        self.assertNotEqual(rc, broken_rc)
        self.assertNotIn("audit surface read, 0 posture docs", broken_out)

    def test_e_unscoped_claim_fails(self):
        root = self.tree("e")
        self.doc(root, UNSCOPED)
        rc, out = self.run_gate(root)
        self.assertEqual(rc, 1, out)
        self.assertIn(
            "FAIL  audit-scope: docs/audits/code-factory-releng-fixture.md:1"
            " gitleaks claim names no --log-opts",
            out,
        )
        self.assertIn("RESULT: FAIL (1 violation(s))", out)

    def test_f_scoped_claim_passes(self):
        root = self.tree("f")
        self.doc(root, SCOPED)
        rc, out = self.run_gate(root)
        self.assertEqual(rc, 0, out)
        self.assertIn("OK  audit-scope: 1 gitleaks claim(s) name their --log-opts", out)
        self.assertIn("RESULT: OK", out)

    def test_g_absent_optional_file_is_named_not_silent(self):
        root = self.tree("g")
        self.doc(root, SCOPED)
        rc, out = self.run_gate(root)
        self.assertEqual(rc, 0, out)
        self.assertIn("docs/SECURITY-TRIAGE.md not present — not read", out)


if __name__ == "__main__":
    unittest.main(verbosity=2)
