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
      source = features.sources.checkoutPath {
        inherit (config.workstation) checkout;
        source = features.coding-agents.source;
      };
      profile = "${home}/.local/state/nix/profiles/llm-agents";
      agents = features.coding-agents.packages {
        inherit pkgs profile;
        hostname = config.networking.hostName;
      };
      inherit (features.coding-agents.themes { inherit lib pkgs; })
        claudeTheme
        codexTheme
        ;
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
          };

      };

      launchd.user.agents = lib.concatMapAttrs (name: updater: {
        "${name}-update" = {
          environment.NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
          serviceConfig = {
            ProgramArguments = [
              (lib.getExe updater)
              "--stage"
            ];
            RunAtLoad = true;
            # Retry this agent without holding up other scheduled updates.
            KeepAlive.SuccessfulExit = false;
            ThrottleInterval = 300;
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
}
