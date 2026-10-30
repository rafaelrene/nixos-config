{
  description = "Declarative workstation configurations for Othinus and Proserpina";

  inputs = {
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    import-tree.url = "github:denful/import-tree";
    devenv.url = "github:cachix/devenv/main";

    anthropic-skills = {
      url = "github:anthropics/skills/main";
      flake = false;
    };

    llm-agents.url = "github:numtide/llm-agents.nix";
    t3-release = {
      url = "path:./modules/applications/t3code/release";
      flake = false;
    };
    # These upstream URLs are overwritten. Archive locked inputs with
    # `nix flake archive` to reproduce superseded downloads on another machine.
    nodejs-checksums = {
      url = "file+https://nodejs.org/dist/latest-v24.x/SHASUMS256.txt";
      flake = false;
    };
    google-drive-download = {
      url = "file+https://dl.google.com/drive-file-stream/5-percent/GoogleDrive.dmg";
      flake = false;
    };
    viber-download = {
      url = "file+https://download.viber.com/desktop/mac_arm/update/update.zip";
      flake = false;
    };
    rex-download = {
      url = "file+https://blob.superlogical.com/download/rex-app/preview/latest.dmg";
      flake = false;
    };

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    brew-api = {
      url = "github:BatteredBunny/brew-api";
      flake = false;
    };
    brew-nix = {
      url = "github:BatteredBunny/brew-nix";
      inputs = {
        nixpkgs.follows = "nixpkgs-darwin";
        nix-darwin.follows = "nix-darwin";
        brew-api.follows = "brew-api";
      };
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    helium-browser = {
      url = "github:schembriaiden/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      inputs.import-tree [
        ./modules
        ./hosts
        ./profiles
        ./themes
      ]
    );
}
