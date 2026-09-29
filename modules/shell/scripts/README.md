# Shell helpers

## Shell leader

Both machines use Nushell's Vi editing mode. Press Esc for normal mode and `i`
to insert text. In normal mode, Space shows these choices; press the second key
without Enter:

| Keys        | Command       | Action                              |
| ----------- | ------------- | ----------------------------------- |
| Space Space | `nav`         | Pick a directory or SSH host.       |
| Space n     | `git nav`     | Navigate the current repository.    |
| Space p     | `project-run` | Pick and run a package.json script. |

Esc, Ctrl+C, or an unlisted key cancels the leader menu. The command line you
were editing stays intact. Space inserts ordinary spaces in insert mode.
These bindings only run at the Nushell prompt; Neovim and other foreground
programs handle their own keys.
Rebuild and start a fresh Nushell to load the bindings.

## Project scripts

Run `project-run` to fuzzy-search `package.json` scripts in the current directory and
its parents, stopping at the Git repository root. Rows show the script name,
package path relative to that root, and command. The nearest package appears
first; sibling packages are not scanned. Outside Git, only the current
directory is checked.

Enter runs the selected script in its package directory, in the current
terminal. Esc cancels. The calling shell keeps its directory. Interactive
input, Ctrl+C, output and the script's exit status pass through normally.

The runner checks `packageManager`, then lockfiles, starting at the selected
package and walking toward the repository root. It supports npm, pnpm, Yarn
and Bun, with npm as the fallback. The command uses the current environment
and PATH, so enter the project's development environment first. It does not
install package managers or dependencies. Malformed manifests are reported.

Both machines install `project-run` through the system rebuild. To try it from a
checkout before rebuilding, run this from a project directory:

```sh
nu --no-config-file /path/to/nixos-config/modules/shell/scripts/project-run.nu
```

## Destination picker

Run `nav` or press **Space Space** in normal mode at a Nushell prompt on either
machine. The fzf picker runs in the current terminal and uses
the shared fzf theme. The shortcut preserves any partially typed command and
only runs at the shell prompt, not while an editor or another program is active.

The list contains Home, Code, Git projects below Code, `~/.config` and its
immediate application folders, plus SSH aliases `othinus` and `proserpina`.
Code is `/data/code` on Othinus and `/Users/rafael/code` on Proserpina. Hidden
grouping folders such as `.personal` are included. Ordinary folders are not
projects. Dependency/build caches and symlinks below Code are skipped; nested
repositories are left to `git nav`. Configuration-directory symlinks are included.

Enter changes the current shell's directory or runs `ssh` for the selected host.
Exiting SSH returns to the local shell in its original directory. Esc cancels
without changing directory or starting a connection. To use a separate terminal,
open one first, then run `nav`.

`nav` is an environment-changing Nushell command, like `git nav`, so directory
changes persist in the calling shell. Rebuild and start a fresh Nushell to load
the command and shortcut. The implementation lives in
[navigation.nu](../../applications/nushell/navigation.nu); the Nushell feature supplies each
host's Home and Code paths through generated settings.

On macOS, Raycast can retain a registered **Workstation destinations** extension
and its global hotkey after Nix removes the managed extension link. Remove that
entry in Raycast Settings → Extensions if present to clear the obsolete command
and hotkey.

## Repository navigation

Run `git nav` in Nushell from any directory inside a checkout. Both workstations
provide the same searchable picker for local branches, worktrees, submodules,
the parent repository, and worktree creation. Search matches destination names
and kinds; rows also show destination paths. Paths inside the current checkout
are relative to its root; other destinations show full paths. `●` marks the
current checkout. The original checkout is labelled `main`; linked checkouts
are labelled `worktree` (or `detached` when no branch is checked out).

| Selection                               | Result                                                                  |
| --------------------------------------- | ----------------------------------------------------------------------- |
| Main checkout                           | Enter the original checkout.                                            |
| Branch checked out in a linked worktree | Enter that worktree.                                                    |
| Other local branch                      | Switch branches in the main checkout, then enter it.                    |
| Detached worktree                       | Enter its directory without switching branches.                         |
| Submodule                               | Enter its checkout. Uninitialized submodules must be initialized first. |
| Parent                                  | Enter the containing repository's root.                                 |
| Create worktree…                        | Ask for a name, then create and enter a worktree with a new branch.     |

The main checkout is the original working directory, regardless of its branch
name. Inside a submodule, branch operations use that submodule's main checkout.
From a submodule's linked worktree, Parent leads to the repository containing
its main checkout. Nested submodules can be traversed one level at a time.

Enter selects a destination in the current shell; Ctrl+T opens it in a new
Ghostty window and keeps the calling shell's directory. Run `git nav --new-window`
(or `git nav -w`) to make Enter open new windows too. On macOS, new
windows launch a separate Ghostty instance without restoring saved windows;
Linux uses Ghostty's new-window action.

Ctrl+N and Ctrl+P move to the next and previous rows. Esc cancels.
Select the first row, **Create worktree…**, to create a worktree; Enter enters
it in the current shell, while Ctrl+T opens it in a new window.
An empty name or Ctrl+C cancels the prompt. Entering a name immediately
creates a worktree and matching branch from the invoking checkout's commit when
the picker opened. There is no starting-point prompt. The main checkout and its
local changes stay untouched.

