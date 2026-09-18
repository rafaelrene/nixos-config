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
  flavorTitle = lib.toUpper (builtins.substring 0 1 flavor) + builtins.substring 1 (-1) flavor;
  blend =
    percent: foreground:
    lib.concatMapStrings
      (
        offset:
        lib.fixedWidthString 2 "0" (
          lib.toLower (
            lib.toHexString (
              builtins.div (
                percent * lib.fromHexString (builtins.substring offset 2 foreground)
                + (100 - percent) * lib.fromHexString (builtins.substring offset 2 colors.base)
              ) 100
            )
          )
        )
      )
      [
        0
        2
        4
      ];
  diff = {
    added = blend 10 colors.green;
    removed = blend 10 colors.red;
    addedEmphasis = blend 25 colors.green;
    removedEmphasis = blend 25 colors.red;
  };
in
palette
// {
  name = "Catppuccin ${flavorTitle}";
  dark = flavor != "latte";
  inherit diff;
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
    colorScheme = "Catppuccin${flavorTitle}${accentTitle}";
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
  delta = {
    dark = flavor != "latte";
    syntax-theme = "Catppuccin ${flavorTitle}";
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
    minus-emph-style = "bold syntax #${diff.removedEmphasis}";
    minus-style = "syntax #${diff.removed}";
    plus-emph-style = "bold syntax #${diff.addedEmphasis}";
    plus-style = "syntax #${diff.added}";
    map-styles = "bold purple => syntax #${blend 25 colors.mauve}, bold blue => syntax #${blend 25 colors.blue}, bold cyan => syntax #${blend 25 colors.teal}, bold yellow => syntax #${blend 25 colors.yellow}";
  };
  neovim = {
    background = "#${colors.base}";
    plugin = "catppuccin/nvim";
    name = "catppuccin";
    colorscheme = "catppuccin-nvim";
    opts = {
      flavour = flavor;
      transparent_background = true;
      custom_highlights = {
        NormalFloat.bg = "NONE";
        FloatBorder.bg = "NONE";
        FloatBorder.fg = "#${colors.${accent}}";
        CursorLineNr.fg = "#${colors.${accent}}";
        Visual.bg = "#${colors.surface2}";
        IncSearch = {
          bg = "#${colors.${accent}}";
          fg = "#${colors.crust}";
        };
      };
    };
  };
}
