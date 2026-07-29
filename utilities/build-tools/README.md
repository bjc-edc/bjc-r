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

## Tests

The focused build-tools Minitest suite covers topic parsing and summary
generation helpers:

```sh
BUNDLE_GEMFILE=utilities/build-tools/Gemfile bundle exec ruby utilities/build-tools/tests.rb
```

The automated RSpec suite lives in `utilities/specs`:

```sh
bundle exec rspec utilities/specs
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
