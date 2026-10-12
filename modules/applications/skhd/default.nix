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
        package = pkgs.skhd.overrideAttrs (previous: {
          postPatch = (previous.postPatch or "") + ''
            # Observe the Hyper modifiers injected by OmniWM's head event tap,
            # regardless of which service starts first.
            substituteInPlace src/event_tap.c \
              --replace-fail kCGHeadInsertEventTap kCGTailAppendEventTap
          '';
        });
        skhdConfig = ''
          alt - return : /usr/bin/open -a Ghostty "$HOME" --args --window-save-state=never

          # Quit Helium to retain its session and bypass Zen mode's hidden close
          # button. Forward every other app to OmniWM's closeFocusedWindow binding.
          ctrl + alt + cmd - q [
            "helium" : /usr/bin/osascript -e 'tell application id "net.imput.helium" to quit'
            * ~
          ]
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
