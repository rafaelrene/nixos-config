#!/usr/bin/env bash
set -euo pipefail

sources="${1:?A checkout is required}/modules/applications/nodejs/release.json"
version=$(curl --fail --silent --show-error --location https://nodejs.org/dist/index.json |
	jq -er '[.[] | .version | select(test("^v24\\.[0-9]+\\.[0-9]+$"))] |
    max_by(ltrimstr("v") | split(".") | map(tonumber)) | select(. != null) | ltrimstr("v")')

if jq -e --arg version "$version" '.version == $version' "$sources" >/dev/null; then
	printf 'Node.js %s is current.\n' "$version"
	exit 0
fi

darwin_url="https://nodejs.org/dist/v$version/node-v$version-darwin-arm64.tar.gz"
linux_url="https://nodejs.org/dist/v$version/node-v$version-linux-x64.tar.gz"
darwin_hash=$(nix store prefetch-file --json "$darwin_url" | jq -er '.hash | select(test("^sha256-[A-Za-z0-9+/]{43}=$"))')
linux_hash=$(nix store prefetch-file --json "$linux_url" | jq -er '.hash | select(test("^sha256-[A-Za-z0-9+/]{43}=$"))')

# Both downloads must succeed before replacing the previous release recipe.
staged=$(mktemp "${sources}.XXXXXX")
trap 'rm -f -- "$staged"' EXIT
jq -n --arg version "$version" \
	--arg darwin_url "$darwin_url" --arg darwin_hash "$darwin_hash" \
	--arg linux_url "$linux_url" --arg linux_hash "$linux_hash" \
	'{version: $version, sources: {
    "aarch64-darwin": {url: $darwin_url, hash: $darwin_hash},
    "x86_64-linux": {url: $linux_url, hash: $linux_hash}
  }}' >"$staged"
chmod 644 "$staged"
mv -f -- "$staged" "$sources"
printf 'Updated Node.js to %s.\n' "$version"
