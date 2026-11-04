{ config, ... }:
let
  shared = (config.features.modulesFor "generic").openssh;
in
{
  flake.modules = {
    generic.openssh.programs.ssh.knownHosts = {
      # Verified against https://api.github.com/meta.
      "github.com".publicKey =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
      # Verified against https://bitbucket.org/site/ssh.
      "ssh.bitbucket.org".publicKey =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIazEu89wgQZ4bqs3d63QSMzYVa0MuJ2e2gKTKqu+UUO";
    };
    nixos.openssh.imports = [ shared ];
    darwin.openssh.imports = [ shared ];
  };
}
