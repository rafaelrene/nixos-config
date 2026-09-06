{ lib, pkgs, ... }:

let
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
    ".local/bin/agent-notify" = "hooks/notification/common.sh";
    ".local/share/codex/AGENTS.md" = "AGENTS.md";
    ".local/share/codex/config.toml" = "codex/config.toml";
    ".local/share/codex/hooks.json" = "codex/hooks.json";
    ".local/share/codex/hooks/notification.sh" = "hooks/notification/codex.sh";
    ".local/share/claude/AGENTS.md" = "AGENTS.md";
    ".local/share/claude/CLAUDE.md" = "CLAUDE.md";
    ".local/share/claude/settings.json" = "claude/settings.json";
    ".local/share/claude/hooks/notification.sh" = "hooks/notification/claude.sh";
    ".config/opencode/AGENTS.md" = "AGENTS.md";
    ".config/opencode/opencode.jsonc" = "opencode/opencode.jsonc";
    ".config/opencode/tui.json" = "opencode/tui.json";
    ".config/opencode/plugins/notification.ts" = "hooks/notification/opencode.ts";
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
    pkgs.libnotify
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
    tmpfiles.rules = map (directory: "d /home/raf/${directory} 0700 raf raf - -") (
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
