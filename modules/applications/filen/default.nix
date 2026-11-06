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
      home = config.users.users.${config.workstation.user}.home;
      data = "${home}/.config/filen-cli";
      mountPoint = config.workstation.filen.mountPoint;
      # ns -u refreshes this input; Filen updates only through Nix rebuilds.
      unstable = withSystem pkgs.stdenv.hostPlatform.system ({ unstable, ... }: unstable);
      desktop = unstable.filen-desktop.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          # Disable every updater entry point, including upstream's E2E path.
          substituteInPlace src/index.ts \
            --replace-fail 'this.updater.initialize()' '// Updates are managed by Nix.'
        '';
      });
      package = unstable.filen-cli.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          # Service shutdown must await the unmount before exiting.
          substituteInPlace src/index.ts \
            --replace-fail 'process.on("SIGINT", () => {' 'process.on("SIGTERM", () => process.emit("SIGINT"))
                  process.on("SIGINT", () => {'
          substituteInPlace src/app/featureInterfaces/driveMountingInterface.ts \
            --replace-fail 'virtualDrive.stop()' 'void virtualDrive.stop().then(resolve, reject)' \
            --replace-fail 'resolve()' ""
        '';
        postConfigure = (old.postConfigure or "") + ''
          # Allow /data/filen; upstream still checks directory access
          # and refuses a nonempty mount point.
          chmod -R u+w node_modules/@filen/network-drive
          substituteInPlace node_modules/@filen/network-drive/dist/index.js \
            --replace-fail 'process.platform === "linux" && !this.mountPoint.startsWith' \
              'false && !this.mountPoint.startsWith'
        '';
        postFixup =
          (old.postFixup or "")
          + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
            # Bun's compiled payload invalidates the original executable signature.
            ${lib.getExe pkgs.rcodesign} sign --code-signature-flags linker-signed "$out/bin/.filen-wrapped"
          '';
      });
      cli = features.shell.application {
        inherit pkgs;
        name = "filen";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.which
        ]
        ++ lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.procps;
        text = ''
          umask 077
          # --data-dir bypasses Filen's default directory creation.
          install -d -m 700 ${lib.escapeShellArg data}
          ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
            export LD_LIBRARY_PATH="${
              lib.makeLibraryPath [
                pkgs.libsecret
                pkgs.fuse3
              ]
            }''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
          ''}
          exec ${lib.getExe package} --skip-update --data-dir ${lib.escapeShellArg data} "$@"
        '';
      };
      mount = features.shell.application {
        inherit pkgs;
        name = "filen-mount";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          umask 077
          # Sign in once with `filen ls` and choose "Keep me logged in". The
          # encrypted session stays here; its key stays in the OS keyring.
          if ! test -f ${lib.escapeShellArg "${data}/.filen-cli-keep-me-logged-in"}; then
            exit 0
          fi
          # Filen forcibly unmounts its target during startup. Protect a drive
          # already owned by the desktop app or another mount process.
          if ${
            if pkgs.stdenv.hostPlatform.isDarwin then
              "/sbin/mount | /usr/bin/grep -F -- ${lib.escapeShellArg " on ${mountPoint} ("} >/dev/null"
            else
              "${lib.getExe' pkgs.util-linux "mountpoint"} -q -- ${lib.escapeShellArg mountPoint}"
          }; then
            echo ${lib.escapeShellArg "${mountPoint} is already mounted. Disable the desktop network drive before using the CLI mount service."} >&2
            exit 1
          fi
          mkdir -p ${lib.escapeShellArg mountPoint}
          exec ${lib.getExe cli} mount ${lib.escapeShellArg mountPoint}
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
          mount
        ];
        system.build.filenMount = mount;
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
      session = "${home}/.config/filen-cli/.filen-cli-keep-me-logged-in";
    in
    {
      imports = [ common ];
      programs.fuse.enable = true;
      # Filen's mount helper downloads its own rclone binary.
      programs.nix-ld.enable = true;
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
              ConditionPathExists = session;
            };
            environment = {
              HOME = home;
              PATH = lib.mkForce "/run/wrappers/bin:${
                lib.makeBinPath [
                  pkgs.bash
                  pkgs.coreutils
                  pkgs.which
                  pkgs.procps
                ]
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
            pathConfig.PathChanged = session;
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
      home = config.users.users.${config.workstation.user}.home;
      session = "${home}/.config/filen-cli/.filen-cli-keep-me-logged-in";
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
      # Desktop login/mount settings live in Chromium storage, not a config file.
      system.activationScripts.postActivation.text = lib.mkAfter ''
        # FUSE-T needs its native installer. Reuse an existing driver because
        # the vendor installer rejects in-place upgrades.
        if ! test -e /usr/local/lib/libfuse-t.dylib; then
          /usr/sbin/installer -pkg ${installer} -target /
        fi
        # The CLI's FUSE-T backend uses Filen as its localhost volume address.
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
            PathState.${session} = true;
          };
          WatchPaths = [ session ];
          ThrottleInterval = 30;
          ExitTimeOut = 120;
          Umask = 63;
          StandardOutPath = "${home}/.local/state/nix-darwin/filen-drive.log";
          StandardErrorPath = "${home}/.local/state/nix-darwin/filen-drive.log";
        };
      };
    };
}
