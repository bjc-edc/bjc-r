# frozen_string_literal: true

# Exercises the self-check (multiple-choice) feedback UI.
#
# These specs drive a real self-check page in a headless browser: they select an
# answer, click "Check Answer", and assert that the per-choice feedback is
# revealed *below* the answer choice it belongs to (rather than squished inline
# beside it) and is colored to match correctness. This guards the layout fix in
# llab/css/default.css + llab/script/quiz/multiplechoice.js.

require_relative 'spec_helper'

# A couple of end-of-unit summary ("self-check") pages. These embed their
# multiple-choice questions inline (no remote src), so no course/topic query
# params are required to render them.
SELF_CHECK_PAGES = [
  '/bjc-r/cur/programming/1-introduction/unit-1-self-check.html',
  '/bjc-r/cur/programming/3-lists/unit-3-self-check.html'
].freeze

# JS that inspects the *first* answer choice whose feedback is currently shown
# and reports the geometry we care about. `this` is the .MultipleChoice element
# (Capybara binds it to the node for Node#evaluate_script).
VISIBLE_FEEDBACK_GEOMETRY_JS = <<~JS
  (function (question) {
    var feedback = Array.prototype.slice
      .call(question.querySelectorAll('.option-feedback'))
      // offsetParent is null when display:none, so this finds the shown one.
      .find(function (el) { return el.offsetParent !== null && el.textContent.trim() !== ''; });
    if (!feedback) { return null; }

    var row = feedback.closest('.option-row');
    var label = row.querySelector('label');
    var feedbackRect = feedback.getBoundingClientRect();
    var labelRect = label.getBoundingClientRect();
    return {
      text: feedback.textContent.trim(),
      choiceState: label.getAttribute('class'),   // "correct" or "incorrect"
      feedbackTop: feedbackRect.top,
      feedbackLeft: feedbackRect.left,
      labelBottom: labelRect.bottom,
      labelLeft: labelRect.left
    };
  })(this)
JS

def self_check_feedback_examples(url)
  describe "self-check feedback (#{url.sub('/bjc-r', '')}) :", :js, type: :feature do
    before do
      visit(url)
      skip("TODO: #{url} is a 404 page.") if page.html.include?('File not found:')
      # Wait for the quiz engine to build the interactive questions.
      # `find` blocks until it appears (and fails the example if it never does).
      find('.MultipleChoice .checkAnswerButton', match: :first, wait: 10)
    end

    it 'hides all answer-choice feedback until an answer is checked' do
      question = find('.MultipleChoice.Question', match: :first)
      expect(question).to have_no_css('.option-feedback', visible: :visible)
    end

    it 'asks for a selection when checking with nothing selected' do
      question = find('.MultipleChoice.Question', match: :first)
      question.find('.checkAnswerButton').click

      # A polite prompt appears (in the screen-reader-announced status region)
      # instead of the question being marked wrong with no feedback anywhere.
      expect(question).to have_css('.resultMessageDiv[role="status"]',
                                   text: /select an answer/i, wait: 5)
      expect(question[:class]).not_to match(/panel-(danger|warning|success)/)
      expect(question).to have_no_css('.option-feedback', visible: :visible)

      # The student can still answer normally afterwards.
      question.find('input[type="radio"], input[type="checkbox"]', match: :first).click
      question.find('.checkAnswerButton').click
      expect(question).to have_css('.option-feedback', visible: :visible, text: /\S/, wait: 5)
      expect(question).to have_no_text(/select an answer/i)
    end

    it 'reveals feedback below the selected choice after checking an answer' do
      question = find('.MultipleChoice.Question', match: :first)

      # Select the first answer choice and check it.
      question.find('input[type="radio"], input[type="checkbox"]', match: :first).click
      question.find('.checkAnswerButton').click

      # Feedback for the chosen answer becomes visible and non-empty.
      expect(question).to have_css('.option-feedback', visible: :visible, text: /\S/, wait: 5)

      geometry = question.evaluate_script(VISIBLE_FEEDBACK_GEOMETRY_JS)
      expect(geometry).not_to be_nil

      # The chosen choice is flagged correct or incorrect...
      expect(geometry['choiceState']).to match(/\A(correct|incorrect)\z/)

      # ...the feedback always states a verdict (authored, or the auto-added
      # "Correct." / "Incorrect." prefix), so no choice checks silently...
      expect(geometry['text']).to match(/correct/i)

      # ...and the label text itself is left neutral (no correctness recoloring);
      # the state class exists only as a styling hook for the feedback box.
      label_color = question.evaluate_script(<<~JS)
        (function (q) {
          var lbl = q.querySelector('.option-row label.correct, .option-row label.incorrect');
          return lbl ? getComputedStyle(lbl).color : null;
        })(this)
      JS
      # Not green (rgb(25,135,84)) and not red (rgb(220,53,69)).
      expect(label_color).not_to match(/25,\s*135,\s*84|220,\s*53,\s*69/)

      # ...and the fix: feedback sits *below* the choice (stacked), not inline to
      # its right. A small tolerance absorbs sub-pixel rounding.
      expect(geometry['feedbackTop']).to be >= (geometry['labelBottom'] - 2)

      # It is also indented under the choice text rather than starting at the
      # very left edge of the row.
      expect(geometry['feedbackLeft']).to be > geometry['labelLeft']
    end
  end
