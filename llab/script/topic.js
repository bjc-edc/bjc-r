/*

  Renders Topic pages

  Special lines start with

  title:
  this replaces the page <title> and the main heading with the value
  { }
  this draws a box around the stuff in between the braces

  topic: the title for each topic

  heading: a smaller heading. may also use h1, h2, etc.

  learning-goal:
  puts values of adjacent lines that start with this as items in learning goals list.
  a blank line or other non learning-goal: line will end the list

  big-idea:
  same as above, for a big ideas list

  <4 spaces>
  if a line starts with four/eight/twelve spaces (tab characters also work),
  it will have an added class stuck in it called 'indent1', 'indent2', etc.
  The line will be treated as any other line otherwise

  raw-html:
  all following lines until a blank line or a resource tag are just raw html
  that is inserted into the model.

  other currently supported classes: quiz, assignment, resource, forum, video, extresource.

  Other lines get their own <div> with the class as specified in the string before the colon
  Can also specify some actual html tags before the colon (e.g. h1)
  Anything in a [] is stuck as the target of a link

  You may hide particular classes by passing URL parameters.
  For instance, to hide all videos, simply add the parameter (without the quotes) "novideo=true".
  It'll end up looking something like this:
  topic.html?topic=berkeley_bjc/intro/broadcast-animations-music.topic&novideo=true&noreading=true

*/

/* The allowed tags for easy entry.
 * e.g.   h1: Some Text [maybe/a/link/too]
 */
llab.topicKeywords = {};
llab.topicKeywords.resources = [
  "quiz",
  "assignment",
  "resource",
  "forum",
  "video",
  "extresource",
  "reading",
  "group",
];
llab.topicKeywords.headings = ["h1", "h2", "h3", "h4", "h5", "h6", "heading"];
llab.topicKeywords.info = ["big-idea", "learning-goal"];
llab.topicKeywords.special = ['raw-html'];

/* Turn a *.topic file in a JSON-type structure.
 * This needs some work to be easier to use...
*/
llab.parseTopicFile = function parser(data) {
  let splitLines = () => data.replace(/(\r)/gm, "").split("\n");
  let lines = splitLines(), topics = { topics: [] };
  let getNextLine = () => llab.stripComments(lines.shift()).trim();

  var line, topic_model, item, text, content, section, indent, raw = false;
  while (lines.length) {
    line = getNextLine();
    if (line.length && !raw) {
      if (line.match(/^title:/)) {
        topics.title = line.slice(6).trim();
      } else if (line.match(/^topic:/)) {
        topic_model.title = line.slice(6).trim();
      } else if (line.match(/^raw-html/)) {
        raw = true;
      } else if (line[0] == "{") {
        topic_model = { type: "topic", url: llab.topic, contents: [] };
        topics.topics.push(topic_model);
        section = { title: "", contents: [], type: "section" };
        topic_model.contents.push(section);
      } else if (llab.isHeading(line)) {
        headingType = llab.getKeyword(line, llab.topicKeywords.headings);
        if (section.contents.length > 0) {
          section = { title: "", contents: [], type: "section" };
          topic_model.contents.push(section);
        }
        section.title = llab.getContent(line)["text"];
        section.headingType = headingType;
      } else if (line[0] == "}") {
        // shouldn't matter
      } else if (llab.isInfo(line)) {
        tag = llab.getKeyword(line, llab.topicKeywords.info);
        indent = llab.indentLevel(line);
        content = llab.getContent(line)["text"]; // ?
        // TODO: do we really need indentation now?
        // if so, I think it should be added to the type
        // and only if indentation levels != nested levels.
        item = { type: tag, contents: content, indent: indent };
        section.contents.push(item);
      } else if (line.length == 0) {
        raw = false;
      } else {
        tag = llab.getKeyword(line, llab.topicKeywords.resources);
        indent = llab.indentLevel(line);
        content = llab.getContent(line);
        item = {
          type: tag,
          indent: indent,
          contents: content.text,
          url: content.url,
        };
        section.contents.push(item);
      }
    }
    if (raw) {
      var raw_html = [];
      text = llab.getContent(line)["text"]; // in case they start the raw html on the same line
      if (text) {
        raw_html.push(text);
      }
      next = lines[1];
      while (next.length >= 1 && next[0] != "}" && !llab.isKeyword(next)) {
        line = getNextLine();
        raw_html.push(line);
        next = lines[0];
      }
      section.contents.push({ type: "raw-html", contents: raw_html.join("\n") });
      raw = false;
    }
  }
  llab.topics = topics;
  return topics;
};

