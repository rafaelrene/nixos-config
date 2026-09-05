# ADR 0005: Keep snapshots local

- Status: accepted
- Date: 2026-09-05

## Context

Btrfs snapshots recover deleted or damaged files and make local rollback cheap.
They do not protect against loss, theft, or failure of the machine and its
drives.

## Decision

Keep hourly home snapshots and replicate them to the local `/data` filesystem.
Keep daily `/data` snapshots. Do not configure an off-machine backup.

## Consequences

The snapshot policy helps with local mistakes but is not a backup against
machine-level loss. That loss risk is explicitly accepted.
