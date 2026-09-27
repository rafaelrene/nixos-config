{ inputs, lib, ... }:
{
  options.features.raycast.package = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Raycast package factory retaining the required database-compatible version.";
  };
  config.features.raycast.package =
    {
      lib,
      pkgs,
    }:
    let
      unstable = import inputs.nixpkgs-unstable {
        system = pkgs.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      };
    in
    # Raycast 2.4 cannot open databases already migrated by 2.5.2.
    if lib.versionAtLeast unstable.raycast.version "2.5.2.0" then
      unstable.raycast
    else if pkgs.stdenv.hostPlatform.system == "aarch64-darwin" then
      unstable.raycast.overrideAttrs {
        version = "2.5.2.0";
        src = pkgs.fetchurl {
          name = "Raycast.dmg";
          url = "https://x-r2.raycast-releases.com/Raycast_2.5.2.0_67ef5b0f31_arm64.dmg";
          hash = "sha256-G3l4Ng0blsqWsL8T2bHRlAWZzuxh3YyFoN4/DoJEWyM=";
        };
      }
    else
      throw "Raycast's 2.5.2 fallback is only packaged for aarch64-darwin.";
}
