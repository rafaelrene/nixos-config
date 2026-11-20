{ config, ... }:
let
  inherit (config) features;
  provisionArgs = pkgs: home: [
    "${./provision.py}"
    "--archive"
    "${./workstation-secrets.age}"
    "--public-keys"
    "${../../applications/openssh}"
    "--home"
    home
    "--bitbucket-helper"
    "${../../applications/bitbucket/credentials.py}"
    "--age"
    "${pkgs.age}/bin/age"
    "--ssh-keygen"
    "${pkgs.openssh}/bin/ssh-keygen"
  ];
in
{
  flake.modules = {
    nixos.workstation-secrets =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        user = config.workstation.user;
        home = config.users.users.${user}.home;
        provision = pkgs.writeShellApplication {
          name = "install-workstation-secrets";
          runtimeInputs = [ pkgs.util-linux ];
          text = ''
            exec runuser -u ${lib.escapeShellArg user} -- ${pkgs.python3}/bin/python3 \
              ${lib.escapeShellArgs (provisionArgs pkgs home)} \
              --script ${pkgs.util-linux}/bin/script
          '';
        };
      in
      {
        # A failed unlock must abort the switch. Boot and dry activation never prompt.
        system.preSwitchChecks.workstationSecrets = ''
          if [ "$2" = switch ] || [ "$2" = test ]; then
            ${lib.getExe provision}
          fi
        '';
      };

    darwin.workstation-secrets =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        user = config.workstation.user;
        home = config.users.users.${user}.home;
        runtimes = features.shell.runtimes { inherit pkgs; };
        provision = lib.escapeShellArgs (
          [
            "/usr/bin/sudo"
            "-H"
            "-u"
            user
            "--"
            runtimes.python3
          ]
          ++ provisionArgs pkgs home
          ++ [
            "--temporary-directory"
            "${home}/.ssh"
          ]
        );
      in
      {
        # Provision after preflight checks and before any services start.
        system.activationScripts.preActivation.text = lib.mkAfter ''
          if [ "''${checkActivation:-0}" != 1 ]; then
            ${provision}
          fi
        '';
      };
  };
}
