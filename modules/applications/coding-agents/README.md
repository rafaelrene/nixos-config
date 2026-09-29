# Coding-agent updates

Both hosts install Codex and Claude Code from their publishers' latest stable
release channels. Codex uses `releases.openai.com/codex/channels/latest`; Claude
uses Anthropic's `claude-code-releases/latest` download pointer and versioned
manifest. Each check resolves these channels afresh, including publisher rollbacks.
Numtide's `llm-agents.nix` supplies OpenCode and Claude's platform integration;
its version pins do not delay Codex or Claude updates.

## Update flow

The updater uses an immutable snapshot of this repository and its locked
dependencies, exporting `legacyPackages.<system>.llmAgentsForSource` through
flake-parts. A system rebuild installs changes to the factory, updater and
schedule. Agent releases update independently of the system's `flake.lock`.

Publisher metadata supplies versions and SHA-256 checksums. Nix verifies every
archive or binary against its checksum. Codex retains its complete official
package layout, including the code-mode host and companion resources. Claude
retains Numtide's wrappers, version check and publisher signature check.
Package build checks remain enabled.

`nix flake prefetch --refresh` resolves one immutable Numtide source without
applying its `nixConfig`. The system supplies the binary caches and signing keys;
global flake-config acceptance and daemon permissions stay unchanged. The
factory records the source, publisher releases, checksums and installed versions
in `share/llm-agents/release.json` inside the generation.

All three packages must build before the updater changes
`~/.local/state/nix/profiles/llm-agents-staged`. Failed discovery, checksum
verification, evaluation or builds leave both staged and active profiles unchanged.
An identical staged generation skips building and installing; factory changes
can produce a new generation even when versions are unchanged.

Updates and activation share
`~/.local/state/nix/profiles/llm-agents-updater/update.lock`, so scheduled and
manual runs cannot overlap. Both profiles retain Nix generations for rollback.
There is no generated flake, extra lock file or mutable package recipe.

## Scheduling and manual use

Both hosts check and stage updates at login and every three hours, then activate
the staged generation at 04:00 local time. Failed checks retry after five minutes.
The first successful check also initializes a missing active profile.

- `update-llm-agents` checks, builds, stages and activates immediately.
- `nup` and `nups` run that command after their T3 Code update step, so they
  resolve the publishers' latest releases on every invocation. A failed update
  stops the command instead of silently accepting an older release.
- `update-llm-agents --stage` checks and builds without changing an existing
  active profile.
- `update-llm-agents --activate` promotes the staged generation without network
  access. The 04:00 job uses this mode.

Activation changes `~/.local/state/nix/profiles/llm-agents` for newly launched
agents. Running agents and their data are unaffected. No service restart or
system rebuild is needed to select a new agent generation.

On Othinus, inspect `llm-agents-update.service` and
`llm-agents-activate.service` with `journalctl --user`. On Proserpina, logs are
`~/.local/state/nix-darwin/agents-update.log` and `agents-activation.log`.

## Inspection and rollback

Read `~/.local/state/nix/profiles/llm-agents/share/llm-agents/release.json` for the
active versions and release metadata; use the corresponding `llm-agents-staged`
path for pending updates. The profiles hold bundles, so `nix profile upgrade`
does not manage individual agents.

List retained active generations with:

```sh
nix-env --profile ~/.local/state/nix/profiles/llm-agents --list-generations
```

Restore the previous generation with:

```sh
nix-env --profile ~/.local/state/nix/profiles/llm-agents --rollback
```

All three agents roll back together. The next manual update or 04:00 activation
can select the staged release again. To retain an older selection for activation,
select its generation in `llm-agents-staged` too; the next background check can
still stage the latest releases.
