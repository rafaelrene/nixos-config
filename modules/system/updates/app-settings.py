"""Merge declared native preferences without replacing unrelated application state."""

import configparser
import io
import json
import os
import runpy
import sqlite3
import subprocess
import sys
import tempfile
from collections.abc import MutableMapping
from pathlib import Path

import tomlkit


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


def merge(data, settings, table=dict):
    if not isinstance(data, MutableMapping):
        raise TypeError("Expected a native settings table")
    changed = False
    for key, value in settings.items():
        if isinstance(value, dict):
            if key not in data:
                data[key] = table()
            changed = merge(data[key], value, table) or changed
        elif data.get(key) != value or (
            isinstance(value, bool) and data.get(key) is not value
        ):
            data[key] = value
            changed = True
    return changed


def prepare_file(path, declaration):
    contents = path.read_text() if path.exists() else ""
    settings = declaration["settings"]
    match declaration["format"]:
        case "json":
            data = json.loads(contents) if path.exists() else {}
            if not isinstance(data, dict):
                raise TypeError(f"Expected JSON object in {path}")
            if not merge(data, settings):
                return []
            output = json.dumps(data, indent=2) + "\n"
        case "toml":
            data = tomlkit.parse(contents) if contents else tomlkit.document()
            if not merge(data, settings, tomlkit.table):
                return []
            output = tomlkit.dumps(data)
        case "ini":
            data = configparser.ConfigParser(interpolation=None)
            data.optionxform = str
            if contents:
                data.read_string(contents)
            changed = False
            for section, values in settings.items():
                if not data.has_section(section):
                    data.add_section(section)
                for key, value in values.items():
                    expected = (
                        str(value).lower() if isinstance(value, bool) else str(value)
                    )
                    current = data.get(section, key, fallback="")
                    if isinstance(value, bool):
                        current = current.lower()
                    if current != expected:
                        data.set(section, key, expected)
                        changed = True
            if not changed:
                return []
            buffer = io.StringIO()
            data.write(buffer, space_around_delimiters=False)
            output = buffer.getvalue()
        case unknown:
            raise ValueError(f"Unsupported native preference format: {unknown}")
    return [replacement(path, output)]


def main():
    settings_file, phase = sys.argv[1:]
    if phase not in ("check", "apply"):
        raise ValueError("Expected check or apply")
    settings = json.loads(Path(settings_file).read_text())
    directory = Path.home() / settings["directory"]
    writes = []
    for filename, declaration in settings.get("files", {}).items():
        writes.extend(prepare_file(directory / filename, declaration))
    # Native databases need an application-owned prepare(directory, replacement)
    # function returning deferred writes, with no mutations during the check phase.
    if "prepare" in settings:
        prepare = runpy.run_path(settings["prepare"])["prepare"]
        writes.extend(prepare(directory, replacement))
    if not writes:
        return
    process = settings["process"]
    result = subprocess.run(
        ["/usr/bin/pgrep", "-i", "-x", process], capture_output=True, check=False
    )
    if result.returncode == 0:
        raise ValueError(f"Close {process} before rebuilding its managed preferences")
    if result.returncode != 1:
        raise ValueError(f"Could not check whether {process} is running")
    if phase == "apply":
        for write in writes:
            write()


if __name__ == "__main__":
    try:
        main()
    except (ValueError, TypeError, OSError, sqlite3.Error, configparser.Error) as error:
        sys.exit(str(error))
