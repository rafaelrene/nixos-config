{ pkgs, ... }:

let
  installKeys = pkgs.writeShellApplication {
    name = "install-managed-ssh-keys";
    runtimeInputs = [ pkgs.util-linux ];
    text = ''
      # Drop root before touching either the checkout or the user's files.
      exec runuser -u raf -- ${pkgs.python3}/bin/python3 ${./ssh-keys.py} \
        --repo /data/code/nixos-config/modules/services/ssh \
        --home /home/raf \
        --source /data/code/ansible/roles/ssh/files \
        --age ${pkgs.age}/bin/age \
        --script ${pkgs.util-linux}/bin/script \
        --ssh-keygen ${pkgs.openssh}/bin/ssh-keygen
    '';
  };
in
{
  users.users.raf.openssh.authorizedKeys.keys = [ (builtins.readFile ./othinus.pub) ];
  networking.firewall.extraInputRules = ''
    ip saddr 192.168.86.0/24 tcp dport 22 accept comment "Othinus LAN SSH"
  '';
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
  environment.systemPackages = [ pkgs.age ];

  # Run before activation so cancellation or a bad passphrase aborts the
  # switch. Boot, build and dry-activate must never wait for a passphrase.
  system.preSwitchChecks.sshKeys = ''
    if [ "$2" = switch ] || [ "$2" = test ]; then
      ${installKeys}/bin/install-managed-ssh-keys
    fi
  '';

  systemd.tmpfiles.rules = [
    "d /home/raf/.ssh 0700 raf raf - -"
    "L /home/raf/.ssh/config - - - - /data/code/nixos-config/modules/services/ssh/config"
  ];
}
