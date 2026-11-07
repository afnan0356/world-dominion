#!/usr/bin/env python3
"""Build the project bundle: a reproducible copy of the project that runs anywhere.

The bundle is the build path that always works. It needs no Android SDK, no export
template and no network: it is a zip of the repository's own files plus a manifest of
what is inside it, with a SHA-256 for every file and for the archive. Opening it in
Godot 4.6.3 and pressing play runs the game.

What is **excluded**, and why:

* `.git`, `.godot`, `__pycache__`, `*.pyc`, `*.uid`-less caches — machine state.
* `dist/` and `build/` — this tool's own output.
* `data/source/` — the downloaded datasets. They are not needed to run, and shipping
  them would redistribute data under licences the bundle does not carry. The pins that
  regenerate them are in `data/world/`.

The archive is deterministic: entries are sorted, timestamps are fixed at 1980-01-01, and
the file mode is normalised, so the same tree always produces the same SHA-256. CI uses
that: the export workflow rebuilds the bundle twice and compares hashes.

Usage:

    python3 tools/build_project_bundle.py                  # write dist/world-dominion-<version>.zip
    python3 tools/build_project_bundle.py --out /tmp/x.zip
    python3 tools/build_project_bundle.py --verify dist/world-dominion-<version>.zip
    python3 tools/build_project_bundle.py --self-test      # proves the archive is reproducible
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"

EXCLUDED_DIRS = {".git", ".godot", ".github", "__pycache__", "dist", "build",
                 "data/source", ".import", "node_modules"}
EXCLUDED_SUFFIXES = {".pyc", ".pyo"}
EXCLUDED_FILES = {"Thumbs.db", ".DS_Store"}
# `.github` is excluded from the *bundle* on purpose: it is CI configuration, not part of
# the game. It stays in the repository, and the export workflow that reads it is not
# something a player needs.

FIXED_DATE = (1980, 1, 1, 0, 0, 0)
FIXED_MODE = 0o644
VERSION_FILE = ROOT / "project.godot"
DEFAULT_VERSION = "0.0.0"


def project_version() -> str:
    """The version the engine reports, read from `project.godot`."""
    try:
        text = VERSION_FILE.read_text(encoding="utf-8")
    except OSError:
        return DEFAULT_VERSION
    match = re.search(r'config/version="([^"]+)"', text)
    return match.group(1) if match else DEFAULT_VERSION


def _skip(relative: Path) -> bool:
    parts = relative.parts
    for index in range(len(parts)):
        candidate = "/".join(parts[: index + 1])
        if candidate in EXCLUDED_DIRS or parts[index] in EXCLUDED_DIRS:
            return True
    if relative.name in EXCLUDED_FILES:
        return True
    return relative.suffix in EXCLUDED_SUFFIXES


def collect(root: Path = ROOT) -> list[Path]:
    """Every file the bundle carries, in a fixed order."""
    found: list[Path] = []
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        relative = path.relative_to(root)
        if _skip(relative):
            continue
        found.append(relative)
    found.sort(key=lambda item: item.as_posix())
    return found


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def build_manifest(root: Path, files: list[Path], version: str) -> dict:
    entries = []
    for relative in files:
        data = (root / relative).read_bytes()
        entries.append({"path": relative.as_posix(), "bytes": len(data),
                        "sha256": sha256_bytes(data)})
    return {
        "kind": "world-dominion-project-bundle",
        "schema": 1,
        "version": version,
        "engine": "Godot 4.6.3",
        "entry_manifest": "data/world/manifest.json",
        "file_count": len(entries),
        "total_bytes": sum(item["bytes"] for item in entries),
        "files": entries,
    }


def build(root: Path, out_path: Path, version: str | None = None) -> dict:
    """Write the bundle and return its manifest plus the archive's own hash."""
    version = version or project_version()
    files = collect(root)
    manifest = build_manifest(root, files, version)
    payload = json.dumps(manifest, ensure_ascii=False, indent=2,
                         sort_keys=True).encode("utf-8") + b"\n"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        _add(archive, "BUNDLE.json", payload)
        for relative in files:
            _add(archive, relative.as_posix(), (root / relative).read_bytes())
    digest = sha256_bytes(out_path.read_bytes())
    manifest["archive_sha256"] = digest
    manifest["archive_path"] = out_path.name
    return manifest


