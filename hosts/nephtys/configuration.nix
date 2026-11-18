{ config, inputs, ... }:
let
  modules = config.features.modulesFor "darwin";
in
{
  flake.darwinConfigurations.nephtys = inputs.nix-darwin.lib.darwinSystem {
    modules = [ modules.nephtys ];
  };
  flake.modules.darwin.nephtys = {
    imports = [ modules.mac-workstation ];

    nixpkgs.hostPlatform = "aarch64-darwin";
    system.stateVersion = 6;
    users.users.raf.openssh.authorizedKeys.keyFiles = [
      ../../modules/applications/openssh/nephtys.pub
    ];
    networking = {
      hostName = "nephtys";
      localHostName = "nephtys";
      computerName = "nephtys";
    };
    workstation.user = "raf";
  };
}
