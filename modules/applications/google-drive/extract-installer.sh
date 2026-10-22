#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
	printf 'Usage: %s source.dmg destination.pkg\n' "$0" >&2
	exit 1
fi

workspace=$(mktemp -d)
mounted=false
cleanup() {
	if $mounted; then
		/usr/bin/hdiutil detach -quiet "$workspace/mount" || return $?
	fi
	rm -rf -- "$workspace"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Google's APFS images use features unsupported by 7zz; undmg only reads HFS.
/usr/bin/hdiutil attach -quiet -readonly -nobrowse -mountpoint "$workspace/mount" "$1"
mounted=true
cp "$workspace/mount/GoogleDrive.pkg" "$2"
/usr/bin/hdiutil detach -quiet "$workspace/mount"
mounted=false
