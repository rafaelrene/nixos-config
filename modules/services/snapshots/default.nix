{ config, ... }: {
  fileSystems."/mnt/btrfs-root" = {
    device = config.fileSystems."/home".device;
    fsType = "btrfs";
    options = [
      "subvolid=5"
      "compress=zstd"
      "noatime"
    ];
  };

  services.btrbk.instances = {
    home = {
      onCalendar = "hourly";
      settings = {
        timestamp_format = "long";
        snapshot_preserve_min = "24h";
        snapshot_preserve = "24h 14d 8w";
        target_preserve_min = "24h";
        target_preserve = "24h 14d 8w";
        volume."/mnt/btrfs-root" = {
          snapshot_dir = ".snapshots/home";
          target = "/data/.snapshots/home-replica";
          subvolume.home.snapshot_name = "home";
        };
      };
    };

    data = {
      onCalendar = "daily";
      snapshotOnly = true;
      settings = {
        timestamp_format = "long";
        snapshot_preserve_min = "1d";
        snapshot_preserve = "14d 8w";
        volume."/data" = {
          snapshot_dir = ".snapshots/data";
          subvolume.".".snapshot_name = "data";
        };
      };
    };
  };

  users.users.btrbk.extraGroups = [ "storage" ];

  systemd.tmpfiles.rules = [
    "d /mnt/btrfs-root/.snapshots 0750 btrbk btrbk - -"
    "d /mnt/btrfs-root/.snapshots/home 0750 btrbk btrbk - -"
    "d /data/.snapshots 0750 btrbk storage - -"
    "d /data/.snapshots/data 0750 btrbk storage - -"
    "d /data/.snapshots/home-replica 0750 btrbk storage - -"
  ];
}
