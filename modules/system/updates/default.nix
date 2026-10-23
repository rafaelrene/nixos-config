{ config, ... }:
let
  inherit (config) features;
  packages =
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
      environment.systemPackages = [
        (features.shell.application {
          inherit pkgs;
          name = "nix-update-packages";
          runtimeInputs = with pkgs; [
            coreutils
            nix
            zsh
            jq
          ];
          text = ''
            exec ${runtimes.zsh} -f ${./updates.zsh} ${lib.escapeShellArg config.workstation.checkout} ${./update-frontend-design.sh} "$@"
          '';
        })
      ];
    };
in
{
  flake.modules.nixos.updates = packages;
  flake.modules.darwin.updates = {
    imports = [ packages ];
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
  };
}
