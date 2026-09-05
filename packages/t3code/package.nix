{
  cacert,
  fetchFromGitHub,
  fetchPnpmDeps,
  fetchurl,
  installShellFiles,
  lib,
  makeBinaryWrapper,
  node-gyp,
  nodejs_24,
  pnpm_11,
  pnpmBuildHook,
  pnpmConfigHook,
  python3,
  stdenv,
  versionCheckHook,
}:

let
  pname = "t3code-nightly";
  version = "0.0.39-nightly.20260905.1287";
  pnpm = pnpm_11;

  src = fetchFromGitHub {
    owner = "pingdotgg";
    repo = "t3code";
    tag = "v${version}";
    hash = "sha256-UCIV9VOxw5ro51DVREYfbEbSqB9oZ1YGBRMt3FPU3G8=";
  };

  # The published nightly contains the official web bundle, T3 Connect public
  # configuration, and resource monitor. Dependencies still come from the
  # matching source lockfile through fetchPnpmDeps.
  npmTarball = fetchurl {
    url = "https://registry.npmjs.org/t3/-/t3-${version}.tgz";
    hash = "sha256-lY6srDHC5uSx+gNv/4Ra9BAd5ruwY8PtZ5coziOcxTQ=";
  };

  pnpmWorkspaces = [
    "@t3tools/monorepo"
    "t3..."
    "@t3tools/desktop..."
    "@t3tools/scripts..."
  ];
in
stdenv.mkDerivation {
  inherit
    pname
    version
    src
    pnpmWorkspaces
    ;

  strictDeps = true;
  __structuredAttrs = true;

  pnpmDeps = fetchPnpmDeps {
    inherit
      pnpm
      pname
      version
      src
      pnpmWorkspaces
      ;
    fetcherVersion = 4;
    hash = "sha256-xtON4Zds68LiB182QF/IWgSqLLj6hvJOL8Ywz3ME+MU=";
  };

  nativeBuildInputs = [
    cacert
    installShellFiles
    makeBinaryWrapper
    node-gyp
    nodejs_24
    pnpm
    pnpmBuildHook
    pnpmConfigHook
    python3
  ];

  preBuild = ''
    export pnpm_config_verify_deps_before_run=false
    export npm_config_nodedir=${nodejs_24}
    pnpm rebuild --pending "''${pnpmInstallFlags[@]}" --filter '!@t3tools/monorepo'
  '';

  dontPnpmBuild = true;
  buildPhase = ''
    runHook preBuild
    runHook postBuild
  '';

  # Dependencies contain prebuilt artifacts for other systems and statically
  # linked executables that must not be patched as host binaries.
  dontPatchELF = true;
  noAuditTmpdir = true;

  installPhase = ''
    runHook preInstall

    tar -xzf ${npmTarball}
    mkdir -p "$out/libexec/t3code/apps/server"
    cp -r --no-preserve=mode node_modules "$out/libexec/t3code/"
    cp -r --no-preserve=mode apps/server/node_modules "$out/libexec/t3code/apps/server/"
    cp -r --no-preserve=mode package/dist "$out/libexec/t3code/apps/server/"
    chmod 755 "$out/libexec/t3code/apps/server/dist/resource-monitor/linux-x64/t3-resource-monitor"

    mkdir -p "$out/bin"
    makeWrapper ${lib.getExe nodejs_24} "$out/bin/t3" \
      --add-flags "$out/libexec/t3code/apps/server/dist/bin.mjs"

    find "$out/libexec/t3code" -xtype l -delete

    runHook postInstall
  '';

  postInstall = ''
    for shell in bash fish zsh; do
      installShellCompletion --cmd t3 --"$shell" <("$out/bin/t3" --completions "$shell")
    done
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
  ];
  versionCheckProgramArg = [ "--version" ];

  passthru = {
    inherit npmTarball;
    # nix-update knows how to refresh fixed-output npmDeps and pnpmDeps.
    npmDeps = npmTarball;
  };

  meta = {
    description = "Official T3 Code nightly packaged with Nix";
    homepage = "https://t3.codes";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "t3";
    platforms = [ "x86_64-linux" ];
  };
}
