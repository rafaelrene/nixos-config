{
  lib,
  fetchzip,
  linkFarm,
}:
let
  version = "0.32.1";
  # Release binaries include the public OAuth client configuration; source builds do not.
  release = fetchzip {
    url = "https://github.com/avivsinai/bitbucket-cli/releases/download/v${version}/bkt_${version}_linux_x86_64.tar.gz";
    hash = "sha256-eUQQ9P1w4P8xhz/zbUWed9R4wTa7JNH5cykbp8ptulA=";
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
      platforms = [ "x86_64-linux" ];
      mainProgram = "bkt";
    };
  })
