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
          if test "''${2-}" = --stage-t3; then
            /run/current-system/sw/bin/update-t3code
          else
            /run/current-system/sw/bin/t3-update-now
          fi
          /run/current-system/sw/bin/update-llm-agents
        '';
      })
    ];
  };
}
