# frozen_string_literal: true

require 'nokogiri'

# Load our custom BJC tools
require_relative '../build-tools/bjc_helpers'
require_relative '../build-tools/course'
require_relative '../build-tools/topic'

module BJCSpecs
  # The list of all courses in BJC
  COURSES = %w[
    bjc4nyc
    bjc4nyc.es
    sparks
    bjc4nyc_teacher
    sparks-teacher
  ].freeze

  # Pages that belong to no single course: the site root, plus pages that are
  # publicly visible but not linked from a course page.
  GENERAL_PAGES = [
    # For the BJC Team, but technically public
    'docs/style_guide',
    'docs/best_practices',
    'docs/translations',
    # Empty Topic pages, but are publicly visible.
    'topic/topic',
    'topic/topic.es',
    # Extra course page, but not a full course.
    'mini/index',
    # Informational Pages, but not linked as part of a course.
    'sparks/design-principles',
    'cur/snap-cheat-sheet',
    'cur/snap-cheat-sheet.es',
    'cur/blown-to-bits',
    'cur/compare',
    'cur/specifications',
    'cur/updates',
    'eir/school-equity',
    # Generated summary pages that no topic or course page links to.
    'cur/programming/atwork',
    'cur/programming/atwork.es',
    'sparks/student-pages/vocab-index'
  ].map { |page| "/bjc-r/#{page}.html" }.freeze

  # This is a map of all pages by course
  ALL_PAGES = { 'general' => ['/bjc-r/', *GENERAL_PAGES].freeze }.freeze

  module_function

  def load_site_urls(courses)
    # Map is a course_name => [url1, url2, ...]
    courses.to_h do |course|
      puts "Building URLs for #{course}..."
      [course, load_all_urls_in_course("#{course}.html")]
    end
  end

  # The specs check every page a student can reach, which includes the
  # vocabulary / self-check / exam-reference pages the build tools generate.
  # Those are excluded from the *build's* view of a topic (it must not
  # summarize its own output), but they still ship, so they still get tested.
  def extract_urls_from_page(topic_file, course)
    topic_file = File.join(File.dirname(__FILE__), '..', '..', 'topic', topic_file)
    lang = topic_file =~ /\.(\w\w)\.topic/ ? Regexp.last_match(1) : 'en'
    topic_parser = BJCTopic.new(topic_file, course: course, language: lang)
    topic_parser.augmented_page_paths_in_topic(include_summaries: true)
  end

  def load_all_urls_in_course(course)
    # Read the course page, then add all "Unit" URLs to the list
    # TODO: Use the BJCCourse class to extract the URLs
    results = ["/bjc-r/course/#{course}"]
    course_file = File.join(File.dirname(__FILE__), '..', '..', 'course', course)
    doc = Nokogiri::HTML(File.read(course_file))
    urls = doc.css('.topic_container .topic_link a').map { |url| url['href'] }

    topic_pages = urls.filter_map do |url|
      next unless url.include?('.topic')

      query_separator = url.include?('?') ? '&' : '?'
      results << "#{url}#{query_separator}course=#{course}"
      topic_file = url.match(/topic=(.*\.topic)/)[1]
      extract_urls_from_page(topic_file, course)
    end.flatten

    results << topic_pages
    results << urls.filter_map do |url|
      unless url.include?('.topic')
        "#{url}#{url.include?('?') ? '&' : '?'}course=#{course}"
      end
    end
    results.flatten.select { |u| u.start_with?('/bjc-r') }.uniq
  end

  def complete_bjc_grouped_file_list(courses)
    ALL_PAGES.merge(load_site_urls(courses))
  end
end
