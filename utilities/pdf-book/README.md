# Course → PDF book pipeline

Builds a single linked PDF book from a BJC course (e.g. `bjc4nyc`,
`sparks`) by walking the course's `.topic` files, converting each
curriculum HTML page to LaTeX via `pandoc`, wrapping the result in a
template adapted from the
[snap-cloud/manual](https://github.com/snap-cloud/manual/tree/main/_latex-template)
LaTeX template (KOMA `scrbook`, US Letter, snap brand colors), then
compiling under `xelatex` or `pdflatex`.

## Output

- Linked, two-level table of contents (`Unit` → `Lab`) via `hyperref`.
- PDF outline / bookmarks for every chapter, section, and page.
- BJC `<div class="learn|takeNote|forYouToDo|endnote|sidenote|vocab">`
  callouts rendered as colored `mdframed` boxes (page-break-safe).
- Snap-style cover page: orange title banner, blue side panel, dotted
  divider, build date.
- A two-column Index at the end with three categories — Vocabulary,
  On the AP Exam, Self-Check Questions — populated from BJC's `.vocab`,
  `.exam`, and `assessment-data` markup. All page references are
  clickable.
- PDF 2.0 with `\DocumentMetadata` declaring PDF/UA-2 conformance and
  the document language, so screen readers announce the right language
  and assistive tech sees a proper accessibility intent.

For `bjc4nyc` (CSP), the current build produces a ~550-page, ~37 MB PDF
covering Units 1–8.

## Dependencies

Local binaries:

- `ruby` (3.0+ — uses the standard library plus the `nokogiri` gem)
- `pandoc` (3.x)
- `lualatex` (default; needed for the tagged-PDF/UA-2 accessibility
  metadata block). `xelatex` and `pdflatex` also work for ASCII-only
  content if you pass `--engine=xelatex` etc.
- `makeindex` (ships with TeX Live; required for the trailing index)
- `pdftoppm` (only when using `--screenshots=N`)
- `qrencode` (optional; generates QR codes next to Snap! "run" links)
- `rsvg-convert` from `librsvg2-bin` (optional; converts SVGs to PDF
  for lossless embedding — pages with SVGs fall back to alt-text
  placeholders otherwise)

Ruby gems: `nokogiri`, `i18n` (the latter is used by the existing
build-tools code we reuse for `BJCCourse`).

```bash
apt-get install -y ruby pandoc texlive-luatex texlive-latex-extra \
                   texlive-fonts-recommended texlive-fonts-extra \
                   texlive-lang-spanish poppler-utils \
                   qrencode librsvg2-bin
gem install nokogiri i18n
```

`texlive-fonts-extra` is needed for the Latin Modern OpenType faces
that `lualatex` loads through `fontspec`; `texlive-lang-spanish` is
needed for `--language=es`.

## Usage

```bash
# From the bjc-r root:
ruby utilities/pdf-book/build.rb \
  --course=bjc4nyc \
  --language=en \
  --engine=xelatex \
  --screenshots=3
```

Common options:

| Flag                | Default                          | Notes                                                  |
| ------------------- | -------------------------------- | ------------------------------------------------------ |
| `--course=NAME`     | `bjc4nyc`                        | Name of a file under `course/` (no `.html`).           |
| `--language=LANG`   | `en`                             | `en` or `es` — picks the matching topic file variants. |
| `--root=PATH`       | autodetected                     | Path to the `bjc-r` root.                              |
| `--output=DIR`      | `utilities/pdf-book/out`         | Build directory; PDF + `.tex` end up here.             |
| `--max-units=N`     | (all units)                      | Limit chapters built. Handy for fast iteration.        |
| `--max-pages=N`     | (all pages)                      | Hard cap on total pages processed.                     |
| `--engine=BIN`      | `lualatex`                       | `xelatex` works too; `pdflatex` only for ASCII content.|
| `--no-pdf`          | off                              | Stop after writing `book.tex`.                         |
| `--screenshots=N`   | `0`                              | After PDF build, run `pdftoppm` on the first N pages.  |

## How it works

```
course/bjc4nyc.html
        │  (BJCCourse, existing build-tools)
        ▼
topic/nyc_bjc/1-intro-loops.topic, 2-conditionals-abstraction.topic …
        │  (BookBuilder.parse_topic_source — re-implemented because
        │   BJCTopic#get_content drops content after the second colon
        │   in headings like "Lab 1: Click Alonzo Game")
        ▼
{ unit, lab, page } triples
        │  (HTMLCleaner: strip <script>/<audio>/snap-run links,
        │   rewrite /bjc-r/img/... to local absolute paths, symlink
        │   images whose names contain LaTeX-unsafe chars, tag BJC
        │   callouts with text-marker sentinels)
        ▼
cleaned HTML fragment per page
        │  (LatexRenderer → pandoc -f html -t latex
        │   --shift-heading-level-by=2 --wrap=preserve;
        │   then swap XBJCBEGIN/END sentinels for \begin{bjc…}/\end)
        ▼
LaTeX fragments
        │  (BookBuilder wraps each in \chapter / \section / \subsection
        │   and concatenates with cover.tex + preamble.tex)
        ▼
out/book.tex
        │  (xelatex × 2 for TOC, then optional pdftoppm)
        ▼
out/book.pdf, out/screenshots/page-001.png …
```

## Why LaTeX (not HTML-to-PDF)?

The ticket noted this as an open question. We went with LaTeX because:

- The existing snap manual template is the design reference we wanted
  to match — it's LaTeX, so we get cover styling, brand colors, heading
  rules, and the cross-reference / index machinery for free by adapting
  it.
- `hyperref` gives a properly linked TOC + PDF outline in a single
  pass; HTML-to-PDF (wkhtmltopdf, weasyprint, headless Chrome) needs
  per-renderer hacks to produce a real outline at book scale.
- Pandoc does the heavy lifting of HTML → LaTeX, so we don't write a
  full HTML parser; we only pre-process the BJC-specific custom
  attributes (`class="learn"`, snap-run links, lazy GIFs, etc.).

## Known gaps vs. the web view

An audit of `llab/script/*.js` and the curriculum HTML surfaced these
things the web has and the PDF currently does not. Ordered roughly
by reader-visible impact.

**Interactive content**

- **Snap! "run" links** (`<a class="run">`, ~255) — rewritten to a
  clickable `snap.berkeley.edu/snap/snap.html#open:…` URL and (when
  `qrencode` is installed) emitted with a small QR code beside the
  link so print readers can scan to launch the project.
- **KaTeX math** (`.katex`, `.katex-block`, ~120) — the literal LaTeX
  source is pulled out of the span and emitted as real `$…$` / `\[…\]`
  math.
- **`.collapse` Bootstrap blocks** (~605) and native `<details>` —
  always rendered. The trigger text ("Click for hint") becomes a bold
  lead-in line followed by the previously-hidden content.
- **Self-check quizzes** (`<div class="assessment-data">`, ~503) —
  still need work. Question stems become index entries but the
  choices, correct answers, and inline feedback render as
  undecorated text.
- **Glossary hover popups** (`.hoverinfo`, ~72) — `glossary.js`
  AJAX-loads `/glossary/<term>.body` on hover. PDF keeps only the
  trigger text; the definition is never inlined.
- **w3-include-html sub-pages** — most `cur/teaching-guide/` pages are
  empty stubs that load content via `w3-include-html="..."` at runtime.
  The pipeline doesn't follow these, so teacher-guide PDFs would be
  near-empty. (Not currently in CI matrix; flag for the future.)
- **Color-swatch helpers** (`data-color`, ~8) silently vanish.
- **Syntax highlighting** — `<pre><code>` blocks are rendered in
  monospace but not colorized. Low-priority; ~56 Python blocks.

**Classes that would benefit from a mapping**

- `.snap` (~272) — handled. Renders as `Snap\textit{!}` via the
  `\snap{}` macro.
- `.imageRight` / `.imageLeft` (~602) — float captions; PDF gets
  inline placement, often misaligned with adjacent prose. Wrapping in
  `wrapfig` would match the web layout.
- `.alert .quoteBlue` / `.quoteGreen` / `.quoteOrange` / `.quoteYellow`
  (~115) — colored pull-quotes rendered as plain paragraphs.
- `.box-head` (~149), `.additional-info` (~173), `.stagedir` (~99) —
  semantic helpers that lose their styling.
- `.truth.bordered` / `.truthtable` (~27) — logic truth tables lose
  borders.
- `.saveAs` / `.newProject` (~74) — UI-instruction badges.

**Media drops**

- `~396` GIFs become italic alt-text placeholders. Extracting the
  first frame as a PNG (`ffmpeg`, `magick convert 'foo.gif[0]'`) would
  give a real image; the cleaner already has the hook in
  `rewrite_image_paths`.
- `~5` SVGs are converted to PDF via `rsvg-convert` (when installed)
  and embedded losslessly. Falls back to alt-text placeholder if the
  tool is missing.
- `.ap-standard` codes outside `.exam` boxes (~982) are stripped but
  not indexed. Could be added to "On the AP Exam" too if useful.

## Known limitations

- **Animated GIFs**: `lualatex`/`xelatex`/`pdflatex` can't embed GIF.
  The cleaner replaces them with italic alt-text placeholders. If
  `convert` / `magick` is available, extracting a first frame is a
  future-work item.
- **`<table>`-heavy pages** sometimes overflow the text width when
  pandoc emits `longtable` with fixed column widths.
- **Remote images** (`<img src="http://…">`) — anything not under
  `/bjc-r/` is skipped; the build report lists them.

## Files

- `build.rb` — CLI entry point.
- `lib/book_builder.rb` — walks the course, calls the renderer, writes
  `book.tex`, invokes `xelatex`.
- `lib/html_cleaner.rb` — Nokogiri pre-processor: image-path rewriting,
  unsupported-node stripping, callout tagging.
- `lib/latex_renderer.rb` — `pandoc` wrapper + sentinel post-processing.
- `templates/preamble.tex` — Snap-manual-derived preamble: scrbook,
  brand colors, callout `mdframed` envs, pandoc highlighting helpers.
- `templates/cover.tex` — TikZ cover page (`\bjccoverpage`).
- `out/` — build output (PDF, `.tex`, `latex.log`, `build-report.txt`,
  `screenshots/`, `img-cache/` of symlinks to unsafe-named images).
