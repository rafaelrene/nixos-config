{ inputs, config, ... }:
{
  flake.modules.darwin.yaak =
    { pkgs, ... }:
    let
      unstable = import inputs.nixpkgs-unstable {
        system = pkgs.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      };
    in
    {
      imports = [ (config.features.updates.darwinAppSettings "yaak") ];
      environment.systemPackages = [ unstable.yaak ];
    };
}
