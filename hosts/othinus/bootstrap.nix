{ pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Keep the current boot path intact until the final Limine configuration has
  # built successfully and the systemd-boot fallback has been verified.
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages;

  networking = {
    hostName = "nixos";
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [ 22 ];
  };

  time.timeZone = "Europe/Bratislava";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [ "root" ];
    };
  };
  nixpkgs.config.allowUnfree = true;

  users.groups.storage = { };
  users.users.othinus = {
    isNormalUser = true;
    uid = 1000;
    description = "Rene Rafael";
    extraGroups = [
      "networkmanager"
      "storage"
      "wheel"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMbbeGv4hOGRf4ClZ/V339bi4yiK5bjvb9v3GsRKC3nF othinus"
    ];
  };

  # This account exists only while the active UID 1000 account is renamed. Its
  # temporary passwordless sudo rule is removed after SSH and sudo work as raf.
  users.users.migration-admin = {
    isNormalUser = true;
    description = "Temporary Othinus migration administrator";
    extraGroups = [
      "networkmanager"
      "storage"
      "wheel"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMbbeGv4hOGRf4ClZ/V339bi4yiK5bjvb9v3GsRKC3nF othinus"
    ];
  };
  security.sudo.extraRules = [
    {
      users = [ "migration-admin" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  environment.systemPackages = with pkgs; [
    curl
    git
    gh
    jq
    ripgrep
  ];

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
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
  systemd.tmpfiles.rules = [ "d /data 2775 root storage - -" ];

  system.stateVersion = "26.05";
}
