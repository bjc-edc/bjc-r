/** curriculum.js
*
*  sets up a curriculum page -- either local or external.
*
*  JavaScript Dependencies:
*   llab.js
*   jQuery
*   library.js
*/

// TODO: Notes on most necessary refactorings:
// * Dynamic Navigation is messy.
// * getters/setters for "current page" in a lab need refactored
// * getCurrentPageURL, nextPageURL, prevPageURL
llab.file = "";
llab.url_list = [];

var FULL = llab.selectors.FULL;

const TOGGLE_HEADINGS = [
  'ifTime',
  'takeItFurther',
  'takeItTeased',
];

llab.set_cache = (key, value) => {
  sessionStorage[key] = value;
  return true;
}

// TODO: Should this ingore the cache in development?
llab.read_cache = key => sessionStorage[key];

// Switch to turn off ajax page loads.
llab.DISABLE_DYNAMIC_NAVIGATION = true;
// this should only be true when navigating back/forwards so we do no repopulate history.
// llab.SKIP_PUSH_STATE = false;

llab.dynamicNavigation = (path) => {
  return (event) => {
    if (llab.DISABLE_DYNAMIC_NAVIGATION) {
      location.href = path;
      return;
    }
    event.preventDefault();
    llab.loadNewPage(path);
  }
}

if (!llab.DISABLE_DYNAMIC_NAVIGATION) {
  // Handle popstate events for when users use the back button
  window.addEventListener("popstate", (event) => {
    const state = event.state;
    console.log(event)
    // debugger;

    if (!state || !state.body || !state.title) {
      location.reload();
      return;
    }

    // llab.SKIP_PUSH_STATE = true;
    llab.rerenderPage(state.body, state.title);
  });
}

/////////////////////

// Executed on *every* page load.
llab.secondarySetUp = function (newPath) {
  let t = llab.translate;
  llab.setupTitle();
  llab.addFooter();

  // Get the topic file and step from the URL
  llab.file = llab.getQueryParameter("topic");

  // fix snap links so they run snap
  $('.js-run, a.run').each(function(_i) {
    $(this).attr('target', '_blank');
    $(this).attr('href', llab.getSnapRunURL(this.getAttribute('href'))); // {version: 'v7'}
  });

  // Return the name of the class on element if it is a class in optionalContent
  function lookupClassName(toggleClasses, classList) {
    return toggleClasses.find(className => classList.includes(className));
  }

  let classSelector = `.${TOGGLE_HEADINGS.join(',.')}`;
  $(classSelector).each(function(_i) {
    let classList = Array.from(this.classList);
    let isVisible = classList.indexOf('show') > -1;
    let contentType = lookupClassName(TOGGLE_HEADINGS, classList);
    this.outerHTML = `
      <details class="${classList.join(' ')}" ${isVisible ? 'open' : ''}>
        <summary class="disclosure-heading">${t(contentType)}</summary>
        <div>${this.innerHTML}</div>
      </details>`;

    // Use class "ifTime show" to show by default.
    if (isVisible) {
      $(this).attr('open', true);
    }
  });

  llab.setupSnapImages();

  // TODO: Figure a nicer place to put all of these...
  // TODO: Rewrite the function to not scan every element.
  if ($('[w3-include-html]')) {
    w3.includeHTML();
  }

  // Make it easy to make little color swatch boxes.
  // These are useful when teaching about RGB.
  $('.color-swatch').each((_, el) => {
    $(el).css('background-color', $(el).attr('data-color'))
  })

  llab.addFeedback(document.title, llab.file, llab.getQueryParameter('course'));

  // We don't have a topic file, so we should exit.
  if (llab.file === '' || !llab.isCurriculum()) {
    return;
  }

  if (!llab.SKIP_PUSH_STATE) {
    window.history.pushState(
      { "title": document.title, "body": $('.full').html() },
      document.title,
      newPath // null on initial page loads...
    );
  } else {
    // once we have rendered a new page, we can add this back.
    llab.SKIP_PUSH_STATE = false;
  }

  if (llab.read_cache(llab.file)) {
    // TODO: Update this to use a parsed JSON object.
    llab.processLinks(llab.read_cache(llab.file));
  } else {
    fetch(`${llab.topics_path}/${llab.file}`)
      .then(response => response.text())
      .then(topic => llab.processLinks(topic))
      .catch(llab.handleError);
  }
}; // close secondarysetup();

