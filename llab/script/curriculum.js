/** curriculum.js
 *
 *  sets up a curriculum page -- either local or external.
 *
 *  Dependencies:
 *       jQuery
 *       library.js
 *       (Bootsrap) - optional, needed for looks, if missing code will still run
 */

llab.file = "";
llab.url_list = [];

var FULL = llab.selectors.FULL,
     hamburger = llab.fragments.hamburger;

llab.secondarySetUp = function() {
     // FIXME -- this needs to be called on EVERY page.
     llab.setupTitle();

     // Get the topic file and step from the URL
     llab.file = llab.getQueryParameter("topic");

     var params, course, cssFile, jsFile, css, js, codeElements;

     params = llab.getURLParameters(),
     course = params.course || '';

     // FIXME -- not sure this really belongs here as well.
     llab.addFeedback(document.title, llab.file, course);
     llab.addFooter(); // Added by Mary Fries on 10/16/17

     /* This stuff should only happen on curriculum pages */

     // fix snap links so they run snap
     $('a.run').each(function(i) {
          $(this).attr('target', '_blank');
          $(this).attr('href', llab.getSnapRunURL(this.getAttribute('href')));
     });

     // making ifTime and takeItFurther DIVs hide until clicked --MF, 2/9/18
     /*$('div.ifTime').each(function(i) {
          var divcontent = this.innerHTML;
		  this.innerHTML = "&nbsp;<a href='#hint-ifTime".concat(i, "' data-toggle='collapse' title='Try these optional activities...'>Try these optional activities...</a><div id='hint-ifTime", i, "' class='collapse'>", divcontent, "</div>");
     });
	 $('div.takeItFurther').each(function(i) {
          var divcontent = this.innerHTML;
		  this.innerHTML = "&nbsp;<a href='#hint-takeItFurther".concat(i, "' data-toggle='collapse' title='Try these optional activities...'>Try these optional activities...</a><div id='hint-takeItFurther", i, "' class='collapse'>", divcontent, "</div>");
     });*/

     llab.additionalSetup([
         {  // TODO: PUT THESE CLASSES SOMEWHERE
            trigger: 'pre code',
            function: llab.codeHighlightSetup()
         },
         {   // TODO: PUT THESE CLASSES SOMEWHERE
             trigger: '.katex, .katex-inline, .katex-block',
             function: llab.mathDisplaySetup()
         }
     ]);

     // We don't have a topic file, so we should exit.
     if (llab.file === '' || !llab.isCurriculum()) {
          return;
     }

     // TODO: Migrate to newer ajax call.
     var ajaxURL = llab.rootURL + "topic/" + llab.file;
     $.ajax({
          url: ajaxURL,
          type: "GET",
          contentType: 'text/plain; charset=UTF-8',
          dataType: "text",
          cache: true,
          success: llab.processLinks,
          error: function(jqXHR, status, error) {
               // TODO: We should push errors to Google Analytics
               console.log('Error Accessing Topic: ' + llab.file);
               console.log('Error: ' + error);
               console.log('Status: ' + status);
          }
     });

}; // close secondarysetup();


/** A prelimary API for defining loading additional content based on triggers.
 *  @{param} array TRIGGERS is an array of {trigger, callback} pairs.
 *  a `trigger` is currently a CSS selector that gets passed to $ to see if any
 *  of those elements are on the current page. If the elements are found then a
 *  `callback` is called with no arguments.
 *  TODO: Cleanup and test this code.
 *  TODO: Explore ideas for better trigger options?
 */
llab.additionalSetup = function(triggers) {
    var items;
    triggers.forEach(function (obj) {
        if (obj.trigger && obj.function) {
            items = $(trigger);
            if (items.length) {
                Function.call(null, obj.function);
            }
        }
    });
}

/** Import the required JS and CSS for Code highlighting.
 *  TODO: Abstract this away into its own function
 */
