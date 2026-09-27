{
  flake.modules.darwin.user-files =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.workstation;
      user = config.workstation.user;
      home = config.users.users.${user}.home;
      manifest = pkgs.writeText "darwin-user-files.json" (
        builtins.toJSON {
          inherit (cfg)
            links
            stateAliases
            ;
        }
      );
      run =
        mode:
        lib.escapeShellArgs [
          "/usr/bin/sudo"
          "-H"
          "-u"
          user
          "--"
          "${pkgs.coreutils}/bin/env"
          "PATH=${
            lib.makeBinPath [
              pkgs.coreutils
              pkgs.jq
            ]
          }"
          "${pkgs.bash}/bin/bash"
          "${./install-files.sh}"
          home
          (toString manifest)
          mode
        ];
    in
    {
      options.workstation = {
        links = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Home-relative symlinks and their absolute targets.";
        };
        stateAliases = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "XDG directory aliases to existing home-relative application state.";
        };
      };
      config = {
        assertions = [
          {
            assertion = lib.hasPrefix "${home}/" cfg.checkout;
            message = "The Darwin checkout must be inside the primary user's home.";
          }
        ];
        system.activationScripts = {
          preActivation.text = lib.mkBefore ''
            ${run "check"}
          '';
          extraActivation.text = ''
            ${run "apply"}
          '';
        };
      };
    };
}