/**
*  Processes just the hyperlinked elements in the topic file,
*  and creates navigation buttons.
*  FIXME: This should share code with llab.topic!
*/
llab.processLinks = (data) => {
  /* NOTE: DO NOT REMOVE THIS CONDITIONAL WITHOUT SERIOUS TESTING
  * llab.file gets reset with the ajax call.
  */
  if (llab.file === '') {
    llab.file = llab.getQueryParameter('topic');
    llab.set_cache(llab.file, data);
  }

  if (location.pathname === llab.empty_curriculum_page_path) {
    llab.addFrame();
  }

  // Reset the URL list
  llab.url_list = [];

  // Get the URL parameters as an object
  // FIXME -- Rename the url variable
  // FIXME -- duplicate query parameters?
  var params = llab.getURLParameters(),
    course = params.course || '',
    topicArray = data.split("\n"),
    url = location.href,
    list = $('.js-llabPageNavMenu'),
    itemContent,
    ddItem,
    line,
    isHidden,
    isHeading,
    lineClass,
    i = 0,
    len = topicArray.length,
    pageCount = -1,
    urlOpen, urlClose;

  // Prevent src, title from being added to other URLs.
  delete params.src;
  delete params.title;

  // Ensure the menu is empty before re-adding items.
  list.html('');

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
      isCurrentPage = location.href.indexOf(url) !== -1;
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
    itemContent = llab.spanTag(llab.t(llab.strings.goMain), 'course-link-list');
    ddItem = llab.dropdownItem(itemContent, course);
    list.prepend(ddItem);
  }
  // Setup the nav button links and build the dropdown.
  llab.setButtonURLs();

  // Before adding the list to the page, remove headings without any links.
  list.find('li.dropdown-header').each((_i, element) => {
    if ($(element).next().length === 0 ||
        $(element).next().hasClass('dropdown-header')) {
      $(element).remove();
    }
  });

  $('.js-navDropdown').append(list);
  // Set the max-height of the dropdown list to not exceed window height
  // This is particularly important for smaller screens.
  $('.dropdown-menu').css('max-height', $(window).height() * 0.6);
  $('.dropdown-menu').css('max-width', Math.min($(window).width()*.97, 450));

  // Attach Dynamic Click Handlers to menu items.
  $('a[role=menuitem]').each((_i, element) => {
    $(element).off('click').on('click', llab.dynamicNavigation(element.href));
  });

  llab.indicateProgress(llab.url_list.length, llab.thisPageNum() + 1);
}; // end processLinks()


// Build a list of links to be appended to the navigation dropdown.
llab.buildDropdownFromTopicModel = _llabObj => {
  // TODO: Just the parsed topic file to create dropdown contents.
  let _list = $('.js-llabPageNavMenu');
}

// Create an iframe when loading from an empty curriculum page
// Used for embedded content. (Videos, books, etc)
llab.addFrame = function() {
  var source = llab.getQueryParameter("src");

  var frame = $(document.createElement("iframe")).attr(
    {'src': source, 'class': 'content-embed', 'title': 'Embedded video content'}
  );

  let content = $(document.createElement('div'));
  content.append(`<a href="${source}" target=_blank>Open page in new window</a><br />`);
  content.append(frame);

  $(FULL).append(content);
};