llab.codeHighlightSetup = function () {
    var cssFile, jsFile, css, js;
    cssFile = llab.paths.syntax_highlighting_css;
    jsFile  = llab.paths.syntax_highlights;
    css = getTag('link', cssFile, 'text/css');
    css.rel = "stylesheet";
    js = getTag('script', jsFile, 'text/javascript');
    // onload function
    $(js).attr({'onload': 'llab.highlightSyntax()'});
    // Using $ to append to head causes onload not to be fired...
    document.head.appendChild(css);
    document.head.appendChild(js);
}

// Call The Functions to HighlightJS to render
llab.highlightSyntax = function() {
    // TODO: PUT THESE CLASSES SOMEWHERE
     $('pre code').each(function(i, block) {
          // Trim the extra whitespace in HTML files.
          block.innerHTML = block.innerHTML.trim();
          if (typeof hljs !== 'undefined') {
               hljs.highlightBlock(block);
          }
     });
}

/** Import the required JS and CSS for LaTeX Code.
 *  TODO: Abstract this away into its own function
 */
llab.mathDisplaySetup = function () {
    var cssFile, jsFile, css, js;
    cssFile = llab.paths.katex_css;
    jsFile  = llab.paths.math_katex_js;
    css = getTag('link', cssFile, 'text/css');
    css.rel = "stylesheet";
    js = getTag('script', jsFile, 'text/javascript');
    // onload function
    $(js).attr({'onload': 'llab.displayMathDivs()'});
    // Using $ to append to head causes onload not to be fired...
    document.head.appendChild(css);
    document.head.appendChild(js);
}

// Call the KaTeX APIS to render the LaTeX code.
llab.displayMathDivs = function () {
    // TODO: Investigate caching of the selectors?
    // TODO: PUT THESE CLASSES SOMEWHERE
    $('.katex, .katex-inline').each(function (idx, elm) {
        katex.render(elm.textContent, elm, {throwOnError: false}); //Changed .innerHTML to .textContent on 1/29/16 to get > and < to work.
    });
    // TODO: PUT THESE CLASSES SOMEWHERE
    $('.katex-block').each(function (idx, elm) {
        katex.render(elm.textContent, elm, { //Changed .innerHTML to .textContent on 1/29/16 to get > and < to work.
            displayMode: true, throwOnError: false
        });
    });
}

/**
 *  Processes just the hyperlinked elements in the topic file,
 *  and creates navigation buttons.
 *  FIXME: This should share code with llab.topic!
 */
