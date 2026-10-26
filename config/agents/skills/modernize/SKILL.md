---
name: modernize
description: Use when asked to modernize a PR or branch.
disable-model-invocation: false
---

# Modernize

Check whether the change still makes sense before updating its branch.

## Assess

- Read repository instructions, local changes, the full diff, and review context.
  Use T3 tools, then authenticated `gh` or `bkt` for GitHub or Bitbucket.
- Establish the original goal. Fetch relevant remotes. Record the actual target,
  original head, merge base, and remote head.
- Check newer work for replacements, changed contracts, moved ownership, and
  behavior that should not be restored.
- Inspect related repositories and submodule pointers. Preserve unrelated work
  and authorship. Use a safe checkout under session worktree rules when needed.
- For GroupSolver edits, read the guides in
  [review-changes](../review-changes/SKILL.md#groupsolver-guides).

Choose:

- MODERNIZE: the goal and implementation still fit.
- REWORK: propose the smallest rewrite. Proceed only if authorized.
- CLOSE: explain why the work is obsolete. Recommend closure; do not close it.

## Update

- Follow repository merge or rebase conventions.
- Commit or push only when authorized, including by full-stop. Stop before
  creating or rewriting commits without that authority.
- Resolve conflicts against current intent. Ask about unresolved product decisions.
- Inspect the final diff. After rebasing, use `git range-diff` to verify intent.
- Keep submodules consistent with parent pointers. Do not advance them beyond scope.
  Test affected repositories together. Run required format, lint, tests, and builds.
- Check for new remote work before pushing. For an authorized rebased push,
  use `--force-with-lease=<branch>:<observed-head-sha>`. Reassess a failed lease.
- Preserve full-stop's automatic-merge restrictions when it calls this skill.
  Never merge, close, deploy, or activate through this workflow.

Report the disposition, evidence, resulting diff, checks, commits or pushes,
and remaining decisions. Recheck and link the PR after an authorized push,
following session rules.
