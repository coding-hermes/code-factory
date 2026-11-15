#!/usr/bin/env python3
"""Hermetic regression tests for the canonical cooldown policy (CF-134)."""

from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import cooldown_policy  # noqa: E402
import load_lane_config  # noqa: E402

LANES = (
    "code-factory",
    "code-factory-qa",
    "code-factory-pm",
    "code-factory-dogfood",
    "code-factory-sync",
    "code-factory-duckbrain",
)


def make_db(path: Path) -> sqlite3.Connection:
    con = sqlite3.connect(path)
    con.execute(
        "CREATE TABLE projects (name TEXT PRIMARY KEY, namespace_id TEXT, "
        "admission_mode TEXT, prompt TEXT, prompt_mode TEXT, "
        "cooldown_s INTEGER, cooldown_floor_s INTEGER, "
        "cooldown_ceiling_s INTEGER, cooldown_pin_s INTEGER)"
    )
    for name in LANES:
        con.execute(
            "INSERT INTO projects VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (name, "old", "old", "old", "replace", 1, 1, 1, None),
        )
    con.commit()
    return con


def policy_rows(con: sqlite3.Connection) -> dict[str, tuple[int, int, int]]:
    return {
        row[0]: row[1:]
        for row in con.execute(
            "SELECT name, cooldown_s, cooldown_floor_s, cooldown_ceiling_s "
            "FROM projects ORDER BY name"
        )
    }


def test_apply_projects_from_one_policy_source_and_is_idempotent(
    tmp_path: Path,
) -> None:
    con = make_db(tmp_path / "scheduler.db")
    prompts = {name: f"prompt for {name}" for name in LANES}

    # The repository module exposes the DB projection only. fleet.toml is an
    # external projection owned by the control-host loader, documented in M9.
    assert not hasattr(cooldown_policy, "fleet_toml_path")

    load_lane_config.apply_updates(con, prompts)
    first = policy_rows(con)
    for name in LANES:
        policy = cooldown_policy.policy_for_lane(name)
        assert first[name] == (
            policy["cadence_s"],
            policy["floor_s"],
            policy["ceiling_s"],
        )

    load_lane_config.apply_updates(con, prompts)
    assert policy_rows(con) == first
    con.close()


def test_role_ceilings_refuse_unsafe_pins_and_accept_safe_pins() -> None:
    representatives = {
        "primary": "code-factory",
        **{
            role: f"code-factory-{role}"
            for role in cooldown_policy.ROLE_POLICY
            if role != "primary"
        },
    }
    for role, name in representatives.items():
        _, ceiling = cooldown_policy.ROLE_POLICY[role]
        cooldown_policy.validate_pin(name, ceiling)
        cooldown_policy.validate_pin(name, ceiling - 1)
        with pytest.raises(cooldown_policy.CooldownPolicyError):
            cooldown_policy.validate_pin(name, ceiling + 1)
        cooldown_policy.validate_pin(name, ceiling + 1, reason="recorded exception")


def test_three_failures_clear_within_bound() -> None:
    backoff = cooldown_policy.FailureBackoff()
    blocked_until = [backoff.record_failure(now_s) for now_s in (0, 1, 2)]
    delays = [blocked_until[0], blocked_until[1] - 1, blocked_until[2] - 2]

    assert delays == sorted(delays)
    assert all(delay <= cooldown_policy.FAILURE_BACKOFF_MAX_S for delay in delays)
    assert not backoff.eligible(2)

    eligible_at = backoff.clear_cause(10)
    assert eligible_at == 10
    assert backoff.consecutive_failures == 0
    assert backoff.eligible(10)


def test_role_for_lane_refuses_unsafe_and_unknown_names() -> None:
    for name in ("../code-factory", "code-factory/qa", "not-code-factory"):
        with pytest.raises(cooldown_policy.CooldownPolicyError):
            cooldown_policy.role_for_lane(name)
    with pytest.raises(cooldown_policy.CooldownPolicyError):
        cooldown_policy.role_for_lane("code-factory-unknown")
