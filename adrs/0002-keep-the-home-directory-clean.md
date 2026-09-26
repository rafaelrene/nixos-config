# ADR 0002: Keep the home directory clean

- Status: accepted
- Date: 2026-09-05
- Amended: 2026-09-26

## Context

Scattered application files make the home directory harder to navigate and
maintain.

## Decision

Prefer XDG locations for tools that support them. Use paths relative to the
user's home. Accept platform-native locations and compatibility paths when
relocation would add complexity or disrupt existing data.

## Consequences

Home stays reasonably tidy without requiring every application to follow one
layout. Document necessary exceptions beside the relevant feature.
