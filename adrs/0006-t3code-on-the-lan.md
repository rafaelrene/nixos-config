# ADR 0006: Keep Othinus's service access private

- Status: accepted
- Date: 2026-09-05
- Amended: 2026-09-26

## Context

Othinus needs remote access from home and away.

## Decision

Allow direct SSH and T3Code access over the trusted LAN and Tailscale. Do not
expose their listening ports directly to the public internet.

## Consequences

Direct access from outside the LAN requires tailnet access. Ports, firewall
rules, and enrollment instructions belong beside the relevant services.
