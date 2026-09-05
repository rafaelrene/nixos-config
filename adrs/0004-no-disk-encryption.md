# ADR 0004: Do not add disk encryption

- Status: accepted
- Date: 2026-09-05

## Context

Only Rene has physical access to Othinus. Retrofitting encryption would add a
boot-time secret, migration risk, and recovery complexity without addressing a
threat in the accepted model.

## Decision

Leave the system and data filesystems unencrypted. Do not revisit encryption
unless the physical-access model or the sensitivity of stored data changes.

## Consequences

Someone who obtains the disks can read them offline. This risk is explicitly
accepted. Snapshots do not provide confidentiality.
