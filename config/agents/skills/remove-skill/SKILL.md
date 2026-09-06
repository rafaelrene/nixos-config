---
name: remove-skill
description: Use when the user wants to remove or delete an existing skill from Othinus’s shared agent configuration and from every agent it is symlinked into.
disable-model-invocation: true
---

# Remove a skill

Delete a skill from `/data/code/nixos-config/config/agents/skills/` and clean up what referenced
it. NixOS discovers shared skills by directory and prunes obsolete managed links
on the next rebuild. Do not remove links by hand; unrelated and built-in skills
are preserved.

Do not delete or modify anything until the user has approved the removal plan.

## Resolve the target

Confirm which skill to remove. If the user did not name one, list
`/data/code/nixos-config/config/agents/skills/` and ask. If the named skill is not there, say it
does not exist and stop.

## Find stale references

Search `/data/code/nixos-config` for the skill's name, excluding its own directory. Expect
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
the system. Tell the user to run
`sudo nixos-rebuild switch --flake path:/data/code/nixos-config#othinus`
to prune the removed skill’s links, then restart agents to refresh discovery.
