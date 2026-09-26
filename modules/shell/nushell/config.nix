{
  lib,
  pkgs,
  checkout ? "/data/code/nixos-config",
  hostname ? "othinus",
  rebuildCommand ? "sudo nixos-rebuild switch",
  updateCommand ? "nix-update-packages",
}:

let
  starshipNuHook = pkgs.runCommand "starship-hook.nu" { nativeBuildInputs = [ pkgs.starship ]; } ''
    starship init nu > "$out"
  '';
  devenvNuHook = pkgs.runCommand "devenv-hook.nu" { nativeBuildInputs = [ pkgs.devenv ]; } ''
    export HOME="$TMPDIR/home"
    export XDG_CACHE_HOME="$TMPDIR/cache"
    mkdir -p "$HOME" "$XDG_CACHE_HOME"
    devenv hook nu > "$out"
  '';
  zoxideNuHook = pkgs.runCommand "zoxide-hook.nu" { nativeBuildInputs = [ pkgs.zoxide ]; } ''
    zoxide init nushell --cmd cd > "$out"
  '';
  nuConfig = pkgs.writeText "config.nu" (
    lib.replaceStrings
      [
        "@zoxide-hook@"
        "@devenv-hook@"
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
        (toString devenvNuHook)
        (toString starshipNuHook)
        "${../.}/nushell/git-nav.nu"
        (builtins.toJSON checkout)
        hostname
        (lib.toLower hostname)
        rebuildCommand
        updateCommand
      ]
      (builtins.readFile ./config.nu)
  );
in
nuConfig