/*
 *  Return true if a line matches with a keywoard in A.
 *  A `line` is either a single word, or an unparsed line of a topic file.
 */
llab.matchesArray = (line, A) => {
  return A.some(s => line.match(new RegExp(`(\s*${s}:)|(^${s}$)`, 'i')) !== null);
};

// TODO: comment...
llab.getKeyword = function (line, A) {
  var matches = A.map((s) => line.match(s));
  var index = matches.findIndex((m) => m !== null);
  return index !== -1 ? A[index] : undefined;
};

llab.getContent = function (line) {
  var sepIdx = line.indexOf(":");
  var content = line.slice(sepIdx + 1);
  // TODO, we could probably strengthen this with a lastIndexOf() call.
  var sliced = content.split(/\[|\]/);
  return { text: sliced[0].trim(), url: sliced[1] };
};

llab.isResource = function (line) {
  return llab.matchesArray(line, llab.topicKeywords.resources);
};

llab.isInfo = function (line) {
  return llab.matchesArray(line, llab.topicKeywords.info);
};

llab.isHeading = function (line) {
  return llab.matchesArray(line, llab.topicKeywords.headings);
};

llab.isSpecial = function (line) {
  return llab.matchesArray(line, llab.topicKeywords.special);
};

llab.isKeyword = function (line) {
  return llab.isResource(line) || llab.isInfo(line) || llab.isHeading(line) || llab.isSpecial(line);
};

llab.renderFull = function renderAndParse(data) {
  var content = llab.parseTopicFile(data);
  llab.renderTopicModel(content);
  llab.secondarySetUp();
  // llab.conditionalSetup(llab.CONDITIONAL_LOADS);
  // if ($('[w3-include-html]')) {
  //   w3.includeHTML();
  // }
};

llab.renderTopicModel = function rederer(topics) {
  llab.renderTitle(topics.title);
  topics.topics.forEach(function (topic) {
    llab.renderTopic(topic);
  });
};

llab.renderTitle = function (title) {
  var navbar, titleText;
  navbar = $('.navbar-title');
  $(llab.selectors.MOBILETITLE).html(title);
  navbar.html(title);
  titleText = navbar.text(); // Normalize Window Title
  titleText = titleText.replace("snap", "Snap!");
  document.title = titleText;
};

llab.renderCourseLink = function (course) {
  if (!course) {
    console.warn('No course found for this topic page.');
    return;
  }

  if (course.indexOf("://") === -1) {
    course = llab.courses_path + course;
  }
  $(".full").prepend(
    `<a class="course_link pull-right" href="${course}">${llab.t(llab.strings.goMain)}</a>`
  );
};

llab.renderTopic = function (topic_model) {
  var FULL = llab.selectors.FULL,
    params = llab.getURLParameters(),
    course = params.course;
  var $topicDiv = $(`<div class="topic"></div>`);

  if (topic_model.title) {
    $topicDiv.append(`<div class="topic_header">${topic_model.title}</div>`);
  }

  var current;
  for (var i = 0; i < topic_model.contents.length; i++) {
    current = topic_model.contents[i];
    if (current.type == "section") {
      llab.renderSection(current, $topicDiv);
    } else {
      console.warn('non-section content skipped:', content)
    }
  }

  // Make sure to only update view once things are rendered.
  $(FULL).append($topicDiv);
  llab.renderCourseLink(course);
};

