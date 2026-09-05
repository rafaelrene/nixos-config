# ADR 0008: Do not enable Secure Boot

- Status: accepted
- Date: 2026-09-05

## Context

Secure Boot would require managing signing keys and signed boot artifacts. Its
main value here would be resisting an attacker with physical access who changes
the boot chain. Only Rene has physical access to Othinus.

## Decision

Leave Secure Boot disabled. Do not add Lanzaboote, custom signing keys, or a
similar signing workflow unless the physical-access model changes.

## Consequences

The firmware does not verify the bootloader or kernel. An attacker with physical
access could modify the boot path. This risk is explicitly accepted.
