/*
 * Common functions for any llab page
 *
 * CANNOT RELY ON JQUERY OR ANY OTHER LLAB LIBRARY
 */


// retrieve llab or create an empty version.
llab = llab || {};
llab.loaded = llab.loaded || {};
llab.DEVELOPER_CLASSES = '.todo, .comment, .commentBig, .ap-standard, .csta-standard'

llab.PRODUCTION_SERVERS = [ 'bjc.berkeley.edu', 'bjc.edc.org', 'cs10.org' ]

////// TRANSLATIONS -- Shared Across All Files.
llab.TRANSLATIONS = {
    'ifTime': {
      en: 'If There Is Time…',
      es: 'Si hay tiempo…',
    },
    'takeItFurther': {
      en: 'Take It Further…',
      es: 'Llevándolo más allá',
    },
    'takeItTeased': {
      en: 'Take It Further…',
      es: 'Llevándolo más allá',
    },
    'backText': {
      en: 'previous page',
      es: 'Anterior',
    },
    'nextText': {
      en: 'next page',
      es: 'Siguiente',
    },
    'selfCheckTitle': {
      en: 'Self-Check Question',
      es: 'Autoevaluación',
    },
    'Try Again': {
      es: 'Intentarlo de nuevo',
    },
    'Check Answer': {
      es: 'Comprobar respuesta',
    },
    'successMessage': {
      en: 'You have successfully completed this question!',
      es: '¡Has completado la pregunta correctamente!',
    },
    'attemptMessage': {
      en: 'This is your %{ordinal} attempt.',
      es: 'Este es tu intento n.º %{number}.',
    },
    'Go to Table of Contents': {
      es: 'Ir a la tabla de contenido'
    }
};

/////////////////
llab.snapRunURLBase = "https://snap.berkeley.edu/snap/snap.html#open:";
llab.snapRunURLBaseVersion = "https://snap.berkeley.edu/versions/VERSION/snap.html#open:";

// It is expected that you host llab content in an environment where CORS is allowed.
llab.getSnapRunURL = function(targeturl, options) {
    if (!targeturl) { return ''; }

    if (targeturl.indexOf('http') == 0 || targeturl.indexOf('//') == 0) {
        // pointing to some non-local resource... do nothing!!
        return targeturl;
    }

    // internal resource!
    let snapURL = llab.snapRunURLBase;
    if (options && options.version) {
        snapURL = llab.snapRunURLBaseVersion.replace('VERSION', options.version);
    }
    if (location.protocol == 'http:') {
        snapURL = snapURL.replace('https://snap', 'http://extensions.snap');
    }

    let origin = location.origin;
    // Resolve relative URLs to the full path.
    // TODO: Consider adapting: new URL("../g", "http://a/b/c/d;p?q").href
    if (targeturl.indexOf("..") != -1 || targeturl.indexOf(llab.rootURL) == -1) {
        let path = location.pathname;
        path = path.split("?")[0];
        path = path.substring(0, path.lastIndexOf("/") + 1);
        origin += path;
    }

    return `${snapURL}${origin}${targeturl}?${new Date().toISOString()}`;
};

llab.pageLang = () => {
    if (llab.CURRENT_PAGE_LANG) {
        return llab.CURRENT_PAGE_LANG;
    }

    let urlLang = llab.determinLangFromURL();
    let htmlLang = $("html").attr('lang');

    if (urlLang) {
        llab.CURRENT_PAGE_LANG = urlLang;
    }

    llab.CURRENT_PAGE_LANG = urlLang || htmlLang || 'en';

    if (!htmlLang) {
        $("html").attr('lang', llab.CURRENT_PAGE_LANG);
    }

    return llab.CURRENT_PAGE_LANG;
}

// Use the filename of the HTML file or course file, or topic file to determine page language.
llab.determinLangFromURL = () => {
    let urlLang = location.href.match(/\.(\w\w)\.(html|topic)/);
    if (urlLang) {
        return urlLang[1];
    }
    return null;
}

