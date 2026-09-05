# ADR 0002: Keep the home directory clean

- Status: accepted
- Date: 2026-09-05

## Context

Applications often create top-level dotfiles and state directories by default.
They make the home directory harder to understand and back up selectively.

## Decision

Use XDG locations wherever the application permits it:

- Configuration: `/home/raf/.config`
- Data: `/home/raf/.local/share`
- State: `/home/raf/.local/state`
- Cache: `/home/raf/.cache`
- User executables: `/home/raf/.local/bin`

Do not add files or directories directly under `/home/raf` unless an
application cannot be redirected or the directory is user content such as
`Pictures`.

## Consequences

T3Code, Codex, Claude, profiles, and related state use explicit XDG paths.
Exceptions must be documented when introduced.
