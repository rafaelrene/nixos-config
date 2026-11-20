let
  packages = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.p7zip ];
  };
in
{
  flake.modules.nixos.p7zip = packages;
  flake.modules.darwin.p7zip = packages;
}
