"""Pin the documentation's count claims to the executor's declared families."""

import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
DOCS = {
    "specs/HARNESS.md": (2, 1),
    "specs/HARNESS-MATRIX.md": (3, 3),
    "specs/HARNESS-MEMORY.md": (1, 1),
    "docs/ACCEPTANCE-PLAN.md": (1, 1),
}
NUMBERS = {
    name: value
    for value, name in enumerate(
        (
            "zero",
            "one",
            "two",
            "three",
            "four",
            "five",
            "six",
            "seven",
            "eight",
            "nine",
            "ten",
        )
    )
}
NUMBER = r"(?:\d+|" + "|".join(NUMBERS) + r")"
TOTAL = re.compile(rf"\b({NUMBER})\s+leg\s+families\b", re.IGNORECASE)
SUPPORT = re.compile(
    rf"\b({NUMBER})\s+per-harness\s+support\s+families\b", re.IGNORECASE
)


def declared_families():
    result = subprocess.run(
        ["bash", str(ROOT / "tests/harness-conformance.sh"), "--list-legs"],
        check=True,
        capture_output=True,
        text=True,
    )
    families = result.stdout.splitlines()
    assert families and len(families) == len(set(families))
    assert "node" in families
    return families


def check_documents(root, families):
    errors = []
    for filename, (min_totals, min_support) in DOCS.items():
        text = (root / filename).read_text()
        for pattern, expected, minimum, label in (
            (TOTAL, len(families), min_totals, "leg families"),
            (SUPPORT, len(families) - 1, min_support, "per-harness support families"),
        ):
            matches = list(pattern.finditer(text))
            if len(matches) < minimum:
                errors.append(
                    f"{filename}: missing {label} count statements ({len(matches)} < {minimum})"
                )
            for match in matches:
                token = match.group(1).lower()
                actual = int(token) if token.isdigit() else NUMBERS[token]
                if actual != expected:
                    line = text.count("\n", 0, match.start()) + 1
                    errors.append(
                        f"{filename}:{line}: {label}: {actual} != declared {expected}"
                    )
    return errors


def test_tracked_documents_agree():
    families = declared_families()
    errors = check_documents(ROOT, families)
    print(
        f"tracked docs: {'FAIL ' + '; '.join(errors) if errors else 'PASS'} ({len(families)} declared families)"
    )
    assert not errors, "\n".join(errors)


@pytest.mark.parametrize(
    "phrase,replacement",
    [
        ("six leg families", "three leg families"),
        ("five per-harness support families", "four per-harness support families"),
    ],
)
def test_mutated_doc_is_rejected(tmp_path, phrase, replacement):
    for filename in DOCS:
        target = tmp_path / filename
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / filename, target)
    target = tmp_path / "specs/HARNESS-MEMORY.md"
    text = target.read_text()
    assert text.count(phrase) == 1
    target.write_text(text.replace(phrase, replacement))
    errors = check_documents(tmp_path, declared_families())
    print("mutated doc: FAIL " + "; ".join(errors))
    assert len(errors) == 1 and "HARNESS-MEMORY.md" in errors[0]
