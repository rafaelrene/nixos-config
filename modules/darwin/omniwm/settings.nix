{ lib, pkgs }:
let
  # Complete defaults from OmniWM v0.7.1's SettingsExport/CanonicalTOMLConfig.
  # Its strict schema requires every action, including unassigned hotkeys.
  defaults = builtins.fromJSON (builtins.readFile ./defaults.json);
  theme = import ../../../themes { inherit lib pkgs; };
  color = hex: {
    red = lib.fromHexString (builtins.substring 0 2 hex) / 255.0;
    green = lib.fromHexString (builtins.substring 2 2 hex) / 255.0;
    blue = lib.fromHexString (builtins.substring 4 2 hex) / 255.0;
    alpha = 1.0;
  };
  # default.nix remaps Caps Lock to Right Control. The built-in keyboard has no
  # Right Control, so these side-specific chords only fire from Caps Lock.
  caps = "Right Control";
  bindings = {
    "focus.left" = "${caps}+Left Arrow";
    "focus.right" = "${caps}+Right Arrow";
    # Niri's focus-window-or-workspace: move within the column, then continue
    # to the adjacent workspace at its edge.
    "focusWindowOrWorkspaceUp" = "${caps}+Up Arrow";
    "focusWindowOrWorkspaceDown" = "${caps}+Down Arrow";
    "moveColumn.left" = "${caps}+Shift+Left Arrow";
    "moveColumn.right" = "${caps}+Shift+Right Arrow";
    "moveWindowUpOrToWorkspaceUp" = "${caps}+Shift+Up Arrow";
    "moveWindowDownOrToWorkspaceDown" = "${caps}+Shift+Down Arrow";
    "switchWorkspace.previous" = "${caps}+PageUp";
    "switchWorkspace.next" = "${caps}+PageDown";
    "moveColumnToWorkspaceUp" = "${caps}+Shift+PageUp";
    "moveColumnToWorkspaceDown" = "${caps}+Shift+PageDown";
    "toggleOverview" = "${caps}+O";
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
  # OmniWM's own Caps Lock trigger stays off; default.nix remaps the key.
  general = {
    updateChecksEnabled = false;
    ipcEnabled = true;
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
  # and overlays window tops only while Caps Lock (or Control) is held, so
  # windows keep the full height.
  statusBar.showWorkspaceName = true;
  workspaceBar = {
    position = "belowMenuBar";
    revealModifier = "control";
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
}
