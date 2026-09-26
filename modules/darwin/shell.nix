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
    systemPackages = [
      branches
      deleteBranches
      prun
    ];
    systemPath = lib.mkBefore [ "$HOME/.local/bin" ];
    # The persistent profile is available before launchd recreates /run at boot.
    shells = [ "/nix/var/nix/profiles/system/sw/bin/nu" ];
    variables = {
      LANG = "en_US.UTF-8";
      # macOS locale identifiers inherited from GUI apps are not POSIX locales.
      LC_ALL = "en_US.UTF-8";
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
    };
  };
}
