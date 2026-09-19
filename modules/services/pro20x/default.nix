{ pkgs, lib, ... }:
let
  browsers = pkgs.playwright-driver.browsers.override {
    withFirefox = false;
    withWebkit = false;
    withFfmpeg = false;
    withChromiumHeadlessShell = false;
  };
  checker = pkgs.writeShellApplication {
    name = "pro20x-check";
    text = ''
      export PLAYWRIGHT_DRIVER=${pkgs.playwright-driver}
      export PLAYWRIGHT_BROWSERS_PATH=${browsers}
      exec ${lib.getExe pkgs.nodejs_24} ${./check.cjs} "$@"
    '';
  };
in
{
  environment.systemPackages = [ checker ];

  systemd.user.services.pro20x-check = {
    description = "Check ChatGPT Pro 20x and notify ntfy";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe checker;
      TimeoutStartSec = "3min";
      UMask = "0077";
    };
  };

  systemd.user.timers.pro20x-check = {
    description = "Check ChatGPT Pro 20x twice daily";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 09,21:00:00 Europe/Bratislava";
      Persistent = true;
    };
  };
}
