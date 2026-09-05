{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  theme = import ../theme.nix;
  inherit (theme) colors;
  accent = colors.${theme.accent};
  accentTitle =
    lib.toUpper (builtins.substring 0 1 theme.accent)
    + builtins.substring 1 ((builtins.stringLength theme.accent) - 1) theme.accent;
  catppuccinGtk = pkgs.catppuccin-gtk.override {
    accents = [ theme.accent ];
    variant = theme.flavor;
  };
  catppuccinCursor = pkgs.catppuccin-cursors."mocha${accentTitle}";
  catppuccinKde = pkgs.catppuccin-kde.override {
    flavour = [ theme.flavor ];
    accents = [ theme.accent ];
  };
  zen = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta;
  helium = inputs.helium-browser.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      wrapProgram $out/bin/helium --add-flags "--force-dark-mode"
    '';
  });
  render =
    name: source: from: to:
    pkgs.writeText name (lib.replaceStrings from to (builtins.readFile source));
  niriConfig =
    render "niri-config.kdl" ../config/niri/config.kdl
      [
        "@accent@"
        "@surface2@"
        "@urgent@"
      ]
      [
        accent
        colors.surface2
        colors.red
      ];
  gtk3Settings =
    render "gtk-3.0-settings.ini" ../config/gtk-3.0-settings.ini
      [ "@accent@" ]
      [ theme.accent ];
  gtk4Settings =
    render "gtk-4.0-settings.ini" ../config/gtk-4.0-settings.ini
      [ "@accent@" ]
      [ theme.accent ];
  kvantumSettings =
    render "kvantum.kvconfig" ../config/kvantum.kvconfig
      [ "@accent@" ]
      [ theme.accent ];
  kdeGlobals =
    render "kdeglobals" ../config/kdeglobals
      [ "@accent-title@" ]
      [
        accentTitle
      ];
  dmsTheme =
    render "dms-catppuccin-${theme.flavor}.json" ../config/dms/catppuccin-mocha.json
      [
        "@accent@"
      ]
      [ "#${accent}" ];
  dmsSettings =
    render "dms-default-settings.json" ../config/dms/default-settings.json
      [
        "@accent@"
      ]
      [ theme.accent ];
