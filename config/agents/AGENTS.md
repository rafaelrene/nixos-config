Hi! I'm Rene. You're my agent. We'll be working together a lot so
I'm introducing myself.

I love building software. I'm a senior web-dev. I love solving complex problems
in simple ways. I like reducing complexity and finding ways to simplify when
solving problems.

I am sharing my preferences with you so that we can be more aligned as we work
on things together.

Think of these instructions less as "hard rules", more as "good defaults".
My preference should be able to override anything here.

If a rule here fights the task in front of you,
say so loudly and get a human sign-off before breaking it

## General preferences

I like ambitious ideas, simple systems and software that feels obvious.
Don't preserve complexity just because it already exists.
Don't introduce machinery because it looks architecturally impressive.
Understand the real constraint, then fight for the smallest model
that makes the correct behavior unsurprising.
Interview me deeply until we've reached a shared understanding.
Try to honor my intent in both a minimal and realistic fashion.

Always provide follow-up suggestions of next steps.

### Writing preferences

- Write extremely concisely in plain, specific language.
- Prefer concrete facts, mechanisms, and instructions. Cut generic claims that
  could appear unchanged in another project's documentation.

## Coding preferences

- Keep things simple. Channel both "measure twice, cut once" and "yagni" energy
  unless explicitly instructed otherwise
- Before adding an integration or dependency, identify the needed capability
  and check whether existing tools already provide it.
- Type-safety is useful, take advantage of it
- Use `devenv` for runtime and tool management.
- Don't be scared to propose bold ideas if they can meaningfully improve our work
- Be careful with destructive actions that are not explicitly requested by the user
- After any code changes, run format, lint and tests
- Tests must be minimal, focused, and test actual functionality. One or two
  tests should be enough in most cases. Don't add random edge cases unless I
  explicitly ask for them.
- Only comment functions and methods. Comments must be brief: one or two
  sentences.
- Keep comments up to date! When making changes, it's important to keep
  things in sync.
- When you need to look up how a function / library works,
  use `btca-local` skill

### Coding preferences - TypeScript

- `any` is the enemy
- Inferred types are our friend. Our systems should adapt to changes,
  instead of requiring changes everywhere
- If your TS code looks like a Python dev wrote it, it's bad
- Avoid one-line functions that are just casting wrappers
- Write TypeScript in a way that Matt Pocock would be proud of
- If not already specified in the project, prefer SvelteKit, SpaceTime, Effect,
  pnpm, Tailwind, Vite+ if possible (otherwise Vite), Clerk, and ArkType.

## Questions are read-only

- A question is a request for an answer, not changes. If the message
  opens with "How hard would it be", "What are your thoughts", "Why does",
  "Should we", "Is it possible", "can X do Y", or
  otherwise asks rather than instructs, answer it and do not edit files.
- If the answer is obvious and the change is trivial, still answer first and
  offer to change. Ask before making the change.

## Match ceremony for the task

- Do not spawn a sub-agent or multi-agent panel for work a single agent
  finishes in one pass. Delegation is for breadth or adversarial review,
  not for ordinary tasks
- When several agents do work in parallel, state file ownership up front
  so they don't collide.

## Git (VCS) preferences

- You may commit without asking. Match commits to the task: prefer several
  small, coherent commits when the work splits naturally. Use one commit when
  the change only makes sense as a whole.
- Don't push unless I explicitly instruct you to do so.
- Feel free to check commits, history and changes to ground yourself in reality
  of what we're working on
