---
name: remove-skill
description: Use when the user wants to remove or delete an existing skill from the workstation’s shared agent configuration and from every agent it is symlinked into.
disable-model-invocation: true
---

# Remove a skill

Use the checkout and rebuild command for the current host:

| Host | `<checkout>` | Rebuild command |
| --- | --- | --- |
| Othinus (NixOS) | `/data/code/nixos-config` | `sudo nixos-rebuild switch --flake path:/data/code/nixos-config#othinus` |
| Proserpina (macOS) | `/Users/rafael/code/.personal/nixos-config` | `sudo darwin-rebuild switch --flake path:/Users/rafael/code/.personal/nixos-config#Proserpina` |

If working in a worktree, edit that checkout. Distribution uses the host's
declared checkout after the changes reach it. Do not activate either host
without explicit permission.

Delete a skill from `<checkout>/config/agents/skills/` and clean up what referenced
it. Both systems discover shared skills by directory and prunes obsolete managed links
on the next rebuild. Do not remove links by hand; unrelated and built-in skills
are preserved.

Do not delete or modify anything until the user has approved the removal plan.

## Resolve the target

Confirm which skill to remove. If the user did not name one, list
`<checkout>/config/agents/skills/` and ask. If the named skill is not there, say it
does not exist and stop.

## Find stale references

Search `<checkout>` for the skill's name, excluding its own directory. Expect
hits in:

- `config/agents/AGENTS.md`
- `config/agents/opencode/opencode.jsonc`
- other `SKILL.md` bodies that invoke the skill

Record each hit with its file, line, and surrounding text. Do not edit yet.

## Present the plan

Show the source directory to delete and how many files it holds, then every
stale reference with its file and line.

Ask once for approval to delete the source directory. Reference edits are a
separate decision, so keep them out of that approval.

## Execute

1. Delete the source directory.
2. For each stale reference, show the exact edit you propose and apply it only
   after the user agrees. Removing a mention from prose may need rewording
   rather than deletion.

## Verify and report

Show the resulting `git diff` and `git status`. Do not commit, push, or activate
the system. Tell the user to run the host's rebuild command above to prune the
removed skill’s links, then restart agents to refresh discovery.
