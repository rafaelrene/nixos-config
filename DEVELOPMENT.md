# Development

T3 worktrees under the configured worktree roots are trusted automatically.
Regular checkouts and other locations require `direnv allow`. The configured Nushell
pre-prompt hook loads the development environment through `.envrc`, reloads
it after configuration changes, and unloads it when you leave. Both workstation
configurations provide Nix, devenv, direnv, and the `use devenv` integration.
For a single command without interactive activation, use `devenv shell -- <command>`.
See the [devenv guide](modules/applications/devenv/README.md) for setup and reload
constraints.

Neovim comes from the workstation configuration so its private Mason installer
runtimes remain available inside the development shell.

`git db` protects the worktree containing the calling shell's `DEVENV_ROOT`.
Change to a surviving checkout and let direnv unload before removing a worktree.
This does not detect environments running in other terminals.

`modules/development/default.nix` declares the repository's tools as a
flake-parts feature exporting a native devenv module. Root `devenv.nix` evaluates
that feature and hands the result to the CLI. `devenv.lock` pins development
inputs independently of the system's `flake.lock`; use `devenv update` to update
them. Nix builds supply their own declared build dependencies.

Every non-entry-point Nix file is a flake-parts feature module. The root flake
loads all `.nix` feature files under `modules/`, `hosts/`, `profiles/`, and
`themes/`, regardless of filename. Package factories and configuration helpers
use typed feature options in the same outer configuration. See the
[module guide](modules/README.md) for composition and the
[application guide](modules/applications/README.md) for package ownership.

## Formatting, lint and tests

Checks run only when requested. From the development shell:

```sh
treefmt --fail-on-change
statix check . --ignore .devenv
deadnix --fail --exclude .devenv
python3 -m unittest discover -s tests -v
```

`treefmt` formats Nix, Bash, Nushell, Lua and Python files. Use `treefmt path/to/file`
to format only edited files, or `treefmt` for the whole repository. Lua uses
the existing Neovim StyLua configuration. `--fail-on-change` still writes
formatting changes, then exits unsuccessfully if any were needed. To check
individual helpers:

```sh
shellcheck path/to/script
ruff check path/to/file.py
```

Prettier and Taplo are available for documentation, JSON/JSONC, YAML, HTML and
TOML edits. Check a Nushell script without running it with
`nu --no-config-file --commands 'nu-check path/to/script.nu'`; validate generated
configuration after Nix substitutes its template values. Lua is also available
for focused configuration checks.
Existing files may have formatting or lint issues; keep unrelated cleanup
separate from feature changes.

Keep runtime logic in `.nu` files beside its feature. Package commands with
`writeShellApplication`, explicit `runtimeInputs`, and a thin
`exec nu --no-config-file ... "$@"` launcher. Keep native Nix build phases and
small process wrappers in Bash when Nushell would add no value. Share portable
logic beside the feature, with service integration in the platform modules.

Use path interpolation (`"${./file}"`) for repository files needed at runtime.
`toString ./file` does not retain the file as a Nix store dependency; generated
launchers and symlinks can break after the flake source is garbage-collected.

For `nav` changes, validate the generated Nushell configuration and module with
`nu-check`, then exercise directory selection, cancellation, and SSH in an
interactive Nushell on each host. Verify Ctrl+Alt+P preserves partially typed
input. Use temporary fixtures for discovery rules, including hidden projects,
worktrees, excluded caches, symlinks, and paths containing whitespace.

For shell leader changes, use an interactive Nushell on both hosts to exercise
Space Space, Space n, and Space p in normal mode, cancellation, preserved input,
and ordinary spaces in insert mode. Use a temporary project with a harmless
package.json script to test `project-run`; confirm its exit status and that the
calling shell's directory stays unchanged. Remove temporary fixtures afterward.

## System validation

```sh
nix flake check --no-build
nix eval --raw .#darwinConfigurations.Proserpina.system.drvPath
nix build --no-link .#nixosConfigurations.othinus.config.system.build.toplevel
nix build --no-link .#darwinConfigurations.Proserpina.system
```

Othinus builds need an x86_64 Linux builder; Proserpina builds need an Apple
Silicon Mac. Devenv does not provide cross-platform system builders. Native Mac
checks also require Apple's Command Line Tools. Follow the
[Proserpina validation guide](hosts/proserpina/README.md#validation) for checks
specific to a changed feature.

Git-backed flakes include only tracked files. For validation before adding new
files to Git, use `path:.` as the flake reference instead of `.`.
System activation still requires explicit approval as described in
[AGENTS.md](AGENTS.md).
