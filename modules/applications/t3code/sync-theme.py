"""Apply the shared palette to a closed T3 desktop's existing Chromium profile."""

import hashlib
import json
import sys
from pathlib import Path

import plyvel

ORIGIN = b"_t3code://app\0"
LIBRARY = "t3code:themes:v1"
GENERATION = "t3code:nix-theme-generation"


def decode(value):
    if value is None:
        return None
    if value[:1] == b"\x01":
        return value[1:].decode("latin-1")
    if value[:1] == b"\x00":
        return value[1:].decode("utf-16-le")
    raise ValueError("Unsupported Chromium string encoding")


def encode(value):
    # JSON is ASCII escaped; selection IDs and generation hashes are ASCII too.
    return b"\x01" + value.encode("ascii")


def sync_theme(theme_file, directory):
    if not (directory / "CURRENT").exists():
        # Chromium initializes new profiles; the next controlled launch themes it.
        return

    raw_theme = theme_file.read_bytes()
    theme = json.loads(raw_theme)
    entry = {
        "id": theme["id"],
        "label": theme["name"],
        "appearance": theme["appearance"],
        "colors": theme["colors"],
    }
    generation = hashlib.sha256(raw_theme).hexdigest()

    # Client-only desktops ignore server themes. Use LevelDB's own exclusive lock
    # only after the lifecycle has stopped all desktop processes, before reopening.
    with plyvel.DB(str(directory), create_if_missing=False) as database:
        if database.get(b"VERSION") != b"1":
            raise ValueError("Unsupported Chromium Local Storage version")
        values = {
            decode(key[len(ORIGIN) :]): (key, decode(value))
            for key, value in database.iterator(prefix=ORIGIN)
        }
        if any(key.startswith("t3code:themes:") and key != LIBRARY for key in values):
            raise ValueError("Unsupported T3 theme library version")
        library = json.loads(values.get(LIBRARY, (None, "[]"))[1])
        if not isinstance(library, list):
            raise TypeError("T3 theme library is not an array")
        # Preserve imports and unrecognized entries; own only the workstation ID.
        library = [
            item
            for item in library
            if not isinstance(item, dict) or item.get("id") != entry["id"]
        ] + [entry]
        updates = {LIBRARY: json.dumps(library, separators=(",", ":"))}
        if values.get(GENERATION, (None, None))[1] != generation:
            updates |= {
                "t3code:theme": entry["id"],
                "t3code:theme-appearance-mode": entry["appearance"],
                "t3code:theme-follow-system": "false",
                "t3code:theme-halves:v1": None,
                GENERATION: generation,
            }
        changes = {
            key: value
            for key, value in updates.items()
            if values.get(key, (None, None))[1] != value
        }
        if not changes:
            return
        with database.write_batch(transaction=True, sync=True) as batch:
            for key, value in changes.items():
                # Blink may encode even ASCII keys as UTF-16LE.
                batch.delete(ORIGIN + b"\x00" + key.encode("utf-16-le"))
                batch.delete(ORIGIN + encode(key))
                if value is not None:
                    batch.put(ORIGIN + encode(key), encode(value))


if __name__ == "__main__":
    sync_theme(Path(sys.argv[1]), Path(sys.argv[2]))
