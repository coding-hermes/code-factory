#!/usr/bin/env python3
"""Canonical code-factory admission cadence and bounded failure backoff policy.

The scheduler DB and fleet.toml are projections of this module's policy.  Keep
this file free of host-specific paths so it can be imported by provisioning
scripts and exercised in hermetic tests.
"""

from __future__ import annotations

from dataclasses import dataclass
import re
from typing import Mapping

PRIMARY_CADENCE_S = 1800
FAILURE_BACKOFF_BASE_S = 300
FAILURE_BACKOFF_MAX_S = 1800

# These are role policy values, not copies of a live DB.  A role's cadence is
# also its default floor; its ceiling is the maximum safe cooldown pin.
ROLE_POLICY: Mapping[str, tuple[int, int]] = {
    "primary": (PRIMARY_CADENCE_S, PRIMARY_CADENCE_S),
    "qa": (43200, 345600),
    "pm": (86400, 691200),
    "sync": (21600, 172800),
    "dogfood": (259200, 2073600),
    "releng": (86400, 691200),
    "docs": (604800, 4838400),
    "readme": (604800, 4838400),
    "perf": (604800, 4838400),
    "review": (604800, 4838400),
    "duckbrain": (21600, 172800),
}

_ROLE_SUFFIXES = tuple(sorted(ROLE_POLICY, key=len, reverse=True))
_LANE_RE = re.compile(r"^code-factory(?:-[a-z0-9]+)*$")


class CooldownPolicyError(ValueError):
    """A malformed or unsafe lane policy input."""


def role_for_lane(name: str) -> str:
    """Return the policy role for a code-factory lane or refuse it."""
    if not isinstance(name, str) or not _LANE_RE.fullmatch(name):
        raise CooldownPolicyError(f"unsafe code-factory lane name: {name!r}")
    if name == "code-factory":
        return "primary"
    suffix = name.removeprefix("code-factory-").split("-")
    for candidate in _ROLE_SUFFIXES:
        if candidate in suffix:
            return candidate
    raise CooldownPolicyError(f"no cooldown role for lane: {name}")


def policy_for_lane(name: str) -> dict[str, int | str]:
    role = role_for_lane(name)
    cadence_s, ceiling_s = ROLE_POLICY[role]
    return {
        "name": name,
        "role": role,
        "cadence_s": cadence_s,
        "floor_s": cadence_s,
        "ceiling_s": ceiling_s,
    }


def ceiling_for_lane(name: str) -> int:
    return int(policy_for_lane(name)["ceiling_s"])


def validate_pin(name: str, pin_s: int | None, reason: str | None = None) -> None:
    """Reject invalid pins and unexplained values above the role ceiling."""
    if pin_s is None:
        return
    if type(pin_s) is not int or pin_s < 0:
        raise CooldownPolicyError(f"invalid cooldown_pin_s for {name}: {pin_s!r}")
    ceiling = ceiling_for_lane(name)
    if pin_s > ceiling and not (isinstance(reason, str) and reason.strip()):
        raise CooldownPolicyError(
            f"cooldown_pin_s {pin_s} exceeds {name} role ceiling {ceiling} without a reason"
        )


def bounded_failure_delay(failures: int) -> int:
    """Return exponential failure delay, capped at the recovery bound."""
    if type(failures) is not int or failures < 0:
        raise CooldownPolicyError(f"invalid consecutive failure count: {failures!r}")
    if failures == 0:
        return 0
    return min(FAILURE_BACKOFF_MAX_S, FAILURE_BACKOFF_BASE_S * (2 ** (failures - 1)))


@dataclass
class FailureBackoff:
    """Small state machine used by admission callers to pace repeated failures.

    Clearing the cause does not erase an already scheduled retry, but it does
    cap recovery at ``FAILURE_BACKOFF_MAX_S`` after the clear.  Thus a lane
    cannot remain blocked forever because of stale failure state.
    """

    consecutive_failures: int = 0
    blocked_until_s: int = 0
    cause_cleared_at_s: int | None = None

    def record_failure(self, now_s: int) -> int:
        if type(now_s) is not int or now_s < 0:
            raise CooldownPolicyError(f"invalid failure timestamp: {now_s!r}")
        self.consecutive_failures += 1
        self.cause_cleared_at_s = None
        self.blocked_until_s = now_s + bounded_failure_delay(self.consecutive_failures)
        return self.blocked_until_s

    def clear_cause(self, now_s: int) -> int:
        if type(now_s) is not int or now_s < 0:
            raise CooldownPolicyError(f"invalid clear timestamp: {now_s!r}")
        self.cause_cleared_at_s = now_s
        return self.eligible_at_s

    @property
    def eligible_at_s(self) -> int:
        if self.cause_cleared_at_s is None:
            return self.blocked_until_s
        return min(
            self.blocked_until_s,
            self.cause_cleared_at_s + FAILURE_BACKOFF_MAX_S,
        )

    def eligible(self, now_s: int) -> bool:
        if type(now_s) is not int or now_s < 0:
            raise CooldownPolicyError(f"invalid eligibility timestamp: {now_s!r}")
        return now_s >= self.eligible_at_s
