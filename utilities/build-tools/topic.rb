require_relative 'bjc_helpers'

class BJCTopic
  attr_reader :file_path, :file_name, :title, :language

  # TODO: Is it useful to know the course a topic came with?
  def initialize(path, course: nil, language: 'en'); end

  # This should return some hash-type structure
  # look at the code in llab
  # TODO: this could arguably be its own class.
  # Is this all that's needed (recursively) ?
  # { title, type, content, number, pages: [] }
  def parse; end

  def unit_number; end

  # TODO: This is what will make the organization a bit tricky...
  # FOR most BJC4NYC --> /bjc-r/cur/programming/{UNIT}/
  # FOR Sparks ..
  # For Teacher guides?
  def base_content_folder; end

  # Just the names of the lab sections
  def section_headings; end

  # This should explicitly exclude the 3 compiled HTML pages.
  def all_pages; end

  def all_pages_with_summaries; end

  def to_h; end

  def to_json(*_args)
    to_h.to_json
  end

  # TODO: What other things might we do with a topic file?
  # Do we need to render the HTML to auit accessibility, etc?
  # Can we return just the HTML fragments?

  ###########################
  #### CODE BELOW THIS LINE SHOULD BE REWRITTEN!!!
  ### This was JavaScript (mostly) auto-translated by ChatGPT
  #########
  llab = {}
  llab[:topic_keywords] = {}
  llab[:topic_keywords][:resources] = %w[quiz assignment resource
                                         forum video extresource
                                         reading group]
  llab[:topic_keywords][:headings] = %w[h1 h2 h3 h4 h5 h6 heading]
  llab[:topic_keywords][:info] = %w[big-idea learning-goal]

  # TODO: comment...
  def parse_topic_file(data)
    llab[:file] = llab[:topic]

    data = data.gsub(/(\r)/, '') # normalize line endings
    lines = data.split("\n")
    # TODO: If we support multiple topics per file -- this should have a URL field and maybe this should just be contents?
    topics = { topics: [] }
    topic_model = nil
    section = nil
    raw = false
    # url = document.URL

    i = 0
    while i < lines.length
      # TODO: remove text after // in a line.
      # line = llab.strip_comments(lines[i])
      line = line.strip

      unless raw
        if line.length.positive?
          if line.match?(/^title:/)
            topics[:title] = line.slice(6..)
          elsif line.match?(/^topic:/)
            topic_model[:title] = line.slice(6..)
          elsif line.match?(/^raw-html/)
            raw = true
          elsif line[0] == '{'
            topic_model = { type: 'topic', url: llab[:topic], contents: [] }
            topics[:topics].push(topic_model)
            section = { title: '', contents: [], type: 'section' }
            topic_model[:contents].push(section)
          elsif llab.is_heading(line)
            heading_type = llab.get_keyword(line, llab[:topic_keywords][:headings])
            if section[:contents].length > 0
              section = { title: '', contents: [], type: 'section' }
              topic_model[:contents].push(section)
            end
            section[:title] = llab.get_content(line)['text']
            section[:headingType] = heading_type
          elsif line[0] == '}'
            # shouldn't matter
          elsif llab.is_info(line)
            tag = llab.get_keyword(line, llab[:topic_keywords][:info])
            indent = llab.indent_level(line)
            content = llab.get_content(line)['text'] # ?
            # TODO: do we really need indentation now?
            # if so, I think it should be added to the type
            # and only if indentation levels != nested levels.
            item = { type: tag, contents: content, indent: }
            section[:contents].push(item)
          elsif llab.is_resource(line) || true
            # FIXME: dumb way to handle lines without a known tag
            # Shouldn't this just be an else case?
            tag = llab.get_keyword(line, llab[:topic_keywords][:resources])
            indent = llab.indent_level(line)
            content = llab.get_content(line)
            item = { type: tag, indent:, contents: content[:text],
                     url: content[:url] }
            section[:contents].push(item)
          end
        elsif line.length == 0
          raw = false
        end

        if raw
          raw_html = []
          text = llab.get_content(line)['text'] # in case they start the raw html on the same line
          raw_html.push(text) if text

          # FIXME: -- if nested topics are good check for {
          while lines[i + 1].length >= 1 && lines[i + 1][0] != '}' && !llab.is_keyword(lines[i + 1])
            i += 1
            line = lines[i]
            raw_html.push(line)
          end

          # FIXME: -- shouldn't the type have a - ?
          section[:contents].push({ type: 'raw_html', contents: raw_html })
          raw = false
        end
      end

      i += 1
    end

    llab[:topics] = topics

    topics
  end

  def matches_array(line, array)
    matches = array.map { |s| line.match(s) }
    matches.any? { |m| !m.nil? }
  end

  # TODO: comment...
  def get_keyword(line, array)
    matches = array.map { |s| line.match(s) }
    array[which(matches.map { |m| !m.nil? })]
  end

  def get_content(line)
    sep_idx = line.index(':')
    content = line.slice(sep_idx + 1)
    # TODO, we could probably strengthen this with a lastIndexOf() call.
    sliced = content.split(/\[|\]/)
    { text: sliced[0], url: sliced[1] }
  end

  def is_resource(line)
    matches_array(line, llab.topic_keywords.resources)
  end

  def is_info(line)
    matches_array(line, llab.topic_keywords.info)
  end

  def is_heading(line)
    matches_array(line, llab.topic_keywords.headings)
  end

  def is_keyword(line)
    is_resource(line) || is_info(line) || is_heading(line)
  end
  ##### END CHAT GPT CODE
end
