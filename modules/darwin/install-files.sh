#!/usr/bin/env bash
# Run as the primary user, never root. Check every destination before changing it.
set -euo pipefail
home=$1
manifest=$2
mode=$3
record="$home/.local/state/nix-darwin/links.json"
previous='{}'

fail() {
	printf 'nix-darwin: %s\n' "$*" >&2
	exit 1
}
pairs() { jq -r "$1 | to_entries[] | [.key, .value] | @tsv" "$manifest"; }
legacy() {
	local path=$1 suffix=$2 target
	[[ -L "$path" && -n "$suffix" ]] || return 1
	target=$(readlink "$path")
	[[ "$target" = /* && "$target" == *"$suffix" ]]
}

# Resolve an XDG alias that will be created later, without moving agent data.
effective() {
	local relative=$1 new old
	while IFS=$'\t' read -r new old; do
		if [[ "$relative" == "$new/"* && ! -e "$home/$new" && ! -L "$home/$new" && -d "$home/$old" ]]; then
			printf '%s\n' "$home/$old/${relative#"$new/"}"
			return
		fi
	done < <(pairs '.stateAliases')
	printf '%s\n' "$home/$relative"
}

# Do not follow arbitrary parent symlinks into another checkout or user tree.
parents() {
	local parent suffix old
	parent=$(dirname "$1")
	while [[ "$parent" != "$home" ]]; do
		[[ "$parent" == "$home/"* ]] || fail "path outside home: $parent"
		if [[ -L "$parent" ]]; then
			suffix=$(jq -r --arg p "${parent#"$home/"}" '.legacyDirectories[$p] // empty' "$manifest")
			legacy "$parent" "$suffix" && return
			old=$(jq -r --arg p "${parent#"$home/"}" '.stateAliases[$p] // empty' "$manifest")
			[[ -n "$old" && "$(readlink "$parent")" == "$home/$old" ]] || fail "unmanaged parent symlink: $parent"
		elif [[ -e "$parent" && ! -d "$parent" ]]; then
			fail "not a directory: $parent"
		fi
		parent=$(dirname "$parent")
	done
}

parents "$record"
[[ ! -L "$record" ]] || fail "manifest must not be a symlink: $record"
[[ ! -f "$record" ]] || previous=$(cat "$record")
jq -e 'type == "object" and all(to_entries[]; (.key | startswith("/") | not) and (.key | split("/") | index("..") | not) and (.value | type == "string"))' <<<"$previous" >/dev/null || fail "invalid previous link manifest: $record"
while IFS= read -r path; do parents "$home/$path"; done < <(jq -r 'keys[]' <<<"$previous")
while IFS=$'\t' read -r path suffix; do
	parents "$home/$path"
	if [[ -L "$home/$path" ]]; then
		legacy "$home/$path" "$suffix" || fail "unmanaged directory link: $home/$path"
		[[ ! -e "$home/$path.before-nix-darwin" && ! -L "$home/$path.before-nix-darwin" ]] || fail "backup already exists: $home/$path.before-nix-darwin"
	elif [[ -e "$home/$path" && ! -d "$home/$path" ]]; then
		fail "not a directory: $home/$path"
	fi
done < <(pairs '.legacyDirectories')

while IFS=$'\t' read -r new old; do
	parents "$home/$new"
	parents "$home/$old"
	# A native app may need its default path to alias an existing XDG directory.
	if [[ -L "$home/$old" && "$(readlink "$home/$old")" == "$home/$new" ]]; then
		[[ -d "$home/$new" && ! -L "$home/$new" ]] || fail "invalid reverse state alias: $home/$old"
		continue
	fi
	if [[ -L "$home/$new" ]]; then
		[[ "$(readlink "$home/$new")" == "$home/$old" && -d "$home/$old" && ! -L "$home/$old" ]] || fail "unmanaged state alias: $home/$new"
	elif [[ -d "$home/$new" && -e "$home/$old" ]]; then
		fail "both current and legacy state exist: $home/$new and $home/$old; reconcile them before switching"
	elif [[ -e "$home/$new" && ! -d "$home/$new" ]]; then
		fail "not a state directory: $home/$new"
	elif [[ ! -e "$home/$new" && -L "$home/$old" ]]; then
		fail "legacy state is a symlink: $home/$old"
	fi
done < <(pairs '.stateAliases')

while IFS=$'\t' read -r path target; do
	[[ -e "$target" ]] || fail "source missing: $target (check the checkout path)"
	destination=$(effective "$path")
	parents "$destination"
	# Files inside a retired Ansible directory remain behind its backup link.
	replaced=false
	while IFS=$'\t' read -r directory suffix; do
		if [[ "$path" == "$directory/"* ]] && legacy "$home/$directory" "$suffix"; then replaced=true; fi
	done < <(pairs '.legacyDirectories')
	"$replaced" && continue
	if [[ -L "$destination" ]]; then
		current=$(readlink "$destination")
		old=$(jq -r --arg p "$path" '.[$p] // empty' <<<"$previous")
		suffix=$(jq -r --arg p "$path" '.legacyLinks[$p] // empty' "$manifest")
		[[ "$current" == "$target" || "$current" == "$old" ]] || legacy "$destination" "$suffix" || fail "unmanaged link: $destination"
	elif [[ -e "$destination" ]]; then
		fail "local file would be overwritten: $destination; reconcile it before switching"
	fi
done < <(pairs '.links')

[[ "$mode" == apply ]] || exit 0
umask 077
while IFS=$'\t' read -r path suffix; do
	if legacy "$home/$path" "$suffix"; then mv "$home/$path" "$home/$path.before-nix-darwin"; fi
	mkdir -p "$home/$path"
done < <(pairs '.legacyDirectories')
while IFS=$'\t' read -r new old; do
	if [[ ! -e "$home/$new" && ! -L "$home/$new" && -d "$home/$old" ]]; then
		mkdir -p "$(dirname "$home/$new")"
		ln -s "$home/$old" "$home/$new"
	else
		mkdir -p "$home/$new"
	fi
done < <(pairs '.stateAliases')
mkdir -p "$home/.local/state/nix-darwin"
while IFS=$'\t' read -r path target; do
	mkdir -p "$(dirname "$home/$path")"
	ln -sfn "$target" "$home/$path"
done < <(pairs '.links')
# Remove only stale links still pointing to our previously recorded target.
while IFS=$'\t' read -r path target; do
	if ! jq -e --arg p "$path" '.links | has($p)' "$manifest" >/dev/null; then
		parents "$home/$path"
		if [[ -L "$home/$path" && "$(readlink "$home/$path")" == "$target" ]]; then rm "$home/$path"; fi
	fi
done < <(jq -r 'to_entries[] | [.key, .value] | @tsv' <<<"$previous")
jq '.links' "$manifest" >"$record.tmp"
mv "$record.tmp" "$record"
