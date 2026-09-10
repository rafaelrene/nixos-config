{
  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "none";
    extraSetFlags = [ "--accept-dns=true" ];
  };

  # Keep the existing LAN rules; allow OpenSSH and T3Code over the tailnet too.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    22
    3773
  ];
}
