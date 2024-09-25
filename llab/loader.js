/* LLAB Loader
 * Lightweight Labs system.
 * This file is the entry point for all llab pages.
 */

const THIS_FILE = 'loader.js';
const RELEASE_DATE = '2024-09-25';

// Basic llab shape.
llab = {
    loaded: {},
    paths: {
        stage_complete_functions: [],
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
    // TODO: Merge this into bjc.css.
    '../css/edcdevtech-headerfooter.css',
];

/////////////////////////
///////////////////////// stage 0
// Stage 0 items can be executed with no dependences.
llab.paths.scripts[0] = [];
llab.paths.scripts[0].push("lib/jquery-3.7.0.slim.min.js");
llab.paths.scripts[0].push("script/library.js");
llab.paths.scripts[0].push("script/quiz/multiplechoice.js");

llab.loaded['config'] = true;
llab.loaded['library'] = false;
llab.loaded['multiplechoice'] = false
llab.paths.stage_complete_functions[0] = () => {
    return (typeof jQuery === 'function') && llab.loaded['library'];
}

/////////////////
///////////////// stage 1
llab.paths.scripts[1] = [];
llab.paths.scripts[1].push("script/curriculum.js");
llab.paths.scripts[1].push("script/course.js");
llab.paths.scripts[1].push("script/topic.js");
llab.paths.scripts[1].push("lib/bootstrap.min.js");
// llab.paths.scripts[1].push("script/lib/sha1.js");     // for brainstorm

// Doing a very weird thing delaying this until stage 1
// try to get the above files loaded faster, they only depend on jQuery.
llab.paths.stage_complete_functions[1] = function() {
    return ( llab.loaded['multiplechoice'] );
}

////////////////////
//////////////////// stage 2
// all these scripts depend on jquery, loaded in stage 1
// all quiz item types should get loaded here
llab.paths.scripts[2] = [];
llab.paths.scripts[2].push("script/quiz.js");
// llab.paths.scripts[2].push("script/brainstorm.js");
// llab.paths.scripts[2].push("script/user.js");

llab.paths.stage_complete_functions[2] = function() {
    return true; // && llab.loaded['user'];
}

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

llab.thisPath = llab.getPathToThisScript();

function getTag(name, src, type, opts) {
    let tag = document.createElement(name),
        link = name === 'link' ? 'href' : 'src';

    if (src.indexOf("//") === -1) {
        src = llab.thisPath.replace(THIS_FILE, src);
    }

    tag[link] = `${src}?${RELEASE_DATE}`;
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
llab.scriptTag = (src, onload) => getTag('script', src, 'text/javascript', { 'onload': onload });
llab.styleTag = (href) => getTag('link', href, 'text/css', { 'rel': 'stylesheet' });


llab.initialSetUp = function() {
    let loadScriptsAndLinks = (stage_num) => {
        llab.paths.scripts[stage_num].forEach(src => {
            document.head.appendChild(llab.scriptTag(src), () => proceedWhenComplete(stage_num));
        });

        // loading optional stuff after jQuery/Bootstrap dependencies, but early as possible.
        if (stage_num == 1) {
            llab.conditionalSetup(llab.CONDITIONAL_LOADS);
        }

        if ((stage_num + 1) < llab.paths.scripts.length) {
            proceedWhenComplete(stage_num);
        }
    }

    proceedWhenComplete = (stage_num) => {
        if (llab.paths.stage_complete_functions[stage_num]()) {
            if ((stage_num + 1) < llab.paths.scripts.length) {
                loadScriptsAndLinks(stage_num + 1);
            }
        } else {
            setTimeout(() => { proceedWhenComplete(stage_num) }, 2);
        }
    }

    llab.paths.css_files.forEach(file => document.head.appendChild(llab.styleTag(file)));
    loadScriptsAndLinks(0);

    if (!llab.isLocalEnvironment() && llab.SENTRY_URL) {
        document.head.appendChild(llab.scriptTag(llab.SENTRY_URL, llab.setupSentry));
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
