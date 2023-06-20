
require_relative 'bjc_helpers'

class BJCTopic
  attr_reader :file_path
  attr_reader :file_name
  attr_reader :title
  attr_reader :language

  # TODO: Is it useful to know the course a topic came with?
  def initialize(path, course: nil, language: 'en')

  end

  # This should return some hash-type structure
  # look at the code in llab
  # TODO: this could arguably be its own class.
  # Is this all that's needed (recursively) ?
  # { title, type, content, number, pages: [] }
  def parse

  end

  def unit_number
  end

  # TODO: This is what will make the organization a bit tricky...
  # FOR most BJC4NYC --> /bjc-r/cur/programming/{UNIT}/
  # FOR Sparks ..
  # For Teacher guides?
  def base_content_folder
  end

  # Just the names of the lab sections
  def section_headings
  end

  # This should explicitly exclude the 3 compiled HTML pages.
  def all_pages

  end

  def all_pages_with_summaries
  end

  def to_h
  end

  def to_json
    self.to_h.to_json
  end

  # TODO: What other things might we do with a topic file?
  # Do we need to render the HTML to auit accessibility, etc?
  # Can we return just the HTML fragments?
end