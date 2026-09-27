let
  common = {
    programs.direnv = {
      enable = true;
      # Devenv supplies use_devenv; nix-direnv's use_nix/use_flake are unnecessary.
      nix-direnv.enable = false;
    };
  };
in
{
  flake.modules.nixos.direnv = common;
  flake.modules.darwin.direnv = common;
}
