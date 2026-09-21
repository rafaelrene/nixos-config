{ pkgs }:
let
  sources = builtins.fromJSON (builtins.readFile ./vendor-sources.json);
in
{
  google-drive = pkgs.stdenvNoCC.mkDerivation {
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
  viber = pkgs.stdenvNoCC.mkDerivation {
    pname = "viber";
    inherit (sources.viber) version;
    src = pkgs.fetchurl {
      inherit (sources.viber) url hash;
      name = "viber.zip";
    };
    nativeBuildInputs = [
      pkgs.unzip
      pkgs.libarchive
    ];
    unpackPhase = ''
      unzip -q "$src" Viber.app.tar
      bsdtar -xf Viber.app.tar
      # Updater bookkeeping is outside the signed bundle's resource seal.
      rm -f Viber.app/manifest.md5
    '';
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      mkdir -p "$out/Applications"
      cp -R Viber.app "$out/Applications/"
    '';
    doInstallCheck = true;
    installCheckPhase = ''
      /usr/bin/codesign --verify --deep --strict "$out/Applications/Viber.app"
    '';
    meta.platforms = [ "aarch64-darwin" ];
  };
}
