{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  writableTmpDirAsHomeHook,
  versionCheckHook,
}:
let
  version = "0.47.0";
  sources = {
    x86_64-linux = {
      platform = "linux-x64";
      hash = "sha256-zi4umgMkvWbiQToDQQ52X0xsHRVQPDOAY5hJYRBR1P8=";
    };
    aarch64-darwin = {
      platform = "darwin-arm64";
      hash = "sha256-zfJaGjJEikhx8d3ZNH4AKaIiOIIqIk1NqFxhJFeTRL0=";
    };
  };
  source = sources.${stdenv.hostPlatform.system};
in
stdenvNoCC.mkDerivation {
  pname = "sentry";
  inherit version;
  src = fetchurl {
    url = "https://github.com/getsentry/toolkit/releases/download/cli%40${version}/sentry-${source.platform}";
    inherit (source) hash;
  };
  dontUnpack = true;
  dontBuild = true;
  # Preserve the embedded application and the vendor signature on macOS.
  dontStrip = true;
  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];
  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/sentry"
    runHook postInstall
  '';
  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
    versionCheckHook
  ];
  versionCheckProgram = "${placeholder "out"}/bin/sentry";
  versionCheckProgramArg = "--version";
  # Sentry initializes its config database even when printing its version.
  versionCheckKeepEnvironment = [ "HOME" ];
  meta = {
    description = "Command-line access to Sentry issues, events, and traces";
    homepage = "https://cli.sentry.dev";
    license = lib.licenses.fsl11Asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames sources;
    mainProgram = "sentry";
  };
}
