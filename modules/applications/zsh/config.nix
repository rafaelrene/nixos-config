{ lib, ... }:
{
  options.features.zsh.configuration = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Generate shared zsh navigation and workstation commands.";
  };
  config.features.zsh.configuration =
    {
      lib,
      pkgs,
      checkout,
      codeRoot,
      hostname,
    }:
    let
      rebuild = if pkgs.stdenv.hostPlatform.isDarwin then "darwin-rebuild" else "nixos-rebuild";
    in
    pkgs.writeText "workstation.zsh" (
      lib.replaceStrings
        [
          "@checkout@"
          "@code-root@"
          "@hostname@"
          "@rebuild@"
          "@navigation@"
          "@git-nav@"
          "@git-worktrees@"
        ]
        [
          (lib.escapeShellArg checkout)
          (lib.escapeShellArg codeRoot)
          (lib.escapeShellArg hostname)
          rebuild
          (toString ./navigation.zsh)
          (toString ./git-nav.zsh)
          (toString ../../shell/scripts/git-worktrees.zsh)
        ]
        (builtins.readFile ./config.zsh)
    );
}
