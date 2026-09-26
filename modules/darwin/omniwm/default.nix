{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  package = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.omniwm;
  home = config.users.users.${config.system.primaryUser}.home;
  settings = import ./settings.nix { inherit lib pkgs; };
  # IDs in com.apple.symbolichotkeys.
  disabledSymbolicHotkeys =
    # Previous choices: accessibility zoom and contrast, Dock hiding, input
    # sources, and Spotlight's Command+Space, which Raycast uses.
    lib.range 15 26
    ++ [
      52
      60
      61
      64
      65
      164
    ]
    # Mission Control, app windows, and space switching take Control+arrows
    # before OmniWM sees Caps Lock chords.
    ++ lib.range 32 35
    ++ lib.range 79 82
    # "Switch to Desktop 1-10" used Option+digits.
    ++ lib.range 118 127;
in
{
  assertions = [
    {
      assertion = package.version == "0.7.1";
      message = "OmniWM's complete settings schema is version-specific. Refresh modules/darwin/omniwm/defaults.json and validate settings.nix before upgrading from 0.7.1.";
    }
  ];

  workstation.links.".config/omniwm/settings.toml" = toString (
    (pkgs.formats.toml { }).generate "omniwm-settings.toml" settings
  );

  launchd.user.agents.omniwm.serviceConfig = {
    # Use the installed, signed copy so macOS permissions have a stable app path.
    ProgramArguments = [ "/Applications/Nix Apps/OmniWM.app/Contents/MacOS/OmniWM" ];
    RunAtLoad = true;
    KeepAlive.Crashed = true;
    ProcessType = "Interactive";
    LimitLoadToSessionType = "Aqua";
    ThrottleInterval = 10;
    StandardOutPath = "${home}/.local/state/nix-darwin/omniwm.log";
    StandardErrorPath = "${home}/.local/state/nix-darwin/omniwm.log";
  };

  # Caps Lock becomes Right Control in the HID layer: it never toggles capitals,
  # drives settings.nix's side-specific chords, and reveals the workspace bar.
  # nix-darwin reapplies the mapping at every boot.
  system.keyboard = {
    enableKeyMapping = true;
    userKeyMapping = [
      {
        HIDKeyboardModifierMappingSrc = lib.fromHexString "700000039"; # Caps Lock
        HIDKeyboardModifierMappingDst = lib.fromHexString "7000000E4"; # Right Control
      }
    ];
  };

  system.defaults = {
    # Nix owns the whole list; unlisted shortcuts revert to macOS defaults.
    # macOS applies changes at the next login.
    CustomUserPreferences."com.apple.symbolichotkeys".AppleSymbolicHotKeys =
      lib.genAttrs (map toString disabledSymbolicHotkeys)
        (_: {
          enabled = false;
        });
    spaces.spans-displays = false;
    dock = {
      autohide = true;
      mru-spaces = false;
      showMissionControlGestureEnabled = false;
      showAppExposeGestureEnabled = false;
    };
    # OmniWM owns three-finger scrolling/workspaces and four-finger overview.
    trackpad = {
      TrackpadThreeFingerDrag = false;
      TrackpadThreeFingerHorizSwipeGesture = 0;
      TrackpadThreeFingerVertSwipeGesture = 0;
      TrackpadFourFingerHorizSwipeGesture = 0;
      TrackpadFourFingerVertSwipeGesture = 0;
    };
  };
}
