"""Record the newest published T3 nightly and its four official artifact hashes."""

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path


def release_snapshot(releases):
    nightlies = [
        release
        for release in releases
        if not release.get("draft")
        and release.get("prerelease")
        and re.fullmatch(
            r"v\d+\.\d+\.\d+-nightly\.\d{8}\.\d+", release.get("tag_name", "")
        )
        and release.get("published_at")
    ]
    if not nightlies:
        raise ValueError("No published nightly appears in the latest 100 releases.")
    release = max(nightlies, key=lambda item: item["published_at"])
    version = release["tag_name"][1:]

    def artifact(*names):
        assets = [asset for asset in release["assets"] if asset["name"] in names]
        if len(assets) != 1:
            raise ValueError(
                f"Nightly {version} needs exactly one artifact named {' or '.join(names)}."
            )
        asset = assets[0]
        digest = asset.get("digest", "")
        if not isinstance(digest, str) or not re.fullmatch(
            r"sha256:[0-9a-f]{64}", digest
        ):
            raise ValueError(
                f"Nightly {version} has no SHA-256 digest for {asset['name']}."
            )
        return {
            "url": asset["browser_download_url"],
            "hash": "sha256-" + base64.b64encode(bytes.fromhex(digest[7:])).decode(),
        }

    platforms = {}
    for system, server, desktop in (
        ("aarch64-darwin", "darwin-arm64", "arm64.zip"),
        ("x86_64-linux", "linux-x64", "x86_64.AppImage"),
    ):
        desktop_asset = artifact(
            f"T3-Code-{version}-{desktop}", f"T3-Code-Nightly-{desktop}"
        )
        platforms[system] = {
            "serverHash": artifact(f"t3-{version}-{server}.tar.gz")["hash"],
            "desktopHash": desktop_asset["hash"],
            "desktopUrl": desktop_asset["url"],
        }
    return {"version": version, "platforms": platforms}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    destination = parser.parse_args().destination
    # Public releases remain available before the first gh auth login.
    token = subprocess.run(
        ["gh", "auth", "token", "--hostname", "github.com"],
        check=False,
        capture_output=True,
        text=True,
    )
    headers = "Accept: application/vnd.github+json\n"
    if token.returncode == 0:
        credential = token.stdout.strip()
        if not credential or any(character.isspace() for character in credential):
            raise ValueError("GitHub returned an invalid authentication token.")
        headers += f"Authorization: Bearer {credential}\n"
    response = subprocess.run(
        [
            "curl",
            "--fail",
            "--silent",
            "--show-error",
            "--connect-timeout",
            "10",
            "--max-time",
            "30",
            "--header",
            "@-",
            "https://api.github.com/repos/pingdotgg/t3code/releases?per_page=100",
        ],
        input=headers,
        check=True,
        capture_output=True,
        text=True,
    )
    snapshot = release_snapshot(json.loads(response.stdout))
    content = json.dumps(snapshot, indent=2) + "\n"
    if not destination.exists() or destination.read_text() != content:
        destination.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(
            mode="w", dir=destination.parent, delete=False
        ) as output:
            temporary = Path(output.name)
            output.write(content)
        try:
            temporary.chmod(0o644)
            os.replace(temporary, destination)
        finally:
            temporary.unlink(missing_ok=True)
    print(f"T3 Code: selected official nightly {snapshot['version']}.")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(f"T3 release discovery failed: {error.stderr.strip()}", file=sys.stderr)
        sys.exit(1)
    except (KeyError, TypeError, ValueError, OSError) as error:
        print(f"T3 release discovery failed: {error}", file=sys.stderr)
        sys.exit(1)
