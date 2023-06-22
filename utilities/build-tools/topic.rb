require_relative 'bjc_helpers'

class BJCTopic
  attr_reader :file_path, :file_name, :title, :language

  # TODO: Is it useful to know the course a topic came with?
  def initialize(path, course: nil, language: 'en')
    @file_path = path
  end

  def file_contents
    @file_contents ||= File.read(@file_path)
  end

  # This should return some hash-type structure
  # look at the code in llab
  # TODO: this could arguably be its own class.
  # Is this all that's needed (recursively) ?
  # { title, type, content, number, pages: [] }
  def parse
    parse_topic_file(file_contents)
  end

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

  # TODO: write this in ruby
  def strip_comments(s)
    s
  end

  # TODO: comment...
  def parse_topic_file(data)
    # TEMPORARY HACK
    llab = {}
    llab[:topic_keywords] = {}
    llab[:topic_keywords][:resources] = %w[quiz assignment resource
                                           forum video extresource
                                           reading group]
    llab[:topic_keywords][:headings] = %w[h1 h2 h3 h4 h5 h6 heading]
    llab[:topic_keywords][:info] = %w[big-idea learning-goal]

    llab[:file] = llab[:topic]

    data = data.gsub(/(\r)/, '') # normalize line endings
    lines = data.split("\n")
    # TODO: If we support multiple topics per file -- this should have a URL field and maybe this should just be contents?
    topics = { topics: [] }
    topic_model = nil
    section = nil
    raw = false
    i = 0
    while i < lines.length
      # TODO: remove text after // in a line.
      line = strip_comments(lines[i]).strip

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
          elsif is_heading(line)
            heading_type = get_keyword(line, llab[:topic_keywords][:headings])
            if section[:contents].length > 0
              section = { title: '', contents: [], type: 'section' }
              topic_model[:contents].push(section)
            end
            section[:title] = get_content(line)['text']
            section[:headingType] = heading_type
          elsif line[0] == '}'
            # shouldn't matter
          elsif is_info(line)
            tag = get_keyword(line, llab[:topic_keywords][:info])
            indent = indent_level(line)
            content = get_content(line)['text'] # ?
            # TODO: do we really need indentation now?
            # if so, I think it should be added to the type
            # and only if indentation levels != nested levels.
            item = { type: tag, contents: content, indent: indent }
            section[:contents].push(item)
          elsif is_resource(line) || true
            # FIXME: dumb way to handle lines without a known tag
            # Shouldn't this just be an else case?
            tag = get_keyword(line, llab[:topic_keywords][:resources])
            indent = indent_level(line)
            content = get_content(line)
            item = { type: tag, indent: indent, contents: content[:text],
                     url: content[:url] }
            section[:contents].push(item)
          end
        elsif line.length == 0
          raw = false
        end

        if raw
          raw_html = []
          text = get_content(line)['text'] # in case they start the raw html on the same line
          raw_html.push(text) if text

          # FIXME: -- if nested topics are good check for {
          while lines[i + 1].length >= 1 && lines[i + 1][0] != '}' && !is_keyword(lines[i + 1])
            i += 1
            line = lines[i]
            raw_html.push(line)
          end

          section[:contents].push({ type: 'raw-html', contents: raw_html })
          raw = false
        end
      end

      i += 1
    end

    llab[:topics] = topics

    topics
  end

  # TODO
  def indent_level(s)
    0
  end

  def matches_array(line, array)
    matches = array.map { |s| line.match(s) }
    matches.any? { |m| !m.nil? }
  end

  def get_keyword(line, array)
    matches = array.map { |s| line.match(s) }
    index = matches.index { |m| !m.nil? }
    array[index] unless index.nil?
  end

  def get_content(line)
    sep_idx = line.index(':')
    content = line.slice(sep_idx + 1)
    # TODO, we could probably strengthen this with a lastIndexOf() call.
    sliced = content.split(/\[|\]/)
    { text: sliced[0], url: sliced[1] }
  end

  def is_resource(line)
    matches_array(line, %w[quiz assignment resource
      forum video extresource
      reading group])
  end

  def is_info(line)
    matches_array(line, %w[big-idea learning-goal])
  end

  def is_heading(line)
    matches_array(line, %w[h1 h2 h3 h4 h5 h6 heading])
  end

  def is_keyword(line)
    is_resource(line) || is_info(line) || is_heading(line)
  end
  ##### END CHAT GPT CODE
end
