{ pkgs }:
pkgs.buildNpmPackage {
  pname = "raycast-workstation-destinations";
  version = "1.0.0";
  src = pkgs.lib.cleanSourceWith {
    src = ./raycast;
    filter =
      path: type:
      pkgs.lib.cleanSourceFilter path type
      && !(builtins.elem (baseNameOf path) [
        "node_modules"
        "dist"
        "raycast-env.d.ts"
      ]);
  };
  npmDepsHash = "sha256-pJNnpLC9ts0GYZ1Z7+agJXnQ42/tU4+7xjI5ze1Yf2A=";
  nodejs = pkgs.nodejs_24;
  doCheck = true;
  checkPhase = ''
    npm run typecheck
    npm run lint
  '';
  installPhase = ''
    mkdir -p "$out"
    cp -R dist/. "$out/"
  '';
}
