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

## Compiled courses (spike)

A course under `src/` is compiled rather than served as written. Its pages do
not state where they are in the course: the compiler works that out from
`src/<course>/course.yml` and the topic files it lists, then writes a course
page, topic files, and pages that llab serves like any other course.

```sh
bundle exec ruby utilities/build-tools/compile.rb            # every course under src/
bundle exec ruby utilities/build-tools/compile.rb --watch    # and again on each change
./run-server                                                 # http://localhost:8000/bjc-r/course/csp.html
```

The compiled site goes to `_site/bjc-r/`, which is not committed. `./run-server`
serves a file from there in place of the same path in the checkout, so a
compiled course appears at its real URL beside the shared `llab/`, `img/`, and
`prog/` folders. Use `--out DIR` to write somewhere else; `DIR` stands for
`/bjc-r/` and must be named `bjc-r` for the summary pages to be built.

What an author writes:

| In the source | In the compiled site |
|---|---|
| `title: Introduction to Programming` in a topic file | `title: Unit 1: Introduction to Programming` |
| `heading: Gossip` | `heading: Lab 2: Gossip` |
| `resource: Making Programs Talk [1-introduction/2-gossip-and-greet/2-gossip.html]` | the same line, with the URL the page is served from |
| `<title>Making Programs Talk</title>` | `<title>Unit 1 Lab 2: Gossip, Page 2</title>` |
| `<a href="/bjc-r/csp/.../3-customizing.html">this page</a>` | the same link, with `?topic=csp/1-introduction.topic&course=csp.html` added |
| `<a href="/bjc-r/csp/.../3-customizing.html" data-page-ref></a>` | `<a href="...">Unit 1 Lab 2 Page 3: Customizing and Debugging</a>` |
| `<a href="..." data-page-ref="short"></a>` | `<a href="...">Lab 2 Page 3: Customizing and Debugging</a>` |

Links may also be relative to the page (`../3-drawing/1-exploring-motion.html`).

The build stops, having written nothing, when:

* a link names a page that is not in the course;
* a link to a page of the course carries its own `?topic=` or `?course=`;
* a topic file lists a page that does not exist, or `course.yml` lists a topic
  file that does not exist.

It warns, without stopping, about a shared file (an image, a Snap! project)
that does not exist.

A page in the source folder that no topic file lists, such as a hints page, is
compiled with the title it was given and has no place in the navigation.

After a course compiles, the existing summary generators run over the compiled
pages to build its vocabulary, self-check, and exam reference pages.

To bring a unit of an existing course into a compiled course:

```sh
bundle exec ruby utilities/build-tools/import-unit.rb nyc_bjc/1-intro-loops.topic csp
```

## Tests

The automated RSpec suite lives in `utilities/specs`:

```sh
bundle exec rspec utilities/specs
```

The build-tools specs are fast and need no browser:

```sh
bundle exec rspec utilities/specs/build_tools_spec.rb utilities/specs/course_compiler_spec.rb
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
