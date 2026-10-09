let
  common = { lib, pkgs, ... }: {
    environment.systemPackages = [ pkgs.zoxide ];
    programs.zsh.interactiveShellInit = ''
      eval "$(${lib.getExe pkgs.zoxide} init zsh --cmd cd)"
    '';
  };
in
{
  flake.modules = {
    nixos.zoxide = common;
    darwin.zoxide = common;
  };
}
