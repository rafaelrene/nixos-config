# Shell helpers

## Project scripts

Run `prun` to fuzzy-search `package.json` scripts in the current directory and
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

Both machines install `prun` through the system rebuild. To try it from a
checkout before rebuilding, run this from a project directory:

```sh
nu --no-config-file /path/to/nixos-config/modules/shell/scripts/prun.nu
```

## Destination picker

`workstation-open` opens a searchable destination picker in Vicinae on Othinus
and Raycast on Proserpina. Use **Ctrl+Alt+P** on Linux. On the Mac, assign
**Control+Option+P** to Raycast's **Open destination** command in
Settings → Workstation destinations after rebuilding. Nix builds and registers
the local extension; no store publication or manual JavaScript build is needed.

The list contains Home, Code, Git projects below Code, `~/.config` and its
immediate application folders, plus SSH aliases `othinus` and `proserpina`.
Code is `/data/code` on Othinus and `/Users/rafael/code` on Proserpina. Hidden
grouping folders such as `.personal` are included. Ordinary folders are not
projects. Dependency/build caches and symlinks below Code are skipped; nested
repositories are left to `git nav`. Configuration-directory symlinks are included.

Enter focuses an identifiable matching Ghostty terminal, or opens a new window.
A project matches its directory and descendants; Home, Code and configuration
entries match only their exact directory. Matching uses canonical paths and
prefers the most recently focused window. No commands are typed into an existing
terminal. SSH selections always create a new connection in a new window.

To force a new local window, use **Cmd+Shift+Enter** or **Open New Window** in
Raycast's action panel. Vicinae provides an **Open new window · …** row for each
local destination. Esc cancels without opening anything.

Nushell sets prompt titles to `hostname: /full/path`. This distinguishes local
terminals from remote SSH shells. Start a fresh shell after rebuilding to load
the hook. macOS reads Ghostty's native terminal directories through AppleScript;
Linux uses Niri's window titles. Only titles identifying the local host are
reused. Programs that replace the title, old shell sessions, and other shells
can cause a new window to open. On Linux only the visible window title is
available, so hidden tabs and splits cannot be matched independently.

The shared implementation is in [destinations/](destinations/); the Mac picker
is in [the Raycast extension](../../darwin/destinations/). Both inherit their
launcher's theme. macOS may request Automation permission to control Ghostty;
an AppleScript error is shown rather than silently creating another window.

For terminal use and diagnostics:

```sh
workstation-open list
workstation-open open 'ssh:othinus'
workstation-open open 'home:/Users/rafael' --new-window
```

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
(or `git nav -w`) to make Enter and Ctrl+N open new windows too. On macOS, new
windows launch a separate Ghostty instance without restoring saved windows;
Linux uses Ghostty's new-window action.

Esc cancels. Ctrl+N opens worktree creation even when the search has no matches.
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