// very loosely mirror the Rails API
llab.translate = (key, replacements) => {
    if (!llab.TRANSLATIONS || !llab.TRANSLATIONS[key]) { return key; }
    if (!replacements) { replacements = {}; }

    let lang = llab.pageLang(),
        result = llab.TRANSLATIONS[key][lang];
    if (result !== '' && !result) {
      result = llab.TRANSLATIONS[key]['en'] || key;
    }

    Object.keys(replacements).forEach(rep => {
      result = result.replace(new RegExp(`%{${rep}}`,'g'), replacements[rep]);
    });
    return result;
};

llab.t = llab.translate;

// TODO: Figure out how to handle common pages that are translated
// e.g. topic.html and topic.es.html are both topic files...
llab.pageLangugeExtension = () => llab.pageLang() == 'en' ? '' : `.${llab.pageLang()}`;

// Turn img.es.png into img.png
llab.stripLangExtensions = (text) => text.replace(new RegExp(`\.${llab.pageLang()}\.`, 'g'), '.');

/////// CONDITIONAL LOADING OF CONTENT
/**
 * A prelimary API for defining loading additional content based on triggers.
 *  @{param} array TRIGGERS is an array of {selectors, libName, onload } objects.
 *  If the selectors are valid, we load *one* CSS and JS file from llab.optionalLibs
 *  An `onload` function can be supplied, which will be called when the JS file is loaded.
 */
// check that we only run this thing one.
llab.conditional_setup_run = false;
llab.conditionalSetup = triggers => {
    if (llab.conditional_setup_run) { return true; }
    triggers.forEach(obj => {
        let selectors = obj.selectors, libName = obj.libName, onload = obj.onload;
        if (document.querySelectorAll(selectors).length > 0) {
          let files = llab.optionalLibs[libName];
          if (!files && onload) {
            onload();
            return;
          }
          if (files.css) {
            document.head.appendChild(llab.styleTag(files.css));
          }
          if (files.js) {
            document.head.appendChild(llab.scriptTag(files.js, onload));
          }
        }
    });
    llab.conditional_setup_run = true;
}

// Call The Functions to HighlightJS to render
llab.highlightSyntax = function() {
  $('pre > code').each(function(i, block) {
    block.innerHTML = block.innerHTML.trim();
    if (typeof hljs !== 'undefined') {
      hljs.highlightBlock(block);
    }
  });
};

llab.displayMathDivs = function () {
  $('.katex, .katex-inline').each(function (_, elm) {
     katex.render(elm.textContent, elm, {throwOnError: false});
  });
  $('.katex-block').each(function (_, elm) {
    katex.render(elm.textContent, elm, {
      displayMode: true, throwOnError: false
    });
  });
};

llab.handleError = (error) => {
    console.warn("Something went wrong: ", error);
    if (typeof Sentry !== "undefined") {
    Sentry.captureException(error);
  }
};

// TODO: jQuery3 -- these need to be migrated.
llab.toggleDevComments = () => $(llab.DEVELOPER_CLASSES).toggle();

// Staging is a dev environment + gh-pages, etc.
llab.isStagingEnvironment = () => !llab.PRODUCTION_SERVERS.includes(location.host);

// TODO: Rename this to "setupDevTools" something...
llab.setUpDevComments = () => {
    // Remove and re-add (necessary for dynamic navigations)
    const rightSideButton = 'imageRight btn btn-sm'
    $('.js-openProdLink, .js-commentBtn').remove();

    // Specifically exclude public staging pages.
    if (llab.isLocalEnvironment()) {
        let addToggle = $(`<button class="${rightSideButton} btn-default js-commentBtn"
            >Toggle developer comments</button>`)
            .click(llab.toggleDevComments);
        $(FULL).prepend(addToggle);
        $(document).ready(llab.toggleDevComments);
    }

    if (llab.isStagingEnvironment()) {
        let open_link = $(`
            <a class="${rightSideButton} btn-primary js-openProdLink"
              target="_blank"
              href=${location.href.replace(location.host, 'bjc.edc.org')}
            >Open on edc.org</a>`)
            $(FULL).prepend(open_link);
    }
}

