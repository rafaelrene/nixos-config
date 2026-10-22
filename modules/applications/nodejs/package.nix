{ lib, ... }:
let
  release = builtins.fromJSON (builtins.readFile ./release.json);
in
{
  options.features.nodejs.package = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Node.js runtime for application-private PATHs.";
  };

  config.features.nodejs.package =
    { pkgs }:
    # nups refreshes release.json from upstream Node 24 releases. Vendor binaries
    # include their patched native libraries without waiting for Nixpkgs.
    pkgs.stdenvNoCC.mkDerivation {
      pname = "nodejs";
      inherit (release) version;
      src = pkgs.fetchurl release.sources.${pkgs.stdenv.hostPlatform.system};
      nativeBuildInputs = lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.autoPatchelfHook;
      buildInputs = lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.stdenv.cc.cc.lib;
      dontBuild = true;
      dontStrip = true;
      installPhase = ''
        runHook preInstall
        mkdir -p "$out"
        cp -r bin include lib share "$out/"
        runHook postInstall
      '';
      doInstallCheck = true;
      nativeInstallCheckInputs = [ pkgs.versionCheckHook ];
      versionCheckProgram = "${placeholder "out"}/bin/node";
      versionCheckProgramArg = "--version";
      meta = {
        description = "Node.js JavaScript runtime";
        homepage = "https://nodejs.org/";
        license = lib.licenses.mit;
        sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
        mainProgram = "node";
        platforms = [
          "aarch64-darwin"
          "x86_64-linux"
        ];
      };
    };
}
