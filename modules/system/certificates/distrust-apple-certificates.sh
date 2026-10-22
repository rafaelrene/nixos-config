#!/bin/bash
set -euo pipefail

# Native Apple trust is independent of /etc/ssl/cert.pem and Nix's CA bundle.
# Pass the pinned PEM resource explicitly so Nix can store it separately.
if [[ $# -ne 1 ]]; then
	printf 'Usage: %s distrusted-apple-roots.pem\n' "$0" >&2
	exit 1
fi

temporary=$(/usr/bin/mktemp -d)
trap '/bin/rm -rf "$temporary"' EXIT

/usr/bin/awk -v directory="$temporary" '
  /^-----BEGIN CERTIFICATE-----$/ { count++; inside = 1 }
  inside { print > (directory "/" count ".pem") }
  /^-----END CERTIFICATE-----$/ { inside = 0 }
  END { if (count != 2 || inside) exit 1 }
' "$1"

# Validate both complete certificates before changing any trust settings.
fingerprints=()
for index in 1 2; do
	fingerprint=$(/usr/bin/openssl x509 -in "$temporary/$index.pem" -noout -sha256 -fingerprint)
	fingerprint=${fingerprint#*=}
	fingerprint=${fingerprint//:/}
	case "$fingerprint" in
	D7A7A0FB5D7E2731D771E9484EBCDEF71D5F0C3E0A2948782BC83EE0EA699EF4 | \
		86A1ECBA089C4A8D3BBE2734C612BA341D813E043CF9E8A862CD5C57A36BBE6B) ;;
	*)
		printf 'Unexpected certificate fingerprint: %s\n' "$fingerprint" >&2
		exit 1
		;;
	esac
	fingerprints+=("$fingerprint")
done
if [[ ${fingerprints[0]} == "${fingerprints[1]}" ]]; then
	printf 'The resource must contain both distinct distrusted roots.\n' >&2
	exit 1
fi

/usr/bin/security trust-settings-export -d "$temporary/admin.plist" >/dev/null
for index in 1 2; do
	certificate="$temporary/$index.pem"
	# Apple's trust-settings plist indexes certificates by SHA-1, not SHA-256.
	identifier=$(/usr/bin/openssl x509 -in "$certificate" -noout -sha1 -fingerprint)
	identifier=${identifier#*=}
	identifier=${identifier//:/}
	settings=$(/usr/bin/plutil -extract "trustList.$identifier.trustSettings" json -o - "$temporary/admin.plist" 2>/dev/null) || settings=
	if [[ $settings == '[{"kSecTrustSettingsResult":3}]' ]]; then
		continue
	fi
	if [[ $EUID -ne 0 ]]; then
		printf 'Administrator activation is required to distrust these roots.\n' >&2
		exit 1
	fi
	# Replace only this certificate's admin settings. No keychain import, user
	# settings changes, or whole-domain import. User overrides take precedence.
	/usr/bin/security add-trusted-cert -d -r deny "$certificate"
done
