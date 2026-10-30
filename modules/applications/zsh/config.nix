{ config, lib, ... }:
{
  options.features.zsh.configuration = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Generate shared zsh navigation and workstation commands.";
  };
  config.features.zsh.configuration =
    {
      lib,
      pkgs,
      codeRoot,
    }:
    pkgs.writeText "workstation.zsh" (
      lib.replaceStrings
        [
          "@code-root@"
          "@navigation@"
          "@git-nav@"
          "@git-worktrees@"
        ]
        [
          (lib.escapeShellArg codeRoot)
          (toString ./navigation.zsh)
          (toString ./git-nav.zsh)
          (toString config.features.shell.gitWorktreesSource)
        ]
        (builtins.readFile ./config.zsh)
    );
}
