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
      source = "${config.workstation.checkout}/modules/applications/openssh";
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
      programs.ssh.startAgent = true;
      # GitHub's ED25519 host key, verified against https://api.github.com/meta.
      programs.ssh.knownHosts."github.com".publicKey =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
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
        # The switch check repoints config with a backup; tmpfiles only fills gaps.
        "L ${home}/.ssh/config - - - - ${source}/config"
        "L ${home}/.ssh/hosts.config - - - - ${source}/hosts.config"
        # Checkout ACLs can make both the linked config and its include group-writable.
        "z ${source}/config 0644 - - - -"
        "z ${source}/hosts.config 0644 - - - -"
      ];
    };
}
