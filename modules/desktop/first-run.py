"""Coordinate native macOS approvals and account setup without storing credentials."""

import argparse
import json
import os
import plistlib
import pwd
import sqlite3
import subprocess
import sys
from pathlib import Path

PANES = {
    "Accessibility": "Privacy_Accessibility",
    "ScreenCapture": "Privacy_ScreenCapture",
    "Microphone": "Privacy_Microphone",
    "SystemPolicyAppBundles": "Privacy_AppBundles",
    "SystemPolicyNetworkVolumes": "Privacy_FilesAndFolders",
    "AppleEvents": "Privacy_Automation",
}


def approvals(home):
    values = {}
    readable = False
    for path in [
        Path("/Library/Application Support/com.apple.TCC/TCC.db"),
        home / "Library/Application Support/com.apple.TCC/TCC.db",
    ]:
        try:
            with sqlite3.connect(f"{path.as_uri()}?mode=ro", uri=True) as database:
                rows = database.execute(
                    "SELECT service, client, auth_value, indirect_object_identifier FROM access"
                )
                for service, client, value, target in rows:
                    values[
                        (
                            service,
                            client,
                            target if service == "kTCCServiceAppleEvents" else None,
                        )
                    ] = value == 2
                readable = True
        except sqlite3.OperationalError:
            pass
    return values, readable


