{ config, lib, ... }:
{
  flake.modules = lib.genAttrs [ "nixos" "darwin" ] (platform: {
    shell.imports = with (config.features.modulesFor platform); [
      cli-tools
      version-control
      starship
      workstation-picker
      zsh
      zoxide
    ];
    version-control.imports = with (config.features.modulesFor platform); [
      git
      delta
      neovim
    ];
  });
}
