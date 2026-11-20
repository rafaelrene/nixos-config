"""Reconcile repository-owned agent links during system activation."""

import argparse
import json
import os
from pathlib import Path


def link_target(path):
    return Path(os.path.abspath(path.parent / os.readlink(path)))


def validate_directory(directory, home, conflicts):
    for parent in (directory, *directory.parents):
        if parent == home:
            break
        if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
            conflicts.append(f"Expected a real directory: {parent}")
            break


def reconcile(home, source, manifest, check=False):
    links = {home / dest: source / src for dest, src in manifest["links"].items()}
    skill_directories = [home / directory for directory in manifest["skillDirectories"]]
    aliases = {
        home / directory: home / alias
        for directory, alias in manifest.get("skillAliases", {}).items()
    }
    conflicts = []
    moves = {}

    for directory in skill_directories:
        validate_directory(directory, home, conflicts)

    for directory, alias in aliases.items():
        validate_directory(alias.parent, home, conflicts)
        if alias.is_symlink():
            if link_target(alias) != directory:
                conflicts.append(f"Unmanaged link: {alias}")
        elif alias.is_dir():
            if directory.is_dir() and any(directory.iterdir()):
                if any(alias.iterdir()):
                    conflicts.append(
                        f"Both skill directories contain data: {directory} and {alias}"
                    )
            else:
                moves[directory] = alias
        elif alias.exists():
            conflicts.append(f"Expected a skill directory or alias: {alias}")

    # Check every destination before changing anything; local files stay intact.
    for dest, target in links.items():
        if not target.exists():
            conflicts.append(f"Missing source: {target}")
        validate_directory(dest.parent, home, conflicts)
        existing = moves.get(dest.parent, dest.parent) / dest.name
        if existing.is_symlink():
            if link_target(existing) != target:
                conflicts.append(f"Unmanaged link: {existing}")
        elif existing.exists():
            conflicts.append(f"Preserving conflicting path: {existing}")

    if conflicts:
        raise ValueError("\n".join(dict.fromkeys(conflicts)))
    if check:
        return

    for directory, alias in aliases.items():
        if directory in moves:
            directory.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            alias.rename(directory)
        else:
            directory.mkdir(parents=True, exist_ok=True, mode=0o700)
            if not alias.is_symlink() and alias.is_dir():
                alias.rmdir()
        alias.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        if not alias.is_symlink():
            alias.symlink_to(directory, target_is_directory=True)

    for dest, target in links.items():
        dest.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        if not dest.is_symlink():
            dest.symlink_to(target)

    for directory in skill_directories:
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
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    try:
        reconcile(
            args.home, args.source, json.loads(args.manifest.read_text()), args.check
        )
    except (OSError, ValueError) as error:
        parser.exit(1, f"Agent configuration was not fully activated:\n{error}\n")


if __name__ == "__main__":
    main()
