"""Remove btca reference clones unused for a day, preserving local work."""

import argparse
import shutil
import subprocess
import time
from pathlib import Path


def git(repository: Path, *arguments: str) -> str:
    return subprocess.run(
        ["git", "--no-optional-locks", "-C", str(repository), *arguments],
        check=True,
        capture_output=True,
        text=True,
        timeout=60,
    ).stdout


def last_used(repository: Path) -> float:
    timestamps = [repository.stat().st_mtime]
    for name in ("btca-last-used", "FETCH_HEAD"):
        marker = repository / ".git" / name
        if marker.exists():
            timestamps.append(marker.stat().st_mtime)
    return max(timestamps)


def has_local_work(repository: Path) -> bool:
    # A clone made with --no-checkout has no index and appears entirely deleted.
    unmaterialized = not (repository / ".git" / "index").exists() and all(
        entry.name == ".git" for entry in repository.iterdir()
    )
    if not unmaterialized and git(repository, "status", "--porcelain"):
        return True
    return bool(
        git(
            repository,
            "rev-list",
            "--max-count=1",
            "HEAD",
            "--branches",
            "--not",
            "--remotes",
        )
    )


def clean_cache(cache: Path, *, dry_run: bool = False) -> None:
    if not cache.exists():
        return
    cutoff = time.time() - 24 * 60 * 60
    for repository in sorted(cache.iterdir()):
        metadata = repository / ".git"
        if (
            repository.is_symlink()
            or repository.is_mount()
            or not repository.is_dir()
            or metadata.is_symlink()
            or not metadata.is_dir()
        ):
            continue
        try:
            if last_used(repository) >= cutoff:
                continue
            if has_local_work(repository):
                print(
                    f"Keeping {repository.name}: local changes or commits", flush=True
                )
                continue
            # A researcher may have refreshed the marker while Git was inspected.
            if last_used(repository) >= cutoff:
                continue
            if dry_run:
                print(f"Would remove {repository.name}", flush=True)
            else:
                shutil.rmtree(repository)
                print(f"Removed {repository.name}", flush=True)
        except (OSError, subprocess.SubprocessError) as error:
            print(f"Keeping {repository.name}: {error}", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cache", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    arguments = parser.parse_args()
    clean_cache(arguments.cache, dry_run=arguments.dry_run)