llab.processLinks = function(data, status, jqXHR) {
     /* NOTE: DO NOT REMOVE THIS CONDITIONAL WITHOUT SERIOUS TESTING
      * llab.file gets reset with the ajax call.
      */
     if (llab.file === '') {
          llab.file = llab.getQueryParameter('topic');
     }

     if (location.pathname === llab.empty_curriculum_page_path) {
          llab.addFrame();
     }

     // Get the URL parameters as an object
     // FIXME -- Rename the url variable
     // FIXME -- duplicate query parameters?
     var params = llab.getURLParameters(),
          course = params.course || '',
          topicArray = data.split("\n"),
          url = document.URL,
          // TODO: Move this to a dropdown function
          list = $(document.createElement("ul")).attr(
          { 'class': 'dropdown-menu dropdown-menu-right',
            'role': 'menu',
            'aria-labeledby': 'Topic-Navigation-Menu'}),
          itemContent,
          ddItem,
          line,
          isHidden,
          isHeading,
          lineClass,
          i = 0,
          len = topicArray.length,
          isExternal,
          pageCount = -1,
          sep, urlOpen, urlClose;

     // Prevent src, title from being added to other URLS.
     delete params.src;
     delete params.title;

     for (; i < len; i += 1) {
          line = llab.stripComments($.trim(topicArray[i]));

          sepIndex = line.indexOf(':');
          urlOpen = line.indexOf('[');
          urlClose = line.indexOf(']');

          // Skip is this line is hidden in URL params.
          lineClass = $.trim(line.slice(0, sepIndex));
          isHidden = params.hasOwnProperty('no' + lineClass);
          if (isHidden || !line) { continue; }

          // Line is a title; Create a link back to the main topic.
          if (line.indexOf("title:") !== -1) {
               url = llab.topic_launch_page + "?" + llab.QS.stringify(params);

               itemContent = line.slice(sepIndex + 1);
               itemContent = $.trim(itemContent);

               // Create a special Title link and add a separator.
               itemContent = llab.spanTag(itemContent, 'main-topic-link');
               ddItem = llab.dropdownItem(itemContent, url);
               // Note: Add to top of list!
               list.prepend(llab.fragments.bootstrapSep);
               list.prepend(ddItem);

               continue;
          }

          // Line is a heading in a topic file, so create menu heading
          isHeading = lineClass == 'heading';
          if (isHeading) {
               itemContent = line.slice(sepIndex + 1);
               itemContent = $.trim(itemContent);
               ddItem = llab.dropdownItem(itemContent);
               ddItem.addClass('dropdown-header');
               list.append(ddItem);
          }

          // If we don't have a link, skip this line.
          hasLink = urlOpen !== -1 && urlClose !== -1;
          if (!hasLink) { continue; }

          // Grab the link title between : [
          itemContent = line.slice(sepIndex + 1, urlOpen);
          itemContent = $.trim(itemContent);
          // Grab the link betweem [ and ]
          url = line.slice(urlOpen + 1, urlClose);
          pageCount += 1;
          // Content References an external resource
          if (url.indexOf("//") !== -1) {
               isCurrentPage = llab.getQueryParameter('src') === decodeURIComponent(url);
               url = llab.empty_curriculum_page_path + "?" + llab.QS.stringify(
                         $.extend({}, params, {
                              src: url,
                              title: itemContent
                         }));
          } else { // Content reference is local
               isCurrentPage = document.URL.indexOf(url) !== -1;
               if (url.indexOf(llab.rootURL) === -1 && url.indexOf("..") === -1) {
                    url = llab.rootURL + (url[0] === "/" ? '' : "/") + url;
               }
               url += url.indexOf("?") !== -1 ? "&" : "?";
               url += llab.QS.stringify($.extend({}, params));
          }

          llab.url_list.push(url);

          // Make the current step have an arrow in the dropdown menu
          if (isCurrentPage) {
               llab.pageNum = pageCount;
               itemContent = llab.spanTag(itemContent, 'current-page-arrow');
          }

          ddItem = llab.dropdownItem(itemContent, url);
          list.append(ddItem);
     } // end for loop

     if (course) {
          if (course.indexOf("//") === -1) {
               course = llab.courses_path + course;
          }
          itemContent = llab.spanTag(llab.strings.goMain, 'course-link-list');
          ddItem = llab.dropdownItem(itemContent, course);
          list.prepend(ddItem);
     }
     // Setup the nav button links and build the dropdown.
     llab.setButtonURLs();
     llab.buildDropdown();
     // FIXME -- will break on pages with multiple dropdowns (future)
     $('.dropdown').append(list);
     // Set the max-height of the dropdown list to not exceed window height
     // This is particularly important for smaller screens.
     $('.dropdown-menu').css('max-height', $(window).height() * 0.8);
     $('.dropdown-menu').css('max-width', Math.min($(window).width() * 0.8, 450));


     // FIXME -- this doesn't belong here.
     llab.indicateProgress(llab.url_list.length, llab.thisPageNum() + 1);

}; // end processLinks()


