# frozen_string_literal: true

require 'nokogiri'

require_relative 'quiz_extractor'

module CCExport
  # Serializes a QuizExtractor::Quiz into the IMS QTI 1.2 XML profile used by
  # Common Cartridge 1.x assessments. CC's QTI subset is documented at
  # https://www.imsglobal.org/cc/ccv1p3/imscc_profilev1p3-AssessmentProfile.html
  #
  # We emit:
  #   - one <questestinterop> document per quiz
  #   - one <assessment> per quiz, with a single <section>
  #   - one <item> per multiple-choice question, with response_lid /
  #     render_choice / resprocessing / itemfeedback blocks
  module QtiWriter
    QTI_NS = 'http://www.imsglobal.org/xsd/ims_qtiasiv1p2'
    QTI_RESOURCE_TYPE = 'imsqti_xmlv1p2/imscc_xmlv1p1/assessment'

    module_function

    def build_assessment_xml(quiz)
      doc = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.questestinterop(xmlns: QTI_NS) do
          xml.assessment(ident: quiz.id, title: quiz.title) do
            xml.qtimetadata do
              xml.qtimetadatafield do
                xml.fieldlabel 'cc_maxattempts'
                xml.fieldentry 'unlimited'
              end
            end
            xml.section(ident: "section-#{quiz.id}") do
              quiz.questions.each { |q| emit_item(xml, q) }
            end
          end
        end
      end
      doc.to_xml
    end

    def emit_item(xml, question)
      xml.item(ident: question.id, title: question.title) do
        emit_item_metadata(xml, question)
        emit_presentation(xml, question)
        emit_resprocessing(xml, question)
        emit_feedback_blocks(xml, question)
      end
    end

    def emit_item_metadata(xml, question)
      xml.itemmetadata do
        xml.qtimetadata do
          xml.qtimetadatafield do
            xml.fieldlabel 'cc_profile'
            xml.fieldentry question.multiple_response ? 'cc.multiple_response.v0p1' : 'cc.multiple_choice.v0p1'
          end
          xml.qtimetadatafield do
            xml.fieldlabel 'cc_weighting'
            xml.fieldentry '1'
          end
          if question.ap_standard && !question.ap_standard.empty?
            xml.qtimetadatafield do
              xml.fieldlabel 'ap_standard'
              xml.fieldentry question.ap_standard
            end
          end
        end
      end
    end

    def emit_presentation(xml, question)
      xml.presentation do
        emit_material_html(xml, question.stem_html)
        cardinality = question.multiple_response ? 'Multiple' : 'Single'
        xml.response_lid(ident: response_ident(question), rcardinality: cardinality) do
          xml.render_choice(shuffle: question.shuffle ? 'Yes' : 'No') do
            question.choices.each do |choice|
              xml.response_label(ident: choice.id) do
                emit_material_html(xml, choice.text_html)
              end
            end
          end
        end
      end
    end

    # The grading rules: for single-response, one varequal per correct choice
    # (any one matches → full credit). For multiple-response, an <and> block
    # demands all correct ids AND requires every incorrect id to NOT be
    # selected — that's what QTI 1.2 requires for true partial-credit-free
    # all-or-nothing scoring of multi-select MC items.
    def emit_resprocessing(xml, question)
      xml.resprocessing do
        xml.outcomes do
          xml.decvar(maxvalue: '100', minvalue: '0', varname: 'SCORE', vartype: 'Decimal')
        end

        # Per-choice feedback hooks: if the learner selects choice X, show
        # the feedback we authored for X. Order matches the choice block.
        question.choices.each do |choice|
          xml.respcondition(continue: 'Yes') do
            xml.conditionvar do
              xml.varequal(respident: response_ident(question)) { xml.text(choice.id) }
            end
            xml.displayfeedback(feedbacktype: 'Response', linkrefid: "fb_#{choice.id}")
          end
        end

        xml.respcondition(continue: 'No') do
          xml.conditionvar do
            if question.multiple_response
              xml.send(:and) do
                question.correct_ids.each do |cid|
                  xml.varequal(respident: response_ident(question)) { xml.text(cid) }
                end
                # Reject any incorrect choice being selected.
                incorrect = question.choices.map(&:id) - question.correct_ids
                incorrect.each do |bad|
                  xml.send(:not) do
                    xml.varequal(respident: response_ident(question)) { xml.text(bad) }
                  end
                end
              end
            elsif question.correct_ids.length == 1
              xml.varequal(respident: response_ident(question)) { xml.text(question.correct_ids.first) }
            else
              xml.send(:or) do
                question.correct_ids.each do |cid|
                  xml.varequal(respident: response_ident(question)) { xml.text(cid) }
                end
              end
            end
          end
          xml.setvar(action: 'Set', varname: 'SCORE') { xml.text('100') }
        end
      end
    end

    def emit_feedback_blocks(xml, question)
      question.choices.each do |choice|
        next if choice.feedback_html.to_s.strip.empty?

        xml.itemfeedback(ident: "fb_#{choice.id}") do
          xml.flow_mat do
            emit_material_html(xml, choice.feedback_html)
          end
        end
      end
    end

    def emit_material_html(xml, html_fragment)
      xml.material do
        xml.mattext(texttype: 'text/html') { xml.cdata(html_fragment.to_s) }
      end
    end

    def response_ident(question)
      "response_#{question.id}"
    end
  end
end
