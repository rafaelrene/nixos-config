{ lib, ... }:
{
  options.features.google-drive.package = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Google Drive package factory using pinned vendor downloads.";
  };
  config.features.google-drive.package =
    { pkgs }:
    let
      sources = builtins.fromJSON (builtins.readFile ../../system/updates/vendor-sources.json);
    in
    pkgs.stdenvNoCC.mkDerivation {
      pname = "google-drive";
      inherit (sources.google-drive) version;
      src = pkgs.fetchurl {
        inherit (sources.google-drive) url hash;
        name = "google-drive.dmg";
      };
      nativeBuildInputs = with pkgs; [
        undmg
        xar
        pbzx
        cpio
      ];
      unpackPhase = ''
        undmg "$src"
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
