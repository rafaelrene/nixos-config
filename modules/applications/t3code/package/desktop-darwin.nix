{ lib, ... }:
let
  release = builtins.fromJSON (builtins.readFile ./release.json);
in
{
  options.features.t3code.desktopDarwinPackage = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Package the signed macOS T3 Code desktop application.";
  };

  config.features.t3code.desktopDarwinPackage =
    {
      lib,
      stdenvNoCC,
      fetchurl,
      unzip,
      version ? release.version,
      hash ? release.aarch64-darwin.desktopHash,
    }:
    stdenvNoCC.mkDerivation (finalAttrs: {
      pname = "t3code-desktop";
      inherit version;
      src = fetchurl {
        url = "https://github.com/pingdotgg/t3code/releases/download/v${finalAttrs.version}/T3-Code-${finalAttrs.version}-arm64.zip";
        inherit hash;
      };
      nativeBuildInputs = [ unzip ];
      sourceRoot = ".";
      dontBuild = true;
      dontFixup = true; # Preserve the upstream signed application bundle.
      installPhase = ''
        runHook preInstall
        mkdir -p "$out/Applications"
        cp -R ./*.app "$out/Applications/"
        runHook postInstall
      '';
      meta = {
        description = "Official T3 Code nightly desktop client";
        homepage = "https://t3.codes";
        license = lib.licenses.mit;
        sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
        platforms = [ "aarch64-darwin" ];
      };
    });
}
