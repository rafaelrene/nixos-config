{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "t3code-desktop";
  version = "0.0.43-nightly.20260918.1895";
  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${finalAttrs.version}/T3-Code-${finalAttrs.version}-arm64.zip";
    hash = "sha256-wntMuGTcI7o2hSsKoEaeCgzUvJbVxVVoqRG1467hR5M=";
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
})
