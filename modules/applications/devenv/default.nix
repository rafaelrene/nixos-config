{ config, inputs, ... }:
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
        # T3 queues project scripts before the first prompt. Devenv's terminal
        # UI and reload session can consume that input during activation.
        if [[ -n "''${T3CODE_PROJECT_ROOT:-}" ]]; then
          eval "$(${executable} hook zsh -- --no-tui --no-reload)"
        else
          eval "$(${executable} hook zsh)"
        fi
        source ${trustHook}
      '';
      # Keep upstream's dependency pins so its binary cache matches on both hosts.
      nixpkgs.overlays = [ inputs.devenv.overlays.default ];
    };
in
{
  flake.modules.nixos.devenv =
    { config, ... }:
    let
      user = config.workstation.user;
      home = config.users.users.${user}.home;
      group = config.users.users.${user}.group;
    in
    {
      imports = [ common ];
      systemd.tmpfiles.rules = [
        "d ${home}/.config/devenv 0755 ${user} ${group} - -"
        "L+ ${home}/.config/devenv/config.yaml - - - - ${./config.yaml}"
      ];
    };
  flake.modules.darwin.devenv = {
    imports = [ common ];
    workstation.links.".config/devenv/config.yaml" = "${./config.yaml}";
  };
}
