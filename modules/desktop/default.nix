{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules = {
    darwin.desktop =
      {
        lib,
        pkgs,
        ...
      }:
      let
        theme = features.theme { inherit lib pkgs; };
      in
      {
        imports = [ (features.modulesFor "darwin").desktop-session ];
        system.defaults = {
          NSGlobalDomain = {
            AppleMeasurementUnits = "Centimeters";
            AppleMetricUnits = 1;
            AppleTemperatureUnit = "Celsius";
            AppleInterfaceStyle = if theme.dark then "Dark" else null;
            AppleInterfaceStyleSwitchesAutomatically = false;
            AppleShowAllExtensions = true;
            InitialKeyRepeat = 15;
            KeyRepeat = 2;
            NSAutomaticCapitalizationEnabled = false;
            NSAutomaticDashSubstitutionEnabled = false;
            NSAutomaticPeriodSubstitutionEnabled = false;
            NSAutomaticQuoteSubstitutionEnabled = false;
            NSAutomaticSpellingCorrectionEnabled = false;
            NSDocumentSaveNewDocumentsToCloud = false;
            NSNavPanelExpandedStateForSaveMode = true;
            NSNavPanelExpandedStateForSaveMode2 = true;
          };
          finder = {
            AppleShowAllFiles = true;
            AppleShowAllExtensions = true;
            ShowPathbar = true;
            ShowStatusBar = true;
            FXDefaultSearchScope = "SCcf";
            FXPreferredViewStyle = "Nlsv";
            NewWindowTarget = "Home";
          };
          dock = {
            show-recents = false;
            tilesize = 39;
            minimize-to-application = true;
            expose-group-apps = true;
          };
          trackpad = {
            Clicking = true;
            TrackpadRightClick = true;
          };
          CustomUserPreferences."com.apple.HIToolbox".AppleEnabledInputSources = [
            {
              InputSourceKind = "Keyboard Layout";
              "KeyboardLayout ID" = 0;
              "KeyboardLayout Name" = "U.S.";
            }
            {
              InputSourceKind = "Keyboard Layout";
              "KeyboardLayout ID" = -11013;
              "KeyboardLayout Name" = "Slovak";
            }
            {
              "Bundle ID" = "com.apple.CharacterPaletteIM";
              InputSourceKind = "Non Keyboard Input Method";
            }
            {
              "Bundle ID" = "com.apple.PressAndHold";
              InputSourceKind = "Non Keyboard Input Method";
            }
          ];
          CustomUserPreferences.NSGlobalDomain = {
            AppleLanguages = [
              "en-SK"
              "sk-SK"
            ];
            AppleLocale = "en_SK";
          };
        };
      };

    nixos.desktop = {
      services = {
        # greetd's PAM integration unlocks the login keyring at desktop login.
        gnome.gnome-keyring.enable = true;
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
      };
      environment.sessionVariables = {
        NIXOS_OZONE_WL = "1";
        QT_QPA_PLATFORM = "wayland;xcb";
      };
    };
  };
}
