{ pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/system
    ../../modules/desktop
    ../../modules/applications
    ../../modules/development
    ../../modules/shell
    ../../modules/services
  ];
  system.stateVersion = "26.05";
  networking.hostName = "othinus";
  # NetworkManager may restore a connection's WoWLAN preference. Enforce the
  # host policy whenever networking comes up.
  systemd.services.disable-wifi-wake = {
    description = "Disable Wi-Fi wake-on-LAN";
    wantedBy = [ "network-online.target" ];
    after = [ "NetworkManager.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      phy="$(${pkgs.iw}/bin/iw dev wlp4s0 info | ${pkgs.gawk}/bin/awk '/wiphy/ { print "phy" $2; exit }')"
      if test -n "$phy"; then
        ${pkgs.iw}/bin/iw phy "$phy" wowlan disable
      fi
    '';
  };

  time.timeZone = "Europe/Bratislava";
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_MEASUREMENT = "en_GB.UTF-8";
      LC_TIME = "en_GB.UTF-8";
    };
  };
  console.keyMap = "us";

  users = {
    mutableUsers = true;
    groups = {
      raf.gid = 1000;
      storage = { };
    };
    users.raf = {
      isNormalUser = true;
      uid = 1000;
      group = "raf";
      description = "Rene Rafael";
      linger = true;
      extraGroups = [
        "networkmanager"
        "storage"
        "video"
        "wheel"
      ];
    };
  };

  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/09479947-a215-42fd-96ac-e5e8d45bcecc";
    fsType = "btrfs";
    options = [
      "compress=zstd"
      "noatime"
      "nofail"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /data 2775 root storage - -"
    "d /data/code 2775 raf storage - -"
  ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    powerManagement = {
      enable = true;
      finegrained = true;
    };
    prime = {
      amdgpuBusId = "PCI:7:0:0";
      nvidiaBusId = "PCI:1:0:0";
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
    };
  };
  services.xserver.videoDrivers = [ "nvidia" ];

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
}
