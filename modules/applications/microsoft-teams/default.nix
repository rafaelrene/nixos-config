{ inputs, ... }:
{
  flake.modules.darwin.microsoft-teams =
    { pkgs, ... }:
    let
      cask = inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.microsoft-teams;
    in
    {
      environment.systemPackages = [
        # Use current cask metadata with Nixpkgs' Teams-only payload extraction.
        (pkgs.teams.overrideAttrs {
          inherit (cask) version src;
          dontFixup = true;
        })
      ];
    };
}
