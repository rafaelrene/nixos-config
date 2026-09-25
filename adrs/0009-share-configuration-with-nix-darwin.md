# ADR 0009: Share application configuration with nix-darwin

- Status: accepted
- Date: 2026-09-20

## Context

Proserpina's macOS configuration is moving from Ansible into this repository.
Othinus's behavior and the Ansible checkout must remain unchanged.

## Decision

Use a separate nix-darwin host with its own stable Darwin Nixpkgs base. Select
newer desktop and tool packages from a separate `nixpkgs-unstable` input. Keep
portable package and configuration generators beside their existing features.
Import them explicitly from each platform's modules; keep systemd, launchd,
desktop applications, and host identity separate.

Continue without Home Manager. On macOS, an approved user-scoped activation
hook installs configuration links, recognizes the old Ansible links, preserves
their directory targets, and refuses unrelated conflicts. A separate approved
activation statement changes the existing account's login shell to Nushell
without making nix-darwin responsible for creating or deleting the account.

Use XDG paths for new application state. Existing agent homes remain in place
behind XDG aliases during migration. Raycast scripts use
`~/.local/share/raycast/scripts`; existing Ansible links remain untouched.
State aliases are exceptions to the clean-home preference. A fresh Mac also
links `~/.t3` to its XDG state: macOS can restore the signed desktop before
launchd supplies environment variables, and both paths must find client-only
settings.

Reuse the rolling Nix agent updater with a launchd schedule. Prefer Nix packages
for Mac desktop apps and CLI tools. Use brew-nix to turn pinned cask metadata
into Nix packages where Nixpkgs lacks a suitable Mac release. Homebrew itself is
not required. Package Google Drive's Apple Silicon payload and Viber's complete
app directly; `nup` refreshes their otherwise unversioned URLs into a version/hash
manifest tracked in this repository. The approved migration cleanup only removes
known Brew replacements and preserves application data and unrelated packages.
Keep cleanup disabled for the first activation; enable
`workstation.removeReplacedHomebrewPackages` after validating the replacements.
Vendor integration and updater preferences change with that final handover.
Package matching T3Code
nightly server/client artifacts in an independent Nix profile, with launchd
managing the server and the desktop acting only as a client. Othinus's boot, disk,
snapshot, service exposure, and desktop decisions apply only to Othinus.

Proserpina also trusts Numtide's signed binary cache for its rolling agent
packages, as documented in the migration guide. This is a Mac-specific exception
to ADR 0007's cache list; Othinus's trusted caches remain unchanged.

## Consequences

Shared application settings can evolve together, while platform differences
remain explicit. Darwin package updates do not update the Linux Nixpkgs pin;
the shared Rust and browser inputs still affect both hosts after a rebuild. The Mac’s `nup` covers all
package sources and rolling tools; `nups` also applies the updated system.
Cask metadata is pinned in `flake.lock`; vendor exceptions are pinned in
`modules/darwin/vendor-sources.json`. nix-darwin installs real app copies under
`/Applications/Nix Apps`. Compatibility links accommodate fixed vendor paths;
Google Drive's mount helper gets the vendor-required permissions only in the
installed copy. Othinus’s update behavior remains unchanged.

Test macOS activation inside a disposable VM before deployment. Building or
running that VM does not authorize applying the configuration to its host.
