{
  lib,
  pkgs,
  home,
  project ? null,
}:
let
  darwin = pkgs.stdenv.hostPlatform.isDarwin;
  state = "${home}/.local/state/t3code-bundle-updater";
  settings = pkgs.writeText "t3code-updater.json" (
    builtins.toJSON {
      inherit state project;
      source = import ./package/source.nix { inherit pkgs; };
      profile = "${home}/.local/state/nix/profiles/t3code";
      base = "${home}/.local/share/t3code";
      refreshInputs = darwin;
      allowFallback = !darwin;
    }
  );
in
pkgs.writeShellApplication {
  name = "update-t3code";
  runtimeInputs = with pkgs; [
    coreutils
    curl
    git
    nix
    nix-update
    nushell
    (if darwin then flock else util-linux)
  ];
  text = ''
    # Hold the existing process lock across the entire update, including promotion.
    install -d -m 0700 ${lib.escapeShellArg state}
    exec 9>${lib.escapeShellArg "${state}/update.lock"}
    echo "T3 Code: waiting for any existing update to finish..."
    flock 9
    exec nu --no-config-file ${./update.nu} ${settings}
  '';
}
