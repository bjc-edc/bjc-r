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
llab.topicKeywords.resources = ["quiz", "assignment", "resource",
                                "forum", "video", "extresource",
                                "reading", "group"];
llab.topicKeywords.headings = ["h1", "h2", "h3", "h4", "h5", "h6", "heading"];
llab.topicKeywords.info = ["big-idea", "learning-goal"]

/* TODO: comment...

*/
llab.parseTopicFile = function parser(data) {

    llab.file = llab.topic;

    data = data.replace(/(\r)/gm,""); // normalize line endings
    var lines = data.split("\n");
    // TODO: If we support multiple topics per file -- this should have a URL field and maybe this should just be contents?
    var topics = { topics: [] };
    var line, topic_model, item, list, text, content, section, indent;
    var in_topic = false, raw = false;
    var url = document.URL;
    for (var i = 0; i < lines.length; i++) {
        line = llab.stripComments(lines[i]);
        line = line.trim();
        if (line.length && !raw) {
            if (line.match(/^title:/)) {
                topics.title = line.slice(6);
            } else if (line.match(/^topic:/)) {
                topic_model.title = line.slice(6);
            } else if (line.match(/^raw-html/)) {
                raw = true;
            } else if (line[0] == "{") {
                topic_model = { type: 'topic', url: llab.topic, contents: [] };
                topics.topics.push(topic_model);
                section = { title: '', contents: [], type: 'section' };
                topic_model.contents.push(section);
            } else if (llab.isHeading(line)) {
                headingType = llab.getKeyword(line, llab.topicKeywords.headings);
                if (section.contents.length > 0) {
                    section = { title: '', contents: [], type: 'section' };
                    topic_model.contents.push(section);
                }
                section.title = llab.getContent(line)['text'];
                section.headingType = headingType;
            } else if (line[0] == "}") {
                // shouldn't matter
            } else if (llab.isInfo(line)) {
                tag = llab.getKeyword(line, llab.topicKeywords.info);
                indent = llab.indentLevel(line);
                content = llab.getContent(line)['text']; // ?
                // TODO: do we really need indentation now?
                // if so, I think it should be added to the type
                // and only if indentation levels != nested levels.
                item = { type: tag, contents: content, indent: indent };
                section.contents.push(item);
            } else if (llab.isResource(line) || true) {
                // FIXME: dumb way to handle lines without a known tag
                // Shouldn't this just be an else case?
                tag = llab.getKeyword(line, llab.topicKeywords.resources);
                indent = llab.indentLevel(line);
                content = llab.getContent(line);
                item = { type: tag, indent: indent, contents: content.text,
                         url: content.url };
                section.contents.push(item);
            }
        } else if (line.length == 0) {
            raw = false;
        }
        if (raw) {
            var raw_html = [];
            text = llab.getContent(line)['text']; // in case they start the raw html on the same line
            if (text) {
                raw_html.push(text)
            }
            // FIXME -- if nested topics are good check for {
            while (lines[i+1].length >= 1 && lines[i+1].slice(0) != "}" && !llab.isKeyword(lines[i+1])) {
                i++;
                line = lines[i];
                raw_html.push(line);
            }
            // FIXME -- shouldn't the type have a - ?
            section.contents.push({ type: 'raw_html', contents: raw_html });
            raw = false;
        }
    }
    llab.topics = topics;

    return topics;
}

// Shorter method alias (used in node API)
llab.parse = llab.parseTopicFile;

/* TODO: Comment needed.
*/
llab.matchesArray = function(line, A) {
    var matches = A.map(function(s) {return line.match(s) });
    return llab.any(matches.map(function(m) {return m != null }));
}

// TODO: comment...
llab.getKeyword = function(line, A) {
    var matches = A.map(function(s) {return line.match(s) });
    return A[llab.which(matches.map(function(m) {return m != null }))];
}

llab.getContent = function(line) {
    var sepIdx = line.indexOf(':');
    var content = line.slice(sepIdx + 1);
    // TODO, we could probably strengthen this with a lastIndexOf() call.
    var sliced = content.split(/\[|\]/);
    return { text: sliced[0], url: sliced[1] };
}

llab.isResource = function(line) {
    return llab.matchesArray(line, llab.topicKeywords.resources);
}

llab.isInfo = function(line) {
    return llab.matchesArray(line, llab.topicKeywords.info);
}

llab.isHeading = function(line) {
    return llab.matchesArray(line, llab.topicKeywords.headings);
}

llab.isKeyword = function(line) {
    return llab.isResource(line) || llab.isInfo(line) || llab.isHeading(line);
}

llab.renderFull = function renderAndParse(data) {
    var content = llab.parseTopicFile(data);
    llab.renderTopicModel(content);
}

// TODO: this data format is messy.
llab.renderTopicModel = function rederer(topics) {
    llab.renderTitle(topics.title);
    topics.topics.forEach(function(topic) {
        llab.renderTopic(topic);
    });
}

