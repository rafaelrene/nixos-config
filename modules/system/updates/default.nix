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
      githubAuth = features.nix.withGithubAuth { inherit pkgs; };
      notify = features.updates.notify { inherit pkgs; };
      home = config.users.users.${config.workstation.user}.home;
      state = "${home}/.local/state/nix-updates";
      stageSettings = pkgs.writeText "nix-update-targets.json" (
        builtins.toJSON {
          agents =
            lib.optional (config.system.build ? codexUpdater) (lib.getExe config.system.build.codexUpdater)
            ++ lib.optional (config.system.build ? claudeUpdater) (
              lib.getExe config.system.build.claudeUpdater
            );
          t3 =
            if config.system.build ? t3codeUpdater then
              {
                stage = lib.getExe config.system.build.t3codeUpdater;
                activate = lib.getExe config.system.build.t3codeActivator;
              }
            else
              null;
        }
      );
      updater = features.shell.application {
        inherit pkgs;
        name = "nix-update-packages";
        runtimeInputs = with pkgs; [
          coreutils
          nix
          zsh
          jq
        ];
        text = ''
          exec ${lib.getExe githubAuth} ${runtimes.zsh} -f ${./report.zsh} \
            'Nix package updates' ${lib.escapeShellArg "${state}/packages.log"} ${lib.getExe notify} \
            ${./updates.zsh} ${lib.escapeShellArg config.workstation.checkout} ${./update-frontend-design.sh} ${stageSettings} "$@"
        '';
      };
      settings = pkgs.writeText "nix-switch.json" (
        builtins.toJSON {
          checkout = config.workstation.checkout;
          hostname = config.networking.hostName;
          rebuild = if pkgs.stdenv.hostPlatform.isDarwin then "darwin-rebuild" else "nixos-rebuild";
          githubAuth = lib.getExe githubAuth;
          packageUpdater = lib.getExe updater;
          targetsFile = "/etc/nix-update-targets.json";
        }
      );
      switch = features.shell.application {
        inherit pkgs;
        name = "ns";
        runtimeInputs = with pkgs; [
          coreutils
          nix
          zsh
          jq
        ];
        text = ''
          exec ${runtimes.zsh} -f ${./report.zsh} \
            'Nix system update' ${lib.escapeShellArg "${state}/ns.log"} ${lib.getExe notify} \
            ${./switch.zsh} ${settings} "$@"
        '';
      };
    in
    {
      system.build.ns = switch;
      environment.etc."nix-update-targets.json".source = stageSettings;
      environment.systemPackages = [
        updater
        switch
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
