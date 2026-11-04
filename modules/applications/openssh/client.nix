{ config, ... }:
let
  inherit (config) features;
  shared = (config.features.modulesFor "generic").openssh;
in
{
  flake.modules = {
    generic.openssh =
      { config, ... }:
      let
        source = features.sources.checkoutPath {
          inherit (config.workstation) checkout;
          source = ./.;
        };
      in
      {
        # Accepted host keys update the checkout, only as its workstation user.
        programs.ssh.extraConfig = ''
          Match localuser ${config.workstation.user}
            GlobalKnownHostsFile /dev/null
            UserKnownHostsFile ${source}/known_hosts
          Match all
        '';
      };
    nixos.openssh.imports = [ shared ];
    darwin.openssh.imports = [ shared ];
  };
}