def _add(archive: zipfile.ZipFile, name: str, data: bytes) -> None:
    info = zipfile.ZipInfo(name, date_time=FIXED_DATE)
    info.external_attr = FIXED_MODE << 16
    info.compress_type = zipfile.ZIP_DEFLATED
    archive.writestr(info, data)


def verify(path: Path) -> list[str]:
    """Check an existing bundle against the manifest it carries."""
    problems: list[str] = []
    if not path.is_file():
        return [f"{path} does not exist"]
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if "BUNDLE.json" not in names:
            return [f"{path.name} has no BUNDLE.json"]
        manifest = json.loads(archive.read("BUNDLE.json").decode("utf-8"))
        listed = {item["path"] for item in manifest.get("files", [])}
        for item in manifest.get("files", []):
            if item["path"] not in names:
                problems.append(f"{item['path']} is listed but missing from the archive")
                continue
            data = archive.read(item["path"])
            if len(data) != item["bytes"]:
                problems.append(f"{item['path']} is {len(data)} bytes, not {item['bytes']}")
            if sha256_bytes(data) != item["sha256"]:
                problems.append(f"{item['path']} does not match its recorded hash")
        for name in names:
            if name != "BUNDLE.json" and name not in listed:
                problems.append(f"{name} is in the archive but not in BUNDLE.json")
        if manifest.get("file_count") != len(manifest.get("files", [])):
            problems.append("file_count disagrees with the file list")
        for entry in ("project.godot", "data/world/countries.json",
                      "data/world/manifest.json"):
            if entry not in listed:
                problems.append(f"the bundle is missing {entry}")
    return problems


def self_test() -> int:
    """Build the bundle twice from the same tree and prove the bytes are identical."""
    failures: list[str] = []
    with tempfile.TemporaryDirectory() as folder:
        first = Path(folder) / "a.zip"
        second = Path(folder) / "b.zip"
        build(ROOT, first)
        build(ROOT, second)
        if first.read_bytes() != second.read_bytes():
            failures.append("two builds of the same tree differ")
        problems = verify(first)
        failures.extend(problems)
        with zipfile.ZipFile(first) as archive:
            manifest = json.loads(archive.read("BUNDLE.json").decode("utf-8"))
        if manifest.get("file_count", 0) < 300:
            failures.append(f"only {manifest.get('file_count')} files: the bundle looks wrong")
        names = [item["path"] for item in manifest.get("files", [])]
        if any(name.startswith("data/source/") for name in names):
            failures.append("a downloaded source file is in the bundle")
        if any(name.startswith(".git/") for name in names):
            failures.append("git metadata is in the bundle")
    if failures:
        for failure in failures:
            print(f"self-test failure: {failure}")
        return 1
    print("self-test ok: the bundle is reproducible and self-describing")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__ or "")
    parser.add_argument("--out", default="", help="where to write the bundle")
    parser.add_argument("--version", default="", help="override the project version")
    parser.add_argument("--verify", default="", help="check an existing bundle")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)

    if args.self_test:
        return self_test()
    if args.verify:
        problems = verify(Path(args.verify))
        for problem in problems:
            print(f"bundle: {problem}")
        if problems:
            print(f"bundle is damaged: {len(problems)} problem(s)")
            return 1
        print(f"bundle ok: {os.path.basename(args.verify)}")
        return 0

    version = args.version or project_version()
    out = Path(args.out) if args.out else DIST / f"world-dominion-{version}.zip"
    manifest = build(ROOT, out, version)
    print(f"wrote {out.relative_to(ROOT) if out.is_relative_to(ROOT) else out} "
          f"({manifest['file_count']} files, {manifest['total_bytes']} bytes)")
    print(f"archive sha256 {manifest['archive_sha256']}")
    if args.out:
        sidecar = out.with_suffix(".json")
        sidecar.write_text(json.dumps(manifest, ensure_ascii=False, indent=2,
                                      sort_keys=True) + "\n", encoding="utf-8")
        print(f"wrote {sidecar.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
