{ pkgs, ... }: {
  imports = [
    ./niri
    ./dms
    ./theming
  ];
  services = {
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
    pulseaudio.enable = false;
    upower.enable = true;
    blueman.enable = true;
  };
  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    graphics = {
      enable = true;
      enable32Bit = true;
    };
  };
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    QT_QPA_PLATFORM = "wayland;xcb";
  };
  environment.systemPackages = [
    pkgs.brightnessctl
    pkgs.xdg-utils
    pkgs.wl-clipboard
  ];
}
