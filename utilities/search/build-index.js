#!/usr/bin/env node
// Pagefind index builder for the BJC curriculum.
//
// Walks the chosen course HTML files, follows them into their .topic files,
// reads each linked lab page, and feeds the HTML to Pagefind with course /
// unit / lab filters attached. No source HTML is modified — filter markers
// are injected into an in-memory copy that's handed to Pagefind.
//
// Topic-file parsing is delegated to the canonical browser-side parser at
// llab/script/topic.js, loaded into Node via vm in llab-loader.js.
//
// Usage:  node build-index.js  [--courses=bjc4nyc.html,sparks.html,...]

import { createIndex } from 'pagefind';
import { load } from 'cheerio';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { loadLlab, topicToLabs } from './llab-loader.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..');

// Courses to index by default. Each is the basename inside /bjc-r/course/.
const DEFAULT_COURSES = ['bjc4nyc.html', 'bjc4nyc.es.html', 'sparks.html'];

// Display names override the course HTML <title>. Add an entry for every
// course you index — defaults fall back to the <title> text.
const COURSE_DISPLAY_NAMES = {
  'bjc4nyc.html': 'BJC AP CS Principles',
  'bjc4nyc.es.html': 'BJC AP CS Principles',
  'sparks.html': 'BJC Sparks',
  'sparks.es.html': 'BJC Sparks',
};

