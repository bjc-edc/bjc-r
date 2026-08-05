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
