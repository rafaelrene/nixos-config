{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.nixos.openssh =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      user = config.workstation.user;
      home = config.users.users.${user}.home;
      group = config.users.users.${user}.group;
      source = features.sources.checkoutPath {
        inherit (config.workstation) checkout;
        source = ./.;
      };
      installKeys = pkgs.writeShellApplication {
        name = "install-managed-ssh-keys";
        runtimeInputs = [ pkgs.util-linux ];
        text = ''
          # Drop root before touching either the checkout or the user's files.
          exec runuser -u ${lib.escapeShellArg user} -- ${pkgs.python3}/bin/python3 ${./ssh-keys.py} \
            --repo ${lib.escapeShellArg source} \
            --home ${lib.escapeShellArg home} \
            --source ${lib.escapeShellArg "${home}/.ssh"} \
            --age ${pkgs.age}/bin/age \
            --script ${pkgs.util-linux}/bin/script \
            --ssh-keygen ${pkgs.openssh}/bin/ssh-keygen
        '';
      };
    in
    {
      services.openssh = {
        enable = true;
        openFirewall = false;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
        };
      };
      programs.ssh = {
        startAgent = true;
        extraConfig = ''
          Match localuser ${user}
            IdentityAgent /run/user/%i/ssh-agent
          Match all
        '';
      };
      # The desktop enables GNOME Keyring, which otherwise adds a second agent.
      services.gnome.gcr-ssh-agent.enable = false;

      # Run before activation so cancellation or a bad passphrase aborts the
      # switch. Boot, build and dry-activate must never wait for a passphrase.
      system.preSwitchChecks.sshKeys = ''
        if [ "$2" = switch ] || [ "$2" = test ]; then
          ${installKeys}/bin/install-managed-ssh-keys
        fi
      '';

      systemd.tmpfiles.rules = [
        "d ${home}/.ssh 0700 ${user} ${group} - -"
        "L ${home}/.ssh/config - - - - ${source}/hosts.config"
        # File replacement must not restore the shared checkout's group-write ACL.
        "a+ ${source} - - - - d:m::r-x"
        "z ${source}/config 0644 - - - -"
        "z ${source}/hosts.config 0644 - - - -"
        "z ${source}/known_hosts 0644 - - - -"
      ];

      # Replace only our legacy wrapper link; leave independently managed config alone.
      system.userActivationScripts.ssh-config = ''
        if [ "$(${pkgs.coreutils}/bin/id -un)" = ${lib.escapeShellArg user} ]; then
          ssh=${lib.escapeShellArg "${home}/.ssh"}
          if [ -L "$ssh/config" ] && [ "$(${pkgs.coreutils}/bin/readlink "$ssh/config")" = "${source}/config" ]; then
            ${pkgs.coreutils}/bin/ln -sfn ${lib.escapeShellArg "${source}/hosts.config"} "$ssh/config"
          fi
          if [ -L "$ssh/hosts.config" ] && [ "$(${pkgs.coreutils}/bin/readlink "$ssh/hosts.config")" = "${source}/hosts.config" ]; then
            ${pkgs.coreutils}/bin/rm "$ssh/hosts.config"
          fi
        fi
      '';
    };
}