// Setup the entire page title. This includes creating any HTML elements.
// This should be called EARLY in the load process!
llab.setupTitle = function() {
  if (llab.titleSet) { return; }

  if (!$('meta[name="viewport"]').length) {
    $(document.head).append('<meta name="viewport" content="width=device-width, initial-scale=1">');
  }

  // Create .full before adding stuff.
  if ($(FULL).length === 0) {
    $(document.body).wrapInner('<main class="full"></main>');
  }
  llab.setAdditionalClasses();

  // Reset the nav + title divs.
  if ($(llab.selectors.NAVSELECT).length !== 0) {
    $(llab.selectors.NAVSELECT).remove();
    $('.title-small-screen').remove();
  }

  // Create the header section and nav buttons
  llab.createTitleNav();

  let titleText = llab.getQueryParameter("title");
  if (titleText !== '') {
    document.title = titleText;
  }

  titleText = document.title;
  if (titleText) {
    $('.navbar-title').html(titleText);
    $('.title-small-screen').html(titleText);
  }

  // Clean up document title if it contains HTML
  document.title = $(".navbar-title").text();
  // Special Case for Snap! in titles.
  document.title = document.title.replace('snap', 'Snap!');

  $(document.body).css('padding-top', $('.llab-nav').height() - 100);
  document.body.onresize = function(_event) {
    $(document.body).css('padding-top', $('.llab-nav').height() + 10);
  };

  llab.titleSet = true;
};

// Create the 'sticky' title header at the top of each page.
llab.createTitleNav = function() {
  llab.setUpDevComments();

  // The BJC Logo takes you to the course ToC, or the BJC index when there is no course defined.
  let t = llab.t,
      navURL = '/bjc-r/',
      logoURL = '/bjc-r/img/header-footer/bjc-logo-sm2.png';
  if (llab.getQueryParameter('course')) {
    navURL = `/bjc-r/course/${llab.getQueryParameter('course')}`;
  } else if (location.pathname.indexOf('/bjc-r/course/') == 0) {
    navURL = location.pathname;
  }

  let previousButtonLabel = `aria-label="${t('backText')}"`,
    nextButtonLabel = `aria-label="${t('nextText')}"`,
    previousPageButton = `
      <a class='btn btn-nav hidden js-backPageLink js-navButton' ${previousButtonLabel}>
        <i class="fas fa-arrow-left" aria-hidden=true></i>
      </a>`,
    nextPageButton = `
      <a class='btn btn-nav hidden js-nextPageLink js-navButton' ${nextButtonLabel}>
        <i class="fas fa-arrow-right" aria-hidden=true></i>
      </a>`,
    // use \u00F1 instead of an ñ in the menu. (Issue in Chrome on topic pages)
    topHTML = `
    <nav class="llab-nav navbar navbar-fixed-top" role="navigation">
      <div class="nav navbar-left">
        <a class="navbar-brand" rel="author" href="${navURL}"
          aria-label="${t('Go to Index')}">
          <img src="${logoURL}" alt="${t('BJC logo')}">
        </a>
        <h1 class="navbar-title"></h1>
      </div>
      <ul class="nav navbar-nav navbar-right">
        <li class="dropdown js-langDropdown nav-lang-dropdown hidden">
          <a class="btn btn-nav btn-nav-lang dropdown-toggle" type="button"
            aria-label=${t('Switch language')} role="button" tabindex=0
            id="dropdown-langs" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
            <i class="far fa-globe" aria-hidden=true></i>
          </a>
          <ul class="dropdown-menu" aria-labelledby="dropdown-langs">
            <li><a class="js-switch-lang-en">English</a></li>
            <li><a class="js-switch-lang-es">Espa\u00F1ol</a></li>
          </ul>
        </li>
        <li class="nav-btn-group nav-btn-group-first">${previousPageButton}</li>
        <li class="nav-btn-group dropdown js-navDropdown js-navButton hidden">
          <a class="btn btn-nav dropdown-toggle"
            type="button" role="button" tabindex=0
            aria-label="${t('Navigation Menu')}"
            id="Topic-Navigation-Menu" data-toggle="dropdown"
            aria-haspopup=true aria-expanded=false>
            <i class="fas fa-bars" aria-hidden=true></i>
          </a>
          <ul class="js-llabPageNavMenu dropdown-menu"
            role="menu" aria-labelledby='Topic-Navigation-Menu'>
          </ul>
        </li>
        <li class="nav-btn-group nav-btn-group-last">${nextPageButton}</li>
      </ul>
      <div class="trapezoid"></div>
    </nav>`,
    botHTML = `
      <nav class="full-bottom-bar" aria-label="secondary page navigation">
        <div class="js-navButton hidden" style="float: left">
          ${previousPageButton}
        </div>
        <div class="progress-indicator"></div>
        <div class="js-navButton hidden" style="float: right">
          ${nextPageButton}
        </div>
      </nav>`,
    topNav = $(llab.selectors.NAVSELECT),
    smallScreenTitle = '<h1 class="title-small-screen"></h1>';

  if ($('.title-small-screen').length === 0) {
    $('main').prepend(smallScreenTitle);
  }

  if (topNav.length === 0) {
    $(document.body).prepend(topHTML);
  }

  llab.setupTranslationsMenu();

  // This doesn't quite belong here. index pages are a special case...
  // TODO: Consider atwork pages too?
  if (location.pathname.indexOf('vocab-index') > 0) {
    let course = llab.getQueryParameter('course');
    llab.renderCourseLink(course);
  }

  // Don't add anything else if we don't know the step...
  // FUTURE - We should separate the rest of this function if necessary.
  if (!llab.isCurriculum()) { return; }

  if ($('.full-bottom-bar').length === 0) {
    $(document.body).append(botHTML);
  }

  llab.setButtonURLs(); // TODO-INVESTIGATE: We should be able to remove this.
};

