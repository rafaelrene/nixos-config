{
  autoPatchelfHook,
  fetchurl,
  installShellFiles,
  lib,
  stdenv,
  versionCheckHook,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "t3code-nightly";
  version = "0.0.43-nightly.20260918.1895";
  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${finalAttrs.version}/t3-${finalAttrs.version}-linux-x64.tar.gz";
    hash = "sha256-F6WPRkH51PZisYgzCzyJnmF5eivl0Rw30/e1m4vz6Jk=";
  };
  nativeBuildInputs = [
    autoPatchelfHook
    installShellFiles
  ];
  buildInputs = [ stdenv.cc.cc.lib ];
  dontBuild = true;
  # Bun embeds the application in the executable. Preserve its payload.
  dontStrip = true;
  # The official archive also ships optional musl addons; NixOS uses glibc.
  autoPatchelfIgnoreMissingDeps = [ "libc.musl-x86_64.so.1" ];
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
    description = "Official T3 Code nightly packaged with Nix";
    homepage = "https://t3.codes";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "t3";
    platforms = [ "x86_64-linux" ];
  };
})
