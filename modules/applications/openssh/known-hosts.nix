{ config, ... }:
let
  shared = (config.features.modulesFor "generic").openssh;
in
{
  flake.modules = {
    generic.openssh = { lib, ... }: {
      # Replace the empty file NixOS otherwise generates from programs.ssh.knownHosts.
      environment.etc."ssh/ssh_known_hosts".source = lib.mkForce ./known_hosts;
      programs.ssh.extraConfig = ''
        GlobalKnownHostsFile /etc/ssh/ssh_known_hosts
        UserKnownHostsFile none
      '';
    };
    nixos.openssh.imports = [ shared ];
    darwin.openssh.imports = [ shared ];
  };
}
