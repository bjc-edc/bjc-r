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

// Content boxes that a URL can name with a #fragment, and that the generated
// summary pages link back to. Each selector must collect exactly what its
// counterpart in utilities/build-tools/ collects -- vocab.rb's VOCAB_CLASSES
// and selfcheck.rb's examFullWidth -- because a generated link identifies a
// box only by its position on the page.
// Self-check questions are missing here on purpose: quiz.js replaces their
// source markup with a rendered question, so multiplechoice.js numbers them.
const CONTENT_ANCHORS = [
  { type: 'vocab', selector: 'div[class*="vocab"]' },
  { type: 'exam', selector: 'div[class*="examFullWidth"]' },
];

// THE switch for dynamic (SPA-style) page loads. This is the only global
// which controls the feature. When false, navigation links behave like
// normal links and browser history is never touched.
llab.ENABLE_DYNAMIC_NAVIGATION = true;

// Internal dynamic-navigation state (not configuration).
// Ignore clicks while a dynamic page load is already in progress.
let dynamicNavInFlight = false;
// The path+query currently rendered, so hash-only popstate events
// (#anchor links) are not treated as page navigations.
let renderedPageURL = location.pathname + location.search;

llab.dynamicNavigation = (path) => {
  return (event) => {
    if (!llab.ENABLE_DYNAMIC_NAVIGATION) { return; } // normal navigation
    // Let the browser handle open-in-new-tab/window clicks.
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey ||
        (event.button !== undefined && event.button !== 0)) {
      return;
    }
    // A link to the current page is a plain reload; don't touch history.
    if (new URL(path, location.href).href === location.href) { return; }
    event.preventDefault();
    llab.loadNewPage(path);
  }
}

// Handle popstate events for when users use the back/forward buttons.
window.addEventListener("popstate", (event) => {
  if (!llab.ENABLE_DYNAMIC_NAVIGATION) { return; }

  // Ignore hash-only changes (#anchor links on the same page).
  if (renderedPageURL === location.pathname + location.search) { return; }

  if (event.state && event.state.llab) {
    // Re-fetch the page (usually served from the HTTP cache) instead of
    // restoring a stored copy, so it is rebuilt exactly like any other
    // dynamic load and never re-enhanced twice.
    llab.loadNewPage(location.href, { push: false });
  } else {
    location.reload();
  }
});

// Fires when the browser restores this page from the back/forward cache
// (bfcache): the DOM and JS heap thaw exactly as the student left them,
// and no load events re-fire. Refresh anything that went stale while frozen.
window.addEventListener("pageshow", (event) => {
  if (!event.persisted) { return; }
  // A dynamic load in flight when the page was frozen will never settle;
  // clear the guard so navigation keeps working.
  dynamicNavInFlight = false;
  // The session may have learned about available translations since.
  llab.setupTranslationsMenu();
});

///////////////////// CONTENT ANCHORS

// The ID of the NUMBERth box of TYPE on a page, counting from 1.
// The build tools spell the same IDs out in BJCHelpers#anchor_id; the two
// must agree, since that is all a generated link has to go on.
llab.anchorID = (type, number) => `${type}-${number}`;

// Give ELEMENT the ID that in-page links use to reach it. The tabindex lets
// llab.scrollToAnchor move keyboard focus onto what is otherwise a plain
// <div>; -1 keeps it out of the tab order. See .anchor-target in default.css.
llab.markAnchorTarget = (element, id) => {
  element.id = id;
  element.classList.add('anchor-target');
  if (!element.hasAttribute('tabindex')) {
    element.setAttribute('tabindex', '-1');
  }
};

// Number every vocab and exam box on the page, in document order, restarting
// at 1 for each type. Curriculum pages are hand-written HTML with no build
// step, so these IDs are applied in the browser rather than saved into the
// files -- on generated summary pages just the same, since their boxes are
// copies of the curriculum's.
llab.addContentAnchors = () => {
  CONTENT_ANCHORS.forEach(({ type, selector }) => {
    document.querySelectorAll(selector).forEach((box, index) => {
      llab.markAnchorTarget(box, llab.anchorID(type, index + 1));
    });
  });
};

