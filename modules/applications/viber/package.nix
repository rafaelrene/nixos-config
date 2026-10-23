{ inputs, lib, ... }:
{
  options.features.viber.package = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Viber package factory preserving the signed vendor application.";
  };
  config.features.viber.package =
    { pkgs }:
    let
      source = inputs.viber-download;
    in
    pkgs.stdenvNoCC.mkDerivation {
      pname = "viber";
      # Pin the complete signed update payload, without a separate hash manifest.
      version = "rolling-${builtins.substring 0 12 (builtins.hashString "sha256" source.narHash)}";
      src = source;
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
