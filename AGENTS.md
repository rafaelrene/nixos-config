# Workstation configuration

This repository configures Othinus with NixOS and Proserpina with nix-darwin.
Everything configurable belongs here: hardware and boot, networking,
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

Use native NixOS and nix-darwin options. Declare packages, services, configuration, and
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

Keep README.md a high-level overview of the project's purpose, philosophy,
features, and basic workflow. Update it when those change. Put necessary setup,
operational, and troubleshooting details beside the relevant host or feature;
do not add per-setting explanations or validation logs to the root README.
Keep deferred work in TODO.md and durable decisions in adrs/.
See [ADR 0010](adrs/0010-keep-documentation-focused.md).

## What not to do

- Never use Home Manager.
- Do not add Python scripts or rewrite helpers in Python.
- Do not add scripts or substantially rewrite them without explicit approval.
- Do not keep a permanent test suite or task-created test files. Temporary tests
  are allowed during development; delete them before considering the task done.
  Keep existing package build checks enabled.
- Do not switch the live workstation without Rene's explicit instruction.
  Evaluation and builds do not require approval.
- Validate Darwin changes with Nix evaluation, builds, and focused native checks.
  A macOS VM is not required. Native checks do not authorize switching the live
  workstation or replacing its running services.

## Validation

For configuration changes, run Nix evaluation and build checks before finishing:

```sh
nix flake check --no-build
nix build --no-link .#nixosConfigurations.othinus.config.system.build.toplevel
```

For Darwin changes, also evaluate `darwinConfigurations.Proserpina.system.drvPath`.
Build `.#darwinConfigurations.Proserpina.system` and run relevant native checks.
Report activation or interactive checks that still need an authorized live
switch. Keep Ansible unchanged and verify that shared refactors preserve
Othinus's configuration.
