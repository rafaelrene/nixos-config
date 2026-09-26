{
  config,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "nix-update-packages";
      runtimeInputs = with pkgs; [
        nix
        jq
        _7zz
        xmlstarlet
        unzip
        libarchive
      ];
      text = ''
        checkout=${lib.escapeShellArg config.workstation.checkout}
        checkout="''${1:-$checkout}"
        echo "Updating Proserpina's Nix inputs..."
        nix flake update --flake "path:$checkout" nixpkgs-darwin nixpkgs-unstable nix-darwin rust-overlay zen-browser helium-browser brew-nix brew-api try-rs
        echo "Updating pinned vendor downloads..."
        ${pkgs.bash}/bin/bash ${./update-vendor-sources.sh} "$checkout"
        echo "Updating T3 Code server and desktop..."
        /run/current-system/sw/bin/t3-update-now
        echo "Updating agent tools..."
        /run/current-system/sw/bin/update-llm-agents
        echo "All update sources checked. Run ns to apply the updated Nix system, or use nups next time."
      '';
    })
  ];
}
