# frozen_string_literal: true

# Run accessibility specs for all pages in the webiste.
# This runs the axe accessibility checker on each page in a headless browser.

require 'nokogiri'

# Load our custom BJC tools
require_relative '../build-tools/bjc_helpers'
require_relative '../build-tools/course'
require_relative '../build-tools/topic'

# spec_helper ensures the webiste is built and can be served locally
require_relative './spec_helper'

COURSES = %w[
  bjc4nyc
  bjc4nyc.es
  sparks
  bjc4nyc_teacher
  sparks-teacher
]

def load_site_urls(courses)
  courses.map do |course|
    puts "Buidling URLs for #{course}..."
    load_all_urls_in_course("#{course}.html")
  end.flatten
end

def extract_urls_from_page(topic_file, course)
  topic_file = File.join(File.dirname(__FILE__), '..', '..', 'topic', topic_file)
  lang = topic_file.match(/\.(\w\w)\.topic/) ? Regexp.last_match(1) : 'en'
  topic_parser = BJCTopic.new(topic_file, course: course, language: lang)
  topic_parser.augmented_page_paths_in_topic
end

def load_all_urls_in_course(course)
  # This is slow...
  # Read the course page, then add all "Unit" URLs to the list
  # TODO: Use the BJCCourse class to extract the URLs
  results = [ "/bjc-r/#{course}" ]
  course_file = File.join(File.dirname(__FILE__), '..', '..', 'course', course)
  doc = Nokogiri::HTML(File.read(course_file))
  urls = doc.css('.topic_container .topic_link a').map { |url| url['href'] }

  topic_pages = urls.filter_map do |url|
    next unless url.match?(/\.topic/)

    results << "#{url}&course=#{course}"
    topic_file = url.match(/topic=(.*\.topic)/)[1]
    extract_urls_from_page(topic_file, course)
  end.flatten

  results << topic_pages
  results << urls.filter_map { |url| "#{url}&course=#{course}" if !url.match?(/\.topic/) }
  results.flatten
end

ALL_PAGES = []
# TODO: We need to figure out what things should be tested.
# Loading all pages, including the old ones is not helpful.
base_path = File.join(File.dirname(__FILE__), '..', '..')
site = File.join(base_path, '**', 'index.html')
index_pages = Dir.glob(site).filter_map { |f| f.gsub(base_path, '/bjc-r') if !f.match?(/old\//) }

ALL_PAGES.concat(index_pages)
ALL_PAGES.concat(load_site_urls(COURSES)).reject! { |u| !u.start_with?('/bjc-r') }.uniq!

puts "Running tests on #{ALL_PAGES.count} pages."
# puts "  - #{ALL_PAGES.join("\n  - ")}\n#{'=' * 72}\n\n"

# Axe-core test standards groups
# See https://github.com/dequelabs/axe-core/blob/develop/doc/API.md#axe-core-tags
required_a11y_standards = %i[wcag2a wcag2aa]
# These are currently skipped until the basic tests are passing.
complete_a11y_standards = %i[wcag21a wcag21 wcag22aa best-practice secion508]

# axe-core rules that are not required to be accessible / do not apply
# See: https://github.com/dequelabs/axe-core/blob/develop/doc/rule-descriptions.md
skipped_rules = [

]
# These are elements that are not required to be accessible
excluded_elements = [
  '[data-a11y-external-errors="true"]',
  '.js-openProdLink',
  'var', # Snap! elements don't have enough color contrast.
]


ALL_PAGES.each do |path|
  describe "'#{path}' is accessible", type: :feature, js: true do
    before(:each) do
      visit(path)
    end

    # These tests should always be enabled.
    it 'according to WCAG 2.0 AA' do
      expect(page).to be_axe_clean
        .according_to(*required_a11y_standards, "#{path} does NOT meet WCAG 2.0 AA")
        .skipping(*skipped_rules)
        .excluding(*excluded_elements)
    end

    # it 'according to WCAG 2.2 and all additional standards', :skip do
    #   expect(page).to be_axe_clean
    #     .according_to(*complete_a11y_standards)
    #     .skipping(*skipped_rules)
    #     .excluding(*excluded_elements)
    # end
  end
end
