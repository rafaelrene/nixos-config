{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.darwin.desktop-session =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.workstation.desktop;
      startupApplications =
        cfg.backgroundApplications ++ lib.optionals cfg.loginUtilities cfg.loginApplications;
      allApplications = cfg.backgroundApplications ++ cfg.loginApplications;
      runtimes = features.shell.runtimes { inherit pkgs; };
      home = config.users.users.${config.system.primaryUser}.home;
      settings = pkgs.writeText "default-applications.duti" cfg.defaultApplications;
      setup = features.shell.darwinApplication {
        inherit pkgs;
        name = "setup-desktop-session";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          ${lib.optionalString (allApplications != [ ]) ''
            if ! timeout 12 /usr/bin/osascript - ${
              lib.escapeShellArgs (map (name: "/Applications/Nix Apps/${name}.app") allApplications)
            } <<'APPLESCRIPT'
            on run managedApplications
              tell application "System Events"
                repeat with managedApplication in managedApplications
                  delete (every login item whose path is (managedApplication as text))
                end repeat
              end tell
            end run
            APPLESCRIPT
            then
              printf >&2 'Login-item cleanup needs System Events approval; continuing desktop setup.\n'
            fi
          ''}
          ${lib.optionalString (cfg.defaultApplications != "") ''
            requests="$HOME/Library/Application Support/nix-desktop/default-app-requests"
            mkdir -p "$(dirname "$requests")"
            touch "$requests"
            for app in '/Applications/Nix Apps/'*.app; do
              /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app"
            done
            while read -r bundle type role; do
              [[ -n "$bundle" ]] || continue
              current=$(${runtimes.directory}/duti -d "$type" 2>/dev/null || true)
              [[ "''${current,,}" != "''${bundle,,}" ]] || continue
              request="$bundle $type $role"
              /usr/bin/grep -Fqx -- "$request" "$requests" && continue
              if /usr/sbin/ioreg -l -n Root -d1 | /usr/bin/grep -q '"CGSSessionScreenIsLocked"=Yes'; then
                continue
              fi
              if [[ -n "$role" ]]; then
                ${runtimes.directory}/duti -s "$bundle" "$type" "$role"
              else
                ${runtimes.directory}/duti -s "$bundle" "$type"
              fi
              printf '%s\n' "$request" >> "$requests"
              current=$(${runtimes.directory}/duti -d "$type" 2>/dev/null || true)
              if [[ "''${current,,}" != "''${bundle,,}" ]]; then
                printf >&2 'macOS has not applied %s for %s; confirm any system default-app dialog.\n' "$bundle" "$type"
              fi
            done < ${settings}
          ''}
          ${lib.optionalString (cfg.wallpaper != null) ''
            ${runtimes.directory}/desktoppr ${lib.escapeShellArg cfg.wallpaper}
          ''}
        '';
      };
      launch = features.shell.darwinApplication {
        inherit pkgs;
        name = "start-login-application";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          name=$1
          /usr/bin/open -g -j ${
            lib.escapeShellArgs (
              lib.concatLists (
                lib.mapAttrsToList (key: value: [
                  "--env"
                  "${key}=${toString value}"
                ]) config.launchd.user.envVariables
              )
            )
          } "/Applications/Nix Apps/$name.app"
          ${lib.optionalString (!cfg.loginUtilities) ''
            if ! timeout 12 /usr/bin/osascript - "$name" <<'APPLESCRIPT'
            on run applicationNames
              tell application "System Events"
                repeat 50 times
                  if exists application process (item 1 of applicationNames) then
                    tell application process (item 1 of applicationNames)
                      if exists window 1 then
                        set visible to false
                        return
                      end if
                    end tell
                  end if
                  delay 0.2
                end repeat
              end tell
            end run
            APPLESCRIPT
            then
              printf >&2 'Could not hide %s; the application is running. Complete workstation-setup approvals.\n' "$name"
            fi
          ''}
        '';
      };
    in
    {
      options.workstation.desktop = {
        defaultApplications = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Native duti associations contributed by selected applications.";
        };
        wallpaper = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Wallpaper image or directory applied to connected displays.";
        };
        loginApplications = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Nix application bundle names launched hidden at login, with Nix owning their login items.";
        };
        backgroundApplications = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Sync and connectivity applications needed without an interactive desktop.";
        };
        loginUtilities = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Start desktop utilities automatically instead of leaving them on demand.";
        };
      };
      config = {
        system.build.desktopLoginLauncher = launch;
        environment.systemPackages =
          lib.optional (cfg.defaultApplications != "") pkgs.duti
          ++ lib.optional (cfg.wallpaper != null) pkgs.desktoppr;
        launchd.user.agents = {
          desktop-session.serviceConfig = {
            ProgramArguments = [ (lib.getExe setup) ];
            RunAtLoad = true;
            LimitLoadToSessionType = "Aqua";
            StandardOutPath = "${home}/Library/Logs/nix-desktop-session.log";
            StandardErrorPath = "${home}/Library/Logs/nix-desktop-session.log";
          };
        }
        // lib.listToAttrs (
          map (name: {
            name = "login-${lib.toLower (lib.replaceStrings [ " " ] [ "-" ] name)}";
            value.serviceConfig = {
              ProgramArguments = [
                (lib.getExe launch)
                name
              ];
              RunAtLoad = true;
              KeepAlive.SuccessfulExit = false;
              ThrottleInterval = 10;
              LimitLoadToSessionType = "Aqua";
            };
          }) startupApplications
        );
        system.activationScripts.postActivation.text = lib.mkAfter ''
          desktop_uid=$(/usr/bin/id -u ${lib.escapeShellArg config.system.primaryUser})
          if /bin/launchctl print "gui/$desktop_uid" >/dev/null 2>&1; then
            /bin/launchctl kickstart "gui/$desktop_uid/${config.launchd.user.agents.desktop-session.serviceConfig.Label}"
          fi
        '';
      };
    };
}
