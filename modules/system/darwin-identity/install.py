"""Install Nix-managed Darwin code at stable paths with one persistent identity."""

import ctypes
import fcntl
import hashlib
import json
import os
import plistlib
import re
import secrets
import shlex
import shutil
import stat
import subprocess
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path


class InstallationError(Exception):
    pass


def run(arguments, *, check=True, redactions=(), input_text=None):
    # Never let subprocess include keychain credentials in an exception message.
    result = subprocess.run(
        [str(argument) for argument in arguments],
        capture_output=True,
        text=True,
        check=False,
        input=input_text,
    )
    if check and result.returncode:
        message = (result.stderr or result.stdout).strip()
        for secret in redactions:
            message = message.replace(secret, "<redacted>")
        raise InstallationError(f"{Path(arguments[0]).name} failed: {message}")
    return result


def owned(path, *, directory=False, protected=False):
    metadata = path.lstat()
    if path.is_symlink() or metadata.st_uid != os.geteuid():
        raise InstallationError(f"Not an owned physical path: {path}")
    if directory and not stat.S_ISDIR(metadata.st_mode):
        raise InstallationError(f"Not a directory: {path}")
    if not directory and not stat.S_ISREG(metadata.st_mode):
        raise InstallationError(f"Not a regular file: {path}")
    if protected and metadata.st_mode & 0o022:
        raise InstallationError(
            f"Managed directory is writable by another user: {path}"
        )
    return metadata


def directory(path, mode=0o755):
    if not path.exists():
        directory(path.parent)
        try:
            path.mkdir(mode=mode)
        except FileExistsError:
            pass
        else:
            os.chmod(path, mode)
    owned(path, directory=True)


@contextmanager
def locked(path):
    descriptor = os.open(path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, "w") as handle:
        owned(path)
        os.fchmod(handle.fileno(), 0o600)
        fcntl.flock(handle, fcntl.LOCK_EX)
        yield


def writable(path, modes):
    metadata = owned(path, directory=path.is_dir())
    modes[path] = stat.S_IMODE(metadata.st_mode)
    os.chmod(path, modes[path] | stat.S_IWUSR)


def digest(path):
    value = hashlib.sha256()
    if path.is_symlink():
        value.update(b"symlink\0" + os.fsencode(os.readlink(path)))
    elif path.is_dir():
        for entry in sorted(path.rglob("*")):
            value.update(os.fsencode(entry.relative_to(path)) + b"\0")
            value.update(
                digest(entry).encode()
                if entry.is_symlink() or not entry.is_dir()
                else b"directory"
            )
    else:
        with path.open("rb") as handle:
            for block in iter(lambda: handle.read(1024 * 1024), b""):
                value.update(block)
    return value.hexdigest()


def write_json(path, value):
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as handle:
        temporary = Path(handle.name)
        handle.write((json.dumps(value, sort_keys=True, indent=2) + "\n").encode())
    try:
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def read_json(path):
    if not path.exists():
        return {}
    owned(path)
    return json.loads(path.read_text())


def signature(path):
    result = run(
        ["/usr/bin/codesign", "--display", "--requirements", "-", "--verbose=2", path],
        check=False,
    )
    if result.returncode:
        return None
    output = result.stderr + result.stdout
    requirement = re.search(r"^designated => (.+)$", output, re.MULTILINE)
    identifier = re.search(r"^Identifier=(.+)$", output, re.MULTILINE)
    return {
        "requirement": requirement.group(1) if requirement else None,
        "identifier": identifier.group(1) if identifier else None,
        "adhoc": "Signature=adhoc" in output,
    }


def verify(path, requirement=None, *, deep=False, check=True):
    arguments = ["/usr/bin/codesign", "--verify", "--strict"]
    if deep:
        arguments.append("--deep")
    if requirement:
        arguments.append("-R=" + requirement)
    arguments.append(path)
    return run(arguments, check=check).returncode == 0