llab.setAdditionalClasses = () => {
  let $container = $('.full');
  let isTeacherGuide = location.href.indexOf('teaching-guide') > 0;
  if (isTeacherGuide) {
    $container.addClass('teacher-guide')
  }
}
/** Build an item for the navigation dropdown
*  Takes in TEXT and a URL and reutrns a list item to be added
*  too an existing dropdown */
llab.dropdownItem = function(text, url) {
  if (url) {
    text = `<a href=${url} role="menuitem">${text}</a>`;
  }

  return $(`<li role="presentation">${text}</li>`);
};

// Pages directly within a lab. Excludes 'topic' and 'course' pages.
llab.isCurriculum = () => llab.getQueryParameter('topic') != "" && !llab.isTopicFile();

/* Return the index value of this page in reference to the lab.
* Indicies are 0 based, and this excludes query parameters because
* they could become re-ordered. */
llab.thisPageNum = () => llab.pageNum;

// Create the Forward and Backward buttons, properly disabling them when needed
llab.setButtonURLs = function() {
  // No dropdowns for places that don't have a step.
  if (!llab.isCurriculum()) { return; }

  // TODO: Should this happen ever?
  var forward = $('.js-nextPageLink'), back = $('.js-backPageLink');
  var buttonsExist = forward.length !== 0 && back.length !== 0;
  if (!buttonsExist & $(llab.selectors.NAVSELECT) !== 0) {
    llab.createTitleNav();
  }

  forward = $('.js-nextPageLink');
  back = $('.js-backPageLink');
  // Unhide buttons and remove click handlers
  $('.js-navButton').removeClass('hidden').off('click');

  if (llab.thisPageNum() === 0) {
    back.addClass('disabled').removeAttr('href').removeAttr('aria-label').attr('disabled', true);
  } else {
    back.removeClass('disabled').removeAttr('disabled')
      .attr('aria-label', llab.t('backText'))
      .attr('href', llab.url_list[llab.thisPageNum() - 1])
      .on('click', llab.dynamicNavigation(llab.url_list[llab.thisPageNum() - 1]));
  }

  // Disable the forward button
  if (llab.thisPageNum() === llab.url_list.length - 1) {
    forward.addClass('disabled').removeAttr('href').removeAttr('aria-label').attr('disabled', true);
  } else {
    forward.removeClass('disabled').removeAttr('disabled')
      .attr('aria-label', llab.t('nextText'))
      .attr('href', llab.url_list[llab.thisPageNum() + 1])
      .on('click', llab.dynamicNavigation(llab.url_list[llab.thisPageNum() + 1]));
  }
};

