# frozen_string_literal: true

require_relative 'bjc_helpers'

class BJCTopic
  attr_reader :file_path, :course, :language

  RESOURCES_KEYWORDS = %w[quiz assignment resource forum video extresource reading group].freeze
  HEADINGS_KEYWORDS = %w[h1 h2 h3 h4 h5 h6 heading].freeze
  INFO_KEYWORDS = %w[big-idea learning-goal].freeze

  # llab matches these keywords loosely: a line is a resource/info/heading line
  # if it contains the word anywhere, with or without a colon.
  RESOURCE_LINE = Regexp.union(RESOURCES_KEYWORDS)
  HEADING_LINE = Regexp.union(HEADINGS_KEYWORDS)
  INFO_LINE = Regexp.union(INFO_KEYWORDS)

  # The heading that introduces the generated summary section of a topic file.
  # Both the parser and the build tools that rewrite topic files need it.
  SUMMARY_HEADINGS = [
    /Unit\s*\d+\s*Review/,
    /Unidad\s*\d+\s*Revision/
  ].freeze

  def self.summary_heading?(text)
    SUMMARY_HEADINGS.any? { |pattern| text.to_s.match?(pattern) }
  end

  def initialize(topic_file_path, course: nil, language: 'en')
    @file_path = topic_file_path
    @course = course
    @unit_data = nil
    @language = language

    raise "Error: No file found at #{@file_path}" unless File.exist?(@file_path)
  end

  def file_contents
    @file_contents ||= File.read(@file_path)
  end

  # The topic's title, e.g. " Unit 1: Introduction to Programming".
  def title
    parsed_topic_object[:title]
  end

  # Just the part of the file path relative to the topic/ directory
  # This is used in the URL for the topic, ?topic=llab_reference_path
  def llab_reference_path
    # Strips everything before the topic/ directory
    @file_path.match(%r{(?:\A|/)topic/(.*\.topic)})[1]
  end

  # BJC: Assume every topic file has one unit.
  # However, the title belongs to the parent topic content.
  def unit_data
    @unit_data ||= parsed_topic_object[:topics].first
  end

  # This should return some hash-type structure
  # look at the code in llab
  # TODO: this could arguably be its own class.
  # Is this all that's needed (recursively) ?
  # { title, type, content, number, pages: [] }
  def parse
    parsed_topic_object
  end

  # FOR most BJC4NYC --> /bjc-r/cur/programming/{UNIT}/
  # FOR Sparks ..
  # For Teacher guides?
  # Find the longest common path prefix for all URLs within a topic.
  # This is the base content folder for the topic.
  # It should be the first part of the URL, like /bjc-r/cur/programming/
  # or /sparks/student-pages/
  def base_content_folder
    @base_content_folder ||= begin
      paths = all_pages.map { |page| File.dirname(page[:url]) }
      longest_common_prefix(paths)
    end
  end

  # Returns the longest common prefix of an array of paths.
  # For example, ['/a/b/c', '/a/b/d'] returns '/a/b'.
  # The comparison is per folder, not per character, so ['/a/L1', '/a/L2']
  # returns '/a' rather than '/a/L'.
  def longest_common_prefix(paths)
    return '' if paths.empty?

    segments = paths.map { |path| path.split('/') }
    segments.reduce do |common, other|
      common.take_while.with_index { |segment, index| segment == other[index] }
    end.join('/')
  end

  # A way to process each page for vocab, self-checks, etc.
  # This yields the data needed to parse each curriculum page:
  # unit (same for all pages), unit path (first subfolder in the path),
  # lab (the lab name, like "Lab 1"), lab/page numbers (1, 2, 3, etc.), path
  # Summary sections/pages and entries without a URL (text, raw-html)
  # are skipped, so only real curriculum pages are yielded.
  # TODO: Do we need a 'Page()' class?
  def iterate_curriculum_pages
    labs = unit_data[:content].reject { |section| summary_section?(section) }
                              .map { |section| [section, section[:content].select { |entry| curriculum_page?(entry) }] }
                              .reject { |_section, pages| pages.empty? }
    labs.each_with_index do |(section, pages), lab_index|
      pages.each_with_index do |entry, page_index|
        yield({
          unit: unit_number,
          unit_path: base_content_folder,
          course: @course,
          lab: section[:title],
          lab_number: lab_index + 1,
          page_number: page_index + 1,
          path: entry[:url]
        })
      end
    end
  end

  # A page entry that is part of the curriculum itself: a resource with a
  # URL that isn't one of the generated summary pages.
  def curriculum_page?(entry)
    RESOURCES_KEYWORDS.include?(entry[:type]) && !entry[:url].nil? && !summary_page?(entry)
  end

  # This should explicitly exclude the 3 compiled HTML pages.
  def all_pages_without_summaries
    all_pages(include_summaries: false)
  end

  def all_pages(include_summaries: false)
    parsed_topic_object[:topics].flat_map do |topic|
      topic[:content].flat_map do |entry|
        next if !include_summaries && (summary_section?(entry) || summary_page?(entry))

        if entry[:type] == 'section'
          extract_pages_in_section(entry, include_summaries: include_summaries)
        elsif RESOURCES_KEYWORDS.include?(entry[:type])
          entry
        end
      end
    end.compact
  end

  # Build compliant llab URLs that show each page with its navigation, by adding
  # a topic and course reference. Used by the accessibility specs to enumerate
  # every page of a course the way a student would load it, which is why they
  # ask for the generated summary pages too.
  # TODO: This isn't the right abstraction...
  # This should maybe be called automatically by the all_pages functions?
  def augmented_page_paths_in_topic(include_summaries: false)
    all_pages(include_summaries: include_summaries).filter_map do |page|
      # Entries like `video: Take-home midterm Wednesday!` have no link.
      next if page[:url].to_s.empty?

      "#{page[:url]}?topic=#{llab_reference_path}&course=#{course}"
    end
  end

  def to_h
    parse
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

    while i < lines.length
      line = strip_comments(lines[i])

      if line.empty? || line[0] == '}'
        # Blank lines and the closing brace of a topic carry no content.
      elsif line.match?(/^title:/)
        topics[:title] = line.slice(6, line.length)
      # TODO: This syntax is not used. Reserve for the future.
      # elsif line.match?(/^topic:/)
      #   topic_model[:title] = line.slice(6..)
      elsif line.match?(/^raw-html:/)
        text = get_content(line)[:text] # in case they start the raw html on the same line
        raw_html = text
        next_line = strip_comments(lines[i + 1])
        while next_line.length >= 1 && next_line[0] != '}' && !keyword_line?(next_line)
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
      elsif heading_line?(line)
        # Start a new section in the topic moduel
        heading_type = get_keyword(line, HEADINGS_KEYWORDS)
        if section[:content].length.positive?
          section = { title: '', content: [], type: 'section' }
          topic_model[:content].push(section)
        end
        section[:headingType] = heading_type
        section[:title] = get_content(line)[:text]
      else # info_line? || resource_line? || unknown
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
  # NOTE: the space after the colon is optional. llab renders "quiz:Title [url]"
  # the same as "quiz: Title [url]", and topic files in the wild use both.
  LINE_TYPE = /^([\w-]+):[ \t]*/
  def parse_line(line)
    indent = indent_level(line.match(/^(\s*)/)[1] || '')
    line = line.gsub(/^\s*/, '')
    resource_matcher = line.match(LINE_TYPE)
    # TODO: Warn if an unknown resource is present?
    resource = resource_matcher ? resource_matcher[1] : 'text'
    { type: resource, indent: indent, **extract_content_url(line.gsub(LINE_TYPE, '')) }
  end

  # Return a hash of { content: '', url: ''} from a line
  # Splits: "Text [url]" where URL is any valid URL or file path
  # URL may be missing
  def extract_content_url(partial_line)
    return { content: partial_line.strip, url: nil } if partial_line.index('[').nil?

    content = partial_line.match(/^(.*)\s*\[/)
    url = partial_line.match(/\[(.*?)\]/)

    # extract the first group from the regexp matchers.
    content = content[1].strip if content
    url = url[1].strip if url

    { content: content, url: url }
  end

  # The unit number from the title, e.g. "1" for both
  # "Unit 1: Introduction" and "Unidad 1: Introducción a la programación".
  # Assumes there is only 1 primary section in the topic file.
  def unit_number
    title.to_s[/\d+/]
  end

  # Pages the build tools generate themselves, rather than curriculum content.
  SUMMARY_URLS = [
    %r{/summaries/}, # all pages in a summaries directory
    /unit-.*-vocab.*\.html/,
    /unit-.*-self-check.*\.html/,
    /unit-.*-exam-reference.*\.html/
  ].freeze

  private

  def summary_section?(section)
    self.class.summary_heading?(section[:title])
  end

  def summary_page?(item)
    return false if item[:url].nil?

    SUMMARY_URLS.any? { |re| item[:url].match?(re) }
  end

  # Takes in one "section" of the parsed topic object
  # Returns an array of all the paths in that section
  # If include_summaries = false, then known "summary" URLs are exlcuded
  # this means quizzes, vocab, ap exam pages.
  def extract_pages_in_section(parsed_section, include_summaries: false)
    parsed_section[:content].flat_map do |item|
      if !include_summaries && summary_page?(item)
        nil
      elsif RESOURCES_KEYWORDS.include?(item[:type])
        item
      elsif item[:type] == 'section'
        extract_pages_in_section(item, include_summaries: include_summaries)
      end
    end.compact
  end

  ### Parsing Helpers -- These should be moved at some point...

  # remove the text after // only if // is at the beginning of a line, or preceded by whitespace.
  # Input: "// hello" Outpit" ""
  # Input "resource: Text [http://test]" Output: "resource: Text [http://test]"
  # Input "resource: Text [http://test] // Comment" Output: "resource: Text [http://test]"
  def strip_comments(s)
    return '' unless s

    s.gsub(%r{(\s|^)//.*}, '').strip
  end

  # Each 'line' in a topic file can be 'indented' by tabs or spaces, which affects
  # its visual position when rendered.
  # NOTE: a the difference between 2 or 4 spaces as one "indent level" was never defined.
  def indent_level(s, tab_size = 4)
    s.count("\t") + (s.count(' ') / tab_size)
  end

  def get_keyword(line, array)
    matches = array.map { |s| line.match(s) }
    index = matches.index { |m| !m.nil? }
    array[index] unless index.nil?
  end

  # Split "resource: Text [url]" in the right parts.
  # Only the first colon separates the keyword from the content, so headings
  # like "heading: Lab 1: Widget Basics" and raw-html containing a URL keep
  # everything after it. This matches llab's own getContent().
  # TODO: figure out of this is necessary or to reuse parse_line
  def get_content(line)
    return { text: '', url: '' } unless line

    content = line.split(':', 2)
    return { text: '', url: '' } unless content.length > 1

    sliced = content[1].split(/\[|\]/)
    text = sliced.length.positive? ? sliced[0].strip : ''
    url = sliced.length > 1 ? sliced[1].strip : ''
    { text: text, url: url }
  end

  def resource_line?(line)
    line.match?(RESOURCE_LINE)
  end

  def info_line?(line)
    line.match?(INFO_LINE)
  end

  def heading_line?(line)
    line.match?(HEADING_LINE)
  end

  def keyword_line?(line)
    resource_line?(line) || info_line?(line) || heading_line?(line)
  end
end
