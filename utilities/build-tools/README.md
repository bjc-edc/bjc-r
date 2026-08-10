# BJC build tools

The Ruby build tools generate the curriculum index and summary pages. Run all
commands from the repository root.

## Setup

Install the Ruby version in `.tool-versions`, then install the dependencies:

```sh
bundle install
```

The root Gemfile includes the build-tools Gemfile, so this installs both the
test and build dependencies. To install only the build dependencies, use:

```sh
BUNDLE_GEMFILE=utilities/build-tools/Gemfile bundle install
```

## Rebuild index and summary pages

Rebuild every configured course and language:

```sh
bundle exec ruby utilities/build-tools/rebuild-all.rb
```

Limit the build to a course and/or language when iterating:

```sh
bundle exec ruby utilities/build-tools/rebuild-all.rb --only bjc4nyc --lang en
bundle exec ruby utilities/build-tools/rebuild-all.rb --only sparks
```

Review all generated changes before committing them.

## Audit the link graph

`link-audit.rb` walks every link in the repo from the six entry points
(`index.html` and the five courses in `LinkAudit::COURSES`) and reports three
things: broken links, files nothing links to, and files that are linked but not
reachable from any course or teacher guide.

```sh
bundle exec ruby utilities/build-tools/link-audit.rb
```

Results are written as CSVs plus a `report.md` summary, to `link-audit-out/` by
default. Useful flags:

| Flag | Effect |
| --- | --- |
| `--out DIR` | Write the report somewhere else |
| `--external` | Also check external URLs over the network (slow) |
| `--check-anchors` | Also validate `#fragment` links |
| `--include-old` | Stop ignoring archived `old/` paths |
| `--include-all` | Stop ignoring build tooling, specs and design sources |
| `--developer-links` | Follow links inside `.todo`/`.comment` blocks |

It reads `.topic` files through `BJCTopic` and course pages through
`BJCCourse`, so its idea of what a course contains is the same as the
generators'. `docs/` and `cur/blown-to-bits.html` are always skipped, and
archived `old/` paths are crawled but never reported.

## Tests

The automated RSpec suite lives in `utilities/specs`:

```sh
bundle exec rspec utilities/specs
```

The build-tools specs are fast and need no browser:

```sh
bundle exec rspec utilities/specs/build_tools_spec.rb
```

## Lints

```sh
bundle exec rubocop
```

The accessibility suite can be limited to a course and standard with tags:

```sh
bundle exec rspec utilities/specs/accessibility_spec.rb --tag bjc4nyc_wcag20
```

## Local site

After generating pages, serve the repository from its parent directory so URLs
under `/bjc-r` resolve correctly:

```sh
cd ..
python -m http.server
```