// Scroll to the box named by the URL's #fragment. Returns whether one was
// found. The browser cannot do this itself: it resolves the fragment while
// the document is parsed, long before llab.addContentAnchors has assigned
// the IDs and before quiz.js has built the self-check questions.
llab.scrollToAnchor = () => {
  let fragment = location.hash.slice(1);
  if (!fragment) { return false; }

  // Non-ASCII IDs (the Spanish vocab index) arrive percent-encoded.
  let target = document.getElementById(fragment) ||
    document.getElementById(decodeURIComponent(fragment));
  if (!target) { return false; }

  // scrollIntoView honors the scroll-margin-top that keeps the box clear of
  // the fixed navbar; :target does not apply, as the ID postdates navigation.
  target.scrollIntoView();
  // Leave keyboard focus on the box the reader was sent to, so the next Tab
  // continues from there instead of from the top of the page. This is a no-op
  // for anything that isn't focusable.
  target.focus({ preventScroll: true });
  return true;
};

// Everything a fragment could name exists by "load": quiz.js builds the
// questions on DOM ready, and llab.addContentAnchors runs before that.
// Later fragment changes need no listener here -- by then the IDs are in the
// document, so the browser scrolls to them itself, clear of the navbar
// thanks to .anchor-target's scroll-margin.
window.addEventListener('load', () => llab.scrollToAnchor());

/////////////////////

