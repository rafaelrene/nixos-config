{ lib, pkgs, ... }:

let
  inherit (import ./themes.nix { inherit lib pkgs; }) claudeTheme codexTheme opencodeTheme;
  agentSource = "/data/code/nixos-config/config/agents";
  inherit (import ./links.nix { inherit lib; })
    rules
    settings
    skillDirectories
    skillLinks
    ;
  agentLinks =
    rules
    // settings
    // skillLinks
    // {
      ".local/share/codex/config.toml" = "codex/config.toml";
    };
  agentManifest = pkgs.writeText "agent-links.json" (
    builtins.toJSON {
      links = agentLinks;
      inherit skillDirectories;
    }
  );
  profile = "/home/raf/.local/state/nix/profiles/llm-agents";
  mkAgentWrapper = name: import ./wrapper.nix { inherit pkgs profile name; };
  updateAgents = import ./update.nix {
    inherit pkgs profile;
  };
in
{
  environment.variables = {
    CODEX_HOME = "$HOME/.local/share/codex";
    CLAUDE_CONFIG_DIR = "$HOME/.local/share/claude";
  };
  environment.systemPackages = [
    updateAgents
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
