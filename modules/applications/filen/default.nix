{
  config,
  inputs,
  withSystem,
  ...
}:
let
  inherit (config) features;
  common =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      user = config.workstation.user;
      home = config.users.users.${user}.home;
      directory = "${home}/.config/filen";
      configuration = "${directory}/rclone.conf";
      # Keep the old WebDAV cache separate, including any pending writes.
      cache = "${home}/.cache/filen-native";
      # ns -u refreshes this input; Filen updates only through Nix rebuilds.
      unstable = withSystem pkgs.stdenv.hostPlatform.system ({ unstable, ... }: unstable);
      rclone = import ./_rclone.nix { inherit (unstable) rclone; };
      desktop = unstable.filen-desktop.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          # Disable every updater entry point, including upstream's E2E path.
          substituteInPlace src/index.ts \
            --replace-fail 'this.updater.initialize()' '// Updates are managed by Nix.'
        '';
      });
      legacy = unstable.filen-cli.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          # The native wrapper owns mounts, including calls with global CLI flags.
          substituteInPlace src/app/app.ts \
            --replace-fail 'import { driveMountingCommand } from "./featureInterfaces/driveMountingInterface"' "" \
            --replace-fail '{ title: "Network drive mounting", features: [driveMountingCommand], visibility: "collapse" },' ""
        '';
        postFixup =
          (old.postFixup or "")
          + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
            # Bun's compiled payload invalidates the original executable signature.
            ${lib.getExe pkgs.rcodesign} sign --code-signature-flags linker-signed "$out/bin/.filen-wrapped"
          '';
      });
      password = features.shell.application {
        inherit pkgs;
        name = "filen-config-password";
        text =
          if pkgs.stdenv.hostPlatform.isDarwin then
            ''
              exec /usr/bin/security find-generic-password \
                -a ${lib.escapeShellArg user} -s filen-rclone -w
            ''
          else
            ''
              exec ${lib.getExe' pkgs.libsecret "secret-tool"} lookup \
                service filen-rclone account ${lib.escapeShellArg user}
            '';
      };
      client = features.shell.application {
        inherit pkgs;
        name = "filen-rclone";
        text = ''
          umask 077
          ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
            # FUSE mounts need NixOS's setuid helper, including outside systemd.
            export PATH="/run/wrappers/bin:$PATH"
          ''}
          exec ${lib.getExe rclone} \
            --config ${lib.escapeShellArg configuration} \
            --password-command ${lib.escapeShellArg (lib.getExe password)} "$@"
        '';
      };
      setup = features.shell.application {
        inherit pkgs;
        name = "filen-setup";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.jq
        ];
        text = ''
          umask 077
          install -d -m 700 ${lib.escapeShellArg directory}
          if ! ${lib.getExe password} >/dev/null 2>&1; then
            if test -e ${lib.escapeShellArg configuration}; then
              echo 'The Filen configuration key is missing or locked. Unlock or restore its OS keyring entry.' >&2
              exit 1
            fi
            key=$(${lib.getExe pkgs.openssl} rand -hex 32)
            ${
              if pkgs.stdenv.hostPlatform.isDarwin then
                ''
                  # security's interactive input keeps the key out of process arguments.
                  printf 'add-generic-password -U -a %s -s filen-rclone -w %s\n' \
                    ${lib.escapeShellArg user} "$key" | /usr/bin/security -i >/dev/null 2>&1
                ''
              else
                ''
                  printf '%s' "$key" | ${lib.getExe' pkgs.libsecret "secret-tool"} store \
                    --label='Filen mount configuration' service filen-rclone account ${lib.escapeShellArg user}
                ''
            }
            if ! stored=$(${lib.getExe password} 2>/dev/null) || [[ "$stored" != "$key" ]]; then
              unset key stored
              echo 'Could not save the Filen configuration key. Unlock the OS keyring and run filen-setup again.' >&2
              exit 1
            fi
            unset key stored
          fi
          if ! test -f ${lib.escapeShellArg configuration}; then
            temporary=$(mktemp ${lib.escapeShellArg "${directory}/.rclone.XXXXXX"})
            trap 'test ! -e "$temporary" || rm -- "$temporary"' EXIT
            ${lib.getExe client} --config "$temporary" config encryption set
            echo 'Create remote FilenNative with storage filen. Use filen export-api-key to obtain its API key.'
            ${lib.getExe client} --config "$temporary" config
            ${lib.getExe client} --config "$temporary" config encryption check
            if ! ${lib.getExe client} --config "$temporary" config dump | jq -e '.FilenNative.type == "filen"' >/dev/null; then
              echo 'FilenNative must use Filen storage.' >&2
              exit 1
            fi
            mv -- "$temporary" ${lib.escapeShellArg configuration}
          else
            exec ${lib.getExe client} config
          fi
        '';
      };
      mount = features.shell.application {
        inherit pkgs;
        name = "filen-mount";
        runtimeInputs = [ pkgs.coreutils ] ++ lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.util-linux;
        text = ''
          umask 077
          if ! test -f ${lib.escapeShellArg configuration}; then
            echo 'Run filen-setup once to configure the native Filen remote.' >&2
            exit 0
          fi
          if (( $# != 0 )); then
            echo 'Usage: filen-mount (the mount point is configured in Nix)' >&2
            exit 2
          fi
          target=${lib.escapeShellArg config.workstation.filen.mountPoint}
          if [[ "$target" != /* ]]; then
            echo 'The Filen mount point must be an absolute path.' >&2
            exit 2
          fi
          install -d -m 700 ${lib.escapeShellArg cache}
          ${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
            export CGOFUSE_LIBFUSE_PATH=/usr/local/lib/libfuse-t.dylib
          ''}
          exec ${(features.shell.runtimes { inherit pkgs; }).python3} ${./mount.py} \
            ${lib.escapeShellArg "${cache}/mount.lock"} "$target" \
            ${lib.getExe client} mount FilenNative: "$target" ${
              lib.escapeShellArgs (
                [
                  "--cache-dir"
                  cache
                  "--vfs-cache-mode"
                  "full"
                  "--vfs-cache-max-size"
                  "50Gi"
                  "--vfs-cache-min-free-space"
                  "5Gi"
                  "--vfs-cache-max-age"
                  "720h"
                  "--dir-cache-time"
                  "30s"
                  "--vfs-fast-fingerprint"
                  "--devname"
                  "Filen"
                  "--volname"
                  "Filen"
                  # Keep status private to this user, without a fixed TCP port.
                  "--rc"
                  "--rc-addr"
                  "${cache}/rc.sock"
                  "--log-level"
                  "NOTICE"
                ]
                ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
                  "-o"
                  "backend=nfs"
                  "-o"
                  "location=Filen"
                  "-o"
                  "nomtime"
                  "-o"
                  "nonamedattr"
                ]
              )
            }
        '';
      };
      cli = features.shell.application {
        inherit pkgs;
        name = "filen";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          umask 077
          if [[ "''${1:-}" == mount ]]; then
            shift
            exec ${lib.getExe mount} "$@"
          fi
          # Retain the upstream login/API-key commands without its WebDAV mount.
          install -d -m 700 ${lib.escapeShellArg "${home}/.config/filen-cli"}
          ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
            export LD_LIBRARY_PATH="${
              lib.makeLibraryPath [ pkgs.libsecret ]
            }''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
          ''}
          exec ${lib.getExe legacy} --skip-update \
            --data-dir ${lib.escapeShellArg "${home}/.config/filen-cli"} "$@"
        '';
      };
    in
    {
      options.workstation.filen.mountPoint = lib.mkOption {
        type = lib.types.str;
        default = "${home}/Filen";
        description = "Absolute directory at which the Filen cloud drive is mounted.";
      };
      config = {
        environment.systemPackages = [
          desktop
          cli
          client
          setup
          mount
        ];
        system.build = {
          filenMount = mount;
          # Build and qualify the same backend and credentials used by the service.
          filenRclone = rclone;
          filenClient = client;
        };
      };
    };
in
{
  flake.modules.nixos.filen =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      user = config.workstation.user;
      home = config.users.users.${user}.home;
      configuration = "${home}/.config/filen/rclone.conf";
    in
    {
      imports = [ common ];
      programs.fuse.enable = true;
      services.gnome.gnome-keyring.enable = true;
      systemd = {
        tmpfiles.rules = [
          "d ${config.workstation.filen.mountPoint} 0700 ${user} ${config.users.users.${user}.group} - -"
        ];
        user = {
          services.filen-drive = {
            description = "Filen cloud drive";
            wantedBy = [ "graphical-session.target" ];
            partOf = [ "graphical-session.target" ];
            after = [ "gnome-keyring-daemon.service" ];
            unitConfig = {
              ConditionUser = user;
              ConditionPathExists = configuration;
            };
            environment = {
              HOME = home;
              PATH = lib.mkForce "/run/wrappers/bin:${
                lib.makeBinPath [ pkgs.coreutils ]
              }:/run/current-system/sw/bin";
            };
            serviceConfig = {
              ExecStart = lib.getExe config.system.build.filenMount;
              Restart = "on-failure";
              RestartSec = 30;
              KillSignal = "SIGINT";
              KillMode = "mixed";
              TimeoutStopSec = 120;
              UMask = "0077";
            };
          };
          paths.filen-drive = {
            wantedBy = [ "graphical-session.target" ];
            unitConfig.ConditionUser = user;
            pathConfig.PathChanged = configuration;
          };
        };
      };
    };
  flake.modules.darwin.filen =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      user = config.workstation.user;
      home = config.users.users.${user}.home;
      configuration = "${home}/.config/filen/rclone.conf";
      cask =
        lib.findFirst (item: item.token == "fuse-t")
          (throw "FUSE-T is missing from the pinned cask metadata")
          (builtins.fromJSON (builtins.readFile "${inputs.brew-api}/cask.json"));
      installer = pkgs.fetchurl {
        inherit (cask) url sha256;
        name = "fuse-t-${cask.version}.pkg";
      };
    in
    {
      imports = [ common ];
      system.activationScripts.preActivation.text = lib.mkBefore ''
        # The vendor installer rejects in-place upgrades; never uninstall a live driver.
        filen_fuse_current() {
          test "$(/usr/bin/readlink /usr/local/lib/libfuse-t.dylib)" = ${lib.escapeShellArg "libfuse-t-${cask.version}.dylib"} &&
            test -e /usr/local/lib/libfuse-t.dylib &&
            test "$(/usr/bin/readlink /usr/local/bin/go-nfsv4)" = ${lib.escapeShellArg "/Library/Application Support/fuse-t/bin/go-nfsv4-${cask.version}"} &&
            test -x /usr/local/bin/go-nfsv4 &&
            /usr/sbin/pkgutil --pkg-info ${lib.escapeShellArg "org.fuse-t.core.${cask.version}"} >/dev/null 2>&1
        }
        if ! filen_fuse_current; then
          if /usr/bin/pgrep -f '^(/usr/local/bin/go-nfsv4|/Library/Application Support/fuse-t/bin/)' >/dev/null ||
            test -n "$(/usr/sbin/lsof -t /usr/local/lib/libfuse-t*.dylib 2>/dev/null || true)"; then
            echo 'Stop applications using FUSE-T before rebuilding its driver. Stop Filen with:' >&2
            echo "/bin/launchctl bootout gui/$(/usr/bin/id -u ${lib.escapeShellArg user})/org.nixos.filen-drive" >&2
            exit 1
          fi
          if test -x '/Library/Application Support/fuse-t/uninstall.sh'; then
            printf 'Y\n' | '/Library/Application Support/fuse-t/uninstall.sh'
          fi
          /usr/sbin/installer -pkg ${installer} -target /
          if ! filen_fuse_current; then
            echo ${lib.escapeShellArg "FUSE-T ${cask.version} did not install the expected helper and library. Check the installer output."} >&2
            exit 1
          fi
        fi
      '';
      system.activationScripts.postActivation.text = lib.mkAfter ''
        # FUSE-T presents the Filen volume through a loopback NFS endpoint.
        if ! /usr/bin/grep -Eiq '^[[:space:]]*127[.]0[.]0[.]1[[:space:]]+([^#]*[[:space:]])?Filen([[:space:]]|$)' /etc/hosts; then
          printf '\n127.0.0.1 Filen\n' >> /etc/hosts
        fi
      '';
      launchd.user.agents.filen-drive = {
        environment = {
          HOME = home;
          PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
        };
        serviceConfig = {
          ProgramArguments = [ (lib.getExe config.system.build.filenMount) ];
          RunAtLoad = true;
          KeepAlive = {
            SuccessfulExit = false;
            PathState.${configuration} = true;
          };
          WatchPaths = [ configuration ];
          ThrottleInterval = 30;
          ExitTimeOut = 120;
          Umask = 63;
          StandardOutPath = "${home}/.local/state/nix-darwin/filen-drive.log";
          StandardErrorPath = "${home}/.local/state/nix-darwin/filen-drive.log";
        };
      };
    };
}
