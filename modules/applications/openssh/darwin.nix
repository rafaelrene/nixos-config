{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.darwin.openssh =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      runtimes = features.shell.runtimes { inherit pkgs; };
      user = config.workstation.user;
      home = config.users.users.${user}.home;
      provision = lib.escapeShellArgs [
        "/usr/bin/sudo"
        "-H"
        "-u"
        user
        "--"
        runtimes.python3
        "${./ssh-keys.py}"
        "--repo"
        "${config.workstation.checkout}/modules/applications/openssh"
        "--home"
        home
        "--source"
        "${home}/.ssh"
        "--age"
        "${pkgs.age}/bin/age"
        "--ssh-keygen"
        "${pkgs.openssh}/bin/ssh-keygen"
        "--temporary-directory"
        "${home}/.ssh"
        "--skip-config"
      ];
    in
    {
      environment.systemPackages = [ pkgs.openssh ];
      services.openssh.enable = true;
      # OpenSSH rejects group-writable checkout files, even behind a symlink.
      workstation.links.".ssh/config" = "${./hosts.config}";

      # Run after existing preflight checks, before files or services are activated.
      # darwin-rebuild check also enters preActivation and must never provision keys.
      system.activationScripts.preActivation.text = lib.mkAfter ''
        if [ "''${checkActivation:-0}" != 1 ]; then
          ${provision}
        fi
      '';
    };
}
