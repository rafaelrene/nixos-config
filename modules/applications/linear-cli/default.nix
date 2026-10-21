let
  common =
    { pkgs, ... }:
    let
      package = pkgs.callPackage ./_package.nix { };
    in
    {
      environment.systemPackages = [ package ];
      programs.zsh.interactiveShellInit = ''
        source <(${package}/bin/linear completions zsh)
      '';
    };
in
{
  flake.modules.nixos.linear-cli = common;
  flake.modules.darwin.linear-cli = common;
}
