---
name: review-changes
description: Use when asked to review changes.
disable-model-invocation: false
---

# Review changes

Stay read-only. Prioritize bugs, useful improvements, then guide violations.

## Scope

- Accept a PR, branch, commit range, or worktree. Default to current changes.
- Read relevant PR or thread context. Use T3 tools, then authenticated `gh` or
  `bkt` for missing GitHub or Bitbucket operations.
- Record the checkout, base, head, and paths. Include relevant staged, unstaged,
  and untracked changes. Use the branch's merge base, supplied range, or HEAD
  for uncommitted-only reviews. Ask when unclear.
- Preserve unrelated work. Do not edit source, commit, push, post, resolve
  threads, or change PR settings. Tests and temporary reproductions are allowed.

## Review loop

- Use [council](../council/SKILL.md) for reviewer selection, reasoning effort,
  review rounds, and scores.
- Supply scope, revisions, intent, these review standards, and check results.
  Reviewers stay read-only and do not delegate.
- Keep council read-only here: report known issues and proposed fixes instead of
  applying them. Return findings and the council score table to the user or calling
  workflow. Leave PR description updates to an authorized implementation workflow.
- Review the change yourself. Verify every delegate finding.
- Track finding IDs, severity, evidence, fixes, and outcomes.
- Start with the full diff. Later rounds cover changes and open findings.
- Exchange evidence until reviewers agree on each finding and fix. Show unresolved
  disagreements. Silence and majority votes are not agreement.
- Authors or an authorized workflow such as full-stop apply fixes outside this
  review. Return findings when changes are needed; resume council after fixes.
  Keep the same finding ledger. Pause edits during review. Recheck behavior changes.
  Skip rounds for formatting and declined suggestions.

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
Cite the rule for guide violations.

Use P0 critical, P1 high, P2 medium, and P3 low. Group bugs, improvements, and
guide violations in that order. Finish with rounds, models, checks,
disagreements, and coverage limits. Remove temporary artifacts.
