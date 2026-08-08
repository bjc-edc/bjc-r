# frozen_string_literal: true

# Drives the in-page anchors that let a generated summary page link back to the
# exact box it copied, rather than to the top of the source page.
#
#   bundle exec rspec utilities/specs/content_anchors_spec.rb
#
# Curriculum pages are hand-written HTML with no build step, so their IDs are
# assigned in the browser -- llab.addContentAnchors for vocab and exam boxes,
# multiplechoice.js for self-check questions. The build tools count the same
# boxes the same way (see utilities/build-tools/{vocab,selfcheck}.rb), and
# nothing checks that agreement but a spec that follows a real link.

require_relative 'spec_helper'

UNIT_2_PARAMS = '?topic=nyc_bjc/2-conditionals-abstraction.topic&course=bjc4nyc.html'
UNIT_2_PAGES = '/bjc-r/cur/programming/2-complexity'
# Two vocab boxes, one exam box, two self-checks.
GUESSING_GAME = "#{UNIT_2_PAGES}/1-variables-games/1-number-guessing-game.html#{UNIT_2_PARAMS}".freeze
# One vocab box, two exam boxes, one self-check -- a different shape, and later
# in the same unit, so unit-wide numbering would not start it back at 1.
CHOOSING_AVATAR = "#{UNIT_2_PAGES}/1-variables-games/5-choosing-avatar.html#{UNIT_2_PARAMS}".freeze
VOCAB_SUMMARY = "#{UNIT_2_PAGES}/unit-2-vocab.html#{UNIT_2_PARAMS}".freeze

