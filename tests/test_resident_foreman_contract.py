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


CANCELLATION_REQUEST_FIELDS = {
    "request_id",
    "expected_state_version",
    "reason",
    "launch_id",
    "execution_key",
    "boot_id",
    "process_instance_id",
    "native_session_id",
}
CANCELLATION_IDENTITY_FIELDS = (
    "launch_id",
    "execution_key",
    "boot_id",
    "process_instance_id",
    "native_session_id",
)


def cancel_run(expected: dict, request: dict) -> dict:
    """Model exact-run cancellation; no process signalling occurs on mismatch."""
    response = {
        "request_id": request.get("request_id"),
        "accepted": False,
        "state": expected["state"],
        "state_version": expected["state_version"],
        "signal": None,
    }
    if set(request) != CANCELLATION_REQUEST_FIELDS:
        response["error"] = "INVALID_FIELD"
        return response
    if request["expected_state_version"] != expected["state_version"]:
        response["error"] = "STATE_CONFLICT"
        return response
    if any(request[field] != expected[field] for field in CANCELLATION_IDENTITY_FIELDS):
        response["error"] = "IDENTITY_CONFLICT"
        return response
    response.update(
        {
            "accepted": True,
            "state": "cancelled",
            "state_version": expected["state_version"] + 1,
            "signal": expected["process_instance_id"],
        }
    )
    return response


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
    if set(expected) != {
        "state",
        "state_version",
        *CANCELLATION_IDENTITY_FIELDS,
    }:
        raise AssertionError("cancellation expected record has the wrong shape")
    for case in cancellation["cases"]:
        request = case["request"]
        if set(request) != CANCELLATION_REQUEST_FIELDS:
            raise AssertionError(f"cancellation request shape mismatch: {case['name']}")
        observed = cancel_run(expected, request)
        if observed != case["response"]:
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
        self.assertEqual(cancel_run(expected, case["request"]), case["response"])

    def test_cancellation_request_and_response_fields_are_registered(self) -> None:
        cancellation = self.contract["cancellation"]
        self.assertEqual(
            set(cancellation["request_fields"]), CANCELLATION_REQUEST_FIELDS
        )
        self.assertEqual(
            set(cancellation["response_fields"]),
            {"request_id", "accepted", "state", "state_version", "signal", "error"},
        )

    def test_missing_native_session_id_or_version_is_rejected(self) -> None:
        expected = self.contract["cancellation"]["expected"]
        request = copy.deepcopy(self.contract["cancellation"]["cases"][0]["request"])
        request.pop("native_session_id")
        self.assertEqual(cancel_run(expected, request)["error"], "INVALID_FIELD")
        request = copy.deepcopy(self.contract["cancellation"]["cases"][0]["request"])
        request.pop("expected_state_version")
        self.assertEqual(cancel_run(expected, request)["error"], "INVALID_FIELD")

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
        self.assertIn("resident_foreman_contract", m2)
        self.assertIn("resident_foreman_contract", m5)
        self.assertIn("single offline vector source", m2)
        self.assertNotIn("native_id:ID|null", m5)
        self.assertNotIn("exact `native_name`", m2 + m5)
        self.assertNotIn("native_name`,", m2 + m5)
        for field in (
            "request_id",
            "expected_state_version",
            "reason",
            "native_session_id",
        ):
            self.assertIn(field, m5)
        self.assertIn("offline", m5)
        self.assertIn("unverified", m5)
        self.assertIn("native_session_id", m2)


# ch:trace row=P5G-13 spec=docs/handbook/OUTLINE.md#f1-dispatch-and-settlement wave=none:serial-worker test=tests/test_resident_foreman_contract.py::ResidentForemanContractTest doc=docs/handbook/chapters/M5-harness.md evidence=docs/handbook/contract-vectors.json witness=none:offline-specification-and-deterministic-fixture verdict=none:foreman-gitreins-pending commit=none:foreman-closeout memory=none:foreman-writes
# STATUS: partial
# TIER: T1
# EVIDENCE: docs/handbook/contract-vectors.json


if __name__ == "__main__":
    unittest.main()
