"""Disable FreeTube's updater in its append-only settings database."""

import json


def prepare(directory, replacement):
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
