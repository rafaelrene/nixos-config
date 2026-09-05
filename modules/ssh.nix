{ pkgs, ... }:

let
  installKeys = pkgs.writeShellApplication {
    name = "install-managed-ssh-keys";
    runtimeInputs = [ pkgs.util-linux ];
    text = ''
      # Drop root before touching either the checkout or the user's files.
      exec runuser -u raf -- ${pkgs.python3}/bin/python3 ${../scripts/ssh-keys.py} \
        --repo /data/code/nixos-config \
        --home /home/raf \
        --source /data/code/ansible/roles/ssh/files \
        --age ${pkgs.age}/bin/age \
        --script ${pkgs.util-linux}/bin/script \
        --ssh-keygen ${pkgs.openssh}/bin/ssh-keygen
    '';
  };
in
{
  programs.ssh.startAgent = true;
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
    "L /home/raf/.ssh/config - - - - /data/code/nixos-config/config/ssh/config"
  ];
}
