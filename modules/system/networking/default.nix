{
  networking = {
    networkmanager = {
      enable = true;
      wifi.powersave = true;
    };
    nftables.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [ ];
    };
  };

  services = {
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
  };
}