/** Returns the value of the URL parameter associated with NAME. */
llab.getQueryParameter = function(paramName) {
    var params = llab.getURLParameters();
    if (params.hasOwnProperty(paramName)) {
        return params[paramName];
    } else {
        return '';
    }
};

llab.isTopicFile = () => {
    return [
        llab.empty_topic_page_path, llab.topic_launch_page, llab.alt_topic_page
      ].includes(llab.stripLangExtensions(location.pathname));
};

// TODO: Write a use this function.
// This should return the "type" of a page used in the repo:
// course, topic, curriculum -- maybe others later (summaries? teacher guide?)
llab.curentPageType = () => {
    return false;
}

/** Strips comments off the line in a topic file. */
llab.stripComments = function(line) {
    var index = line.indexOf("//");
    // the second condition makes this ignore urls (http://...)
    if (index !== -1 && line[index - 1] !== ":") {
        line = line.slice(0, index);
    }
    return line;
};

/* Google Analytics Tracking
 * To make use of this code, the two ga() functions need to be called
 * on each page that is loaded, which means this file must be loaded.
 */
if (llab.GACode) {
    document.head.appendChild(getTag(
        'script',
        `https://www.googletagmanager.com/gtag/js?id=${llab.GACode}`,
        'text/javascript'
    ));
    window.dataLayer = window.dataLayer || [];
    function gtag(){ dataLayer.push(arguments); }
    gtag('js', new Date());
    gtag('config', llab.GACode, {
        // page_title: document && document.querySelector('title').textContent,
        page_location: document.URL
    });
}

/** Truncate a STR to an output of N chars.
 *  N does NOT include any HTML characters in the string.
 */
llab.truncate = function(str, n) {
    // Ensure string is 'proper' HTML by putting it in a div, then extracting.
    var clean = document.createElement('div');
        clean.innerHTML = str;
        clean = clean.textContent || clean.innerText || '';

    // TODO: Be smarter about stripping from HTML content
    // This, doesn't factor HTML into the removed length
    // Perhaps match postion of nth character to the original string?
    // &#8230; is a unicode ellipses
    if (clean.length > n) {
        return clean.slice(0, n - 1) + '&#8230;';
    }

    return str; // return the HTML content if possible.
};


// TODO: Replace this with new URLSearchParams(window.location.search)
/*!
    query-string
    Parse and stringify URL query strings
    https://github.com/sindresorhus/query-string
    by Sindre Sorhus
    MIT License
*/
// Modiefied for LLAB. Inlined to reduce requests
var queryString = {};

