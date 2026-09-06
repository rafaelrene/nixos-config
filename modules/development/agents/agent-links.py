#!/usr/bin/env python3
"""Reconcile repository-owned agent links during raf's NixOS activation."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile


def link_target(path):
    return Path(os.path.abspath(path.parent / os.readlink(path)))


def reconcile(home, source, manifest):
    links = {home / dest: source / src for dest, src in manifest["links"].items()}
    previous = manifest["previousSettings"]
    migrations = []
    conflicts = []

    for relative in manifest["skillDirectories"]:
        directory = home / relative
        for parent in (directory, *directory.parents):
            if parent == home:
                break
            if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
                conflicts.append(f"Expected a real directory: {parent}")
                break

    # Check every destination before changing anything. Only the two imported
    # settings snapshots may replace regular files, and their bytes must match.
    for dest, target in links.items():
        if not target.exists():
            conflicts.append(f"Missing source: {target}")
        for parent in dest.parents:
            if parent == home:
                break
            if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
                conflicts.append(f"Expected a real directory: {parent}")
                break
        if dest.is_symlink():
            if link_target(dest) != target:
                conflicts.append(f"Unmanaged link: {dest}")
        elif dest.exists():
            expected = previous.get(str(dest.relative_to(home)))
            if (
                expected
                and dest.is_file()
                and hashlib.sha256(dest.read_bytes()).hexdigest() == expected
            ):
                migrations.append(dest)
            else:
                conflicts.append(f"Preserving conflicting path: {dest}")

    if conflicts:
        raise ValueError("\n".join(dict.fromkeys(conflicts)))

    if migrations:
        backup_root = home / ".local/state/agent-config-backups"
        backup_root.mkdir(parents=True, exist_ok=True, mode=0o700)
        backup = Path(tempfile.mkdtemp(prefix="initial-", dir=backup_root))
        for dest in migrations:
            saved = backup / dest.relative_to(home)
            saved.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            dest.rename(saved)
        print(f"Original agent settings saved in {backup}")

    for dest, target in links.items():
        dest.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        if not dest.is_symlink():
            dest.symlink_to(target)

    for relative in manifest["skillDirectories"]:
        directory = home / relative
        directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        for dest in directory.iterdir():
            if (
                dest.is_symlink()
                and dest not in links
                and link_target(dest).parent == source / "skills"
            ):
                dest.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    args = parser.parse_args()
    try:
        reconcile(args.home, args.source, json.loads(args.manifest.read_text()))
    except (OSError, ValueError) as error:
        parser.exit(1, f"Agent configuration was not fully activated:\n{error}\n")


if __name__ == "__main__":
    main()
