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
        dontFixup = true;
        # Raycast v2 no longer reads updaterEnabled. Removing execute permission
        # blocks launchd even if macOS re-enables these services, while preserving
        # Raycast's vendor signature and extension/runtime updates. Checks and
        # downloads may still occur.
        postInstall = (previous.postInstall or "") + ''
          chmod a-x \
            "$out/Applications/Raycast.app/Contents/Resources/Updater" \
            "$out/Applications/Raycast.app/Contents/Resources/UpdaterDaemon"
        '';
      });
}
