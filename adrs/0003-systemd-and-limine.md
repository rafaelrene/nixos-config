# ADR 0003: Keep systemd and use Limine for boot

- Status: accepted
- Date: 2026-09-05

## Context

NixOS integrates deeply with systemd as its service manager and init system.
Replacing it would mean leaving supported NixOS rather than selecting a normal
NixOS option. The bootloader is independent from the init system.

## Decision

Keep systemd as PID 1 and the service manager. Use Limine as the configured
bootloader with ten NixOS generations, checksum validation, and a five-second
menu. Retain the existing systemd-boot EFI files as a recovery path during the
migration.

## Consequences

Services use standard NixOS systemd modules. A previous NixOS generation is the
first rollback path. Changing the init system requires changing distributions.
