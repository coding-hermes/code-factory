#!/usr/bin/env python3
"""Deterministic model check for M2 §15.2 uncertain native-start recovery.

This is specification-model evidence, not a live supervisor qualification.  The
model deliberately exposes the supervisor's durable identity lookup and counts
native launches so that every uncertain path can assert the no-relaunch rule.
"""

from __future__ import annotations

from dataclasses import dataclass, replace


EXECUTION_KEY = "exec-p5g11-001"
NATIVE_NAME = "cf-exec-p5g11-001"
INPUT_DIGEST = "digest-input-a"
CHANGED_DIGEST = "digest-input-b"
BOOT_ID = "boot-a"
NEW_BOOT_ID = "boot-b"
START_TICKS = 4100
NATIVE_SESSION_ID = "session-a"


@dataclass(frozen=True)
class JournalRecord:
    execution_key: str
    native_name: str
    input_digest: str
    state: str = "RESERVED"
    boot_id: str | None = None
    process_start_ticks: int | None = None
    process_instance_id: str | None = None
    native_session_id: str | None = None
    release_observed: bool | None = None
    native_output: bool = False
    result: str | None = None


class RecoveryModel:
    """Small supervisor/launcher model with the §15.2 ordering rules."""

    def __init__(self) -> None:
        self.records: dict[str, JournalRecord] = {}
        self.native_launches = 0
        self.lookups: list[dict[str, object]] = []

    def reserve(self, *, digest: str = INPUT_DIGEST) -> JournalRecord:
        record = JournalRecord(EXECUTION_KEY, NATIVE_NAME, digest)
        self.records[EXECUTION_KEY] = record
        return record

    def lookup(
        self,
        *,
        execution_key: str,
        native_name: str,
        input_digest: str,
        boot_id: str | None = None,
        process_start_ticks: int | None = None,
        native_session_id: str | None = None,
    ) -> JournalRecord | None | str:
        query = {
            "execution_key": execution_key,
            "native_name": native_name,
            "input_digest": input_digest,
            "boot_id": boot_id,
            "process_start_ticks": process_start_ticks,
            "native_session_id": native_session_id,
        }
        self.lookups.append(query)
        record = self.records.get(execution_key)
        if record is None:
            return None
        if record.native_name != native_name or record.input_digest != input_digest:
            return "LAUNCH_CONFLICT"
        for field in ("boot_id", "process_start_ticks", "native_session_id"):
            expected = getattr(record, field)
            observed = query[field]
            if observed is not None and expected != observed:
                return None
        return record

    def create_or_discover(self, *, digest: str = INPUT_DIGEST) -> str:
        found = self.lookup(
            execution_key=EXECUTION_KEY,
            native_name=NATIVE_NAME,
            input_digest=digest,
        )
        if found == "LAUNCH_CONFLICT":
            return "LAUNCH_CONFLICT"
        if isinstance(found, JournalRecord) and found.state != "RESERVED":
            return "DUPLICATE_LOOKUP"
        if found is None:
            self.reserve(digest=digest)
        self.native_launches += 1
        self.records[EXECUTION_KEY] = replace(
            self.records[EXECUTION_KEY],
            state="START_INTENT",
            boot_id=BOOT_ID,
            process_start_ticks=START_TICKS,
            process_instance_id="proc-a",
            native_session_id=NATIVE_SESSION_ID,
            release_observed=False,
        )
        return "NATIVE_LAUNCHED"

    def native_launch(self, *, gated: bool = True) -> None:
        """Represent a launch whose pre-launch intent was already fsynced."""
        record = self.records[EXECUTION_KEY]
        assert record.state == "RESERVED"
        self.native_launches += 1
        self.records[EXECUTION_KEY] = replace(
            record,
            state="START_INTENT",
            boot_id=BOOT_ID,
            process_start_ticks=START_TICKS,
            process_instance_id="proc-a",
            native_session_id=NATIVE_SESSION_ID,
            release_observed=False if gated else None,
        )

    def parent_started(self, *, released: bool | None = None) -> None:
        record = self.records[EXECUTION_KEY]
        assert record.state == "START_INTENT"
        self.records[EXECUTION_KEY] = replace(
            record,
            state="STARTED",
            release_observed=released,
        )

    def release(self) -> None:
        record = self.records[EXECUTION_KEY]
        assert record.state in {"STARTED", "RUNNING"}
        self.records[EXECUTION_KEY] = replace(
            record, release_observed=True, state="RUNNING"
        )

    def native_output_before_parent(self) -> None:
        record = self.records[EXECUTION_KEY]
        assert record.state == "START_INTENT"
        self.records[EXECUTION_KEY] = replace(
            record, native_output=True, state="START_INTENT"
        )

    def terminal(self, result: str = "pass") -> None:
        record = self.records[EXECUTION_KEY]
        self.records[EXECUTION_KEY] = replace(record, state="TERMINAL", result=result)

    def recover(
        self, *, current_boot: str = BOOT_ID, child_present: bool = True
    ) -> str:
        record = self.records[EXECUTION_KEY]
        if record.state == "TERMINAL":
            return "REPLAY_RESULT"
        if record.state == "RESERVED":
            return "UNSTARTED"
        exact = self.lookup(
            execution_key=record.execution_key,
            native_name=record.native_name,
            input_digest=record.input_digest,
            boot_id=record.boot_id,
            process_start_ticks=record.process_start_ticks,
            native_session_id=record.native_session_id,
        )
        if exact == "LAUNCH_CONFLICT":
            return "LAUNCH_CONFLICT"
        if not child_present or exact is None or record.boot_id != current_boot:
            self.records[EXECUTION_KEY] = replace(record, state="START_UNKNOWN")
            return "START_UNKNOWN_QUARANTINE"
        if record.state == "START_INTENT" and record.native_output:
            self.records[EXECUTION_KEY] = replace(record, state="RUNNING")
            return "RECOVER_RUNNING"
        if record.state == "START_INTENT" and record.release_observed is False:
            self.parent_started(released=False)
            self.release()
            return "DISCOVER_START_PERSIST_RELEASE"
        if record.state == "STARTED" and record.release_observed is None:
            self.records[EXECUTION_KEY] = replace(record, state="RUNNING")
            return "DISCOVER_SESSION_NO_RELAUNCH"
        return "DISCOVER_NO_RELAUNCH"


