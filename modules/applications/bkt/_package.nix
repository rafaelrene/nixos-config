{
  lib,
  stdenv,
  fetchzip,
  linkFarm,
}:
let
  version = "0.32.1";
  sources = {
    x86_64-linux = {
      platform = "linux_x86_64";
      hash = "sha256-eUQQ9P1w4P8xhz/zbUWed9R4wTa7JNH5cykbp8ptulA=";
    };
    aarch64-darwin = {
      platform = "darwin_arm64";
      hash = "sha256-ndiP8AoA9qzW46Ccr4e4ZbxY06xHA+D6NlwDL26PShU=";
    };
  };
  source = sources.${stdenv.hostPlatform.system};
  # Release binaries include the public OAuth client configuration; source builds do not.
  release = fetchzip {
    url = "https://github.com/avivsinai/bitbucket-cli/releases/download/v${version}/bkt_${version}_${source.platform}.tar.gz";
    inherit (source) hash;
    stripRoot = false;
  };
in
(linkFarm "bitbucket-cli-${version}" {
  "bin/bkt" = "${release}/bkt";
}).overrideAttrs
  (_: {
    inherit version;
    pname = "bitbucket-cli";
    meta = {
      description = "Bitbucket CLI with OAuth authentication";
      homepage = "https://github.com/avivsinai/bitbucket-cli";
      license = lib.licenses.mit;
      platforms = builtins.attrNames sources;
      mainProgram = "bkt";
    };
  })
