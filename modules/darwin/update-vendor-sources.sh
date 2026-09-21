#!/usr/bin/env bash
set -euo pipefail

checkout=$1
sources="$checkout/modules/darwin/vendor-sources.json"
workspace=$(mktemp -d)
trap 'rm -rf "$workspace"' EXIT

# These vendors overwrite their download URLs. Pin the complete app payload,
# never an online installer, and publish both new hashes only after inspection.
for name in google-drive viber; do
  url=$(jq -r --arg name "$name" '.[$name].url' "$sources")
  extension=zip
  if [[ "$name" == google-drive ]]; then extension=dmg; fi
  nix store prefetch-file --refresh --json --name "$name.$extension" "$url" >"$workspace/$name.json"
done

google_src=$(jq -r .storePath "$workspace/google-drive.json")
7zz e -so "$google_src" 'Install Google Drive/GoogleDrive.pkg' >"$workspace/GoogleDrive.pkg"
7zz e -so "$workspace/GoogleDrive.pkg" GoogleDrive_arm64.pkg/PackageInfo >"$workspace/PackageInfo"
google_version=$(xmlstarlet sel -t -v '/pkg-info/bundle/@CFBundleVersion' "$workspace/PackageInfo")

viber_src=$(jq -r .storePath "$workspace/viber.json")
unzip -p "$viber_src" Viber.app.tar >"$workspace/Viber.app.tar"
bsdtar -xOf "$workspace/Viber.app.tar" ./Viber.app/Contents/Info.plist >"$workspace/Info.plist"
viber_version=$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$workspace/Info.plist")

for version in "$google_version" "$viber_version"; do
  if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
    echo "Invalid vendor package version: $version" >&2
    exit 1
  fi
done

jq --arg google_version "$google_version" --arg viber_version "$viber_version" \
  --arg google_hash "$(jq -r .hash "$workspace/google-drive.json")" \
  --arg viber_hash "$(jq -r .hash "$workspace/viber.json")" \
  '."google-drive".version = $google_version | ."google-drive".hash = $google_hash |
   .viber.version = $viber_version | .viber.hash = $viber_hash' "$sources" >"$workspace/sources.json"
if ! cmp -s "$workspace/sources.json" "$sources"; then
  # Stage beside the destination so the rename stays atomic across filesystems.
  staged=$(mktemp "$sources.XXXXXX")
  cp "$workspace/sources.json" "$staged"
  chmod 644 "$staged"
  mv "$staged" "$sources"
fi
echo "Pinned Google Drive $google_version and Viber $viber_version."