in
{
  programs = {
    dconf = {
      enable = true;
      profiles.user.databases = [
        {
          settings."org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
            gtk-theme = "catppuccin-${theme.flavor}-${theme.accent}-standard";
            icon-theme = "breeze-dark";
            cursor-theme = "catppuccin-${theme.flavor}-${theme.accent}-cursors";
          };
        }
      ];
    };
    niri = {
      enable = true;
      useNautilus = false;
    };
    dms-shell.enable = true;
    regreet = {
      enable = true;
      theme = {
        package = catppuccinGtk;
        name = "catppuccin-${theme.flavor}-${theme.accent}-standard";
      };
      font = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = theme.font.interface;
        size = 12;
      };
      cursorTheme = {
        package = catppuccinCursor;
        name = "catppuccin-${theme.flavor}-${theme.accent}-cursors";
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

  # Install both Qt 5/6 style plugins and expose them to applications.
  qt = {
    enable = true;
    platformTheme = "kde";
    style = "kvantum";
  };

  # Publish the dconf preference through the desktop settings portal.
  xdg.portal.config.niri."org.freedesktop.impl.portal.Settings" = [ "gtk" ];

  services = {
    displayManager.defaultSession = "niri";
    greetd.settings.default_session.user = "greeter";

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
    pulseaudio.enable = false;
    upower.enable = true;
    blueman.enable = true;
    logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
    };
  };

  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    nvidia = {
      modesetting.enable = true;
      open = true;
      powerManagement = {
        enable = true;
        finegrained = true;
      };
      prime = {
        amdgpuBusId = "PCI:7:0:0";
        nvidiaBusId = "PCI:1:0:0";
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
      };
    };
  };
  services.xserver.videoDrivers = [ "nvidia" ];

  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
    ];
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
      BROWSER = "helium";
      NIXOS_OZONE_WL = "1";
      QT_QPA_PLATFORM = "wayland;xcb";
      XCURSOR_THEME = "catppuccin-${theme.flavor}-${theme.accent}-cursors";
      XCURSOR_SIZE = "24";
    };
    systemPackages = with pkgs; [
      brightnessctl
      catppuccinCursor
      catppuccinGtk
      catppuccinKde
      (catppuccin-kvantum.override {
        variant = theme.flavor;
        accent = theme.accent;
      })
      ffmpegthumbnailer
      ghostty
      helium
      kdePackages.ark
      kdePackages.breeze-icons
      kdePackages.dolphin
      kdePackages.gwenview
      kdePackages.kdegraphics-thumbnailers
      kdePackages.kio-extras
      kdePackages.okular
      mpv
      vicinae
      xdg-utils
      xwayland-satellite
      zen
    ];

    etc."xdg/gtk-3.0/settings.ini".source = gtk3Settings;
    etc."xdg/gtk-4.0/settings.ini".source = gtk4Settings;
    etc."xdg/Kvantum/kvantum.kvconfig".source = kvantumSettings;
    etc."xdg/kdeglobals".source = kdeGlobals;

    etc."xdg/mimeapps.list".text = ''
      [Default Applications]
      text/html=helium.desktop
      x-scheme-handler/http=helium.desktop
      x-scheme-handler/https=helium.desktop
      x-scheme-handler/about=helium.desktop
      x-scheme-handler/unknown=helium.desktop
      application/pdf=org.kde.okular.desktop
      image/jpeg=org.kde.gwenview.desktop
      image/png=org.kde.gwenview.desktop
      video/mp4=mpv.desktop
      inode/directory=org.kde.dolphin.desktop
    '';
  };

  systemd.user.services.vicinae = {
    description = "Vicinae launcher";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    path = [
      config.system.path
      pkgs.pulseaudio
    ];
    unitConfig.ConditionUser = "raf";
    serviceConfig = {
      ExecStart = "${pkgs.vicinae}/bin/vicinae server --replace";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  systemd.tmpfiles.rules = [
    "d /home/raf/Pictures 0755 raf raf - -"
    "d /home/raf/Pictures/Screenshots 0755 raf raf - -"
    "d /home/raf/.config/DankMaterialShell 0700 raf raf - -"
    "d /home/raf/.config/ghostty 0700 raf raf - -"
    "d /home/raf/.config/gtk-3.0 0700 raf raf - -"
    "d /home/raf/.config/gtk-4.0 0700 raf raf - -"
    "d /home/raf/.config/Kvantum 0700 raf raf - -"
    "d /home/raf/.config/vicinae 0700 raf raf - -"
    "d /home/raf/.config/niri 0700 raf raf - -"
    "L+ /home/raf/.config/niri/config.kdl - - - - ${niriConfig}"
    "L+ /home/raf/.config/ghostty/config - - - - /data/code/nixos-config/config/ghostty/config"
    "L+ /home/raf/.config/gtk-3.0/settings.ini - - - - ${gtk3Settings}"
    "L+ /home/raf/.config/gtk-4.0/settings.ini - - - - ${gtk4Settings}"
    "L+ /home/raf/.config/Kvantum/kvantum.kvconfig - - - - ${kvantumSettings}"
    "L+ /home/raf/.config/kdeglobals - - - - ${kdeGlobals}"
    "L+ /home/raf/.config/nvim - - - - /data/code/nixos-config/config/nvim"
    "L+ /home/raf/.config/DankMaterialShell/theme.json - - - - ${dmsTheme}"
    "C /home/raf/.config/DankMaterialShell/settings.json 0600 raf raf - ${dmsSettings}"
    "C /home/raf/.config/vicinae/config.json 0600 raf raf - /data/code/nixos-config/config/vicinae/config.json"
  ];
}
