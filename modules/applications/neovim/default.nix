{ lib, pkgs, ... }:
let
  theme = import ../../../themes { inherit lib pkgs; };
in
{
  # Mason downloads executables built for conventional Linux distributions.
  programs.nix-ld.enable = true;

  environment = {
    systemPackages = [
      (pkgs.neovim.override {
        # Mason's installers need these runtimes, but the shell does not.
        wrapperArgs = [
          "--suffix"
          "PATH"
          ":"
          (lib.makeBinPath [
            pkgs.gcc
            pkgs.go
            pkgs.python3
          ])
        ];
      })
    ];
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
