---
name: bjc-branches-and-prs
description: Commit, sync with main, split work, and open pull requests in bjc-r the way the maintainers review them. Use when asked to commit, push, "sync with main", resolve merge conflicts, extract part of a branch into its own pull request, split a large change, or open or update a pull request.
---

# Commits, branches, and pull requests

Only commit, push, or open a pull request when asked. Never force-push unless the
user says to in so many words.

## Commits

- One purpose per commit, with a message that says what and why.
- Natural units here: one lab or unit of content fixes; one bug; a mechanical
  rename (for example `data-toggle` → `data-bs-toggle`) on its own.
- When asked to "make each fix a distinct commit", do exactly that, in the order the
  fixes were listed.
- Commit a known-good state before trying a different approach to the same problem.

## Keep these in separate pull requests

Mixed pull requests have repeatedly been sent back to be split. Split up front:

| Kind of change | Why it is separate |
| --- | --- |
| Adding or upgrading vendored files in `llab/lib/` | Tens of thousands of lines nobody reads; merge first, alone |
| Pure file deletions | Reviewable at a glance when nothing else is mixed in |
| Content HTML (`cur/`, `sparks/`, `topic/`) | Reviewed by curriculum authors |
| Shared JS / CSS (`llab/`, `css/`) | Reviewed by developers; affects every page |
| Build-tool logic vs regenerated output | See `bjc-build-tools` |
| New assets (images, SVGs) vs the pages that use them | Assets can merge before the interactive work |

For large content sweeps, open one pull request per unit, with the English and
Spanish pages for that unit together. Aim for something a person can review in one
sitting; a pull request touching hundreds of files will not be merged as is.

If you find an unrelated bug, report it and offer a separate branch. Do not fold it
into the current one.

## Extracting part of a branch

When asked to pull a subset of a branch into its own pull request:

1. Branch from current `main`, not from the feature branch.
2. Bring over only the requested paths: `git checkout <feature-branch> -- <paths>`
   for whole files, or cherry-pick when history should be kept. Ask if it is unclear
   whether commit IDs need to be preserved; usually they do not.
3. Check the result stands alone: `git diff main --stat` should show only the
   intended paths, and the specs for that area should pass.
4. Say what remains on the original branch.

## Syncing with main

- "Sync with main" means **merge** `origin/main` into the branch. Do not rebase a
  branch that has been pushed.
- Fetch first, and also pull the branch's own remote; people push to these branches.
- Resolve conflicts by keeping both intents. In particular, keep accessibility fixes
  from `main` and re-apply your change on top, rather than taking one side wholesale.
- If the branch was started long ago and the diff against `main` has become huge
  after merging, stop and say so. Replaying the few real commits onto a fresh branch
  from `main` is usually better than a large merge.
- After syncing, re-run the fast specs, and regenerate summaries if either side
  touched content. Then check nothing under an `old` path appears in
  `git diff main --name-only`.

## Pull request description

- Title: what the change does, not the ticket title pasted verbatim.
- What changed and why, in a few lines.
- How it was verified: the exact spec commands and their results. If something could
  not be run, say so here.
- Screenshots for anything visual, embedded so they render inline.
- A short list of pages to open to check it.
- `Closes #N` for any GitHub issue it resolves.
- Open as a draft if it is exploratory or meant to be replaced.

If `gh pr create` is refused in a sandbox, say so and give the branch name rather
than working around it silently.
