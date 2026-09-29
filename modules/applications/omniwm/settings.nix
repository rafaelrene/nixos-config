{ config, lib, ... }:
{
  options.features.omniwm.settings = lib.mkOption {
    type = lib.types.functionTo lib.types.attrs;
    description = "Create OmniWM settings from shared styling and application defaults.";
  };
  config.features.omniwm.settings =
    { lib, pkgs }:
    let
      # OmniWM v0.7.3 defaults, with app rules declared below instead.
      # Its strict schema requires every action, including unassigned hotkeys.
      defaults = builtins.fromJSON (builtins.readFile ./defaults.json);
      theme = config.features.theme { inherit lib pkgs; };
      color = hex: {
        red = lib.fromHexString (builtins.substring 0 2 hex) / 255.0;
        green = lib.fromHexString (builtins.substring 2 2 hex) / 255.0;
        blue = lib.fromHexString (builtins.substring 4 2 hex) / 255.0;
        alpha = 1.0;
      };
      # default.nix maps Caps Lock to F18, which OmniWM uses as Hyper. Exclude Shift
      # so Caps+Shift actions stay distinct, and leave plain Control to apps.
      caps = "Hyper";
      bindings = {
        "focus.left" = "Option+Left Arrow";
        "focus.right" = "Option+Right Arrow";
        # Niri's focus-window-or-workspace: move within the column, then continue
        # to the adjacent workspace at its edge. Vertical arrows are reversed
        # for both focus and movement: Down acts upward, Up acts downward.
        "focusWindowOrWorkspaceUp" = "Option+Down Arrow";
        "focusWindowOrWorkspaceDown" = "Option+Up Arrow";
        "moveColumn.left" = "Option+Shift+Left Arrow";
        "moveColumn.right" = "Option+Shift+Right Arrow";
        "moveWindowUpOrToWorkspaceUp" = "Option+Shift+Down Arrow";
        "moveWindowDownOrToWorkspaceDown" = "Option+Shift+Up Arrow";
        "switchWorkspace.previous" = "${caps}+PageUp";
        "switchWorkspace.next" = "${caps}+PageDown";
        "moveColumnToWorkspaceUp" = "${caps}+Shift+PageUp";
        "moveColumnToWorkspaceDown" = "${caps}+Shift+PageDown";
        "toggleOverview" = "Option+0";
        "closeFocusedWindow" = "${caps}+Q";
        "cycleSizeForward" = "${caps}+R";
        "cycleSizeBackward" = "${caps}+Shift+R";
        "setContainerPrimarySpan.decrease10Percent" = "${caps}+-";
        "setContainerPrimarySpan.increase10Percent" = "${caps}+=";
        "toggleContainerFullPrimarySpan" = "${caps}+F";
        "toggleFullscreen" = "${caps}+Shift+F";
        "toggleFocusedWindowFloating" = "${caps}+V";
        "consumeWindowIntoColumn" = "${caps}+[";
        "expelWindowFromColumn" = "${caps}+]";
      }
      # OmniWM's numbered workspace actions stop at 9.
      // builtins.listToAttrs (
        lib.concatMap (index: [
          {
            name = "switchWorkspace.${toString index}";
            value = "Option+${toString (index + 1)}";
          }
          {
            name = "moveColumnToWorkspace.${toString index}";
            value = "Option+Shift+${toString (index + 1)}";
          }
        ]) (lib.range 0 8)
      );
    in
    assert lib.assertMsg (builtins.all (id: builtins.elem id (map (entry: entry.id) defaults.hotkeys)) (
      builtins.attrNames bindings
    )) "An OmniWM shortcut refers to an unknown action in defaults.json";
    lib.recursiveUpdate defaults {
      appRules = [
        {
          id = "7876C9EF-437E-4D4F-9C27-B1B02F4AABCE";
          bundleId = "com.mitchellh.ghostty";
          assignToWorkspace = "1";
        }
        {
          id = "80AA774B-5F90-44B7-AF27-78DF0AF28D1E";
          # Match the running client, not the local.proserpina launcher.
          bundleId = "com.t3tools.t3code";
          assignToWorkspace = "1";
        }
        {
          id = "69862ED8-4A20-4AC1-90D5-E96B66E867F4";
          bundleId = "net.imput.helium";
          assignToWorkspace = "1";
        }
        {
          id = "C0CC8269-974E-499D-A312-334F67477AD3";
          bundleId = "com.tinyspeck.slackmacgap";
          assignToWorkspace = "1";
        }
        {
          id = "AE78B053-327D-4B1F-A912-81D85E339068";
          bundleId = "com.microsoft.teams2";
          assignToWorkspace = "1";
        }
        {
          id = "F500EA2C-7CC3-42AC-ABC8-3954D2019280";
          bundleId = "net.whatsapp.WhatsApp";
          assignToWorkspace = "8";
        }
        {
          id = "CB1220FD-30D8-4C7D-8EAE-56B6C8F86F7D";
          bundleId = "com.viber.osx";
          assignToWorkspace = "8";
        }
        {
          id = "3F045253-BBA1-418F-B2D4-CBBF0CD7BBD2";
          bundleId = "org.whispersystems.signal-desktop";
          assignToWorkspace = "8";
        }
        {
          id = "1CF39647-F30D-4E76-9686-79B551F1B094";
          bundleId = "app.zen-browser.zen";
          assignToWorkspace = "9";
        }
        {
          id = "13B3566D-C476-4E9C-8AAF-C0DFAFE25EE7";
          bundleId = "com.apple.systempreferences";
          layout = "tile";
          initialContainerPrimarySpan = 0.5;
        }
      ];
      general = {
        animationsEnabled = false;
        updateChecksEnabled = false;
        ipcEnabled = true;
        systemHyperTrigger = "F18";
        hyperKeyModifiers = "Control+Option+Command";
      };
      gaps = {
        size = 2.0;
        outer = {
          left = 2.0;
          right = 2.0;
          top = 2.0;
          bottom = 2.0;
        };
      };
      niri = {
        infiniteLoop = true;
        visibleContainerCount = 1;
        centerFocusedColumn = "onOverflow";
        singleWindowFit = "container_primary_span";
        defaultContainerPrimarySpan = 1.0;
        containerPrimarySpanPresets = [
          0.33333
          0.5
          0.66667
          1.0
        ];
      };
      borders = {
        width = 1.0;
        color = color theme.accentColor;
      };
      overview.backdrop = color theme.colors.base;
      # The menu bar item names the current workspace. The full bar stays hidden
      # and overlays window tops only while Option is held, so
      # windows keep the full height.
      statusBar.showWorkspaceName = true;
      workspaceBar = {
        deduplicateAppIcons = true;
        hideEmptyWorkspaces = true;
        position = "belowMenuBar";
        revealModifier = "option";
        showFloatingWindows = true;
        accentColor = color theme.accentColor;
        textColor = color theme.colors.text;
      };
      gestures = {
        workspaceSwipeEnabled = true;
        overviewGestureEnabled = true;
        overviewGestureFingerCount = 4;
        # Mouse modifiers cannot be side-specific, and Control+click is right-click.
        mouseMoveModifierKey = "optionCommand";
        mouseResizeModifierKey = "optionCommand";
      };
      # Existing Ghostty, Raycast, and Thaw retain their roles.
      quakeTerminal.enabled = false;
      hiddenBar.enabled = false;
      hotkeys = map (entry: {
        inherit (entry) id;
        binding = bindings.${entry.id} or "Unassigned";
      }) defaults.hotkeys;
      workspaces = map (
        workspace:
        workspace
        // {
          displayName = if workspace.name == "1" then "Work" else workspace.name;
          monitorAssignment.type = "main";
          layoutType = "niri";
        }
      ) defaults.workspaces;
    };
}
