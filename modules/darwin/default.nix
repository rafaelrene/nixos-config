{
  imports = [
    ../system/common.nix
    ../development/runtimes
    ./files.nix
    ./packages.nix
    ./shell.nix
    ./ssh.nix
    ./applications.nix
    ./omniwm
    ./agents.nix
    ./t3code
    ./updates.nix
  ];

  nix = {
    settings.trusted-users = [ "root" ];
    gc.interval = {
      Weekday = 0;
      Hour = 3;
      Minute = 0;
    };
  };

  environment = {
    variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };
}
