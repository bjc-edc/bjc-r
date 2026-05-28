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

Ruby gems: `nokogiri`, `i18n` (the latter is used by the existing
build-tools code we reuse for `BJCCourse`).

```bash
apt-get install -y ruby pandoc texlive-luatex texlive-latex-extra \
                   texlive-fonts-recommended texlive-fonts-extra \
                   texlive-lang-spanish poppler-utils
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

## Known limitations

- **Animated GIFs**: `pdflatex`/`xelatex` can't embed GIF. The cleaner
  replaces them with italic alt-text placeholders. If `convert` /
  `magick` is available, extracting a first frame is a future-work
  item.
- **Snap! project run-links** (`<a class="run">`) are stripped. The
  rendered PDF doesn't have anywhere to "run" them; we could optionally
  swap them for a printed URL.
- **`<table>`-heavy pages** sometimes overflow the text width when
  pandoc emits `longtable` with fixed column widths.
- **`<svg>`** is dropped (same reason as GIF). Most BJC pages don't
  rely on inline SVG, but some external embeds will be missing.
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
