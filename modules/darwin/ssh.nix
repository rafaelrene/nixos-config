{
  config,
  lib,
  pkgs,
  ...
}:
let
  user = config.system.primaryUser;
  home = config.users.users.${user}.home;
  provision = lib.escapeShellArgs [
    "/usr/bin/sudo"
    "-H"
    "-u"
    user
    "--"
    "${pkgs.python3}/bin/python3"
    (toString ../services/ssh/ssh-keys.py)
    "--repo"
    "${config.workstation.checkout}/modules/services/ssh"
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
  environment.systemPackages = [ pkgs.age ];

  # Run after existing preflight checks, before files or services are activated.
  # darwin-rebuild check also enters preActivation and must never provision keys.
  system.activationScripts.preActivation.text = lib.mkAfter ''
    if [ "''${checkActivation:-0}" != 1 ]; then
      ${provision}
    fi
  '';
}
