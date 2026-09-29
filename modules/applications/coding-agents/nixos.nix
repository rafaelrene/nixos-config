{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.nixos.coding-agents =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      user = config.workstation.user;
      home = config.users.users.${user}.home;
      group = config.users.users.${user}.group;
      inherit (features.coding-agents.themes { inherit lib pkgs; }) claudeTheme codexTheme opencodeTheme;
      agentSource = "${config.workstation.checkout}/config/agents";
      inherit (features.coding-agents.links { inherit lib; })
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
      profile = "${home}/.local/state/nix/profiles/llm-agents";
      agents = features.coding-agents.packages {
        inherit pkgs profile;
      };
    in
    {
      # NixOS runs this as the user on login and every system switch. Keep links
      # writable into the checkout, and reconcile them without touching runtime data.
      system.userActivationScripts.agentLinks = ''
        if [ "$(${pkgs.coreutils}/bin/id -un)" = ${lib.escapeShellArg user} ]; then
          ${pkgs.python3}/bin/python ${./agent-links.py} \
            --home ${lib.escapeShellArg home} --source ${lib.escapeShellArg agentSource} --manifest ${agentManifest}
        fi
      '';

      systemd = {
        tmpfiles.rules = [
          "d ${home}/.local/share/claude/themes 0700 ${user} ${group} - -"
          "L+ ${home}/.local/share/claude/themes/workstation.json - - - - ${claudeTheme}"
          "d ${home}/.local/share/codex/themes 0700 ${user} ${group} - -"
          "L+ ${home}/.local/share/codex/themes/workstation.tmTheme - - - - ${codexTheme}"
          "d ${home}/.config/opencode/themes 0700 ${user} ${group} - -"
          "L+ ${home}/.config/opencode/themes/workstation.json - - - - ${opencodeTheme}"
        ]
        ++ map (directory: "d ${home}/${directory} 0700 ${user} ${group} - -") (
          [
            ".local/share/codex"
            ".local/share/claude"
            ".config/opencode"
          ]
          ++ skillDirectories
        );

        user = {
          services.llm-agents-update = {
            description = "Stage the latest LLM agent releases";
            unitConfig.ConditionUser = user;
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${lib.getExe agents.updater} --stage";
              TimeoutStartSec = "4h";
              Restart = "on-failure";
              RestartSec = "5m";
            };
          };

          timers.llm-agents-update = {
            description = "Check for LLM agent releases every three hours";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnStartupSec = "1s";
              OnCalendar = "*-*-* 00/3:00:00";
              Persistent = true;
            };
          };

          services.llm-agents-activate = {
            description = "Activate the staged LLM agent releases";
            unitConfig.ConditionUser = user;
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${lib.getExe agents.updater} --activate";
              TimeoutStartSec = "4h";
            };
          };

          timers.llm-agents-activate = {
            description = "Activate LLM agent releases daily at 04:00";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "*-*-* 04:00:00";
              Persistent = true;
            };
          };
        };
      };
    };
}
