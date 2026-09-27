{ config, ... }:
let
  makeTheme = config.features.theme;
  common = { lib, pkgs, ... }: {
    fonts.packages = [ (makeTheme { inherit lib pkgs; }).font.interfacePackage ];
  };
in
{
  flake.modules.nixos.fonts = { pkgs, ... }: {
    imports = [ common ];
    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
    ];
  };
  flake.modules.darwin.fonts = { pkgs, ... }: {
    imports = [ common ];
    fonts.packages = with pkgs; [
      nerd-fonts.hack
      jetbrains-mono
    ];
  };
}
