{ inputs, ... }:
let
  common = { config, ... }: {
    programs.direnv = {
      enable = true;
      # Devenv supplies use_devenv; nix-direnv's use_nix/use_flake are unnecessary.
      nix-direnv.enable = false;
      # Trailing slashes keep trust within these directories, excluding sibling names.
      settings.whitelist.prefix = [
        "${config.users.users.${config.workstation.user}.home}/.local/share/t3code/worktrees/"
      ];
    };
    nixpkgs.overlays = [
      (_final: prev: {
        inherit
          (import inputs.nixpkgs-unstable {
            system = prev.stdenv.hostPlatform.system;
          })
          direnv
          ;
      })
    ];
  };
in
{
  flake.modules.nixos.direnv = common;
  flake.modules.darwin.direnv = { config, ... }: {
    imports = [ common ];
    # Proserpina's XDG T3 directory aliases existing ~/.t3 state.
    programs.direnv.settings.whitelist.prefix = [
      "${config.users.users.${config.workstation.user}.home}/.t3/worktrees/"
    ];
  };
}
