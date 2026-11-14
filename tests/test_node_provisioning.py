#!/usr/bin/env python3
"""Hermetic tests for the CF-003 provisioning slice.

Five mechanisms, each with a refusal arm, none of them touching the network, a private
GitLab, a bunker server or a real credential:

  1. scripts/deploy_key.py    — a per-repo key lands 0600, ssh offers it and nothing else,
                                and a world-readable key / HTTPS remote / public key is refused.
  2. scripts/install-node.sh  — a pinned runtime is extracted, its version is READ BACK from
                                the binary that will run, a wrong digest and a lying binary fail.
  3. scripts/gomodcache.py    — a shared cache can be sealed read-only; the fixture proves a
                                sealed cache builds with GOPROXY=off (no download), a cold
                                cache cannot, and a NEW module is refused instead of growing
                                the cache (the 656 MB re-download is measured, not asserted).
  4. scripts/node_hygiene.py footprint — component bytes add up to the reported total and are
                                admitted against the floor, with a below-floor refusal.
  5. scripts/node_hygiene.py reap — orphan homes/keys are named in check mode and removed in
                                apply mode, live ids and symlinks are preserved.

The live obligations this file does NOT prove (named so a green here is not read as more):
cloning the real private GitLab with a real read-only deploy key from a fresh bunker node,
the 11 node-dependent tests in the Go repo that needs `node` on PATH, reaping a real
bunker host's orphan directories, or deleting orphan bunker OS users. The repository owns
no safe user-account registry or deletion path, so the last obligation remains UNVERIFIED.

The residue fixtures are deliberately narrower than a live bunker: they prove registry-derived
homes and key files only. They must not be read as live-node evidence.
"""

from __future__ import annotations

import hashlib
import json
import os
import platform
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import time
import unittest
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCRIPTS = REPO / "scripts"
PY = sys.executable
KEY_MARKER = "FIXTUREKEYMATERIALnobody-should-print-this"


def invoke(
    script: Path,
    *args: object,
    env: dict | None = None,
    cwd: Path | None = None,
    timeout: int = 240,
) -> subprocess.CompletedProcess:
    environment = dict(os.environ)
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    if env:
        environment.update(env)
    tail = [*[str(a) for a in args]]
    if script.suffix == ".sh":
        command = ["bash", str(script), *tail]
    else:
        command = [PY, str(script), *tail]
    return subprocess.run(
        command,
        capture_output=True,
        text=True,
        env=environment,
        cwd=str(cwd) if cwd else None,
        timeout=timeout,
    )


def py(script: str, *args: object, **kw) -> subprocess.CompletedProcess:
    return invoke(SCRIPTS / script, *args, **kw)


def write_private_key(path: Path, marker: str = KEY_MARKER, mode: int = 0o600) -> bytes:
    begin = "-----BEGIN " + "OPENSSH PRIVATE KEY" + "-----"
    end = "-----END " + "OPENSSH PRIVATE KEY" + "-----"
    data = (
        begin
        + "\n"
        + marker
        + "\n"
        + "ZmFrZS1ib2R5LWZvci1hLWZpeHR1cmUta2V5\n"
        + end
        + "\n"
    ).encode()
    path.write_bytes(data)
    path.chmod(mode)
    return data


def make_node_archive(
    root: Path, version: str = "v22.22.3", reported: str = "v22.22.3"
) -> tuple[Path, str]:
    """A tar.xz shaped like the real Node dist, with a node that PRINTS a chosen version."""
    machine = platform.machine()
    arch = "arm64" if machine in ("aarch64", "arm64") else "x64"
    top = f"node-{version}-linux-{arch}"
    bin_dir = root / top / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    node = bin_dir / "node"
    node.write_text(f"#!/bin/sh\necho {reported}\n")
    node.chmod(0o755)
    npm = bin_dir / "npm"
    npm.write_text("#!/bin/sh\necho 10.9.4\n")
    npm.chmod(0o755)
    archive = root / f"{top}.tar.xz"
    with tarfile.open(archive, "w:xz") as handle:
        handle.add(root / top, arcname=top)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    return archive, digest


