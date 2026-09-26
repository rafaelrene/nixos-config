{
  description = "Rolling official T3 Code server and desktop";
  inputs.nixpkgs.url = "@nixpkgs@";
  outputs = { nixpkgs, ... }: {
    packages."@system@" =
      let
        pkgs = nixpkgs.legacyPackages."@system@";
      in
      rec {
        t3code-nightly = pkgs.callPackage ./package.nix { };
        t3code-desktop = pkgs.callPackage ./desktop.nix { };
        default =
          assert t3code-nightly.version == t3code-desktop.version;
          pkgs.buildEnv {
            name = "t3code-${t3code-nightly.version}";
            paths = [
              t3code-nightly
              t3code-desktop
            ];
          };
      };
  };
}
