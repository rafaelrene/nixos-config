# Git helpers

## Repository navigation

Run `git nav` in Nushell from any directory inside a checkout. Both workstations
provide the same searchable picker for local branches, worktrees, submodules,
the parent repository, and branch creation. Search matches destination names
and kinds; rows also show destination paths. Paths inside the current checkout
are relative to its root; other destinations show full paths. `●` marks the
current checkout.

| Selection                        | Result                                                                          |
| -------------------------------- | ------------------------------------------------------------------------------- |
| Branch checked out in a worktree | Enter that worktree.                                                            |
| Other local branch               | Switch branches in the main checkout, then enter it.                            |
| Detached worktree                | Enter its directory without switching branches.                                 |
| Submodule                        | Enter its checkout. Uninitialized submodules must be initialized first.         |
| Parent                           | Enter the containing repository's root.                                         |
| Create branch…                   | Ask for a name and starting point, then create and switch in the main checkout. |

The main checkout is the original working directory, regardless of its branch
name. Inside a submodule, branch operations use that submodule's main checkout.
From a submodule's linked worktree, Parent leads to the repository containing
its main checkout. Nested submodules can be traversed one level at a time.

Enter selects a destination; Esc cancels. Ctrl+N opens branch creation even when
the search has no matches. An empty branch name cancels; Ctrl+C cancels either
creation prompt. The starting point defaults to the invoking checkout's commit
when the picker opened, or accepts a branch, tag, or commit. Every new branch
opens in the main checkout, including when invoked from a linked worktree.

Git's normal switch checks preserve local changes. A failed switch or creation
leaves the shell in its original directory. The navigator does not fetch,
initialize submodules, create worktrees, or support bare repositories.
Repositories need an initial commit before creating another branch here.

`git nav` is a Nushell command, so directory changes persist in the calling
shell. Other Git subcommands run normally. Rebuild the system and start a fresh
Nushell to load it. To try the module from this checkout without rebuilding:

```nu
use ./modules/shell/nushell/git-nav.nu *
git nav
```

## Branch helpers

Both workstations also provide `git branches` to switch branches in the current
checkout and `git db` (also `git delete-branches`) to delete selected local
branches and worktrees. These helpers are linked into `$HOME/.local/bin`, which
both machines include in the shell's PATH. Devenv inherits that PATH.

Run `git db` from any worktree. Each branch has one row, including its worktree
path when checked out. Deleting that row removes both. Detached worktrees have
separate rows. Remote branches are never deleted.

Every eligible row starts selected. Type to search; filtering does not deselect
hidden rows. The picker shows these shortcuts:

| Shortcut        | Action                                                    |
| --------------- | --------------------------------------------------------- |
| Tab / Shift+Tab | Toggle the current row and move down / up                 |
| Ctrl+A          | Clear the search and select every row                     |
| Ctrl+D          | Clear every selection, including hidden rows              |
| Enter           | Review selected deletions, then confirm with Enter or `y` |
| Esc             | Cancel                                                    |

Confirmation defaults to Yes; enter `n` to cancel.
An empty selection or declining confirmation deletes nothing. The current branch
and worktree, the main worktree and its branch, and the default branch are
excluded. The worktree containing this shell's `DEVENV_ROOT` is also excluded,
even after changing directories: exit that devenv shell before deleting it.
This does not detect environments running in other terminals.
The default comes from the locally recorded `origin/HEAD`, falling
back to `main`, `master`, then the main worktree's branch.

`DIRTY` takes precedence over merge status when a worktree has staged, unstaged,
or untracked changes. Ignored files do not count. `UNKNOWN` means the worktree
could not be inspected. Commit comparison applies only to committed changes;
an unchanged branch at the default commit counts as `merged`.

`merged` means the branch is reachable from that default reference, its patches
were rebased/cherry-picked into it, its combined diff matches an upstream
squash commit, or it has no net changes since the common ancestor.
Comparison uses local refs without fetching; fetch first if the
remote has newer merges. If no default is known, comparison uses current `HEAD`.
Conflict resolutions that change patches can still show `UNMERGED`.
These rows also start selected, and their branches are
force-deleted after confirmation. Dirty or locked worktrees are refused and their
branches kept. Failed deletions produce a nonzero exit status; other selected
entries are still attempted. Entries changed while the picker was open are
skipped. Rebuild the system to install changes to these helpers.