def assert_lookup_shape(model: RecoveryModel) -> None:
    required = {"execution_key", "native_name", "input_digest"}
    assert model.lookups, "recovery must perform a durable identity lookup"
    for query in model.lookups:
        assert required <= query.keys()
        if query["boot_id"] is not None:
            assert query["process_start_ticks"] is not None
            assert query["native_session_id"] is not None


def case_reserved_without_intent() -> None:
    model = RecoveryModel()
    model.reserve()
    assert model.recover() == "UNSTARTED"
    assert model.create_or_discover() == "NATIVE_LAUNCHED"
    assert model.native_launches == 1
    assert model.create_or_discover() == "DUPLICATE_LOOKUP"
    assert model.native_launches == 1
    assert_lookup_shape(model)
    print("PASS RESERVED/no START_INTENT -> UNSTARTED, create-or-discover once")


def case_gated_child() -> None:
    model = RecoveryModel()
    model.reserve()
    model.native_launch()
    assert model.recover() == "DISCOVER_START_PERSIST_RELEASE"
    assert model.records[EXECUTION_KEY].state == "RUNNING"
    assert model.records[EXECUTION_KEY].release_observed is True
    assert model.native_launches == 1
    assert_lookup_shape(model)
    print("PASS START_INTENT gated child -> discover, STARTED, release")


def case_started_release_unknown() -> None:
    model = RecoveryModel()
    model.reserve()
    model.native_launch()
    model.parent_started(released=None)
    assert model.recover() == "DISCOVER_SESSION_NO_RELAUNCH"
    assert model.records[EXECUTION_KEY].native_session_id == NATIVE_SESSION_ID
    assert model.native_launches == 1
    assert_lookup_shape(model)
    print("PASS STARTED/release unknown -> exact session, no relaunch")


def case_output_before_parent_started() -> None:
    model = RecoveryModel()
    model.reserve()
    model.native_launch()
    model.native_output_before_parent()
    assert model.recover() == "RECOVER_RUNNING"
    assert model.records[EXECUTION_KEY].state == "RUNNING"
    assert model.native_launches == 1
    assert_lookup_shape(model)
    print("PASS release/native output before parent STARTED -> RUNNING")


def case_new_boot_unknown() -> None:
    model = RecoveryModel()
    model.reserve()
    model.native_launch()
    assert model.recover(current_boot=NEW_BOOT_ID, child_present=False) == (
        "START_UNKNOWN_QUARANTINE"
    )
    assert model.records[EXECUTION_KEY].state == "START_UNKNOWN"
    assert model.native_launches == 1
    assert model.recover(current_boot=NEW_BOOT_ID, child_present=False) == (
        "START_UNKNOWN_QUARANTINE"
    )
    assert model.native_launches == 1
    print("PASS new boot/no child or terminal proof -> START_UNKNOWN quarantine")


def case_terminal_replay() -> None:
    model = RecoveryModel()
    model.reserve()
    model.native_launch()
    model.terminal()
    assert model.recover() == "REPLAY_RESULT"
    assert model.native_launches == 1
    assert not model.lookups, "terminal replay needs no native lookup or invocation"
    print("PASS terminal result -> replay only, no native invocation")


def case_changed_input_conflict() -> None:
    model = RecoveryModel()
    model.reserve()
    assert model.create_or_discover(digest=CHANGED_DIGEST) == "LAUNCH_CONFLICT"
    assert model.native_launches == 0
    assert model.records[EXECUTION_KEY].input_digest == INPUT_DIGEST
    print("PASS changed input under same key/name -> LAUNCH_CONFLICT")


def case_identity_mismatch() -> None:
    model = RecoveryModel()
    model.reserve()
    model.native_launch()
    assert (
        model.lookup(
            execution_key=EXECUTION_KEY,
            native_name=NATIVE_NAME,
            input_digest=INPUT_DIGEST,
            boot_id=BOOT_ID,
            process_start_ticks=START_TICKS,
            native_session_id="session-other",
        )
        is None
    )
    assert (
        model.lookup(
            execution_key=EXECUTION_KEY,
            native_name="cf-other",
            input_digest=INPUT_DIGEST,
        )
        == "LAUNCH_CONFLICT"
    )
    assert model.native_launches == 1
    print("PASS mismatched process/native identity -> no relaunch")


def main() -> int:
    case_reserved_without_intent()
    case_gated_child()
    case_started_release_unknown()
    case_output_before_parent_started()
    case_new_boot_unknown()
    case_terminal_replay()
    case_changed_input_conflict()
    case_identity_mismatch()
    print(
        "PASS exact identity: execution_key + native_name + input_digest + process identity"
    )
    print("PASS deterministic model only; live supervisor qualification UNVERIFIED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
