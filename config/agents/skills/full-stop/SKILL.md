---
name: full-stop
description: Use when asked to run the full stop workflow.
disable-model-invocation: false
---

# Full stop

Finish the change and prepare an open PR for the user to merge.

## Authority

- A full-stop request authorizes implementation, tests, task-branch commits and
  pushes, PR creation or updates, and fixes for verified review or CI issues.
- It includes branch updates using repository conventions and explicit-head
  force-with-lease pushes after authorized rebases.
- Draft replies. Posting replies and resolving threads need separate approval
  of the exact replies and resolutions.
- Never merge, enable auto-merge, enter a merge queue, push to the default
  branch, bypass protection, or delegate those actions.
- Deployment, activation, production changes, data deletion, and unrelated work
  need separate authorization.

## Deliver

1. Read repository instructions and task context. Use a task branch.
   Preserve unrelated work. For GroupSolver, read the guides in
   [review-changes](../review-changes/SKILL.md#groupsolver-guides).
2. Disable auto-merge and remove the PR from merge queues. Recheck before every
   push and at handoff. Stop if automatic merging cannot be prevented.
3. Use [modernize](../modernize/SKILL.md) when the branch needs updating.
4. Make the smallest change that meets the goal. Prove behavior with direct
   reproductions and relevant tests or runtime checks. Follow testing rules.
5. Use [review-changes](../review-changes/SKILL.md). Fix verified issues within scope,
   rerun proof, and review behavior changes with the same ledger and round budget.
   Keep unrelated suggestions as follow-ups.
6. Find an existing PR before creating one. Use T3 tools, then authenticated
   `gh` or `bkt` for missing operations. Follow repository conventions.
7. Commit and push intended changes. Prepare an open, non-draft PR describing
   the problem, behavior, proof, and review outcome. Link it under session rules.

## Monitor

- Read checks and full review threads, including older unresolved findings.
- Fix real failures within scope. Separate defects from infrastructure failures.
  Reprove and review behavior changes before pushing. Draft replies for approval.
- In T3, only the owning parent uses `watch_pull_request`. Call it and end the
  turn; resume on its wake. No duplicate watchers or polling loops.
- Outside T3, use available host or harness monitoring. Report unsupported
  monitoring. Check external CI separately.
- Call `unwatch_pull_request` before a question or handoff. Skip filler updates.

## Handoff

Recheck the live head, base, checks, approvals, mergeability, and auto-merge.
Proof and independent review must cover the final diff.

Report:

- READY TO MERGE: checks and approvals pass, findings are addressed, repository
  update requirements are met, and the host reports it mergeable.
- WAITING FOR USER: only identified approvals, replies, or thread resolutions remain.
- BLOCKED: proof, review, checks, access, or a decision prevents readiness.

Include the PR link, head SHA, proof, review outcome, risks, and remaining actions.
Confirm it is open and unmerged, or report its changed state. Incomplete review
or unresolved findings cannot count as readiness.

Use the question tool for blocking decisions. Give context, options, and a
recommendation. Never infer approval from silence.