llab.renderTitle = function(title) {
    var navbar, titleText;
    navbar = $(llab.selectors.NAVTITLE)
    $(llab.selectors.MOBILETITLE).html(title);
    navbar.html(title);
    titleText = navbar.text(); // Normalize Window Title
    titleText = titleText.replace('snap', 'Snap!');
    document.title = titleText;
};

llab.renderCourseLink = function(course) {
    if (course.indexOf("://") === -1) {
        course = llab.courses_path + course;
    }
    $('.nav.navbar-nav.navbar-right').prepend($(document.createElement("a")).attr(
        {"class":"course_link", "href": course }
    ).html(llab.strings.goMain));
};

llab.renderTopic = function(topic_model) {
    var FULL = llab.selectors.FULL,
        params = llab.getURLParameters(),
        course = params.course;
    var topicDOM = $("<div>").attr({ 'class': 'topic' });

    // FIXME -- css eventually, should be topic-header
    topicDOM.append($(document.createElement("div")).attr(
        {'class': 'topic_header'}).append(topic_model.title));

    // FIXME -- forEach
    var current;
    for (var i = 0; i < topic_model.contents.length; i++) {
        current = topic_model.contents[i];
        if (current.type == "section") {
            llab.renderSection(current, topicDOM);
        }
    }

    // Make sure to only update view once things are rendered.
    $(FULL).append(topicDOM);
    llab.renderCourseLink(course);
}

llab.renderSection = function(section, parent) {
    var sectionDOM = $("<section>"),
        params = llab.getURLParameters();
    if (section.title) {
        var tag = section.headingType == "heading" ? 'h3' : section.headingType;
        sectionDOM.append($('<' + tag + '>').append(section.title));
    }

    // FIXME -- for each loop!
    var current;
    for (var i = 0; i < section.contents.length; i++) {
        current = section.contents[i];
        isHidden = params.hasOwnProperty('no' + current.type);

        // Skip Rendering Hidden Resources.
        if (isHidden) {
            continue;
        }

        if (current.type && llab.isResource(current.type)) {
            llab.renderResource(current, sectionDOM);
        } else if (current.type && llab.isInfo(current.type)) {
            var infoSection = [current];
            while (i < section.contents.length - 1 && section.contents[i].type == current.type) {
                i++;
                infoSection.push(section.contents[i]);
            }
            llab.renderInfo(infoSection, current.type, sectionDOM);
        } else if (current.type == "section") {
            llab.renderSection(current, sectionDOM);
        } else { // also handles: current.type == "raw_html"
            sectionDOM.append(current.contents);
        }
    }

    sectionDOM.appendTo(parent);
}

llab.renderResource = function(resource, parent) {
    var item = $("<div>").attr({ 'class': resource.type });
    var new_contents = resource.contents + "\n";
    if (resource.url) {
        var slash = resource.url[0] == "/" ? '' : '/';
        item.append($(document.createElement("a")).attr({'href': resource.url}).append(new_contents));
    } else {
        item.append(new_contents);
    }
    parent.append(item);
}

llab.renderInfo = function(contents, type, parent) {
    var infoDOM =  $(document.createElement("div")).attr({'class': type});
    var list = $(document.createElement("ul")).appendTo(infoDOM);
    list.append(contents.map(function(item) {return $(document.createElement("li")).append(item.contents) }));
    parent.append(infoDOM);
}

/* Returns the indent class of this string,
 * depending on how far it has been indented
 * on the line. */
llab.indentLevel = function(s) {
    var len = s.length;
    var count = 0;
    for (var i = 0; i < len; i++) {
        if (s[i] == " ") {
            count++;
        } else if (s[i] == "\t") {
            count += 4;
        } else {
            break;
        }
    }
    return Math.floor(count/4);
}

// TODO: Separate out the llab.file stuff
// TODO: save to an read from local storage.

llab.displayTopic = function() {
    llab.file = llab.getQueryParameter("topic");

    if (llab.file) {
        $.ajax({
            url : llab.topics_path + llab.file,
            type : "GET",
            dataType : "text",
            cache : true,
            success : llab.renderFull // FIXME -- rename
        });
    } else {
        // FIXME -- put that text somewhere
        document.getElementsByTagName(llab.selectors.FULL).item(0).innerHTML = "Please specify a file in the URL.";
    }
}

// Make a call to build a topic page.
// Be sure that content is set only on pages that it should be
$(document).ready(function() {
    var url = document.URL,
        isTopicFile = (url.indexOf("topic.html") !== -1 ||
            // FIXME -- this may be broken.
            url.indexOf("empty-topic-page.html") !== -1);

    if (isTopicFile) {
        llab.displayTopic();
    }
});


// TODO: Export nodeJS stuff here.

/*
  Error checking (do this after building page, so it won't slow it down?)

  Check the link targets if present - if they aren't there (give a 404),
  put a "broken" class on the link to render in red or something

  Maybe be smart about a mistyped youtube target?  dunno.

  Be forgiving:

  if there is no closing brace, put one there when another one opens or the page ends

  No error checking:

  No error checking on class name before the colon - it could be misspelled

  if no colon at all, just put no class on the div

*/
