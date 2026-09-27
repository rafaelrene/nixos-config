{
  flake.modules.nixos.updates = { config, pkgs, ... }: {
    environment.systemPackages = [
      (pkgs.writeShellApplication {
        name = "nix-update-packages";
        runtimeInputs = [
          pkgs.nix
          pkgs.systemd
        ];
        text = ''
          checkout="''${1:-${config.workstation.checkout}}"
          nix flake update --flake "path:$checkout"
          /run/current-system/sw/bin/t3-update-now
          /run/current-system/sw/bin/update-llm-agents
        '';
      })
    ];
  };
}
