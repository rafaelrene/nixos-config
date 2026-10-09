{
  flake.modules.darwin.skhd =
    { config, lib, ... }:
    let
      cfg = config.services.skhd;
      executable = "/var/lib/skhd/skhd";
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

      launchd.user.agents.skhd.serviceConfig = {
        ProgramArguments = lib.mkForce (
          [ executable ]
          ++ lib.optionals (cfg.skhdConfig != "") [
            "-c"
            "/etc/skhdrc"
          ]
        );
        # Change the plist when the package changes so nix-darwin restarts skhd.
        EnvironmentVariables.SKHD_PACKAGE = toString cfg.package;
      };

      # macOS resolves symlinks and records the designated signing requirement.
      # Keep a real executable and an identity independent of its binary hash.
      system.activationScripts.extraActivation.text = ''
        (
          /usr/bin/install -d -m 0755 -o root -g wheel /var/lib/skhd
          skhd_tmp=$(/usr/bin/mktemp /var/lib/skhd/.skhd.XXXXXX)
          trap '/bin/rm -f "$skhd_tmp"' EXIT
          /usr/bin/install -m 0755 -o root -g wheel ${cfg.package}/bin/skhd "$skhd_tmp"
          /usr/bin/codesign --force --sign - --timestamp=none \
            --identifier org.nixos.skhd \
            --requirements '=designated => identifier "org.nixos.skhd"' "$skhd_tmp"
          /usr/bin/codesign --verify --strict "$skhd_tmp"
          if ! /usr/bin/cmp -s "$skhd_tmp" ${executable}; then
            /bin/mv -f "$skhd_tmp" ${executable}
          fi
        )
      '';
    };
}
