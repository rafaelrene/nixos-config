{
  inputs,
  lib,
  ...
}:
{
  options.features.raycast.package = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Raycast package factory using pinned stable vendor downloads.";
  };
  config.features.raycast.package =
    { pkgs }:
    let
      upstream = inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.raycast;
    in
    if pkgs.stdenv.hostPlatform.system != "aarch64-darwin" then
      throw "Raycast v2 is only packaged for aarch64-darwin."
    else
      upstream.overrideAttrs (previous: {
        version = "2.13.1.0";
        src = pkgs.fetchurl {
          url = "https://x-r2.raycast-releases.com/Raycast_2.13.1.0_7695c029bb_arm64.dmg";
          hash = "sha256-5id3SR/r5b+t9GHT+aHOdhwuZh5jW8E+aSGhbXVmDHc=";
        };
        dontFixup = true;
        # brew-nix skips postInstall, so disable its updaters in installPhase.
        # Raycast may still check for and download updates.
        installPhase = previous.installPhase + ''
          chmod a-x \
            "$out/Applications/Raycast.app/Contents/Resources/Updater" \
            "$out/Applications/Raycast.app/Contents/Resources/UpdaterDaemon"
        '';
      });
}
