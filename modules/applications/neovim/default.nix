{ lib, pkgs, ... }:
let
  theme = import ../../../themes { inherit lib pkgs; };
in
{
  environment = {
    systemPackages = [ pkgs.neovim ];
    variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
    etc."xdg/nvim-theme.json".text = builtins.toJSON theme.neovim;
  };
  systemd.tmpfiles.rules = [
    "L+ /home/raf/.config/nvim - - - - /data/code/nixos-config/modules/applications/neovim/config"
  ];
}
