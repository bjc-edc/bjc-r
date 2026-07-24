# Common Cartridge Export for BJC

Builds an [IMS Common Cartridge 1.3](https://www.imsglobal.org/cc/index.html)
(`.imscc`) package from a BJC course so a teacher can import all the units,
labs, sidebar resources, and gradeable assignments into their LMS in one go.

Written in Ruby and reuses the existing parsers in `utilities/build-tools/`
(`BJCCourse` for the course-HTML topic list, `BJCTopic` for the `.topic` DSL).
No duplicate topic parser.

What ends up in the LMS:

- **Modules** for each unit, with **sub-sections per lab** (e.g. "Lab 2: Gossip").
- **QTI 1.2 quizzes** auto-extracted from the BJC self-check HTML (`<div class="assessment-data">` blocks) — questions, choices, correct answers, and per-choice feedback all come along.
- **LMS assignments** auto-generated for every page where students build something (any page with a `<div class="forYouToDo">` box). Each assignment description links to the page and asks the student to submit a Snap! share URL or upload their `.xml` project.
- **Explicitly authored assignments** for high-stakes work (AP Create Task practice + official, etc.) — written in the config YAML and placed in the right module.
- **Web links** to the rest of the curriculum pages (readings, summary pages, sidebar resources).

## Quick start

```bash
cd utilities/cc-export
bundle install                                  # if you haven't already
ruby cc_export.rb configs/csp.yml --mode iframe # default; tiny package
ruby cc_export.rb configs/csp.yml --mode copy   # bundles every page + asset
ruby cc_export.rb configs/csp.yml --all         # both at once
```

Pre-built iframe cartridges are checked into `dist/`. Re-run the tool when
content, assignments, or sidebar links change.

### Specs

```bash
rspec utilities/specs/cc_export/cc_export_spec.rb
```

The spec doesn't require the full Capybara setup in `utilities/specs/spec_helper.rb`
— it only loads the builder, packager, and `BJCTopic`/`BJCCourse`. Runs in ~1 sec.

## Modes

| Mode | Tradeoff |
|---|---|
| **`iframe`** | Each page becomes an IMS Web Link (`imswl_xmlv1p3`) pointing to `https://bjc.edc.org/bjc-r/...`. Tiny cartridges (~100 KB), always current, but the LMS must be online and the BJC site has to be reachable for students. Canvas, Moodle, and Schoology render web links inline (configurable as iframe or "new tab"); D2L/Brightspace renders them as outbound links. |
| **`copy`** | HTML pages are bundled into the cartridge along with referenced assets (images, JS, CSS, etc.) and absolute `/bjc-r/...` paths are rewritten to relative paths. Self-contained, ~90–190 MB for the full courses, works offline. Use this when the school blocks `bjc.edc.org`, or for archival. Not committed under `dist/` (too large for git). |

### Copy-mode limitations

The path rewriter only touches HTML attributes (`src`, `href`, `data-src`). CSS
files that reference assets via `url(...)` still point at `/bjc-r/...`, which
means the bundled pages need the live CSS at viewing time for full styling.
Pages render perfectly with the live site reachable; without it they show plain
HTML. This is acceptable for the offline-fallback use case but worth fixing if
the cartridge becomes the primary distribution channel.

## Config schema (YAML)

```yaml
title: "Beauty and Joy of Computing — AP CSP"
identifier: "bjc-csp"                # stable id; affects resource identifiers
language: "en"                       # ISO 639-1
course_file: "course/bjc4nyc.html"   # relative to bjc-r root
base_url: "https://bjc.edc.org"      # host for absolute URLs
description: |
  Multi-line description.

# Sidebar links surfaced as a top-level "BJC Resources" module.
sidebar_links:
  - title: "Snap! Programming Environment"
    url: "https://snap.berkeley.edu/snap/snap.html"
  - title: "Snap! Cheat Sheet"
    url: "/bjc-r/cur/snap-cheat-sheet.html"  # leading / -> base_url is prepended
  # - target: "_iframe"  # optional; default "_blank"

# Turn HTML self-check questions (<div class="assessment-data">) into real CC
# QTI 1.2 quizzes. Defaults to on when the key is present.
auto_quizzes:
  enabled: true

# For every curriculum page with <div class="forYouToDo"> (i.e. lab pages
# where students build something), emit an LMS assignment with a link to the
# page and submission instructions (Snap! share URL or .xml upload).
auto_assignments:
  enabled: true
  points: 10
  submission_types: [online_text_entry, online_upload]
  skip_topics:
    - "nyc_bjc/create-task.topic"   # high-stakes assignments cover this topic
  # exclude_urls:
  #   - "*/some-discussion-only-page.html"

# High-stakes assignments authored explicitly. Each one becomes an LMS
# assignment placed inside the module of the topic it references. Drop `topic`
# to put it in a dedicated module.
assignments:
  - id: "ap-create-task-practice"
    title: "AP Create Task — Practice (with PPR draft)"
    topic: "nyc_bjc/create-task.topic"
    points: 50
    submission_types: [online_upload, online_text_entry]
    description: |
      Multi-line description supported.
      Blank lines become paragraph breaks in the LMS.
```

## LMS compatibility

The exporter emits four kinds of resources. How well each one survives import
depends on the target LMS:

| LMS | Web links | Quizzes (QTI 1.2) | Auto-assignments | Manual assignments |
|---|---|---|---|---|
| **Canvas** | Native (inline render configurable) | Native — questions + feedback + correct-answer scoring all come through | Native — reads the Canvas `<assignment>` extension; becomes a graded submission box | Native (uses Canvas extension) |
| **Moodle 4.x** | URL resource | Imports as a real Moodle quiz with grading | Comes in as a URL resource; teacher re-categorizes as Assignment activity if grading needed | Same — re-categorize post-import |
| **Schoology** | Web Link item | Imports as a Schoology test/quiz with grading | Imports as Web Link; convert to assignment in UI if you want submissions | Same as auto-assignments |
| **D2L Brightspace** | Quicklink | Imports as a Brightspace Quiz, including feedback | Imports as content topic; teacher promotes to Assignment to get a submission folder | Same as auto-assignments |
| **Blackboard Learn (Original)** | Web Link | Imports as a Blackboard Test, mostly with feedback | Imports as a content item; manual conversion to Assignment for grading | Same |
| **Blackboard Learn (Ultra)** | Web Link | Imports but per-choice feedback is often dropped in Ultra | Becomes a Document — Ultra has weaker CC support; manual cleanup likely | Same |
| **Sakai** | Web Link in Lessons | Imports via Tests & Quizzes; check that feedback survived | Imports as Lessons web link | Same |
| **Open edX** | External URL | Limited — many CC quiz features (per-choice feedback) flatten to "show feedback after submission" | External URL; manual conversion needed | Same |
| **Google Classroom** | n/a — see section below | n/a | n/a | n/a |

**Practical short version:** Canvas, Moodle, Schoology, and D2L all turn the
QTI quizzes into real, grade-able quizzes with feedback. Blackboard Ultra and
Open edX are workable but expect to clean up some items by hand. Anywhere that
doesn't recognize Canvas's assignment-XML extension still sees the same
resource as a web link with submission instructions in the description — so
no information is *lost*, the teacher just clicks "Convert to assignment" once
per item if they want gradebook entries there.

### What if the school uses Google Classroom?

Google Classroom (and Google for Education in general) **does not import
Common Cartridge files** — that's a longstanding policy, not a bug. The
practical options for teachers:

1. **Post links directly.** Classroom can attach any URL as a Material or
   Assignment. The fastest path is for the teacher to create a Classroom topic
   per unit and post links to the BJC pages. Cumbersome, but it's the path
   most BJC-on-Classroom teachers actually use today.
2. **Use a bridge LMS.** Canvas Free for Teachers, Schoology Basic, and
   Moodle.org's free hosting all import these cartridges and integrate with
   Google Classroom via OAuth/single sign-on. Students see Classroom; the
   teacher manages the BJC content in the bridge LMS.
3. **Use a third-party converter.** There are commercial tools that ingest a
   Common Cartridge and post the contents to Classroom as Materials and
   Assignments (e.g. Kiddom, Edpuzzle, Pear Deck Tutor's import flow, and a
   few others) — quality and completeness vary, and none are first-party
   Google. Worth piloting before recommending broadly.
4. **LTI 1.3.** Classroom has an [LTI add-ons program](https://support.google.com/edu/classroom/answer/12597901)
   (rolling out 2024+) — once BJC has an LTI tool provider, teachers could
   attach Snap! / curriculum pages as Classroom add-ons. This is the most
   future-proof path but requires hosting BJC as an LTI tool, which is
   separate work from this exporter.

The short answer to "is there a tool to build a Google Classroom site for
BJC?" is **no first-party tool exists today**. The team's best near-term
deliverable for Classroom-using teachers is probably:

- A short Markdown "BJC for Google Classroom" guide (per-unit lists of links
  + suggested assignments + submission instructions copy-paste-able into a
  Classroom assignment), and
- An optional CSV export that maps onto the [Classroom course-content import
  format](https://support.google.com/edu/classroom/answer/9216691) — which
  *does* accept structured spreadsheets even though it doesn't accept CC.

Both are good follow-ups to this exporter and would reuse the same builder.

### Are there alternatives to Common Cartridge?

- **LTI 1.3** — for live integration (gradebook passback, user identity, deep
  linking). Better than CC for ongoing courses, but requires hosting an LTI
  tool provider for BJC. Out of scope for this exporter; possible future work.
- **SCORM 2004 / 1.2** — older, originally for corporate training. Most LMSes
  still import it; pages would be packaged as a SCORM "SCO" with completion
  tracking. Heavier to author than CC; not recommended unless a partner
  explicitly requires it.
- **QTI 3.0** — the modern QTI revision. CC 1.x ships QTI 1.2 (what this
  exporter produces); QTI 3 is supported by a smaller but growing set of
  importers. Worth revisiting once Canvas/D2L finish their QTI 3 rollouts.
- **xAPI (Tin Can)** — a learning-record protocol, not a packaging format.
  Pairs with CC/LTI rather than replacing them.
- **Thin Common Cartridge** — a stripped-down profile (1.2+) limited to web
  links and basic LTI launches. What this exporter produces in `iframe` mode
  is effectively a superset of Thin CC.

## Repository layout

```
utilities/cc-export/
├── README.md             # this file
├── cc_export.rb          # CLI entrypoint
├── lib/
│   ├── builder.rb        # Cartridge construction (uses BJCCourse + BJCTopic)
│   ├── cartridge.rb      # Plain structs for the in-memory cartridge
│   ├── copy_resources.rb # copy-mode asset bundling + path rewriting
│   ├── manifest_writer.rb# imsmanifest.xml + per-resource XML (Nokogiri)
│   ├── packager.rb       # shells out to `zip` to produce the .imscc
│   ├── page_inspector.rb # detects quiz markup + student-work blocks per page
│   ├── quiz_extractor.rb # parses .assessment-data divs into a Quiz struct
│   ├── qti_writer.rb     # serialises a Quiz to IMS QTI 1.2 / CC assessment XML
│   └── assignment_template.rb # HTML body for auto-generated work assignments
├── configs/
│   ├── csp.yml           # AP CSP — English; has the Create Task assignments
│   ├── csp-es.yml        # AP CSP — Spanish; same assignment list, translated
│   └── sparks.yml        # BJC Sparks; sample unit project assignment
└── dist/                 # pre-built iframe-mode .imscc files (committed)

utilities/specs/cc_export/
└── cc_export_spec.rb     # RSpec smoke tests; doesn't require capybara
```

## Adding a new course

1. Drop a new YAML file in `configs/`.
2. Point `course_file` at the course HTML and set the language.
3. List the assignments you want graded in the LMS.
4. Run `ruby cc_export.rb configs/<your-file>.yml --mode iframe`.

For Spanish (or any other language) mirror an existing config, change
`course_file` to the `.es.html` variant, translate the visible strings, and
point each assignment's `topic` field at the corresponding `.es.topic` file —
the assignment list itself should match the English version 1:1.

## Future work

- Validate `imsmanifest.xml` against the IMS XSDs in CI.
- Rewrite CSS `url(...)` references in copy mode so cartridges are fully
  self-contained without the live site.
- Optional **LTI 1.3 deep-link** mode in addition to web links, so the LMS
  passes user identity through to a tool-provider proxy in front of `bjc.edc.org`.
- A "split" mode that emits one cartridge per unit, for teachers who pace
  units independently.
