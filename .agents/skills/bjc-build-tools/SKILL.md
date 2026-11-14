---
name: bjc-build-tools
description: Change the Ruby build tools in `utilities/build-tools/`, regenerate the unit vocabulary / self-check / exam-reference pages and indexes, or write a new repo-processing script. Use for tickets about summaries, index generation, `.topic` parsing, rubocop, the build-tools specs, or any new script that walks courses, topics, or pages.
---

# Build tools and repo scripts

## What is generated

`rebuild-all.rb` reads each live course and writes, per unit and language:
`unit-N-vocab`, `unit-N-self-check`, `unit-N-exam-reference`, plus `vocab-index` and
`atwork`. It also rewrites the "Unit Review" section at the end of each `.topic`
file. Never edit those outputs by hand. Change the source page or the generator.

```sh
bundle exec ruby utilities/build-tools/rebuild-all.rb                       # everything, ~2s
bundle exec ruby utilities/build-tools/rebuild-all.rb --only sparks --lang en
```

## Workflow for a build-tool change

1. **Record the baseline.** Curriculum edits land before summaries are regenerated,
   so a rebuild on a clean checkout often already produces a small diff. Run it
   once before you start, note which files changed (`git status --short`), then
   restore exactly those files with `git checkout -- <files>` so the baseline is
   not mixed into your work.
2. Make the change, with a spec in `utilities/specs/build_tools_spec.rb`.
3. Run the fast checks. All three finish in seconds and need no browser:

   ```sh
   bundle exec rspec utilities/specs/build_tools_spec.rb utilities/specs/summary_pages_spec.rb
   bundle exec rubocop
   ```

4. Rebuild and read the diff. Every changed line should be explained by your change
   or by the baseline. Whitespace-only churn across many files means the generator
   changed its formatting; fix that rather than committing the churn.
5. Commit generator changes and regenerated output **separately**, so the review of
   the logic is not buried under generated HTML.

When a ticket says to work on the build tools, do not also edit content HTML to make
the output come out right.

## Writing a new script

- **Ruby, in `utilities/build-tools/`**, using the gems already in the Gemfile
  (Nokogiri, i18n). Not Python, not Node.
- **Reuse the parsers.** `BJCCourse` (`course.rb`) lists a course's topics and knows
  which are hidden in developer-only blocks. `BJCTopic` (`topic.rb`) parses a
  `.topic` file and lists its pages. `BJCSpecs` (`utilities/specs/bjc_helper.rb`)
  combines them into the full live-page list. Parsing `.topic` files is fiddly;
  there must be only one implementation.
- **Skip what the build skips:** topics hidden inside `.todo`/`.comment` on the
  course page, developer-only elements within pages, and `old` paths.
- **Translatable strings** go in `bjc_translations.yml`, not inline.
- **Do not replace output until the run has finished**, and do not depend on
  scratch directories inside the repo. A failed run must leave the tree unchanged.
- **Do not hard-code URL parameters** such as `&novideo&noassignment`.
- Give the script a `--help`, and print a summary line (files read, files changed).
- Rubocop config is in `.rubocop.yml`; several naming and metrics cops are off on
  purpose for legacy code. Do not rename existing camelCase methods as a side effect.

## Ignore

`utilities/summaries/` (the old C implementation) and `utilities/archive/` are
deprecated. Do not read them for guidance, modify them, or report on them.

## CI

`.github/workflows/build-tools.yml` runs rubocop, the two fast specs, and a rebuild
that warns if committed summaries are stale. A script that takes a repo path must
work when the checkout is at `…/bjc-r/bjc-r` (as on GitHub Actions), so resolve
paths from `__dir__`, not from the current directory or its parent.