// Create an iframe when loading from an empty curriculum page
// Used for embedded content. (Videos, books, etc)
llab.addFrame = function() {
     var source = llab.getQueryParameter("src");

     var frame = $(document.createElement("iframe")).attr(
          {'src': source, 'class': 'content-embed'} );

    var conent = $(document.createElement('div'));
    conent.append(
        '<a href=' + source + ' target="_blank">Open page in new window</a><br />');
    conent.append(frame);

     $(FULL).append(conent);
};

// Setup the entire page title. This includes creating any HTML elements.
// This should be called EARLY in the load process!
// FIXME: lots of stuff needs to be pulled out of this function
llab.setupTitle = function() {
     // TODO: rename / refactor location
     $(document.head).append('<meta name="viewport" content="width=device-width, initial-scale=1">');

     if (llab.titleSet) {
          return;
     }

     // Create .full before adding stuff.
     if ($(FULL).length === 0) {
          $(document.body).wrapInner('<div class="full"></div>');
     }

     // Work around when things are oddly loaded...
     if ($(llab.selectors.NAVSELECT).length !== 0) {
          $(llab.selectors.NAVSELECT).remove();
     }

     // Create the header section and nav buttons
     llab.createTitleNav();

     // create Title tag, yo
     var titleText = llab.getQueryParameter("title");
     if (titleText !== '') {
          document.title = titleText;
     }

     // Set the header title to the page title.
     titleText = document.title;
     if (titleText) {
          // FIXME this needs to be a selector
          $('.navbar-title').html(titleText);
          $('.title-small-screen').html(titleText);
     }

     // Clean up document title if it contains HTML
     document.title = $(".navbar-title").text();
     // Special Case for Snap! in titles.
     document.title = document.title.replace('snap', 'Snap!');

     $(document.body).css('padding-top', $('.llab-nav').height() + 10);
     document.body.onresize = function(event) {
          $(document.body).css('padding-top', $('.llab-nav').height() + 10);
     };

     llab.titleSet = true;
};

llab.toggleDevComments = function() {
    $(".todo, .comment, .commentBig").toggle();
};

// Create the 'sticky' title header at the top of each page.
llab.createTitleNav = function() {
    var addToggle = "";
    if (window.location.href.slice(0,16) == "http://localhost" || window.location.href.slice(0,32) == "http://bjc-edc-2017-18.github.io") {
        addToggle = $('<button>').addClass('imageRight btn btn-default')
                    .click(llab.toggleDevComments)
                    .text('Toggle developer todos/comments (red boxes)');
    };

    // FIXME -- clean up!!
    var topHTML = (
        '<nav class="llab-nav navbar navbar-default navbar-fixed-top" role="navigation">' +
        '<div class="nav navbar-nav navbar-left navbar-title"></div></nav>' +
        '<div class="title-small-screen"></div>'
        ),
        botHTML = "<div class='full-bottom-bar'><div class='bottom-nav btn-group'></div></div>",
        navHTML = '<div class="nav navbar-nav navbar-right">' +
                  '<ul class="nav-btns btn-group"></ul></div>',
        topNav = $(llab.selectors.NAVSELECT),
        buttons = "<a class='btn btn-default backbutton arrow'>back</a>" +
                  "<a class='btn btn-default forwardbutton arrow'>next</a>";

    if (topNav.length === 0) {
        $(document.body).prepend(addToggle);
        $(document.body).prepend(topHTML);
        topNav = $(llab.selectors.NAVSELECT);
        topNav.append(navHTML);
     }

     // Don't add anything else if we don't know the step...
     // FUTURE - We should separate the rest of this function if necessary.
     if (!llab.isCurriculum()) {
          return;
     }

     // TODO: selector...
     $('.nav-btns').append(buttons);
     if ($(llab.selectors.PROGRESS).length === 0) {
          $(document.body).append(botHTML);
          $('.bottom-nav').append(buttons);
     }

     llab.setButtonURLs();
};


