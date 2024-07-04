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

# ===== bjc-r specific config/parsing....
def load_site_urls(courses)
  # Map is a course_name => [url1, url2, ...]
  courses.map do |course|
    puts "Buidling URLs for #{course}..."
    [course, load_all_urls_in_course("#{course}.html")]
  end.to_h
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
  results = [ "/bjc-r/course/#{course}" ]
  course_file = File.join(File.dirname(__FILE__), '..', '..', 'course', course)
  doc = Nokogiri::HTML(File.read(course_file))
  urls = doc.css('.topic_container .topic_link a').map { |url| url['href'] }

  topic_pages = urls.filter_map do |url|
    next unless url.match?(/\.topic/)

    query_separator = url.match?(/\?/) ? '&' : '?'
    results << "#{url}#{query_separator}course=#{course}"
    topic_file = url.match(/topic=(.*\.topic)/)[1]
    extract_urls_from_page(topic_file, course)
  end.flatten

  results << topic_pages
  results << urls.filter_map { |url| "#{url}#{url.match?(/\?/) ? '&' : '?'}course=#{course}" if !url.match?(/\.topic/) }
  results.flatten.reject { |u| !u.start_with?('/bjc-r') }.uniq
end
# ===============================

def test_tags(tags)
  # Adds "course_wcag22" tag to the list.
  tags << tags.join("_")
  Hash[tags.map { |k| [k.to_sym, true] }]
end

# Create a readable path for specs from the page URL
def trimmed_url(url)
  path = url.gsub('/bjc-r', '')
  path.split('?').first # Trim all query parameters for readability.
end

def topic_from_url(url)
  return '-' unless url.match(/topic=(.*)\.topic/)

  "- #{Regexp.last_match(1)} -"
end

def a11y_test_cases(course, url)
  # A little hacky, but `rspec --tag` doesn't allow "and" conditions.
  # Allows CI to run only the tests for a specific course AND standard.
  wcag20_tags = test_tags([course, :wcag20])
  wcag22_tags = test_tags([course, :wcag22])

  # ====== AXE Configuration
  # Axe-core test standards groups
  # See https://github.com/dequelabs/axe-core/blob/develop/doc/API.md#axe-core-tags
  required_a11y_standards = %i[wcag2a wcag2aa]
  # These are currently skipped until the basic tests are passing.
  complete_a11y_standards = %i[wcag21a wcag21aa wcag22aa wcag2a-obsolete best-practice secion508]

  # axe-core rules that are not required to be accessible / do not apply
  # See: https://github.com/dequelabs/axe-core/blob/develop/doc/rule-descriptions.md
  skipped_rules = []

  # These are elements that are not required to be accessible
  excluded_elements = [
    '[data-a11y-external-errors="true"]', # should be used very sparingly.
    '.js-openProdLink', # OK to exclude, only in development.
    'var', # Snap! elements don't have enough color contrast.
  ]

  describe "#{course} #{topic_from_url(url)} #{trimmed_url(url)}",
    type: :feature, js: true do
    before(:each) do
      visit(url)

      if page.html.match?(/File not found:/)
        skip("TODO: #{url} is a 404 page.")
      end
    end

    # These tests should always be enabled.
    it 'is WCAG 2.0 accessible', **wcag20_tags do
      expect(page).to be_axe_clean
        .according_to(*required_a11y_standards)
        .skipping(*skipped_rules)
        .excluding(*excluded_elements)
    end

    it 'is WCAG 2.2 accessible', **wcag22_tags do
      expect(page).to be_axe_clean
        .according_to(*complete_a11y_standards)
        .skipping(*skipped_rules)
        .excluding(*excluded_elements)
    end

    it 'has no broken links', course => true do
      passed_test = true
      page.all('a').each do |link|
        url = link['href']
        response = Net::HTTP.get_response(URI(url))
        unless [200, 301, 302].include?(response.code.to_i)
          passed_test = false
          puts "Broken link: #{url} returned a #{response.code}"
        end
      end
      expect(passed_test).to be true
    end
  end
end

# Use course as a tag (`rspec --tag bjc4nyc`) to run only the tests for that course.
COURSES = %w[
  bjc4nyc
  bjc4nyc.es
  sparks
  bjc4nyc_teacher
  sparks-teacher
]
ALL_PAGES = load_site_urls(COURSES)
# TODO: We need to figure out what things should be tested.
# base_path = File.join(File.dirname(__FILE__), '..', '..')
# site = File.join(base_path, '**', 'index.html')
# index_pages = Dir.glob(site).filter_map { |f| f.gsub(base_path, '/bjc-r') if !f.match?(/old\//) }
# ALL_PAGES['Indexes'] = index_pages
puts "Running tests on #{ALL_PAGES.values.map(&:length).sum} pages."

ALL_PAGES.each do |course, pages|
  pages.each { |url| a11y_test_cases(course, url) }
end
