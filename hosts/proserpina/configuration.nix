{ config, inputs, ... }:
let
  modules = config.features.modulesFor "darwin";
in
{
  flake.darwinConfigurations.Proserpina = inputs.nix-darwin.lib.darwinSystem {
    modules = [ modules.proserpina ];
  };
  flake.modules.darwin.proserpina = {
    imports = [
      modules.mac-workstation
      modules.headful
    ];

    nixpkgs.hostPlatform = "aarch64-darwin";
    system.stateVersion = 6;
    users.users.rafael.openssh.authorizedKeys.keyFiles = [
      ../../modules/applications/openssh/proserpina.pub
    ];
    networking = {
      hostName = "Proserpina";
      localHostName = "Proserpina";
      computerName = "proserpina";
    };
    workstation.user = "rafael";
    workstation.desktop.sessionPolicy = "manual-lock";
  };
}
