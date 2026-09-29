def main [
    default_checkout: string
    vendor_updater: path
    checkout?: string
    --stage-t3
] {
    let checkout = $checkout | default $default_checkout
    print "Updating Proserpina's Nix inputs..."
    ^nix flake update --flake $"path:($checkout)" flake-parts nixpkgs-darwin nixpkgs-unstable nix-darwin rust-overlay zen-browser helium-browser brew-nix brew-api
    print "Updating pinned vendor downloads..."
    ^nu --no-config-file $vendor_updater $checkout
    print "Updating T3 Code server and desktop..."
    if $stage_t3 {
        ^/nix/var/nix/profiles/system/sw/bin/update-t3code
    } else {
        ^/nix/var/nix/profiles/system/sw/bin/t3-update-now
    }
    print "Updating agent tools..."
    ^/nix/var/nix/profiles/system/sw/bin/update-llm-agents
    print "All update sources checked. Run ns to apply the updated Nix system, or use nups next time."
}
