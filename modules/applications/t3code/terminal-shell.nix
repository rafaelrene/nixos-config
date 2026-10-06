{ lib, ... }:
{
  options.features.t3code.terminalShell = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Build T3 Code's private zsh with direnv integration.";
  };

  config.features.t3code.terminalShell =
    { pkgs }:
    let
      startup = pkgs.writeTextDir ".zshrc" ''
        export DIRENV_CONFIG=/etc/direnv
        eval "$(${lib.getExe pkgs.direnv} hook zsh)"
      '';
    in
    pkgs.runCommand "t3code-zsh"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
        meta.mainProgram = "zsh";
      }
      ''
        mkdir -p "$out/bin"
        makeWrapper ${lib.getExe pkgs.zsh} "$out/bin/zsh" \
          --set ZDOTDIR ${startup}
      '';
}
