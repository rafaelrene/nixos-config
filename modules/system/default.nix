{ config, ... }:
{
  flake.modules = {
    generic.system = {
      environment.variables = {
        XDG_CONFIG_HOME = "$HOME/.config";
        XDG_CACHE_HOME = "$HOME/.cache";
        XDG_DATA_HOME = "$HOME/.local/share";
        XDG_STATE_HOME = "$HOME/.local/state";
      };
    };
    nixos.system = {
      imports = [
        (config.features.modulesFor "generic").system
        (config.features.modulesFor "nixos").nix
        (config.features.modulesFor "nixos").boot
        (config.features.modulesFor "nixos").networking
      ];
    };
    darwin.system = {
      imports = [
        (config.features.modulesFor "generic").system
        (config.features.modulesFor "darwin").nix
      ];
      homebrew.enable = false;
    };
  };
}
