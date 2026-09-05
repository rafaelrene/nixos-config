{
  config,
  lib,
  pkgs,
  ...
}:

let
  sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMbbeGv4hOGRf4ClZ/V339bi4yiK5bjvb9v3GsRKC3nF othinus";
in
{
  networking = {
    hostName = "othinus";
    networkmanager = {
      enable = true;
      wifi.powersave = true;
    };
    nftables.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [ ];
      extraInputRules = ''
        ip saddr 192.168.86.0/24 tcp dport { 22, 3773 } accept comment "Othinus LAN services"
      '';
    };
  };

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

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = lib.mkForce [ "root" ];
      substituters = [
        "https://cache.nixos.org"
        "https://devenv.cachix.org"
        "https://cache.numtide.com"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbZGZpVJ8lrQ1kX7H7lYZ7cP0E="
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
    };
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
  nixpkgs.config.allowUnfree = true;

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
      shell = pkgs.nushell;
      extraGroups = [
        "networkmanager"
        "storage"
        "video"
        "wheel"
      ];
      openssh.authorizedKeys.keys = [ sshKey ];
    };
  };

  security = {
    polkit.enable = true;
    rtkit.enable = true;
    sudo = {
      enable = true;
      wheelNeedsPassword = true;
    };
  };

  services = {
    openssh = {
      enable = true;
      openFirewall = false;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
    };
    fwupd.enable = true;
    power-profiles-daemon.enable = true;
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
    "d /home/raf/.cache 0700 raf raf - -"
    "d /home/raf/.config 0700 raf raf - -"
    "d /home/raf/.config/git 0700 raf raf - -"
    "L /home/raf/.config/git/config - - - - /data/code/nixos-config/config/git/config"
    "d /home/raf/.local 0700 raf raf - -"
    "d /home/raf/.local/bin 0755 raf raf - -"
    "d /home/raf/.local/share 0700 raf raf - -"
    "d /home/raf/.local/state 0700 raf raf - -"
  ];

  environment = {
    variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      NH_FLAKE = "/data/code/nixos-config";
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_STATE_HOME = "$HOME/.local/state";
      CODEX_HOME = "$HOME/.local/share/codex";
      CLAUDE_CONFIG_DIR = "$HOME/.local/share/claude";
      T3CODE_HOME = "$HOME/.local/share/t3code";
    };
    localBinInPath = true;
    systemPackages = with pkgs; [
      bat
      btop
      clang
      curl
      eza
      fd
      fzf
      gh
      git
      gnutar
      jq
      lsof
      neovim
      nh
      p7zip
      pciutils
      ripgrep
      unzip
      usbutils
      wget
      wl-clipboard
      xz
      yq-go
      zip
      zoxide
    ];
  };

  programs.bash.completion.enable = true;

  assertions = [
    {
      assertion = config.nix.settings.trusted-users == [ "root" ];
      message = "Only root may be a trusted Nix user on Othinus.";
    }
  ];
}
