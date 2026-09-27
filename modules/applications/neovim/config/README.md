# Neovim configuration

Both workstations link this directory as `~/.config/nvim`. LazyVim and
`lazy-lock.json` manage plugins; `lua/plugins/` contains workstation overrides.

The system generates `/etc/xdg/nvim-theme.json` from the shared theme.
The Nix package in `../package.nix` supplies runtimes for Mason installers and
Lazygit, Tree-sitter for parser builds, and Viu for image previews on Neovim's
private `PATH` on both machines.
Project tools come from each project's Devenv environment.

Use the repository's `devenv shell` and `treefmt` when editing this configuration.
