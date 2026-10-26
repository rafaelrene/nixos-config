---
name: review-changes
description: Use when asked to review changes.
disable-model-invocation: false
---

# Review changes

Stay read-only. Prioritize bugs, useful improvements, then guide violations.

## Scope

- Accept a PR, branch, commit range, or worktree. Default to current changes.
- Read repository instructions and relevant PR or thread context. Use T3 tools,
  then authenticated `gh` or `bkt` for missing GitHub or Bitbucket operations.
- Record the checkout, base, head, and paths. Include relevant staged, unstaged,
  and untracked changes. Use the branch's merge base, supplied range, or HEAD
  for uncommitted-only reviews. Ask when unclear.
- Preserve unrelated work. Do not edit source, commit, push, post, resolve
  threads, or change PR settings. Tests and temporary reproductions are allowed.

## GroupSolver guides

For GroupSolver code, confirm `groupsolver.atlassian.net` and read these guides:

```sh
acli confluence auth status
acli confluence page view --id 1722220555 --body-format storage --json
acli confluence page view --id 1722187777 --body-format storage --json
acli confluence page view --id 2105966593 --body-format storage --json
```

Cite applicable Code, Naming, and TypeScript rules. Respect repository exceptions.
If required context or guides are missing, ask whether to continue and disclose
the gap. Other repositories use their own instructions.

## Review loop

- Default to an independent Sol 6.1 reviewer on xhigh. Honor requested effort.
- Add Opus 5.5 skeptics or other reviewers when another provider's perspective
  helps. Use only these two models. Reviewers stay read-only and do not delegate.
- Follow session delegation rules. Supply scope, revisions, intent, instructions,
  and check results. Disclose unavailable reviewers; never imply their approval.
- Review the change yourself. Verify every delegate finding.
- Track finding IDs, severity, evidence, fixes, and outcomes.
- Start with the full diff. Later rounds cover changes and open findings.
- Default to three rounds. Allow five for security, auth, permissions, data loss,
  or concurrency while material findings remain. Extend further only on request.
  Keep the same budget and ledger across fixes.
- Exchange evidence until reviewers agree on each finding and fix. After two
  unresolved exchanges or budget exhaustion, show both positions. Silence and
  majority votes are not agreement.
- Authors or full-stop apply fixes outside this review. Pause edits during review.
  Recheck behavior changes. Skip rounds for formatting and declined suggestions.

## Verify and report

- Trace real triggers through callers, types, safeguards, and tests. Report only
  problems introduced, exposed, or worsened by the change.
- Prove impact with a test, reproduction, or complete code trace. Reject
  hypothetical problems. Rank rare bugs by impact.
- Verify the smallest root-cause fix. Combine related findings. Defer unrelated
  suggestions with reasons.
- Recheck the final revision. Approve only when its behavior is reviewed and
  no issue requiring a change to this diff remains.

Report APPROVED, CHANGES NEEDED, or UNRESOLVED, with base and head.

For each finding, show its ID, severity, category, linked location, impact,
root cause, verification, failing code example, and minimal fix.

Use P0 critical, P1 high, P2 medium, and P3 low. Group bugs, improvements, and
guide violations in that order. Finish with rounds, models, checks,
disagreements, and coverage limits. Remove temporary artifacts.
