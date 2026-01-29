# frozen_string_literal: true

require_relative 'bjc_helpers'

class BJCTopic
  attr_reader :file_path, :course, :title, :language

  RESOURCES_KEYWORDS = %w[quiz assignment resource forum video extresource reading group]
  HEADINGS_KEYWORDS = %w[h1 h2 h3 h4 h5 h6 heading]
  INFO_KEYWORDS = %w[big-idea learning-goal]

  def initialize(topic_file_path, course: nil, language: 'en')
    @file_path = topic_file_path
    @course = course

    if !File.exist?(@file_path)
      raise "Error: No file found at #{file_path}"
    end
  end

  def file_contents
    @file_contents ||= File.read(@file_path)
  end

  # Just the part of the file path relative to the topic/ directory
  # This is used in the URL for the topic, ?topic=llab_reference_path
  def llab_reference_path
    # Strips everything before the topic/ directory
    @file_path.match(/\/topic\/(.*\.topic)/)[1]
  end

  # This should return some hash-type structure
  # look at the code in llab
  # TODO: this could arguably be its own class.
  # Is this all that's needed (recursively) ?
  # { title, type, content, number, pages: [] }
  def parse
    parsed_topic_object
  end

  def unit_number; end

  # TODO: This is what will make the organization a bit tricky...
  # FOR most BJC4NYC --> /bjc-r/cur/programming/{UNIT}/
  # FOR Sparks ..
  # For Teacher guides?
  def base_content_folder; end

  # Just the names of the lab sections
  def section_headings; end


  # A way to process each page for vocab, self-checks, etc.
  # TODO: Do we need a 'Page()' class?
  def iterate_curriculum_pages(&block)
    # This should yield the data needed to parse each curriculum page.
    all_pages_without_summaries.each do |page|
      binding.irb
      block.call(path_to_page, unit, lab, page_number)
    end
  end

  # This should explicitly exclude the 3 compiled HTML pages.
  def all_pages_without_summaries
    all_pages(include_summaries: false)
  end

  # TODO: pass more than just the URL
  def all_pages(include_summaries=false)
    parsed_topic_object[:topics].each_with_index.map do |topic, topic_index|
      topic[:content].each_with_index.map do |entry, entry_index|
        next if is_summary_section?(entry) || (!entry[:url].nil? && is_summary_page?(entry))

        if entry[:type] == 'section'
          extract_pages_in_section(entry, include_summaries: include_summaries)
        elsif RESOURCES_KEYWORDS.include?(entry[:type])
          entry[:url]
        end
      end.flatten
    end.flatten
  end

  # Return all valid links to HTML pages as an array (no nesting)
  def all_pages_with_summaries
   all_pages(include_summaries: true)
  end

  def to_h = parse

  def to_json(*_args)
    to_h.to_json
  end

  # Build a compliant llab URL that would show the full page w/ navigation
  # Adds a topic and course reference to the URL
  # TODO: This isn't the right abstraction...
  # This should maybe be called automatically by the all_pages functions?
  def augmented_page_paths_in_topic
    all_pages_without_summaries.map do |path|
      "#{path}?topic=#{llab_reference_path}&course=#{course}"
    end
  end

  # TODO: Cleanup when we move to a topic parser class.
  def parsed_topic_object
    @parsed_topic_object ||= parse_topic_file(file_contents)
  end

  ###########################
  #### CODE BELOW THIS LINE SHOULD BE REWRITTEN!!!
  ### This was JavaScript (mostly) auto-translated by ChatGPT
  ### TODO: I think this should be a TopicParser class
  ### It can more easily maintain state, like @lineNumber and @currentSection
  #########
  def parse_topic_file(data)
    data = data.gsub(/(\r)/, '') # normalize line endings
    lines = data.split("\n")
    # TODO: Reduce unnecessary nesting!
    topics = { topics: [] }
    topic_model = nil
    section = nil
    i = 0

    while i < lines.length do
      line = strip_comments(lines[i])

      if line.length == 0 || line[0] == '}'
      elsif line.match?(/^title:/)
        topics[:title] = line.slice(6, line.length)
      # TODO: This syntax is not used. Reserve for the future.
      # elsif line.match?(/^topic:/)
      #   topic_model[:title] = line.slice(6..)
      elsif line.match?(/^raw-html:/)
        text = get_content(line)[:text] # in case they start the raw html on the same line
        raw_html = text
        next_line = strip_comments(lines[i + 1])
        while next_line.length >= 1 && next_line[0] != '}' && !is_keyword?(next_line) do
          i += 1
          next_line = strip_comments(lines[i + 1])
          line = strip_comments(lines[i]) # TODO: Is this right? Probably?
          raw_html += line
        end
        section[:content].push({ type: 'raw-html', content: raw_html })
      # TODO: Stuff before this line shouldn't be rendered, but stored.
      elsif line[0] == '{'
        topic_model = { type: 'topic', url: @file_path, content: [] }
        topics[:topics].push(topic_model)
        section = { title: '', content: [], type: 'section' }
        topic_model[:content].push(section)
      elsif is_heading?(line)
        # Start a new section in the topic moduel
        heading_type = get_keyword(line, HEADINGS_KEYWORDS)
        if section[:content].length > 0
          section = { title: '', content: [], type: 'section' }
          topic_model[:content].push(section)
        end
        section[:headingType] = heading_type
        section[:title] = get_content(line)[:text]
      else # is_info? || is_resource? || unknown
        item = parse_line(line)
        section[:content].push(item)
      end
      i += 1
    end

    topics
  end
  ##### END CHAT GPT CODE

  ## Consider fleshing this out...
  ### A resource line is:
  ### "    resource: Title Text [url]"
  ### Should return:
  ### { type: resource, content: 'Title Text', url: url, indent: 1 }
  def parse_line(line)
    indent = indent_level(line.match(/^(\s*)/)[1] || '')
    line = line.gsub(/^\s*/, '')
    resource_matcher = line.match(/^([\w\-]+):\s/)
    if !resource_matcher
      # puts "Could not find any resource for line: #{line}"
      resource = 'text'
    else
      # TODO: Warn if an unknown resource is present?
      resource = resource_matcher[1]
    end
    line = line.gsub(/^([\w\-]+):\s/, '')
    content_url = extract_content_url(line)
    # if !content_url[:url]
    #   puts "WARNING: No URL found for line: #{line}"
    # end
    { type: resource, indent: indent, **content_url }
  end

  # Return a hash of { content: '', url: ''} from a line
  # Splits: "Text [url]" where URL is any valid URL or file path
  # URL may be missing
  def extract_content_url(partial_line)
    if partial_line.index('[').nil?
      return { content: partial_line.strip, url: nil }
    end
    content = partial_line.match(/^(.*)\s*\[/)
    url = partial_line.match(/\[(.*?)\]/)

    # extract the first group from the regexp matchers.
    content = content[1].strip if content
    url = url[1].strip if url

    { content: content, url: url }
  end

  #not fully function - vic added
  def generate_topic_file(json_hash)
    topic_file = "title: #{json_hash[:title]}\n"

    json_hash[:content].each do |section|
      topic_file += "\nheading: #{section[:title]}\n"
      section[:content].each do |item|
        if item[:type] == "raw-html"
          topic_file += "\t#{item[:content]}\n"
        else
          topic_file += "\tresource: #{item[:content]} [#{item[:url]}]\n"
        end
      end
    end

    File.open(topic_file, 'w') {|f| f.write(topic_file) }
  end

  private
  # TODO: Many methods above should be made private

  # Determines if a section is a "summary" of content based on the heading.
  SUMMARY_SECTION_TITLES = [
    /Unit\s*\d+\s*Review/,
    /Unidad\s*\d+\s*Revision/,
  ]
  def is_summary_section?(section)
    SUMMARY_SECTION_TITLES.any? { |re| section[:title].match?(re) }
  end

  SUMMARY_URLS = [
    /\/summaries\//, # all pages in a summaries directory
    /unit-.*-vocab.*\.html/,
    /unit-.*-self-check.*\.html/,
    /unit-.*-exam-reference.*\.html/,
  ]
  def is_summary_page?(item)
    SUMMARY_URLS.any? { |re| item[:url].match?(re) }
  end

  # Takes in one "section" of the parsed topic object
  # Returns an array of all the paths in that section
  # If include_summaries = false, then known "summary" URLs are exlcuded
  # this means quizzes, vocab, ap exam pages.
  def extract_pages_in_section(parsed_section, include_summaries=false)
    parsed_section[:content].each_with_index.map do |item, item_index|
      if !include_summaries && is_summary_page?(item)
        nil
      elsif RESOURCES_KEYWORDS.include?(item[:type])
        item[:url]
      elsif item[:type] == 'section'
        extract_pages_in_section(item, include_summaries: include_summaries)
      else
        nil
      end
    end.flatten.compact
  end

  ### Parsing Helpers -- These should be moved at some point...

  # remove the text after // only if // is at the beginning of a line, or preceded by whitespace.
  # Input: "// hello" Outpit" ""
  # Input "resource: Text [http://test]" Output: "resource: Text [http://test]"
  # Input "resource: Text [http://test] // Comment" Output: "resource: Text [http://test]"
  def strip_comments(s)
    return '' unless s

    s.gsub(/(\s|^)\/\/.*/, '').strip
  end

  # Each 'line' in a topic file can be 'indented' by tabs or spaces, which affects
  # its visual position when rendered.
  # NOTE: a the difference between 2 or 4 spaces as one "indent level" was never defined.
  def indent_level(s, tab_size = 4)
    s.count("\t") + s.count(' ')/tab_size
  end

  def get_keyword(line, array)
    matches = array.map { |s| line.match(s) }
    index = matches.index { |m| !m.nil? }
    array[index] unless index.nil?
  end

  # Split "resource: Text [url]" in the right parts.
  # TODO: figure out of this is necessary or to reuse parse_line
  def get_content(line)
    return { text: '', url: '' } unless line
    content = line.split(':')
    return { text: '', url: '' } unless content.length > 1
    sliced = content[1].split(/\[|\]/)
    text = sliced.length > 0 ? sliced[0].strip : ''
    url = sliced.length > 1 ? sliced[1].strip : ''
    { text: text, url: url }
  end

  def is_resource?(line)
    RESOURCES_KEYWORDS.any? { |word| line.include?(word) }
  end

  def is_info?(line)
    INFO_KEYWORDS.any? { |word| line.include?(word) }
  end

  def is_heading?(line)
    HEADINGS_KEYWORDS.any? { |word| line.include?(word) }
  end

  def is_keyword?(line)
    is_resource?(line) || is_info?(line) || is_heading?(line)
  end
end