// Page "kind" — used for the `kind` filter so users can include/exclude
// end-of-unit summary content (vocab, self-checks, exam refs). Mirrors
// BJCTopic#is_summary_page? in utilities/build-tools/topic.rb.
function pageKindFromUrl(url) {
  if (/\/summaries\//.test(url)) return 'summary';
  if (/unit-[^/]*-vocab[^/]*\.html/.test(url)) return 'vocab';
  if (/unit-[^/]*-self-check[^/]*\.html/.test(url)) return 'self-check';
  if (/unit-[^/]*-exam-reference[^/]*\.html/.test(url)) return 'exam-reference';
  return 'lesson';
}

// BJC in-page section conventions — see lab HTML like .learn / .forYouToDo etc.
// Multiple classes map to the same logical section label so the filter doesn't
// fragment (e.g. .vocab + .vocabBig + .vocabFullWidth all → "Vocabulary").
const SECTION_CLASS_MAP = {
  learn: 'Learn',
  forYouToDo: 'For You To Do',
  ifTime: 'If There Is Time',
  takeItFurther: 'Take It Further',
  vocab: 'Vocabulary',
  vocabBig: 'Vocabulary',
  vocabFullWidth: 'Vocabulary',
  endnote: 'Endnote',
  takeNote: 'Take Note',
  sidenoteBig: 'Take Note',
  atworkFullWidth: 'At Work',
  examFullWidth: 'Exam Reference',
  newProject: 'New Project',
};

function parseArgs() {
  const args = process.argv.slice(2);
  const out = { courses: DEFAULT_COURSES };
  for (const a of args) {
    if (a.startsWith('--courses=')) {
      out.courses = a.slice('--courses='.length).split(',').filter(Boolean);
    }
  }
  return out;
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

// Convert a /bjc-r/... URL (from a .topic resource line) into an on-disk path.
// Returns null if the URL isn't a local HTML page we can index.
function urlToFsPath(url) {
  if (!url) return null;
  const clean = url.split('?')[0].split('#')[0];
  if (!clean.startsWith('/bjc-r/')) return null;
  if (!clean.endsWith('.html')) return null;
  return path.join(REPO_ROOT, clean.slice('/bjc-r/'.length));
}

// Parse a course HTML file → list of topic file paths referenced from it.
// Mirrors BJCCourse#list_topics (utilities/build-tools/course.rb): only
// `.topic_link a` hrefs that contain `?topic=`.
function listTopicsForCourse(courseHtmlPath) {
  const html = fs.readFileSync(courseHtmlPath, 'utf8');
  const $ = load(html);
  const titleText = ($('title').first().text() || path.basename(courseHtmlPath, '.html')).trim();
  const seen = new Set();
  const topics = [];
  $('.topic_link a').each((_, el) => {
    const href = $(el).attr('href') || '';
    if (!href.includes('?topic=')) return;
    const topicFile = href.split('?topic=')[1].split('&')[0].split('#')[0];
    if (seen.has(topicFile)) return;
    seen.add(topicFile);
    topics.push({
      topicFile,
      label: ($(el).attr('title') || $(el).text() || '').trim(),
    });
  });
  return { titleText, topics };
}

// Inspect a lab page's HTML once with cheerio to extract:
//  - the set of section labels (filter values for `section`)
//  - an augmented HTML body where each <img> is followed by a visible
//    <span> containing its alt text — so Pagefind picks it up as content.
function processLabHtml(html) {
  const $ = load(html);
  const sections = new Set();

  for (const [klass, label] of Object.entries(SECTION_CLASS_MAP)) {
    if ($(`.${klass}`).length > 0) sections.add(label);
  }

  $('img[alt]').each((_, el) => {
    const alt = ($(el).attr('alt') || '').trim();
    if (!alt) return;
    // Skip purely decorative / repeated noise.
    if (alt.length < 2) return;
    // Inject visible text after the image so Pagefind indexes it. The HTML
    // is only used in-memory by the indexer; the file on disk is untouched.
    $(el).after(` <span class="pf-alt-text">${escapeHtml(alt)}</span>`);
  });

  return { sections: [...sections], html: $.html() };
}

// Inject Pagefind filter/meta markers as hidden elements at the start of <body>.
// Pagefind reads attribute values regardless of element visibility, so
// `display:none` markers still populate the filter index.
function injectPagefindMeta(html, { filters, meta }) {
  const tags = [];
  for (const [k, v] of Object.entries(filters || {})) {
    const values = Array.isArray(v) ? v : [v];
    for (const val of values) {
      if (val == null || val === '') continue;
      tags.push(
        `<span data-pagefind-filter="${k}[data-value]" data-value="${escapeHtml(val)}" style="display:none"></span>`,
      );
    }
  }
  for (const [k, v] of Object.entries(meta || {})) {
    if (v == null || v === '') continue;
    tags.push(
      `<span data-pagefind-meta="${k}[data-value]" data-value="${escapeHtml(v)}" style="display:none"></span>`,
    );
  }
  const block = tags.join('') + '\n';
  if (/<body[^>]*>/i.test(html)) {
    return html.replace(/<body([^>]*)>/i, `<body$1>${block}`);
  }
  return `<body>${block}</body>${html}`;
}

async function main() {
  const { courses } = parseArgs();
  console.log(`Pagefind index builder. Courses: ${courses.join(', ')}`);

  const llab = loadLlab();

  // Don't force a language — Pagefind reads <html lang="..."> per page and
  // keeps a separate sub-index per language. en + es live side by side.
  const { index, errors: createErrors } = await createIndex({ rootSelector: 'body' });
  if (createErrors?.length) throw new Error(`createIndex errors: ${createErrors.join('; ')}`);

  const seenUrls = new Set();
  let totalIndexed = 0;
  let totalSkipped = 0;

  for (const courseFile of courses) {
    const courseFsPath = path.join(REPO_ROOT, 'course', courseFile);
    if (!fs.existsSync(courseFsPath)) {
      console.warn(`! course file not found: ${courseFsPath}`);
      continue;
    }
    const { titleText, topics } = listTopicsForCourse(courseFsPath);
    const courseName = COURSE_DISPLAY_NAMES[courseFile] || titleText;
    console.log(`\nCourse: ${courseName}  [${courseFile}]  (${topics.length} units)`);

    for (const { topicFile, label } of topics) {
      const topicFsPath = path.join(REPO_ROOT, 'topic', topicFile);
      if (!fs.existsSync(topicFsPath)) {
        console.warn(`  ! topic file missing: ${topicFile}`);
        continue;
      }
      const data = fs.readFileSync(topicFsPath, 'utf8');
      const parsed = llab.parseTopicFile(data);
      const rawTitle = parsed.title || label || topicFile;
      const unitTitle = String(rawTitle).replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();
      const labs = topicToLabs(parsed, unitTitle);
      console.log(`  Unit: ${unitTitle}  (${labs.length} labs)`);

      for (const lab of labs) {
        const labLabel = lab.heading || unitTitle;
        for (const pageUrl of lab.pageUrls) {
          const fsPath = urlToFsPath(pageUrl);
          if (!fsPath) { totalSkipped++; continue; }
          if (!fs.existsSync(fsPath)) {
            console.warn(`    ! page missing on disk: ${pageUrl}`);
            totalSkipped++;
            continue;
          }
          const rel = path.relative(REPO_ROOT, fsPath).split(path.sep).join('/');
          const augmentedUrl =
            `/bjc-r/${rel}?topic=${encodeURIComponent(topicFile)}` +
            `&course=${encodeURIComponent(courseFile)}`;
          if (seenUrls.has(augmentedUrl)) { totalSkipped++; continue; }
          seenUrls.add(augmentedUrl);

          const rawHtml = fs.readFileSync(fsPath, 'utf8');
          const pageTitle = (rawHtml.match(/<title>([^<]*)<\/title>/i)?.[1] || '').trim();
          const { sections, html: htmlWithAlts } = processLabHtml(rawHtml);
          const kind = pageKindFromUrl('/bjc-r/' + rel);

          const augmented = injectPagefindMeta(htmlWithAlts, {
            filters: {
              course: courseName,
              unit: unitTitle,
              lab: labLabel,
              kind,
              section: sections,
            },
            meta: pageTitle ? { title: pageTitle } : {},
          });

          const { errors: fileErrors } = await index.addHTMLFile({
            url: augmentedUrl,
            content: augmented,
          });
          if (fileErrors?.length) {
            console.warn(`    ! addHTMLFile errors for ${augmentedUrl}: ${fileErrors.join('; ')}`);
          } else {
            totalIndexed++;
          }
        }
      }
    }
  }

  const outputPath = path.join(REPO_ROOT, 'search', 'pagefind');
  const { errors: writeErrors } = await index.writeFiles({ outputPath });
  if (writeErrors?.length) throw new Error(`writeFiles errors: ${writeErrors.join('; ')}`);

  console.log(`\nIndexed ${totalIndexed} pages, skipped ${totalSkipped} (duplicates / non-local / missing).`);
  console.log(`Pagefind output written to ${outputPath}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
