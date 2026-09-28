# Project environments

Both hosts use stock devenv and direnv packages from the same pinned
`nixpkgs-unstable` input, keeping their versions aligned. The shared Nushell
configuration checks direnv before each prompt. No Rust source patch is applied
to devenv.

## Setup

Declare project tools in `devenv.nix` and put this in the project's `.envrc`:

```bash
use devenv
```

Direnv automatically trusts `.envrc` files beneath these directories:

- Othinus: `/home/raf/.local/share/t3code/worktrees/`.
- Proserpina: `/Users/rafael/.t3/worktrees/` and its
  `/Users/rafael/.local/share/t3code/worktrees/` alias.

New worktrees and changes to `.envrc` in these directories need no approval.
Their shell code runs automatically when direnv loads the environment.
Regular checkouts and worktrees elsewhere still require `direnv allow` and
reapproval after changing `.envrc`.
The shared direnv feature declares `programs.direnv.settings.whitelist.prefix`;
the native NixOS/nix-darwin modules install it in `/etc/direnv/direnv.toml`.

The workstation supplies `use_devenv` through `/etc/direnv/lib/devenv.sh`; do not
replace it with `eval "$(devenv direnvrc)"` in `.envrc`, which would bypass the
watch-list correction below. This repository already includes `.envrc`.

Use `devenv shell -- <command>` for noninteractive commands. Agent launchers
retain this entry path when they are not already inside the project's environment.
Avoid interactive `devenv shell` in Nushell: upstream's shared reload helper can
consume another session's pending update. Direnv does not use that helper.

## Reload behavior

- Configuration edits reload at the next prompt. Rebuilding the environment can
  delay that prompt; there is no background reload status bar.
- Leaving the project restores the preceding environment in the same shell.
- A failed devenv evaluation can unload the project environment. Fix the
  configuration and return to the prompt to reload it.
- An already-running program keeps its inherited environment. Restart it to
  pick up changes.

The Nushell hook applies only direnv's changes, converts PATH back into a list,
and removes variables that direnv unsets. It replaces native devenv activation;
do not install a second `devenv hook nu` alongside it.

## Integration maintenance

`default.nix` generates the Bash integration with `devenv direnvrc` during the
Nix build. It corrects the watch-list reader to include an unterminated final
line: devenv writes `input-paths.txt` without a trailing newline, so the original
reader misses its last dependency. This correction changes only the generated
script and preserves the cached devenv binary.

The substitution fails the build if its expected source changes. Recheck it on
devenv updates and remove the correction when upstream reads the complete list.
The direnv feature uses native NixOS/nix-darwin options with nix-direnv disabled;
devenv supplies its own integration.
