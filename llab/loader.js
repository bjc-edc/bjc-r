/* LLAB Loader
 * Lightweight Labs system.
 * This file is the entry point for all llab pages.
 */

const THIS_FILE = 'loader.js';
const RELEASE_DATE = '2026-08-01a';

// Basic llab shape.
llab = {
    loaded: {},
    paths: {
        scripts: [],
        css_files: []
    },
    rootURL: '',
    install_directory: '',
    CONFIG_FILE_PATH: '../llab.js', // currently unsed.
    optionalLibs: {},

};

llab.isLocalEnvironment = () => ['localhost', '127.0.0.1'].includes(window.location.hostname);

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

// google analytics tokens
llab.GACode = 'G-WK0EW5GQRZ';
llab.GAurl = location.origin;

// Error Handling -- The URL embeds the Sentry desination
llab.SENTRY_URL = 'https://js.sentry-cdn.com/f55a4cd65a8b48fd99e8247c6a5e6c2d.min.js';

// CSS
llab.paths.css_files = [
    'css/3.3.7/bootstrap.min.css',
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
    "lib/bootstrap.min.js",
    "script/quiz.js",                // all quiz item types load after multiplechoice.js
    // "script/lib/sha1.js",         // for brainstorm
    // "script/brainstorm.js",
    // "script/user.js",
];

llab.loaded['config'] = true;
llab.loaded['library'] = false;
llab.loaded['multiplechoice'] = false

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
        js: '../utilities/gifffer.min.js'
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
    tag.type = type;
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
// async=false makes dynamically-injected scripts download in parallel,
// but still execute in the order they were appended.
llab.scriptTag = (src, onload) => getTag('script', src, 'text/javascript', { 'onload': onload, 'async': false });
llab.styleTag = (href) => getTag('link', href, 'text/css', { 'rel': 'stylesheet' });


llab.initialSetUp = function() {
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