// Executed on *every* page load.
llab.secondarySetUp = function () {
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
  // Ahead of the early return below: pages reached without a ?topic= (a unit
  // vocab page opened straight from the index) still need their anchors.
  llab.addContentAnchors();

  // TODO: Figure a nicer place to put all of these...
  // TODO: Rewrite the function to not scan every element.
  if ($('[w3-include-html]').length) {
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

  // TODO: Update this to use a parsed JSON object.
  llab.fetchTopicFile(llab.file)
    .then(topic => llab.processLinks(topic))
    .catch(llab.handleError);
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
    if (isCurrentPage) {
      ddItem.find('a').attr('aria-current', 'page');
    }
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
  $('.js-llabPageNavMenu a').each((_i, element) => {
    $(element).off('click').on('click', llab.dynamicNavigation(element.href));
  });

  llab.indicateProgress(llab.url_list.length, llab.thisPageNum() + 1);
}; // end processLinks()


// Create an iframe when loading from an empty curriculum page
// Used for embedded content. (Videos, books, etc)
llab.addFrame = function() {
  var source = llab.getQueryParameter("src");
  // The `title` param carries the resource's name from the topic file; the
  // embed isn't always a video, so only fall back to a generic label.
  var frameTitle = llab.getQueryParameter("title") || 'Embedded content';

  var frame = $(document.createElement("iframe")).attr(
    {'src': source, 'class': 'content-embed', 'title': frameTitle}
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
  $(FULL).first().attr({ 'id': 'main-content', 'tabindex': '-1' });
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
      <a class='btn btn-nav d-none js-backPageLink js-navButton' ${previousButtonLabel}>
        <i class="fas fa-arrow-left" aria-hidden=true></i>
      </a>`,
    nextPageButton = `
      <a class='btn btn-nav d-none js-nextPageLink js-navButton' ${nextButtonLabel}>
        <i class="fas fa-arrow-right" aria-hidden=true></i>
      </a>`,
    // use \u00F1 instead of an ñ in the menu. (Issue in Chrome on topic pages)
    topHTML = `
    <nav class="llab-nav navbar fixed-top navbar-expand" role="navigation"
      aria-label="${t('primaryNavLabel')}">
      <a class="skip-link" href="#main-content">${t('Skip to main content')}</a>
      <div class="d-flex align-items-center justify-content-start">
        <a class="navbar-brand" rel="author" href="${navURL}"
          aria-label="${t('Go to Index')}">
          <img src="${logoURL}" alt="${t('BJC logo')}">
        </a>
        <!-- Hidden from AT: duplicates the always-exposed .title-small-screen
             <h1> inside <main>, and would otherwise put the page's heading
             inside the navigation landmark. -->
        <h1 class="navbar-title" aria-hidden="true"></h1>
      </div>
      <ul class="navbar-nav flex-row ms-auto">
        <li class="nav-search nav-search-li">
          <button type="button" class="btn btn-nav btn-nav-search js-navbarSearchToggle"
            aria-label="${t('Search BJC')}" aria-expanded="false">
            <i class="fas fa-search" aria-hidden="true"></i>
          </button>
        </li>
        <li class="dropdown js-langDropdown nav-lang-dropdown d-none">
          <button class="btn btn-nav btn-nav-lang dropdown-toggle" type="button"
            aria-label="${t('Switch language')}"
            id="dropdown-langs" data-bs-toggle="dropdown" aria-expanded="false">
            <i class="far fa-globe" aria-hidden=true></i>
          </button>
          <ul class="dropdown-menu" aria-labelledby="dropdown-langs">
            <li><a class="js-switch-lang-en dropdown-item">English</a></li>
            <li><a class="js-switch-lang-es dropdown-item">Espa\u00F1ol</a></li>
          </ul>
        </li>
        <li class="nav-btn-group nav-btn-group-first">${previousPageButton}</li>
        <li class="nav-btn-group dropdown js-navDropdown js-navButton d-none">
          <button class="btn btn-nav dropdown-toggle" type="button"
            aria-label="${t('Navigation Menu')}"
            id="Topic-Navigation-Menu" data-bs-toggle="dropdown"
            aria-expanded="false">
            <i class="fas fa-bars" aria-hidden=true></i>
          </button>
          <ul class="js-llabPageNavMenu dropdown-menu"
            aria-labelledby='Topic-Navigation-Menu'>
          </ul>
        </li>
        <li class="nav-btn-group nav-btn-group-last">${nextPageButton}</li>
      </ul>
      <div class="navbar-search-bar js-navbarSearchBar" role="search">
        <label class="visually-hidden" for="navbarSearchInput">${t('Search BJC')}</label>
        <input type="search" id="navbarSearchInput" name="q"
          class="navbar-search-input js-navbarSearchInput"
          placeholder="${t('Search BJC')}" aria-label="${t('Search BJC')}"
          tabindex="-1">
      </div>
      <div class="trapezoid"></div>
    </nav>`,
    botHTML = `
      <nav class="full-bottom-bar" aria-label="${t('secondaryNavLabel')}">
        <div class="js-navButton d-none" style="float: left">
          ${previousPageButton}
        </div>
        <div class="progress-indicator"></div>
        <div class="js-navButton d-none" style="float: right">
          ${nextPageButton}
        </div>
      </nav>`,
    topNav = $(llab.selectors.NAVSELECT),
    smallScreenTitle = '<h1 class="title-small-screen"></h1>';

  // This <h1> is the page's only heading exposed to assistive tech (the
  // navbar title is aria-hidden), so it must exist on every page — axe's
  // page-has-heading-one fails otherwise. Target .full rather than <main>
  // so pages shipping .full on another element still get it.
  if ($('.title-small-screen').length === 0) {
    $(FULL).first().prepend(smallScreenTitle);
  }

  if (topNav.length === 0) {
    $(document.body).prepend(topHTML);
  }

  llab.setupNavbarSearch();
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
    text = `<a href="${url}" class="dropdown-item">${text}</a>`;
  }

  return $(`<li>${text}</li>`);
};

// Pages directly within a lab. Excludes 'topic' and 'course' pages.
llab.isCurriculum = () => llab.getQueryParameter('topic') != "" && !llab.isTopicFile();

/* Return the index value of this page in reference to the lab.
* Indicies are 0 based, and this excludes query parameters because
* they could become re-ordered. */
llab.thisPageNum = () => llab.pageNum;

// Hint the browser to fetch a likely-next URL so a click resolves from cache.
// Same-origin only — we don't want to warm third-party links.
llab.prefetched_urls = llab.prefetched_urls || new Set();
llab.prefetchPage = function(url) {
  if (!url || llab.prefetched_urls.has(url)) { return; }
  if (url.indexOf('//') !== -1 && url.indexOf(location.origin) !== 0) { return; }
  llab.prefetched_urls.add(url);
  let tag = document.createElement('link');
  tag.rel = 'prefetch';
  tag.href = url;
  tag.as = 'document';
  document.head.appendChild(tag);
};

// Create the Forward and Backward buttons, properly disabling them when needed
llab.setButtonURLs = function() {
  // No dropdowns for places that don't have a step.
  if (!llab.isCurriculum()) { return; }

  // Keep the buttons hidden until the topic's page list is available —
  // configuring them against an empty url_list leaves visible <a> elements
  // with an aria-label but no href (an axe aria-prohibited-attr violation).
  if (!llab.url_list || llab.url_list.length === 0) { return; }

  // TODO: Should this happen ever?
  var forward = $('.js-nextPageLink'), back = $('.js-backPageLink');
  var buttonsExist = forward.length !== 0 && back.length !== 0;
  if (!buttonsExist) {
    llab.createTitleNav();
  }

  forward = $('.js-nextPageLink');
  back = $('.js-backPageLink');
  // Remove click handlers; the buttons stay hidden until their href and
  // aria-label are set below — unhiding first exposes an <a> with an
  // aria-label but no href/role, which axe flags (aria-prohibited-attr).
  $('.js-navButton').off('click');

  // Disabled buttons: dropping the href takes the <a> out of the tab order,
  // and role="link" + aria-disabled keeps it announced by name as unavailable
  // (aria-label alone on an href-less <a> is an axe aria-prohibited-attr
  // violation; the `disabled` attribute is invalid on anchors).
  if (llab.thisPageNum() === 0) {
    back.addClass('disabled').removeAttr('href').removeAttr('disabled')
      .attr({ 'role': 'link', 'aria-disabled': 'true', 'aria-label': llab.t('backText') });
  } else {
    let prevURL = llab.url_list[llab.thisPageNum() - 1];
    back.removeClass('disabled').removeAttr('disabled')
      .removeAttr('role').removeAttr('aria-disabled')
      .attr('aria-label', llab.t('backText'))
      .attr('href', prevURL)
      .on('click', llab.dynamicNavigation(prevURL));
    llab.prefetchPage(prevURL);
  }

  // Disable the forward button
  if (llab.thisPageNum() === llab.url_list.length - 1) {
    forward.addClass('disabled').removeAttr('href').removeAttr('disabled')
      .attr({ 'role': 'link', 'aria-disabled': 'true', 'aria-label': llab.t('nextText') });
  } else {
    let nextURL = llab.url_list[llab.thisPageNum() + 1];
    forward.removeClass('disabled').removeAttr('disabled')
      .removeAttr('role').removeAttr('aria-disabled')
      .attr('aria-label', llab.t('nextText'))
      .attr('href', nextURL)
      .on('click', llab.dynamicNavigation(nextURL));
    llab.prefetchPage(nextURL);
  }

  // Unhide only once the buttons are fully configured.
  $('.js-navButton').removeClass('d-none');
};

// Fetch PATH and rebuild the page in place.
// Pass { push: false } (back/forward) to leave the history untouched.
llab.loadNewPage = (path, options) => {
  let pushState = !(options && options.push === false);

  if (dynamicNavInFlight) { return; }
  dynamicNavInFlight = true;

  fetch(path)
    .then(response => {
      if (!response.ok) {
        throw new Error(`Fetching ${path} returned ${response.status}`);
      }
      return response.text();
    })
    .then(html => {
      llab.rebuildPageFromHTML(html, path, pushState);
      dynamicNavInFlight = false;
    })
    .catch(err => {
      dynamicNavInFlight = false;
      llab.handleError(err);
      // make a traditional redirect.
      location.href = path;
    });
}


llab.rerenderPage = (body, title, path, docLang) => {
  // Reset llab state that is cached per-page.
  llab.titleSet = false;
  llab.conditional_setup_run = false;
  llab.safeURLParams = null;     // cached query parameters (library.js)
  llab.pageNum = undefined;      // position within the lab
  llab.CURRENT_PAGE_LANG = null; // cached page language
  // English URLs have no lang marker, so when switching languages the
  // fetched document's own <html lang> is the reliable fallback.
  let lang = llab.determinLangFromURL() || docLang;
  if (lang) { $('html').attr('lang', lang); }

  renderedPageURL = location.pathname + location.search;

  document.title = title;
  $('.full').html(body);
  llab.setAdditionalClasses();
  llab.displayTopic(); // only topic pages...
  llab.editURLs(); // only course pages
  llab.secondarySetUp();
  if (typeof buildQuestions === 'function') { buildQuestions(); } // MCQs
  llab.conditionalSetup(llab.CONDITIONAL_LOADS);
  // TODO: Do we need to fire off any events? Bootstrap? dom loaded?
  // A new page starts at the top, unless the link named a box on it. There is
  // no "load" event for a dynamic navigation, so scroll from here instead.
  if (!llab.scrollToAnchor()) {
    window.scrollTo({ top: 0, behavior: 'instant' });
  }

  if (llab.GACode) {
    gtag('config', llab.GACode, {
      page_title: title,
      page_location: location.href // Full URL is required.
    });
  }
}

// Called when we load a new document via a fetch.
llab.rebuildPageFromHTML = (html, path, pushState) => {
  let parser = new DOMParser(),
    doc = parser.parseFromString(html, 'text/html');

  let title = doc.querySelector('title') ? doc.querySelector('title').text : '';
  let docLang = doc.documentElement.getAttribute('lang');
  // Drop all script tags: jQuery re-executes any script in content passed
  // to .html(), which would re-run the entire llab loader.
  doc.body.querySelectorAll('script').forEach(tag => tag.remove());
  let body = doc.body.innerHTML;

  if (pushState) {
    // Tag the current entry so popstate can recognize our own entries,
    // then push the new page *before* rendering so all of the setup code
    // sees the new URL in `location`.
    if (!history.state || !history.state.llab) {
      history.replaceState({ llab: true }, '');
    }
    window.history.pushState({ llab: true }, '', path);
  }

  llab.rerenderPage(body, title, path, docLang);
}

llab.addFeedback = function(title, topic, course) {
  // Remove any previous widget; it is re-added on each dynamic page load.
  $('.page-feedback').remove();

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
    'class': 'btn btn-primary btn-sm feedback-button',
    'type': 'button',
    'data-bs-toggle': "collapse",
    'data-bs-target': "#fdbk"
  }).text('Feedback'),
  innerDiv = $(document.createElement('div')).attr({
    'id': "fdbk",
    'class': "collapse feedback-panel card border-primary"
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
      <div class="container">
        <div class="footer row">
          <div class="footer-col col-4 col-md-1">
            <img src="/bjc-r/img/header-footer/NSF_logo.png" alt="NSF" />
          </div>
          <div class="footer-col col-4 col-md-1">
            <img src="/bjc-r/img/header-footer/EDC_logo.png" alt="EDC" />
          </div>
          <div class="footer-col col-4 col-md-1">
            <img src="/bjc-r/img/header-footer/UCB_logo.svg" alt="UCB" />
          </div>
          <div class="footer-col col-12 col-md-8">
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
        <div class="footer-col col-4 col-md-1">
          <img src="/bjc-r/img/header-footer/cc_88x31.png" alt="Creative Commons Attribution" />
        </div>
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

// Google site-restricted search wired up to the navbar.
// Default UI is just the magnifier; clicking expands the input in place of
// the other right-side nav items. The `site:` filter is added when building
// the Google URL — the visible input value is never rewritten.

// Derive the site filter from the current host + the install folder
// (llab.rootURL). On localhost we fall back to bjc.edc.org since localhost
// itself isn't indexed by Google.
llab.NAVBAR_SEARCH_LOCAL_HOST = 'bjc.edc.org';
llab.getSearchSite = () => {
  let host = llab.isLocalEnvironment() ? llab.NAVBAR_SEARCH_LOCAL_HOST : location.hostname;
  let folder = (llab.rootURL || '').replace(/^\/+|\/+$/g, '');
  return folder ? `${host}/${folder}` : host;
};

llab.setupNavbarSearch = function () {
  let $toggle = $('.js-navbarSearchToggle');
  let $input = $('.js-navbarSearchInput');
  let $bar = $('.js-navbarSearchBar');
  if ($toggle.length === 0 || $toggle.data('llab-search-bound')) { return; }
  $toggle.data('llab-search-bound', true);

  let $nav = $('.llab-nav');
  let isOpen = () => $nav.hasClass('navbar-search-open');

  // Bootstrap 3 marks an open dropdown by adding .open to its wrapper.
  // Whenever search opens we collapse any sibling menu so only one
  // overlay is showing at a time.
  let closeOpenDropdowns = () => $nav.find('.dropdown.open').removeClass('open');

  let open = () => {
    closeOpenDropdowns();
    $nav.addClass('navbar-search-open');
    $toggle.attr('aria-expanded', 'true');
    $input.attr('tabindex', '0');
    setTimeout(() => $input.trigger('focus'), 0);
  };

  let close = () => {
    $nav.removeClass('navbar-search-open');
    $toggle.attr('aria-expanded', 'false');
    $input.attr('tabindex', '-1');
    $input.val('');
  };

  // Use a synthesized anchor.click() rather than window.open() — this
  // honors the user's browser preference for new tabs/windows and avoids
  // popup-blocker quirks tied to window.open feature strings.
  let openInNewWindow = (url) => {
    let a = document.createElement('a');
    a.href = url;
    a.target = '_blank';
    a.rel = 'noopener noreferrer';
    a.click();
  };

  let performSearch = () => {
    let query = ($input.val() || '').trim();
    if (!query) { close(); return; }
    let q = `${query} site:${llab.getSearchSite()}`;
    openInNewWindow(`https://www.google.com/search?q=${encodeURIComponent(q)}`);
    close();
  };

  $toggle.on('click', (event) => {
    event.preventDefault();
    if (!isOpen()) { open(); return; }
    performSearch();
  });

  $input.on('keydown', (event) => {
    if (event.key === 'Enter') {
      event.preventDefault();
      performSearch();
    } else if (event.key === 'Escape') {
      close();
      $toggle.trigger('focus');
    }
  });

  // Click anywhere outside the search UI (while open) to close.
  $(document).off('click.navbarSearch').on('click.navbarSearch', (event) => {
    if (!isOpen()) { return; }
    if ($(event.target).closest('.js-navbarSearchToggle, .js-navbarSearchBar').length) { return; }
    close();
  });

  // Bootstrap 3 dropdowns call `return false` on the toggle click, so the
  // event never reaches our outside-click handler. Hook the dropdown's own
  // show event instead: whenever a sibling dropdown is about to open,
  // collapse the search.
  $nav.off('show.bs.dropdown.navbarSearch').on('show.bs.dropdown.navbarSearch', () => {
    if (isOpen()) close();
  });
};

// TRANSLATIONS MENU (the navbar globe)
// The globe is shown when the content exists in the other language. To
// avoid the navbar shifting while we ask the server, the answer is checked
// once per *unit* (topic file) -- do all of its pages have a translation?
// -- and cached in sessionStorage. Every later page in the unit can then
// show or hide the globe synchronously, before the nav is even visible.

// sessionStorage key for the current unit's translation status.
llab.unitTranslationKey = () => {
  let topic = llab.getQueryParameter('topic');
  return topic ? `llab-unit-translations:${topic}` : null;
};

// Return PATH in the other language: page.html <-> page.es.html
llab.translatedPath = (path) => {
  if (llab.pageLang() === 'es') {
    return path.replace(/\.es\./g, '.');
  }
  return path.replace(/\.(html|topic)$/, '.es.$1');
};

// Return the local (non-external) page paths listed in topic file DATA.
llab.localTopicPages = (data) => {
  return data.split('\n').map(line => {
    line = llab.stripComments($.trim(line));
    let urlOpen = line.indexOf('['), urlClose = line.indexOf(']');
    if (urlOpen === -1 || urlClose === -1) { return null; }
    let url = line.slice(urlOpen + 1, urlClose).split('?')[0];
    if (url.indexOf('//') !== -1) { return null; } // external content
    if (url.indexOf(llab.rootURL) === -1 && url.indexOf('..') === -1) {
      url = llab.rootURL + (url[0] === '/' ? '' : '/') + url;
    }
    return url;
  }).filter(Boolean);
};

// Check that the current unit's topic file, and every local page listed in
// it, exist in the other language. Resolves true/false. Rejects on network
// errors, so a flaky connection is never cached as "no translation".
llab.checkUnitTranslations = () => {
  let file = llab.getQueryParameter('topic');

  let translatedTopicExists = fetch(
    llab.topics_path + llab.translatedPath(file), { method: 'HEAD' }
  ).then(response => response.ok);

  let allPagesExist = llab.fetchTopicFile(file).then(data => {
    let checks = llab.localTopicPages(data).map(page =>
      fetch(llab.translatedPath(page), { method: 'HEAD' }).then(r => r.ok)
    );
    return Promise.all(checks).then(results => results.every(Boolean));
  });

  return Promise.all([translatedTopicExists, allPagesExist])
    .then(([topicOK, pagesOK]) => topicOK && pagesOK);
};

// Show or hide the globe, and point the language links at this page's
// counterpart in the other language.
llab.showTranslationsMenu = (show) => {
  let dropdown = $('.js-langDropdown');
  if (!show) {
    dropdown.addClass('d-none');
    dropdown.find('a').removeAttr('href');
    return;
  }

  let new_url = llab.translated_page_url();
  if (llab.pageLang() === 'es') {
    $('.js-switch-lang-es').attr('href', location.href);
    $('.js-switch-lang-en').attr('href', new_url);
  } else {
    $('.js-switch-lang-es').attr('href', new_url);
    $('.js-switch-lang-en').attr('href', location.href);
  }
  // Language switches use dynamic navigation, like every other nav link.
  dropdown.find('.js-switch-lang-es, .js-switch-lang-en').each((_i, el) => {
    $(el).off('click').on('click', llab.dynamicNavigation(el.href));
  });
  dropdown.removeClass('d-none');
};

llab.setupTranslationsMenu = function() {
  // Embedded external content has no llab-managed translation to switch to.
  if (location.pathname === llab.empty_curriculum_page_path) {
    llab.showTranslationsMenu(false);
    return;
  }

  let unitKey = llab.unitTranslationKey();
  if (!unitKey) {
    // No unit context (course pages, index, ...): check just this page.
    // Only existence matters, so a HEAD request (no body download) is enough.
    let pageKey = `llab-translation-exists:${llab.translated_content_url()}`;
    let cached = llab.read_cache(pageKey);
    if (cached !== undefined) {
      llab.showTranslationsMenu(cached === 'true');
      return;
    }
    llab.showTranslationsMenu(false);
    fetch(llab.translated_content_url(), { method: 'HEAD' })
      .then(response => {
        llab.set_cache(pageKey, response.ok);
        llab.showTranslationsMenu(response.ok);
      })
      .catch(() => {}); // network error: leave hidden, retry next load
    return;
  }

  let cached = llab.read_cache(unitKey);
  if (cached !== undefined) {
    llab.showTranslationsMenu(cached === 'true');
    return;
  }

  // First page of this unit this session: the globe stays hidden until the
  // unit-wide check completes. Every later page hits the cache above.
  llab.showTranslationsMenu(false);
  llab.pendingTranslationChecks = llab.pendingTranslationChecks || {};
  if (!llab.pendingTranslationChecks[unitKey]) {
    llab.pendingTranslationChecks[unitKey] = llab.checkUnitTranslations()
      .then(complete => { llab.set_cache(unitKey, complete); return complete; })
      .catch(err => {
        // Do not cache network failures; allow the next page to retry.
        delete llab.pendingTranslationChecks[unitKey];
        throw err;
      });
  }
  llab.pendingTranslationChecks[unitKey]
    .then(complete => {
      // Only touch the UI if the user is still within this unit.
      if (llab.unitTranslationKey() === unitKey) {
        llab.showTranslationsMenu(complete);
      }
    })
    .catch(() => {});
}

llab.setupSnapImages = () => {
  $('img.js-runInSnap').each((_idx, elm) => {
    let openURL = llab.getSnapRunURL($(elm).attr('src'));
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
  // The sliding Alonzo image is purely visual; give assistive tech a text
  // equivalent. currentStep is NaN when the page isn't found in the lab.
  if (numSteps >= 1 && currentStep >= 1) {
    $(llab.selectors.PROGRESS).html(
      `<span class="visually-hidden">${llab.t('progressText', { current: currentStep, total: numSteps })}</span>`
    );
  }
};

// Setup the nav and parse the topic file.
$(document).ready( () => llab.secondarySetUp() );
