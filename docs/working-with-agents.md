# Working with coding agents

How to get good results from coding agents (Claude Code, Codex) on this repo, based
on a review of the first 59 Superconductor tickets, their 78 implementations, and
the roughly 60 pull requests that came out of them (November 2026).

Agents read [`AGENTS.md`](../AGENTS.md) on every run and load the skills in
`.agents/skills/` when a task matches. This page is for the people writing tickets.

## What the review found

Across 78 implementations there were 232 follow-up messages. Most fell into a few
repeating groups, and each now has a rule or a skill behind it.

| What kept happening | How often | Now handled by |
| --- | --- | --- |
| Agent could not run the specs: no Ruby, no Chrome, or a blocked download. It then verified "by reasoning" or wrote a throwaway test harness. | 27 of 78 implementations | `bjc-env-setup` and its setup script |
| "Please try again" after a run died or stalled | 15 messages | Mostly environment; see below |
| "Access allowed" after the agent hit a blocked host | 12 messages | Pre-allow hosts; see below |
| "Sync with main" / resolve conflicts | 19 messages | `bjc-branches-and-prs` |
| Edits made to `old/` files had to be undone, or old files were counted in an audit | 10 messages | `AGENTS.md` rule 1, `bjc-live-pages` |
| A pull request had to be split (vendored files, deletions, HTML vs JS/CSS, per unit) | 8 messages | `bjc-branches-and-prs` |
| Hundreds of HTML pages edited when a JS fix was wanted | 4 tickets | `AGENTS.md` rule 4 |
| Script written in Python, or with its own `.topic` parser | 3 tickets | `AGENTS.md` rule 6, `bjc-build-tools` |
| Visual fix reported done but still broken at another screen width | 72 messages across the 3 worst tickets | `bjc-frontend-changes` |
| Spanish page not updated alongside the English one | 4 tickets | `AGENTS.md` rule 3 |

Three tickets (the Bootstrap 5 upgrade, the first accessibility pass, and the navbar
search button) account for over a third of all follow-up messages. All three were
broad, and in all three the agent had no browser to see or test the result in.

Other patterns worth knowing:

- **Audit first, then implement, works well.** Tickets that asked for a report and
  were followed by "do items 2 and 3" produced small pull requests that merged.
- **Narrow tickets merge.** Pull requests under about 15 files mostly merged.
  The ones touching 400 or more files were closed and redone in pieces.
- **Running several agents on one ticket** was useful for audits and design
  questions, where comparing answers has value. For implementation work usually one
  result was kept and the rest discarded.
- **A second ticket to "take over" a branch** or extract part of it worked better
  than continuing a very long conversation.

## Do these once

1. **Bake the toolchain into the Superconductor snapshot.** In Project Settings →
   Development Environment, add this build command and rebuild the snapshot:

   ```sh
   cd /workspace/bjc-r && .agents/skills/bjc-env-setup/scripts/setup.sh --browser
   ```

   Agents then start with Ruby, the gems, and Chrome, and can run every spec.
2. **Turn on the Playwright MCP** (Project Settings → Skills and MCPs) so agents can
   open the preview, check a layout at phone width, and attach screenshots.
3. **Allow the hosts agents keep asking for** (Project Settings → Network Access):
   `bjc.edc.org`, `bjc.berkeley.edu`, `cs10.org`, `web.archive.org`, `archive.ph`,
   `googlechromelabs.github.io`, `storage.googleapis.com`.

## Writing a ticket

A good ticket answers five questions. Leaving one out is what usually causes the
second and third message.

1. **Scope.** Which course, unit, or files? English only, or Spanish too?
2. **Where the fix belongs.** Shared JS/CSS, content HTML, or build tools? Say so if
   you know, especially "do this in JS, do not edit the pages".
3. **What done looks like.** A spec that should pass, a page and screen width that
   should look right, or "report only, change nothing".
4. **How to deliver.** Report, commits, or pull request? One pull request or
   several? Draft?
5. **Starting point.** Branch or pull request to build on, if not `main`.

### Templates

Bug or visual fix:

```text
On <page URL with query string>, at <screen width>, <what is wrong>.
Expected: <what it should look like or do>.
Check at phone and desktop widths and attach screenshots.
```

Accessibility failures:

```text
Fix these axe failures (output below). English and Spanish.
One commit per unit. Do not change how the pages look.
<pasted rspec failure list — the short "rspec ./utilities/specs/…" lines are enough>
```

Audit:

```text
Audit <area> for <problem>. Live pages only.
Report findings as a numbered list with file and line. Do not change any files.
```

Sweep across many pages:

```text
Change <X> to <Y> on live pages in <course/unit>. English and Spanish.
First tell me how many files match and whether this could be done in llab instead.
One pull request per unit.
```

New tool:

```text
Write a Ruby script in utilities/build-tools that <does X>, reusing BJCTopic /
BJCCourse. Add specs. Run it on <unit> and attach the output.
```

### Habits that save a round trip

- Paste the page URL including `?topic=…&course=…`, not just "2.1.1".
- For CI failures, paste the list of failing example lines; the full axe output for
  one failure is enough to show the pattern.
- Number your requests. "Do 1, 2, and 5" then works as a follow-up.
- When a visual fix fails twice, ask for a screenshot at the failing width before
  the next attempt, or give the exact CSS you want.
- Put unrelated requests in a new ticket rather than the same conversation. Long
  conversations are where branches drift from `main` and pull requests grow.
- If you change your mind about the approach, say "commit this, then try…" so the
  working state is kept.

## Keeping the instructions current

When you find yourself giving an agent the same correction twice, add one line to
`AGENTS.md` or to the matching skill. Keep `AGENTS.md` short: it is read on every
run, so each line costs something. Detail belongs in a skill.

Skills are plain Markdown in `.agents/skills/<name>/SKILL.md`. The `description` at
the top decides when an agent loads the skill, so write it as a list of situations.
`.claude/skills` is a link to the same directory for Claude Code running locally.