llab.loadNewPage = (path) => {
  console.log('LOAD NEW PAGE: ', path);

  if (llab.PREVENT_NAVIGATIONS) {
    // this seems like a poor way to debounce multiple clicks.
    setTimeout((() => llab.PREVENT_NAVIGATIONS = false), 500);
  }

  llab.PREVENT_NAVIGATIONS = true;
  fetch(path)
    .then(response => response.text())
    .then(html => llab.rebuildPageFromHTML(html, path))
    .catch(err => {
      llab.PREVENT_NAVIGATIONS = false;
      console.warn('Something went wrong.', err);
      if (typeof Sentry !== 'undefined') {
        Sentry.captureException(err);
      }
      // make a traditional redirect.
      location.href = path;
    });
}


llab.rerenderPage = (body, title, path) => {
  // Reset llab state.
  llab.titleSet = false;
  llab.conditional_setup_run = false;
  console.log('RERENDER PAGE: ', path)

  document.title = title;
  $('.full').html(body);
  llab.setAdditionalClasses();
  llab.displayTopic(); // only topic pages...
  llab.editURLs(); // only course pages
  llab.secondarySetUp(path);
  buildQuestions(); // MCQs
  llab.conditionalSetup(llab.CONDITIONAL_LOADS);
  // TODO: Do we need to fire off any events? Bootstrap? dom loaded?
  window.scrollTo({ top: 0, behavior: 'instant' });

  if (llab.GACode) {
    gtag('config', llab.GACode, {
      page_title: title,
      page_location: location.href // Full URL is required.
    });
  }
}

// Called when we load an new document via a fetch.
llab.rebuildPageFromHTML = (html, path) => {
  let parser = new DOMParser(),
    doc = parser.parseFromString(html, 'text/html');

  let title = doc.querySelector('title') ? doc.querySelector('title').text : '';
  let body = doc.body.innerHTML;
  console.log('REBUILD FROM HTML')
  llab.rerenderPage(body, title, path);

  llab.PREVENT_NAVIGATIONS = false;
}

llab.addFeedback = function(title, topic, course) {
  // Prevent Button on small devices
  if (screen.width < 1024) { return; }

  // Show Feedback ONLY on Teacher Guide
  if (location.pathname.slice(0,25) != "/bjc-r/cur/teaching-guide") {
    return;
  }

  var surveyURL = 'https://getfeedback.com/r/LRm9oI3N?';
  surveyURL += $.param({
    'PAGE': title,
    'TOPIC': topic,
    'COURSE': course,
    'URL': location.href
  });

  var button = $(document.createElement('button')).attr({
    'class': 'btn btn-primary btn-xs feedback-button',
    'type': 'button',
    'data-toggle': "collapse",
    'data-target': "#fdbk"
  }).text('Feedback'),
  innerDiv = $(document.createElement('div')).attr({
    'id': "fdbk",
    'class': "collapse feedback-panel panel panel-primary"
  }),
  feedback = $(document.createElement('div')).attr(
    {'class' : 'page-feedback'}
  ).append(button, innerDiv);

  // Delay inserting a frame until the button is clicked.
  // Reason 1: Performance
  // Reason 2: GetFeedback tracks "opens" and each load is an open
  button.click('click', function(_event) {
    if ($('#feedback-frame').length === 0) {
      var frame = $(document.createElement('iframe')).attr({
        'frameborder': "0",
        'id': 'feedback-frame',
        'width': "300",
        'height': "230",
        'src': surveyURL,
        'title': 'Page feedback survey'
      });
      $('#fdbk').append(frame);
    }
  });
  $(document.body).append(feedback);
};

