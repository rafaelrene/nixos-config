{
  flake.modules.darwin.freetube = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.freetube ];
  };
}
