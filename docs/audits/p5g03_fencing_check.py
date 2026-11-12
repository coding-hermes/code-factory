#!/usr/bin/env python3
"""Check the documented fencing example; this models the spec, not production."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHAPTER = ROOT / "docs/handbook/chapters/M7-github.md"
ROWS = {
    "Git publication": ("git-A", "git-B", "git-C"),
    "Board": ("board-A", "board-B", "board-C"),
    "Memory": ("memory-A", "memory-B", "memory-C"),
    "Crier": ("crier-A", "crier-B", "crier-C"),
    "Scheduler": ("scheduler-A", "scheduler-B", "scheduler-C"),
}


class Model:
    def __init__(self, value):
        self.active = 7
        self.value = value
        self.pending = None
        self.effects = {}
        self.online = True

    def begin(self, fence, effect, digest):
        if not self.online:
            return "AUTHORITY_UNAVAILABLE"
        if fence != self.active:
            return "STALE_OWNER"
        if effect in self.effects:
            old_digest, state = self.effects[effect]
            return state if old_digest == digest else "EFFECT_CONFLICT"
        self.effects[effect] = (digest, "pending")
        self.pending = effect
        return "pending"

    def finish(self, effect, observed):
        assert self.pending == effect
        self.value = observed
        digest, _ = self.effects[effect]
        self.effects[effect] = (digest, "applied")
        self.pending = None

    def advance(self):
        if self.pending is not None:
            return "EFFECT_UNRESOLVED"
        self.active = 8
        return "advanced"


def check():
    text = CHAPTER.read_text(encoding="utf-8")
    section = text.split("### 17.1 Deterministic fencing procedure", 1)[1].split(
        "## 18.", 1
    )[0]
    table = {}
    for line in section.splitlines():
        if line.startswith("| "):
            cells = [cell.strip() for cell in line.strip("|").split("|")]
            if cells[0] in ROWS:
                assert cells[0] not in table, cells[0]
                table[cells[0]] = tuple(cells[1:4])
    assert table == ROWS, (table, ROWS)
    for name, (before, old, new) in table.items():
        m = Model(before)
        assert m.begin(7, "old-1", old) == "pending"
        assert m.advance() == "EFFECT_UNRESOLVED"
        assert (m.active, m.pending) == (7, "old-1")
        m.finish("old-1", old)
        assert m.advance() == "advanced"
        assert m.begin(7, "stale", "bad") == "STALE_OWNER"
        assert m.value == old and "stale" not in m.effects
        m.online = False
        assert m.begin(8, "new-1", new) == "AUTHORITY_UNAVAILABLE"
        assert m.value == old and "new-1" not in m.effects
        m.online = True
        assert m.begin(8, "new-1", new) == "pending"
        m.finish("new-1", new)
        assert m.begin(8, "new-1", new) == "applied"
        assert m.begin(8, "new-1", "different") == "EFFECT_CONFLICT"
        assert (m.active, m.pending, m.value) == (8, None, new)
        m = Model(before)
        assert m.advance() == "advanced"
        assert m.begin(7, "late", old) == "STALE_OWNER"
        assert m.value == before and "late" not in m.effects
        assert m.begin(8, "new-1", new) == "pending"
        m.finish("new-1", new)
        assert m.value == new
        print(
            f"PASS {name}: blocked unknown, recovery, stale rejection, both orderings"
        )
    print("PASS specification model only; runtime UNVERIFIED")


if __name__ == "__main__":
    check()
