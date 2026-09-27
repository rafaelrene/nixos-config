# Development

Run `devenv shell` from this checkout, or prefix an individual command with
`devenv shell --`. Nix with flakes and devenv must already be installed; both
workstation configurations provide them. The configured Nushell hook also
supports automatic entry after `devenv allow` in this checkout.

Neovim comes from the workstation configuration so its private Mason installer
runtimes remain available inside the development shell.

Both hosts patch devenv's Nushell reload helper to take the calling shell's
reload path as an argument. Concurrent shells in one checkout can then share
the generated helper without consuming each other's pending reloads. The patch
lives beside `modules/applications/devenv/default.nix`; recheck it when updating
devenv. After installing a changed devenv package, exit existing development
shells and re-enter them to regenerate their shell hooks.

A running devenv shell keeps watching the checkout where it started, even if
you change directories. Exit it before removing that checkout or worktree;
`git db` protects the worktree containing the calling shell's `DEVENV_ROOT`.
If the checkout was already deleted and reload fails, run `exit`, change to a
surviving checkout, and run `devenv shell` there.

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

The local Raycast destination extension is built and checked by its Nix package.
For an editing loop in `modules/applications/raycast/destinations/raycast`, run `npm ci`, then
`npm run build`, `npm run typecheck` and `npm run lint`. The build writes `dist/`
without installing into the running Raycast. Format its TypeScript and JSON
with Prettier. No `ray develop` process is needed for system installation.

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
