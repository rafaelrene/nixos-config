# ADR 0006: Expose SSH and T3Code on the trusted LAN and tailnet

- Status: accepted
- Date: 2026-09-05
- Amended: 2026-09-10

## Context

Othinus and its clients initially shared one trusted network. Access away from
home is now required, while existing LAN access must keep working.

## Decision

Run the headless T3Code server on port 3773. Accept that port and OpenSSH on
port 22 from `192.168.86.0/24` and the `tailscale0` interface, subject to
tailnet access policy. Keep direct HTTP and the existing SSH keys. Do not expose
these service ports to the public internet.

Enable Tailscale through the native NixOS service and accept tailnet DNS.
Othinus is a regular tailnet device, not an exit node or subnet router; do not
enable Tailscale SSH. Enroll once through a browser and disable this device's
key expiry in the admin console. These are accepted exceptions to the
no-post-rebuild-steps preference. Keep credentials in Tailscale's local state,
outside the repository and Nix store.

## Consequences

SSH and T3Code work over both the LAN and the tailnet. Tailscale starts at boot
and reuses its saved login. The existing sleep policy remains: Othinus is
unreachable while suspended and reconnects after resume. MagicDNS names depend
on the tailnet's DNS configuration. Device enrollment and expiry settings remain
external to NixOS.