// TODO: Move to bootstrap classes (wait until BS5)
llab.addFooter = () => {
  if ($('footer').length > 0) { return; }

  $(document.body).append(
    `<footer>
      <div class="footer wrapper margins">
        <div class="footer-col col-md-1 col-xs-4">
          <img src="/bjc-r/img/header-footer/NSF_logo.png" alt="NSF" />
        </div>
        <div class="footer-col col-md-1 col-xs-4">
          <img src="/bjc-r/img/header-footer/EDC_logo.png" alt="EDC" />
        </div>
        <div class="footer-col col-md-1 col-xs-4">
          <img src="/bjc-r/img/header-footer/UCB_logo.png" alt="UCB" />
        </div>
        <div class="footer-col col-md-8 col-xs-12">
          <p>The Beauty and Joy of Computing by University of California, Berkeley and Education
          Development Center, Inc. is licensed under a Creative Commons
          Attribution-NonCommercial-ShareAlike 4.0 International License. The development of this
          site has been funded by the National Science Foundation under grant nos. 1138596, 1441075,
          and 1837280; the U.S. Department of Education under grant number S411C200074; and the
          Hopper-Dean Foundation.
          Any opinions, findings, and conclusions or recommendations expressed in this material are
          those of the author(s) and do not necessarily reflect the views of the National Science
          Foundation or our other funders.
        </p>
      </div>
      <div class="footer-col col-md-1 col-xs-4">
        <img src="/bjc-r/img/header-footer/cc_88x31.png" alt="Creative Commons Attribution" />
      </div>
    </div>
  </footer>`
  );
};

llab.translated_page_url = function() {
  // Return the URL to the current page when a translation exists.
  if (llab.pageLang() === 'es') {
    return location.href.replace(/\.es\./g, '.');
  } else if (llab.pageLang() === 'en') {
    return location.href.replace(/\.html/g, '.es.html').replace(/\.topic/g, '.es.topic');
   }
};

llab.translated_content_url = function() {
  // This returns the URL directly to a topic file, so we can see if the fetch passes.
  if (!llab.isTopicFile()) {
    return llab.translated_page_url();
  } else {
    let topic_file = llab.getQueryParameter("topic");
    if (llab.pageLang() === 'es') {
      topic_file = topic_file.replace(/\.es\./g, '.');
    } else if (llab.pageLang() === 'en') {
      topic_file = topic_file.replace(/\.topic/g, '.es.topic');
    }
    return llab.topics_path + topic_file;
  }
}

// Show a dropdwon icon in the navbar if the same URL exists in a translated form.
llab.setupTranslationsMenu = function() {
  // extract the language from the file name
  // make an ajax call to get the file name in the other language
  // if the file exists, add a link to it
  let lang = llab.pageLang();
  let new_url = llab.translated_page_url();
  // This URL is different when on a topic page.
  let translated_content_url = llab.translated_content_url();

  fetch(translated_content_url).then(response => {
    if (!response.ok) {
      console.log('Not found!!')
      // We need to re-hide the menu if it is currently showing.
      $('.js-langDropdown').addClass('hidden');
      $('.js-langDropdown a').removeAttr('href');
      return;
    }
    $('.js-langDropdown').removeClass('hidden');
    if (lang == 'es') {
      $('.js-switch-lang-es').attr('href', location.href);
      $('.js-switch-lang-en').attr('href', new_url);
    } else if (lang == 'en') {
      $('.js-switch-lang-es').attr('href', new_url);
      $('.js-switch-lang-en').attr('href', location.href);
    }
  }).catch(() => {});
}

llab.setupSnapImages = () => {
  $('img.js-runInSnap').each((_idx, elm) => {
    let openURL = llab.getSnapRunURL($img.attr('src'));
    $(elm).wrap(`<a href="${openURL}" class="snap-project" target=_blank></a>`);
  });
};

/**
*  Positions an image along the bottom of the lab page, signifying progress.
*  numSteps is the total number of steps in the lab
*  currentStep is the number of the current step
*/
llab.indicateProgress = function(numSteps, currentStep) {
  $(llab.selectors.PROGRESS).css(
    "background-position", `${currentStep / (numSteps) * 100}% 0`
  );
};

// Setup the nav and parse the topic file.
$(document).ready( () => llab.secondarySetUp() );
