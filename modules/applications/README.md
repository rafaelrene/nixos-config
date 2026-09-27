# Application modules

Each directory owns an application: its package, configuration, platform
integration, and private dependencies. `default.nix` is a flake-parts feature
module. `flake.nix` discovers every `.nix` feature file automatically.
Discovery makes a feature available; it does not install the application.
The [repository module guide](../README.md) defines the common evaluation
context and helper conventions for applications, infrastructure, and tooling.

[profiles/default.nix](../../profiles/default.nix) selects shared applications
once. [Othinus](../../hosts/othinus/configuration.nix) and
[Proserpina](../../hosts/proserpina/configuration.nix) import that profile and
list their own additions. A host-specific application stays in this directory
when another machine starts using it.

## Adding an application

Create `application-name/default.nix` and export native modules under the same
name for supported platforms. A portable package needs only:

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

Add its name once to the shared profile, or its platform module to the host's
imports. Do not repeat shared applications in host additions. There is no
separate package-installation list or application enable registry.

## File conventions

- `default.nix` contains the application's main declarations.
- Optional `nixos.nix` and `darwin.nix` files contribute native integration to
  the same feature. Discovery loads them automatically.
- `package.nix`, `settings.nix`, and other focused helpers are also outer
  flake-parts modules. They declare typed `features.<application>` options;
  consumers capture those values from the outer configuration.
- Keep configuration assets and application-specific scripts beside the feature.
  Shared shell helper sources live in `modules/shell/scripts`.

Simple applications have one file. Do not create empty platform files or package
recipes that merely return an unchanged Nixpkgs package. Use a native `programs`
or `services` option when it already owns package installation.

Package factories return packages; they do not install them. Keep each installation
declaration in the owning feature. Platform-specific package selection belongs
in its recipe, using `pkgs.stdenv.hostPlatform.system` for architecture-specific
sources. Declare unsupported vendor platforms explicitly.

## Configuration contexts

The outer feature receives flake inputs and can contribute packages or native
modules. Inner NixOS and Darwin modules receive that host's `config`, `lib`, and
`pkgs`. Use those inner arguments when constructing installed packages; this
preserves the independent Linux and Darwin Nixpkgs pins.

Each host declares `workstation.user`, `workstation.checkout`, and
`workstation.codeRoot`. Read the home directory from
`config.users.users.${config.workstation.user}.home`. These values remain
separate for each host: Othinus uses `raf`; Proserpina uses `rafael`.

User-file infrastructure lives in `modules/system/user-files`. Apps declare Mac
links through `workstation.links` and Linux links through native tmpfiles rules.
Platform services stay with their application as systemd or launchd definitions.

## Updates and private dependencies

`nup` refreshes package sources; `nups` also rebuilds and switches. Forgejo CLI
uses the host's Nixpkgs package. T3Code and coding agents retain their independent
rolling profiles; see [ADR 0007](../../adrs/0007-rolling-tool-profiles.md).

On both hosts, `update-llm-agents` prefetches Numtide's latest flake source and
passes its path and hash to a shared Nix bundle factory. It loads the packages
without applying upstream `nixConfig`; cache trust stays in the system
configuration. The agents install together after a successful build. See the
[coding-agent update guide](coding-agents/README.md) for operation and rollback.

Neovim's package wrapper provides Lazygit, Viu, Tree-sitter, and Mason's helper
runtimes on its private PATH. They are not separate globally selected apps.
Build dependencies and command `runtimeInputs` also stay with their consumer.
Both hosts install mpv; Othinus retains p7zip for archives.

See [DEVELOPMENT.md](../../DEVELOPMENT.md) for formatting, linting, evaluations,
and native build requirements.
