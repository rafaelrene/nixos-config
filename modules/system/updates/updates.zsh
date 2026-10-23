set -euo pipefail

default_checkout=$1
skill_updater=$2
shift 2
checkout=${1:-$default_checkout}

nix flake update --refresh --flake "$checkout"
# Keep the upstream skill editable alongside the other live agent settings.
zsh -f "$skill_updater" "$checkout"

system_bin=/nix/var/nix/profiles/system/sw/bin
if [[ -x $system_bin/update-llm-agents ]]; then
  "$system_bin/update-llm-agents" --stage --flake "$checkout"
fi
if [[ -x $system_bin/update-t3code ]]; then
  "$system_bin/update-t3code" --flake "$checkout"
fi
