{
  lib,
  stdenvNoCC,
  fetchurl,
  installShellFiles,
  versionCheckHook,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "t3code-nightly";
  version = "0.0.43-nightly.20260918.1895";
  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${finalAttrs.version}/t3-${finalAttrs.version}-darwin-arm64.tar.gz";
    hash = "sha256-drvAN/AVncwKPcwEMmUsyGCsQSJnHUfPk8agzq+wkf0=";
  };
  nativeBuildInputs = [ installShellFiles ];
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/libexec/t3code" "$out/bin"
    cp -r t3 client resource-monitor node_modules "$out/libexec/t3code/"
    ln -s "$out/libexec/t3code/t3" "$out/bin/t3"
    runHook postInstall
  '';
  preInstallCheck = ''
    for shell in bash fish zsh; do
      installShellCompletion --cmd t3 --"$shell" <("$out/bin/t3" --completions "$shell")
    done
  '';
  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = [ "--version" ];
  meta = {
    description = "Official T3 Code nightly server";
    homepage = "https://t3.codes";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "t3";
    platforms = [ "aarch64-darwin" ];
  };
})
