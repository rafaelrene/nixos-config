set -euo pipefail

default_checkout=$1
vendor_updater=$2
shift 2
checkout=$default_checkout
stage_t3=false
checkout_supplied=false

for argument in "$@"; do
	case "$argument" in
	--stage-t3) stage_t3=true ;;
	--help | -h)
		print -r -- 'Usage: nix-update-packages [checkout] [--stage-t3]'
		exit 0
		;;
	--*)
		print -u2 -r -- "Unknown option: $argument"
		exit 1
		;;
	*)
		if $checkout_supplied; then
			print -u2 -r -- 'Only one checkout may be supplied.'
			exit 1
		fi
		checkout=$argument
		checkout_supplied=true
		;;
	esac
done

print -r -- "Updating Proserpina's Nix inputs..."
nix flake update --flake "$checkout" flake-parts nixpkgs-darwin nixpkgs-unstable nix-darwin rust-overlay zen-browser helium-browser brew-nix brew-api
print -r -- 'Updating pinned vendor downloads...'
zsh -f "$vendor_updater" "$checkout"
print -r -- 'Updating T3 Code server and desktop...'
if $stage_t3; then
	/nix/var/nix/profiles/system/sw/bin/update-t3code
else
	/nix/var/nix/profiles/system/sw/bin/t3-update-now
fi
print -r -- 'Updating agent tools...'
/nix/var/nix/profiles/system/sw/bin/update-llm-agents
print -r -- 'All update sources checked. Run ns to apply the updated Nix system, or use nups next time.'
