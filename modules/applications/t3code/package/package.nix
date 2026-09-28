{ lib, ... }:
let
  release = builtins.fromJSON (builtins.readFile ./release.json);
in
{
  options.features.t3code.serverPackage = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Package the official T3 Code server with Nushell setup completion support.";
  };

  config.features.t3code.serverPackage =
    {
      appimageTools,
      asar,
      autoPatchelfHook,
      desktop,
      fetchurl,
      installShellFiles,
      lib,
      makeWrapper,
      nodejs_24,
      stdenv,
      stdenvNoCC,
      versionCheckHook,
      version ? release.version,
      hash ? release.${stdenv.hostPlatform.system}.serverHash,
    }:
    let
      isDarwin = stdenv.hostPlatform.isDarwin;
      buildStdenv = if isDarwin then stdenvNoCC else stdenv;
      platform = if isDarwin then "darwin-arm64" else "linux-x64";
      desktopResources =
        if isDarwin then
          "${desktop}/Applications/T3 Code (Nightly).app/Contents/Resources"
        else
          "${
            appimageTools.extractType2 {
              pname = "t3code-desktop";
              inherit version;
              inherit (desktop) src;
            }
          }/resources";
    in
    buildStdenv.mkDerivation (finalAttrs: {
      pname = "t3code-nightly";
      inherit version;
      src = fetchurl {
        url = "https://github.com/pingdotgg/t3code/releases/download/v${finalAttrs.version}/t3-${finalAttrs.version}-${platform}.tar.gz";
        inherit hash;
      };
      nativeBuildInputs = lib.optional (!isDarwin) autoPatchelfHook ++ [
        asar
        installShellFiles
        makeWrapper
      ];
      buildInputs = lib.optional (!isDarwin) stdenv.cc.cc.lib;
      dontBuild = true;
      # Preserve the bundled native modules and resource monitor.
      dontStrip = true;
      # The Linux archive also ships optional musl addons; NixOS uses glibc.
      autoPatchelfIgnoreMissingDeps = lib.optional (!isDarwin) "libc.musl-x86_64.so.1";
      postUnpack = ''
        # The CLI executable embeds its JS. The matching desktop ships a patchable
        # copy; extract it separately so the signed desktop remains untouched.
        asar extract "${desktopResources}/app.asar" "$sourceRoot/desktop"
      '';
      patches = [
        ./nushell-completion.patch
        ./nushell-hidden-setup.patch
      ];
      patchFlags = [
        "-p1"
        "--fuzz=0"
      ];
      installPhase = ''
        runHook preInstall
        mkdir -p "$out/libexec/t3code" "$out/bin"
        cp -r desktop/apps/server/dist/. "$out/libexec/t3code/"
        # Use the CLI's native dependencies, not Electron's addon builds.
        cp -r resource-monitor node_modules "$out/libexec/t3code/"
        ${lib.optionalString isDarwin ''
          # Runtime chmod cannot repair this helper in the read-only Nix store.
          chmod +x "$out/libexec/t3code/node_modules/node-pty/prebuilds/darwin-arm64/spawn-helper"
        ''}
        makeWrapper ${lib.getExe nodejs_24} "$out/bin/t3" \
          --add-flags "$out/libexec/t3code/bin.mjs"
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
        description = "T3 Code nightly server with Nushell setup completion support";
        homepage = "https://t3.codes";
        license = lib.licenses.mit;
        sourceProvenance = with lib.sourceTypes; [
          fromSource
          binaryNativeCode
        ];
        mainProgram = "t3";
        platforms = [
          "x86_64-linux"
          "aarch64-darwin"
        ];
      };
    });
}
