"""Runtime-only SSH key provisioning, called by the NixOS pre-switch hook."""

import argparse
import base64
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile


KEYS = ("personal", "bitbucket_work", "othinus")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def private_directory(path):
    if path.is_symlink():
        raise RuntimeError(f"Refusing a symlinked private directory: {path}")
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    if path.stat().st_uid != os.getuid():
        raise RuntimeError(f"Private directory belongs to another user: {path}")
    path.chmod(0o700)


def atomic_write(path, data, mode=0o600):
    fd, name = tempfile.mkstemp(prefix=f".{path.name}-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
            os.fchmod(stream.fileno(), mode)
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def backup(path):
    if path.exists() or path.is_symlink():
        fd, name = tempfile.mkstemp(prefix=f"{path.name}.before-nixos-", dir=path.parent)
        os.close(fd)
        os.replace(path, name)
        print(f"Preserved existing {path.name} as {Path(name).name}.", flush=True)


def age_interactive(args, arguments):
    if not os.isatty(0):
        raise RuntimeError("SSH keys need a passphrase. Run nixos-rebuild switch in an interactive terminal.")
    # nixos-rebuild-ng passes terminal FDs through systemd-run --pipe, but the
    # service has no controlling terminal. script gives age its own PTY while
    # forwarding the inherited terminal. Never log terminal input or output.
    result = subprocess.run(
        [args.script, "--quiet", "--return", "--echo", "never", "--command",
         shlex.join([args.age, *map(str, arguments)]), "/dev/null"],
        check=False,
    )
    if result.returncode:
        raise RuntimeError("SSH key encryption/decryption failed; installed keys were not changed.")


def fingerprint(args, path):
    result = subprocess.run(
        [args.ssh_keygen, "-l", "-E", "sha256", "-f", str(path)],
        capture_output=True, check=False,
    )
    if result.returncode or len(result.stdout.splitlines()) != 1:
        raise RuntimeError(f"Invalid SSH key: {path.name}")
    return result.stdout.split()[1]


def validate_keys(args, keys, public, temporary):
    if set(keys) != set(KEYS):
        raise RuntimeError("The bundle must contain exactly the three configured SSH keys.")
    for name in KEYS:
        # Fingerprint the private file without a neighboring .pub file, so
        # ssh-keygen cannot accidentally validate the sidecar instead.
        private = temporary / name
        private.write_bytes(keys[name])
        private.chmod(0o600)
        pub = temporary / f"expected-{name}.pub"
        pub.write_bytes(public[name])
        if fingerprint(args, private) != fingerprint(args, pub):
            raise RuntimeError(f"Private key does not match the configured public key: {name}")


def installed_matches(state, bundle, public, ssh):
    if state.get("bundle") != digest(bundle):
        return False
    files = state.get("files", {})
    if not isinstance(files, dict):
        return False
    for name in KEYS:
        for filename in (name, f"{name}.pub"):
            path = ssh / filename
            if path.is_symlink() or not path.is_file():
                return False
            if digest(path.read_bytes()) != files.get(filename):
                return False
        if (ssh / f"{name}.pub").read_bytes() != public[name]:
            return False
    return True


def link_config(ssh, target):
    # The shared checkout can inherit group-write permissions through its ACL.
    # OpenSSH checks the symlink target and rejects a group-writable config.
    if target.stat().st_uid != os.getuid():
        raise RuntimeError(f"SSH config belongs to another user: {target}")
    target.chmod(0o644)
    path = ssh / "config"
    if path.is_symlink() and os.readlink(path) == str(target):
        return
    backup(path)
    path.symlink_to(target)


def provision(args):
    repo, home = Path(args.repo), Path(args.home)
    ssh = home / ".ssh"
    state_dir = home / ".local/state/ssh-keys"
    private_directory(ssh)
    private_directory(state_dir)
    lock_path = state_dir / "lock"
    lock_fd = os.open(lock_path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(lock_fd, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        provision_locked(args, repo, ssh, state_dir)


def provision_locked(args, repo, ssh, state_dir):
    target = repo / "config/ssh/config"
    if not target.is_file():
        raise RuntimeError(f"Missing SSH config: {target}")
    public = {name: (repo / f"config/ssh/{name}.pub").read_bytes() for name in KEYS}
    bundle_path = repo / "secrets/ssh-keys.age"
    state_path = state_dir / "installed.json"
    try:
        state = json.loads(state_path.read_text())
    except (FileNotFoundError, ValueError):
        state = {}
    if not isinstance(state, dict):
        state = {}
    bundle = bundle_path.read_bytes() if bundle_path.is_file() else None
    if bundle is not None and installed_matches(state, bundle, public, ssh):
        for name in KEYS:
            (ssh / name).chmod(0o600)
            (ssh / f"{name}.pub").chmod(0o644)
        link_config(ssh, target)
        print("Managed SSH keys are current; no passphrase needed.")
        return

    # Never place a plaintext archive in the checkout, Nix store or disk /tmp.
    with tempfile.TemporaryDirectory(prefix="nixos-ssh-", dir="/dev/shm") as directory:
        temporary = Path(directory)
        payload = temporary / "keys.json"
        if bundle is None:
            source = Path(args.source)
            if not all((source / name).is_file() for name in KEYS):
                raise RuntimeError("No encrypted SSH bundle or Ansible source keys found. Restore secrets/ssh-keys.age from Git.")
            keys = {name: (source / name).read_bytes() for name in KEYS}
            validate_keys(args, keys, public, temporary)
            payload.write_text(json.dumps({name: base64.b64encode(value).decode("ascii") for name, value in keys.items()}))
            encrypted = temporary / "keys.age"
            print("Creating the encrypted SSH bundle. Choose its archive passphrase at the age prompt.", flush=True)
            age_interactive(args, ["--passphrase", "--output", encrypted, payload])
            bundle = encrypted.read_bytes()
            bundle_path.parent.mkdir(exist_ok=True)
            atomic_write(bundle_path, bundle)
            print("Encrypted bundle created. Commit secrets/ssh-keys.age after the rebuild.", flush=True)
        else:
            # Decrypt the exact bytes whose digest will be recorded, even if
            # the checkout changes while the user is entering the passphrase.
            encrypted = temporary / "keys.age"
            encrypted.write_bytes(bundle)
            print("Unlocking managed SSH keys.", flush=True)
            age_interactive(args, ["--decrypt", "--output", payload, encrypted])
            encoded = json.loads(payload.read_text())
            if not isinstance(encoded, dict) or any(not isinstance(value, str) for value in encoded.values()):
                raise RuntimeError("Invalid SSH bundle structure.")
            keys = {name: base64.b64decode(value, validate=True) for name, value in encoded.items()}
            validate_keys(args, keys, public, temporary)

        files = {}
        for name in KEYS:
            files[name] = keys[name]
            files[f"{name}.pub"] = public[name]
        for name, value in files.items():
            path = ssh / name
            if path.is_symlink() or (path.exists() and path.read_bytes() != value):
                backup(path)
            atomic_write(path, value, 0o644 if name.endswith(".pub") else 0o600)
        link_config(ssh, target)
        atomic_write(state_path, json.dumps({
            "bundle": digest(bundle),
            "files": {name: digest(value) for name, value in files.items()},
        }).encode())
        print("Installed all three SSH identities and linked the editable SSH config.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("repo", "home", "source", "age", "script", "ssh-keygen"):
        parser.add_argument(f"--{name}", required=True)
    args = parser.parse_args()
    os.umask(0o077)
    try:
        provision(args)
    except (OSError, ValueError, RuntimeError) as error:
        # Do not print JSON/parser values or decrypted key material.
        if isinstance(error, ValueError):
            print("Invalid SSH bundle encoding.", file=sys.stderr)
        else:
            print(f"SSH setup failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
