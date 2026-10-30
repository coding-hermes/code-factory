#!/usr/bin/env python3
"""Precise provisioning admission and opt-in, flat disposable-cache reclaim."""

from contextlib import ExitStack
import fcntl
import os
from pathlib import Path
import re
import stat
import subprocess
import sys

GIB = 1 << 30
DIR_FLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW


def require(condition, message):
    if not condition:
        raise ValueError(message)


def floor_ratio(value):
    require(
        re.fullmatch(r"[0-9]{1,9}(?:\.[0-9]{1,9})?", value),
        "invalid floor; expected unsigned decimal GiB (1-9 digits per part)",
    )
    whole, _, fraction = value.partition(".")
    scale = 10 ** len(fraction)
    return int(whole) * scale + int(fraction or "0"), scale


def available_kib(path):
    result = subprocess.run(
        ["df", "-Pk", "--", path],
        env={**os.environ, "LC_ALL": "C"},
        capture_output=True,
        text=True,
        timeout=10,
        check=False,
    )
    require(result.returncode == 0, "df failed; free GiB unknown")
    require(len(result.stdout) <= 65536, "invalid df measurement; free GiB unknown")
    rows = result.stdout.splitlines()
    require(
        len(rows) == 2
        and rows[0].split()
        == [
            "Filesystem",
            "1024-blocks",
            "Used",
            "Available",
            "Capacity",
            "Mounted",
            "on",
        ],
        "invalid df rows/header; free GiB unknown",
    )
    fields = rows[1].split(maxsplit=5)
    require(len(fields) == 6, "invalid df row; free GiB unknown")
    require(
        all(re.fullmatch(r"[0-9]{1,20}", s) for s in fields[1:4])
        and re.fullmatch(r"[0-9]{1,3}%", fields[4])
        and fields[5].startswith("/"),
        "invalid df numeric fields/mount; free GiB unknown",
    )
    total, used, free = map(int, fields[1:4])
    require(
        used + free <= total and int(fields[4][:-1]) <= 100,
        "inconsistent df measurement; free GiB unknown",
    )
    return free


def snapshot(info):
    return (
        info.st_dev,
        info.st_ino,
        info.st_mode,
        info.st_uid,
        info.st_nlink,
        info.st_size,
        info.st_mtime_ns,
        info.st_ctime_ns,
    )


def reclaim(home):
    """No recursion or caller-selected target. Account and producers are trusted."""
    require(
        home == os.environ.get("HOME")
        and home == os.path.normpath(home)
        and home.startswith("/")
        and home != "/",
        "unsafe reclaim HOME",
    )
    with ExitStack() as stack:

        def opened(name, parent=None):
            fd = os.open(name, DIR_FLAGS, dir_fd=parent)
            stack.callback(os.close, fd)
            return fd

        fd = opened("/")
        for part in Path(home).parts[1:]:
            fd = opened(part, fd)
        base = os.fstat(fd)
        require(
            base.st_uid == os.getuid() and not base.st_mode & 0o022,
            "unsafe reclaim HOME ownership/mode",
        )
        for part in (".node", "disposable-cache-v1"):
            try:
                fd = opened(part, fd)
            except FileNotFoundError:
                return 0
            info = os.fstat(fd)
            require(
                info.st_uid == os.getuid()
                and stat.S_IMODE(info.st_mode) == 0o700
                and info.st_dev == base.st_dev,
                "unsafe reclaim directory ownership/mode/device",
            )
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        entries = []
        with os.scandir(fd) as iterator:
            for entry in iterator:
                require(len(entries) < 1024, "reclaim entry limit exceeded")
                require(
                    re.fullmatch(r"cache-[A-Za-z0-9_-]{1,64}\.bin", entry.name),
                    "unsafe reclaim entry name",
                )
                info = os.stat(entry.name, dir_fd=fd, follow_symlinks=False)
                require(
                    stat.S_ISREG(info.st_mode)
                    and stat.S_IMODE(info.st_mode) == 0o600
                    and info.st_uid == os.getuid()
                    and info.st_nlink == 1
                    and info.st_dev == base.st_dev,
                    "unsafe reclaim entry type/ownership/mode/links/device",
                )
                entries.append((entry.name, snapshot(info)))
        # Validate the whole flat namespace before unlinking any entry.
        for name, expected in entries:
            require(
                snapshot(os.stat(name, dir_fd=fd, follow_symlinks=False)) == expected,
                "reclaim entry changed; refusing",
            )
            os.unlink(name, dir_fd=fd)
        return len(entries)


def admission(path, floor, cleanup=False):
    numerator, denominator = floor_ratio(floor)

    def enough(free):
        return free * 1024 * denominator >= numerator * GIB

    def values(free):
        # KiB / 2**20 has an exact decimal expansion of at most 20 places.
        whole, remainder = divmod(free, 1 << 20)
        fraction = f"{remainder * 5**20:020d}".rstrip("0")
        gib = f"{whole}.{fraction}" if fraction else str(whole)
        return f"{free} KiB available ({gib} GiB free); floor {floor} GiB"

    free = available_kib(path)
    if not enough(free) and cleanup:
        print(f"  WARN  disk — {values(free)}; attempting opted-in disposable reclaim")
        count = reclaim(path)
        print(f"  ..    disposable reclaim: {count} cache blobs removed")
        free = available_kib(path)
    if not enough(free):
        print(f"  FAIL  disk — {values(free)}; below floor")
        return 1
    print(f"  PASS  disk — {values(free)}")
    return 0


def main():
    require(len(sys.argv) in (3, 4), "invalid disk policy arguments")
    cleanup = len(sys.argv) == 4
    require(
        not cleanup or sys.argv[3] == "--reclaim-disposable", "invalid reclaim option"
    )
    return admission(sys.argv[1], sys.argv[2], cleanup)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, subprocess.SubprocessError, UnicodeError) as error:
        # Never echo df output or arbitrary filenames from an unsafe namespace.
        message = str(error) if isinstance(error, ValueError) else type(error).__name__
        print(f"  FAIL  disk — floor/measurement/reclaim refused: {message}")
        sys.exit(1)
