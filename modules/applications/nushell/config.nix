{ lib, ... }:
{
  options.features.nushell.configuration = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Generate Nushell configuration with host paths, commands, and shell hooks.";
  };
  config.features.nushell.configuration =
    {
      lib,
      pkgs,
      checkout,
      hostname,
      rebuildCommand ? "sudo nixos-rebuild switch",
      updateCommand ? "nix-update-packages",
    }:

    let
      starshipNuHook = pkgs.runCommand "starship-hook.nu" { nativeBuildInputs = [ pkgs.starship ]; } ''
        starship init nu > "$out"
      '';
      zoxideNuHook = pkgs.runCommand "zoxide-hook.nu" { nativeBuildInputs = [ pkgs.zoxide ]; } ''
        zoxide init nushell --cmd cd > "$out"
      '';
      nuConfig = pkgs.writeText "config.nu" (
        lib.replaceStrings
          [
            "@zoxide-hook@"
            "@direnv-hook@"
            "@starship-hook@"
            "@git-nav@"
            "@checkout@"
            "@hostname@"
            "@title-hostname@"
            "@rebuild-command@"
            "@update-command@"
          ]
          [
            (toString zoxideNuHook)
            "${../direnv/hook.nu}"
            (toString starshipNuHook)
            # Retain the tree so git-nav's relative import of shell/scripts/git.nu works.
            "${../..}/applications/nushell/git-nav.nu"
            (builtins.toJSON checkout)
            hostname
            (lib.toLower hostname)
            rebuildCommand
            updateCommand
          ]
          (builtins.readFile ./config.nu)
      );
    in
    nuConfig;
}
