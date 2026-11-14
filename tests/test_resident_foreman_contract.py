#!/usr/bin/env python3
"""Offline contract checks for the P5G-13 resident foreman surface."""

from __future__ import annotations

import copy
import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
VECTOR_PATH = ROOT / "docs" / "handbook" / "contract-vectors.json"
M5_PATH = ROOT / "docs" / "handbook" / "chapters" / "M5-harness.md"
M2_PATH = ROOT / "docs" / "handbook" / "chapters" / "M2-dispatch.md"

REQUIRED_PROTOCOLS = {
    "supervisor.v1",
    "cf.native.v1",
    "cf.native-event.v1",
}
REQUIRED_IDENTITIES = {
    "launch_id",
    "execution_key",
    "boot_id",
    "process_instance_id",
    "native_session_id",
    "state_version",
}


def load_vectors() -> dict:
    with VECTOR_PATH.open(encoding="utf-8") as handle:
        return json.load(handle)


def cancel_run(expected: dict, request: dict) -> dict:
    """Model exact-run cancellation; no process signalling occurs on mismatch."""
    if request.get("state_version") != expected["state_version"]:
        return {"accepted": False, "error": "STATE_CONFLICT", "signal": None}
    identity = (
        "launch_id",
        "execution_key",
        "boot_id",
        "process_instance_id",
        "native_session_id",
    )
    if any(request.get(field) != expected[field] for field in identity):
        return {"accepted": False, "error": "IDENTITY_CONFLICT", "signal": None}
    return {"accepted": True, "signal": expected["process_instance_id"]}


def recover_after_reboot(case: dict) -> dict:
    """Model journal replay/discovery, explicitly excluding relaunch."""
    if case["native_proof"] == "unproven":
        return {"action": "quarantine", "relaunch": False, "admission": False}
    if case["journal_state"] == "terminal":
        return {"action": "replay", "relaunch": False, "admission": True}
    return {"action": "reattach", "relaunch": False, "admission": True}


def validate_contract(document: dict) -> None:
    contract = document["resident_foreman_contract"]
    if set(contract["protocols"]) != REQUIRED_PROTOCOLS:
        raise AssertionError("resident/native protocol vocabulary drifted")
    if set(contract["identity_fields"]) != REQUIRED_IDENTITIES:
        raise AssertionError("resident identity vocabulary is incomplete")

    cancellation = contract["cancellation"]
    expected = cancellation["expected"]
    for case in cancellation["cases"]:
        observed = cancel_run(expected, case["request"])
        wanted = {key: case[key] for key in ("accepted", "signal") if key in case}
        if "error" in case:
            wanted["error"] = case["error"]
        if observed != wanted:
            raise AssertionError(f"cancellation case mismatch: {case['name']}")

    recovery = contract["reboot_recovery"]
    for case in recovery["cases"]:
        observed = recover_after_reboot(case)
        wanted = {key: case[key] for key in ("action", "relaunch", "admission")}
        if observed != wanted:
            raise AssertionError(f"recovery case mismatch: {case['name']}")
    if recovery["admission_when_unproven"] is not False:
        raise AssertionError("unproven reboot recovery must keep admission closed")


class ResidentForemanContractTest(unittest.TestCase):
    def setUp(self) -> None:
        self.document = load_vectors()
        validate_contract(self.document)
        self.contract = self.document["resident_foreman_contract"]

    def test_vectors_parse_and_contract_is_versioned(self) -> None:
        self.assertEqual(
            self.contract["schema_version"], "cf.resident-foreman-contract.v1"
        )
        self.assertEqual(set(self.contract["protocols"]), REQUIRED_PROTOCOLS)

    def test_matching_identity_signals_only_expected_process(self) -> None:
        expected = self.contract["cancellation"]["expected"]
        case = self.contract["cancellation"]["cases"][0]
        self.assertEqual(
            cancel_run(expected, case["request"]),
            {"accepted": True, "signal": "process-1"},
        )

    def test_stale_version_and_reused_pid_never_signal(self) -> None:
        expected = self.contract["cancellation"]["expected"]
        for case in self.contract["cancellation"]["cases"][1:]:
            with self.subTest(case=case["name"]):
                result = cancel_run(expected, case["request"])
                self.assertFalse(result["accepted"])
                self.assertIsNone(result["signal"])
                self.assertIn(result["error"], {"STATE_CONFLICT", "IDENTITY_CONFLICT"})

    def test_reboot_recovery_replays_or_reattaches_without_relaunch(self) -> None:
        for case in self.contract["reboot_recovery"]["cases"]:
            with self.subTest(case=case["name"]):
                result = recover_after_reboot(case)
                self.assertFalse(result["relaunch"])
                self.assertEqual(result["admission"], case["admission"])
                self.assertEqual(result["action"], case["action"])

    def test_mutation_control_rejects_identity_and_recovery_weakening(self) -> None:
        mutated = copy.deepcopy(self.document)
        mutated["resident_foreman_contract"]["identity_fields"].remove(
            "native_session_id"
        )
        with self.assertRaises(AssertionError):
            validate_contract(mutated)

        mutated = copy.deepcopy(self.document)
        unknown = mutated["resident_foreman_contract"]["reboot_recovery"]["cases"][2]
        unknown["admission"] = True
        with self.assertRaises(AssertionError):
            validate_contract(mutated)

    def test_handbook_uses_the_same_protocol_and_identity_terms(self) -> None:
        m5 = M5_PATH.read_text(encoding="utf-8")
        m2 = M2_PATH.read_text(encoding="utf-8")
        combined = m5 + "\n" + m2
        for term in (
            REQUIRED_PROTOCOLS
            | REQUIRED_IDENTITIES
            | {"reboot", "recovery", "cancellation"}
        ):
            self.assertIn(term, combined, term)
        self.assertIn("admission=false", m5)
        self.assertIn("Journal replay/discovery", m5)
        self.assertNotIn("native_id:ID|null", m5)


# ch:trace row=P5G-13 spec=docs/handbook/OUTLINE.md#f1-dispatch-and-settlement wave=none:serial-worker test=tests/test_resident_foreman_contract.py::ResidentForemanContractTest doc=docs/handbook/chapters/M5-harness.md evidence=docs/handbook/contract-vectors.json witness=none:specification-and-offline-deterministic-fixture verdict=none:foreman-gitreins-pending commit=none:foreman-closeout memory=none:foreman-writes
# STATUS: complete
# TIER: T1
# EVIDENCE: docs/handbook/contract-vectors.json


if __name__ == "__main__":
    unittest.main()
