// Polyfills for older browsers
if (!String.prototype.endsWith) {
  Object.defineProperty(String.prototype, 'endsWith', {
    value: function(searchString, position) {
      var subjectString = this.toString();
      if (position === undefined || position > subjectString.length) {
        position = subjectString.length;
      }
      position -= searchString.length;
      var lastIndex = subjectString.indexOf(searchString, position);
      return lastIndex !== -1 && lastIndex === position;
    }
  });
}



/////////// FIXME -- put this in a better place.



/* LLAB Loader
 * Lightweight Labs system.
 * This file is the entry point for all llab pages.
 */


var THIS_FILE = 'loader.js';

llab = {};
llab.loaded = {};  // keys are true if that script file is loaded
llab.paths  = {};
llab.paths.stage_complete_functions = [];
llab.paths.scripts = [];  // holds the scripts to load, in stages below
llab.paths.css_files = [];
llab.rootURL = "";  // to be overridden in config.js
llab.install_directory = "";  // to be overridden in config.js


// This file must always be at the same level as the llab install directory
llab.CONFIG_FILE_PATH = "../llab.js";

// This file must always be at the same level as the llab install directory
llab.BUILD_FILE_PATH = "./llab-complied.js";


// ADDITIONAL LIBRARIES

// Syntax Highlighting support
llab.paths.syntax_highlights = "//cdnjs.cloudflare.com/ajax/libs/highlight.js/8.4/highlight.min.js";
llab.paths.syntax_highlighting_css = "css/tomorrow-night-blue.css";
// Math / LaTeX rendering
llab.paths.math_katex_js = "lib/katex.min.js";
llab.paths.katex_css = "css/katex.min.css";

// CSS
llab.paths.css_files.push('css/3.3.7/bootstrap-compiled.min.css');


/////////////////////////
///////////////////////// stage 0
// Stage 0 items can be executed with no dependences.
llab.paths.scripts[0] = [];
llab.paths.scripts[0].push(llab.CONFIG_FILE_PATH);
llab.paths.scripts[0].push("lib/jquery.min.js");
llab.paths.scripts[0].push("script/library.js");
llab.paths.scripts[0].push("script/quiz/multiplechoice.js");

llab.loaded['config'] = false;
llab.loaded['library'] = false;
llab.loaded['multiplechoice'] = false
llab.paths.stage_complete_functions[0] = function() {
    return ( typeof jQuery === 'function' &&
        llab.loaded['config'] && llab.loaded['library'] );
}


/////////////////
///////////////// stage 1
llab.paths.scripts[1] = [];
llab.paths.scripts[1].push("lib/bootstrap.min.js");
llab.paths.scripts[1].push("script/curriculum.js");
llab.paths.scripts[1].push("script/course.js");
llab.paths.scripts[1].push("script/topic.js");
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


//////////////

llab.getPathToThisScript = function() {
    var scripts = document.scripts;
    for (var i = 0; i < scripts.length; i += 1) {
        var src = scripts[i].src;
        if (src.endsWith('/' + THIS_FILE)) {
            return src;
        }
    }
    return '';
};

llab.thisPath = llab.getPathToThisScript();


function getTag(name, src, type) {
    var tag = document.createElement(name);

    if (src.substring(0, 2) !== "//") {
        src = llab.thisPath.replace(THIS_FILE, src);
    }

    var link  = name === 'link' ? 'href' : 'src';
    tag[link] = src;
    tag.type  = type;

    return tag;
}



llab.initialSetUp = function() {
    var headElement = document.head;
    var tag, i, src;

    // start the process
    loadScriptsAndLinks(0);

    function loadScriptsAndLinks(stage_num) {
        var i, tag;

        // load css files
        while (llab.paths.css_files.length != 0) {
            tag = getTag("link", llab.paths.css_files.shift(), "text/css");
            tag.rel = "stylesheet";
            headElement.appendChild(tag);
        }

        // load scripts
        llab.paths.scripts[stage_num].forEach(function(scriptfile) {
            tag = getTag("script", scriptfile, "text/javascript");
            headElement.appendChild(tag);
        });

        if ((stage_num + 1) < llab.paths.scripts.length) {
            proceedWhenComplete(stage_num);
        }
    }

    function proceedWhenComplete(stage_num) {
        if (llab.paths.stage_complete_functions[stage_num]()) {
            if ((stage_num + 1) < llab.paths.scripts.length) {
                loadScriptsAndLinks(stage_num + 1);
            }
        } else {
            setTimeout(function() {
                proceedWhenComplete(stage_num);
            }, 10);
        }
    }
};

/////////////////////

llab.initialSetUp();