def make_module_proxy(root: Path, padding: int = 1 << 20) -> Path:
    """A file:// Go module proxy plus a consumer module — no network, deterministic bytes."""
    proxy = root / "proxy"
    moddir = proxy / "example.com" / "dep" / "@v"
    moddir.mkdir(parents=True, exist_ok=True)
    gomod = "module example.com/dep\n\ngo 1.21\n"
    (moddir / "list").write_text("v1.0.0\nv1.0.1\n")
    for version in ("v1.0.0", "v1.0.1"):
        (moddir / f"{version}.mod").write_text(gomod)
        (moddir / f"{version}.info").write_text(
            json.dumps({"Version": version, "Time": "2024-01-01T00:00:00Z"})
        )
        with zipfile.ZipFile(moddir / f"{version}.zip", "w") as handle:
            handle.writestr(f"example.com/dep@{version}/go.mod", gomod)
            handle.writestr(
                f"example.com/dep@{version}/dep.go",
                f'package dep\n\nfunc Greeting() string {{ return "hello-{version}" }}\n',
            )
            # Padding makes the cache bytes a visible measurement instead of 0.0 MiB.
            handle.writestr(f"example.com/dep@{version}/padding.bin", b"p" * padding)
    consumer = root / "consumer"
    consumer.mkdir(parents=True, exist_ok=True)
    (consumer / "go.mod").write_text(
        "module fixture.local/consumer\n\ngo 1.21\n\nrequire example.com/dep v1.0.0\n"
    )
    (consumer / "main.go").write_text(
        'package main\n\nimport (\n\t"fmt"\n\n\t"example.com/dep"\n)\n\n'
        "func main() { fmt.Println(dep.Greeting()) }\n"
    )
    return consumer


def force_writable(root: Path) -> None:
    for base, dirs, files in os.walk(root):
        for name in dirs + files:
            try:
                os.chmod(Path(base) / name, 0o755)
            except OSError:
                pass
    try:
        os.chmod(root, 0o755)
    except OSError:
        pass


def go_binary() -> str | None:
    found = shutil.which("go")
    if found:
        return found
    candidate = Path(os.path.expanduser("~/go-toolchain/current/bin/go"))
    return str(candidate) if candidate.is_file() else None