def macho(path, *, executable=False):
    with path.open("rb") as handle:
        header = handle.read(16)
        magic = header[:4]
        if magic in (
            b"\xca\xfe\xba\xbe",
            b"\xbe\xba\xfe\xca",
            b"\xca\xfe\xba\xbf",
            b"\xbf\xba\xfe\xca",
        ):
            if not executable:
                return True
            byteorder = "big" if magic[:1] == b"\xca" else "little"
            wide = magic in (b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca")
            handle.seek(16)
            offset = int.from_bytes(handle.read(8 if wide else 4), byteorder)
            handle.seek(offset)
            header = handle.read(16)
            magic = header[:4]
        if magic not in (
            b"\xfe\xed\xfa\xce",
            b"\xce\xfa\xed\xfe",
            b"\xfe\xed\xfa\xcf",
            b"\xcf\xfa\xed\xfe",
        ):
            return False
        byteorder = "big" if magic[:1] == b"\xfe" else "little"
        return not executable or int.from_bytes(header[12:16], byteorder) == 2


def remove(path):
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.exists():
        for parent, _, _ in os.walk(path, followlinks=False):
            directory_path = Path(parent)
            mode = owned(directory_path, directory=True).st_mode
            os.chmod(directory_path, stat.S_IMODE(mode) | stat.S_IWUSR)
        shutil.rmtree(path)


def replace(temporary, destination):
    if temporary.is_dir() and not temporary.is_symlink() and destination.exists():
        # Darwin can exchange populated directories without a missing-path gap.
        exchange = ctypes.CDLL(None, use_errno=True).renamex_np
        exchange.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
        exchange.restype = ctypes.c_int
        if exchange(os.fsencode(temporary), os.fsencode(destination), 2):
            error = ctypes.get_errno()
            raise OSError(error, os.strerror(error), str(destination))
    else:
        os.replace(temporary, destination)


class Installer:
    def __init__(self, manifest):
        self.manifest = manifest
        self.state = Path(manifest["state"])
        self.bin = Path(manifest["bin"])
        self.keychain = self.state / "identity.keychain-db"
        self.password_file = self.state / "password"
        self.certificate = self.state / "certificate.pem"
        self.identity_file = self.state / "identity.json"
        directory(self.state, 0o700)
        owned(self.state.parent, directory=True, protected=True)
        os.chmod(self.state, 0o700)
        directory(self.bin)
        owned(self.bin, directory=True, protected=True)
        owned(self.bin.parent, directory=True, protected=True)

    def resource_destination(self, name):
        requested = Path(os.path.normpath(self.bin / name))
        physical = Path(os.path.realpath(requested.parent)) / requested.name
        try:
            relative = physical.relative_to(self.bin.parent.resolve())
        except ValueError as error:
            raise InstallationError(
                f"Resource is outside the managed directory: {requested}"
            ) from error
        destination = self.bin.parent / relative
        if destination in (self.bin, self.bin.parent):
            raise InstallationError(
                f"Resource would replace its managed parent: {destination}"
            )
        return destination

    def resource_paths(self, field="resourceSymlinks"):
        return {
            self.resource_destination(name): Path(source).resolve(strict=True)
            for name, source in self.manifest.get(field, {}).items()
        }

    def native(self, path, identifier, old_requirement=None, *, deep=False):
        original = signature(path)
        if (
            original
            and not original["adhoc"]
            and verify(path, original["requirement"], deep=deep, check=False)
        ):
            requirement = original["requirement"]
        else:
            self.sign(path, identifier)
            requirement = self.requirement(identifier)
        if old_requirement:
            verify(path, old_requirement, deep=deep)
        return requirement

    def resource_aliases(self, trees):
        aliases = {}
        for name, target in self.manifest.get("resourceExecutableAliases", {}).items():
            destination = self.resource_destination(name)
            target = Path(os.path.normpath(target))
            own = Path(os.path.realpath(target.parent)) / target.name
            approved = target in {
                Path("/var/lib/nix-darwin/bin") / shell
                for shell in ("bash", "zsh", "sh")
            }
            if not target.is_absolute() or not (
                own.is_relative_to(self.bin.resolve()) or approved
            ):
                raise InstallationError(
                    f"Resource executable alias has no approved fixed target: {target}"
                )
            if not any(destination.is_relative_to(tree) for tree in trees):
                raise InstallationError(
                    f"Resource executable alias is outside its resource tree: {destination}"
                )
            aliases[destination] = target
        return aliases

    def resources(self):
        record_file = self.state / "resources.json"
        records = read_json(record_file)
        desired = {}
        for kind, field in (
            ("link", "resourceSymlinks"),
            ("tree", "resourceTrees"),
            ("file", "resourceFiles"),
        ):
            for destination, source in self.resource_paths(field).items():
                if destination in desired or any(
                    destination.is_relative_to(other)
                    or other.is_relative_to(destination)
                    for other in desired
                ):
                    raise InstallationError(
                        f"Overlapping resource destinations: {destination}"
                    )
                if source.is_dir() != (kind != "file"):
                    raise InstallationError(f"Invalid resource {kind} input: {source}")
                desired[destination] = (kind, source)
        trees = {
            destination for destination, (kind, _) in desired.items() if kind == "tree"
        }
        aliases = self.resource_aliases(trees)
        for destination, (kind, source) in desired.items():
            parent = self.bin.parent
            for component in destination.parent.relative_to(parent).parts:
                parent /= component
                directory(parent)
                owned(parent, directory=True, protected=True)
            inputs = str(source) if kind == "link" else digest(source)
            tree_aliases = {
                path: target
                for path, target in aliases.items()
                if path.is_relative_to(destination)
            }
            inputs += json.dumps(
                {
                    str(path.relative_to(destination)): str(target)
                    for path, target in tree_aliases.items()
                },
                sort_keys=True,
            )
            previous = records.get(str(destination))
            if destination.exists() or destination.is_symlink():
                metadata = destination.lstat()
                if (
                    metadata.st_uid != os.geteuid()
                    or not previous
                    or previous["installed"] != digest(destination)
                ):
                    raise InstallationError(
                        f"Refusing to replace a changed or unmanaged resource: {destination}"
                    )
                if (
                    previous.get("source") == inputs
                    and previous.get("identity") == self.sha1
                ):
                    continue
            temporary = destination.parent / (
                "." + destination.name + "." + secrets.token_hex(8)
            )
            requirements = {}
            try:
                if kind == "link":
                    temporary.symlink_to(source)
                elif kind == "file":
                    shutil.copy2(source, temporary)
                else:
                    ignored = {path.relative_to(destination) for path in tree_aliases}

                    def ignore(directory_name, names, source=source, ignored=ignored):
                        relative = Path(directory_name).relative_to(source)
                        return [name for name in names if relative / name in ignored]

                    shutil.copytree(source, temporary, ignore=ignore)
                    for path, target in tree_aliases.items():
                        alias = temporary / path.relative_to(destination)
                        modes = {}
                        try:
                            writable(alias.parent, modes)
                            alias.symlink_to(target)
                        finally:
                            for changed, mode in modes.items():
                                os.chmod(changed, mode)
                candidates = (
                    [temporary]
                    if kind == "file"
                    else temporary.rglob("*")
                    if kind == "tree"
                    else []
                )
                for executable in candidates:
                    if (
                        executable.is_symlink()
                        or not executable.is_file()
                        or not macho(executable, executable=True)
                    ):
                        continue
                    relative = (
                        str(executable.relative_to(temporary)) if kind == "tree" else ""
                    )
                    identity_name = (
                        str(destination.relative_to(self.bin.parent)) + "/" + relative
                    )
                    identifier = "org.nixos.resource." + re.sub(
                        r"[^A-Za-z0-9._-]",
                        lambda match: f"_{ord(match[0]):02x}",
                        identity_name,
                    )
                    modes = {}
                    try:
                        writable(executable.parent, modes)
                        writable(executable, modes)
                        old_requirement = (
                            (previous or {}).get("requirements", {}).get(relative)
                        )
                        requirements[relative] = self.native(
                            executable, identifier, old_requirement
                        )
                    finally:
                        for changed, mode in reversed(list(modes.items())):
                            os.chmod(changed, mode)
                replace(temporary, destination)
                records[str(destination)] = {
                    "kind": kind,
                    "source": inputs,
                    "installed": digest(destination),
                    "inode": destination.lstat().st_ino,
                    "identity": self.sha1,
                    "requirements": requirements,
                }
                write_json(record_file, records)
            finally:
                remove(temporary)
        for path in list(records.keys() - {str(path) for path in desired}):
            destination = self.resource_destination(path)
            owned(destination.parent, directory=True)
            if destination.exists() or destination.is_symlink():
                metadata = destination.lstat()
                if (
                    metadata.st_uid != os.geteuid()
                    or metadata.st_ino != records[path]["inode"]
                    or digest(destination) != records[path]["installed"]
                ):
                    raise InstallationError(
                        f"Managed resource changed outside activation: {destination}"
                    )
                remove(destination)
            del records[path]
        write_json(record_file, records)

    def security(self, arguments):
        # Feed security's command parser over stdin; passwords never enter argv.
        return run(
            ["/usr/bin/security", "-i"],
            input_text=shlex.join(str(argument) for argument in arguments) + "\n",
            redactions=(self.password,),
        )

    def identity(self):
        if not self.identity_file.exists():
            if (
                any(self.state.glob("identity*"))
                or self.password_file.exists()
                or self.certificate.exists()
            ):
                raise InstallationError(
                    "Incomplete signing identity; restore its backup before switching"
                )
            self.password = secrets.token_hex(32)
            descriptor = os.open(
                self.password_file, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600
            )
            with os.fdopen(descriptor, "w") as handle:
                handle.write(self.password)
            with locked(self.state.parent / ".keychain-search.lock"):
                previous = shlex.split(
                    self.security(["list-keychains", "-d", "user"]).stdout
                )
                private = self.state / "private.pem"
                archive = self.state / "identity.p12"
                try:
                    run(
                        [
                            self.manifest["openssl"],
                            "req",
                            "-x509",
                            "-newkey",
                            "rsa:2048",
                            "-nodes",
                            "-days",
                            "36500",
                            "-subj",
                            "/CN=Nix Darwin local code signing/",
                            "-addext",
                            "basicConstraints=critical,CA:FALSE",
                            "-addext",
                            "keyUsage=critical,digitalSignature",
                            "-addext",
                            "extendedKeyUsage=codeSigning",
                            "-keyout",
                            private,
                            "-out",
                            self.certificate,
                        ]
                    )
                    os.chmod(private, 0o600)
                    os.chmod(self.certificate, 0o600)
                    run(
                        [
                            self.manifest["openssl"],
                            "pkcs12",
                            "-export",
                            "-inkey",
                            private,
                            "-in",
                            self.certificate,
                            "-out",
                            archive,
                            "-certpbe",
                            "PBE-SHA1-3DES",
                            "-keypbe",
                            "PBE-SHA1-3DES",
                            "-macalg",
                            "SHA1",
                            "-passout",
                            f"file:{self.password_file}",
                        ]
                    )
                    os.chmod(archive, 0o600)
                    self.security(
                        ["create-keychain", "-p", self.password, self.keychain]
                    )
                    self.security(
                        ["unlock-keychain", "-p", self.password, self.keychain]
                    )
                    self.security(
                        [
                            "import",
                            archive,
                            "-k",
                            self.keychain,
                            "-P",
                            self.password,
                            "-T",
                            "/usr/bin/codesign",
                            "-x",
                        ]
                    )
                    self.security(
                        [
                            "set-key-partition-list",
                            "-S",
                            "apple-tool:,apple:",
                            "-s",
                            "-k",
                            self.password,
                            self.keychain,
                        ]
                    )
                    fingerprint = (
                        run(
                            [
                                self.manifest["openssl"],
                                "x509",
                                "-in",
                                self.certificate,
                                "-noout",
                                "-fingerprint",
                                "-sha1",
                            ]
                        )
                        .stdout.strip()
                        .split("=", 1)[1]
                        .replace(":", "")
                        .upper()
                    )
                    write_json(self.identity_file, {"sha1": fingerprint})
                finally:
                    self.security(["list-keychains", "-d", "user", "-s", *previous])
                    private.unlink(missing_ok=True)
                    archive.unlink(missing_ok=True)
        for path in (
            self.password_file,
            self.certificate,
            self.keychain,
            self.identity_file,
        ):
            owned(path)
            os.chmod(path, 0o600)
        self.password = self.password_file.read_text().strip()
        self.sha1 = read_json(self.identity_file)["sha1"]
        if not re.fullmatch(r"[A-F0-9]{40}", self.sha1) or not re.fullmatch(
            r"[a-f0-9]{64}", self.password
        ):
            raise InstallationError(
                "Invalid persistent signing identity; restore its backup"
            )
        fingerprint = (
            run(
                [
                    self.manifest["openssl"],
                    "x509",
                    "-in",
                    self.certificate,
                    "-noout",
                    "-fingerprint",
                    "-sha1",
                ]
            )
            .stdout.strip()
            .split("=", 1)[1]
            .replace(":", "")
            .upper()
        )
        if fingerprint != self.sha1:
            raise InstallationError(
                "Persistent signing certificate does not match its identity"
            )
        self.security(["unlock-keychain", "-p", self.password, self.keychain])
        identities = self.security(
            ["find-identity", "-p", "codesigning", self.keychain]
        ).stdout
        if self.sha1 not in identities.upper():
            raise InstallationError(
                "Persistent signing key is missing; restore its backup"
            )

    def requirement(self, identifier):
        return f'identifier "{identifier}" and certificate leaf = H"{self.sha1}"'

    def sign(self, path, identifier):
        run(
            [
                "/usr/bin/codesign",
                "--force",
                "--sign",
                self.sha1,
                "--keychain",
                self.keychain,
                "--timestamp=none",
                "--identifier",
                identifier,
                "--preserve-metadata=entitlements,flags,runtime,launch-constraints",
                path,
            ]
        )
        verify(path, self.requirement(identifier))

    def executable(self, source, destination, identifier, records):
        if destination.is_relative_to(self.bin):
            parent = self.bin
            for component in destination.parent.relative_to(self.bin).parts:
                parent /= component
                directory(parent)
                owned(parent, directory=True, protected=True)
        directory(destination.parent)
        owned(destination.parent, directory=True, protected=True)
        previous = records.get(str(destination))
        alias = None
        if source.is_symlink():
            target = Path(os.path.normpath(os.readlink(source)))
            payload_bin = Path(self.manifest["payload"]) / "bin"
            absolute = Path(os.path.normpath(source.parent / target))
            if not target.is_absolute() and absolute.is_relative_to(payload_bin):
                alias = os.path.relpath(
                    self.bin / absolute.relative_to(payload_bin), destination.parent
                )
            elif target.is_absolute() and (
                target.is_relative_to(self.bin)
                or target.is_relative_to(Path(self.manifest["installedApplications"]))
            ):
                alias = str(target)
        source_hash = (
            hashlib.sha256(alias.encode()).hexdigest()
            if alias
            else digest(source.resolve())
        )
        if destination.exists() or destination.is_symlink():
            current = destination.lstat()
            if current.st_uid != os.geteuid():
                raise InstallationError(
                    f"Destination belongs to another user: {destination}"
                )
            if (
                previous
                and previous["source"] == source_hash
                and previous["installed"] == digest(destination)
            ):
                if not alias and macho(destination):
                    verify(
                        destination,
                        previous.get("requirement") or self.requirement(identifier),
                    )
                return
            if previous and previous["installed"] != digest(destination):
                raise InstallationError(
                    f"Managed executable changed outside activation: {destination}"
                )
            if not previous:
                existing = (
                    signature(destination) if not destination.is_symlink() else None
                )
                original = (
                    signature(source.resolve())
                    if not alias and macho(source.resolve())
                    else None
                )
                expected = (
                    original["identifier"]
                    if original
                    and not original["adhoc"]
                    and verify(source.resolve(), original["requirement"], check=False)
                    else identifier
                )
                if not existing or existing["identifier"] != expected:
                    raise InstallationError(
                        f"Refusing to replace an unmanaged path: {destination}"
                    )
        temporary = destination.parent / (
            "." + destination.name + "." + secrets.token_hex(8)
        )
        old = (
            signature(destination)
            if destination.exists() and not destination.is_symlink()
            else None
        )
        requirement = None
        try:
            if alias:
                temporary.symlink_to(alias)
            else:
                shutil.copyfile(source.resolve(), temporary)
                os.chmod(temporary, source.stat().st_mode & 0o777)
                if macho(temporary):
                    requirement = self.native(
                        temporary, identifier, old["requirement"] if old else None
                    )
            os.replace(temporary, destination)
            records[str(destination)] = {
                "source": source_hash,
                "installed": digest(destination),
                "inode": destination.lstat().st_ino,
                "requirement": requirement,
            }
        finally:
            temporary.unlink(missing_ok=True)

    def executables(self, bootstrap=False):
        record_file = self.state / "executables.json"
        records = read_json(record_file)
        desired = {}
        payload_bin = Path(self.manifest["payload"]) / "bin"
        resource_paths = set()
        for field in ("resourceSymlinks", "resourceTrees", "resourceFiles"):
            resource_paths.update(self.resource_paths(field))
        if bootstrap:
            sources = self.manifest.get(
                "bootstrapExecutables", {"bash": self.manifest["bootstrapBash"]}
            )
            paths = [
                (
                    payload_bin / name
                    if (payload_bin / name).exists()
                    else Path(source),
                    Path(name),
                )
                for name, source in sources.items()
            ]
        else:
            paths = [
                (source, source.relative_to(payload_bin))
                for source in sorted(payload_bin.rglob("*"))
                if source.is_symlink() or source.is_file()
                if not any(
                    (self.bin / source.relative_to(payload_bin)).is_relative_to(
                        resource
                    )
                    for resource in resource_paths
                )
            ]
        for source, relative in paths:
            identifier = "org.nixos.command." + re.sub(
                r"[^A-Za-z0-9._-]", lambda match: f"_{ord(match[0]):02x}", str(relative)
            )
            desired[str(self.bin / relative)] = (source, identifier)
        if not bootstrap:
            for item in self.manifest.get("extraExecutables", {}).values():
                desired[item["destination"]] = (
                    Path(item["source"]),
                    item["identifier"],
                )
        for path, (source, identifier) in desired.items():
            self.executable(source, Path(path), identifier, records)
            write_json(record_file, records)
        if not bootstrap:
            for path in list(records.keys() - desired.keys()):
                destination = Path(path)
                owned(destination.parent, directory=True)
                if destination.exists() or destination.is_symlink():
                    metadata = destination.lstat()
                    if (
                        metadata.st_uid != os.geteuid()
                        or metadata.st_ino != records[path]["inode"]
                        or digest(destination) != records[path]["installed"]
                    ):
                        raise InstallationError(
                            f"Managed executable changed outside activation: {destination}"
                        )
                    destination.unlink()
                del records[path]
        write_json(record_file, records)
        if not bootstrap:
            self.resources()

    def normalize_frameworks(self, source, destination):
        # Some Nix app packages dereference a framework's version aliases. macOS
        # rejects that duplicated layout; restore aliases only after proving the
        # immutable package contains identical copies.
        for framework in source.rglob("*.framework"):
            current = framework / "Versions/Current"
            if framework.is_symlink() or current.is_symlink() or not current.is_dir():
                continue
            versions = [
                version
                for version in current.parent.iterdir()
                if version.name != "Current"
                and version.is_dir()
                and digest(version) == digest(current)
            ]
            if len(versions) != 1:
                continue
            version = versions[0]
            changes = [(current, version.name)]
            for entry in framework.iterdir():
                if entry.name == "Versions" or entry.is_symlink():
                    continue
                equivalent = version / entry.name
                if equivalent.exists() and digest(entry) == digest(equivalent):
                    changes.append((entry, "Versions/Current/" + entry.name))
            for original, target in changes:
                copied = destination / original.relative_to(source)
                if copied.is_symlink():
                    continue
                if digest(copied) != digest(original):
                    raise InstallationError(
                        f"Local framework differs from its package: {copied}"
                    )
                modes = {}
                try:
                    writable(copied.parent, modes)
                    remove(copied)
                    copied.symlink_to(target)
                finally:
                    for changed, mode in modes.items():
                        os.chmod(changed, mode)

    def seal_application(self, source, destination, overrides, previous):
        self.normalize_frameworks(source, destination)
        root = destination.resolve()
        bundles = [
            destination,
            *(
                path
                for path in destination.rglob("*")
                if path.is_dir()
                and not path.is_symlink()
                and path.suffix in {".app", ".framework", ".xpc", ".bundle"}
            ),
        ]
        info = {}
        mains = set()
        for bundle in bundles:
            for candidate in (
                bundle / "Contents/Info.plist",
                bundle / "Resources/Info.plist",
                bundle / "Info.plist",
            ):
                if candidate.is_file():
                    with candidate.open("rb") as handle:
                        info[bundle] = plistlib.load(handle)
                    break
            name = info.get(bundle, {}).get("CFBundleExecutable")
            if name:
                for candidate in (bundle / "Contents/MacOS" / name, bundle / name):
                    if candidate.is_file():
                        physical = candidate.resolve()
                        if not physical.is_relative_to(root):
                            raise InstallationError(
                                f"App code points outside its managed bundle: {candidate}"
                            )
                        mains.add(physical)
                        break
        modes = {}
        requirements = {}
        old_requirements = (previous or {}).get("requirements", {})
        try:
            for path in [destination, *destination.rglob("*")]:
                if path.is_symlink():
                    continue
                if path.is_dir() or (
                    path.is_file() and (macho(path) or "_CodeSignature" in path.parts)
                ):
                    writable(path, modes)
            # Empty Git directory markers are packaging scaffolding. macOS
            # treats every MacOS/ entry as code and rejects these unsigned files.
            for marker in destination.rglob(".gitkeep"):
                if (
                    "MacOS" in marker.relative_to(destination).parts
                    and not marker.is_symlink()
                    and marker.stat().st_size == 0
                ):
                    relative = marker.relative_to(destination)
                    original = source / relative
                    if original.is_file() and original.stat().st_size == 0:
                        owned(marker)
                        marker.unlink()
            if overrides.exists():
                for replacement in sorted(overrides.rglob("*")):
                    if replacement.is_dir():
                        continue
                    target = destination / replacement.relative_to(overrides)
                    if replacement.is_symlink() or not target.is_file():
                        raise InstallationError(
                            f"Invalid app executable override: {replacement}"
                        )
                    target = target.resolve()
                    if not target.is_relative_to(root):
                        raise InstallationError(
                            f"App override points outside its bundle: {target}"
                        )
                    for parent in target.parents:
                        if parent == root.parent:
                            break
                        owned(parent, directory=True)
                    if target not in modes:
                        writable(target, modes)
                    temporary = target.parent / (
                        "." + target.name + "." + secrets.token_hex(8)
                    )
                    try:
                        shutil.copyfile(replacement, temporary)
                        os.chmod(temporary, stat.S_IMODE(target.stat().st_mode))
                        os.replace(temporary, target)
                    finally:
                        temporary.unlink(missing_ok=True)
            for path in sorted(destination.rglob("*")):
                if (
                    path.is_symlink()
                    or not path.is_file()
                    or not macho(path)
                    or path.resolve() in mains
                ):
                    continue
                relative = str(path.relative_to(destination))
                existing = signature(path)
                identifier = (existing or {}).get(
                    "identifier"
                ) or "org.nixos.application." + re.sub(
                    r"[^A-Za-z0-9._-]", "_", relative
                )
                requirements[relative] = self.native(
                    path, identifier, old_requirements.get(relative)
                )
            for bundle in sorted(
                bundles, key=lambda path: len(path.parts), reverse=True
            ):
                relative = str(bundle.relative_to(destination))
                existing = signature(bundle)
                identifier = info.get(bundle, {}).get("CFBundleIdentifier") or (
                    existing or {}
                ).get("identifier")
                if not identifier:
                    continue
                requirements[relative] = self.native(
                    bundle, identifier, old_requirements.get(relative), deep=True
                )
            verify(destination, deep=True)
        finally:
            for path, mode in reversed(list(modes.items())):
                if path.exists():
                    os.chmod(path, mode)
            for seal in destination.rglob("_CodeSignature"):
                if seal.is_symlink():
                    raise InstallationError(
                        f"App signature points outside its bundle: {seal}"
                    )
                for path in [seal, *seal.rglob("*")]:
                    if path not in modes and not path.is_symlink():
                        parent = path.parent
                        while parent not in modes and parent != destination.parent:
                            parent = parent.parent
                        readonly = not (modes.get(parent, 0o755) & stat.S_IWUSR)
                        mode = 0o755 if path.is_dir() else 0o644
                        os.chmod(path, mode & ~(0o222 if readonly else 0))
        return requirements

    def applications(self):
        installed = Path(self.manifest["installedApplications"])
        owned(installed, directory=True, protected=True)
        record_file = self.state / "applications.json"
        records = read_json(record_file)
        applications = Path(self.manifest["applications"])
        overrides = Path(self.manifest["payload"]) / "app-overrides"
        names = set()
        for source in sorted(applications.glob("*.app")):
            names.add(source.name)
            destination = installed / source.name
            if not stat.S_ISDIR(destination.lstat().st_mode):
                raise InstallationError(f"Not a physical app bundle: {destination}")
            original = signature(source)
            override = overrides / source.name
            if (
                original
                and not original["adhoc"]
                and verify(source, original["requirement"], deep=True, check=False)
            ):
                if override.exists():
                    raise InstallationError(
                        f"Refusing to modify a vendor-signed app: {source.name}"
                    )
                verify(destination, original["requirement"], deep=True)
                continue
            # nix-darwin preserves existing app owners. Vendor bundles are only
            # verified; local bundles must be owned before we change their code.
            owned(destination, directory=True)
            inputs = str(source.resolve()) + (
                digest(override) if override.exists() else ""
            )
            previous = records.get(source.name)
            if (
                previous
                and previous["source"] == inputs
                and previous["installed"] == digest(destination)
            ):
                for relative, requirement in previous.get("requirements", {}).items():
                    verify(
                        destination / relative,
                        requirement,
                        deep=(destination / relative).is_dir(),
                    )
                verify(destination, deep=True)
                continue
            requirements = self.seal_application(
                source, destination, override, previous
            )
            records[source.name] = {
                "source": inputs,
                "installed": digest(destination),
                "requirements": requirements,
            }
            write_json(record_file, records)
        write_json(
            record_file,
            {name: record for name, record in records.items() if name in names},
        )


def main():
    os.umask(0o077)
    if len(sys.argv) != 3 or sys.argv[2] not in (
        "bootstrap",
        "executables",
        "applications",
    ):
        raise InstallationError(
            "Usage: install.py MANIFEST bootstrap|executables|applications"
        )
    manifest = json.loads(Path(sys.argv[1]).read_text())
    installer = Installer(manifest)
    lock_path = installer.state / "activation.lock"
    with locked(lock_path):
        installer.identity()
        os.umask(0o022)
        if sys.argv[2] == "applications":
            installer.applications()
        else:
            installer.executables(bootstrap=sys.argv[2] == "bootstrap")


if __name__ == "__main__":
    try:
        main()
    except (InstallationError, OSError, ValueError, KeyError) as error:
        print(f"Darwin code identity: {error}", file=sys.stderr)
        sys.exit(1)
