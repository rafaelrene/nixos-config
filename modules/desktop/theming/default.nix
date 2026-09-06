{ lib, pkgs, ... }:
let
  theme = import ../../../themes { inherit lib pkgs; };
  inherit (theme) colors;
  accent = theme.accentColor;
  render =
    name: source:
    pkgs.writeText name (
      lib.replaceStrings
        [
          "@gtk-theme@"
          "@cursor-theme@"
          "@font@"
          "@monospace-font@"
          "@color-scheme@"
          "@icon-theme@"
          "@kvantum-theme@"
        ]
        [
          theme.gtk.name
          theme.cursor.name
          theme.font.interface
          theme.font.monospace
          theme.kde.colorScheme
          theme.icons.name
          theme.kvantum.name
        ]
        (builtins.readFile source)
    );
  gtk3Settings = render "gtk-3.0-settings.ini" ./gtk-3.0-settings.ini;
  gtk4Settings = render "gtk-4.0-settings.ini" ./gtk-4.0-settings.ini;
  kvantumSettings = render "kvantum.kvconfig" ./kvantum.kvconfig;
  kdeGlobals = render "kdeglobals" ./kdeglobals;
in
{
  programs = {
    dconf = {
      enable = true;
      profiles.user.databases = [
        {
          settings."org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
            gtk-theme = theme.gtk.name;
            icon-theme = theme.icons.name;
            cursor-theme = theme.cursor.name;
          };
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
    "L+ /home/raf/.config/Kvantum/kvantum.kvconfig - - - - ${kvantumSettings}"
    "L+ /home/raf/.config/kdeglobals - - - - ${kdeGlobals}"
  ];
}
