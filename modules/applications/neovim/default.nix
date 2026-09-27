{ config, ... }:
let
  inherit (config) features;
  common =
    { lib, pkgs, ... }:
    let
      theme = features.theme { inherit lib pkgs; };
    in
    {
      environment = {
        systemPackages = [ (features.neovim.package { inherit lib pkgs; }) ];
        variables = {
          EDITOR = "nvim";
          VISUAL = "nvim";
        };
        etc."xdg/nvim-theme.json".text = builtins.toJSON theme.neovim;
      };
    };
in
{
  flake.modules = {
    nixos.neovim =
      { config, ... }:
      let
        home = config.users.users.${config.workstation.user}.home;
      in
      {
        imports = [ common ];
        # Mason downloads executables built for conventional Linux distributions.
        programs.nix-ld.enable = true;
        systemd.tmpfiles.rules = [
          "L+ ${home}/.config/nvim - - - - ${config.workstation.checkout}/modules/applications/neovim/config"
        ];
      };
    darwin.neovim = { config, ... }: {
      imports = [ common ];
      workstation.links.".config/nvim" =
        "${config.workstation.checkout}/modules/applications/neovim/config";
    };
  };
}
