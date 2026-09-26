# Git helpers

Both workstations provide `git branches` to switch branches and `git db`
(also `git delete-branches`) to delete selected local branches and worktrees.
The helpers are linked into `$HOME/.local/bin`, which both machines include in
the shell's PATH. Devenv inherits that PATH. Start a fresh shell after rebuilding
to load PATH changes.

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
