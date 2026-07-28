#!/usr/bin/env node
// Pagefind index builder for the BJC curriculum.
//
// Walks the chosen course HTML files, follows them into their .topic files,
// reads each linked lab page, and feeds the HTML to Pagefind with a `course`
// filter attached. No source HTML is modified — filter markers are injected
// into an in-memory copy that's handed to Pagefind.
//
// Two separate indexes are written:
//   search/pagefind/          — student courses (BJC CS Principles, BJC Sparks)
//   search/pagefind-teacher/  — the teacher guide for each course
// The search page merges the teacher bundle in only when an explicit query
// parameter is present, so teacher-guide results stay out of student searches.
//
// Result titles come from the first <h2> on each page (the BJC page-title
// convention) with the <title> tag as a fallback; every extracted title is
// captured in title-report.json and pages missing an <h2> are logged.
//
// Topic-file parsing is delegated to the canonical browser-side parser at
// llab/script/topic.js, loaded into Node via vm in llab-loader.js.
//
// Usage:  node build-index.js  [--courses=...] [--teacher-courses=...]

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
const DEFAULT_TEACHER_COURSES = ['bjc4nyc_teacher.html', 'sparks-teacher.html'];

// Display names override the course HTML <title>. Add an entry for every
// course you index — defaults fall back to the <title> text. These values
// are what users see in the search page's course filter, and they must stay
// in sync with COURSE_FILENAME_TO_DISPLAY in search/index.html.
const COURSE_DISPLAY_NAMES = {
  'bjc4nyc.html': 'BJC CS Principles',
  'bjc4nyc.es.html': 'BJC CS Principles',
  'sparks.html': 'BJC Sparks',
  'sparks.es.html': 'BJC Sparks',
  'bjc4nyc_teacher.html': 'BJC CS Principles Teacher Guide',
  'sparks-teacher.html': 'BJC Sparks Teacher Guide',
};

