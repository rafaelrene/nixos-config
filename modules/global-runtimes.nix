{ lib, pkgs, ... }:

let
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
      ]
      [
        (toString zoxideNuHook)
        (toString devenvNuHook)
      ]
      (builtins.readFile ../config/nushell/config.nu)
  );
in
{
  # Global runtimes are deliberately small. Projects declare their own
  # versions in devenv, whose Nushell hook activates on directory changes.
  environment.systemPackages = with pkgs; [
    devenv
    nodejs_24
  ];

  systemd.tmpfiles.rules = [
    "d /home/raf/.config/nushell 0700 raf raf - -"
    "L+ /home/raf/.config/nushell/config.nu - - - - ${nuConfig}"
  ];
}
