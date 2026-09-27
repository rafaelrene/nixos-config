{
  flake.modules.nixos.nix =
    {
      config,
      lib,
      ...
    }:

    {
      nix = {
        settings.trusted-users = lib.mkForce [ "root" ];
        optimise.automatic = true;
        gc.dates = "weekly";
      };

      assertions = [
        {
          assertion = config.nix.settings.trusted-users == [ "root" ];
          message = "Only root may be a trusted Nix user on Othinus.";
        }
      ];
    };
}
