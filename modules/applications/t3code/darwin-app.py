"""Keep the signed desktop at a stable path without overwriting a live bundle."""

import ctypes
import json
import os
import plistlib
import pwd
import shutil
import stat
import subprocess
import sys
from pathlib import Path


def save_json(path, value):
    temporary = path.with_suffix(".tmp")
    with temporary.open("w") as output:
        json.dump(value, output)
        output.flush()
        os.fsync(output.fileno())
    temporary.replace(path)
    sync_directory(path.parent)


def sync_directory(path):
    descriptor = os.open(path, os.O_RDONLY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def writable_directories(path):
    for root, _, _ in os.walk(path):
        directory = Path(root)
        mode = directory.lstat().st_mode
        if stat.S_ISDIR(mode) and not mode & stat.S_IWUSR:
            directory.chmod(mode | stat.S_IWUSR)


def copy_contents(source, destination):
    # Create writable directories ourselves. Preserve signed files and framework
    # symlinks without inheriting the Nix store's read-only directory modes.
    for item in source.iterdir():
        copied = destination / item.name
        if item.is_symlink():
            copied.symlink_to(os.readlink(item))
        elif item.is_dir():
            copied.mkdir()
            copy_contents(item, copied)
        else:
            shutil.copy2(item, copied)


def identity(path):
    # Both copies stay in one directory. macOS device numbers change on reboot.
    return str(path.stat().st_ino)


def version(app):
    with (app / "Contents/Info.plist").open("rb") as source:
        return plistlib.load(source)["CFBundleVersion"]


def verify(app, target):
    expected = json.loads((Path(target) / "share/t3code/release.json").read_text())
    if version(app) != expected["version"]:
        raise RuntimeError("The copied T3 Code desktop has the wrong version.")
    subprocess.run(
        ["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)], check=True
    )
    source = Path(target) / "Applications/T3 Code (Nightly).app"
    if signature(app) != signature(source):
        raise RuntimeError("The T3 Code desktop does not match its Nix release.")


def signature(app):
    result = subprocess.run(
        ["/usr/bin/codesign", "--display", "--verbose=4", str(app)],
        capture_output=True,
        text=True,
        check=True,
    )
    for line in result.stderr.splitlines():
        if line.startswith("CDHash="):
            return line
    raise RuntimeError(f"No code signature identity was found for {app}.")


def exchange(source, destination):
    # RENAME_SWAP replaces two nonempty directories atomically on APFS.
    rename = ctypes.CDLL(None, use_errno=True).renamex_np
    rename.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
    rename.restype = ctypes.c_int
    if rename(os.fsencode(source), os.fsencode(destination), 2) != 0:
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error))


