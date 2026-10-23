{ config, lib, ... }:
let
  inherit (config) features;
in
{
  options.features.coding-agents.themes = lib.mkOption {
    type = lib.types.functionTo (lib.types.attrsOf lib.types.package);
    description = "Generate the Claude and Codex themes.";
  };

  config.features.coding-agents.themes =
    { lib, pkgs, ... }:

    let
      theme = features.theme { inherit lib pkgs; };
      colors = lib.mapAttrs (_: color: "#${color}") theme.colors;
      claudeTheme = pkgs.writeText "claude-workstation.json" (
        builtins.toJSON {
          inherit (theme) name;
          base = if theme.dark then "dark" else "light";
          overrides = {
            inherit (colors) text;
            claude = "#${theme.accentColor}";
            claudeShimmer = colors.lavender;
            inverseText = colors.crust;
            inactive = colors.subtext0;
            subtle = colors.overlay0;
            suggestion = "#${theme.accentColor}";
            permission = "#${theme.accentColor}";
            remember = colors.lavender;
            success = colors.green;
            error = colors.red;
            warning = colors.yellow;
            merged = colors.mauve;
            promptBorder = "#${theme.accentColor}";
            planMode = colors.blue;
            autoAccept = colors.green;
            bashBorder = colors.peach;
            ide = colors.teal;
            fastMode = colors.yellow;
            diffAdded = "#${theme.diff.added}";
            diffRemoved = "#${theme.diff.removed}";
            diffAddedDimmed = "#${theme.diff.added}";
            diffRemovedDimmed = "#${theme.diff.removed}";
            diffAddedWord = "#${theme.diff.addedEmphasis}";
            diffRemovedWord = "#${theme.diff.removedEmphasis}";
            userMessageBackground = colors.mantle;
            userMessageBackgroundHover = colors.surface0;
            bashMessageBackgroundColor = colors.mantle;
            memoryBackgroundColor = colors.mantle;
            selectionBg = colors.surface2;
            rate_limit_fill = "#${theme.accentColor}";
            rate_limit_empty = colors.surface0;
            briefLabelYou = colors.text;
            briefLabelClaude = "#${theme.accentColor}";
          };
        }
      );
      codexTheme = (pkgs.formats.plist { }).generate "workstation.tmTheme" {
        name = "Workstation";
        settings = [
          {
            settings = {
              background = colors.base;
              foreground = colors.text;
              caret = "#${theme.accentColor}";
              selection = colors.surface2;
              lineHighlight = colors.surface0;
            };
          }
        ]
        ++
          lib.mapAttrsToList
            (scope: foreground: {
              inherit scope;
              settings = { inherit foreground; };
            })
            {
              comment = colors.overlay2;
              string = colors.green;
              "constant.numeric" = colors.peach;
              "constant.language" = colors.peach;
              keyword = colors.mauve;
              storage = colors.mauve;
              "entity.name.function" = colors.blue;
              "support.function" = colors.blue;
              "entity.name.type" = colors.yellow;
              "support.type" = colors.yellow;
              variable = colors.text;
              "variable.parameter" = colors.maroon;
              punctuation = colors.overlay2;
              "markup.heading" = "#${theme.accentColor}";
              "markup.inserted" = colors.green;
              "markup.deleted" = colors.red;
              "markup.changed" = colors.yellow;
              "markup.underline.link" = colors.blue;
            };
      };
    in
    {
      inherit claudeTheme codexTheme;
    };
}
