{
  config,
  inputs,
  lib,
  ...
}:
{
  options.features.google-drive.package = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Google Drive package factory using pinned vendor downloads.";
  };
  config.perSystem = { pkgs, ... }: {
    packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      google-drive = config.features.google-drive.package { inherit pkgs; };
    };
  };
  config.features.google-drive.package =
    { pkgs }:
    let
      source = inputs.google-drive-download;
    in
    pkgs.stdenvNoCC.mkDerivation {
      pname = "google-drive";
      # The mutable download has no independent version/hash feed. The lockfile
      # pins its bytes; the signed bundle retains the actual application version.
      version = "rolling-${builtins.substring 0 12 (builtins.hashString "sha256" source.narHash)}";
      src = source;
      nativeBuildInputs = with pkgs; [
        xar
        pbzx
        cpio
      ];
      unpackPhase = ''
        bash ${./extract-installer.sh} "$src" GoogleDrive.pkg
        xar -xf GoogleDrive.pkg
        mkdir payload
        cd payload
        pbzx -n ../GoogleDrive_arm64.pkg/Payload | cpio -id
      '';
      dontBuild = true;
      dontFixup = true;
      installPhase = ''
        mkdir -p "$out/Applications"
        cp -R "Google Drive.app" "$out/Applications/"
      '';
      meta.platforms = [ "aarch64-darwin" ];
    };
}
