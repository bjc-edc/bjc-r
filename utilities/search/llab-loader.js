// Load the canonical llab topic-file parser (llab/script/topic.js) into Node.
//
// topic.js is browser code and uses globals (`llab`, `$`, `document`). We
// evaluate it in a vm context with the smallest possible shim — enough that
// `llab.parseTopicFile(data)` returns its usual JSON structure.
//
// Returns { parseTopicFile, walkSections } — the latter is a small helper
// that turns the parsed tree into a flat list of labs with page URLs.

import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const LLAB_SCRIPT_DIR = path.resolve(__dirname, '..', '..', 'llab', 'script');

const RESOURCE_TYPES = new Set([
  'quiz', 'assignment', 'resource', 'forum', 'video', 'extresource', 'reading', 'group',
]);

export function loadLlab() {
  const noop = () => {};
  const $ = () => ({ append: noop, html: noop, find: noop });
  $.trim = (s) => String(s).trim();
  $.extend = Object.assign;

  const context = vm.createContext({
    llab: {},
    $,
    jQuery: $,
    console,
    document: {
      head: { appendChild: noop },
      getElementsByTagName: () => [],
      querySelector: () => null,
      title: '',
    },
    window: { dataLayer: [] },
    fetch: () => Promise.resolve({ text: () => Promise.resolve('') }),
  });

  // library.js defines llab.stripComments + a lot else; topic.js only needs
  // stripComments and the keyword helpers it defines itself. To stay
  // hermetic, inline stripComments rather than evaluating all of library.js.
  context.llab.stripComments = function (line) {
    const i = line.indexOf('//');
    if (i !== -1 && line[i - 1] !== ':') return line.slice(0, i);
    return line;
  };

  // Load topic.js, stripping its jQuery DOM-ready bootstrap at the bottom so
  // it doesn't try to inspect document on import.
  const topicSrc = fs
    .readFileSync(path.join(LLAB_SCRIPT_DIR, 'topic.js'), 'utf8')
    .replace(/\$\(llab\.displayTopic\);\s*$/m, '');
  vm.runInContext(topicSrc, context, { filename: 'llab/script/topic.js' });

  return context.llab;
}

// Plain-text a string (strips HTML used for styling in titles/headings).
function plainText(s) {
  return String(s || '').replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();
}

// Walk a parsed topic object → [{ heading, pageUrls }]. The llab parser
// already groups resources into sections by `heading:` / `h2:` line, so this
// is just a shallow flatten.
export function topicToLabs(parsed, unitTitle) {
  const labs = [];
  for (const topic of parsed.topics || []) {
    for (const section of topic.contents || []) {
      if (section.type !== 'section') continue;
      const pageUrls = (section.contents || [])
        .filter((item) => item.url && RESOURCE_TYPES.has(item.type))
        .map((item) => item.url);
      if (pageUrls.length === 0) continue;
      labs.push({
        heading: plainText(section.title) || unitTitle,
        pageUrls,
      });
    }
  }
  return labs;
}
