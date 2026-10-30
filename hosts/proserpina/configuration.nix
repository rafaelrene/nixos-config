{ config, inputs, ... }:
let
  modules = config.features.modulesFor "darwin";
in
{
  flake.darwinConfigurations.Proserpina = inputs.nix-darwin.lib.darwinSystem {
    modules = [ modules.proserpina ];
  };
  flake.modules.darwin.proserpina =
    { config, ... }:
    {
      imports = [
        modules.workstation
        modules.desktop-workstation
      ];

      nixpkgs.hostPlatform = "aarch64-darwin";
      system = {
        stateVersion = 6;
        primaryUser = config.workstation.user;
      };
      users.users.rafael.home = "/Users/rafael";
      users.users.rafael.openssh.authorizedKeys.keyFiles = [
        ../../modules/applications/openssh/proserpina.pub
      ];
      networking = {
        hostName = "Proserpina";
        localHostName = "Proserpina";
        computerName = "Proserpina";
      };
      workstation = {
        user = "rafael";
        codeRoot = "/Users/rafael/code";
        checkout = "/Users/rafael/code/.personal/nixos-config";
      };
    };
}
