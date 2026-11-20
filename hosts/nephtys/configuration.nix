{ config, inputs, ... }:
let
  modules = config.features.modulesFor "darwin";
in
{
  flake.darwinConfigurations.nephtys = inputs.nix-darwin.lib.darwinSystem {
    modules = [ modules.nephtys ];
  };
  flake.modules.darwin.nephtys = {
    imports = with modules; [
      mac-workstation
      desktop-applications
      desktop
      remote-desktop
      discord
      slack
      omniwm
      gifox
      raycast
      shottr
      skhd
      proton-pass
      ungoogled-chromium
    ];

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
    workstation = {
      user = "raf";
      rex.defaultTerminal = true;
      desktop.sessionPolicy = "unattended";
    };
  };
}
