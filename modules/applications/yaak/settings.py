"""Disable Yaak's updater without creating or migrating its settings database."""

import sqlite3
import sys


def prepare(directory, _replacement):
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

    def update():
        with sqlite3.connect(f"{path.as_uri()}?mode=rw", uri=True) as database:
            database.execute(
                "UPDATE settings SET autoupdate = 0, auto_download_updates = 0 WHERE id = 'default'"
            )

    return [update]
