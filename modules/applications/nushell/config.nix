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
      home,
      code,
      rebuildCommand ? "sudo nixos-rebuild switch",
      updateCommand ? "nix-update-packages",
    }:

    let
      navSettings = pkgs.writeText "nav-settings.json" (
        builtins.toJSON {
          inherit home code;
          sshHosts = [
            "othinus"
            "proserpina"
          ];
        }
      );
      navModule = pkgs.writeText "navigation.nu" (
        lib.replaceStrings [ "@nav-settings@" ] [ (toString navSettings) ] (
          builtins.readFile ./navigation.nu
        )
      );
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
            "@nav@"
            "@checkout@"
            "@hostname@"
            "@rebuild-command@"
            "@update-command@"
          ]
          [
            (toString zoxideNuHook)
            "${../direnv/hook.nu}"
            (toString starshipNuHook)
            # Retain the tree so git-nav's relative import of shell/scripts/git.nu works.
            "${../..}/applications/nushell/git-nav.nu"
            (toString navModule)
            (builtins.toJSON checkout)
            hostname
            rebuildCommand
            updateCommand
          ]
          (builtins.readFile ./config.nu)
      );
    in
    nuConfig;
}
