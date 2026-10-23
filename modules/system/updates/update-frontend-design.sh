#!/usr/bin/env bash
set -euo pipefail

checkout=${1:?A checkout is required}
upstream_ref=$(jq -er '
  .nodes[.nodes.root.inputs["anthropic-skills"]].locked |
  "github:\(.owner)/\(.repo)/\(.rev)?narHash=\(.narHash | @uri)"
' "$checkout/flake.lock")
upstream=$(nix flake prefetch --json "$upstream_ref" | jq -er '.storePath')
source="$upstream/skills/frontend-design"
destination="$checkout/config/agents/skills/frontend-design"
test -s "$source/SKILL.md"

# Stage the entire pinned skill, including its license and supporting files.
staged=$(mktemp -d "${destination}.XXXXXX")
trap 'rm -rf -- "$staged"' EXIT
cp -R -- "$source/." "$staged/"
chmod -R u+w "$staged"

# Replace the directory so removed upstream files do not linger; keep it editable.
rm -rf -- "$destination"
mv -- "$staged" "$destination"
printf 'Updated frontend-design from the pinned Anthropic skills source.\n'
