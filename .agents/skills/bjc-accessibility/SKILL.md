---
name: bjc-accessibility
description: Fix axe / WCAG accessibility failures in bjc-r pages and maintain the accessibility specs. Use when a ticket pastes failing `accessibility_spec.rb` output, mentions axe, WCAG, a11y, screen readers, focus styling, or asks to make a page, table, image, or embed accessible.
---

# Accessibility fixes

The suite runs axe-core in headless Chrome against every live page. Each page has
two examples: WCAG 2.0 (`<course>_wcag20`, required) and WCAG 2.2 plus best practice
(`<course>_wcag22`, aspirational). CI reports both but does not block on them.

## Reproduce before you edit

Never fix from the pasted failure text alone. Run the failing page first so you can
see it fail and then see it pass. If Chrome is missing, run
`.agents/skills/bjc-env-setup/scripts/setup.sh --browser`.

```sh
# One page (matches on the example name, so a filename is enough)
bundle exec rspec utilities/specs/accessibility_spec.rb -e "4-brick-wall.es.html"

# One course and standard: bjc4nyc, bjc4nyc.es, sparks, bjc4nyc_teacher,
# sparks-teacher, general — each with _wcag20 or _wcag22
bundle exec rspec utilities/specs/accessibility_spec.rb --tag general_wcag20

# After a run, a compact count of failures by axe rule
ruby utilities/specs/spec_summary.rb
```

The spec opens every `<details>` and Bootstrap collapse before running axe, so
content inside "If There Is Time" and "Take It Further" boxes is tested. A page that
looks fine collapsed can still fail.

## Choosing the fix

Work down this list and stop at the first that applies.

1. **Shared cause, shared fix.** If the same rule fails on many pages, the cause is
   usually in `llab` JS or shared CSS. Fix it once there.
2. **Markup fix in the page.** Typical cases: a `<div>` or `<img>` directly inside
   `<ol>`/`<ul>` (wrap it in the `<li>` it belongs to), skipped heading levels, a
   table used for data without `<thead>` and `scope`, an image of a table or of text.
3. **Third-party embed.** If the failure is inside an iframe you do not control, add
   `data-a11y-errors="true"` to that one iframe. This is the only sanctioned
   exclusion and it must be per element so the exceptions stay visible in review.
   Do not exclude all iframes, and do not add to `SKIPPED_RULES`.

Constraints that have each been corrected in review before:

- **The page must look the same afterwards.** Raising a heading level is right
  semantically, but keep its visual size with CSS. Take a before and after
  screenshot of anything you restructure.
- **Do not hide things to pass a rule.** A disabled navigation button stays visible
  and in place, styled accessibly, rather than being removed. Layout must not jump.
- **Apply the identical change to the `.es.html` page**, translating any new visible
  text and labels.
- **No inline `<style>`.** Put new rules at the bottom of `css/bjc.css` with a
  comment naming the page.
- **Focus styling:** use `:focus-visible`, make `a` and `button` match, and check
  the ring has contrast against its real background (not blue on blue).
- **Colour:** any new colour pair must meet 4.5:1. State the measured ratio.
- **Check ARIA against axe**, not from memory. A wrong `role` is worse than none.
- Skip `old` paths and developer-only elements; see `bjc-live-pages`.

## Replacing an image with real markup

When converting an image of a table or diagram: use native elements, give a data
table `<thead>` and `scope="col"`, make the screen-reader label describe what this
specific table shows, and check it at phone width. If a wide table has to be split
in two for small screens, leave a short HTML comment saying why.

## Shape of the work

- One commit per lab or unit, so each can be reviewed and merged alone.
- For large batches, one pull request per unit (English and Spanish together) and a
  separate pull request for shared CSS/JS fixes. See `bjc-branches-and-prs`.
- Finish by re-running the same tag you started with and reporting the failure count
  before and after.
