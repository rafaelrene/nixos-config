{ pkgs, ... }:

let
  theme = import ../theme.nix;
  inherit (theme) colors;
  accent = colors.${theme.accent};
in
{
  boot = {
    loader = {
      timeout = 5;
      efi.canTouchEfiVariables = true;
      limine = {
        enable = true;
        enableEditor = true;
        maxGenerations = 10;
        validateChecksums = true;
        panicOnChecksumMismatch = false;
        style = {
          wallpapers = [ ];
          backdrop = colors.base;
          interface = {
            branding = "Othinus";
            brandingColor = accent;
            helpColor = colors.green;
            helpColorBright = colors.teal;
          };
          graphicalTerminal = {
            palette = "${colors.surface0};${colors.red};${colors.green};${colors.yellow};${colors.blue};${colors.mauve};${colors.teal};${colors.subtext0}";
            brightPalette = "${colors.surface2};${colors.red};${colors.green};${colors.yellow};${colors.blue};${colors.pink};${colors.sky};${colors.text}";
            foreground = colors.text;
            background = "00${colors.base}";
            brightForeground = colors.text;
            brightBackground = colors.surface0;
            margin = 24;
          };
        };
      };
    };

    plymouth = {
      enable = true;
      theme = "catppuccin-mocha";
      themePackages = [
        (pkgs.catppuccin-plymouth.override { variant = theme.flavor; })
      ];
    };
    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "udev.log_level=3"
    ];
  };
}
