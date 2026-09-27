{ config, lib, ... }:
{
  options.features.theme = lib.mkOption {
    type = lib.types.functionTo lib.types.attrs;
    description = "Shared theme factory evaluated with each host's lib and pkgs.";
  };

  config.features.theme = config.features.themes.catppuccin;
}
