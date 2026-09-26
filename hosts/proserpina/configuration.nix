{ config, ... }:
{
  imports = [ ../../modules/darwin ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  system = {
    stateVersion = 6;
    primaryUser = "rafael";
  };
  users.users.rafael.home = "/Users/rafael";
  users.users.rafael.openssh.authorizedKeys.keyFiles = [
    ../../modules/services/ssh/proserpina.pub
  ];
  services.openssh.enable = true;
  networking = {
    hostName = "Proserpina";
    localHostName = "Proserpina";
    computerName = "Proserpina";
  };
  workstation = {
    checkout = "/Users/rafael/code/.personal/nixos-config";
    links.".local/share/codex/config.toml" =
      "${config.workstation.checkout}/hosts/proserpina/codex.toml";
    links.".local/share/claude/settings.json" =
      "${config.workstation.checkout}/hosts/proserpina/claude.json";
  };
}
