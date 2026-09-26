# Agent guide

This repository configures Othinus (NixOS) and Proserpina (nix-darwin).

See [README.md](README.md) for the overview and [adrs/](adrs/) for decisions.
Read relevant ADRs before changing a feature; explain conflicts and ask before
departing from a decision.

## Working principles

- Unless explicitly instructed otherwise, all changes apply to every machine
  managed by this repository.
- Convenience first: declare workstation changes here and apply them through
  the system rebuild, without extra manual setup.
- Prefer native Nix options and application-native configuration. Use scripts
  and other implementation languages only when native configuration cannot
  provide the required behavior. Reuse existing modules and helpers; keep
  platform differences explicit.
- Simplify within the task's scope. Propose unrelated rewrites separately.
- Keep existing checkout paths. Put necessary documentation beside the feature,
  and deferred work in [TODO.md](TODO.md).

## Boundaries

- Get explicit approval before switching the live system or replacing running services.
- Get approval for new scripts, substantial script rewrites (including embedded
  shell), or new implementation languages. Application-native configuration is fine.
- Keep plaintext secrets out of this public repository and the Nix store.
- Use temporary tests and remove them afterward; do not add a permanent suite.
  Keep existing package build checks enabled.

## Validation

Enter `devenv shell` for the repository's development tools. Run checks explicitly;
the environment does not install Git hooks or format files on entry. See
[DEVELOPMENT.md](DEVELOPMENT.md) for commands and platform prerequisites.

For configuration changes, run formatting, lint, and relevant checks, including:

```sh
nix flake check --no-build
nix build --no-link .#nixosConfigurations.othinus.config.system.build.toplevel
```

For Darwin changes, also evaluate and build the Darwin system and run focused
native checks using the [Proserpina guide](hosts/proserpina/README.md#validation).
Verify shared refactors preserve Othinus. Report checks that remain untested;
evaluation and builds do not require approval.
