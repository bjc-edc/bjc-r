# Working in bjc-r

Instructions for coding agents (Claude Code, Codex, and others). `CLAUDE.md` imports
this file. Task-specific procedures live in `.agents/skills/` and are listed at the
bottom; read the matching one before starting that kind of work.

## What this repo is

The Beauty and Joy of Computing curriculum: a static site with **no build step**.
Pages are plain HTML that load `llab/loader.js`, which injects Bootstrap 5, the
shared CSS, the navigation bar, and the quiz code at runtime.

- `course/*.html` lists units → `topic/**/*.topic` lists pages → `cur/`, `sparks/`
  hold the pages themselves.
- Five live courses: `bjc4nyc` (shown to people as "BJC AP CS Principles"),
  `bjc4nyc.es`, `sparks`, `bjc4nyc_teacher`, `sparks-teacher`.
- `llab/` is the shared framework (JS, `llab/css/default.css`, vendored libraries in
  `llab/lib/`). `css/bjc.css` holds BJC-specific styles. Both load on every page.
- `utilities/build-tools/` (Ruby) generates the per-unit vocabulary, self-check, and
  exam-reference pages and the indexes. `utilities/specs/` holds the RSpec suites.
- Translations sit beside the original: `page.html` and `page.es.html`.

Only about a third of the HTML in this repo is live. The rest is history kept for
reference.

## Ground rules

These come from corrections that were needed repeatedly in past agent work.

1. **Leave `old` paths alone.** Do not edit, fix, count, or report on any file whose
   path has a directory containing "old" (`old/`, `very old/`, `OldVersion/`,
   `pre-2017/…`), nor `utilities/archive/` or the C code in `utilities/summaries/`.
   A repo-wide find-and-replace must filter them out first.
2. **Scope sweeps to live pages.** When a change touches many pages, start from the
   list the specs test, not from `grep -r`. See the `bjc-live-pages` skill.
3. **Keep English and Spanish in step.** A structural change to `x.html` gets the
   same change in `x.es.html`. Translate any new visible text.
4. **Prefer one fix in shared JS or CSS over edits to hundreds of pages.** If the
   behaviour can be supplied by `llab` at runtime, do that. Ask before starting a
   sweep of content HTML that the ticket did not ask for.
5. **Do not hand-edit generated pages** (`unit-N-vocab`, `unit-N-self-check`,
   `unit-N-exam-reference`, `vocab-index`, `atwork`, in either language). Change the
   source page or the build tools and regenerate.
6. **Write tooling in Ruby and reuse the existing parsers** (`BJCCourse`,
   `BJCTopic` in `utilities/build-tools/`). Do not write a second `.topic` parser,
   and do not add Python or Node scripts for repo processing.
7. **Do only what was asked.** Report unrelated problems you find; do not fix them
   in the same branch.
8. **No visual drift from structural fixes.** An accessibility or markup fix should
   leave the page looking the same unless the ticket says otherwise.

## Commands

Run from the repo root. If `ruby` is missing, see the `bjc-env-setup` skill before
concluding that tests cannot be run.

| Task | Command |
| --- | --- |
| Serve the site | `./run-server --no-open` then open `http://localhost:8000/bjc-r/` |
| Fast specs (no browser, under 2s) | `bundle exec rspec utilities/specs/build_tools_spec.rb utilities/specs/summary_pages_spec.rb` |
| Lint Ruby | `bundle exec rubocop` |
| Navigation specs (browser) | `bundle exec rspec utilities/specs --tag dynamic_nav` |
| Self-check quiz specs (browser) | `bundle exec rspec utilities/specs/self_check_feedback_spec.rb` |
| Accessibility, one group | `bundle exec rspec utilities/specs/accessibility_spec.rb --tag sparks_wcag20` |
| Accessibility, one page | `bundle exec rspec utilities/specs/accessibility_spec.rb -e "2-caesar-cipher.html"` |
| Regenerate summary pages | `bundle exec ruby utilities/build-tools/rebuild-all.rb` |
| List live pages | `bundle exec ruby .agents/skills/bjc-live-pages/scripts/live_pages.rb` |

Page URLs need their query string to render navigation, for example
`/bjc-r/cur/programming/1-introduction/1-building-an-app/1-start-your-first-snap-app.html?topic=nyc_bjc/1-intro-loops.topic&course=bjc4nyc.html`.
`live_pages.rb --urls` prints them ready to use.

## Code conventions

- JavaScript: always use curly braces, including one-line `if`. New code should not
  add jQuery; `library.js` must not depend on it. Put new constants and helpers with
  the existing ones rather than at the top of a file.
- Bootstrap 5 only: `.card` not `.panel`, `.d-none` not `.hidden`,
  `.visually-hidden` not `.sr-only`, `data-bs-*` attributes. Use Bootstrap utilities
  and grid before writing new CSS.
- CSS: no page-level `<style>` blocks. Shared rules go in `llab/css/default.css`;
  BJC-specific or one-page rules go at the bottom of `css/bjc.css` with a comment
  naming the page they serve. Do not load extra stylesheets.
- Comments describe what the code does now. Do not write comments about what it used
  to do ("previously in Bootstrap 3…"). Label any deliberate workaround or
  intentional duplication in one line.
- User-visible strings in JS go through `llab.t()` with a Spanish entry. Build-tool
  strings go in `utilities/build-tools/bjc_translations.yml`.
- Keep literal UTF-8 characters in JS and CSS; do not replace them with escapes.
- Vendored libraries live in `llab/lib/` and are loaded through `llab/loader.js`.

## Before you say you are done

- Run the fast specs and rubocop for any Ruby change, and the relevant browser spec
  for any JS, CSS, or page change. State exactly which commands you ran.
- If something could not be run, say so plainly and say why. "Verified by reasoning"
  is not verification.
- For anything visual, look at it in a browser at phone (375px), tablet (768px), and
  desktop widths, and attach screenshots. See `bjc-frontend-changes`.
- List pages the reviewer should open to check the change.

## Git and pull requests

Do not commit, push, or open a pull request unless asked. When asked, follow the
`bjc-branches-and-prs` skill: small single-purpose commits, merge `main` rather than
rebasing shared branches, and keep vendored files, deletions, content HTML, and
JS/CSS in separate pull requests.

## Skills

| Skill | Use it when |
| --- | --- |
| `bjc-env-setup` | Ruby, Bundler, or Chrome is missing, or a download is blocked |
| `bjc-live-pages` | A change, audit, or search spans many pages or files |
| `bjc-accessibility` | Fixing axe / WCAG failures or touching the a11y specs |
| `bjc-frontend-changes` | Changing CSS, layout, navigation, or quiz rendering |
| `bjc-build-tools` | Changing the Ruby build tools or regenerating summary pages |
| `bjc-branches-and-prs` | Committing, syncing with `main`, or opening pull requests |

For people writing tickets, see `docs/working-with-agents.md`.
