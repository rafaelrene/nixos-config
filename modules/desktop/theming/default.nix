{ lib, pkgs, ... }:
let
  theme = import ../../../themes { inherit lib pkgs; };
  inherit (theme) colors;
  accent = theme.accentColor;
  renderText =
    source:
    lib.replaceStrings
      [
        "@gtk-theme@"
        "@cursor-theme@"
        "@font@"
        "@monospace-font@"
        "@color-scheme@"
        "@icon-theme@"
        "@kvantum-theme@"
        "@prefer-dark@"
      ]
      [
        theme.gtk.name
        theme.cursor.name
        theme.font.interface
        theme.font.monospace
        theme.kde.colorScheme
        theme.icons.name
        theme.kvantum.name
        (if theme.dark then "1" else "0")
      ]
      (builtins.readFile source);
  render = name: source: pkgs.writeText name (renderText source);
  gtk3Settings = render "gtk-3.0-settings.ini" ./gtk-3.0-settings.ini;
  gtk4Settings = render "gtk-4.0-settings.ini" ./gtk-4.0-settings.ini;
  # Import by store path so the stylesheet's relative asset URLs remain valid.
  gtk4Css = pkgs.writeText "gtk-4.0.css" ''
    @import url("${theme.gtk.package}/share/themes/${theme.gtk.name}/gtk-4.0/gtk.css");
  '';
  kvantumSettings = render "kvantum.kvconfig" ./kvantum.kvconfig;
  rgb =
    color:
    lib.concatMapStringsSep ","
      (offset: toString (lib.fromHexString (builtins.substring offset 2 color)))
      [
        0
        2
        4
      ];
  kdeColors = background: alternate: foreground: {
    BackgroundNormal = rgb background;
    BackgroundAlternate = rgb alternate;
    ForegroundNormal = rgb foreground;
    ForegroundInactive = rgb colors.overlay1;
    ForegroundActive = rgb accent;
    ForegroundLink = rgb colors.blue;
    ForegroundVisited = rgb colors.lavender;
    ForegroundNegative = rgb colors.red;
    ForegroundNeutral = rgb colors.yellow;
    ForegroundPositive = rgb colors.green;
    DecorationFocus = rgb accent;
    DecorationHover = rgb accent;
  };
  # KDE applications read these roles directly; ColorScheme alone is insufficient.
  kdeGlobals = pkgs.writeText "kdeglobals" (
    renderText ./kdeglobals
    + lib.generators.toINI { } {
      "Colors:View" = kdeColors colors.base colors.mantle colors.text;
      "Colors:Window" = kdeColors colors.mantle colors.base colors.text;
      "Colors:Button" = kdeColors colors.surface0 colors.surface1 colors.text;
      "Colors:Selection" = kdeColors accent accent colors.crust;
      "Colors:Tooltip" = kdeColors colors.crust colors.mantle colors.text;
      "Colors:Complementary" = kdeColors colors.crust colors.mantle colors.text;
      "Colors:Header" = kdeColors colors.mantle colors.base colors.text;
      WM = {
        activeBackground = rgb colors.mantle;
        activeForeground = rgb colors.text;
        inactiveBackground = rgb colors.mantle;
        inactiveForeground = rgb colors.overlay1;
      };
    }
  );
in
{
  programs = {
    dconf = {
      enable = true;
      profiles.user.databases = [
        {
          settings."org/gnome/desktop/interface" = {
            color-scheme = if theme.dark then "prefer-dark" else "prefer-light";
            gtk-theme = theme.gtk.name;
            icon-theme = theme.icons.name;
            cursor-theme = theme.cursor.name;
            font-name = "${theme.font.interface} 10";
            monospace-font-name = "${theme.font.monospace} 10";
          };
          locks = map (key: "/org/gnome/desktop/interface/${key}") [
            "color-scheme"
            "gtk-theme"
            "icon-theme"
            "cursor-theme"
            "font-name"
            "monospace-font-name"
          ];
        }
      ];
    };
    regreet = {
      enable = true;
      theme = {
        package = theme.gtk.package;
        name = theme.gtk.name;
      };
      font = {
        package = theme.font.interfacePackage;
        name = theme.font.interface;
        size = 12;
      };
      cursorTheme = {
        package = theme.cursor.package;
        name = theme.cursor.name;
      };
      settings = {
        background = {
          path = "";
          fit = "Cover";
          color = "#${colors.base}";
        };
      };
      extraCss = ''
        window { background: #${colors.base}; color: #${colors.text}; }
        button.suggested-action { background: #${accent}; color: #${colors.crust}; }
      '';
    };
  };

  services.greetd.settings.default_session.user = "greeter";
  # Install both Qt 5/6 style plugins and expose them to applications.
  qt = {
    enable = true;
    platformTheme = "kde";
    style = "kvantum";
  };

  fonts = {
    packages = theme.font.packages;
    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ theme.font.monospace ];
        sansSerif = [
          theme.font.interface
          theme.font.sansSerif
        ];
        serif = [ theme.font.serif ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };

  environment = {
    pathsToLink = [
      "/share/Kvantum"
      "/share/color-schemes"
    ];
    sessionVariables = {
      XCURSOR_THEME = theme.cursor.name;
      XCURSOR_SIZE = "24";
    };
    systemPackages = [
      theme.gtk.package
      theme.cursor.package
      theme.kde.package
      theme.kvantum.package
      theme.icons.package
    ];
    etc = {
      "xdg/gtk-3.0/settings.ini".source = gtk3Settings;
      "xdg/gtk-4.0/settings.ini".source = gtk4Settings;
      "xdg/gtk-4.0/gtk.css".source = gtk4Css;
      "xdg/Kvantum/kvantum.kvconfig".source = kvantumSettings;
      "xdg/kdeglobals".source = kdeGlobals;
    };

  };
  systemd.tmpfiles.rules = [
    "d /home/raf/.config/gtk-3.0 0700 raf raf - -"
    "d /home/raf/.config/gtk-4.0 0700 raf raf - -"
    "d /home/raf/.config/Kvantum 0700 raf raf - -"
    "L+ /home/raf/.config/gtk-3.0/settings.ini - - - - ${gtk3Settings}"
    "L+ /home/raf/.config/gtk-4.0/settings.ini - - - - ${gtk4Settings}"
    "L+ /home/raf/.config/gtk-4.0/gtk.css - - - - ${gtk4Css}"
    "L+ /home/raf/.config/Kvantum/kvantum.kvconfig - - - - ${kvantumSettings}"
    "L+ /home/raf/.config/kdeglobals - - - - ${kdeGlobals}"
  ];
}