end

SELF_CHECK_PAGES.each { |url| self_check_feedback_examples(url) }

# The one question the examples below work with; marked from JS by
# stage_middle_question.
TARGET_QUESTION = '.MultipleChoice.Question.js-spec-target'

# Checking an answer moves focus off the Check Answer button, which is disabled
# at that moment and would otherwise strand keyboard focus on <body>. Focusing
# a button also scrolls it into view, which yanked the page out from under a
# student mid-question on anything but a very tall window.
RSpec.describe 'checking an answer', :js, driver: :chrome_headless_short, type: :feature do
  # Everything below is driven through JS rather than through Capybara, which
  # scrolls an element into view before clicking it -- the very thing being
  # measured here.
  #
  # Picks a question in the middle of the page and answers it.
  def stage_middle_question
    page.execute_script(<<~JS)
      var questions = document.querySelectorAll('.MultipleChoice.Question');
      var question = questions[Math.floor(questions.length / 2)];
      question.classList.add('js-spec-target');
      question.querySelector('input[type=radio], input[type=checkbox]').click();
    JS
  end

  # Puts the reader partway through the question, with its buttons just below
  # the bottom of the window. That is the situation the fix is about: focusing
  # a button there has somewhere to scroll to, and scrolling loses their place.
  def scroll_buttons_just_below_the_fold
    page.execute_script(<<~JS)
      var button = document.querySelector('#{TARGET_QUESTION} .tryAgainButton');
      var bottom = button.getBoundingClientRect().bottom + window.scrollY;
      window.scrollTo(0, bottom - window.innerHeight - 60);
    JS
  end

  def check_answer
    page.execute_script("document.querySelector('#{TARGET_QUESTION} .checkAnswerButton').click()")
  end

  def try_again_offscreen?
    page.evaluate_script(
      "document.querySelector('#{TARGET_QUESTION} .tryAgainButton')" \
      '.getBoundingClientRect().bottom > window.innerHeight'
    )
  end

  # Images above the question keep loading for a moment after it is scrolled
  # to, and Chrome's scroll anchoring moves the page along with them. Read the
  # position only once it has stopped changing on its own.
  def settled_scroll_position
    previous = nil
    20.times do
      current = page.evaluate_script('window.scrollY')
      return current if current == previous

      previous = current
      sleep 0.25
    end
    raise 'the page never stopped scrolling on its own'
  end

  before do
    visit SELF_CHECK_PAGES.first
    # find, not expect: waits the same way, but a before hook is no place for
    # an assertion.
    find('.MultipleChoice.Question .checkAnswerButton', match: :first, wait: 15)
    stage_middle_question
    settled_scroll_position # let the page finish moving before moving it ourselves
    scroll_buttons_just_below_the_fold
  end

  it 'leaves the page where the student left it' do
    before_scroll = settled_scroll_position
    # Without this the question would already be fully on screen, and focusing
    # its buttons would scroll nothing whatever the code did.
    expect(try_again_offscreen?).to be(true)

    check_answer

    expect(page).to have_css("#{TARGET_QUESTION} .option-feedback", visible: :visible, text: /\S/, wait: 5)
    expect(page.evaluate_script('window.scrollY')).to be_within(5).of(before_scroll)
  end

  it 'still moves focus to Try Again, off the disabled Check Answer button' do
    check_answer

    expect(page).to have_css("#{TARGET_QUESTION} .option-feedback", visible: :visible, text: /\S/, wait: 5)
    expect(page.evaluate_script('document.activeElement.className')).to include('tryAgainButton')
  end
end
