{ config, inputs, ... }:
let
  inherit (config) features;
in
{
  flake.modules.nixos.rex = { pkgs, ... }: {
    environment.systemPackages = [
      inputs.rex-linux.packages.${pkgs.stdenv.hostPlatform.system}.rex
    ];
  };
  flake.modules.darwin.rex =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      package = features.rex.package { inherit pkgs; };
      terminal = features.shell.darwinApplication {
        inherit pkgs;
        name = "rex-terminal";
        text = ''
          if (( $# )); then
            ${lib.getExe package} new --cwd "$1" >/dev/null
          fi
          exec /usr/bin/open -a '/Applications/Nix Apps/Rex Beta.app'
        '';
      };
    in
    {
      options.workstation.rex.defaultTerminal = lib.mkEnableOption "Rex as the workstation terminal";
      config = {
        environment.systemPackages = [ package ];
        environment.variables.TERMINAL = lib.mkIf config.workstation.rex.defaultTerminal (
          lib.getExe terminal
        );
        # Rex forces update checks; updates require an explicit install choice.
        system.defaults.CustomUserPreferences."com.superlogical.rex".SUAutomaticallyUpdate = false;
      };
    };
}
