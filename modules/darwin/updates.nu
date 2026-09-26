def main [default_checkout: string, vendor_updater: path, checkout?: string] {
    let checkout = $checkout | default $default_checkout
    print "Updating Proserpina's Nix inputs..."
    ^nix flake update --flake $"path:($checkout)" nixpkgs-darwin nixpkgs-unstable nix-darwin rust-overlay zen-browser helium-browser brew-nix brew-api try-rs
    print "Updating pinned vendor downloads..."
    ^nu --no-config-file $vendor_updater $checkout
    print "Updating T3 Code server and desktop..."
    ^/nix/var/nix/profiles/system/sw/bin/t3-update-now
    print "Updating agent tools..."
    ^/nix/var/nix/profiles/system/sw/bin/update-llm-agents
    print "All update sources checked. Run ns to apply the updated Nix system, or use nups next time."
}
