{ lib, ... }:
let
  version = "3.131.1";
  requestsBundle = "/etc/ssl/certs/ca-certificates.crt";
  removedRoots = [
    "emSign ECC Root CA - G3"
    "emSign Root CA - C1"
    "emSign ECC Root CA - C3"
  ];
  updatedCacert =
    pkgs:
    lib.makeOverridable (
      {
        blacklist ? [ ],
        ...
      }@arguments:
      let
        base = pkgs.cacert.override (
          arguments
          // {
            # The stable OS modules still blacklist these now-absent roots.
            # buildcatrust rejects names that are absent from its source.
            blacklist = lib.unique (lib.subtractLists removedRoots blacklist ++ [ "Comodo AAA Services root" ]);
          }
        );
        updated =
          if lib.versionOlder base.version version then
            base.overrideAttrs {
              inherit version;
              src = pkgs.fetchurl {
                urls = [
                  "https://hg-edge.mozilla.org/projects/nss/raw-file/NSS_3_131_1_RTM/lib/ckfw/builtins/certdata.txt"
                  "https://raw.githubusercontent.com/nss-dev/nss/refs/tags/NSS_3_131_1_RTM/lib/ckfw/builtins/certdata.txt"
                ];
                hash = "sha256-PsK00kDcEsdH6vRQBh24SvdXxIO72jAvninOtdcL5RA=";
              };
            }
          else
            base;
      in
      updated.overrideAttrs (old: {
        # Some PEM readers ignore OpenSSL reject attributes. Remove only the
        # compromised roots, preserving every other explicit trust decision.
        nativeBuildInputs = old.nativeBuildInputs ++ [
          pkgs.buildPackages.python3
          pkgs.buildPackages.openssl
        ];
        installPhase = old.installPhase + ''
          python3 ${./remove-compromised-roots.py} \
            "$out/etc/ssl/certs/ca-bundle.crt" \
            "$out/etc/ssl/certs/ca-no-trust-rules-bundle.crt"
        '';
      })
    ) { };

  # Keep the upstream options and store wiring, but scope the CA update to PKI.
  # A global cacert overlay rebuilds unrelated packages that embed the old bundle.
  scopedPki =
    modulePath:
    {
      config,
      lib,
      pkgs,
      modulesPath,
      ...
    }:
    {
      disabledModules = [ modulePath ];
      imports = [
        (import (modulesPath + "/${modulePath}") {
          inherit config lib;
          pkgs = pkgs // {
            cacert = updatedCacert pkgs;
          };
        })
      ];
    };
in
{
  flake.modules = {
    nixos.system = {
      imports = [ (scopedPki "security/ca.nix") ];
      # Requests otherwise selects its own certifi bundle, even with SSL_CERT_FILE.
      environment.sessionVariables.REQUESTS_CA_BUNDLE = requestsBundle;
    };

    darwin.system =
      { config, pkgs, ... }:
      let
        cacert = updatedCacert pkgs;
        pki = config.security.pki;
        systemCacert = cacert.override { blacklist = pki.caCertificateBlacklist; };
        # PEM-only readers need current roots and the compatible trust output.
        # Reuse custom PKI certificates without feeding the generated base back in.
        appleCacert = systemCacert.override {
          extraCertificateFiles = lib.filter (
            file: toString file != "${systemCacert}/etc/ssl/certs/ca-bundle.crt"
          ) pki.certificateFiles;
          extraCertificateStrings = pki.certificates;
        };
      in
      {
        imports = [ (scopedPki "security/pki") ];

        environment.variables = lib.mkIf config.security.pki.installCACerts {
          REQUESTS_CA_BUNDLE = requestsBundle;
        };
        launchd.user = lib.mkIf config.security.pki.installCACerts {
          envVariables.REQUESTS_CA_BUNDLE = requestsBundle;
          # launchctl's environment must be set again after each GUI login.
          agents.requests-ca-bundle.serviceConfig = {
            ProgramArguments = [
              "/bin/launchctl"
              "setenv"
              "REQUESTS_CA_BUNDLE"
              requestsBundle
            ];
            RunAtLoad = true;
          };
        };

        system.activationScripts.postActivation.text =
          lib.optionalString pki.installCACerts ''
            # Apple's PEM and native trust stores are independent of Nix's bundle.
            /bin/bash ${./update-apple-certificates.sh} \
              ${appleCacert}/etc/ssl/certs/ca-no-trust-rules-bundle.crt || exit $?
          ''
          + ''
            /bin/bash ${./distrust-apple-certificates.sh} ${./distrusted-apple-roots.pem} || exit $?
          ''
          + lib.optionalString (config.nix.enable && config.security.pki.installCACerts) ''
            # The original Nix installer also owns a separate root profile bundle.
            installerProfile=/nix/var/nix/profiles/per-user/root/profile
            if [ "$(/usr/bin/readlink /nix/var/nix/profiles/default)" = "$installerProfile" ] &&
               [ -f "$installerProfile/manifest.nix" ]; then
              installedPackages=$(${config.nix.package}/bin/nix-env --profile "$installerProfile" --query --out-path) || exit $?
              if ! printf '%s\n' "$installedPackages" | /usr/bin/awk '{print $NF}' | /usr/bin/grep -Fxq '${cacert}'; then
                ${config.nix.package}/bin/nix-env --profile "$installerProfile" --install ${cacert} || exit $?
              fi
            fi
          '';
      };
  };
}
