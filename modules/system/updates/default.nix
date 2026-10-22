{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.darwin.updates =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      runtimes = features.shell.runtimes { inherit pkgs; };
    in
    {
      # Squirrel must inherit this at launch; restart running apps after changes.
      # Other Electron update checks/downloads may remain enabled.
      # Activation sets the current session; launchd does not retain it across logins.
      launchd.user.envVariables.DISABLE_UPDATE_CHECK = "1";
      environment.variables.DISABLE_UPDATE_CHECK = "1";
      launchd.user.agents.disable-squirrel-updates.serviceConfig = {
        ProgramArguments = [
          "/bin/launchctl"
          "setenv"
          "DISABLE_UPDATE_CHECK"
          "1"
        ];
        RunAtLoad = true;
      };

      environment.systemPackages = [
        (features.shell.darwinApplication {
          inherit pkgs;
          name = "nix-update-packages";
          runtimeInputs = with pkgs; [
            coreutils
            nix
            zsh
            curl
            jq
            libxml2
            _7zz
            unzip
            libarchive
          ];
          text = ''
            exec ${runtimes.zsh} -f ${./updates.zsh} ${lib.escapeShellArg config.workstation.checkout} ${./update-vendor-sources.zsh} ${./update-nodejs.sh} "$@"
          '';
        })
      ];
    };
}
