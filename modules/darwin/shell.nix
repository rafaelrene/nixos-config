{
  config,
  lib,
  pkgs,
  ...
}:
let
  home = config.users.users.${config.system.primaryUser}.home;
  checkout = config.workstation.checkout;
  nuConfig = import ../shell/nushell/config.nix {
    inherit lib pkgs;
    rebuildCommand = ''sudo darwin-rebuild switch --flake "path:${checkout}#${config.networking.hostName}"'';
    updateCommand = "nix-update-packages";
  };
  inherit (import ../shell/scripts/packages.nix { inherit pkgs; }) branches deleteBranches;
in
{
  environment = {
    # The persistent profile is available before launchd recreates /run at boot.
    shells = [ "/nix/var/nix/profiles/system/sw/bin/nu" ];
    systemPackages = [
      pkgs.nushell
      pkgs.starship
    ];
    variables = {
      STARSHIP_CONFIG = "${home}/.config/starship/starship.toml";
      FZF_DEFAULT_OPTS = import ../shell/fzf.nix { inherit lib pkgs; };
    };
    # Nushell does not source nix-darwin's POSIX shell initialization.
    etc."nushell/environment.json".text = builtins.toJSON (
      lib.mapAttrs (_: value: lib.replaceStrings [ "$HOME" ] [ home ] value) config.environment.variables
    );
  };
  # Keep Zsh available for existing tools such as the imported Zentty helpers.
  programs.zsh.enable = true;

  workstation = {
    legacyDirectories = {
      ".config/nushell" = "/roles/nushell/files";
      ".config/starship" = "/roles/starship/files";
    };
    links = {
      ".config/nushell/config.nu" = toString nuConfig;
      ".config/nushell/env.nu" = toString ./env.nu;
      # Nushell discovers its macOS config in Application Support before it can
      # load env.nu and learn our XDG settings.
      "Library/Application Support/nushell/env.nu" = toString ./env.nu;
      "Library/Application Support/nushell/config.nu" = toString nuConfig;
      ".config/starship/starship.toml" = toString (
        import ../shell/starship/config.nix { inherit lib pkgs; }
      );
      ".local/bin/git-branches" = "${branches}/bin/git-branches";
      ".local/bin/git-delete-branches" = "${deleteBranches}/bin/git-delete-branches";
      ".local/bin/git-db" = "${deleteBranches}/bin/git-delete-branches";
      ".local/bin/zentty-project" = "${checkout}/modules/darwin/scripts/zentty-project";
      ".local/bin/zp" = "${checkout}/modules/darwin/scripts/zentty-project";
      ".local/bin/zentty-subrepo" = "${checkout}/modules/darwin/scripts/zentty-subrepo";
      ".local/bin/zsr" = "${checkout}/modules/darwin/scripts/zentty-subrepo";
    };
    legacyLinks = {
      ".local/bin/git-branches" = "/roles/scripts/files/git-branches";
      ".local/bin/git-delete-branches" = "/roles/scripts/files/git-delete-branches";
      ".local/bin/git-db" = "/roles/scripts/files/git-delete-branches";
      ".local/bin/zentty-project" = "/roles/scripts/files/zentty-project";
      ".local/bin/zp" = "/roles/scripts/files/zentty-project";
      ".local/bin/zentty-subrepo" = "/roles/scripts/files/zentty-subrepo";
      ".local/bin/zsr" = "/roles/scripts/files/zentty-subrepo";
    };
  };
}
