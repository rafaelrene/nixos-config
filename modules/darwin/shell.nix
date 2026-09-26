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
    inherit lib pkgs checkout;
    hostname = config.networking.hostName;
    rebuildCommand = "sudo darwin-rebuild switch";
    updateCommand = "nix-update-packages";
  };
  inherit (import ../shell/scripts/packages.nix { inherit pkgs; }) branches deleteBranches prun;
in
{
  environment = {
    systemPackages = [ prun ];
    systemPath = lib.mkBefore [ "$HOME/.local/bin" ];
    # The persistent profile is available before launchd recreates /run at boot.
    shells = [ "/nix/var/nix/profiles/system/sw/bin/nu" ];
    variables = {
      STARSHIP_CONFIG = "${home}/.config/starship/starship.toml";
      FZF_DEFAULT_OPTS = import ../shell/fzf.nix { inherit lib pkgs; };
    };
    # Nushell does not source nix-darwin's POSIX shell initialization.
    etc."nushell/environment.json".text = builtins.toJSON (
      lib.mapAttrs (_: value: lib.replaceStrings [ "$HOME" ] [ home ] value) config.environment.variables
    );
  };
  # Keep nix-darwin's standard Zsh integration; interactive terminals use Nushell.
  programs.zsh.enable = true;

  workstation = {
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
    };
  };
}
