{
  flake.modules.nixos.ark = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.kdePackages.ark ];
  };
}
