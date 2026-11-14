---
name: bjc-frontend-changes
description: Make and verify CSS, layout, navigation bar, footer, and self-check quiz changes in bjc-r without regressions. Use for any visual or styling ticket, Bootstrap class changes, responsive or mobile layout fixes, changes under `llab/` or `css/`, and whenever a change needs screenshots or a list of pages to test.
---

# CSS, layout, and llab changes

Visual tickets in this repo have taken the most back-and-forth by far, almost always
because a fix was reported done without being looked at in a browser at the width
where the problem was. Verify first, report second.

## Where things live

| File | Holds |
| --- | --- |
| `llab/css/default.css` | Framework styles: navbar, quiz cards, page chrome |
| `css/bjc.css` | BJC-specific styles, and one-page rules at the bottom |
| `llab/script/curriculum.js` | Navbar, page navigation, footer |
| `llab/script/quiz/multiplechoice.js` | Self-check questions |
| `llab/script/library.js` | Helpers, translations (`llab.t`), config constants |
| `llab/loader.js` | The lists of CSS and JS files every page loads |

Curriculum pages get their CSS from `loader.js`. The root `index.html` is different:
it does not use the loader, so check which stylesheets a page really loads before
moving rules between files.

Before adding a rule, search both CSS files for an existing one. Reuse Bootstrap 5
utilities and the grid instead of new wrapper classes. Do not duplicate what
Bootstrap already ships (for example `.visually-hidden`).

## Change one thing

- Fix what the ticket names. If you spot something else, list it at the end.
- Do not restyle neighbouring elements "while you are there".
- If the user supplies exact CSS, use it as given.
- When a fix involves a deliberate workaround (a negative margin, a duplicated
  rule), add a one-line comment saying so.
- If two approaches have failed, stop and describe the trade-off rather than trying
  a third variation. Commit the working state before attempting a different design.

## Verify in a browser

Start the site with `./run-server --no-open` and load real pages with their query
string. `bundle exec ruby .agents/skills/bjc-live-pages/scripts/live_pages.rb --urls`
prints valid URLs.

Check every change at these widths: **320, 375, 768, 1280**. Most regressions were
between 375 and 780px, where the navbar and footer wrap.

Pages that exercise the shared pieces:

| What | Page |
| --- | --- |
| First page of a unit (disabled "previous" button) | `cur/programming/1-introduction/1-building-an-app/1-start-your-first-snap-app.html?topic=nyc_bjc/1-intro-loops.topic&course=bjc4nyc.html` |
| Self-checks with images | `cur/programming/1-introduction/2-gossip-and-greet/5-if-else.html?topic=nyc_bjc/1-intro-loops.topic&course=bjc4nyc.html` |
| Many self-checks on one page | `cur/programming/1-introduction/unit-1-self-check.html?topic=nyc_bjc/1-intro-loops.topic&course=bjc4nyc.html` |
| Every content box style | `docs/style_guide.html` |
| Topic page | `topic/topic.html?topic=nyc_bjc/1-intro-loops.topic&course=bjc4nyc.html` |
| Course page | `course/bjc4nyc.html` |
| Spanish (longer strings) | the `.es.html` version of any of the above, with `.es.topic` |
| Landing page (no loader) | `index.html` |

All paths are under `http://localhost:8000/bjc-r/`.

For navbar work also check: every dropdown opens with the keyboard (Space and
Enter), opening one menu closes the others, nothing overflows the right edge, and
the logo is not covered. For quiz work check the unanswered, correct, partially
correct, and incorrect states, and that only the card header changes colour.

Take screenshots at the widths that matter and attach them. If you cannot run a
browser, say so; do not describe the result as verified.

## Then run the specs

```sh
bundle exec rspec utilities/specs/self_check_feedback_spec.rb   # quiz changes
bundle exec rspec utilities/specs --tag dynamic_nav             # navbar / navigation
bundle exec rspec utilities/specs/accessibility_spec.rb --tag general_wcag20
```

If you rename a class that a spec selects on (for example `.hidden` to `.d-none`),
update the spec in the same change.

## Report

End with: what changed, the widths and pages you checked, screenshots, which specs
ran, and a short list of pages for the reviewer to open.