function parseArgs() {
  const args = process.argv.slice(2);
  const out = { courses: DEFAULT_COURSES, teacherCourses: DEFAULT_TEACHER_COURSES };
  for (const a of args) {
    if (a.startsWith('--courses=')) {
      out.courses = a.slice('--courses='.length).split(',').filter(Boolean);
    }
    if (a.startsWith('--teacher-courses=')) {
      out.teacherCourses = a.slice('--teacher-courses='.length).split(',').filter(Boolean);
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

// Clean a <title> tag for display alongside the h2 title: drop the
// descriptive lab name between the colon and the page/activity marker.
// "Unit 1 Lab 4: Protecting Your Privacy, Page 4"        → "Unit 1 Lab 4, Page 4"
// "Unidad 4 Laboratorio 2: Ciberseguridad, página 6"     → "Unidad 4 Laboratorio 2, página 6"
// "Unit 2 Lab 3: Make Some Noise, Activity 1"            → "Unit 2 Lab 3, Activity 1"
// Titles without that shape (e.g. "Unit 1 Vocabulary") pass through as-is.
function cleanTitleTag(titleTag) {
  const t = String(titleTag || '').replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();
  const m = t.match(/^(.+?):\s+.*,\s*((?:page|p[áa]gina|activity|actividad)\s*\d+)\s*$/i);
  return m ? `${m[1]}, ${m[2]}` : t;
}

// Loose comparison so "Unit 1: Vocabulary" and "Unit 1 Vocabulary" count as
// the same title and we don't render "Unit 1: Vocabulary (Unit 1 Vocabulary)".
function sameTitle(a, b) {
  const norm = (s) => String(s).toLowerCase().replace(/[^\p{L}\p{N}]+/gu, '');
  return norm(a) === norm(b);
}

// Inspect a lab page's HTML once with cheerio to extract:
//  - the page title, taken from the first <h2> (the BJC convention — the
//    <title> tag is usually a generic "Unit X Lab Y, Page Z" string while
//    the first <h2> holds the human-facing page title)
//  - an augmented HTML body where each <img> is followed by a visible
//    <span> containing its alt text — so Pagefind picks it up as content.
function processLabHtml(html) {
  const $ = load(html);

  const h2Title = $('h2').first().text().replace(/\s+/g, ' ').trim();
  const titleTag = ($('title').first().text() || '').replace(/\s+/g, ' ').trim();

  $('img[alt]').each((_, el) => {
    const alt = ($(el).attr('alt') || '').trim();
    if (!alt) return;
    // Skip purely decorative / repeated noise.
    if (alt.length < 2) return;
    // Inject visible text after the image so Pagefind indexes it. The HTML
    // is only used in-memory by the indexer; the file on disk is untouched.
    $(el).after(` <span class="pf-alt-text">${escapeHtml(alt)}</span>`);
  });

  return { h2Title, titleTag, html: $.html() };
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

// Index every page of every course in `courses` into a fresh Pagefind index
// and write it to `outputPath`. Returns per-run stats; appends one entry per
// indexed page to `titleReport`.
async function buildIndexFor({ courses, outputPath, llab, titleReport }) {
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
          const { h2Title, titleTag, html: htmlWithAlts } = processLabHtml(rawHtml);

          // BJC convention: the human-facing page title is the first <h2>;
          // the <title> tag carries the position within the course. Combine
          // them as "{h2} ({cleaned title})", e.g.
          // "Protecting Your Privacy (Unit 1 Lab 4, Page 4)".
          const cleanedTag = cleanTitleTag(titleTag);
          let pageTitle = h2Title || cleanedTag;
          if (h2Title && cleanedTag && !sameTitle(h2Title, cleanedTag)) {
            pageTitle = `${h2Title} (${cleanedTag})`;
          }
          if (!h2Title) {
            console.warn(`    ! no <h2> title on ${pageUrl}${titleTag ? ` — falling back to <title> "${titleTag}"` : ' — no <title> either'}`);
          }
          titleReport.push({
            url: `/bjc-r/${rel}`,
            course: courseName,
            title: pageTitle || null,
            titleSource: h2Title ? 'h2' : (titleTag ? 'title-tag' : 'none'),
            titleTag: titleTag || null,
          });

          const augmented = injectPagefindMeta(htmlWithAlts, {
            filters: { course: courseName },
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

  // Pagefind names every fragment/index file by content hash and writeFiles
  // never deletes, so clear the bundle dir first to avoid stale orphans.
  fs.rmSync(outputPath, { recursive: true, force: true });
  const { errors: writeErrors } = await index.writeFiles({ outputPath });
  if (writeErrors?.length) throw new Error(`writeFiles errors: ${writeErrors.join('; ')}`);

  return { totalIndexed, totalSkipped };
}

async function main() {
  const { courses, teacherCourses } = parseArgs();
  console.log(`Pagefind index builder.`);
  console.log(`  Student courses: ${courses.join(', ')}`);
  console.log(`  Teacher courses: ${teacherCourses.join(', ')}`);

  const llab = loadLlab();
  const titleReport = [];

  console.log('\n=== Student index ===');
  const student = await buildIndexFor({
    courses,
    outputPath: path.join(REPO_ROOT, 'search', 'pagefind'),
    llab,
    titleReport,
  });

  console.log('\n=== Teacher-guide index ===');
  const teacher = await buildIndexFor({
    courses: teacherCourses,
    outputPath: path.join(REPO_ROOT, 'search', 'pagefind-teacher'),
    llab,
    titleReport,
  });

  // Capture the extracted titles so title sourcing can be audited without
  // re-running the build. Not committed — see .gitignore.
  const reportPath = path.join(__dirname, 'title-report.json');
  fs.writeFileSync(reportPath, JSON.stringify(titleReport, null, 2) + '\n');

  const noH2 = titleReport.filter((r) => r.titleSource !== 'h2');
  console.log(`\nIndexed ${student.totalIndexed} student + ${teacher.totalIndexed} teacher pages ` +
    `(skipped ${student.totalSkipped + teacher.totalSkipped} duplicates / non-local / missing).`);
  console.log(`Titles: ${titleReport.length - noH2.length}/${titleReport.length} pages use their first <h2>; ` +
    `${noH2.length} fell back to the <title> tag (see ${path.relative(REPO_ROOT, reportPath)}).`);
  console.log(`Pagefind output written to ${path.join(REPO_ROOT, 'search', 'pagefind')} and ${path.join(REPO_ROOT, 'search', 'pagefind-teacher')}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