queryString.parse = function (str) {
    if (typeof str !== 'string') {
        return {};
    }

    str = str.trim().replace(/^(\?|#)/, '');

    if (!str) {
        return {};
    }

    return str.trim().split('&').reduce(function (ret, param) {
        var parts = param.replace(/\+/g, ' ').split('=');
        var key = parts[0];
        var val = parts[1];

        key = decodeURIComponent(key);
        // missing `=` should be `null`:
        // http://w3.org/TR/2012/WD-url-20120524/#collect-url-parameters
        val = val === undefined ? null : decodeURIComponent(val);

        if (!ret.hasOwnProperty(key)) {
            ret[key] = val;
        } else if (Array.isArray(ret[key])) {
            ret[key].push(val);
        } else {
            ret[key] = [ret[key], val];
        }

        return ret;
    }, {});
};

queryString.stringify = function (obj) {
    return obj ? Object.keys(obj).map(function (key) {
        var val = obj[key];

        if (Array.isArray(val)) {
            return val.map(function (val2) {
                if (!val2) { // Mod: Don't have =null values in URL params
                    return encodeURIComponent(key);
                }
                return encodeURIComponent(key) + '=' + encodeURIComponent(val2);
            }).join('&');
        }

        if (!val) { // Mod: Don't have =null values in URL params
            return encodeURIComponent(key);
        }

        return encodeURIComponent(key) + '=' + encodeURIComponent(val);
    }).join('&') : '';
};
/*! End Query String */
llab.QS = queryString;


// Return a new object with the combined properties of A and B.
// Desgined for merging query strings
// B will clobber A if the fields are the same.
llab.merge = function(objA, objB) {
    var result = {}, prop;
    for (prop in objA) {
        if (objA.hasOwnProperty(prop)) {
            result[prop] = objA[prop];
        }
    }
    for (prop in objB) {
        if (objB.hasOwnProperty(prop)) {
            result[prop] = objB[prop];
        }
    }
    return result;
};

llab.getURLParameters = function() {
    let stripHTML = (content) => $('<div/>').text(content).html();
    if (!llab.safeURLParams) {
        llab.safeURLParams = {};
        const searchParams = new URLSearchParams(location.search);
        for (const [param, value] of searchParams) {
            llab.safeURLParams[param] = stripHTML(value);
          }
    }
    return llab.safeURLParams;
};

llab.getAttributesForElement = function(elm) {
    var map = elm.attributes,
        ignore = ['class', 'id', 'style'],
        attrs = {},
        item,
        i = 0,
        len = map.length;

    for (; i < len; i += 1) {
        item = map.item(i);
        if (ignore.indexOf(item.name) === -1) {
            attrs[item.name] = item.value;
        }
    }
    return attrs;
};


// These are STRINGS that are query selectors for selecting page elements
// We want to store them in a single place because it's easier to update
llab.selectors = {};
// These are code fragments which are reusable components.
llab.fragments = {};
// These are common strings that need not be build and should be reused!
llab.strings = {};
llab.strings.goMain = 'Go to Table of Contents';
llab.fragments.bootstrapSep = '<li class="divider" role="presentation"></li>';
llab.fragments.bootstrapCaret = '<span class="caret"></span>';
// TODO: Translate this
llab.fragments.hamburger = '<span class="sr-only">Toggle navigation</span><span class="icon-bar"></span><span class="icon-bar"></span><span class="icon-bar"></span>';
// LLAB selectors for common page elements
llab.selectors.FULL = '.full';
llab.selectors.NAVSELECT = '.llab-nav';
llab.selectors.PROGRESS = '.progress-indicator';

//// cookie stuff
// someday my framework will come, but for now, stolen blithely from http://www.quirksmode.org/js/cookies.html
llab.createCookie = function(name,value,days) {
    if (days) {
        var date = new Date();
        date.setTime(date.getTime()+(days*24*60*60*1000));
        var expires = "; expires="+date.toGMTString();
    }
    else var expires = "";
    document.cookie = name+"="+value+expires+"; path=/";
}

llab.readCookie = function(name) {
    var nameEQ = name + "=";
    var ca = document.cookie.split(';');
    for(var i=0;i < ca.length;i++) {
        var c = ca[i];
        while (c.charAt(0)==' ') c = c.substring(1,c.length);
        if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
    }
    return null;
}

llab.eraseCookie = name => createCookie(name, "", -1);

llab.spanTag = (content, className) => `<span class="${className}">${content}</span>`;

/////////// Other Inlined Dependencies
if (typeof w3 === 'undefined') { w3 = {}; }
w3.includeHTML = function(cb) {
    var z, i, elmnt, file, xhttp;
    z = document.getElementsByTagName("*");
    for (i = 0; i < z.length; i++) {
        elmnt = z[i];
        file = elmnt.getAttribute("w3-include-html");
        if (file) {
        xhttp = new XMLHttpRequest();
        xhttp.onreadystatechange = function() {
            if (this.readyState == 4) {
            if (this.status == 200) {elmnt.innerHTML = this.responseText;}
            if (this.status == 404) {elmnt.innerHTML = "Page not found.";}
            elmnt.removeAttribute("w3-include-html");
            w3.includeHTML(cb);
            }
        }
        xhttp.open("GET", file, true);
        xhttp.send();
        return;
        }
    }
    if (cb) cb();
};

/////////////////////  END

llab.loaded['library'] = true;
