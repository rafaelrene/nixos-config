{ config, inputs, ... }:
let
  inherit (config) features;
in
{
  flake.modules.darwin.omniwm =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      unstable = import inputs.nixpkgs-unstable {
        system = pkgs.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      };
      sources = builtins.fromJSON (builtins.readFile ../../system/updates/vendor-sources.json);
      # Reuse Nixpkgs' signed-bundle packaging with the upstream release from nup.
      package = unstable.omniwm.overrideAttrs {
        inherit (sources.omniwm) version;
        src = pkgs.fetchurl {
          inherit (sources.omniwm) url hash;
        };
      };
      home = config.users.users.${config.system.primaryUser}.home;
      settings = features.omniwm.settings { inherit lib pkgs; };
      settingsFile = (pkgs.formats.toml { }).generate "omniwm-settings.toml" settings;
      installSettings = features.shell.darwinApplication {
        inherit pkgs;
        name = "install-omniwm-settings";
        text = ''
          directory=$1
          ${pkgs.coreutils}/bin/mkdir -p "$directory"
          temporary=$(${pkgs.coreutils}/bin/mktemp "$directory/settings.toml.XXXXXX")
          trap '${pkgs.coreutils}/bin/rm -f "$temporary"' EXIT
          ${pkgs.coreutils}/bin/install -m 600 ${settingsFile} "$temporary"
          ${pkgs.coreutils}/bin/mv -fT "$temporary" "$directory/settings.toml"
        '';
      };
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
        # Keep native Mission Control, app windows, and space switching off.
        ++ lib.range 32 35
        ++ lib.range 79 82
        # "Switch to Desktop 1-10" used Option+digits.
        ++ lib.range 118 127;
    in
    {
      environment.systemPackages = [ package ];

      launchd.user.agents.omniwm.serviceConfig = {
        # Use the installed, signed copy so macOS permissions have a stable app path.
        ProgramArguments = [ "/Applications/Nix Apps/OmniWM.app/Contents/MacOS/OmniWM" ];
        # Reload the agent when either the package or declared settings change.
        EnvironmentVariables = {
          OMNIWM_PACKAGE = toString package;
          OMNIWM_SETTINGS = toString settingsFile;
        };
        RunAtLoad = true;
        KeepAlive.Crashed = true;
        ProcessType = "Interactive";
        LimitLoadToSessionType = "Aqua";
        ThrottleInterval = 10;
        StandardOutPath = "${home}/.local/state/nix-darwin/omniwm.log";
        StandardErrorPath = "${home}/.local/state/nix-darwin/omniwm.log";
      };

      system = {
        # OmniWM rewrites settings during schema migrations and GUI edits. Reapply
        # Nix settings as a writable copy after user-files removes the old symlink.
        activationScripts.extraActivation.text = lib.mkAfter ''
          ${lib.escapeShellArgs [
            "/usr/bin/sudo"
            "-H"
            "-u"
            config.system.primaryUser
            "--"
            (lib.getExe installSettings)
            "${home}/.config/omniwm"
          ]}
        '';

        defaults = {
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
      };
    };
}
