{ inputs, ... }:
{
  flake.modules.darwin.proton-pass =
    { pkgs, ... }:
    let
      unstable = import inputs.nixpkgs-unstable {
        system = pkgs.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      };
    in
    {
      environment.systemPackages = [
        (unstable.proton-pass.overrideAttrs { dontFixup = true; })
      ];
    };
}
