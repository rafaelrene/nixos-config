{ inputs, config, ... }:
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
      home = config.users.users.${config.workstation.user}.home;
      runtimes = features.shell.runtimes { inherit pkgs; };
      executable =
        if pkgs.stdenv.hostPlatform.isDarwin then
          "${runtimes.directory}/devenv"
        else
          lib.getExe pkgs.devenv;
      trustedRoots = [
        "${home}/.local/share/t3code/worktrees"
      ]
      # Proserpina's XDG T3 directory aliases existing ~/.t3 state.
      ++ lib.optional pkgs.stdenv.hostPlatform.isDarwin "${home}/.t3/worktrees";
      trustHook = pkgs.writeText "devenv-t3-trust.zsh" (
        lib.replaceStrings
          [ "@trusted-roots@" ]
          [ (lib.concatMapStringsSep " " lib.escapeShellArg trustedRoots) ]
          (builtins.readFile ./trust-t3.zsh)
      );
    in
    {
      environment.systemPackages = [ pkgs.devenv ];
      programs.zsh.interactiveShellInit = lib.mkAfter ''
        eval "$(${executable} hook zsh)"
        source ${trustHook}
      '';
      # Share the release across hosts while preserving upstream cache identity.
      nixpkgs.overlays = [
        (_final: prev: {
          inherit
            (import inputs.nixpkgs-unstable {
              system = prev.stdenv.hostPlatform.system;
              config.allowUnfree = true;
            })
            devenv
            ;
        })
      ];
    };
in
{
  flake.modules.nixos.devenv = common;
  flake.modules.darwin.devenv = common;
}
