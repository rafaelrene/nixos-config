{ config, ... }:
let
  inherit (config) features;
  common =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      runtimes = features.shell.runtimes { inherit pkgs; };
      shellApplication = args: features.shell.application ({ inherit pkgs; } // args);
      node = features.nodejs.package { inherit pkgs; };
      deletionReview = shellApplication {
        name = "git-delete-branches";
        runtimeInputs = with pkgs; [
          git
          fzf
          jq
          coreutils
          findutils
          gnugrep
          gawk
          bash
        ];
        text = ''
          exec ${runtimes.zsh} -f ${./.}/git-delete-branches.zsh "$@"
        '';
      };
      picker = shellApplication {
        name = "workstation-picker";
        runtimeInputs = with pkgs; [
          git
          fzf
          fd
          openssh
        ];
        text = ''
          exec ${lib.getExe node} ${./.}/picker.mts ${lib.getExe deletionReview} ${lib.escapeShellArg config.workstation.codeRoot} "$@"
        '';
      };
    in
    {
      environment.systemPackages = [ picker ];
      programs.zsh.interactiveShellInit = lib.mkOrder 950 ''
        source ${./integration.zsh}
      '';
    };
in
{
  flake.modules = {
    nixos.workstation-picker = common;
    darwin.workstation-picker = common;
  };
}
