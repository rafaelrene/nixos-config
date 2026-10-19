{ lib, ... }:
{
  flake.modules = lib.genAttrs [ "nixos" "darwin" ] (_: {
    ffmpeg = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.ffmpeg ];
    };
  });
}
