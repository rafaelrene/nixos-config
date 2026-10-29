#!/usr/bin/env bash
# Credentials stay in the process environment, including when sudo preserves NIX_CONFIG.
set +x
if github_token=$(gh auth token --hostname github.com 2>/dev/null) &&
	[[ -n $github_token && $github_token != *[[:space:]]* ]]; then
	# Native append semantics keep explicitly configured credentials ahead of this fallback.
	export NIX_CONFIG="${NIX_CONFIG:+$NIX_CONFIG$'\n'}extra-access-tokens = github.com=$github_token"
fi
unset github_token
exec "$@"
