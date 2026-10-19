This repository is a central configuration for all of my machines.
It configures them regardless of OS: Linux (NixOS) and MacOS (nix-darwin).

See [README.md](README.md) for the project introduction and overview of features.

## Working principles

- Follow the dendritic Nix pattern with flake-parts and import-tree
- Keep application modules individually selectable; compose them through ordinary,
  nested bundles for shared and platform selections
- Use `features.modulesFor` for named module imports so overlapping bundles include
  each merged feature once
- By default, any changes apply to all machines
- Convenience of use is number one priority
- Prioritize nix options, then application-native configuration and lastly,
  only fallback to scripts when needed
- Keep differences between platforms or machines explicit, while keeping
  common parts reusable
- Preserve live editing of Git, Ghostty, Neovim, and agent configuration
- Avoid scope creep, ask about unrelated changes

## Application updates

- Disable built-in auto-updates by default for every app; document unsupported
  cases in brief comments beside the affected configuration.
- Keep scheduled Nix updates for coding agents and T3 Code; update other apps
  manually through Nix.
- Apps may update their plugins, extensions, tools, and content.

## Documentation

- Keep [README.md](README.md) limited to purpose, machines, major capabilities,
  architecture, update ownership, and rebuild/update commands.
- Describe only the current state and keep each point brief.
- Keep implementation details, decision rationales, hotkey references, catalogues,
  runbooks, and TODOs out of the README. Do not move removed material into new docs.
- Put implementation constraints and unsupported updater cases in brief comments
  beside the relevant source configuration.

## Boundaries

- Evaluate risk after task is done and only ask for approval if there are risks
- Keep secrets out of repository and Nix store

## Validation

Enter `devenv shell` for the repository's development tools. Run checks explicitly;
the environment does not install Git hooks or format files on entry. For one
command, use `devenv shell -- <command>`.

```sh
treefmt --fail-on-change
statix check . --ignore .devenv
deadnix --fail --exclude .devenv
```

Use temporary tests to verify behavior when useful. Remove them and their artifacts
before finishing the task

For configuration changes, run formatting, lint, and relevant checks, including:

```sh
nix flake check --no-build
nix build --no-link .#nixosConfigurations.othinus.config.system.build.toplevel
```

For Darwin changes, also evaluate and build the Darwin system:

```sh
nix eval --raw .#darwinConfigurations.Proserpina.system.drvPath
nix build --no-link .#darwinConfigurations.Proserpina.system
```

If you need me to activate a system with sudo give me command with
absolute path so I can copy paste it into terminal regardless of where I am:

```sh
ns [absolute/path/to/nixos-config-worktree]
nups [absolute/path/to/nixos-config-worktree]
```
