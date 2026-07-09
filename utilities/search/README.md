# Client-side search (Pagefind)

This directory builds [Pagefind](https://pagefind.app/) search indexes for the
BJC curriculum. Search runs entirely client-side — no third-party server, no
API key — and supports filtering results by `course`.

## How it works

`build-index.js` is a Node script that:

1. Reads one or more **course HTML files** in `course/` and pulls out the list of
   `.topic` references (same selector as `BJCCourse#list_topics`).
2. Parses each `.topic` file using the canonical browser parser at
   `llab/script/topic.js` — loaded into Node via `llab-loader.js`
   (`vm.runInContext` with a small `llab` / `$` / `document` shim) — so we
   don't duplicate the topic-file grammar.
3. Reads each lab page's HTML and builds the result title as
   **`{first <h2>} ({cleaned <title>})`** — e.g.
   "Innovations and Privacy (Unit 1 Lab 4, Page 4)". The first `<h2>` is the
   BJC page-title convention; the `<title>` tag carries the position in the
   course, cleaned by dropping the lab name between the colon and the
   page/activity marker. It then injects a hidden
   `<span data-pagefind-filter>` marker for the course into the `<body>` and
   feeds the augmented HTML to Pagefind's
   [indexing API](https://pagefind.app/docs/node-api/).
4. Writes **two** indexes at the repo root:
   - `/search/pagefind/` — student courses
   - `/search/pagefind-teacher/` — the teacher guide for each course

No committed HTML is modified — the filter markers exist only in the in-memory
copy handed to Pagefind.

### Title capture / logging

Every extracted title is written to `title-report.json` (gitignored) with its
source (`h2`, `title-tag` fallback, or `none`). Pages missing a first `<h2>`
are warned about during the build, and the build summary reports how many
pages fell back to the `<title>` tag. As of the last audit, **all 560 indexed
pages have a first `<h2>`**.

## Running the build

```sh
cd utilities/search
npm install
npm run build     # indexes the default course lists below
node build-index.js --courses=bjc4nyc.html,sparks.html --teacher-courses=bjc4nyc_teacher.html
```

## Courses indexed

| Course file | Filter value | Bundle |
| --- | --- | --- |
| `bjc4nyc.html`, `bjc4nyc.es.html` | BJC CS Principles | `search/pagefind/` |
| `sparks.html` | BJC Sparks | `search/pagefind/` |
| `bjc4nyc_teacher.html` | BJC CS Principles Teacher Guide | `search/pagefind-teacher/` |
| `sparks-teacher.html` | BJC Sparks Teacher Guide | `search/pagefind-teacher/` |

Course display names live in `COURSE_DISPLAY_NAMES` in `build-index.js` and
must stay in sync with `COURSE_FILENAME_TO_DISPLAY` in `search/index.html`.

## Using the search

The search page lives at `/bjc-r/search/` (i.e. `search/index.html`). Serve the
repo locally (`./run-server`) and open <http://localhost:8000/bjc-r/search/>.
The navbar magnifier on curriculum pages opens an inline input; submitting
navigates here with `?q=…` (and `?course=…` when on a course page) so the
query re-runs and the matching course filter is pre-selected.

Query parameters:

- `q` — run this query immediately.
- `course` — pre-select a course filter; accepts a course-file basename
  (`sparks.html`) or a display name (`BJC Sparks`).
- `teacher` — **teacher guides are hidden unless this is present** (any value
  except `0`/`false`). The teacher bundle is merged into the search via
  Pagefind's `mergeIndex`, so teacher-guide pages are never downloaded, shown,
  or listed in the course filter without it. Arriving with
  `?course=bjc4nyc_teacher.html` or `?course=sparks-teacher.html` also enables
  it.
- `lang` — `en`/`es` page chrome (results are mixed-language; Pagefind keeps
  per-language sub-indexes).

## Files

- `build-index.js` — indexer (both bundles + title report)
- `llab-loader.js` — loads `llab/script/topic.js` into Node
- `package.json` — Node deps (`pagefind`, `cheerio`)

## Limitations / next steps

- Teacher-guide *topic pages* contain prose (`raw-html:` lines in the `.topic`
  files) that has no standalone HTML page, so it isn't indexed — only the
  linked teacher lab pages are.
- The build re-indexes everything on each run. For a few hundred pages
  that's <2 s, so incremental indexing isn't worth the complexity yet.
- The `teacher` query parameter is a visibility gate, not access control —
  the teacher bundle is still public to anyone who constructs the URL.
- If `cs10/bjc-r` or another fork wants its own index, point the script at
  different course HTML files via `--courses=` / `--teacher-courses=`.
