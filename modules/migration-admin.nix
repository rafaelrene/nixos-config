{
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

  # Delete this module from the active configuration as soon as raf can log in
  # and use password-authenticated sudo.
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
}
