{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.workstation;
  user = config.system.primaryUser;
  home = config.users.users.${user}.home;
  manifest = pkgs.writeText "darwin-user-files.json" (
    builtins.toJSON {
      inherit (cfg)
        links
        legacyLinks
        legacyDirectories
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
      (toString ./install-files.sh)
      home
      (toString manifest)
      mode
    ];
in
{
  options.workstation = {
    checkout = lib.mkOption {
      type = lib.types.str;
      description = "Absolute path to the editable workstation checkout.";
    };
    links = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Home-relative symlinks and their absolute targets.";
    };
    legacyLinks = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Recognized Ansible target suffix for each replaced symlink.";
    };
    legacyDirectories = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Ansible directory links to preserve as backups and replace with real directories.";
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
      # Never add the existing admin to users.knownUsers: that gives nix-darwin
      # responsibility for creating and deleting the account as well.
      postActivation.text = ''
        /usr/bin/dscl . -create ${lib.escapeShellArg "/Users/${user}"} UserShell /nix/var/nix/profiles/system/sw/bin/nu
      '';
    };
  };
}