RSpec.describe 'content anchors', :js, driver: :chrome_headless_short, type: :feature do
  # Capybara's `visit` returns once the document is complete, but the scroll
  # runs on "load" and the self-checks are built on DOM ready, so the page
  # settles a beat later.
  def wait_for(description, timeout: 10)
    deadline = Time.now + timeout
    loop do
      result = yield
      return result if result
      raise "Timed out after #{timeout}s waiting for #{description}" if Time.now > deadline

      sleep 0.1
    end
  end

  # Every box llab.addContentAnchors or multiplechoice.js numbered.
  def anchor_ids
    page.evaluate_script("Array.from(document.querySelectorAll('.anchor-target')).map(el => el.id)")
  end

  def scroll_y
    page.evaluate_script('window.scrollY')
  end

  # How far below the top of the viewport the box sits, once scrolled.
  def distance_from_viewport_top(selector)
    page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().top")
  end

  def navbar_bottom
    page.evaluate_script("document.querySelector('.llab-nav').getBoundingClientRect().bottom")
  end

  def wait_for_anchors(*ids)
    ids.each { |id| expect(page).to have_css("##{id}", visible: :all, wait: 15) }
  end

  # Wait until SELECTOR has been scrolled up near the top of the window. Not
  # "until the page has scrolled at all": the nav and the bottom bar are added
  # asynchronously and nudge the page a few pixels on their own, which is
  # enough to satisfy a scrollY check well before the anchor is honored.
  def wait_until_scrolled_to(selector)
    wait_for("#{selector} to be scrolled into view") do
      distance_from_viewport_top(selector) < 300
    end
  end

  describe 'numbering' do
    it 'numbers each kind of box from 1, per page' do
      visit GUESSING_GAME
      wait_for_anchors('vocab-2', 'exam-1', 'self-check-2')

      expect(anchor_ids).to match_array(%w[vocab-1 vocab-2 exam-1 self-check-1 self-check-2])
    end

    it 'starts back at 1 on the next page of the same unit' do
      visit CHOOSING_AVATAR
      wait_for_anchors('vocab-1', 'exam-2', 'self-check-1')

      expect(anchor_ids).to match_array(%w[vocab-1 exam-1 exam-2 self-check-1])
    end

    it 'numbers the boxes of a generated summary page too' do
      visit VOCAB_SUMMARY
      wait_for_anchors('vocab-1')

      # The vocab index links to a term by its place on this page, so the
      # numbering has to run past the boxes of every source page it collected.
      expect(anchor_ids.length).to eq(page.all('.vocab.summaryBox', visible: :all).length)
      expect(anchor_ids).to include('vocab-1', 'vocab-2')
    end
  end

  describe 'scrolling' do
    it 'scrolls to the box named by the URL fragment' do
      visit "#{GUESSING_GAME}#vocab-2"
      wait_for_anchors('vocab-2')

      wait_until_scrolled_to('#vocab-2')
      expect(scroll_y).to be > 300
    end

    it 'leaves the box clear of the fixed navbar' do
      visit "#{GUESSING_GAME}#vocab-2"
      wait_for_anchors('vocab-2')
      wait_until_scrolled_to('#vocab-2')

      expect(distance_from_viewport_top('#vocab-2')).to be >= navbar_bottom
    end

    it 'scrolls to a self-check, which exists only once quiz.js has built it' do
      visit "#{GUESSING_GAME}#self-check-2"
      wait_for_anchors('self-check-2')

      wait_until_scrolled_to('#self-check-2')
      expect(distance_from_viewport_top('#self-check-2')).to be >= navbar_bottom
    end

    it 'stays at the top when the URL names no box' do
      visit GUESSING_GAME
      wait_for_anchors('vocab-2')

      expect(scroll_y).to eq(0)
    end

    it 'scrolls when only the fragment changes' do
      visit GUESSING_GAME
      wait_for_anchors('vocab-2')
      expect(scroll_y).to eq(0)

      page.execute_script("location.hash = 'vocab-2'")

      wait_until_scrolled_to('#vocab-2')
      expect(distance_from_viewport_top('#vocab-2')).to be >= navbar_bottom
    end

    it 'starts a dynamic page load at the top when it names no box' do
      visit "#{GUESSING_GAME}#vocab-2"
      wait_for_anchors('vocab-2')
      wait_until_scrolled_to('#vocab-2')

      find('.llab-nav .js-nextPageLink:not(.d-none)', wait: 15).click

      wait_for('the next page to render') { page.evaluate_script('location.hash') == '' }
      wait_for('the new page to settle') { scroll_y.zero? }
      expect(scroll_y).to eq(0)
    end

    # Going back to a page that was reached by a summary backlink: the loader
    # rebuilds it rather than restoring it, so the anchor has to be applied
    # again or the reader loses their place.
    it 'returns to the box when going back to an anchored page' do
      visit "#{GUESSING_GAME}#vocab-2"
      wait_for_anchors('vocab-2')
      wait_until_scrolled_to('#vocab-2')
      find('.llab-nav .js-nextPageLink:not(.d-none)', wait: 15).click
      wait_for('the next page to render') { page.evaluate_script('location.hash') == '' }

      page.go_back

      wait_for_anchors('vocab-2')
      wait_until_scrolled_to('#vocab-2')
      expect(distance_from_viewport_top('#vocab-2')).to be >= navbar_bottom
    end
  end

  # The point of the whole exercise: a link the build tools wrote, followed in a
  # browser, landing on the box whose text the summary page copied.
  describe 'a summary page backlink' do
    it 'lands on the box the summary copied, not merely on the page' do
      visit VOCAB_SUMMARY
      link = find("a[href*='1-number-guessing-game.html'][href$='#vocab-2']", wait: 15)
      summary_box = link.find(:xpath, './ancestor::div[contains(@class, "summaryBox")]')
      copied_term = summary_box.first('strong', minimum: 1).text

      link.click

      wait_for_anchors('vocab-2')
      wait_until_scrolled_to('#vocab-2')
      expect(find('#vocab-2', visible: :all).first('strong', minimum: 1).text).to eq(copied_term)
      # ...and the box the link used to land on says something else, so the
      # assertion above would notice if the anchor were dropped.
      expect(find('#vocab-1', visible: :all).first('strong', minimum: 1).text)
        .not_to eq(copied_term)
    end
  end
end