def checks(settings):
    home = Path(settings["home"])
    grants, _ = approvals(home)
    result = []
    if settings.get("remoteDesktop"):
        ready = None
        try:
            state = subprocess.run(
                [
                    "/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Support/tccstate"
                ],
                capture_output=True,
                timeout=5,
                check=False,
            )
            if state.returncode == 0:
                normalized = subprocess.run(
                    ["/usr/bin/plutil", "-convert", "xml1", "-o", "-", "-"],
                    input=state.stdout,
                    capture_output=True,
                    timeout=5,
                    check=False,
                )
                if normalized.returncode == 0:
                    remote_grants = plistlib.loads(normalized.stdout)
                    if (
                        isinstance(remote_grants, dict)
                        and {"screenCapture", "postEvent"} <= remote_grants.keys()
                    ):
                        values = [
                            remote_grants["screenCapture"],
                            remote_grants["postEvent"],
                        ]
                        if all(
                            isinstance(value, (int, str)) and value in (0, 1, "0", "1")
                            for value in values
                        ):
                            ready = all(value in (1, "1") for value in values)
        except (OSError, ValueError, subprocess.TimeoutExpired):
            pass
        result.append(
            {
                "name": "Native remote control",
                "ready": ready,
                "detail": "screen capture and remote input approved"
                if ready
                else "approve Remote Management screen capture and remote input in Sharing"
                if ready is False
                else "cannot inspect native approval without administrator access; check Remote Management in Sharing",
                "open": "x-apple.systempreferences:com.apple.Sharing-Settings.extension",
                "application": "/System/Applications/System Settings.app",
            }
        )
    session_checks = []
    if settings.get("unattended"):
        session_checks = [
            (
                "-autologin",
                "Automatic login user: " + settings["user"],
                "Automatic login",
                "com.apple.Users-Groups-Settings.extension",
            ),
            (
                "-screenLock",
                "screenLock is off",
                "No screen locking",
                "com.apple.Lock-Screen-Settings.extension",
            ),
        ]
    elif settings.get("manualLock"):
        session_checks = [
            (
                "-screenLock",
                "screenLock delay is immediate",
                "Manual locking requires a password",
                "com.apple.Lock-Screen-Settings.extension",
            )
        ]
    for argument, expected, title, pane in session_checks:
        status = subprocess.run(
            ["/usr/sbin/sysadminctl", argument, "status"],
            capture_output=True,
            text=True,
            check=False,
        )
        ready = expected in status.stdout + status.stderr
        result.append(
            {
                "name": title,
                "ready": ready,
                "detail": "configured"
                if ready
                else "native password enrollment is required",
                "open": "x-apple.systempreferences:" + pane,
                "application": "/System/Applications/System Settings.app",
            }
        )
    for item in settings["permissions"]:
        if not Path(item["application"]).exists():
            continue
        granted = grants.get(
            ("kTCCService" + item["service"], item["client"], item.get("target"))
        )
        result.append(
            {
                "name": f"{item['name']}: {item['service']}",
                "ready": granted,
                "detail": "approved"
                if granted is True
                else "not approved"
                if granted is False
                else "cannot inspect this approval from this process",
                "open": "x-apple.systempreferences:com.apple.preference.security?"
                + PANES[item["service"]],
                "application": item["application"],
            }
        )
    for item in settings["accounts"]:
        if not Path(item["application"]).exists():
            continue
        detail = "sign-in or Finder Enable is required"
        if item["name"] == "Filen":
            ready = Path(item["mountPoint"]).is_mount()
            if ready:
                detail = "mounted"
        elif item["name"] == "Tailscale":
            detail = "approve Network Extensions, sign in, and connect in Tailscale"
            try:
                status = as_user(
                    settings,
                    [
                        "/usr/bin/env",
                        "TAILSCALE_BE_CLI=1",
                        item["application"] + "/Contents/MacOS/Tailscale",
                        "status",
                        "--json",
                    ],
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
                ready = (
                    status.returncode == 0
                    and json.loads(status.stdout).get("BackendState") == "Running"
                )
            except (OSError, subprocess.TimeoutExpired, ValueError):
                ready = False
            if ready:
                detail = "VPN connected"
            if settings.get("unattended"):
                try:
                    onboarding = as_user(
                        settings,
                        [
                            "/usr/bin/defaults",
                            "read",
                            "io.tailscale.ipn.macsys",
                            "OnboardingFlow",
                        ],
                        capture_output=True,
                        text=True,
                        timeout=5,
                    )
                    complete = (
                        onboarding.returncode == 0
                        and onboarding.stdout.strip() == "hide"
                    )
                except (OSError, subprocess.TimeoutExpired):
                    complete = False
                if not complete:
                    ready = False
                    detail = (
                        "complete the Tailscale walkthrough: approve the extension and VPN "
                        "configuration, sign in, leave Start at login and connectivity "
                        "alerts off, choose Menu bar only, then click Start the Tailscale app"
                    )
        else:
            ready = False
            for path in (home / "Library/CloudStorage").glob(item["prefix"] + "*"):
                try:
                    list(path.iterdir())
                    ready = True
                except OSError:
                    pass
            if ready:
                detail = "filesystem accessible"
            if item["name"] == "Proton Drive" and settings.get("unattended"):
                if not ready:
                    detail = "sign in, enable Proton Drive in Finder, and leave Launch on startup enabled"
                else:
                    uid = pwd.getpwnam(settings["user"]).pw_uid
                    try:
                        launcher = as_user(
                            settings,
                            [
                                "/bin/launchctl",
                                "print",
                                f"gui/{uid}/ch.protonmail.drive.launcher.ProtonDriveMacLauncher",
                            ],
                            capture_output=True,
                            timeout=5,
                        )
                        ready = launcher.returncode == 0
                    except (OSError, subprocess.TimeoutExpired):
                        ready = False
                    if not ready:
                        detail = "enable Launch on startup in Proton Drive settings"
        result.append(
            {
                "name": item["name"],
                "ready": ready,
                "detail": detail,
                "open": item["application"],
            }
        )
    return result


def as_user(settings, arguments, **options):
    if os.geteuid() == 0:
        user = settings["user"]
        arguments = [
            "/bin/launchctl",
            "asuser",
            str(pwd.getpwnam(user).pw_uid),
            "/usr/bin/sudo",
            "-H",
            "-u",
            user,
            "--",
            *arguments,
        ]
    return subprocess.run(arguments, check=False, **options)


def show(rows):
    for row in rows:
        label = "UNKNOWN" if row["ready"] is None else "OK" if row["ready"] else "TODO"
        print(f"{label} {row['name']}: {row['detail']}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("settings")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Report readiness without opening apps or changing settings",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Return readiness for an agent or another program",
    )
    parser.add_argument(
        "--retry-default-apps",
        action="store_true",
        help="Retry declared app associations and their native confirmation dialogs",
    )
    args = parser.parse_args()
    settings = json.loads(Path(args.settings).read_text())
    if args.retry_default_apps:
        if args.check or args.json:
            parser.error(
                "--retry-default-apps changes associations; use it separately from read-only checks"
            )
        requests = (
            Path(settings["home"])
            / "Library/Application Support/nix-desktop/default-app-requests"
        )
        result = as_user(settings, ["/bin/rm", "-f", str(requests)])
        if result.returncode != 0:
            return result.returncode
        uid = pwd.getpwnam(settings["user"]).pw_uid
        result = as_user(
            settings,
            [
                "/bin/launchctl",
                "kickstart",
                "-k",
                f"gui/{uid}/{settings['desktopSessionService']}",
            ],
        )
        if result.returncode == 0:
            print(
                "Confirm any macOS default-application dialogs. Applications already set correctly are skipped."
            )
        return result.returncode
    rows = checks(settings)
    if not args.check and not args.json:
        if not sys.stdin.isatty():
            parser.error("Use --check for non-interactive inspection")
        pending = {}
        for row in rows:
            if row["ready"]:
                continue
            pending.setdefault(row["open"], []).append(row)
        for destination, group in pending.items():
            applications = set()
            for row in group:
                print(f"\n{row['name']}: {row['detail']}")
                application = row.get("application")
                if application and application not in applications:
                    applications.add(application)
                    if Path(application).suffix == ".app":
                        as_user(settings, ["/usr/bin/open", "-g", application])
                    else:
                        print(
                            f"Add and enable this executable in Settings: {application}"
                        )
                if row["name"] == "Filen":
                    print(
                        "For the native mount, use filen export-api-key, then filen-setup. Credentials stay in the encrypted config and OS keyring."
                    )
            if applications:
                print(
                    "Complete approvals for every application listed above. macOS may require your password."
                )
            as_user(settings, ["/usr/bin/open", destination])
            input("Press Enter after completing this step: ")
        rows = checks(settings)
    if args.json:
        print(json.dumps(rows, indent=2))
    else:
        show(rows)
    if any(row["ready"] is False for row in rows):
        return 1
    return 2 if any(row["ready"] is None for row in rows) else 0


if __name__ == "__main__":
    sys.exit(main())
