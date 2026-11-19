{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.darwin.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      theme = features.theme { inherit lib pkgs; };
      files = builtins.readDir ../../wallpapers;
      wallpapers = pkgs.linkFarm "wallpapers" (
        map
          (name: {
            inherit name;
            path = ../../wallpapers + "/${name}";
          })
          (
            builtins.filter (
              name:
              files.${name} == "regular"
              && builtins.match ".*\\.(jpg|jpeg|png|webp)" name != null
              && builtins.match ".*-[0-9]+x[0-9]+\\.[^.]+" name == null
            ) (builtins.attrNames files)
          )
      );
    in
    {
      imports = [ (features.modulesFor "darwin").desktop-session ];
      power.sleep = {
        computer = "never";
        harddisk = "never";
        display = 10;
      };
      # pmset applies to AC, battery, and UPS; systemsetup alone is not sufficient.
      system.activationScripts.power.text = lib.mkAfter ''
        /usr/bin/pmset -a sleep 0 disksleep 0 displaysleep ${
          if config.power.sleep.display == "never" then "0" else toString config.power.sleep.display
        }
      '';
      workstation = {
        links."Pictures/Wallpapers" = toString wallpapers;
        desktop.wallpaper = "${wallpapers}/akame-95y5rk.png";
      };
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
}