class DeployKey(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.key = self.root / "deploy.key"
        write_private_key(self.key)
        self.repo = "ssh://git@gitlab.example:2222/group/project.git"

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def install(
        self, *extra: object, key: Path | None = None, repo: str | None = None
    ) -> subprocess.CompletedProcess:
        return py(
            "deploy_key.py",
            "install",
            "--home",
            self.home,
            "--repo",
            repo or self.repo,
            "--key",
            key or self.key,
            *extra,
        )

    def test_install_is_0600_and_check_prints_one_clone_command(self) -> None:
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        installed = self.home / ".node" / "keys" / "project.key"
        self.assertTrue(installed.is_file())
        self.assertEqual(stat.S_IMODE(installed.stat().st_mode), 0o600)
        config = (self.home / ".node" / "keys" / "ssh_config").read_text()
        self.assertIn("Host gitlab.example", config)
        self.assertIn("Port 2222", config)
        self.assertIn("IdentitiesOnly yes", config)
        self.assertIn(str(installed), config)
        check = py("deploy_key.py", "check", "--home", self.home, "--repo", self.repo)
        self.assertEqual(check.returncode, 0, check.stdout + check.stderr)
        self.assertIn("PASS  key", check.stdout)
        self.assertIn("PASS  ssh_config", check.stdout)
        self.assertIn(f"git clone --depth 1 --branch main {self.repo}", check.stdout)
        self.assertIn("GIT_SSH_COMMAND=", check.stdout)
        # The key's bytes are never an argument and never a log line.
        for output in (result.stdout, result.stderr, check.stdout, check.stderr):
            self.assertNotIn(KEY_MARKER, output)

    def test_world_readable_key_is_refused(self) -> None:
        self.key.chmod(0o644)
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL  key_mode", result.stdout)
        self.assertIn("0644", result.stdout)
        self.assertFalse(
            (self.home / ".node" / "keys" / "project.key").exists(),
            "a refused key must not be installed",
        )

    def test_https_remote_is_refused_naming_why(self) -> None:
        result = self.install(repo="https://gitlab.example/group/project.git")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL  repo", result.stdout)
        self.assertIn("SSH", result.stdout)

    def test_public_key_is_refused(self) -> None:
        public = self.root / "deploy.key.pub"
        public.write_text(
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFIXTURE fixture@example\n"
        )
        public.chmod(0o600)
        result = self.install(key=public)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL  key_file", result.stdout)
        self.assertIn("PUBLIC key", result.stdout)

    def test_rotation_requires_replace(self) -> None:
        self.assertEqual(self.install().returncode, 0)
        other = self.root / "other.key"
        write_private_key(other, marker="ROTATEDKEYMATERIAL")
        refused = self.install(key=other)
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn("already holds a different key", refused.stdout)
        replaced = self.install("--replace", key=other)
        self.assertEqual(replaced.returncode, 0, replaced.stdout + replaced.stderr)
        installed = (self.home / ".node" / "keys" / "project.key").read_text()
        self.assertIn("ROTATEDKEYMATERIAL", installed)

    def test_second_repo_on_the_same_host_keeps_both_identities(self) -> None:
        self.assertEqual(self.install().returncode, 0)
        second = self.root / "second.key"
        write_private_key(second, marker="SECONDKEYMATERIAL")
        result = self.install(key=second, repo="git@gitlab.example:group/other.git")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        config = (self.home / ".node" / "keys" / "ssh_config").read_text()
        self.assertEqual(config.count("Host gitlab.example"), 1, "one block per host")
        self.assertIn("project.key", config)
        self.assertIn("other.key", config)

    def test_check_goes_red_when_the_key_disappears(self) -> None:
        self.assertEqual(self.install().returncode, 0)
        (self.home / ".node" / "keys" / "project.key").unlink()
        result = py("deploy_key.py", "check", "--home", self.home, "--repo", self.repo)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL  key", result.stdout)


class InstallNode(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self.archive, self.digest = make_node_archive(self.root / "dist")
        self.install_root = self.root / "toolchain"

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def apply(
        self, *extra: object, sha: str | None = None
    ) -> subprocess.CompletedProcess:
        return py(
            "install-node.sh",
            "--apply",
            "--root",
            self.install_root,
            "--tarball",
            self.archive,
            "--sha256",
            sha or self.digest,
            *extra,
        )

    def test_check_before_apply_is_red(self) -> None:
        result = py(
            "install-node.sh",
            "--check",
            "--root",
            self.install_root,
            "--tarball",
            self.archive,
            "--sha256",
            self.digest,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL  node", result.stdout)
        self.assertIn("run with --apply", result.stdout)

    def test_apply_installs_reads_back_and_is_idempotent(self) -> None:
        first = self.apply()
        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        owned = self.install_root / "v22.22.3" / "bin" / "node"
        self.assertTrue(owned.is_file())
        self.assertEqual(
            (self.install_root / "current").resolve(),
            (self.install_root / "v22.22.3").resolve(),
        )
        self.assertIn("PASS  node", first.stdout)
        self.assertIn("v22.22.3", first.stdout)
        # A sentinel inside the installed tree survives a second --apply: no re-extract.
        sentinel = self.install_root / "v22.22.3" / "sentinel"
        sentinel.write_text("untouched")
        second = self.apply()
        self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
        self.assertIn("unchanged", second.stdout)
        self.assertTrue(sentinel.is_file())
        checked = py(
            "install-node.sh",
            "--check",
            "--root",
            self.install_root,
            "--tarball",
            self.archive,
            "--sha256",
            self.digest,
        )
        self.assertEqual(checked.returncode, 0, checked.stdout + checked.stderr)

    def test_wrong_digest_installs_nothing(self) -> None:
        result = self.apply(sha="0" * 64)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL  node_dist", result.stdout)
        self.assertFalse((self.install_root / "v22.22.3" / "bin" / "node").exists())

    def test_a_binary_that_lies_about_its_version_fails_the_readback(self) -> None:
        archive, digest = make_node_archive(self.root / "lying", reported="v22.22.2")
        result = py(
            "install-node.sh",
            "--apply",
            "--root",
            self.install_root,
            "--tarball",
            archive,
            "--sha256",
            digest,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL  node", result.stdout)
        self.assertIn(
            "v22.22.2", result.stdout, "the row names what the binary actually printed"
        )
        self.assertIn("NODE: FAIL", result.stdout)

    def test_tarball_without_digest_is_refused(self) -> None:
        result = py(
            "install-node.sh",
            "--apply",
            "--root",
            self.install_root,
            "--tarball",
            self.archive,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("--tarball needs --sha256", result.stderr)


class GoModCache(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self.cache = self.root / "shared"
        self.go = go_binary()
        self.addCleanup(self._make_clean)

    def _make_clean(self) -> None:
        force_writable(self.root)
        self._tmp.cleanup()

    def test_seal_removes_every_write_bit_and_check_goes_red_on_tamper(self) -> None:
        self.cache.mkdir()
        (self.cache / "payload").write_bytes(b"x" * 4096)
        sealed = py("gomodcache.py", "seal", "--dir", self.cache)
        self.assertEqual(sealed.returncode, 0, sealed.stdout + sealed.stderr)
        self.assertIn("read-only", sealed.stdout)
        checked = py("gomodcache.py", "check", "--dir", self.cache)
        self.assertEqual(checked.returncode, 0, checked.stdout + checked.stderr)
        self.assertIn("PASS  modcache_seal", checked.stdout)
        # One write bit back on one file is enough for check to refuse it.
        os.chmod(self.cache / "payload", 0o644)
        tampered = py("gomodcache.py", "check", "--dir", self.cache)
        self.assertNotEqual(tampered.returncode, 0)
        self.assertIn("FAIL  modcache_seal", tampered.stdout)

    def test_manifest_detects_a_cache_that_changed_after_seal(self) -> None:
        self.cache.mkdir()
        (self.cache / "payload").write_bytes(b"x" * 1024)
        self.assertEqual(py("gomodcache.py", "seal", "--dir", self.cache).returncode, 0)
        os.chmod(self.cache, 0o755)
        os.chmod(self.cache / "payload", 0o644)
        (self.cache / "extra").write_bytes(b"y" * 512)
        os.chmod(self.cache / "extra", 0o444)
        os.chmod(self.cache / "payload", 0o444)
        os.chmod(self.cache, 0o555)
        result = py("gomodcache.py", "check", "--dir", self.cache)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL  modcache_manifest", result.stdout)
        self.assertIn("+512 bytes", result.stdout)

    def test_sealed_cache_builds_with_no_network_and_cannot_grow(self) -> None:
        if not self.go:
            self.skipTest(
                "none:go-absent — the no-download property needs a Go toolchain to observe"
            )
        consumer = make_module_proxy(self.root)
        env = {
            "GOPATH": str(self.root / "gopath"),
            "GOCACHE": str(self.root / "build"),
            "GOTOOLCHAIN": "local",
            "GOSUMDB": "off",
            "GOFLAGS": "-mod=mod",
            "GO111MODULE": "on",
        }
        go = self.go
        cold = dict(env, GOPROXY="off", GOMODCACHE=str(self.root / "cold"))
        cold_build = subprocess.run(
            [go, "build", "-o", str(self.root / "cold.out"), "./..."],
            cwd=str(consumer),
            env=dict(os.environ, **cold),
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(
            cold_build.returncode,
            0,
            "an empty cache with the proxy disabled must not build",
        )
        # Seed the shared cache through the file:// proxy, then seal it.
        seeded = py(
            "gomodcache.py",
            "seed",
            "--dir",
            self.cache,
            "--module",
            consumer,
            env=dict(os.environ, **env, GOPROXY=f"file://{self.root / 'proxy'}"),
        )
        self.assertEqual(seeded.returncode, 0, seeded.stdout + seeded.stderr)
        self.assertEqual(py("gomodcache.py", "seal", "--dir", self.cache).returncode, 0)
        before = json.loads(
            py("gomodcache.py", "measure", "--dir", self.cache, "--json").stdout
        )
        self.assertGreater(
            before["bytes"], 500_000, "the fixture must be a measurable download"
        )
        # The measurement: the same build, network forbidden, from the sealed cache.
        warm = dict(env, GOPROXY="off", GOMODCACHE=str(self.cache))
        warm_build = subprocess.run(
            [go, "build", "-o", str(self.root / "warm.out"), "./..."],
            cwd=str(consumer),
            env=dict(os.environ, **warm),
            capture_output=True,
            text=True,
        )
        self.assertEqual(warm_build.returncode, 0, warm_build.stderr)
        after = json.loads(
            py("gomodcache.py", "measure", "--dir", self.cache, "--json").stdout
        )
        print(
            f"\n  MEASURED shared GOMODCACHE {before['bytes']} bytes; sealed rebuild added "
            f"{after['bytes'] - before['bytes']} bytes"
        )
        self.assertEqual(
            after["bytes"],
            before["bytes"],
            "a sealed cache must not change when a node builds from it",
        )
        # And a module that was never seeded is refused instead of growing the cache.
        growth = dict(
            env, GOPROXY=f"file://{self.root / 'proxy'}", GOMODCACHE=str(self.cache)
        )
        proc = subprocess.run(
            [go, "mod", "download", "example.com/dep@v1.0.1"],
            cwd=str(consumer),
            env=dict(os.environ, **growth),
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(
            proc.returncode, 0, "a sealed cache must refuse a module it lacks"
        )
        combined = proc.stdout + proc.stderr
        self.assertIn("permission denied", combined)
        final = json.loads(
            py("gomodcache.py", "measure", "--dir", self.cache, "--json").stdout
        )
        self.assertEqual(final["bytes"], before["bytes"])


class NodeFootprint(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        sizes = {
            "repo": 1000,
            "node-toolchain": 2000,
            "go-toolchain": 3000,
            ".hermes": 4000,
            ".node": 500,
        }
        for name, size in sizes.items():
            target = self.root / name
            target.mkdir(parents=True)
            (target / "blob").write_bytes(b"x" * size)
        self.modcache = self.root / "modcache"
        self.modcache.mkdir()
        (self.modcache / "blob").write_bytes(b"m" * 5000)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def footprint(self, *extra: object) -> subprocess.CompletedProcess:
        return py(
            "node_hygiene.py",
            "footprint",
            "--root",
            self.root,
            "--modcache",
            self.modcache,
            "--working-room-mib",
            "0",
            "--json",
            *extra,
        )

    def test_components_add_up_and_admission_passes(self) -> None:
        result = self.footprint("--floor-gib", "1", "--floor-source", "fixture")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        payload = json.loads(result.stdout.strip().splitlines()[-1])
        self.assertEqual(payload["total_bytes"], 15_500)
        self.assertEqual(payload["components"]["repo"]["bytes"], 1000)
        self.assertEqual(payload["components"]["modcache"]["bytes"], 5000)
        self.assertEqual(payload["verdict"], "PASS")
        self.assertIn("PASS  footprint:floor", result.stdout)

    def test_working_room_shortfall_is_a_refusal(self) -> None:
        result = py(
            "node_hygiene.py",
            "footprint",
            "--root",
            self.root,
            "--modcache",
            self.modcache,
            "--working-room-mib",
            "1000000",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL  footprint:room", result.stdout)
        self.assertIn("short", result.stdout)

    def test_total_above_the_floor_is_a_refusal(self) -> None:
        result = self.footprint("--floor-gib", "0.000001", "--floor-source", "fixture")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL  footprint:floor", result.stdout)

    def test_an_undeclared_modcache_is_named_not_silently_zero(self) -> None:
        result = py("node_hygiene.py", "footprint", "--root", self.root, "--json")
        payload = json.loads(result.stdout.strip().splitlines()[-1])
        self.assertEqual(payload["components"]["modcache"]["state"], "not-declared")


class OrphanReap(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self.homes = self.root / "homes"
        self.keys = self.root / "keys"
        self.homes.mkdir()
        self.keys.mkdir()
        self.registry = self.root / "registry.txt"
        self.registry.write_text("live1\n# a live agent\nlive2\n")
        self.outside = self.root / "outside"
        self.outside.mkdir()
        (self.outside / "keep").write_text("do-not-delete")
        old = time.time() - 7200
        for name in ("bunker-live1", "bunker-orphan1"):
            path = self.homes / name
            path.mkdir()
            (path / "data").write_text(name)
            os.utime(path, (old, old))
        recent = self.homes / "bunker-recent"
        recent.mkdir()
        os.utime(recent, None)
        (self.keys / "live1.key").write_text("k")
        (self.keys / "orphan1.key").write_text("k")
        (self.keys / "orphan2.pub").write_text("k")
        (self.keys / "orphan-note.txt").write_text("must not be treated as a key")
        os.utime(self.keys / "orphan1.key", (old, old))
        os.utime(self.keys / "orphan2.pub", (old, old))
        os.utime(self.keys / "orphan-note.txt", (old, old))
        (self.homes / "bunker-link").symlink_to(self.outside)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def reap(self, *extra: object) -> subprocess.CompletedProcess:
        return py(
            "node_hygiene.py",
            "reap",
            "--homes-dir",
            self.homes,
            "--keys-dir",
            self.keys,
            "--registry",
            self.registry,
            "--min-age-minutes",
            "60",
            *extra,
        )

    def test_check_names_orphans_and_removes_nothing(self) -> None:
        result = self.reap()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL  orphans", result.stdout)
        self.assertIn("bunker-orphan1", result.stdout)
        self.assertIn("orphan1.key", result.stdout)
        self.assertIn("orphan2.pub", result.stdout)
        self.assertNotIn("orphan-note.txt", result.stdout)
        self.assertNotIn("bunker-live1", result.stdout)
        self.assertNotIn("bunker-recent", result.stdout)
        self.assertTrue(
            (self.homes / "bunker-orphan1").is_dir(), "check mode reaps nothing"
        )

    def test_apply_reaps_exactly_the_orphans_and_spares_links_and_live_ids(
        self,
    ) -> None:
        result = self.reap("--apply")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((self.homes / "bunker-orphan1").exists())
        self.assertFalse((self.keys / "orphan1.key").exists())
        self.assertFalse((self.keys / "orphan2.pub").exists())
        self.assertTrue((self.homes / "bunker-live1").is_dir())
        self.assertTrue((self.homes / "bunker-recent").is_dir())
        self.assertTrue((self.keys / "live1.key").is_file())
        self.assertTrue(
            (self.outside / "keep").is_file(), "a symlink target is never followed"
        )
        self.assertTrue((self.homes / "bunker-link").is_symlink())
        again = self.reap("--apply")
        self.assertEqual(again.returncode, 0, again.stdout + again.stderr)
        self.assertIn("PASS  orphans", again.stdout)

    def test_no_registry_is_a_refusal_not_a_guess(self) -> None:
        result = py(
            "node_hygiene.py",
            "reap",
            "--homes-dir",
            self.homes,
            "--keys-dir",
            self.keys,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL  reap_registry", result.stdout)
        self.assertTrue((self.homes / "bunker-orphan1").is_dir())

    def test_root_is_refused(self) -> None:
        result = py(
            "node_hygiene.py", "reap", "--homes-dir", "/", "--registry", self.registry
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL  reap_root", result.stdout)

    def test_bunker_ladder_reuses_live_registry_and_reports_apply(self) -> None:
        bunker = self.root / "bunker-bin"
        bunker.mkdir()
        calls = self.root / "bunker-calls"
        fake = bunker / "bunker"
        fake.write_text(
            "#!/usr/bin/env bash\n"
            'printf \'%s\\n\' "$1" >> "$CF007_CALLS"\n'
            'case "$1" in\n'
            "  --version) printf 'bunker-fixture 1\\n' ;;\n"
            "  list) printf '  live1 running\\n' ;;\n"
            "  status) printf 'status clean\\n' ;;\n"
            "esac\n"
        )
        fake.chmod(0o755)
        config = self.root / "bunker-config.yaml"
        config.write_text("server: fixture-server\\n")
        (self.root / "home").mkdir()
        env = {
            "PATH": f"{bunker}:/usr/bin:/bin",
            "HOME": str(self.root / "home"),
            "BUNKER_SERVER": "fixture-server",
            "BUNKER_CONFIG": str(config),
            "BUNKER_HOMES_DIR": str(self.homes),
            "BUNKER_KEYS_DIR": str(self.keys),
            "CF007_CALLS": str(calls),
        }
        check = invoke(SCRIPTS / "bunker-server-install.sh", "--check", env=env)
        self.assertNotEqual(check.returncode, 0)
        self.assertIn("FAIL  orphans", check.stdout)
        self.assertTrue((self.homes / "bunker-orphan1").is_dir())
        self.assertEqual(calls.read_text().splitlines().count("list"), 1)
        applied = invoke(
            SCRIPTS / "bunker-server-install.sh", "--reap-orphans", env=env
        )
        self.assertEqual(applied.returncode, 0, applied.stdout + applied.stderr)
        self.assertIn("reaped 3 orphan(s)", applied.stdout)
        self.assertFalse((self.homes / "bunker-orphan1").exists())
        self.assertFalse((self.keys / "orphan1.key").exists())
        self.assertTrue((self.homes / "bunker-live1").is_dir())
        self.assertTrue((self.keys / "live1.key").is_file())
        self.assertEqual(calls.read_text().splitlines().count("list"), 2)


if __name__ == "__main__":
    unittest.main(verbosity=2)
