{ inputs, ... }:
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
      environment.systemPackages = [ unstable.yaak ];
    };
}
