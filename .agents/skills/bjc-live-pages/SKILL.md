---
name: bjc-live-pages
description: Find which bjc-r pages are actually live, and scope multi-file edits, audits, and searches to them. Use before any find-and-replace, bulk HTML edit, dead-code or unused-file audit, link check, or "search the repo for…" task, and whenever deciding whether a file in an `old` directory matters.
---

# Scoping work to live pages

The repo has roughly 1,700 HTML files. About 580 are live. The rest are earlier
versions kept for reference, mostly under directories named `old`. Editing them
creates review noise and has had to be reverted many times.

## Get the list

```sh
bundle exec ruby .agents/skills/bjc-live-pages/scripts/live_pages.rb > /tmp/live.txt
```

One repo-relative path per line: every page reachable from the five course pages,
plus the standalone "general" pages, in both languages. It is the same list the
accessibility specs test and it is built with the same parser, so it cannot drift.

| Option | Result |
| --- | --- |
| `--course sparks` | Only that group (repeatable). Groups: `bjc4nyc`, `bjc4nyc.es`, `sparks`, `bjc4nyc_teacher`, `sparks-teacher`, `general` |
| `--urls` | Browsable URLs with the `?topic=…&course=…` query string |
| `--count` | A page count per group |

Pages that a topic file lists but that do not exist are reported on stderr. Those
are real broken links; mention them, but do not fix them unless asked.

Use the list as the input to whatever you do next:

```sh
xargs grep -l 'data-toggle=' < /tmp/live.txt        # which live pages need a change
xargs grep -c '<a name=' < /tmp/live.txt | grep -v ':0$'
```

## Rules for sweeps

1. **Never touch `old` paths.** Any path with a directory containing "old" in any
   capitalisation, plus `utilities/archive/` and the C sources in
   `utilities/summaries/`. This filter catches them:

   ```sh
   git ls-files '*.html' | grep -viE '(^|/)[^/]*old[^/]*/'
   ```

   Do not report them as broken, unused, or inaccessible either. They are known.
2. **A file being listed is not the same as being linked.** If you find a page that
   is in a topic file but hidden inside a `.todo` or `.comment` block, or listed
   nowhere, ask whether it is in scope before editing it.
3. **English and Spanish together.** If `x.html` is in your change set, so is
   `x.es.html` when it exists. Make the identical structural change.
4. **Skip generated pages** (`unit-N-vocab`, `unit-N-self-check`,
   `unit-N-exam-reference`, `vocab-index`, `atwork`). Fix the source and regenerate;
   see `bjc-build-tools`.
5. **Check whether a sweep is needed at all.** Many per-page fixes are better done
   once in `llab` JavaScript or shared CSS. Past examples: adding element IDs for
   anchors, initialising GIF players, setting the page charset. If the ticket did
   not explicitly ask for HTML edits, propose the shared fix first.
6. **Report the size before and after.** Say how many files matched and how many you
   changed, and confirm none are under an `old` path:

   ```sh
   git diff --name-only | grep -iE '(^|/)[^/]*old[^/]*/'   # must print nothing
   ```

## Developer-only content

Elements with the classes `.todo`, `.comment`, `.commentBig`, `.ap-standard`, and
`.csta-standard` are author notes, hidden in production. Exclude them from
accessibility work, content audits, structure comparisons, and exports unless the
task is about them specifically.

## Dev hosts

`llab.isLocalEnvironment()` in `llab/loader.js` is true on `localhost` and on
`*.runloop.ai` (Superconductor previews). That is what shows the developer-comment
toggle and skips caching there, so previews behave like a local checkout.
