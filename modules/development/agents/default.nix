{ lib, pkgs, ... }:

let
  theme = import ../../../themes { inherit lib pkgs; };
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
  opencodeTheme = pkgs.writeText "opencode-workstation.json" (
    builtins.toJSON {
      "$schema" = "https://opencode.ai/theme.json";
      theme = {
        primary = "#${theme.accentColor}";
        secondary = colors.lavender;
        accent = "#${theme.accentColor}";
        error = colors.red;
        warning = colors.yellow;
        success = colors.green;
        info = colors.teal;
        inherit (colors) text;
        textMuted = colors.overlay2;
        background = colors.base;
        backgroundPanel = colors.mantle;
        backgroundElement = colors.crust;
        border = colors.surface0;
        borderActive = "#${theme.accentColor}";
        borderSubtle = colors.surface2;
        diffAdded = colors.green;
        diffRemoved = colors.red;
        diffContext = colors.overlay2;
        diffHunkHeader = colors.peach;
        diffHighlightAdded = colors.green;
        diffHighlightRemoved = colors.red;
        diffAddedBg = "#${theme.diff.added}";
        diffRemovedBg = "#${theme.diff.removed}";
        diffContextBg = colors.mantle;
        diffLineNumber = colors.overlay2;
        diffAddedLineNumberBg = colors.mantle;
        diffRemovedLineNumberBg = colors.mantle;
        markdownText = colors.text;
        markdownHeading = "#${theme.accentColor}";
        markdownLink = colors.blue;
        markdownLinkText = colors.sky;
        markdownCode = colors.green;
        markdownBlockQuote = colors.yellow;
        markdownEmph = colors.yellow;
        markdownStrong = colors.peach;
        markdownHorizontalRule = colors.subtext0;
        markdownListItem = colors.blue;
        markdownListEnumeration = colors.sky;
        markdownImage = colors.blue;
        markdownImageText = colors.sky;
        markdownCodeBlock = colors.text;
        syntaxComment = colors.overlay2;
        syntaxKeyword = colors.mauve;
        syntaxFunction = colors.blue;
        syntaxVariable = colors.red;
        syntaxString = colors.green;
        syntaxNumber = colors.peach;
        syntaxType = colors.yellow;
        syntaxOperator = colors.sky;
        syntaxPunctuation = colors.text;
      };
    }
  );
  agentSource = "/data/code/nixos-config/config/agents";
  skillDirectories = [
    ".local/share/codex/skills"
    ".local/share/claude/skills"
    ".config/opencode/skills"
  ];
  skillNames = lib.attrNames (
    lib.filterAttrs (
      name: type:
      type == "directory" && builtins.pathExists (../../../config/agents/skills + "/${name}/SKILL.md")
    ) (builtins.readDir ../../../config/agents/skills)
  );
  agentLinks = {
    ".local/share/codex/AGENTS.md" = "AGENTS.md";
    ".local/share/codex/config.toml" = "codex/config.toml";
    ".local/share/claude/AGENTS.md" = "AGENTS.md";
    ".local/share/claude/CLAUDE.md" = "CLAUDE.md";
    ".local/share/claude/settings.json" = "claude/settings.json";
    ".config/opencode/AGENTS.md" = "AGENTS.md";
    ".config/opencode/opencode.jsonc" = "opencode/opencode.jsonc";
    ".config/opencode/tui.json" = "opencode/tui.json";
  }
  // lib.listToAttrs (
    lib.concatMap (
      directory:
      map (name: {
        name = "${directory}/${name}";
        value = "skills/${name}";
      }) skillNames
    ) skillDirectories
  );
  agentManifest = pkgs.writeText "agent-links.json" (
    builtins.toJSON {
      links = agentLinks;
      inherit skillDirectories;
      # Only these original settings may be backed up and replaced on first
      # activation. Newer edits or unrelated destination files cause an error.
      previousSettings = {
        ".local/share/codex/config.toml" =
          "c5716d9c416be824025fe723650d7c9d00957b57b98e3029e85409e494bcc7fb";
        ".local/share/claude/settings.json" =
          "27dafb2742d0da69a49cc8d206fc9cc429feff09cc3738addcf590d9c4358f97";
      };
    }
  );
  profile = "/home/raf/.local/state/nix/profiles/llm-agents";
  flake = "github:numtide/llm-agents.nix";
  mkAgentWrapper =
    name:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.coreutils
        pkgs.devenv
      ];
      text = ''
        real="${profile}/bin/${name}"
        if ! test -x "$real"; then
          echo "${name} is not installed yet. Run: systemctl --user start llm-agents-update.service" >&2
          exit 1
        fi

        dir="$PWD"
        project=""
        while true; do
          if test -e "$dir/devenv.nix" || test -e "$dir/devenv.yaml"; then
            project="$dir"
            break
          fi
          if test "$dir" = /; then
            break
          fi
          dir="$(dirname "$dir")"
        done

        if test -n "$project" && test "''${DEVENV_ROOT:-}" != "$project"; then
          cd "$project"
          exec devenv shell -- "$real" "$@"
        fi

        exec "$real" "$@"
      '';
    };
  updateAgents = pkgs.writeShellApplication {
    name = "update-llm-agents";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.nix
    ];
    text = ''
      mkdir -p "$(dirname "${profile}")"
      if test -e "${profile}/manifest.json"; then
        nix profile upgrade --profile "${profile}" --refresh --no-accept-flake-config '.*'
      else
        nix profile install --profile "${profile}" --no-accept-flake-config \
          "${flake}#codex" \
          "${flake}#claude-code" \
          "${flake}#opencode"
      fi
    '';
  };
