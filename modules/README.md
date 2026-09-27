# Nix module structure

All Nix configuration follows the [dendritic pattern](https://github.com/mightyiam/dendritic)
with [flake-parts](https://flake.parts/). Every feature file is a module in the
same outer configuration. This includes applications, system policy, hardware,
themes, development tooling, package recipes, and configuration generators.

## Discovery and selection

The root `flake.nix` discovers every `.nix` file under `modules/`, `hosts/`,
`profiles/`, and `themes/`. Flake entry points are excluded. Filenames do not
select a module's platform or change its evaluation context. A split feature
needs no import list: its files contribute to the same options.

Discovery makes a feature available. Hosts select native modules through
`config.flake.modules.nixos` or `config.flake.modules.darwin`.
[profiles/default.nix](../profiles/default.nix) selects common applications
once; hosts import that profile and their own additions.

- `modules/applications/` owns application packages, settings, services, and assets.
- `modules/system/`, `modules/desktop/`, and `modules/services/` own workstation infrastructure.
- `hosts/` owns machine identity, hardware, and feature selection.
- `themes/` owns the shared theme and its selection.
- `modules/development/` owns the repository's development environment.
- `modules/shell/scripts/` owns shared shell command sources and their packages.

## Native configuration

A portable package can share one native module across both platforms:

```nix
let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.example ];
  };
in {
  flake.modules.nixos.example = common;
  flake.modules.darwin.example = common;
}
```

Native modules receive their host's `config`, `lib`, and `pkgs`. Use those
arguments for installed packages, preserving the independent Linux and Darwin
Nixpkgs pins. Capture flake inputs and shared feature values in the outer
module; do not pass them through native `specialArgs`.

Host identity stays native: read `config.workstation.user`,
`config.workstation.checkout`, and `config.workstation.codeRoot`. Read the home
directory from `config.users.users.${config.workstation.user}.home`.
Othinus uses `raf`; Proserpina uses `rafael`.

## Shared functions and values

Keep small private helpers in their consumer's `let` block. A helper that merits
its own file declares a typed option under `features.<owner>` in that file.
Consumers read the option from the outer `config` instead of importing a helper
file. For example, a `package.nix` feature can declare:

```nix
{ lib, ... }:
{
  options.features.example.package = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Example package built with the consuming host's package set.";
  };
  config.features.example.package = { pkgs }: pkgs.example;
}
```

Its consumer captures the factory before entering a native module:

```nix
{ config, ... }:
let
  makePackage = config.features.example.package;
  common = { pkgs, ... }: {
    environment.systemPackages = [ (makePackage { inherit pkgs; }) ];
  };
in {
  flake.modules.nixos.example = common;
  flake.modules.darwin.example = common;
}
```

Use the result type that matches the helper: package, string, attributes, or
another specific type. Do not add a global factory registry or per-application
enable flags. Shared values need no `flake.lib` output.

## Entry points and assets

`flake.nix` starts the workstation configuration. Root `devenv.nix` adapts the
devenv CLI to the development feature. T3Code's rolling updater calls this
flake's shared package definitions with the selected release version and hashes.
Entry points select and evaluate feature modules; they do not duplicate feature
implementations.

Configuration assets, scripts, JSON, and templates remain in their native
formats beside their feature. Othinus's generated hardware settings are kept
inside `flake.modules.nixos.othinus-hardware`; preserve that wrapper when
refreshing hardware detection.

See the [application guide](applications/README.md) for package ownership and
[DEVELOPMENT.md](../DEVELOPMENT.md) for validation.
