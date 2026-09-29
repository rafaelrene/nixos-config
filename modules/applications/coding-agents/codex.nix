{ lib, ... }:
{
  options.features.coding-agents.codex = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Package an official Codex release with its companion resources.";
  };

  config.features.coding-agents.codex =
    { pkgs, release }:
    let
      system = pkgs.stdenv.hostPlatform.system;
      target =
        {
          aarch64-darwin = "aarch64-apple-darwin";
          x86_64-linux = "x86_64-unknown-linux-musl";
        }
        .${system};
    in
    pkgs.stdenvNoCC.mkDerivation {
      pname = "codex";
      inherit (release) version;
      src = pkgs.fetchurl {
        url = "https://releases.openai.com/codex/releases/${release.version}/codex-package-${target}.tar.gz";
        sha256 = release.hashes.${system};
      };
      sourceRoot = ".";
      dontStrip = true;
      dontPatchELF = true;
      dontPatchShebangs = true;
      nativeBuildInputs = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.makeWrapper ];
      installPhase = ''
        runHook preInstall
        mkdir -p $out/libexec/codex $out/bin
        cp -R bin codex-package.json codex-path codex-resources $out/libexec/codex/
        ${
          if pkgs.stdenv.hostPlatform.isLinux then
            "makeWrapper $out/libexec/codex/bin/codex $out/bin/codex --prefix PATH : ${
              lib.makeBinPath [ pkgs.bubblewrap ]
            }"
          else
            "ln -s ../libexec/codex/bin/codex $out/bin/codex"
        }
        ln -s ../libexec/codex/bin/codex-code-mode-host $out/bin/codex-code-mode-host
        runHook postInstall
      '';
      doInstallCheck = true;
      nativeInstallCheckInputs = [ pkgs.versionCheckHook ];
      versionCheckProgram = "${placeholder "out"}/bin/codex";
      versionCheckProgramArg = "--version";
      meta = {
        description = "OpenAI Codex CLI";
        homepage = "https://github.com/openai/codex";
        license = lib.licenses.asl20;
        mainProgram = "codex";
        platforms = [
          "aarch64-darwin"
          "x86_64-linux"
        ];
        sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      };
    };
}
