{
  config,
  inputs,
  lib,
  ...
}:
{
  options.features.rex.package = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Rex package factory preserving the signed vendor application.";
  };
  config.perSystem = { pkgs, ... }: {
    packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      rex = config.features.rex.package { inherit pkgs; };
    };
  };
  config.features.rex.package =
    { pkgs }:
    let
      source = inputs.rex-download;
    in
    pkgs.stdenvNoCC.mkDerivation {
      pname = "rex";
      # The preview URL is mutable. The lockfile pins its bytes and ns -u updates
      # them; the signed bundle retains the actual application version.
      version = "rolling-${builtins.substring 0 12 (builtins.hashString "sha256" source.narHash)}";
      src = source;
      nativeBuildInputs = [ pkgs.undmg ];
      unpackPhase = ''
        undmg "$src"
      '';
      dontBuild = true;
      dontFixup = true; # Preserve the vendor signature, including the bundled server.
      installPhase = ''
        mkdir -p "$out/Applications" "$out/bin"
        cp -R "Rex Beta.app" "$out/Applications/"
        ln -s "$out/Applications/Rex Beta.app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex" "$out/bin/rex"
      '';
      doInstallCheck = true;
      installCheckPhase = ''
        /usr/bin/codesign --verify --deep --strict "$out/Applications/Rex Beta.app"
        "$out/bin/rex" version
      '';
      meta = {
        description = "Terminal and SSH multiplexer";
        homepage = "https://www.superlogical.com/rex";
        mainProgram = "rex";
        sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
        platforms = [ "aarch64-darwin" ];
      };
    };
}
