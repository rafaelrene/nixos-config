{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  libsecret,
  versionCheckHook,
}:
let
  version = "3.0.0";
  sources = {
    x86_64-linux = {
      platform = "x86_64-unknown-linux-gnu";
      hash = "sha256-UGSmOn5qi1iTpVDhOMCnujc6rWXUJd3msrZrUKbBAok=";
    };
    aarch64-darwin = {
      platform = "aarch64-apple-darwin";
      hash = "sha256-heuE55VUSld63Be5b4sAdxvOyU840mRC/X1WHNgjNvI=";
    };
  };
  source = sources.${stdenv.hostPlatform.system};
in
stdenvNoCC.mkDerivation {
  pname = "linear-cli";
  inherit version;
  src = fetchurl {
    url = "https://github.com/schpet/linear-cli/releases/download/v${version}/linear-${source.platform}.tar.xz";
    inherit (source) hash;
  };
  dontBuild = true;
  # Preserve the vendor signature on macOS. The CLI has no built-in auto-updater.
  dontStrip = true;
  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];
  installPhase = ''
    runHook preInstall
    install -Dm755 linear "$out/bin/linear"
    runHook postInstall
  '';
  # Linux authentication calls secret-tool to store API keys in the desktop keyring.
  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    wrapProgram "$out/bin/linear" --prefix PATH : ${lib.makeBinPath [ libsecret ]}
  '';
  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgram = "${placeholder "out"}/bin/linear";
  versionCheckProgramArg = "--version";
  meta = {
    description = "Command-line interface for Linear with Git and Jujutsu integration";
    homepage = "https://github.com/schpet/linear-cli";
    license = lib.licenses.isc;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames sources;
    mainProgram = "linear";
  };
}
