{
  config,
  lib,
  pkgs,
  ...
}:
let
  home = config.users.users.${config.system.primaryUser}.home;
  source = "${config.workstation.checkout}/config/agents";
  profile = "${home}/.local/state/nix/profiles/llm-agents";
  updater = import ../development/agents/update.nix {
    inherit pkgs profile;
    # Current Nix requires an explicit flag to select every profile entry.
    upgradeAll = true;
  };
  inherit (import ../development/agents/themes.nix { inherit lib pkgs; })
    claudeTheme
    codexTheme
    opencodeTheme
    ;
  skills = lib.attrNames (
    lib.filterAttrs (
      name: type:
      type == "directory" && builtins.pathExists (../../config/agents/skills + "/${name}/SKILL.md")
    ) (builtins.readDir ../../config/agents/skills)
  );
  skillDirectories = [
    ".local/share/codex/skills"
    ".local/share/claude/skills"
    ".local/share/pi/agent/skills"
    ".config/opencode/skills"
  ];
  rules = {
    ".local/share/codex/AGENTS.md" = "AGENTS.md";
    ".local/share/claude/AGENTS.md" = "AGENTS.md";
    ".local/share/claude/CLAUDE.md" = "CLAUDE.md";
    ".local/share/pi/agent/AGENTS.md" = "AGENTS.md";
    ".config/opencode/AGENTS.md" = "AGENTS.md";
  };
  skillLinks = lib.listToAttrs (
    lib.concatMap (
      directory:
      lib.mapAttrsToList
        (name: target: {
          name = "${directory}/${name}";
          value = target;
        })
        (
          (lib.genAttrs skills (name: "${source}/skills/${name}"))
          // {
            create-web-app = "${config.workstation.checkout}/modules/darwin/skills/create-web-app";
          }
        )
    ) skillDirectories
  );
in
{
  environment = {
    systemPackages = [
      updater
    ]
    ++
      map
        (
          name:
          import ../development/agents/wrapper.nix {
            inherit pkgs profile name;
            installCommand = "update-llm-agents";
          }
        )
        [
          "claude"
          "codex"
          "opencode"
        ];
    variables = {
      CODEX_HOME = "${home}/.local/share/codex";
      CLAUDE_CONFIG_DIR = "${home}/.local/share/claude";
      PI_CODING_AGENT_DIR = "${home}/.local/share/pi/agent";
    };
    systemPath = [ "${profile}/bin" ];
  };

  # When these legacy homes exist, XDG paths alias them. No credentials,
  # sessions, or local settings are copied, moved, or put in the Nix store.
  workstation = {
    stateAliases = {
      ".local/share/codex" = ".codex";
      ".local/share/claude" = ".claude";
      ".local/share/pi/agent" = ".pi/agent";
    };
    links =
      lib.mapAttrs (_: path: "${source}/${path}") rules
      // skillLinks
      // {
        ".local/share/codex/themes/workstation.tmTheme" = toString codexTheme;
        ".local/share/claude/settings.json" = lib.mkDefault "${source}/claude/settings.json";
        ".local/share/claude/themes/workstation.json" = toString claudeTheme;
        ".config/opencode/opencode.jsonc" = "${source}/opencode/opencode.jsonc";
        ".config/opencode/tui.json" = "${source}/opencode/tui.json";
        ".config/opencode/themes/workstation.json" = toString opencodeTheme;
      };
    legacyLinks =
      lib.mapAttrs (_: path: "/roles/agents/files/${path}") rules
      // lib.mapAttrs (_: path: "/roles/agents/files/skills/${baseNameOf path}") skillLinks
      // {
        ".config/opencode/opencode.jsonc" = "/roles/agents/files/agent_configs/opencode/opencode.jsonc";
        ".config/opencode/tui.json" = "/roles/agents/files/agent_configs/opencode/tui.json";
      };

  };

  launchd.user.agents.llm-agents-update = {
    environment.NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    serviceConfig = {
      ProgramArguments = [ "${updater}/bin/update-llm-agents" ];
      RunAtLoad = true;
      # First activation reloads the Nix daemon after starting user services.
      KeepAlive.SuccessfulExit = false;
      ThrottleInterval = 300;
      StartCalendarInterval = [
        {
          Hour = 4;
          Minute = 30;
        }
      ];
      ProcessType = "Background";
      StandardOutPath = "${home}/.local/state/nix-darwin/agents-update.log";
      StandardErrorPath = "${home}/.local/state/nix-darwin/agents-update.log";
    };
  };
}
