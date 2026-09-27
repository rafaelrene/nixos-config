# Coding-agent updates

Both hosts install Codex, Claude Code and OpenCode from Numtide's
`llm-agents.nix`. `update-llm-agents` runs during `nup`/`nups` after T3 Code,
and through each host's scheduled agent service. Agent versions update
independently of the system's `flake.lock` and do not require a system rebuild.

## Update flow

The updater follows T3 Code's shared package-factory pattern. It uses an immutable
snapshot of this repository and its locked dependencies, exporting
`legacyPackages.<system>.llmAgentsForSource` through flake-parts. A system rebuild
installs changes to the factory and updater.

`nix flake prefetch --refresh` resolves and downloads one Numtide source without
evaluating it. The updater passes that store path and content hash to the factory,
which loads the package definitions with `builtins.getFlake`. This does not apply
Numtide's `nixConfig`. The system supplies the binary caches and signing keys;
global flake-config acceptance and daemon permissions stay unchanged. Nix errors,
build logs and the system flake's lock-file update notices remain visible.

The factory combines the three packages and records their versions and source
in `share/llm-agents/release.json` inside the generation. Package build checks
remain enabled. All packages must build before the updater changes
`~/.local/state/nix/profiles/llm-agents`. A failed fetch, evaluation or build leaves
the previous generation installed; the first installation requires success.
An identical result skips building and installing, while a changed factory can
produce a new generation even when the upstream source is unchanged.

Updates hold `~/.local/state/nix/profiles/llm-agents-updater/update.lock` from
discovery through installation so scheduled and manual runs do not overlap.
There is no generated flake, extra lock file or mutable package recipe.
An existing profile is replaced only after a successful bundle build, retaining
its previous generations. The profile is reserved for these three agent tools.

## Inspection and rollback

Read `~/.local/state/nix/profiles/llm-agents/share/llm-agents/release.json` for the
installed versions and pinned source. The profile holds a bundle, so
`nix profile list` and `nix profile upgrade` do not manage its individual agents;
use `update-llm-agents` to update it.

List retained generations with:

```sh
nix-env --profile ~/.local/state/nix/profiles/llm-agents --list-generations
```

Restore the previous generation with:

```sh
nix-env --profile ~/.local/state/nix/profiles/llm-agents --rollback
```

All three agents roll back together. Already running agents and their data are
unaffected; newly launched agents use the selected generation. The next scheduled
or manual update can install the latest packages again.