// Create the navigation dropdown
llab.buildDropdown = function() {
     // TODO -- cleanup use selectors for classes

     var dropwon, list_header;
     // Container div for the whole menu (title + links)
     dropdown = $(document.createElement("div")).attr(
          {'class': 'dropdown inline'});

     // build the list header
     list_header = $(document.createElement("button")).attr(
          {'class': 'navbar-toggle btn btn-default dropdown-toggle list_header',
           'type' : 'button', 'data-toggle' : "dropdown" });
     list_header.append(hamburger);

     // Add Header to dropdown
     dropdown.append(list_header);
     // Insert into the top div AFTER the backbutton.
     dropdown.insertAfter($('.navbar-default .navbar-right .backbutton'));
};

/** Build an item for the navigation dropdown
 *  Takes in TEXT and a URL and reutrns a list item to be added
 *  too an existing dropdown */
llab.dropdownItem = function(text, url) {
     var item, link;
     // li container
     item = $(document.createElement("li")).attr(
          {'class': 'list_item', 'role' : 'presentation'});
     if (url) {
          link = $(document.createElement("a")).attr(
               {'href': url, 'role' : 'menuitem'});
          link.html(text);
          item.append(link);
     } else {
          item.html(text);
     }

     return item;
};

// FIXME
llab.isCurriculum = function() {
     if (llab.getQueryParameter('topic')) {
          return location.pathname !== llab.empty_topic_page_path &&
                  location.pathname !== llab.topic_launch_page &&
                  location.pathname !== llab.alt_topic_page;
     }
     return false;
}


/* Return the index value of this page in reference to the lab.
 * Indicies are 0 based, and this excludes query parameters because
 * they could become re-ordered. */
llab.thisPageNum = function() {
     return llab.pageNum;
     /// This code below needs to be removed, pending some testing
     // January 21, 2015 (If it hasn't been removed in a long while, chuck it)
     var path = location.pathname;
     var urls;
     if (path === llab.empty_curriculum_page_path) {
          urls = llab.url_list.map(function(item) {
               return llab.QS.parse(item)['src'];
          });
          path = llab.getQueryParameter('src');
     } else {
          var result = -1;
          llab.url_list.forEach(function(item, idx) {
               if (document.URL.indexOf(item) !== -1) {
                    result = idx;
                    return result;
               }
          });
          return result;
     }
     return urls.indexOf(path);
}

// Create the Forward and Backward buttons, properly disabling them when needed
llab.setButtonURLs = function() {
     // No dropdowns for places that don't have a step.
     if (!llab.isCurriculum()) {
          return;
     }

     // TODO REFACTOR THIS
     var forward = $('.forwardbutton');
          back     = $('.backbutton');

     var buttonsExist = forward.length !== 0 && back.length !== 0;

     if (!buttonsExist & $(llab.selectors.NAVSELECT) !== 0) {
          // freshly minted buttons. MMM, tasty!
          llab.createTitleNav();
     }

     forward = $('.forwardbutton');
     back     = $('.backbutton');

     // Disable the back button
     var thisPage = llab.thisPageNum();
     if (thisPage === 0) {
          back.each(function(i, item) {
               $(item).addClass('disabled')
                       .attr('href', '#');
          });
     } else {
          back.each(function(i, item) {
               $(item).removeClass('disabled')
                       .attr('href', llab.url_list[thisPage - 1])
                       .click(llab.goBack);
          });
     }

     // Disable the forward button
     if (thisPage === llab.url_list.length - 1) {
          forward.each(function(i, item) {
               $(item).addClass('disabled')
                       .attr('href', '#');
          });
     } else {
          forward.each(function(i, item) {
               $(item).removeClass('disabled')
                       .attr('href', llab.url_list[thisPage + 1])
                       .click(llab.goForward);
          });
     }
};

// TODO: Update page content and push URL onto browser back button
llab.goBack = function() {
     location.href = llab.url_list[llab.thisPageNum() - 1];
};

llab.goForward = function() {
     location.href = llab.url_list[llab.thisPageNum() + 1];
};

