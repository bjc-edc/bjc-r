# CSP Course Migration Plan (DRAFT)

Status: **draft for discussion** — nothing here is decided until the
"Decisions" section says so. Written November 2026.

Companion doc: [Build tools roadmap](./build-tools-roadmap.md) — what we would
add to `utilities/build-tools` to generate the new course.

## 1. Goals

1. Rewrite the AP CSP course for the **2027–2028** school year, and keep
   updating it during that year.
2. Leave room for a **second edition** (parallel or partial revision) for
   2028–2029.
3. Keep **all courses in this one repository**.
4. **Every existing URL keeps working**, either by serving what it serves today
   or by redirecting to the new equivalent.
5. New URLs are dramatically simpler:
   - `/bjc-r/courses/csp.html`
   - `/bjc-r/courses/csp/<unit>/<lab>/<page>.html`
6. Introduce a build step for the new course so that pages arrive in the
   browser complete, instead of being assembled by `llab` at runtime.

### Non-goals

- Converting the existing ~1,700 legacy pages to the new system. They stay as
  they are, served by `llab`.
- Changing Sparks / Middle School. They can adopt the new system later.
- Reducing the size of the repository (1.4 GB checkout, 1.1 GB `.git`). Worth
  doing, but as its own project.

## 2. Where we are today

| | |
| --- | --- |
| HTML pages | ~1,730 (about 880 of them under `old*` directories) |
| Spanish pages | 253 `*.es.html`, 9 `*.es.topic` |
| Topic files | 148 `.topic` |
| Images | ~7,400 files, 673 MB in `img/`, 538 MB in `sparks/` |
| Runtime | `llab/` — about 3,000 lines of our own JS plus jQuery and Bootstrap |
| Build tools | `utilities/build-tools` — about 1,600 lines of Ruby |

How a page works now:

- A curriculum page is a bare HTML document with one script tag,
  `/bjc-r/llab/loader.js`.
- In the browser, `llab` injects the CSS and JS, fetches and parses the unit's
  `.topic` file, and builds the navbar, title, previous/next buttons, progress
  dots, footer, translation menu, quizzes and content anchors.
- Which course and unit a page belongs to comes from the query string
  (`?topic=nyc_bjc/1-intro-loops.topic&course=bjc4nyc.html`). 426 content pages
  hardcode those parameters in their own links.
- The Ruby build tools scrape curriculum HTML to generate the vocabulary,
  self-check, exam-reference and "@ Work" pages. Their output is committed, and
  they rewrite the "Unit Review" section of `.topic` files.

What this costs us:

- Nothing identifies which pages are live. That is how ~880 pages accumulated
  in `old*` directories.
- Broken links are only found by clicking.
- The same logic exists twice — for example anchor IDs are numbered by
  `llab.anchorID` in the browser and `anchor_id` in Ruby, and the two must
  agree.
- Pages render late and shift as `llab` builds them.

## 3. Decisions

### Proposed (need a yes/no)

| # | Proposal |
| --- | --- |
| D1 | Legacy content (`cur/`, `topic/`, `course/`, `sparks/`, `img/`, `prog/`, `llab/`) is **frozen in place** and published unchanged. |
| D2 | The new course is **built**; the build output is what gets deployed. Generated files are never committed. |
| D3 | Course structure lives in a **manifest** (one YAML file per course edition), replacing `.topic` files and `course/*.html` for new content. |
| D4 | New URLs have **no query strings and no year**. The unversioned URL always means the current edition. |
| D5 | Old URLs are preserved by D1; retired pages are replaced by **generated redirect stubs**. |
| D6 | New content keeps the **existing class vocabulary** (`forYouToDo`, `takeNote`, `ifTime`, `vocab`, …) so authors' habits and old content carry over. |

### Open

| # | Question | Notes |
| --- | --- | --- |
| O1 | **Which generator?** Extend our Ruby build tools, or adopt Eleventy? | See section 9. The roadmap doc describes the "extend our own" path. |
| O2 | How do bjc.berkeley.edu and bjc.edc.org deploy today? | Determines whether CI publishes a built branch or the servers build. |
| O3 | Does `cs10/bjc-r` still depend on `llab` or content from this repo? | Another reason to freeze rather than edit `llab`. |
| O4 | Are source pages complete HTML documents or fragments with front matter? | `.gitignore` has Dreamweaver entries, which suggests some authors use a WYSIWYG editor that wants complete documents. |
| O5 | Markdown as a second authoring format? | Cheap to add later; not needed for launch. |
| O6 | When does the current CSP course stop being the default? | Drives the redirect schedule in section 6. |

## 4. Target repository layout

