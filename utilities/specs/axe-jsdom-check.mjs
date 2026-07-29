#!/usr/bin/env node
//
// Lightweight, browser-free accessibility pre-check.
//
// Runs axe-core against page HTML in jsdom to catch *structural* WCAG
// violations (list nesting, image-alt, labels, etc.) without needing Ruby,
// Capybara, or a headless Chrome. This is a fast triage tool for iterating on
// fixes locally — it is NOT a replacement for the real suite in
// `accessibility_spec.rb`.
//
// IMPORTANT LIMITATION: jsdom does not compute layout, so the `color-contrast`
// rule cannot be evaluated and is filtered out of the results. Always confirm
// final passes with the full rspec/axe suite (which runs in a real browser).
//
// Setup (from anywhere with node available):
//   npm install axe-core jsdom
//
// Usage:
//   node axe-jsdom-check.mjs <file.html> [more.html ...]
//   node axe-jsdom-check.mjs path/to/page.html path/to/page.es.html
//
// Exit code is non-zero if any page has structural violations.

import { JSDOM } from 'jsdom';
import axe from 'axe-core';
import fs from 'fs';
import path from 'path';

// Mirrors the `required_a11y_standards` in accessibility_spec.rb.
const WCAG_TAGS = ['wcag2a', 'wcag2aa'];

// Rules we skip here because jsdom can't evaluate them reliably (no layout).
const SKIP_RULES = new Set(['color-contrast']);

async function checkFile(file) {
  const html = fs.readFileSync(file, 'utf8');
  const dom = new JSDOM(html, { runScripts: 'outside-only', pretendToBeVisual: true });
  const { window } = dom;

  // Inject and run axe-core *inside* the jsdom window so its global lookups
  // (window/document) resolve correctly.
  window.eval(axe.source);
  const results = await window.axe.run(window.document, {
    runOnly: { type: 'tag', values: WCAG_TAGS },
  });

  const violations = results.violations.filter((v) => !SKIP_RULES.has(v.id));

  if (!violations.length) {
    console.log(`✓ ${file} — no structural violations (color-contrast not checked)`);
    return 0;
  }

  console.log(`✗ ${file}`);
  for (const v of violations) {
    console.log(`  ## ${v.id} (${v.impact}) — ${v.help}`);
    for (const n of v.nodes) {
      console.log(`     target: ${n.target.join(' ')}`);
      console.log(`     html:   ${n.html.slice(0, 180).replace(/\s+/g, ' ').trim()}`);
    }
  }
  return violations.length;
}

const files = process.argv.slice(2);
if (!files.length) {
  console.error('usage: node axe-jsdom-check.mjs <file.html> [more.html ...]');
  process.exit(2);
}

let total = 0;
for (const f of files) {
  try {
    total += await checkFile(path.resolve(f));
  } catch (err) {
    // jsdom logs an unimplemented-canvas warning for some pages; that's benign.
    if (!String(err).includes('getContext')) {
      console.error(`! ${f}: ${err.message || err}`);
      total += 1;
    }
  }
}
process.exit(total ? 1 : 0);
