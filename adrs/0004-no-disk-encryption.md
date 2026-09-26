# ADR 0004: Do not add disk encryption

- Status: accepted
- Date: 2026-09-05
- Amended: 2026-09-26

## Context

Othinus's filesystems are unencrypted. Retrofitting encryption would require a
storage migration and an unlock and recovery strategy.

## Decision

Leave Othinus's filesystems unencrypted. Reconsider if physical-access risks or
the sensitivity of stored data change. This decision does not cover Proserpina.

## Consequences

Anyone who obtains the disks can read their contents. This risk is accepted.
