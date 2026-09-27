{ config, ... }:
let
  common = {
    # Portable workstation policy; scheduling and OS integration stay in each host's modules.
    nixpkgs.config.allowUnfree = true;
    nix = {
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        substituters = [
          "https://cache.nixos.org"
          "https://devenv.cachix.org"
          "https://cache.numtide.com"
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbZGZpVJ8lrQ1kX7H7lYZ7cP0E="
          "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
          "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        ];
      };
      gc = {
        automatic = true;
        options = "--delete-older-than 30d";
      };
    };

    environment.variables = {
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_STATE_HOME = "$HOME/.local/state";
    };
  };
in
{
  flake.modules.nixos.system = {
    imports = [
      common
      config.flake.modules.nixos.nix
      config.flake.modules.nixos.boot
      config.flake.modules.nixos.networking
    ];
  };
  flake.modules.darwin.system = {
    imports = [ common ];
    nix.settings.trusted-users = [ "root" ];
    nix.gc.interval = {
      Weekday = 0;
      Hour = 3;
      Minute = 0;
    };
    homebrew.enable = false;
  };
}
