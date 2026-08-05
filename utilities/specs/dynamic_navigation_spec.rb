# frozen_string_literal: true

# Functional tests for the dynamic (SPA-style) page loader and the
# translations globe in the navbar.
#
# Run with: bundle exec rspec utilities/specs --tag dynamic_nav
#
# The "no full page load" assertions work by setting a marker on `window`
# before acting: a dynamic navigation keeps the same document, so the marker
# survives; a full page load creates a new document and wipes it.

require_relative 'spec_helper'

# A lab page in a fully translated unit (nyc_bjc unit 1).
LAB_PAGE_1 = '/bjc-r/cur/programming/1-introduction/1-building-an-app/' \
             '1-start-your-first-snap-app.html' \
             '?topic=nyc_bjc%2F1-intro-loops.topic&course=bjc4nyc.html'
# A lab page in a unit with no Spanish translation.
SPARKS_PAGE = '/bjc-r/sparks/student-pages/U1/L1/01-say-hello-to-snap.html' \
              '?topic=sparks%2F1-functions-data.topic&course=sparks.html'

# The nav is built after the topic file is fetched, and the translations
# globe after the unit-wide check; both need generous waits in CI.
NAV_WAIT = { wait: 15 }.freeze

RSpec.describe 'Dynamic page navigation', :dynamic_nav, :js, type: :feature do
  def wait_for_nav
    expect(page).to have_css('.llab-nav .js-nextPageLink:not(.d-none)', **NAV_WAIT)
  end

  def visit_and_mark(path)
    visit path
    wait_for_nav
    page.execute_script('window.llabSpecMarker = true')
  end

  # True while the browser is still on the same document (no full load).
  def same_document?
    page.evaluate_script('window.llabSpecMarker == true')
  end

  # Poll sessionStorage until the unit translation check has cached a result.
  def unit_translation_cache(topic_file)
    result = nil
    30.times do
      result = page.evaluate_script(
        "sessionStorage.getItem('llab-unit-translations:#{topic_file}')"
      )
      break unless result.nil?

      sleep 0.5
    end
    result
  end

  describe 'lab pages' do
    it 'builds the lab navigation' do
      visit LAB_PAGE_1
      wait_for_nav
      expect(page).to have_css('.llab-nav .js-backPageLink.disabled', **NAV_WAIT)
      expect(page).to have_css('.js-llabPageNavMenu li', minimum: 5, visible: :all, **NAV_WAIT)
    end

    it 'moves to the next page without a full page load' do
      visit_and_mark LAB_PAGE_1
      find('.llab-nav .js-nextPageLink').click

      expect(page).to have_current_path(/2-creating-a-snap-account/, **NAV_WAIT)
      expect(page).to have_css('.llab-nav .js-backPageLink:not(.disabled)', **NAV_WAIT)
      expect(same_document?).to be(true)
      expect(page.evaluate_script('window.history.state && window.history.state.llab')).to be(true)
    end

    it 'handles the browser back button without a full page load' do
      visit_and_mark LAB_PAGE_1
      find('.llab-nav .js-nextPageLink').click
      expect(page).to have_current_path(/2-creating-a-snap-account/, **NAV_WAIT)

      page.go_back
      expect(page).to have_current_path(/1-start-your-first-snap-app/, **NAV_WAIT)
      expect(page).to have_css('.llab-nav .js-backPageLink.disabled', **NAV_WAIT)
      expect(same_document?).to be(true)
    end

    it 'uses normal navigation when ENABLE_DYNAMIC_NAVIGATION is off' do
      visit_and_mark LAB_PAGE_1
      page.execute_script('llab.ENABLE_DYNAMIC_NAVIGATION = false')
      find('.llab-nav .js-nextPageLink').click

      expect(page).to have_current_path(/2-creating-a-snap-account/, **NAV_WAIT)
      wait_for_nav
      # A full page load creates a new document, wiping the marker.
      expect(same_document?).to be(false)
    end
  end

  describe 'translations globe' do
    it 'appears for a fully translated unit and is cached for the session' do
      visit LAB_PAGE_1
      expect(page).to have_css('.js-langDropdown:not(.d-none)', **NAV_WAIT)
      expect(unit_translation_cache('nyc_bjc/1-intro-loops.topic')).to eq('true')

      # Later pages in the unit decide from the cache.
      find('.llab-nav .js-nextPageLink').click
      expect(page).to have_current_path(/2-creating-a-snap-account/, **NAV_WAIT)
      expect(page).to have_css('.js-langDropdown:not(.d-none)', **NAV_WAIT)
    end

    it 'switches en -> es -> en without full page loads' do
      visit LAB_PAGE_1
      expect(page).to have_css('.js-langDropdown:not(.d-none)', **NAV_WAIT)
      page.execute_script('window.llabSpecMarker = true')

      find('.js-langDropdown .dropdown-toggle').click
      find('.js-switch-lang-es', **NAV_WAIT).click
      expect(page).to have_current_path(/1-start-your-first-snap-app\.es\.html/, **NAV_WAIT)
      expect(same_document?).to be(true)
      expect(page.evaluate_script('document.documentElement.lang')).to eq('es')

      # Back to English; the fetched page's own <html lang> drives the reset.
      expect(page).to have_css('.js-langDropdown:not(.d-none)', **NAV_WAIT)
      find('.js-langDropdown .dropdown-toggle').click
      find('.js-switch-lang-en', **NAV_WAIT).click
      expect(page).to have_current_path(/1-start-your-first-snap-app\.html/, **NAV_WAIT)
      expect(same_document?).to be(true)
      expect(page.evaluate_script('document.documentElement.lang')).to eq('en')
    end

    it 'stays hidden for a unit without a translation' do
      visit SPARKS_PAGE
      wait_for_nav
      expect(unit_translation_cache('sparks/1-functions-data.topic')).to eq('false')
      expect(page).to have_css('.js-langDropdown.d-none', visible: :all, **NAV_WAIT)
    end
  end
end
