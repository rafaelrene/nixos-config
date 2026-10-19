"""Set native updater preferences without replacing unrelated application state."""

import configparser
import io
import json
import os
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

import tomlkit

APPLICATIONS = {
    "anytype": ("Anytype", "Library/Application Support/anytype"),
    "standard-notes": ("Standard Notes", "Library/Application Support/Standard Notes"),
    "freetube": ("FreeTube", "Library/Application Support/FreeTube"),
    "yaak": ("yaak-app", "Library/Application Support/app.yaak.desktop"),
    "obs-studio": ("OBS", "Library/Application Support/obs-studio"),
    "rustdesk": ("RustDesk", "Library/Preferences/com.carriez.RustDesk"),
}


def replacement(path, contents):
    """Prepare first; replace atomically only after every file has validated."""

    def write():
        path.parent.mkdir(parents=True, exist_ok=True)
        descriptor, temporary = tempfile.mkstemp(dir=path.parent)
        try:
            with os.fdopen(descriptor, "w") as output:
                output.write(contents)
            if path.exists():
                os.chmod(temporary, path.stat().st_mode & 0o777)
            os.replace(temporary, path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)

    return write


def prepare(app, directory):
    if app == "obs-studio":
        path = directory / "global.ini"
        data = configparser.ConfigParser(interpolation=None)
        data.optionxform = str
        if path.exists():
            data.read_string(path.read_text())
        if not data.has_section("General"):
            data.add_section("General")
        if data.get("General", "EnableAutoUpdates", fallback="").lower() == "false":
            return []
        data.set("General", "EnableAutoUpdates", "false")
        output = io.StringIO()
        data.write(output, space_around_delimiters=False)
        return [replacement(path, output.getvalue())]

    if app in ("anytype", "standard-notes"):
        filename, key, value = (
            ("devconfig.json", "updateDisabled", True)
            if app == "anytype"
            else ("user-preferences.json", "enableAutoUpdates", False)
        )
        path = directory / filename
        data = json.loads(path.read_text()) if path.exists() else {}
        if not isinstance(data, dict):
            raise ValueError(f"Expected JSON object in {path}")
        if data.get(key) is value:
            return []
        data[key] = value
        return [replacement(path, json.dumps(data, indent=2) + "\n")]

    if app == "freetube":
        path = directory / "settings.db"
        if path.with_name("settings.db~").exists():
            raise ValueError(
                "FreeTube has pending database recovery; open and close it first"
            )
        contents = path.read_text() if path.exists() else ""
        current = None
        for line in contents.splitlines():
            if line.strip():
                record = json.loads(line)
                if record.get("_id") == "checkForUpdates":
                    current = None if record.get("$$deleted") else record.get("value")
        if current is False:
            return []
        contents = contents.rstrip("\n") + ("\n" if contents else "")
        contents += json.dumps({"_id": "checkForUpdates", "value": False}) + "\n"
        return [replacement(path, contents)]

    if app == "rustdesk":
        writes = []
        for filename, key in (
            ("RustDesk_local.toml", "enable-check-update"),
            ("RustDesk2.toml", "allow-auto-update"),
        ):
            path = directory / filename
            data = (
                tomlkit.parse(path.read_text()) if path.exists() else tomlkit.document()
            )
            if "options" not in data:
                data["options"] = tomlkit.table()
            if data["options"].get(key) == "N":
                continue
            data["options"][key] = "N"
            writes.append(replacement(path, tomlkit.dumps(data)))
        return writes

    # Yaak owns its schema and migrations. Never create a partial database.
    path = directory / "db.sqlite"
    if not path.exists():
        print(
            "Yaak is not initialized; disable its updater in Settings before use",
            file=sys.stderr,
        )
        return []
    with sqlite3.connect(f"{path.as_uri()}?mode=ro", uri=True) as database:
        row = database.execute(
            "SELECT autoupdate, auto_download_updates FROM settings WHERE id = 'default'"
        ).fetchone()
    if row is None:
        print(
            "Yaak has no settings row; disable its updater in Settings before use",
            file=sys.stderr,
        )
        return []
    if row == (0, 0):
        return []

    def update_yaak():
        with sqlite3.connect(f"{path.as_uri()}?mode=rw", uri=True) as database:
            database.execute(
                "UPDATE settings SET autoupdate = 0, auto_download_updates = 0 WHERE id = 'default'"
            )

    return [update_yaak]


def main():
    app, phase = sys.argv[1:]
    if phase not in ("check", "apply"):
        raise ValueError("Expected check or apply")
    process, relative = APPLICATIONS[app]
    writes = prepare(app, Path.home() / relative)
    if not writes:
        return
    result = subprocess.run(
        ["/usr/bin/pgrep", "-i", "-x", process], capture_output=True, check=False
    )
    if result.returncode == 0:
        raise ValueError(f"Close {process} before rebuilding its updater preferences")
    if result.returncode != 1:
        raise ValueError(f"Could not check whether {process} is running")
    if phase == "apply":
        for write in writes:
            write()


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, sqlite3.Error) as error:
        sys.exit(str(error))
