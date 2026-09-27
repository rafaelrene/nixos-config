{ inputs, ... }:
let
  common =
    { pkgs, ... }:
    let
      direnvrc = pkgs.runCommand "devenv-direnvrc" { nativeBuildInputs = [ pkgs.devenv ]; } ''
        export XDG_CACHE_HOME="$TMPDIR/cache"
        export XDG_DATA_HOME="$TMPDIR/data"
        devenv direnvrc > "$out"
        # Devenv's input-paths.txt has no final newline. Include its last dependency.
        substituteInPlace "$out" --replace-fail \
          'while IFS= read -r file; do' \
          'while IFS= read -r file || [[ -n "$file" ]]; do'
        bash -n "$out"
      '';
    in
    {
      environment.systemPackages = [ pkgs.devenv ];
      environment.etc."direnv/lib/devenv.sh".source = direnvrc;
    };
in
{
  flake.modules.nixos.devenv = common;
  flake.modules.darwin.devenv = {
    imports = [ common ];
    # Darwin needs the newer package; keep its upstream binary cache identity.
    nixpkgs.overlays = [
      (_final: prev: {
        inherit
          (import inputs.nixpkgs-unstable {
            system = prev.stdenv.hostPlatform.system;
            config.allowUnfree = true;
          })
          devenv
          ;
      })
    ];
  };
}
