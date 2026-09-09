{ lib, pkgs }:
let
  palette = {
    flavor = "mocha";
    accent = "mauve";

    font = {
      interface = "JetBrainsMono Nerd Font";
      interfacePackage = pkgs.nerd-fonts.jetbrains-mono;
      packages = with pkgs; [
        nerd-fonts.jetbrains-mono
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
      ];
      monospace = "JetBrainsMono Nerd Font";
      serif = "Noto Serif";
      sansSerif = "Noto Sans";
    };

    colors = {
      rosewater = "f5e0dc";
      flamingo = "f2cdcd";
      pink = "f5c2e7";
      mauve = "cba6f7";
      red = "f38ba8";
      maroon = "eba0ac";
      peach = "fab387";
      yellow = "f9e2af";
      green = "a6e3a1";
      teal = "94e2d5";
      sky = "89dceb";
      sapphire = "74c7ec";
      blue = "89b4fa";
      lavender = "b4befe";
      text = "cdd6f4";
      subtext1 = "bac2de";
      subtext0 = "a6adc8";
      overlay2 = "9399b2";
      overlay1 = "7f849c";
      overlay0 = "6c7086";
      surface2 = "585b70";
      surface1 = "45475a";
      surface0 = "313244";
      base = "1e1e2e";
      mantle = "181825";
      crust = "11111b";
    };
  };
  inherit (palette)
    flavor
    accent
    colors
    ;
  accentTitle =
    lib.toUpper (builtins.substring 0 1 accent)
    + builtins.substring 1 ((builtins.stringLength accent) - 1) accent;
in
palette
// {
  name = "Catppuccin Mocha";
  accentColor = colors.${accent};
  gtk = {
    name = "catppuccin-${flavor}-${accent}-standard";
    package = pkgs.catppuccin-gtk.override {
      accents = [ accent ];
      variant = flavor;
    };
  };
  cursor = {
    name = "catppuccin-${flavor}-${accent}-cursors";
    package = pkgs.catppuccin-cursors."${flavor}${accentTitle}";
  };
  kde = {
    colorScheme = "CatppuccinMocha${accentTitle}";
    package = pkgs.catppuccin-kde.override {
      flavour = [ flavor ];
      accents = [ accent ];
    };
  };
  kvantum = {
    name = "catppuccin-${flavor}-${accent}";
    package = pkgs.catppuccin-kvantum.override {
      variant = flavor;
      inherit accent;
    };
  };
  icons = {
    name = "breeze-dark";
    package = pkgs.kdePackages.breeze-icons;
  };
  plymouth = {
    name = "catppuccin-${flavor}";
    package = pkgs.catppuccin-plymouth.override { variant = flavor; };
  };
  ghostty = "Catppuccin Mocha";
  delta = {
    dark = true;
    syntax-theme = "Catppuccin Mocha";
    blame-palette = "#${colors.base} #${colors.mantle} #${colors.crust} #${colors.surface0} #${colors.surface1}";
    commit-decoration-style = "box ul";
    file-decoration-style = "#${colors.text}";
    file-style = "#${colors.text}";
    hunk-header-decoration-style = "box ul";
    hunk-header-file-style = "bold";
    hunk-header-line-number-style = "bold #${colors.subtext0}";
    hunk-header-style = "file line-number syntax";
    line-numbers-left-style = "#${colors.overlay0}";
    line-numbers-minus-style = "bold #${colors.red}";
    line-numbers-plus-style = "bold #${colors.green}";
    line-numbers-right-style = "#${colors.overlay0}";
    line-numbers-zero-style = "#${colors.overlay0}";
    # Catppuccin Mocha blends: 25% accent for emphasis, 10% otherwise.
    minus-emph-style = "bold syntax #53394c";
    minus-style = "syntax #34293a";
    plus-emph-style = "bold syntax #404f4a";
    plus-style = "syntax #2c3239";
    map-styles = "bold purple => syntax #494060, bold blue => syntax #384361, bold cyan => syntax #384d5d, bold yellow => syntax #544f4e";
  };
  vicinae = "catppuccin-${flavor}";
  neovim = {
    plugin = "catppuccin/nvim";
    name = "catppuccin";
    colorscheme = "catppuccin-nvim";
    opts = {
      flavour = flavor;
      transparent_background = true;
      custom_highlights = {
        NormalFloat.bg = "NONE";
        FloatBorder.bg = "NONE";
      };
    };
  };
}
