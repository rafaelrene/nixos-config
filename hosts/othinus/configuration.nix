{
  imports = [
    ./hardware-configuration.nix
    ../../modules/base.nix
    ../../modules/ssh.nix
    ../../modules/boot.nix
    ../../modules/desktop.nix
    ../../modules/global-runtimes.nix
    ../../modules/agents.nix
    ../../modules/t3code.nix
    ../../modules/snapshots.nix
  ];

  system.stateVersion = "26.05";
}
