import argparse
import base64
import getpass
import http.client
import os
import re
import shlex
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

MACOS = sys.platform == "darwin"
SERVICE = "workstation-bitbucket"
LEGACY_SERVICE = "t3code-bitbucket-api-token"
ACCOUNT = "bitbucket"
EMAIL_KEY = "T3CODE_BITBUCKET_EMAIL"
TOKEN_KEY = "T3CODE_BITBUCKET_API_TOKEN"


def credential_file():
    home = Path.home()
    base = home / ".local/share/t3code"
    native = home / ".t3"
    if (
        MACOS
        and not base.exists()
        and not base.is_symlink()
        and native.is_dir()
        and not native.is_symlink()
    ):
        base = native
    return base / "bitbucket.env"


def valid(email, token):
    return bool(re.fullmatch(r"[!-9;-~]+@[!-9;-~]+", email)) and bool(
        re.fullmatch(r"[!-~]+", token)
    )


def security(*args, command=None):
    return subprocess.run(
        ["/usr/bin/security", *args],
        input=command,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        timeout=15,
    )


def keychain_password(service, account):
    result = security("find-generic-password", "-s", service, "-a", account, "-w")
    return result.stdout.rstrip("\n") if result.returncode == 0 else ""


def load_keychain():
    entry = keychain_password(SERVICE, ACCOUNT)
    if entry:
        email, _, token = entry.partition(":")
        return email, token

    metadata = security("find-generic-password", "-s", LEGACY_SERVICE)
    account = re.search(r'^\s*"acct"<blob>="([^"]+)"$', metadata.stdout, re.M)
    if account:
        email = subprocess.run(
            ["/bin/launchctl", "getenv", EMAIL_KEY],
            capture_output=True,
            text=True,
            timeout=5,
        ).stdout.strip()
        return email, keychain_password(LEGACY_SERVICE, account[1])
    return "", ""


def load_file():
    keys = {}
    try:
        with credential_file().open() as stream:
            info = os.fstat(stream.fileno())
            if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077:
                raise ValueError("Bitbucket credentials file must be private.")
            for line in stream:
                name, _, value = line.strip().partition("=")
                if name in (EMAIL_KEY, TOKEN_KEY):
                    values = shlex.split(value)
                    if len(values) == 1:
                        keys[name] = values[0]
    except FileNotFoundError:
        pass
    return keys.get(EMAIL_KEY, ""), keys.get(TOKEN_KEY, "")


def load():
    email, token = load_file()
    if MACOS and not token:
        email, token = load_keychain()
    return (email, token) if valid(email, token) else ("", "")


def save(email, token):
    if MACOS:
        entry = f"{email}:{token}"
        # security's interactive command keeps the password out of process arguments.
        command = f"add-generic-password -U -s {SERVICE} -a {ACCOUNT} -X {entry.encode().hex()}\n"
        security("-i", command=command)
        if keychain_password(SERVICE, ACCOUNT) != entry:
            raise ValueError("Could not save the Bitbucket credential to Keychain.")
        credential_file().unlink(missing_ok=True)
        return

    save_file(email, token)


def save_file(email, token):
    path = credential_file()
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            # systemd consumes this file too. Escape double quotes and backslashes.
            for name, value in ((EMAIL_KEY, email), (TOKEN_KEY, token)):
                quoted = value.replace("\\", "\\\\").replace('"', '\\"')
                stream.write(f'{name}="{quoted}"\n')
            stream.close()
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def install(email, token):
    try:
        save(email, token)
    except (OSError, ValueError, subprocess.TimeoutExpired):
        if not MACOS:
            raise
        # A switch over SSH can run before the login Keychain is unlocked.
        save_file(email, token)


def verify(email, token):
    authorization = base64.b64encode(f"{email}:{token}".encode()).decode()
    connection = http.client.HTTPSConnection("api.bitbucket.org", timeout=15)
    try:
        connection.request(
            "GET", "/2.0/user", headers={"Authorization": f"Basic {authorization}"}
        )
        status = connection.getresponse().status
    finally:
        connection.close()
    if status != 200:
        raise ValueError(
            f"Bitbucket returned HTTP {status}. Check the email, token, and User Read scope."
        )


def setup(args):
    parser = argparse.ArgumentParser(
        prog="bitbucket-setup",
        description="Set up or rotate the shared Bitbucket Cloud API token for T3 Code and TWG.",
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--check", action="store_true", help="Verify the stored credential."
    )
    mode.add_argument(
        "--adopt", action="store_true", help="Verify and save the existing credential."
    )
    options = parser.parse_args(args)
    if options.check or options.adopt:
        email, token = load()
        if not token:
            raise ValueError(
                "No shared Bitbucket credential found. Run bitbucket-setup."
            )
    else:
        if not sys.stdin.isatty():
            raise ValueError("Run bitbucket-setup in an interactive terminal.")
        email = input("Atlassian account email: ").strip()
        token = getpass.getpass("Bitbucket API token: ")
        if not valid(email, token):
            raise ValueError("Enter an Atlassian email and a Bitbucket API token.")
    verify(email, token)
    if options.check:
        print("Bitbucket accepted the stored credential.")
    else:
        save(email, token)
        print("Bitbucket credential saved. TWG will use it on the next command.")
        print("Restart the T3 Code server to apply it.")


def main():
    action, *args = sys.argv[1:]
    if action == "setup":
        setup(args)
        return

    try:
        email, token = (
            load() if action == "read" or not os.getenv("TWG_BBC_TOKEN") else ("", "")
        )
    except (OSError, ValueError, subprocess.TimeoutExpired):
        print(
            "Could not read the shared Bitbucket credential. Run bitbucket-setup --check.",
            file=sys.stderr,
        )
        email, token = "", ""

    if action == "read":
        if token:
            print(email, token, sep="\t")
        return

    if token:
        os.environ.update(TWG_BBC_USER=email, TWG_BBC_TOKEN=token)
    os.execv(args[0], args)


if __name__ == "__main__":
    try:
        main()
    except ValueError as error:
        sys.exit(str(error))
    except (OSError, http.client.HTTPException, subprocess.TimeoutExpired, EOFError):
        sys.exit(
            "Bitbucket setup failed while reading, verifying, or saving the credential."
        )
