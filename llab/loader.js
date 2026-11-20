/* LLAB Loader
 * Lightweight Labs system.
 * This file is the entry point for all llab pages.
 */

const THIS_FILE = 'loader.js';
const RELEASE_DATE = '2026-08-01a';

// Basic llab shape.
llab = {
    paths: {
        scripts: [],
        css_files: []
    },
    rootURL: '',
    install_directory: '',
    optionalLibs: {},
};

llab.isLocalEnvironment = () => ['localhost', '127.0.0.1'].includes(window.location.hostname) ||
    window.location.hostname.endsWith('.runloop.ai'); // Superconductor dev boxes

/*
 ***********************
 ******** CONFIG *******
 ***********************
 See ../llab.js for more explanations.
 */
llab.rootURL = "/bjc-r/";
llab.install_directory = "llab/";
llab.llab_path = llab.rootURL + llab.install_directory;
llab.courses_path = llab.rootURL + "course/";
llab.topics_path = llab.rootURL + "topic/";
llab.topic_launch_page = llab.llab_path + "html/topic.html";
llab.alt_topic_page = llab.rootURL + "topic/topic.html";
llab.empty_curriculum_page_path = llab.llab_path + "html/empty-curriculum-page.html";

// google analytics token
llab.GACode = 'G-WK0EW5GQRZ';

// Error Handling -- The URL embeds the Sentry desination
llab.SENTRY_URL = 'https://js.sentry-cdn.com/f55a4cd65a8b48fd99e8247c6a5e6c2d.min.js';

// Teacher Guide "Feedback" button. Responses are POSTed straight to a Google
// Form, so they land in the form's Responses tab (and optionally a Sheet).
// See llab.addFeedback in script/curriculum.js. The button is hidden until
// `action` and the `fields` entry IDs are filled in.
//
// Setting up the form:
//  * Add one question per key in `fields` below. Make every question
//    "Short answer" or "Paragraph" and NOT required: Google silently drops a
//    submission that skips a required question or sends a multiple-choice
//    value that doesn't match an option exactly.
//  * Settings > Responses: turn off "Collect email addresses" and
//    "Restrict to users in <org>"; either one forces a sign-in and every
//    anonymous POST is discarded.
//  * `action`: the form's share link, docs.google.com/forms/d/e/<ID>/viewform,
//    with `viewform` replaced by `formResponse`.
//  * Entry IDs: ⋮ > "Get pre-filled link", type anything in each box,
//    "Get link"; the link contains `entry.<number>=` once per question.
llab.FEEDBACK_FORM = {
    // "BJC Teacher Guide Feedback"
    action: 'https://docs.google.com/forms/d/e/1FAIpQLSfofF83Jqt-F0HLnbs44i4Zap-Zw2mjG8vQx7D1d5i7SaW5zw/formResponse',
    fields: {
        // The questions, matching the GetFeedback survey this replaces.
        about: 'entry.1570082201',        // What are you providing feedback about?
        studentPages: 'entry.1859815119', // Which student lab page(s) are you providing feedback about?
        comment: 'entry.2018947148',      // What can we do to make this content better?
        email: 'entry.564431291',         // Email (optional)
        // Filled in automatically, as GetFeedback's merge fields were.
        page: 'entry.71824495',           // Page title: document.title
        url: 'entry.377017937',           // Page URL: location.href, with ?topic= and ?course=
        topic: 'entry.85697841',          // Topic file: the ?topic= file
        course: 'entry.1677853741',       // Course file: the ?course= file
    },
};

// Third-party origins we contact during page load. Pre-warming the
// connection (DNS + TLS) shaves time off the first request to each.
llab.PRECONNECT_ORIGINS = [
    'https://www.googletagmanager.com',
    'https://js.sentry-cdn.com',
];

// CSS, relative to llab/
llab.paths.css_files = [
    'lib/bootstrap-5.3.8-dist/css/bootstrap.min.css',
    'css/default.css',
    '../css/bjc.css',
];

/////////////////////////
///////////////////////// scripts
// Scripts are injected with async=false, so they download in parallel but
// are guaranteed to execute in insertion order.
// This list MUST remain in dependency order.
llab.paths.scripts = [
    "lib/jquery-3.7.0.slim.min.js",
    "script/library.js",             // must not depend on jQuery
    "script/quiz/multiplechoice.js",
    "script/curriculum.js",
    "script/course.js",
    "script/topic.js",
    "lib/bootstrap-5.3.8-dist/js/bootstrap.bundle.min.js",
    "script/quiz.js",                // all quiz item types load after multiplechoice.js
];

///////// OPTIONAL LIBRARIES:
llab.optionalLibs = {
    katex: {
        css: 'css/katex.min.css',
        js: 'lib/katex.min.js'
    },
    highlights: {
        css: 'css/tomorrow-night-blue.css',
        js: '//cdnjs.cloudflare.com/ajax/libs/highlight.js/8.4/highlight.min.js'
    },
    gifffer: {
        css: null,
        js: 'lib/gifffer.min.js'
    }
};

//////////////

