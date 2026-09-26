# Raycast recovery

Raycast 2.4.1 cannot open Proserpina's databases after its previous app updated
them to 2.5.2. This caused the “Raycast failed to restart” alert. The minimum
version override in [packages.nix](../../modules/darwin/packages.nix) preserves
the signed upstream bundle; newer Nixpkgs versions take precedence automatically.
Do not downgrade the app or reset its databases to resolve this error.

The 2.5.2 package passed signature verification, opened all 11 existing
databases, and worked with the saved Command-Space hotkey. The September 25
check ran from the Nix store. Confirm the current installed version before
deciding whether an authorized system switch is still needed.

After replacing the installed bundle, quit the old process, open
`/Applications/Nix Apps/Raycast.app`, and verify Command-Space and the login-item
path. A login item registered by a Nix-store launch may retain that store path.
Login startup was not checked during recovery.

Private preferences and application data backups remain at
`~/.local/state/nix-darwin/backups/raycast-2026-09-25`. Keep them outside the
repository and Nix store. No data, hotkey, or permission reset was needed.
