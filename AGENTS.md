# Othinus workstation configuration

This repository is the full NixOS configuration for Rene's workstation PC,
Othinus. Everything configurable belongs here: hardware and boot, networking,
users, packages and runtimes, services, desktop and themes, SSH, editor and
shell configuration, and agent tools.

## Philosophy

Convenience comes first. The intended workflow is to clone this repository and
apply the workstation configuration with:

```sh
sudo nixos-rebuild switch --flake /data/code/nixos-config#othinus
```

Keep the existing hardcoded checkout paths for now. Checkout-location
independence is deferred in TODO.md.

Do everything the NixOS way. Declare packages, services, configuration, and
themes here and apply them through the system rebuild. Do not introduce extra
manual setup scripts or post-rebuild steps. The existing independent tool
updaters remain until the unified update work in TODO.md is implemented.

This is a public GitHub repository. Never put plaintext secrets or decryption
credentials in the repository or Nix store. Encrypted secret bundles are allowed.

## Coding preferences

Write simple, robust code that is easy to understand. Aggressively rewrite code
when it simplifies the task at hand. Propose unrelated rewrites separately.
Prefer NixOS options and declarative configuration over custom runtime logic.

Application-native configuration may use the language the application requires,
such as Lua for Neovim. Ask before introducing other languages or adding scripts.
Every new script or substantial script rewrite needs explicit approval, including
shell code embedded in Nix activation hooks, services, and package wrappers.
Existing scripts are not blanket approval for expansion. Leave the current SSH
Python helper unchanged for now. Node is an option to propose for approved
helpers, not permission to add them.

Read and consider the ADRs in [adrs/](adrs/) for every decision. Explain any
conflict and ask before departing from an ADR.

Update README.md when behavior, setup commands, or required manual steps change.

## What not to do

- Never use Home Manager.
- Do not add Python scripts or rewrite helpers in Python.
- Do not add scripts or substantially rewrite them without explicit approval.
- Do not keep a permanent test suite or task-created test files. Temporary tests
  are allowed during development; delete them before considering the task done.
  Keep existing package build checks enabled.
- Do not switch the live workstation without Rene's explicit instruction.
  Evaluation and builds do not require approval.

## Validation

For configuration changes, run Nix evaluation and build checks before finishing:

```sh
nix flake check --no-build
nix build --no-link .#nixosConfigurations.othinus.config.system.build.toplevel
```
