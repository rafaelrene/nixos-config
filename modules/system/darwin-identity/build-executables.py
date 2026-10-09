#!/usr/bin/env python3
"""Build fixed-path executable payloads without changing Nix package inputs."""

import json
import os
import plistlib
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

MACH_O = {
    b"\xfe\xed\xfa\xce",
    b"\xce\xfa\xed\xfe",
    b"\xfe\xed\xfa\xcf",
    b"\xcf\xfa\xed\xfe",
    b"\xca\xfe\xba\xbe",
    b"\xbe\xba\xfe\xca",
    b"\xca\xfe\xba\xbf",
    b"\xbf\xba\xfe\xca",
}
STORE_PATH = re.compile(r"/nix/store/[a-z0-9]{32}-[^\s\"'`$;:(){}\[\]<>|\\]+")


def executable(path):
    return path.is_file() and os.access(path, os.X_OK)


def wrapper_arguments(data):
    """Read makeBinaryWrapper's documented invocation, never evaluate its text."""
    start = data.find(b"makeCWrapper ")
    if start < 0:
        return None
    end = data.find(b"# (Use `nix-shell -p makeBinaryWrapper`", start)
    if end < 0:
        raise ValueError("Compiled Nix wrapper has no complete reconstruction metadata")
    command = data[start:end].decode("utf-8").replace("\\\n", "")
    arguments = shlex.split(command, comments=True)
    if len(arguments) < 2 or arguments[0] != "makeCWrapper":
        raise ValueError("Invalid compiled Nix wrapper metadata")
    return arguments[1:]


