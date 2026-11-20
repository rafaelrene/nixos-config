{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:
let
  version = "1.4.6";
  sources = {
    x86_64-linux = {
      platform = "linux-x64";
      hash = "sha256-KJ6AT/rlT+lY0L4+qDdNyAan40HTzzTl/sqBrQwfQb8=";
    };
    aarch64-darwin = {
      platform = "darwin-arm64";
      hash = "sha256-6VuShal/PXmkrhEiJkpD9yUidAlE3i3I/xuSN2QYkm0=";
    };
  };
  source = sources.${stdenv.hostPlatform.system};
  inherit (stdenv.hostPlatform) isLinux;
in
stdenvNoCC.mkDerivation {
  pname = "twg";
  inherit version;
  src = fetchurl {
    url = "https://teamwork-graph.atlassian.com/cli/twg-${source.platform}-v${version}";
    inherit (source) hash;
  };

  dontUnpack = true;
  dontBuild = true;
  # Preserve the embedded application and the vendor signature on macOS.
  dontStrip = true;
  nativeBuildInputs = lib.optional isLinux autoPatchelfHook;
  buildInputs = lib.optional isLinux stdenv.cc.cc.lib;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/twg"
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
    versionCheckHook
  ];
  versionCheckProgramArg = "--version";
  versionCheckKeepEnvironment = [ "HOME" ];

  meta = {
    description = "Atlassian Teamwork Graph CLI for Jira, Confluence, and Bitbucket";
    homepage = "https://developer.atlassian.com/cloud/twg-cli/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames sources;
    mainProgram = "twg";
  };
}
