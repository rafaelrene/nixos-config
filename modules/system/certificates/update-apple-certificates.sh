#!/bin/bash
set -euo pipefail

# A filtered old Apple bundle lacks newer roots needed after AAA is removed.
# Install the updated compatible PKI bundle; native Apple trust is separate.
if [[ $# -lt 1 || $# -gt 2 ]]; then
	printf 'Usage: %s updated-bundle.pem [destination.pem]\n' "$0" >&2
	exit 1
fi
replacement=$1
bundle=${2:-/etc/ssl/cert.pem}
if /usr/bin/cmp -s "$bundle" "$replacement"; then
	exit 0
fi
temporary=$(/usr/bin/mktemp "${bundle}.XXXXXX")
trap '/bin/rm -f "$temporary"' EXIT
/bin/cp -p "$bundle" "$temporary"
/bin/cat "$replacement" >"$temporary"

# Refuse an empty or malformed result before replacing the system file.
/usr/bin/grep -q '^-----BEGIN CERTIFICATE-----$' "$temporary"
/usr/bin/openssl crl2pkcs7 -nocrl -certfile "$temporary" -out /dev/null
if [[ ! -e ${bundle}.before-emudhra-2026-10-20 ]]; then
	/bin/cp -p "$bundle" "${bundle}.before-emudhra-2026-10-20"
fi
/bin/mv -f "$temporary" "$bundle"
