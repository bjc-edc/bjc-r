# frozen_string_literal: true

require 'nokogiri'

module CCExport
  # Parses a BJC self-check HTML page (`unit-N-self-check.html` and friends)
  # into a structured Quiz the QTI writer can serialize.
  #
  # The site convention is a flat list of <div class="assessment-data">
  # blocks. Each block has:
  #
  #   - type="multiplechoice" (the only type used in BJC self-checks)
  #   - identifier="..."          — a human title; not unique enough to use as id
  #   - responseidentifier="ri..." — the per-question id, used everywhere
  #   - maxchoices="N"            — 1 => single-select; >1 => multi-select
  #   - shuffle="true|false"
  #
  # Children of an assessment-data block:
  #
  #   <div class="prompt">          stem HTML (may contain <img>, <code>, etc.)
  #   <div class="choice" identifier="cN">
  #     <div class="text">          answer HTML
  #     <div class="feedback">      per-choice explanation
  #   <div class="responseDeclaration" identifier="riN">
  #     <div class="correctResponse" identifier="cN"/>  (one or more)
  module QuizExtractor
    Question = Struct.new(
      :id, :title, :stem_html, :choices, :correct_ids,
      :shuffle, :multiple_response, :ap_standard,
      keyword_init: true
    )

    Choice = Struct.new(:id, :text_html, :feedback_html, keyword_init: true)

    Quiz = Struct.new(:id, :title, :questions, keyword_init: true)

    module_function

    def extract(html_text, quiz_id:, title:)
      doc = Nokogiri::HTML5(html_text)
      questions = doc.css('div.assessment-data').filter_map { |node| parse_question(node) }
      Quiz.new(id: quiz_id, title: title, questions: questions)
    end

    def parse_question(node)
      response_id = node['responseidentifier'].to_s.strip
      return nil if response_id.empty?

      max_choices = node['maxchoices'].to_i
      shuffle = node['shuffle'].to_s.downcase == 'true'

      prompt_node = node.at_css('> .prompt') || node.at_css('.prompt')
      stem_html = prompt_node ? inner_html_without(prompt_node, '.ap-standard') : ''
      ap_standard = prompt_node&.at_css('.ap-standard')&.text&.strip

      choices = node.css('> .choice').map do |choice_node|
        Choice.new(
          id: choice_node['identifier'].to_s.strip,
          text_html: inner_html(choice_node.at_css('> .text')),
          feedback_html: inner_html(choice_node.at_css('> .feedback'))
        )
      end
      return nil if choices.empty?

      correct_ids = node.css('> .responseDeclaration > .correctResponse').map { |c| c['identifier'].to_s.strip }
      correct_ids = choices.first(1).map(&:id) if correct_ids.empty? # defensive: avoid empty key set

      Question.new(
        id: response_id,
        title: (node['identifier'] || response_id).to_s.strip,
        stem_html: stem_html,
        choices: choices,
        correct_ids: correct_ids,
        shuffle: shuffle,
        multiple_response: max_choices > 1,
        ap_standard: ap_standard
      )
    end

    def inner_html(node)
      return '' if node.nil?

      node.children.map(&:to_html).join.strip
    end

    # Return inner HTML of `node` with descendants matching `selector` removed
    # (we strip `.ap-standard` because we surface it as a separate metadata
    # field — embedding it in the stem clutters the quiz UI).
    def inner_html_without(node, selector)
      clone = node.dup
      clone.css(selector).each(&:remove)
      inner_html(clone)
    end
  end
end