```
bjc-r/
  content/                         # NEW: source for built courses
    courses/
      csp/
        course.yml                 # current edition: units → labs → pages
        editions/                  # other editions, when they exist
          2028.yml
        intro/                     # one directory per unit
          unit.yml                 # optional unit-level metadata
          click-alonzo/            # one directory per lab
            programming-a-game.html
            programming-a-game.es.html
            img/                   # images used only by this lab
            prog/                  # Snap! projects used only by this lab
        teacher/                   # teaching guide, same shape
  site/                            # NEW: layouts, partials, CSS, small runtime JS
  _site/                           # NEW: build output (gitignored)

  cur/ topic/ course/ img/ prog/   # LEGACY: frozen, published unchanged
  sparks/ llab/ css/               # LEGACY
  utilities/build-tools/           # the build
```

Notes:

- Source lives under `content/`, not `courses/`, so that a fork served raw by
  GitHub Pages never exposes unbuilt pages at the real URLs.
- Images and Snap! projects sit beside the pages that use them. Shared assets
  (icons, block images) stay in a shared directory.
- Directory and file names are **slugs without numbers**. Order comes from the
  manifest, so reordering a lab does not change any URL.

### The manifest

```yaml
# content/courses/csp/course.yml
title: Beauty and Joy of Computing — AP CSP
slug: csp
languages: [en, es]
units:
  - slug: intro
    title: "Unit 1: Introduction to Programming"
    labs:
      - slug: click-alonzo
        title: "Lab 1: Click Alonzo Game"
        pages:
          - programming-a-game
          - saving-projects
          - { page: keeping-score, type: quiz }
```

The manifest is the single answer to "is this page live?". Anything under
`content/` that no manifest references is reported by the build as an orphan.

## 5. URL scheme

| What | URL |
| --- | --- |
| Course list | `/bjc-r/courses/` |
| Course home | `/bjc-r/courses/csp.html` |
| Unit | `/bjc-r/courses/csp/intro.html` |
| Page | `/bjc-r/courses/csp/intro/click-alonzo/programming-a-game.html` |
| Spanish page | `…/programming-a-game.es.html` (same suffix convention as today) |
| Teaching guide | `/bjc-r/courses/csp/teacher/intro.html` |
| Frozen past edition | `/bjc-r/courses/csp-2027/…` |
| Draft next edition | `/bjc-r/courses/csp-2028/…` |

- `/bjc-r/course/` (singular, legacy) and `/bjc-r/courses/` (plural, new) do
  not collide.
- The `/bjc-r/` prefix is a single build setting.

## 6. Preserving and redirecting old URLs

Three states for any old URL:

1. **Unchanged** (default). The file is still published at the same path and
   still runs on `llab`. `?topic=…&course=…` links keep working.
2. **Bannered.** Unchanged, plus a "there is a newer version of this page"
   notice. This needs one small change in `llab` and a lookup table.
3. **Redirected.** The old file is replaced in the build output by a stub:
   `<meta http-equiv="refresh">` plus `<link rel="canonical">` pointing at the
   new page. Query strings are ignored.

How redirects are declared — in the new page, next to the content that
replaces the old one:

```yaml
redirect_from:
  - /bjc-r/cur/programming/1-introduction/1-building-an-app/1-start-your-first-snap-app.html
```

A central `content/redirects.yml` covers old pages that map to something other
than one new page (a unit home, or nothing).

Why stubs: GitHub Pages cannot do server-side redirects, and stubs work the
same on GitHub Pages, bjc.berkeley.edu and bjc.edc.org. On the Apache hosts we
can additionally generate real 301 rules into `.htaccess`.

Proposed schedule (depends on O6):

| When | Old CSP URLs |
| --- | --- |
| Until launch | Unchanged |
| 2027–2028 | Bannered — teachers finishing on the old course are not disrupted |
| Summer 2028 or later | Redirected, unit by unit |

The source files for redirected pages stay in the repository; only the
published output changes.

## 7. Editions

- `course.yml` is the current edition and is edited live through the year.
- A **partial revision** is a second manifest (`editions/2028.yml`) that lists
  mostly the same page files and points at new files only where content
  differs. Unchanged pages are not copied.
- Each manifest is built to its own URL space (`csp-2028/`), so one source
  page can appear in two editions.
- At rollover: the outgoing edition is built once more to `csp-2027/` and
  frozen, and the new manifest becomes `course.yml`.
- A git tag is cut at each rollover.

The cost of year-less URLs: a bookmarked page can change or disappear at
rollover. Redirect stubs cover the disappearing case.

## 8. What happens to `llab`

`llab` is frozen for legacy pages. For built pages:

