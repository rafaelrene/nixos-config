{ config, ... }:
let
  inherit (config) features;
  server = "truenas.local";
  share = "media";
  ciphertext = ./credentials.age;
  mountFor =
    config:
    let
      user = config.workstation.user;
      inherit (config.users.users.${user}) home;
      directory = "${home}/TrueNAS";
    in
    {
      inherit home user directory;
      mountPoint = "${directory}/${share}";
    };
in
{
  flake.modules.nixos.truenas =
    {
      config,
      lib,
      pkgs,
      utils,
      ...
    }:
    let
      inherit (mountFor config) user directory mountPoint;
      inherit (config.users.users.${user}) group;
      credentials = "/run/truenas-media/credentials";
      unlock = pkgs.writeShellApplication {
        name = "unlock-truenas-media";
        runtimeInputs = [
          pkgs.age
          pkgs.coreutils
          pkgs.diffutils
        ];
        text = ''
          umask 077
          temporary=$(mktemp "$RUNTIME_DIRECTORY/credentials.XXXXXXXX")
          trap 'rm -f -- "$temporary"' EXIT
          age --decrypt --identity /etc/ssh/ssh_host_ed25519_key ${ciphertext} > "$temporary"
          mv -- "$temporary" ${credentials}

          legacy=/etc/nixos/secrets/truenas-media
          if [[ -f $legacy && ! -L $legacy ]] && cmp -s -- ${credentials} "$legacy"; then
            rm -- "$legacy"
          fi
        '';
      };
    in
    {
      boot.supportedFilesystems = [ "cifs" ];
      systemd = {
        tmpfiles.rules = [ "d ${directory} 0700 ${user} ${group} - -" ];
        services.truenas-media-credentials = {
          description = "Unlock TrueNAS media credentials";
          wants = [ "sshd-keygen.service" ];
          after = [ "sshd-keygen.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            RuntimeDirectory = "truenas-media";
            RuntimeDirectoryMode = "0700";
            ExecStart = lib.getExe unlock;
          };
        };
        mounts = [
          {
            what = "//${server}/${share}";
            where = mountPoint;
            type = "cifs";
            requires = [ "truenas-media-credentials.service" ];
            after = [ "truenas-media-credentials.service" ];
            options = lib.concatStringsSep "," [
              "credentials=${credentials}"
              "uid=${user}"
              "gid=${group}"
              "file_mode=0600"
              "dir_mode=0700"
              "nosuid"
              "nodev"
            ];
            mountConfig.TimeoutSec = "15s";
          }
        ];
        timers.truenas-media = {
          description = "Mount TrueNAS media at startup and after network failures";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "1s";
            OnCalendar = "*-*-* *:0/5:00";
            Unit = "${utils.escapeSystemdPath mountPoint}.mount";
          };
        };
      };
    };

  flake.modules.darwin.truenas =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (mountFor config) home mountPoint;
      nativeMount = pkgs.runCommandCC "mount-truenas-smb" { } ''
        mkdir -p "$out/bin"
        cc -Wall -Wextra -Werror -framework CoreFoundation -framework NetFS \
          ${./mount.c} -o "$out/bin/mount-truenas-smb"
      '';
      mountMedia = features.shell.darwinApplication {
        inherit pkgs;
        name = "mount-truenas-media";
        runtimeInputs = [ pkgs.age ];
        text = ''
          mount_point=${lib.escapeShellArg mountPoint}
          if /sbin/mount -t smbfs | /usr/bin/grep -F "${server}/${share} on $mount_point (" >/dev/null; then
            exit 0
          fi
          umask 077
          /bin/mkdir -p "$mount_point"
          contents=$(/usr/bin/find "$mount_point" -mindepth 1 -maxdepth 1 -print -quit)
          if [[ -n $contents ]]; then
            printf >&2 'TrueNAS mount point is occupied: %s\n' "$mount_point"
            exit 1
          fi
          age --decrypt --identity ${lib.escapeShellArg "${home}/.config/truenas/identity.agekey"} \
            ${ciphertext} | ${lib.getExe' nativeMount "mount-truenas-smb"} \
            'smb://${server}/${share}' "$mount_point"
        '';
      };
      log = "${home}/.local/state/nix-darwin/truenas-media.log";
    in
    {
      launchd.user.agents.truenas-media.serviceConfig = {
        ProgramArguments = [ (lib.getExe mountMedia) ];
        LimitLoadToSessionType = "Aqua";
        RunAtLoad = true;
        StartInterval = 300;
        StandardOutPath = log;
        StandardErrorPath = log;
      };
    };
}