class Desktop:
    def __init__(self, settings):
        self.app = Path(settings["home"]) / "Applications/T3 Code.app"
        self.candidate = self.app.with_name(".T3 Code.next.app")
        self.record = Path(settings["state"]) / "desktop-copies.json"
        self.releases = [
            settings.get(key) for key in ("initial", "profile", "previous", "staged")
        ]

    def copies(self):
        copies = json.loads(self.record.read_text()) if self.record.exists() else {}
        # Read legacy device:inode records even after the device is renumbered.
        return {key.rsplit(":", 1)[-1]: target for key, target in copies.items()}

    def matches(self, app, target):
        if not app.exists() or app.is_symlink():
            return False
        expected = json.loads((Path(target) / "share/t3code/release.json").read_text())
        try:
            return (
                self.copies().get(identity(app)) == target
                and version(app) == expected["version"]
            )
        except (OSError, ValueError, KeyError):
            return False

    def current(self, target):
        return self.matches(self.app, target)

    def known_release(self, app, copies):
        # An older updater could leave a complete retained copy unrecorded.
        # A name, bundle ID or version alone never authorizes deleting it.
        for target in dict.fromkeys([*copies.values(), *self.releases]):
            if target is None or not Path(target).exists():
                continue
            target = str(Path(target).resolve())
            try:
                verify(app, target)
            except (
                OSError,
                ValueError,
                KeyError,
                RuntimeError,
                subprocess.CalledProcessError,
            ):
                continue
            return target
        return None

    def prepare(self, target):
        copies = self.copies()
        if self.app.is_symlink() or self.app.exists():
            managed = None if self.app.is_symlink() else copies.get(identity(self.app))
            if managed is None:
                raise RuntimeError(
                    f"An unmanaged application already exists at {self.app}."
                )
            # Legacy device:inode records must still describe the signed release.
            verify(self.app, managed)
        if self.current(target):
            return
        if self.candidate.is_symlink():
            raise RuntimeError(f"Refusing to replace a symlink at {self.candidate}.")
        if self.matches(self.candidate, target):
            try:
                verify(self.candidate, target)
                return
            except (
                OSError,
                ValueError,
                KeyError,
                RuntimeError,
                subprocess.CalledProcessError,
            ):
                # A recorded copy may have been interrupted before verification.
                pass
        self.app.parent.mkdir(parents=True, exist_ok=True)
        if self.candidate.exists():
            if (
                identity(self.candidate) not in copies
                and self.known_release(self.candidate, copies) is None
            ):
                raise RuntimeError(
                    f"An unmanaged application already exists at {self.candidate}."
                )
            writable_directories(self.candidate)
            shutil.rmtree(self.candidate)
        # Record only the live copy before creating the new candidate. Inode reuse
        # must never make an incomplete copy look like a previously verified one.
        copies = (
            {identity(self.app): copies[identity(self.app)]}
            if self.app.exists()
            else {}
        )
        save_json(self.record, copies)
        source = Path(target) / "Applications/T3 Code (Nightly).app"
        self.candidate.mkdir()
        sync_directory(self.app.parent)
        # Record ownership before writing contents so interrupted copies can be
        # removed safely. Only a verified copy may be exchanged into the live path.
        copies[identity(self.candidate)] = target
        save_json(self.record, copies)
        try:
            copy_contents(source, self.candidate)
            verify(self.candidate, target)
            subprocess.run(["/bin/sync"], check=True)
            save_json(self.record, copies)
        except Exception as failure:
            try:
                if self.candidate.exists():
                    writable_directories(self.candidate)
                    shutil.rmtree(self.candidate)
            except OSError as cleanup:
                failure.add_note(
                    f"The recorded candidate could not be removed: {cleanup}"
                )
            raise

    def install(self, target):
        self.prepare(target)
        if self.current(target):
            return
        # The inode-to-release record is durable before the swap. Both the new
        # live copy and the retained old copy remain identifiable after a crash.
        if self.app.exists():
            exchange(self.candidate, self.app)
        else:
            self.candidate.rename(self.app)
        sync_directory(self.app.parent)

    def process_current(self, target, pid):
        if not self.current(target):
            return False
        # Version alone cannot identify a client restored without our updater flag.
        environment = subprocess.run(
            ["/bin/ps", "eww", "-p", pid, "-o", "command="],
            capture_output=True,
            text=True,
            check=False,
        )
        if (
            environment.returncode != 0
            or "T3CODE_DISABLE_AUTO_UPDATE=true" not in environment.stdout.split()
        ):
            return False
        with (self.app / "Contents/Info.plist").open("rb") as source:
            executable = plistlib.load(source)["CFBundleExecutable"]
        binary = self.app / "Contents/MacOS" / executable
        result = subprocess.run(
            ["/usr/sbin/lsof", "-a", "-p", pid, "-d", "txt", "-Fni"],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            return False
        inode = None
        for line in result.stdout.splitlines():
            if line.startswith("f"):
                inode = None
            elif line.startswith("i"):
                inode = line[1:]
            elif line == f"n{binary}" and inode == str(binary.stat().st_ino):
                return True
        return False


def is_t3(tile):
    data = tile.get("tile-data", {})
    return data.get("bundle-identifier") in {
        "com.t3tools.t3code",
        "local.proserpina.t3code-client",
    } or data.get("file-label") in {"T3 Code", "T3 Code (Nightly)"}


def dock_tiles(tiles, app, refresh=False):
    result = []
    inserted = False
    for tile in tiles:
        if not is_t3(tile):
            result.append(tile)
        elif not inserted:
            data = tile.get("tile-data", {})
            url = app.as_uri() + "/"
            if data.get("file-data", {}).get("_CFURLString") == url and not refresh:
                result.append(tile)
            else:
                replacement = {
                    "tile-type": "file-tile",
                    "tile-data": {
                        "bundle-identifier": "com.t3tools.t3code",
                        "file-label": "T3 Code",
                        "file-type": 1,
                        "file-data": {"_CFURLString": url, "_CFURLStringType": 15},
                    },
                }
                if "GUID" in tile:
                    replacement["GUID"] = tile["GUID"]
                result.append(replacement)
            inserted = True
    # Preserve an unpinned Dock. Existing T3 pins are migrated in place.
    return result


def migrate_dock(app, record):
    preferences = plistlib.loads(
        subprocess.check_output(["/usr/bin/defaults", "export", "com.apple.dock", "-"])
    )
    changed = False
    installed = identity(app)
    refresh = not record.exists() or record.read_text() != installed
    for key in ("persistent-apps", "recent-apps"):
        previous = preferences.get(key, [])
        updated = (
            dock_tiles(previous, app, refresh)
            if key == "persistent-apps"
            else [tile for tile in previous if not is_t3(tile)]
        )
        if previous != updated:
            # Write only the affected arrays; retain unrelated Dock preferences,
            # tile GUIDs and binary bookmark data for all other applications.
            values = [plistlib.dumps(tile).decode() for tile in updated]
            subprocess.run(
                [
                    "/usr/bin/defaults",
                    "write",
                    "com.apple.dock",
                    key,
                    "-array",
                    *values,
                ],
                check=True,
            )
            changed = True
    subprocess.run(
        [
            "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
            "-f",
            str(app),
        ],
        check=True,
    )
    if changed:
        subprocess.run(
            ["/usr/bin/killall", "-u", pwd.getpwuid(os.getuid()).pw_name, "Dock"],
            check=False,
        )
    record.write_text(installed)


def main():
    settings = json.loads(Path(sys.argv[1]).read_text())
    desktop = Desktop(settings)
    action = sys.argv[2]
    target = sys.argv[3]
    if action == "prepare":
        desktop.prepare(target)
    elif action == "install":
        desktop.install(target)
    elif action == "current":
        print(str(desktop.current(target)).lower())
    elif action == "process-current":
        print(str(desktop.process_current(target, sys.argv[4])).lower())
    elif action == "dock":
        migrate_dock(desktop.app, Path(settings["state"]) / "dock-app-inode")
    else:
        raise ValueError(f"Unknown desktop action: {action}")


if __name__ == "__main__":
    main()
