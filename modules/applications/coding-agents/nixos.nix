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
      agentSource = features.sources.checkoutPath {
        inherit (config.workstation) checkout;
        source = features.coding-agents.source;
      };
      inherit (features.coding-agents.links { inherit lib; })
        rules
        skillDirectories
        skillLinks
        ;
      agentLinks = rules // skillLinks;
      agentManifest = pkgs.writeText "agent-links.json" (
        builtins.toJSON {
          links = agentLinks;
          inherit skillDirectories;
        }
      );
      profile = "${home}/.local/state/nix/profiles/llm-agents";
      agents = features.coding-agents.packages {
        inherit pkgs profile;
        hostname = config.networking.hostName;
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
        tmpfiles.rules = map (
          directory: "d ${home}/${directory} 0700 ${user} ${group} - -"
        ) skillDirectories;

        user = {
          services = lib.concatMapAttrs (name: updater: {
            "${name}-update" = {
              description = "Stage the latest ${name} release";
              unitConfig.ConditionUser = user;
              serviceConfig = {
                Type = "oneshot";
                ExecStart = "${lib.getExe updater} --stage";
                TimeoutStartSec = "4h";
                Restart = "on-failure";
                RestartSec = "5m";
              };
            };
            "${name}-activate" = {
              description = "Activate the staged ${name} release";
              unitConfig.ConditionUser = user;
              serviceConfig = {
                Type = "oneshot";
                ExecStart = "${lib.getExe updater} --activate";
                TimeoutStartSec = "4h";
              };
            };
          }) agents.updaters;
          timers = lib.concatMapAttrs (name: _: {
            "${name}-update" = {
              description = "Check for ${name} releases every three hours";
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnStartupSec = "1s";
                OnCalendar = "*-*-* 00/3:00:00";
                Persistent = true;
              };
            };
            "${name}-activate" = {
              description = "Activate ${name} daily at 04:00";
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = "*-*-* 04:00:00";
                Persistent = true;
              };
            };
          }) agents.updaters;
        };
      };
    };
}
