import errno
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def prepare_linux_mount(target: str) -> None:
    result = subprocess.run(
        [
            "findmnt",
            "--json",
            "--nocanonicalize",
            "--mountpoint",
            target,
            "--output",
            "FSTYPE,OPTIONS",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode == 1:
        return
    result.check_returncode()
    mounts = json.loads(result.stdout)["filesystems"]
    if len(mounts) == 1:
        mount = mounts[0]
        owned = f"user_id={os.getuid()}" in mount["options"].split(",")
        if mount["fstype"] == "fuse.rclone" and owned:
            try:
                os.stat(target)
            except OSError as error:
                # Only a disconnected kernel FUSE endpoint permits recovery.
                if error.errno == errno.ENOTCONN:
                    subprocess.run(
                        ["/run/wrappers/bin/fusermount3", "-uz", "--", target],
                        check=True,
                    )
                    return
    raise SystemExit(f"{target} is already mounted; stop its existing owner first.")


def prepare_darwin_mount(target: str) -> None:
    # FUSE-T's orphaned helper waits for umount before exiting. Starting its
    # replacement earlier can race that teardown even after the mount disappears.
    helpers = {
        "/usr/local/bin/go-nfsv4",
        str(Path("/usr/local/bin/go-nfsv4").resolve()),
    }
    deadline = time.monotonic() + 10
    while True:
        processes = subprocess.check_output(
            ["/bin/ps", "-axo", "uid=,ppid=,comm=", "-ww"], text=True
        )
        orphaned = any(
            len(fields) == 3
            and int(fields[0]) == os.getuid()
            and fields[1] == "1"
            and fields[2] in helpers
            for fields in (line.split(None, 2) for line in processes.splitlines())
        )
        if not orphaned:
            break
        if time.monotonic() >= deadline:
            raise SystemExit("FUSE-T is still unmounting; wait for its helper to exit.")
        time.sleep(0.1)
    mounts = subprocess.check_output(["/sbin/mount"], text=True)
    if f" on {target} (" in mounts:
        raise SystemExit(f"{target} is already mounted; stop its existing owner first.")


def main() -> None:
    lock_path, target, *command = sys.argv[1:]
    descriptor = os.open(lock_path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        fcntl.lockf(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError as error:
        if error.errno in (errno.EACCES, errno.EAGAIN):
            raise SystemExit("The Filen mount cache is already in use.") from None
        raise
    # POSIX locks survive exec but belong to this process, not FUSE-T's children.
    os.set_inheritable(descriptor, True)
    if sys.platform == "linux":
        prepare_linux_mount(target)
    else:
        prepare_darwin_mount(target)
    os.makedirs(target, mode=0o700, exist_ok=True)
    os.chmod(target, 0o700)
    # A crashed process can leave its socket; the cache lock excludes a live owner.
    Path(lock_path).with_name("rc.sock").unlink(missing_ok=True)
    os.execv(command[0], command)


if __name__ == "__main__":
    main()