llab.addFeedback = function(title, topic, course) {
     // Prevent Button on small devices
     if (screen.width < 1024) {
          return;
     }

	 // Prevent Feedback Button on non Teacher Guide pages (Added by Mary Fries on 10/16/17)
	 if (location.pathname.slice(0,25) != "/bjc-r/cur/teaching-guide") {
		 return;
	 }

     // TODO: Make this config
     var surveyURL = 'https://getfeedback.com/r/LRm9oI3N?PAGE=pageRep&TOPIC=topicRep&COURSE=courseRep&URL=urlRep';
     surveyURL = surveyURL.replace(/pageRep/g, encodeURIComponent(title))
                                .replace(/topicRep/g, encodeURIComponent(topic))
                                .replace(/courseRep/g, encodeURIComponent(course))
                                .replace(/urlRep/g, encodeURIComponent(document.URL));

     var button = $(document.createElement('button')).attr(
               {   'class': 'btn btn-primary btn-xs feedback-button',
                    'type': 'button',
                    'data-toggle': "collapse",
                    'data-target': "#fdbk" }).text('Feedback'),
          innerDiv = $(document.createElement('div')).attr(
               {   'id': "fdbk",
                    'class': "collapse feedback-panel panel panel-primary"
               }),
          feedback = $(document.createElement('div')).attr(
               {'class' : 'page-feedback'}).append(button, innerDiv);

     // Delay inserting a frame until the button is clicked.
     // Reason 1: Performance
     // Reason 2: GetFeedback tracks "opens" and each load is an open
     button.click('click', function(event) {
          if ($('#feedback-frame').length === 0) {
               var frame = $(document.createElement('iframe')).attr(
               {
                    'frameborder': "0",
                    'id': 'feedback-frame',
                    'width': "300",
                    'height': "230",
                    'src': surveyURL
               });
               $('#fdbk').append(frame);
          }
     });
     $(document.body).append(feedback);
};

// Footer content added by Mary on 1/20/16 was moved outside of feedback function by Mary on 10/16/17
llab.addFooter = function() {
     var footer = '<div class="footer" style="position:relative;"><a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/" target="_blank"><img class="imageLeft" alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a><div style="position:absolute;left: 135px; margin-bottom: 20px;"><span xmlns:dct="http://purl.org/dc/terms/" property="dct:title"><em>Beauty and Joy of Computing</em></span> by <span xmlns:cc="http://creativecommons.org/ns#" property="cc:attributionName">University of California, Berkeley and Education Development Center, Inc.</span> is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/" target="_blank">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>. The development of this site is funded by the National Science Foundation under grant number 1441075. Any opinions, findings, and conclusions or recommendations expressed in this material are those of the author(s) and do not necessarily reflect the views of the National Science Foundation.</div></div>';
	$(document.body).append(footer);
}

/**
 *  Positions an image along the bottom of the lab page, signifying progress.
 *  numSteps is the total number of steps in the lab
 *  currentStep is the number of the current step
 *  Note, these steps are 0 indexed!
 */
llab.indicateProgress = function(numSteps, currentStep) {
     var progress = $(llab.selectors.PROGRESS),
          width = progress.width(),
          // TODO: This neeeds to be a global selector!!
          btns = $('.bottom-nav').width(),
          pctMargin, result; // result stores left-offset of background image.

     /* This works as long as the buttons are on the RIGHT of the image to be
      * moved. The image on the last step will be moved at most the % width of
      * the buttons.
      */
     pctMargin = (btns / width) * 100;
     result = currentStep /  (numSteps + 1);
     result = result * (100 - pctMargin);
     result = result + "% 3px";
     // 3px == height of bottom-bar - image height == (32px - 26px)/ 2
     progress.css("background-position", result);
};

// Setup the nav and parse the topic file.
$(document).ready(function() {
     llab.secondarySetUp();
});