| `llab` feature | New home |
| --- | --- |
| `loader.js` script/CSS injection | Real `<link>` and `<script>` tags in the layout |
| `topic.js` (parse and render `.topic`) | Manifest + unit template |
| `course.js` | Course template |
| Title, navbar, prev/next, progress, footer | Layout |
| Translations menu (probes for translated files at runtime) | Layout — the build knows which translations exist |
| Link rewriting (`processLinks`), content anchors | Build-time HTML transform |
| KaTeX, syntax highlighting | Build-time render |
| Snap! run links (`a.run`) | Build-time transform |
| Quiz markup expansion | Build-time transform; interaction stays in JS |
| Fetch-and-swap page navigation | Probably dropped — pages arrive complete |
| Quiz interaction, click-to-play GIFs, dev-comment toggle, feedback link, analytics, Sentry, search | Small runtime script, loaded only where used |
| jQuery | Dropped for built pages |
| Bootstrap | Keep the CSS; trim to what is used |

## 9. Generator choice (O1)

| | Extend our Ruby build tools | Adopt Eleventy |
| --- | --- | --- |
| Starting point | Topic parser, vocab/self-check/@Work generators, i18n, specs already exist | Starts empty; our generators are ported or called as a pre-step |
| Toolchain | Ruby only (already required) | Adds Node |
| Templates, routing, watch, dev server | We write and maintain them | Provided |
| One page in several editions | We design it; straightforward with a manifest | Supported via data-driven pagination |
| Directives | Nokogiri transforms we already know | Transforms, shortcodes, Markdown plugins |
| Pandoc | Shell out from Ruby | Custom template format |
| Risk | Scope creep; depends on whoever maintains it | Framework churn; second language in the repo |

Either path produces the same content layout, manifests and URLs, so sections
4–8 do not depend on this choice. The companion roadmap scopes the Ruby path
so its real cost can be judged.

## 10. Content migration

Most of the course is being rewritten, so this is mainly a porting aid for the
pages that carry over.

A `port` command takes an old page path and a new location and:

1. Copies the page, removing the `loader.js` script tag.
2. Rewrites internal links to the new URLs, dropping `?topic=…&course=…`.
3. Moves the images and Snap! projects the page uses next to it, and rewrites
   their paths. Assets shared with legacy pages are copied, not moved.
4. Adds `redirect_from` for the old path (inactive until the schedule in
   section 6 says so).
5. Does the same for the `.es.html` sibling if there is one.

A second command converts a `.topic` file into a manifest fragment.

Per unit: draft manifest → port or write pages → build with zero broken links
and zero orphans → accessibility pass → review.

## 11. Translations

- Keep the `page.es.html` suffix convention.
- The manifest lists the course's languages. For each language the build uses
  the translated page if it exists and reports the ones that are missing.
- Whether a missing translation falls back to English or is left out of the
  Spanish navigation is a per-course setting.
- UI strings move from `llab.TRANSLATIONS` and `bjc_translations.yml` into one
  file used by the layouts.

## 12. Hosting and deployment

- CI builds on every push to `main` and publishes the result. Proposed: push
  the output to a `published` branch that the Apache hosts pull, so they never
  need Ruby or Node (depends on O2).
- GitHub Pages switches from "serve the branch" to "deploy from Actions".
  Forks need Actions enabled to get a working preview.
- Pull requests get a build, link check and (ideally) a preview URL.

## 13. Quality checks the build makes possible

- Broken internal links and missing images fail the build.
- Orphan report: pages and assets no manifest references.
- Missing-translation report.
- The existing axe accessibility suite runs against static output, without
  waiting for `llab` to finish rendering.
- HTML validation of every built page.

## 14. Proposed timeline

| When | What |
| --- | --- |
| Nov 2026 – Jan 2027 | Settle O1–O4. Spike: one unit end to end (manifest, layout, quiz, Spanish, deploy). |
| Feb – Mar 2027 | Build tools milestones M1–M5 (see roadmap). Authoring guide. Port command. |
| Mar – Jun 2027 | Content authoring. Tooling changes limited to fixes. |
| Jun – Jul 2027 | Summer PD uses the new course. Feedback fixes. |
| Aug 2027 | Launch at `/bjc-r/courses/csp.html`. Old course bannered. |
| 2027–2028 | Live updates. Draft `editions/2028.yml` if needed. |
| Summer 2028 | Rollover: freeze `csp-2027/`, begin redirecting old CSP URLs. |

Dates are a proposal to react to, not commitments.

## 15. Risks

| Risk | Mitigation |
| --- | --- |
| Tooling is not ready when authors need it | Spike first; authors can write pages against the class vocabulary before the build is finished, because the page format barely changes |
| Build becomes a barrier for non-technical authors | One command (`./run-server`) builds and watches; CI builds for anyone who edits on GitHub |
| Redirects break links teachers have saved | Banner for a full year before redirecting; stubs rather than deletions |
| Two systems (legacy + built) drift | Legacy is frozen; shared CSS is the only overlap |
| Custom generator grows without limit | Fixed milestone list in the roadmap; re-evaluate against Eleventy after the spike |
