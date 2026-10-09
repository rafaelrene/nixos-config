{ config, ... }:
let
  inherit (config) features;
  common = { lib, pkgs, ... }: {
    environment.systemPackages = [ pkgs.zoxide ];
    programs.zsh.interactiveShellInit = ''
      eval "$(${
        if pkgs.stdenv.hostPlatform.isDarwin then
          "${(features.shell.runtimes { inherit pkgs; }).directory}/zoxide"
        else
          lib.getExe pkgs.zoxide
      } init zsh --cmd cd)"
    '';
  };
in
{
  flake.modules = {
    nixos.zoxide = common;
    darwin.zoxide = common;
  };
}
