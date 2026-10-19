{ config, lib, ... }:
{
  flake.modules = lib.genAttrs [ "nixos" "darwin" ] (platform: {
    shell.imports = [
      (config.features.modulesFor "generic").shell
    ]
    ++ (with (config.features.modulesFor platform); [
      cli-tools
      version-control
      project-run
      starship
      zsh
      zoxide
    ]);
    version-control.imports = with (config.features.modulesFor platform); [
      git
      delta
      git-delete-branches
      neovim
    ];
  });
}
