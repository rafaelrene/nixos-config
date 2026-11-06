{ config, lib, ... }:
let
  inherit (config) features;
in
{
  options.features.t3code.theme = lib.mkOption {
    type = lib.types.functionTo lib.types.str;
    description = "Generate the T3 Code theme JSON.";
  };

  config.features.t3code.theme =
    { lib, pkgs }:
    let
      theme = features.theme { inherit lib pkgs; };
      colors = lib.mapAttrs (_: color: "#${color}") theme.colors;
      foreground = "#efedf6";
      mutedForeground = "#8f8e9a";
      themeJSON = builtins.toJSON {
        # Also accept this file in the desktop's native custom-theme importer.
        version = 1;
        # A separate managed ID avoids shadowing by older client-local imports.
        id = "workstation";
        inherit (theme) name;
        appearance = if theme.dark then "dark" else "light";
        canvas = colors.base;
        accent = "#${theme.accentColor}";
        colors = {
          # Match Proserpina's imported palette, including its app-specific shades.
          canvas = colors.base;
          chrome = colors.base;
          toolbar = colors.base;
          toolbarForeground = foreground;
          toolbarBorder = "#44414d";
          toolbarControl = "#37353d";
          toolbarControlForeground = foreground;
          toolbarControlHover = "#44414c";
          surface = colors.mantle;
          surfaceRaised = colors.mantle;
          surfaceOverlay = colors.base;
          inherit (colors) text;
          textMuted = colors.text;
          border = colors.surface2;
          input = colors.base;
          focus = "#${theme.accentColor}";
          accent = "#${theme.accentColor}";
          accentForeground = colors.crust;
          secondary = "#3a3644";
          secondaryForeground = foreground;
          muted = "#2f2d36";
          inherit mutedForeground;
          placeholder = mutedForeground;
          secondaryLabel = mutedForeground;
          iconMuted = mutedForeground;
          error = colors.red;
          errorForeground = "#ff6467";
          errorSurface = "#412432";
          warning = colors.peach;
          warningForeground = "#ffb900";
          warningSurface = "#423227";
          update = "#413956";
          updateForeground = foreground;
          updateSurface = "#444050";
          accentSurface = colors.surface0;
          accentSurfaceForeground = foreground;
          messageSurface = "#4a4557";
          messageForeground = foreground;
          messageAction = "#${theme.accentColor}";
          messageActionForeground = colors.crust;
          messageActionHover = "#785166";
          codeBackground = colors.mantle;
          codeForeground = foreground;
          sidebar = colors.mantle;
          sidebarForeground = colors.text;
          sidebarMutedForeground = "#9b99a2";
          sidebarControlSurface = "#393740";
          sidebarRowHover = "#252535";
          sidebarRowActive = colors.surface0;
          sidebarRowSelected = colors.surface0;
          sidebarBorder = colors.mantle;
          terminalBackground = colors.base;
          terminalForeground = colors.text;
          terminalCursor = colors.rosewater;
          terminalSelection = colors.surface2;
          terminalScrollbar = "#3b3d4f";
          terminalScrollbarHover = "#706e75";
        };
      };
    in
    themeJSON;
}
