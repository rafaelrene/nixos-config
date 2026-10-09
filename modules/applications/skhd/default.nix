{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.darwin.skhd =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.skhd;
      executable = "/var/lib/skhd/skhd";
      runtimes = features.shell.runtimes { inherit pkgs; };
    in
    {
      services.skhd = {
        enable = true;
        skhdConfig = ''
          alt - return : /usr/bin/open -a Ghostty "${
            config.users.users.${config.workstation.user}.home
          }" --args --window-save-state=never
        '';
      };

      workstation.darwinIdentity.executables.skhd = {
        source = "${cfg.package}/bin/skhd";
        destination = executable;
        identifier = "org.nixos.skhd";
      };
      launchd.user.agents.skhd.serviceConfig = {
        ProgramArguments = lib.mkForce (
          [ executable ]
          ++ lib.optionals (cfg.skhdConfig != "") [
            "-c"
            "/etc/skhdrc"
          ]
        );
        EnvironmentVariables = {
          SHELL = runtimes.zsh;
          # Change the plist when the package changes so nix-darwin restarts skhd.
          SKHD_PACKAGE = toString cfg.package;
        };
      };
    };
}
