This repository is a central configuration for all of my machines.
It configures them regardless of OS: Linux (NixOS) and MacOS (nix-darwin).

See [README.md](README.md) for the project introduction and overview of features.

## Working principles

- Follow dendritic nix pattern
- Use flake-parts
- By default, any changes apply to all machines
- Convenience of use is number one priority
- Prioritize nix options, then application-native configuration and lastly,
only fallback to scripts when needed
- Keep differences between platforms or machines explicit, while keeping
common parts reusable
- Avoid scope creep, ask about unrelated changes

## Documentation

- Keep repository overview in [README.md](README.md)
- Keep overview in sync with code; Describe only current state
- Keep every point brief; Utilize short descriptions and lists

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
python3 -m unittest discover -s tests -v
```

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
