# Git helpers

Both workstations provide `git branches` to switch branches and `git db`
(also `git delete-branches`) to delete selected local branches and worktrees.

Run `git db` from any worktree. Each branch has one row, including its worktree
path when checked out. Deleting that row removes both. Detached worktrees have
separate rows. Remote branches are never deleted.

Every eligible row starts selected. Type to search; filtering does not deselect
hidden rows. The picker shows these shortcuts:

| Shortcut        | Action                                           |
| --------------- | ------------------------------------------------ |
| Tab / Shift+Tab | Toggle the current row and move down / up        |
| Ctrl+A          | Clear the search and select every row            |
| Ctrl+D          | Clear every selection, including hidden rows     |
| Enter           | Review selected deletions, then confirm with `y` |
| Esc             | Cancel                                           |

An empty selection or declining confirmation deletes nothing. The current branch
and worktree, the main worktree and its branch, and the default branch are
excluded. The default comes from the locally recorded `origin/HEAD`, falling
back to `main`, `master`, then the main worktree's branch.

`UNMERGED` marks commits not reachable from that default reference, or the current
`HEAD` if none is known. These rows also start selected, and their branches are
force-deleted after confirmation. Dirty or locked worktrees are refused and their
branches kept. Failed deletions produce a nonzero exit status; other selected
entries are still attempted. Entries changed while the picker was open are
skipped. Rebuild the system to install changes to these helpers.