class Payload:
    def __init__(self, manifest, output):
        self.output = output
        self.fixed_bin = Path(manifest["bin"])
        self.installed_apps = Path(
            manifest.get("installedApplications", "/Applications/Nix Apps")
        )
        self.external = {
            str(Path(source).resolve()): destination
            for source, destination in manifest.get("externalExecutables", {}).items()
        }
        self.external_shells = {
            Path(source).name: destination
            for source, destination in manifest.get("externalExecutables", {}).items()
            if Path(source).name in {"bash", "zsh"}
        }
        self.aliases = manifest.get("aliases", {})
        self.sources = {
            name: Path(source)
            for name, source in manifest.get("executableSources", {}).items()
        }
        for path in sorted(Path(manifest["systemBin"]).iterdir()):
            # A system profile can already point at our not-yet-installed payload.
            if path.name not in self.sources and executable(path):
                self.sources[path.name] = path
        self.names = {}
        self.contexts = {}
        self.reserved = {}
        explicit = set(manifest.get("executableSources", {}))
        for name, source in self.sources.items():
            if name not in self.aliases:
                resolved = str(source.resolve())
                current = self.names.get(resolved)
                if current is None or (
                    current not in explicit
                    and name in {source.name, source.resolve().name}
                ):
                    self.names[resolved] = name
        self.entries = {}
        self.completed = set()
        self.mirrors = {}
        self.mirror_counts = {}
        self.wrapper_commands = []
        self.apps = []
        self.reserve_public_targets()
        self.discover_apps(Path(manifest["applications"]))

    @staticmethod
    def wrapped_target(source):
        data = source.read_bytes()
        arguments = wrapper_arguments(data)
        if arguments:
            return Path(arguments[0])
        if data.startswith(b"#!"):
            match = re.search(
                r"^exec(?:\s+-a\s+(?:\"[^\"]*\"|'[^']*'|\S+))?\s+"
                r"(?:\"([^\"]+)\"|'([^']+)'|([^\s;]+))",
                data.decode("utf-8"),
                re.MULTILINE,
            )
            if match:
                path = next(value for value in match.groups() if value is not None)
                if path.startswith("/nix/store/"):
                    return Path(path)
        return None

    def reserve_public_targets(self):
        # Allocate public programs before a dependency's PATH mirror sees them.
        # The final executable keeps its name even when wrapper layers change.
        for name, source in self.sources.items():
            if name in self.aliases or self.names[str(source.resolve())] != name:
                continue
            chain = []
            seen = {str(source.resolve())}
            target = self.wrapped_target(source)
            while target is not None and executable(target):
                resolved = str(target.resolve())
                if resolved in seen:
                    break
                seen.add(resolved)
                chain.append(target)
                target = self.wrapped_target(target)
            for index, target in enumerate(chain):
                resolved = str(target.resolve())
                if resolved in self.names or resolved in self.external:
                    continue
                role = (
                    "real" if index == len(chain) - 1 else "wrapper-" + str(index + 1)
                )
                candidate = "." + self.safe_name(name + "-" + role).lstrip(".")
                if candidate in self.sources or candidate in self.reserved:
                    raise ValueError("Executable name collision: " + candidate)
                self.names[resolved] = candidate
                self.contexts[candidate] = name
                self.reserved[candidate] = target

    def discover_apps(self, directory):
        for app in sorted(directory.glob("*.app")):
            info_path = app / "Contents/Info.plist"
            if not info_path.is_file():
                continue
            with info_path.open("rb") as stream:
                info = plistlib.load(stream)
            main = app / "Contents/MacOS" / info.get("CFBundleExecutable", "")
            if not executable(main):
                continue
            result = subprocess.run(
                ["/usr/bin/codesign", "-dv", "--verbose=2", str(main)],
                capture_output=True,
                text=True,
                check=False,
            )
            vendor_signed = any(
                line.startswith("Authority=") for line in result.stderr.splitlines()
            )
            installed = self.installed_apps / app.name
            self.apps.append((app.resolve(), installed, vendor_signed))
            if not vendor_signed and wrapper_arguments(main.read_bytes()):
                name = self.safe_name(info.get("CFBundleIdentifier", app.stem))
                self.copy(
                    ".app-" + name,
                    main,
                    Path("app-overrides") / app.name / "Contents/MacOS" / main.name,
                )

    @staticmethod
    def safe_name(name):
        return re.sub(r"[^A-Za-z0-9._+-]", "_", name)

    def app_path(self, source):
        resolved = source.resolve()
        for original, installed, _ in self.apps:
            try:
                return installed / resolved.relative_to(original)
            except ValueError:
                pass
            # Profile and application outputs may be assembled through different
            # package wrappers while referring to the same installed bundle.
            marker = "/Applications/" + installed.name + "/"
            if marker in str(resolved):
                return installed / str(resolved).split(marker, 1)[1]
        return None

    def link(self, relative, destination):
        path = self.output / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.symlink_to(destination)

    def include(self, source, caller, role, copy_app=False):
        resolved = str(source.resolve())
        if resolved in self.external:
            return self.external[resolved]
        if source.name in self.external_shells:
            return self.external_shells[source.name]
        if source.name == "sh" and "bash" in self.external_shells:
            return self.external_shells["bash"]
        shell = self.aliases.get(source.name, source.name)
        if shell in {"bash", "zsh"} and shell in self.sources:
            return str(self.fixed_bin / source.name)
        if not copy_app:
            installed_app_path = self.app_path(source)
            if installed_app_path:
                return str(installed_app_path)
        name = self.names.get(resolved)
        if copy_app and name in self.sources and self.app_path(source):
            name = None
        if name is None:
            caller = self.contexts.get(caller, caller)
            base_name = "." + self.safe_name(caller + "-" + role).lstrip(".")
            name = base_name
            suffix = 1
            while name in self.names.values():
                suffix += 1
                name = base_name + "-" + str(suffix)
            self.names[resolved] = name
            # A private wrapper owns its interpreter and native target names.
            self.contexts[name] = name
            self.copy(name, source)
        elif name in self.reserved:
            self.copy(name, self.reserved[name])
        return str(self.fixed_bin / name)

    def replace_reference(self, match, caller):
        original = match.group()
        source = Path(original)
        installed_app_path = self.app_path(source)
        if installed_app_path:
            return str(installed_app_path)
        if executable(source):
            role = "real" if source.name.startswith(".") else source.name
            return self.include(source, caller, role)
        if source.name == "bin" and source.is_dir():
            return self.mirror_bin(source, caller)
        return original

    def mirror_bin(self, source, caller):
        key = (caller, str(source.resolve()))
        if key in self.mirrors:
            return self.mirrors[key]
        ordinal = self.mirror_counts.get(caller, 0) + 1
        self.mirror_counts[caller] = ordinal
        context = self.safe_name(caller) + "/" + str(ordinal)
        relative = Path("bin/.paths") / context
        installed = self.fixed_bin / ".paths" / context
        self.mirrors[key] = str(installed)
        (self.output / relative).mkdir(parents=True, exist_ok=True)
        for child in sorted(source.iterdir()):
            if executable(child):
                target = self.include(child, caller, child.name)
                self.link(relative / child.name, target)
        return str(installed)

    def rewrite(self, text, caller):
        # App paths can contain spaces, so replace their known prefixes first.
        for original, installed, _ in self.apps:
            text = text.replace(str(original) + "/", str(installed) + "/")
            prefix = r"/nix/store/[a-z0-9]{32}-[^/\s]+/Applications/"
            text = re.sub(
                prefix + re.escape(installed.name) + "/", str(installed) + "/", text
            )
        return STORE_PATH.sub(lambda match: self.replace_reference(match, caller), text)

    def relocate_loader_paths(self, original, copied):
        result = subprocess.run(
            ["otool", "-l", str(original)],
            capture_output=True,
            text=True,
            check=True,
        )
        command = None
        changes = []
        for line in result.stdout.splitlines():
            stripped = line.strip()
            if stripped.startswith("cmd "):
                command = stripped[4:]
            if command == "LC_RPATH" and stripped.startswith("path "):
                value = stripped[5:].rsplit(" (offset ", 1)[0]
                option = "-rpath"
            elif command in {
                "LC_LOAD_DYLIB",
                "LC_LOAD_WEAK_DYLIB",
                "LC_REEXPORT_DYLIB",
            } and stripped.startswith("name "):
                value = stripped[5:].rsplit(" (offset ", 1)[0]
                option = "-change"
            else:
                continue
            for prefix in ("@loader_path", "@executable_path"):
                if value == prefix or value.startswith(prefix + "/"):
                    replacement = str(original.parent) + value[len(prefix) :]
                    change = [option, value, replacement]
                    if not any(
                        changes[index : index + 3] == change
                        for index in range(0, len(changes), 3)
                    ):
                        changes.extend(change)
                    break
        if changes:
            subprocess.run(["install_name_tool", *changes, str(copied)], check=True)

    def copy(self, name, source, relative=None):
        relative = relative or Path("bin") / name
        if str(relative) in self.completed:
            return
        self.completed.add(str(relative))
        source = source.resolve(strict=True)
        if not executable(source):
            raise ValueError("Not an executable: " + str(source))
        self.entries[str(relative)] = str(source)
        caller = self.contexts.get(name, name)
        target = self.output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        target.chmod(target.stat().st_mode | 0o200)
        data = source.read_bytes()
        arguments = wrapper_arguments(data)
        if arguments:
            # A local app wrapper can wrap another package's main executable for
            # the same bundle. Mapping that target to the installed app recurses.
            real = self.include(
                Path(arguments[0]), caller, "real", copy_app=caller.startswith(".app-")
            )
            flags = [self.rewrite(argument, caller) for argument in arguments[1:]]
            invocation = shlex.join(["makeCWrapper", real, *flags])
            output = shlex.quote(str(target))
            # makeCWrapper prints C and does not require its fixed target to exist.
            self.wrapper_commands.append(
                "(set +u; "
                + invocation
                + ' | "$CC" -Wall -Werror -Wpedantic -Wno-overlength-strings -Os -x c -o '
                + output
                + " -)"
            )
        elif data.startswith(b"#!"):
            text = data.decode("utf-8")
            shebang, separator, body = text.partition("\n")
            interpreter_name = shlex.split(shebang[2:])[0].rsplit("/", 1)[-1]
            match = re.match(r"(#!\s*)(/nix/store/\S+)(.*)", shebang)
            if match:
                interpreter = Path(match[2])
                interpreter_name = self.aliases.get(interpreter.name, interpreter.name)
                if interpreter_name in self.external_shells:
                    fixed = self.external_shells[interpreter_name]
                elif (
                    interpreter_name in {"bash", "zsh"}
                    and interpreter_name in self.sources
                ):
                    fixed = str(self.fixed_bin / interpreter.name)
                else:
                    fixed = self.include(interpreter, caller, "interpreter")
                shebang = match[1] + fixed + match[3]
            else:
                env = re.match(r"(#!\s*)/usr/bin/env(?:\s+-S)?\s+(\S+)(.*)", shebang)
                if env:
                    interpreter_name = env[2]
                    configured = self.aliases.get(interpreter_name, interpreter_name)
                    shared = next(
                        (
                            destination
                            for original, destination in self.external.items()
                            if Path(original).name == configured
                        ),
                        None,
                    )
                    if shared or configured in self.sources:
                        fixed = shared or str(self.fixed_bin / configured)
                        shebang = env[1] + fixed + env[3]
            if interpreter_name in {"node", "nodejs"}:
                # Run the original module as main, retaining relative imports,
                # require.main, ESM support and the command's argument vector.
                body = (
                    "process.argv[1] = "
                    + json.dumps(str(source))
                    + ';\nimport("node:module").then(({runMain}) => runMain(process.argv[1]));\n'
                )
            elif re.fullmatch(r"python(?:[23](?:\.\d+)?)?", interpreter_name):
                body = (
                    "import os, runpy, sys\n"
                    "sys.argv[0] = "
                    + json.dumps(str(source))
                    + "\nif not getattr(sys.flags, 'safe_path', sys.flags.isolated):\n"
                    "    sys.path[0] = os.path.dirname(sys.argv[0])\n"
                    "runpy.run_path(sys.argv[0], run_name='__main__')\n"
                )
            else:
                body = self.rewrite(body, caller)
            target.write_text(shebang + separator + body)
        elif data[:4] in MACH_O:
            self.relocate_loader_paths(source, target)
        else:
            raise ValueError("Unsupported executable format: " + str(source))

    def build(self):
        for name, source in self.sources.items():
            if name in self.aliases:
                continue
            relative = Path("bin") / name
            external = self.external.get(str(source.resolve()))
            app_path = self.app_path(source)
            canonical = self.names[str(source.resolve())]
            if external:
                self.link(relative, external)
            elif app_path:
                self.link(relative, app_path)
            elif canonical != name:
                self.link(relative, self.fixed_bin / canonical)
            else:
                self.copy(name, source)
        for name, destination in self.aliases.items():
            if destination not in self.sources:
                raise ValueError("Alias target is missing: " + destination)
            self.link(Path("bin") / name, self.fixed_bin / destination)
        (self.output / "rebuild-wrappers.sh").write_text(
            "\n".join(self.wrapper_commands) + "\n"
        )
        (self.output / "executables.json").write_text(
            json.dumps(self.entries, sort_keys=True, indent=2) + "\n"
        )


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: build-executables.py MANIFEST.json OUTPUT")
    with Path(sys.argv[1]).open() as stream:
        manifest = json.load(stream)
    output = Path(sys.argv[2])
    output.mkdir(parents=True, exist_ok=True)
    Payload(manifest, output).build()


if __name__ == "__main__":
    main()
