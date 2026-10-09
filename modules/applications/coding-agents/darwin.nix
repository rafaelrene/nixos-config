{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.darwin.coding-agents =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      home = config.users.users.${config.workstation.user}.home;
      source = "${config.workstation.checkout}/config/agents";
      profile = "${home}/.local/state/nix/profiles/llm-agents";
      agents = features.coding-agents.packages {
        inherit pkgs profile;
      };
      inherit (features.coding-agents.themes { inherit lib pkgs; })
        claudeTheme
        codexTheme
        opencodeTheme
        ;
      sharedLinks = features.coding-agents.links {
        inherit lib;
        skillSource = "${source}/skills";
        extraSkills.create-web-app = "${config.workstation.checkout}/modules/applications/webapps/skills/create-web-app";
      };
      inherit (sharedLinks) skillLinks;
    in
    {
      environment = {
        systemPath = [ "${profile}-executables/bin" ];
      };

      # The daemon is ready here; retain installed versions on the first switch.
      system.activationScripts.postActivation.text = ''
        if test -e ${lib.escapeShellArg profile} && ! test -x ${lib.escapeShellArg "${profile}-executables/bin/codex"}; then
          /usr/bin/sudo -H -u ${lib.escapeShellArg config.workstation.user} -- \
            ${agents.updater}/bin/update-llm-agents --migrate
        fi
      '';

      # XDG paths alias existing application homes. No credentials,
      # sessions, or local settings are copied, moved, or put in the Nix store.
      workstation = {
        stateAliases = {
          ".local/share/codex" = ".codex";
          ".local/share/claude" = ".claude";
          # Keep existing Pi data reachable while activation prunes its managed links.
          ".local/share/pi/agent" = ".pi/agent";
        };
        links =
          lib.mapAttrs (_: path: "${source}/${path}") sharedLinks.rules
          // lib.mapAttrs (_: path: "${source}/${path}") sharedLinks.settings
          // skillLinks
          // {
            ".local/share/codex/themes/workstation.tmTheme" = toString codexTheme;
            ".local/share/claude/settings.json" = lib.mkDefault "${source}/claude/settings.json";
            ".local/share/claude/themes/workstation.json" = toString claudeTheme;
            ".config/opencode/themes/workstation.json" = toString opencodeTheme;
          };

      };

      launchd.user.agents.llm-agents-update = {
        environment.NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
        serviceConfig = {
          ProgramArguments = [
            "${agents.updater}/bin/update-llm-agents"
            "--stage"
          ];
          RunAtLoad = true;
          # First activation reloads the Nix daemon after starting user services.
          KeepAlive.SuccessfulExit = false;
          ThrottleInterval = 300;
          StartInterval = 10800;
          ProcessType = "Background";
          StandardOutPath = "${home}/.local/state/nix-darwin/agents-update.log";
          StandardErrorPath = "${home}/.local/state/nix-darwin/agents-update.log";
        };
      };

      launchd.user.agents.llm-agents-activate.serviceConfig = {
        ProgramArguments = [
          "${agents.updater}/bin/update-llm-agents"
          "--activate"
        ];
        StartCalendarInterval = [
          {
            Hour = 4;
            Minute = 0;
          }
        ];
        ProcessType = "Background";
        StandardOutPath = "${home}/.local/state/nix-darwin/agents-activation.log";
        StandardErrorPath = "${home}/.local/state/nix-darwin/agents-activation.log";
      };
    };
}
