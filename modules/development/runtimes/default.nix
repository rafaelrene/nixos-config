{ pkgs, ... }: {
  # Projects declare their own runtime versions in Devenv.
  environment.systemPackages = [
    pkgs.devenv
    pkgs.nodejs_24
    pkgs.clang
  ];
}
