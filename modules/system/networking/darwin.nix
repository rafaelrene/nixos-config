{
  flake.modules.darwin.networking =
    # PF supports source-network rules; Apple's wildcard anchor preserves OS-managed rules.
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      applyFirewall = pkgs.writeShellApplication {
        name = "apply-workstation-firewall";
        text = builtins.readFile ./firewall.sh;
      };
    in
    {
      environment.etc."pf.anchors/nixos-workstation".source = ./firewall.pf;
      launchd.daemons.workstation-firewall.serviceConfig = {
        ProgramArguments = [
          "/bin/sh"
          "-c"
          "/bin/wait4path ${lib.getExe applyFirewall} && exec ${lib.getExe applyFirewall}"
        ];
        RunAtLoad = true;
        KeepAlive.SuccessfulExit = false;
        ThrottleInterval = 10;
        StandardOutPath = "/var/log/nixos-workstation-firewall.log";
        StandardErrorPath = "/var/log/nixos-workstation-firewall.log";
      };
      system.activationScripts.postActivation.text = lib.mkAfter ''
        /bin/launchctl kickstart system/${config.launchd.daemons.workstation-firewall.serviceConfig.Label}
      '';
    };
}