llab.renderSection = function (section, parent) {
  var $section = $("<section>"),
    params = llab.getURLParameters();

  // TODO: This heading needs to be computed in a more accurate way...
  if (section.title) {
    var tag = section.headingType == "heading" ? "h2" : section.headingType;
    $section.append(`<${tag}>${section.title}</${tag}>`);
  }

  $section.append('<ol>');
  let $contentContainer = $section.find('ol');

  var current;
  for (var i = 0; i < section.contents.length; i++) {
    current = section.contents[i];
    isHidden = params.hasOwnProperty(`no${current.type}`);

    // Skip Rendering Hidden Resources.
    if (isHidden) { continue; }

    if (current.type && llab.isResource(current.type)) {
      llab.renderResource(current, $contentContainer);
    } else if (current.type && llab.isInfo(current.type)) {
      var infoSection = [current];
      while (
        i < section.contents.length - 1 &&
        section.contents[i].type == current.type
      ) {
        i++;
        infoSection.push(section.contents[i]);
      }
      llab.renderInfo(infoSection, current.type, $contentContainer);
    } else if (current.type == "section") {
      llab.renderSection(current, $section);
    } else if (current.type === "raw-html") {
      // TODO: This section is challening...
      // Content before the item list belongs to the containr.
      // Content w/in the list needs to conform to being an li or ul.
      // It all needs to be (Seeming?) appear in-order (see Sparks TG)
      if ($contentContainer.children().length == 0) {
        $contentContainer.before(current.contents);
      } else {
        $contentContainer.append(current.contents);
      }
    } else {
      $contentContainer.append(current.contents);
    }
  }

  if ($contentContainer.children().length == 0) {
    $contentContainer.remove();
  }

  $section.appendTo(parent);
};

llab.fullResourceURL = (url) => {
  let query = llab.getURLParameters();

  // TODO: Do not append llab-specific query parameters to external links.
  if (url.indexOf("http") != -1) {
      query = $.extend({}, query, { src: url });
      url = llab.empty_curriculum_page_path;
  } else if (url.indexOf(llab.rootURL) == -1 && url.indexOf("..") == -1) {
      url = `${llab.rootURL}${url[0] == "/" ? '' : '/'}${url}`;
  }
  url += (url.indexOf('?') !== -1 ? '&' : '?') + llab.QS.stringify(query);

  return url;
}

llab.renderResource = (resource, parent) => {
  const item = $(`<li></li>`); // class="${resource.type}"

  if (resource.url) {
    item.append(`<a href=${llab.fullResourceURL(resource.url)}>${resource.contents}</a>`);
  } else {
    item.append(resource.contents);
  }

  parent.append(item);
};

llab.renderInfo = function (contents, type, parent) {
  var infoDOM = $(document.createElement("div")).attr({ class: type });
  var list = $(document.createElement("ol")).appendTo(infoDOM);
  list.append(
    contents.map(function (item) {
      return $(document.createElement("li")).append(item.contents);
    })
  );
  parent.append(infoDOM);
};

/* Returns the indent class of this string,
 * depending on how far it has been indented
 * on the line. */
llab.indentLevel = function (s) {
  const len = s.length;
  let count = 0;
  for (let i = 0; i < len; i++) {
    if (s[i] == " ") {
      count++;
    } else if (s[i] == "\t") {
      count += 4;
    } else {
      break;
    }
  }
  return Math.floor(count / 4);
};

llab.displayTopic = function() {
  if (!llab.isTopicFile()) { return; }

  llab.file = llab.getQueryParameter("topic");

  if (llab.file) {
    fetch(llab.topics_path + llab.file)
      .then(response => response.text())
      .then(data => llab.renderFull(data))
      .catch(llab.handleError);
  } else {
    document.getElementsByTagName(llab.selectors.FULL).item(0).innerHTML =
      "Please specify a file in the URL.";
  }
};

$(document).ready(() => llab.displayTopic());
