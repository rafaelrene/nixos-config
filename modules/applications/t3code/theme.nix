{ lib, pkgs }:
let
  theme = import ../../../themes { inherit lib pkgs; };
  colors = lib.mapAttrs (_: color: "#${color}") theme.colors;
  themeJSON = builtins.toJSON {
    # Also accept this file in the desktop's native custom-theme importer.
    version = 1;
    id = "othinus";
    inherit (theme) name;
    appearance = if theme.dark then "dark" else "light";
    canvas = colors.base;
    accent = "#${theme.accentColor}";
    colors = {
      canvas = colors.base;
      chrome = colors.mantle;
      toolbar = colors.mantle;
      toolbarForeground = colors.text;
      toolbarBorder = colors.surface0;
      toolbarControl = colors.surface0;
      toolbarControlForeground = colors.text;
      toolbarControlHover = colors.surface1;
      surface = colors.base;
      surfaceRaised = colors.surface0;
      surfaceOverlay = colors.surface1;
      inherit (colors) text;
      textMuted = colors.subtext0;
      border = colors.surface1;
      input = colors.mantle;
      focus = "#${theme.accentColor}";
      accent = "#${theme.accentColor}";
      accentForeground = colors.crust;
      secondary = colors.surface0;
      secondaryForeground = colors.text;
      muted = colors.surface0;
      mutedForeground = colors.subtext0;
      placeholder = colors.overlay1;
      secondaryLabel = colors.subtext1;
      iconMuted = colors.overlay2;
      error = colors.red;
      errorForeground = colors.crust;
      errorSurface = colors.surface0;
      warning = colors.yellow;
      warningForeground = colors.crust;
      warningSurface = colors.surface0;
      update = colors.green;
      updateForeground = colors.crust;
      updateSurface = colors.surface0;
      accentSurface = colors.surface0;
      accentSurfaceForeground = "#${theme.accentColor}";
      messageSurface = colors.mantle;
      messageForeground = colors.text;
      messageAction = colors.surface0;
      messageActionForeground = colors.text;
      messageActionHover = colors.surface1;
      codeBackground = colors.mantle;
      codeForeground = colors.text;
      sidebar = colors.mantle;
      sidebarForeground = colors.text;
      sidebarMutedForeground = colors.subtext0;
      sidebarControlSurface = colors.surface0;
      sidebarRowHover = colors.surface0;
      sidebarRowActive = colors.surface1;
      sidebarRowSelected = colors.surface1;
      sidebarBorder = colors.surface0;
      terminalBackground = colors.base;
      terminalForeground = colors.text;
      terminalCursor = "#${theme.accentColor}";
      terminalSelection = colors.surface2;
      terminalScrollbar = colors.surface1;
      terminalScrollbarHover = colors.surface2;
    };
  };
in
themeJSON