in
{
  environment.variables = {
    CODEX_HOME = "$HOME/.local/share/codex";
    CLAUDE_CONFIG_DIR = "$HOME/.local/share/claude";
  };
  environment.systemPackages = [
    pkgs.coreutils
    pkgs.systemd
    (mkAgentWrapper "claude")
    (mkAgentWrapper "codex")
    (mkAgentWrapper "opencode")
  ];

  # NixOS runs this as the user on login and every system switch. Keep links
  # writable into the checkout, and reconcile them without touching runtime data.
  system.userActivationScripts.agentLinks = ''
    if [ "$(${pkgs.coreutils}/bin/id -un)" = raf ]; then
      ${pkgs.python3}/bin/python ${./agent-links.py} \
        --home /home/raf --source ${agentSource} --manifest ${agentManifest}
    fi
  '';

  systemd = {
    tmpfiles.rules = [
      "d /home/raf/.local/share/claude/themes 0700 raf raf - -"
      "L+ /home/raf/.local/share/claude/themes/workstation.json - - - - ${claudeTheme}"
      "d /home/raf/.local/share/codex/themes 0700 raf raf - -"
      "L+ /home/raf/.local/share/codex/themes/workstation.tmTheme - - - - ${codexTheme}"
      "d /home/raf/.config/opencode/themes 0700 raf raf - -"
      "L+ /home/raf/.config/opencode/themes/workstation.json - - - - ${opencodeTheme}"
      "r /home/raf/.local/bin/agent-notify - - - - -"
      "r /home/raf/.local/share/codex/hooks.json - - - - -"
      "r /home/raf/.local/share/codex/hooks/notification.sh - - - - -"
      "r /home/raf/.local/share/claude/hooks/notification.sh - - - - -"
      "r /home/raf/.config/opencode/plugins/notification.ts - - - - -"
    ]
    ++ map (directory: "d /home/raf/${directory} 0700 raf raf - -") (
      [
        ".local/share/codex"
        ".local/share/claude"
        ".config/opencode"
      ]
      ++ skillDirectories
    );

    user = {
      services.llm-agents-update = {
        description = "Update the independent LLM agent profile";
        unitConfig.ConditionUser = "raf";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe updateAgents;
          TimeoutStartSec = "4h";
        };
      };

      timers.llm-agents-update = {
        description = "Update LLM agents daily";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "5m";
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
      };
    };
  };
}
