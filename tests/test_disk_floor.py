#!/usr/bin/env python3
"""Hermetic tests for scripts/disk_floor.py — the configurable node floor (CF-007).

The floor must be configurable AND unambiguous: every precedence rung wins over the
one below it, and a malformed value fails closed instead of silently falling back
to a default (a typo must never lower a floor).
"""

from __future__ import annotations

import os
import sys
import tempfile
import unittest

sys.path.insert(
    0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts")
)
import disk_floor  # noqa: E402


class ParseValue(unittest.TestCase):
    def test_plain_integers(self):
        self.assertEqual(disk_floor.parse_value("7"), 7)
        self.assertEqual(disk_floor.parse_value(12), 12)

    def test_suffixed_values(self):
        for raw in ("7G", "7GiB", "7gib", "7 G"):
            self.assertEqual(disk_floor.parse_value(raw), 7)

    def test_decimal_is_preserved_not_truncated(self):
        # CF-082: a decimal floor used to resolve DOWN (5.9G -> 5), so admission
        # enforced a lower number than the operator wrote.
        self.assertEqual(disk_floor.parse_value("5.9G"), 5.9)
        self.assertEqual(disk_floor.parse_value("5.9"), 5.9)
        self.assertEqual(disk_floor.parse_value(5.9), 5.9)
        self.assertEqual(disk_floor.parse_value("1.5G"), 1.5)

    def test_integral_values_stay_whole_numbers(self):
        # No regression to 5.0-ish output: an integral floor is an int, so the
        # --explain payload and the bare print stay whole numbers.
        for raw in ("5G", "5GiB", "5.0G", "5", 5, 5.0, 12):
            value = disk_floor.parse_value(raw)
            self.assertIsInstance(value, int, f"{raw!r} should parse to an int")
            self.assertEqual(value, 5 if str(raw).startswith("5") else 12)

    def test_three_decimals_are_three_distinct_floors(self):
        floors = [disk_floor.parse_value(v) for v in ("5.1G", "5.5G", "5.9G")]
        self.assertEqual(floors, [5.1, 5.5, 5.9])
        self.assertEqual(len(set(floors)), 3)

    def test_decimal_floor_is_never_below_the_requested_number(self):
        for raw in ("5.1G", "5.5G", "5.9G", "1.9G", "12.25"):
            requested = float(raw.rstrip("G"))
            self.assertGreaterEqual(disk_floor.parse_value(raw), requested)

    def test_bounds_apply_to_the_decimal(self):
        self.assertEqual(disk_floor.parse_value("4096G"), 4096)
        self.assertEqual(disk_floor.parse_value("1.0001G"), 1.0001)
        for raw in ("0.5G", "0.999", "4096.5G"):
            with self.assertRaises(disk_floor.FloorError):
                disk_floor.parse_value(raw)

    def test_non_finite_values_fail_closed(self):
        for raw in (float("nan"), float("inf"), float("-inf")):
            with self.assertRaises(disk_floor.FloorError):
                disk_floor.parse_value(raw)

    def test_rejects_nonsense(self):
        for raw in ("", "lots", "7TB", "-3", "0", "99999", True):
            with self.assertRaises(disk_floor.FloorError):
                disk_floor.parse_value(raw)


class Resolve(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="floor-")

    def _cfg(self, body: str) -> str:
        path = os.path.join(self.tmp, "node.toml")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(body)
        return path

    def test_role_defaults(self):
        for role, expected in disk_floor.ROLE_DEFAULTS.items():
            gib, source = disk_floor.resolve(role=role)
            self.assertEqual((gib, source), (expected, "role-default"))

    def test_cli_beats_env_and_config(self):
        cfg = self._cfg('[disk]\ndefault_gib = "20"\nworker_gib = "15"\n')
        gib, source = disk_floor.resolve("worker", cli="3", env="9", config_path=cfg)
        self.assertEqual((gib, source), (3, "cli"))

    def test_env_beats_config(self):
        cfg = self._cfg('[disk]\nworker_gib = "15"\n')
        gib, source = disk_floor.resolve("worker", env="9", config_path=cfg)
        self.assertEqual((gib, source), (9, "env"))

    def test_config_role_beats_default(self):
        cfg = self._cfg('[disk]\nworker_gib = "15"\ndefault_gib = "20"\n')
        self.assertEqual(
            disk_floor.resolve("worker", config_path=cfg), (15, "config-role")
        )
        # a role with no explicit key falls to [disk] default
        self.assertEqual(
            disk_floor.resolve("builder", config_path=cfg), (20, "config-default")
        )

    def test_missing_config_is_not_an_error(self):
        gib, source = disk_floor.resolve(
            "full", config_path=os.path.join(self.tmp, "absent.toml")
        )
        self.assertEqual((gib, source), (20, "role-default"))

    def test_bad_config_value_fails_closed(self):
        cfg = self._cfg('[disk]\nworker_gib = "plenty"\n')
        with self.assertRaises(disk_floor.FloorError):
            disk_floor.resolve("worker", config_path=cfg)

    def test_bad_cli_fails_closed(self):
        with self.assertRaises(disk_floor.FloorError):
            disk_floor.resolve("worker", cli="big")

    def test_unknown_role_fails(self):
        with self.assertRaises(disk_floor.FloorError):
            disk_floor.resolve("toaster")

    def test_every_rung_preserves_a_decimal_floor(self):
        # CF-082: truncation was not a CLI-only bug — the config rungs fed the same
        # parse_value, so a config decimal was silently lowered the same way.
        cfg = self._cfg('[disk]\nworker_gib = "5.9G"\ndefault = "5.5"\n')
        self.assertEqual(disk_floor.resolve("worker", cli="5.1G"), (5.1, "cli"))
        self.assertEqual(disk_floor.resolve("worker", env="5.5G"), (5.5, "env"))
        self.assertEqual(
            disk_floor.resolve("worker", config_path=cfg), (5.9, "config-role")
        )
        self.assertEqual(
            disk_floor.resolve("builder", config_path=cfg), (5.5, "config-default")
        )
        # The built-in role defaults are whole GiB and stay ints.
        absent = os.path.join(self.tmp, "absent.toml")
        gib, source = disk_floor.resolve("worker", config_path=absent)
        self.assertIsInstance(gib, int)
        self.assertEqual((gib, source), (5, "role-default"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
