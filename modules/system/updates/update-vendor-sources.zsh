set -euo pipefail
setopt extendedglob

if (($# != 1)); then
	print -u2 -r -- 'Usage: update-vendor-sources checkout'
	exit 1
fi

sources="$1/modules/system/updates/vendor-sources.json"
manifest=$(<"$sources")
jq -e 'type == "object" and ([."google-drive", .viber] | all(.[];
  type == "object" and has("version") and has("url") and has("hash")))' <<<"$manifest" >/dev/null
workspace=$(mktemp --directory)
staged=''
trap 'rm -rf -- "$workspace"; if [[ -n "$staged" ]]; then rm -f -- "$staged"; fi' EXIT

checked() {
	local exit_code
	if "$@" 2>"$workspace/error"; then
		return 0
	else
		exit_code=$?
		print -u2 -r -- "$1 failed: $(<"$workspace/error")"
		exit "$exit_code"
	fi
}

# Google Drive and Viber overwrite download URLs, so inspect their app payloads.
# OmniWM publishes versioned archives with checksums in GitHub release metadata.
release=$(checked curl --fail --silent --show-error --location https://api.github.com/repos/OmniNull/OmniWM/releases/latest)
tag=$(jq -er '.tag_name | select(type == "string" and length > 0)' <<<"$release")
asset=$(jq -ce --arg name "OmniWM-$tag.zip" '.assets | map(select(.name == $name)) | first' <<<"$release")
digest=$(jq -er '.digest | select(type == "string" and test("^sha256:[0-9a-fA-F]{64}$")) | sub("^sha256:"; "")' <<<"$asset")
omniwm_hash=$(checked nix hash convert --hash-algo sha256 --to sri "$digest")
omniwm_hash=${omniwm_hash##[[:space:]]#}
omniwm_hash=${omniwm_hash%%[[:space:]]#}
omniwm_url=$(jq -er '.browser_download_url | select(type == "string" and length > 0)' <<<"$asset")
omniwm_version=${tag#v}

google_url=$(jq -er '."google-drive".url | select(type == "string" and length > 0)' <<<"$manifest")
viber_url=$(jq -er '.viber.url | select(type == "string" and length > 0)' <<<"$manifest")
google=$(checked nix store prefetch-file --refresh --json --name google-drive.dmg "$google_url")
viber=$(checked nix store prefetch-file --refresh --json --name viber.zip "$viber_url")
google_store=$(jq -er '.storePath | select(type == "string" and length > 0)' <<<"$google")
viber_store=$(jq -er '.storePath | select(type == "string" and length > 0)' <<<"$viber")
google_hash=$(jq -er '.hash | select(type == "string" and length > 0)' <<<"$google")
viber_hash=$(jq -er '.hash | select(type == "string" and length > 0)' <<<"$viber")

checked 7zz e -so "$google_store" 'Install Google Drive/GoogleDrive.pkg' >"$workspace/GoogleDrive.pkg"
checked 7zz e -so "$workspace/GoogleDrive.pkg" GoogleDrive_arm64.pkg/PackageInfo >"$workspace/PackageInfo"
google_version=$(checked xmllint --nonet --xpath 'string((/pkg-info/bundle)[1]/@CFBundleVersion)' "$workspace/PackageInfo")
checked unzip -p "$viber_store" Viber.app.tar >"$workspace/Viber.app.tar"
checked bsdtar -xOf "$workspace/Viber.app.tar" ./Viber.app/Contents/Info.plist >"$workspace/Info.plist"
viber_version=$(checked plutil -extract CFBundleShortVersionString raw -o - "$workspace/Info.plist")
viber_version=${viber_version##[[:space:]]#}
viber_version=${viber_version%%[[:space:]]#}

for version in "$google_version" "$viber_version"; do
	if [[ ! "$version" =~ '^[0-9]+(\.[0-9]+)+$' ]]; then
		print -u2 -r -- "Invalid vendor package version: $version"
		exit 1
	fi
done

updated=$(jq --arg google_version "$google_version" --arg google_hash "$google_hash" \
	--arg omniwm_version "$omniwm_version" --arg omniwm_url "$omniwm_url" --arg omniwm_hash "$omniwm_hash" \
	--arg viber_version "$viber_version" --arg viber_hash "$viber_hash" '
  ."google-drive".version = $google_version |
  ."google-drive".hash = $google_hash |
  .omniwm = {version: $omniwm_version, url: $omniwm_url, hash: $omniwm_hash} |
  .viber.version = $viber_version |
  .viber.hash = $viber_hash
' <<<"$manifest")
if ! jq -e --argjson updated "$updated" '. == $updated' <<<"$manifest" >/dev/null; then
	# Rename beside the destination to stay atomic across filesystems.
	staged=$(mktemp --tmpdir="${sources:h}" vendor-sources.json.XXXXXX)
	print -r -- "$updated" >"$staged"
	chmod 644 "$staged"
	mv -f -- "$staged" "$sources"
	staged=''
fi
print -r -- "Pinned Google Drive $google_version, OmniWM $omniwm_version and Viber $viber_version."
