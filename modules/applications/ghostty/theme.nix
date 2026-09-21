{ lib, pkgs, ... }:
let
  theme = import ../../../themes { inherit lib pkgs; };
  inherit (theme) colors;
  terminalColors = with colors; [
    surface1
    red
    green
    yellow
    blue
    pink
    teal
    subtext1
    surface2
    red
    green
    yellow
    blue
    pink
    teal
    subtext0
  ];
in
''
  font-family = ${theme.font.monospace}
  background = ${colors.base}
  foreground = ${colors.text}
  cursor-color = ${theme.accentColor}
  cursor-text = ${colors.crust}
  selection-background = ${colors.surface2}
  selection-foreground = ${colors.text}
''
+ lib.concatStringsSep "\n" (
  lib.imap0 (index: color: "palette = ${toString index}=${color}") terminalColors
)
+ "\n"