// Fallback for the (rare) case loader.js is injected dynamically,
// where document.currentScript is null.
llab.getPathToThisScript = function() {
    var scripts = document.scripts, i, src;
    for (i = 0; i < scripts.length; i += 1) {
        src = scripts[i].src;
        if (src.endsWith('/' + THIS_FILE)) {
            return src;
        }
    }
    return '';
};

// loader.js executes synchronously, so currentScript is this script tag.
llab.thisPath = (document.currentScript && document.currentScript.src) ||
    llab.getPathToThisScript();

function getTag(name, src, type, opts) {
    let tag = document.createElement(name),
        link = name === 'link' ? 'href' : 'src';

    if (src.indexOf("//") === -1) {
        src = llab.thisPath.replace(THIS_FILE, src);
    }

    if (src.indexOf("?") === -1) {
        src += `?${RELEASE_DATE}`;
    }
    tag[link] = src;
    if (type) { tag.type = type; }
    if (opts) {
        for (let opt in opts) {
            tag[opt] = opts[opt];
        }
    }
    return tag;
}

// TODO: these need to just be insert script / insert stylesheet
// those functions can then check if something is already loaded.
// Array.from(document.scripts).map(node => node.src.replace(location.origin, '').replace(/?.*$/, ''))
// Array.from(document.styleSheets).map(node => node.src.replace(location.origin, '').replace(/\?.*$/, ''))
// TODO - will need to normalize paths.
// async=false keeps execution order (jQuery before bootstrap, etc.) while
// still letting the browser fetch every script in parallel.
llab.scriptTag = (src, onload) => getTag('script', src, 'text/javascript', { 'onload': onload, 'async': false });
llab.styleTag = (href) => getTag('link', href, 'text/css', { 'rel': 'stylesheet' });

// Resource hints. Inserted up front so the preload scanner can kick off
// downloads while stage 0 is still booting.
llab.preloadTag = (href, as) => getTag('link', href, null, { 'rel': 'preload', 'as': as });
// No crossorigin: the actual GA/Sentry script loads aren't CORS, so a
// crossorigin preconnect wouldn't be reused for them.
llab.preconnectTag = (href) => {
    let tag = document.createElement('link');
    tag.rel = 'preconnect';
    tag.href = href;
    return tag;
};

// Emit one <link rel=preload> per script so they all start downloading
// immediately, ahead of the actual <script> injections.
llab.emitResourceHints = function() {
    llab.PRECONNECT_ORIGINS.forEach(origin => {
        document.head.appendChild(llab.preconnectTag(origin));
    });

    llab.paths.css_files.forEach(file => {
        document.head.appendChild(llab.preloadTag(file, 'style'));
    });

    llab.paths.scripts.forEach(src => {
        document.head.appendChild(llab.preloadTag(src, 'script'));
    });
};


llab.initialSetUp = function() {
    llab.emitResourceHints();

    llab.paths.css_files.forEach(file => document.head.appendChild(llab.styleTag(file)));

    let lastIndex = llab.paths.scripts.length - 1;
    llab.paths.scripts.forEach((src, i) => {
        // After the final script executes, all of llab is defined and
        // content-based optional libraries can be evaluated.
        let onload = i === lastIndex ? llab.loadOptionalLibraries : null;
        let tag = llab.scriptTag(src, onload);
        if (onload) {
            // Even if the last script fails to load, still try the optional libs.
            tag.onerror = onload;
        }
        document.head.appendChild(tag);
    });

    if (!llab.isLocalEnvironment() && llab.SENTRY_URL) {
        document.head.appendChild(llab.scriptTag(llab.SENTRY_URL, llab.setupSentry));
    }
};

// Optional libraries are selected by scanning the page's content,
// so wait until the DOM is fully parsed before checking.
llab.loadOptionalLibraries = function() {
    let run = () => {
        if (typeof llab.conditionalSetup === 'function') {
            llab.conditionalSetup(llab.CONDITIONAL_LOADS);
        }
    };
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', run);
    } else {
        run();
    }
};

//// CONDITIONALLY LOAD LIBRARIES
// All of these are loaded *after* stage 0 is ready.
// These functions must either be global, or defined in library.js
llab.CONDITIONAL_LOADS = [
    {
      selectors: 'pre > code',
      libName: 'highlights', // must be defined in llab.optionalLibs (above)
      onload: () => { llab.highlightSyntax(); } // these must be wrapped in a function.
    },
    {
      selectors: '.katex, .katex-inline, .katex-block',
      libName: 'katex',
      onload: () => { llab.displayMathDivs(); }
    },
    {
      selectors: '[data-gifffer]',
      libName: 'gifffer',
      onload: () => { Gifffer(); }
    }
];

/////////////////////

llab.setupSentry = function () {
  Sentry.onLoad(function() {
    Sentry.init({
      // No need to configure DSN here, it is already configured in the loader script
      // You can add any additional configuration here
      sampleRate: 0.5,
      integrations: [new Sentry.Integrations.BrowserTracing()]
    });
  });
}

llab.initialSetUp();
