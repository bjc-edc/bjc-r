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

# ===== Page / Couse List
# Use course as a tag (`rspec --tag bjc4nyc`) to run only the tests for that course.
COURSES = %w[
  bjc4nyc
  bjc4nyc.es
  sparks
  bjc4nyc_teacher
  sparks-teacher
]
ALL_PAGES = load_site_urls(COURSES)
# A handful of pages we should ensure are compliant.
ALL_PAGES['general'] = [
  '/bjc-r/',
  '/bjc-r/docs/style_guide.html',
  '/bjc-r/docs/best_practices.html',
  '/bjc-r/docs/translations.html',
  '/bjc-r/topic/topic.html',
  '/bjc-r/topic/topic.es.html',
  '/bjc-r/sparks/design-principles.html',
  '/bjc-r/mini/index.html'
]
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

  "- #{Regexp.last_match(1)}"
end

def a11y_test_cases(course, url)
  # A little hacky, but `rspec --tag` doesn't allow "and" conditions.
  # Allows CI to run only the tests for a specific course AND standard.
  wcag20_tags = test_tags([course, :wcag20])
  wcag22_tags = test_tags([course, :wcag22])
  subset_tags = test_tags([course, :subset])

  # ====== AXE Configuration
  # Axe-core test standards groups
  # See https://github.com/dequelabs/axe-core/blob/develop/doc/API.md#axe-core-tags
  required_a11y_standards = %i[wcag2a wcag2aa]
  # These are currently skipped until the basic tests are passing.
  complete_a11y_standards = %i[wcag21a wcag21aa wcag22aa wcag2a-obsolete best-practice secion508]

  # axe-core rules that are not required to be accessible / do not apply
  # See: https://github.com/dequelabs/axe-core/blob/develop/doc/rule-descriptions.md
  skipped_rules = ['listitem']

  # These are elements that are not required to be accessible
  excluded_elements = [
    # should be used very sparingly.
    '[data-a11y-errors="true"]',
    # Developer Tools, which aren't visible in production
    '.todo',
    '.comment',
    '.commentBig',
    '.ap-standard',
    '.csta-standard',
    # TODO: items below here **must** be fixed eventually.
    'var', # Snap! elements don't have enough color contrast.
  ]

  describe "#{course} #{topic_from_url(url)} (#{trimmed_url(url)}) :",
    type: :feature, js: true do
    before(:each) do
      visit(url)

      if page.html.match?(/File not found:/)
        skip("TODO: #{url} is a 404 page.")
      end

      # TODO: Add a function to expand all optional content.
      # TODO: This only works for the ifTime, etc. boxes.
      page.execute_script <<~JS
        window.onload = (_) => {
          Array.from(document.querySelectorAll('details')).forEach(el => el.open = true);
        };
      JS
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

    # TODO: Remove or comment out this test after the subset rules are passing.    # it allows you to easily/temporary update a subset of axe rules and run just those.
    it 'passes heading-order a11y rules', **wcag22_tags, heading_order: true do
      expect(page).to be_axe_clean
        .checking_only(%i|
          heading-order
        |)
        .excluding(*excluded_elements)
    end


    # it allows you to easily/temporary update a subset of axe rules and run just those.
    it 'passes a subset a11y rules', **subset_tags do
      expect(page).to be_axe_clean
        .checking_only(%i|
          color-contrast
          duplicate-id
          listitem
          frame-title
          image-alt
          label
          area-alt
        |)
        .excluding(*excluded_elements)
    end

    # TODO: This test *kind of* works, but has too many false positives.
    # Some URLs fail on GitHub actions which are actually valid when used by a human.
    # it 'has no broken links', **subset_tags do
    #   passed_test = true
    #   page.all('a').each do |link|
    #     url = link['href']
    #     next unless url

    #     # All google docs seem to report 401's falsely in CI.
    #     next if url.match(/docs\.google\.com/)

    #     response = Net::HTTP.get_response(URI(url))
    #     unless [200, 301, 302, 303].include?(response.code.to_i)
    #       passed_test = false
    #       puts "Broken link: #{url} returned a #{response.code}"
    #     end
    #   end
    #   expect(passed_test).to be true
    # end
  end
end


puts "Running tests on #{ALL_PAGES.values.map(&:length).sum} pages."
ALL_PAGES.each do |course, pages|
  pages.each { |url| a11y_test_cases(course, url) }
end
