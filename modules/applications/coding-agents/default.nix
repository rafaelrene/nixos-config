{ config, lib, ... }:
let
  inherit (config) features;
in
{
  flake.modules = lib.genAttrs [ "nixos" "darwin" ] (platform: {
    coding-agents =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        user = config.workstation.user;
        inherit (config.users.users.${user}) home;
        source = features.sources.checkoutPath {
          inherit (config.workstation) checkout;
          source = features.coding-agents.source;
        };
        profile = "${home}/.local/state/nix/profiles/llm-agents";
        agents = features.coding-agents.packages {
          inherit pkgs profile;
          hostname = config.networking.hostName;
        };
        nixos =
          let
            inherit (config.users.users.${user}) group;
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
          in
          {
            # NixOS runs this as the user on login and every system switch. Keep links
            # writable into the checkout, and reconcile them without touching runtime data.
            system.userActivationScripts.agentLinks = ''
              if [ "$(${pkgs.coreutils}/bin/id -un)" = ${lib.escapeShellArg user} ]; then
                ${pkgs.python3}/bin/python ${./agent-links.py} \
                  --home ${lib.escapeShellArg home} --source ${lib.escapeShellArg source} --manifest ${agentManifest}
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
        darwin =
          let
            sharedLinks = features.coding-agents.links {
              inherit lib;
              skillSource = "${source}/skills";
            };
            inherit (sharedLinks) skillLinks;
          in
          {
            environment = {
              systemPath = map (path: "${path}-executables/bin") (lib.attrValues agents.profiles) ++ [
                "${profile}-executables/bin"
              ];
            };

            # XDG paths alias existing application homes. No credentials,
            # sessions, or local settings are copied, moved, or put in the Nix store.
            workstation = {
              stateAliases = {
                # Keep existing Pi data reachable while activation prunes its managed links.
                ".local/share/pi/agent" = ".pi/agent";
              };
              links = lib.mapAttrs (_: path: "${source}/${path}") sharedLinks.rules // skillLinks;
            };

            launchd.user.agents = lib.concatMapAttrs (name: updater: {
              "${name}-update" = {
                environment.NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
                serviceConfig = {
                  ProgramArguments = [
                    (lib.getExe updater)
                    "--stage"
                  ];
                  # Switches load jobs before the Nix daemon is ready. Use the schedule.
                  RunAtLoad = false;
                  StartInterval = 10800;
                  ProcessType = "Background";
                  StandardOutPath = "${home}/.local/state/nix-darwin/${name}-update.log";
                  StandardErrorPath = "${home}/.local/state/nix-darwin/${name}-update.log";
                };
              };
              "${name}-activate".serviceConfig = {
                ProgramArguments = [
                  (lib.getExe updater)
                  "--activate"
                ];
                StartCalendarInterval = [
                  {
                    Hour = 4;
                    Minute = 0;
                  }
                ];
                ProcessType = "Background";
                StandardOutPath = "${home}/.local/state/nix-darwin/${name}-activation.log";
                StandardErrorPath = "${home}/.local/state/nix-darwin/${name}-activation.log";
              };
            }) agents.updaters;
          };
      in
      {
        imports = with (features.modulesFor platform); [
          codex
          claude
          antigravity
        ];
        config = lib.mkMerge [
          {
            system.build = agents.bundles // {
              codexUpdater = agents.updaters.codex;
              claudeUpdater = agents.updaters.claude-code;
              antigravityUpdater = agents.updaters.antigravity-cli;
              # An installed pre-split updater may still stage this output during the first switch.
              llm-agents = features.coding-agents.bundle { inherit pkgs profile; };
            };
            environment.systemPackages = agents.packages;
          }
          (if platform == "nixos" then nixos else darwin)
        ];
      };
  });
}
