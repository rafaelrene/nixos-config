# Development

Run `devenv shell` from this checkout, or prefix an individual command with
`devenv shell --`. Nix with flakes and devenv must already be installed; both
workstation configurations provide them. The configured Nushell hook also
supports automatic entry after `devenv allow` in this checkout.

A running devenv shell keeps watching the checkout where it started, even if
you change directories. Exit it before removing that checkout or worktree;
`git db` protects the worktree containing the calling shell's `DEVENV_ROOT`.
If the checkout was already deleted and reload fails, run `exit`, change to a
surviving checkout, and run `devenv shell` there.

`devenv.nix` supplies the repository's tools on Linux and macOS. `devenv.lock`
pins them independently of the system's `flake.lock`; use `devenv update` to
update development tools. Nix builds supply their own declared build dependencies.

## Formatting, lint and tests

Checks run only when requested. From the development shell:

```sh
treefmt --fail-on-change
statix check . --ignore .devenv
deadnix --fail --exclude .devenv
python3 -m unittest discover -s tests -v
```

`treefmt` formats Nix, Bash, Lua and Python files. Use `treefmt path/to/file`
to format only edited files, or `treefmt` for the whole repository. Lua uses
the existing Neovim StyLua configuration. `--fail-on-change` still writes
formatting changes, then exits unsuccessfully if any were needed. To check
individual helpers:

```sh
shellcheck path/to/script
ruff check path/to/file.py
```

Prettier and Taplo are available for documentation, JSON/JSONC, YAML, HTML and
TOML edits. Nushell and Lua are available for focused configuration checks.
Existing files may have formatting or lint issues; keep unrelated cleanup
separate from feature changes.

The local Raycast destination extension is built and checked by its Nix package.
For an editing loop in `modules/darwin/destinations/raycast`, run `npm ci`, then
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
