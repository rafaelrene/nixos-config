{
  flake.modules.nixos.wl-screenrec = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.wl-screenrec ];
  };
}
