# ADR 0006: Expose T3Code only on the trusted LAN

- Status: accepted
- Date: 2026-09-05

## Context

Othinus and its clients currently share one trusted network. SSH already
provides administrative access. Remote access is useful later but is not needed
for the first deployment.

## Decision

Run the headless T3Code server on port 3773. Accept that port and SSH only from
`192.168.86.0/24`. Use direct HTTP and T3 Connect for now. Do not expose the
port to the internet.

## Consequences

T3Code works from local computers and phones. Access away from home waits for a
later Tailscale setup recorded in `TODO.md`.
