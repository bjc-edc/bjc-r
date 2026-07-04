# Client-side search (Pagefind prototype)

This directory builds a [Pagefind](https://pagefind.app/) search index for the BJC
curriculum. It runs entirely client-side — no third-party server, no API key —
and supports filtering results by `course`, `unit`, and `lab`.

## How it works

`build-index.js` is a Node script that:

1. Reads one or more **course HTML files** in `course/` and pulls out the list of
   `.topic` references (same selector as `BJCCourse#list_topics`).
2. Parses each `.topic` file using the canonical browser parser at
   `llab/script/topic.js` — loaded into Node via `llab-loader.js`
   (`vm.runInContext` with a small `llab` / `$` / `document` shim) — so we
   don't duplicate the topic-file grammar.
3. Reads each lab page's HTML, injects three hidden `<span data-pagefind-filter>`
   markers into the `<body>` (one each for course / unit / lab), and feeds the
   augmented HTML to Pagefind's [indexing API](https://pagefind.app/docs/node-api/).
4. Writes the index to `/search/pagefind/` at the repo root.

No committed HTML is modified — the filter markers exist only in the in-memory
copy handed to Pagefind.

## Running the build

```sh
cd utilities/search
npm install
npm run build                 # indexes bjc4nyc.html (the AP CSP course)
node build-index.js --courses=bjc4nyc.html,sparks.html   # custom courses
```

Output lands in `/workspace/bjc-r/search/pagefind/` (≈ 2 MB for 186 pages).

## Using the search

The search page lives at `/bjc-r/search/` (i.e. `search/index.html`). Serve the
repo locally (`./run-server`) and open <http://localhost:8000/bjc-r/search/>.
The sidebar exposes the course / unit / lab facets; results link straight to
the lab pages.

## Current scope

- **Course:** AP CSP (`bjc4nyc.html`) only.
- **Language:** English (Spanish `.es.html` pages are skipped).
- **Pages indexed:** ~186, covering all 8 units + the Create Task practice.

To extend to other courses, pass `--courses=...`. To extend to Spanish, drop
the `.es.html` skip in `urlToFsPath` and run Pagefind without `forceLanguage`.

## Files

- `build-index.js` — indexer
- `package.json` — Node deps (`pagefind`, `cheerio`)
- `test-search.js` — dev-time smoke test (requires a running local server +
  `npm install --save-dev jsdom`; partial — see "Limitations" below)

## Limitations / next steps

- The smoke test runs Pagefind under jsdom, which doesn't have Web Workers,
  so the runtime falls through to a path that resolves URLs against
  `document.baseURI`. Production search in a real browser works fine; the
  jsdom path needs more shimming or a real headless browser to drive.
- The build re-indexes everything on each run. For a few hundred pages
  that's <2 s, so incremental indexing isn't worth the complexity yet.
- If `cs10/bjc-r` or another fork wants its own index, just point the
  script at a different course HTML file.