New worktrees use T3 Code's layout:
`$T3CODE_HOME/worktrees/<main-checkout-name>/<worktree-name>`, defaulting to
`~/.local/share/t3code` when `T3CODE_HOME` is unset. On Proserpina, this resolves
to `~/.t3/worktrees/` through the existing alias. Slashes in branch names become
hyphens in directory names, so `feature/login` uses `feature-login`. No random
suffix is added. Existing branch names and destination paths are rejected.

Git's normal switch checks preserve local changes. A failed switch or creation
leaves the shell in its original directory. Opening an existing branch in a new
window still switches that branch in its checkout. Creating a worktree opens
the new checkout instead.
If window launch fails, completed Git operations remain in effect.
The navigator does not fetch,
initialize submodules or support bare repositories.
Repositories need an initial commit before creating a worktree here.

`git nav` is a Nushell command, so directory changes persist in the calling
shell. Other Git subcommands run normally. Rebuild the system and start a fresh
Nushell to load it. To try the module from this checkout without rebuilding:

```nu
use ./modules/applications/nushell/git-nav.nu *
git nav
```

## Branch helpers

Both workstations also provide `git branches` to switch branches in the current
checkout and `git db` (also `git delete-branches`) to delete selected local
branches and worktrees. Both machines install these Nushell helpers as system
packages; they also work when invoked from other shells. `git branches` includes
remote branches and accepts a branch name to skip its picker.

Run `git db` from any worktree. Each branch has one row, including its worktree
path when checked out. Deleting that row removes both. Detached worktrees have
separate rows. Remote branches are never deleted.

Only entries that pass normal deletion checks start selected. Dirty, locked,
unmerged, unreadable, and submodule-blocked entries start unselected and show
the reason. Type to search; filtering does not deselect hidden rows.
The picker shows these shortcuts:

| Shortcut  | Action                                                              |
| --------- | ------------------------------------------------------------------- |
| Tab       | Cycle highlighted row: unselected → selected → force → unselected   |
| Shift+Tab | Cycle the highlighted row in reverse                                |
| Up / Down | Move between rows                                                   |
| Ctrl+F    | Toggle force for all entries that require it, including hidden rows |
| Ctrl+A    | Clear the search and select every row                               |
| Ctrl+D    | Clear every selection and force flag, including hidden rows         |
| Enter     | Review selected deletions, then confirm with Enter or `y`           |
| Esc       | Cancel                                                              |

Confirmation defaults to Yes; enter `n` to cancel.
An empty selection or declining confirmation deletes nothing. The current branch
and worktree, the main worktree and its branch, and the default branch are
excluded. The worktree containing this shell's `DEVENV_ROOT` is also excluded.
Change directories and let direnv unload before deleting it. If using an explicit
devenv subshell, exit that shell first.
This does not detect environments running in other terminals.
The default comes from the locally recorded `origin/HEAD`, falling
back to `main`, `master`, then the main worktree's branch.

`DIRTY` marks uncommitted changes, including untracked files; ignored files do
not count. `LOCKED` marks locked worktrees. `BLOCKED` means inspection failed
or submodule data needs preserving. The reason appears beside the row.

`merged` means the branch is reachable from the default reference, its patches
were rebased/cherry-picked into it, its combined diff matches an upstream
squash commit, or it has no net changes since the common ancestor.
Comparison uses local refs without fetching; fetch first if the remote has
newer merges. If no default is known, comparison uses current `HEAD`.
Conflict resolutions that change patches can still show `UNMERGED`.
Unmerged branches require force, including branches without worktrees.

Normal deletion checks each initialized submodule recursively for uncommitted
changes. It also checks submodule Git repositories, including those left behind
by deinitialization, for stashes and commits reachable from HEAD, local refs or
reflogs but absent from locally recorded remote branches. Preserve that history
elsewhere, or fetch the submodule's remote if it has already been pushed.
These checks do not fetch automatically. Clean submodule worktrees that pass
are removed with one `--force`, which Git requires for submodules. Ignored files
are removed with their worktree.

**Tab** cycles the highlighted row through unselected, selected, `[FORCE]`, and
back to unselected. **Shift+Tab** cycles in reverse. Both keep the cursor on
that row; use the arrow keys to move. Every row supports all three states.

**Ctrl+F** selects and enables force for every entry that requires it, including
rows hidden by the search. If all such entries are already selected with force,
it deselects them and clears their force flags. Other entries keep their state.
Search and hidden selections survive state changes. **Ctrl+D** clears all
selections and force flags. The confirmation lists force entries explicitly.
Force skips all pre-deletion rechecks and removes the worktree with
`git worktree remove --force --force`, then deletes its branch with `git branch -D`.
This discards uncommitted changes, unmerged commits and private submodule
history, and bypasses worktree locks. The excluded current, main, default and
active devenv entries remain unavailable in the picker.

A blocked entry in the ordinary selected state is skipped with a reason; cycle
it to `[FORCE]` to delete it. Ctrl+A selects all entries without enabling force. Normal entries are checked again before removal,
and entries changed while the picker was open are skipped. Stop processes writing
to selected worktrees before confirming, since inspection and removal are not atomic.

Inspection and worktree removal each run up to eight entries concurrently.
Completed worktree removals print progress. Branch deletion runs sequentially
afterward to avoid contention on shared Git configuration. A branch is kept if
its worktree cannot be removed. The final summary counts deleted, skipped and
failed entries. Skipped or failed deletions produce a nonzero exit status;
other selected entries are still attempted. Rebuild the system to install changes.
