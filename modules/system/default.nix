{ pkgs, ... }: {
  imports = [
    ./boot
    ./networking
    ./nix
  ];
  security = {
    polkit.enable = true;
    rtkit.enable = true;
    sudo = {
      enable = true;
      wheelNeedsPassword = true;
    };
  };

  services.fwupd.enable = true;
  services.power-profiles-daemon.enable = true;
  environment = {
    localBinInPath = true;
    variables = {
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_STATE_HOME = "$HOME/.local/state";
    };
    systemPackages = with pkgs; [
      bat
      btop
      curl
      fd
      fzf
      gnutar
      jq
      lsof
      p7zip
      pciutils
      ripgrep
      unzip
      usbutils
      wget
      xz
      yq-go
      zip
    ];
  };
  systemd.tmpfiles.rules = [
    "d /home/raf/.cache 0700 raf raf - -"
    "d /home/raf/.config 0700 raf raf - -"
    "d /home/raf/.local 0700 raf raf - -"
    "d /home/raf/.local/bin 0755 raf raf - -"
    "d /home/raf/.local/share 0700 raf raf - -"
    "d /home/raf/.local/state 0700 raf raf - -"
  ];
}
