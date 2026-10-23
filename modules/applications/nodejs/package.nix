{ inputs, lib, ... }:
let
  checksums = lib.splitString "\n" (builtins.readFile inputs.nodejs-checksums);
  platforms = {
    aarch64-darwin = "darwin-arm64";
    x86_64-linux = "linux-x64";
  };
  sources = lib.mapAttrs (
    _: platform:
    let
      matches = lib.filter (entry: entry != null) (
        map (builtins.match "([0-9a-f]{64})  node-v(24[.][0-9]+[.][0-9]+)-${platform}[.]tar[.]gz") checksums
      );
      entry =
        if builtins.length matches == 1 then
          builtins.head matches
        else
          throw "Expected one Node.js 24 checksum for ${platform}.";
      version = builtins.elemAt entry 1;
    in
    {
      inherit version;
      url = "https://nodejs.org/dist/v${version}/node-v${version}-${platform}.tar.gz";
      sha256 = builtins.elemAt entry 0;
    }
  ) platforms;
in
{
  options.features.nodejs.package = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Node.js runtime for application-private PATHs.";
  };

  config.features.nodejs.package =
    { pkgs }:
    let
      source = sources.${pkgs.stdenv.hostPlatform.system};
    in
    # The locked upstream checksum manifest selects binaries with their bundled
    # native-library fixes, independently of Nixpkgs' Node release schedule.
    pkgs.stdenvNoCC.mkDerivation {
      pname = "nodejs";
      inherit (source) version;
      src = pkgs.fetchurl { inherit (source) url sha256; };
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
