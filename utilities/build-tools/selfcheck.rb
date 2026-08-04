# frozen_string_literal: true

require 'fileutils'
require 'i18n'

require_relative 'course'
require_relative 'bjc_helpers'

class SelfCheck
  include BJCHelpers

  def initialize(path, language, content, course)
    @parentPath = path
    # The generators are handed the content folder; the checkout root is what
    # is left once the content path is taken off the end of it.
    @rootDir = path.delete_suffix('/').delete_suffix("/#{content}")
    @content = content
    @course = course
    @currUnit = nil
    @currUnitNum = 0
    @currLab = ''
    @currUnitName = nil
    @language = language
    @language_ext = language_ext(language)
    I18n.locale = @language.to_sym
    @box_num = 0
    # Track the previous lab/section heading for the self-check+exam page.
    # If it changes, then we need to insert a new page heading.
    @priorPageHeading = { 'Self-Check' => nil, 'Exam' => nil }
    # The current unit's page contents, keyed by page type.
    # Files are only written out once the whole run has finished.
    @page_content = { 'Self-Check' => +'', 'Exam' => +'' }
  end

  def unit
    @currUnit.match(/[A-Za-z]+/).to_s
  end

  def currFile(file)
    @currFile = file
  end

  def currUnit(unit)
    @currUnit = unit
  end

  def currUnitNum(num)
    @currUnitNum = num
  end

  def currUnitName(str)
    @currUnitName = str
  end

  def self_check_file_name
    "unit-#{@currUnitNum}-self-check#{@language_ext}.html"
  end

  def exam_file_name
    "unit-#{@currUnitNum}-exam-reference#{@language_ext}.html"
  end

  def box_num(num)
    @box_num = num
  end

  def read_file(file)
    return unless File.exist?(file)

    currFile(file)
    # puts "Reading file: #{file}"
    doc = File.open(file) { |f| Nokogiri::HTML(f) }
    parse_unit(doc)
    extract_self_checks(doc)
    extract_ap_exam_blocks(doc)
    puts "Completed self-check and exam data for: #{@currUnit}"
  end

  def parse_unit(doc)
    currUnit(doc.xpath('//title').to_s.split(%r{</?\w+>}).join)
    currUnitNum(@currUnit.match(/\d+/).to_s)
  end

  def extract_self_checks(doc)
    self_checks = doc.xpath("//div[contains(@class, 'assessment-data')]")
    return if self_checks.empty?

    # puts "Found #{self_checks.length} self-check sets in" if !self_checks.empty?
    self_checks.each do |node|
      response_id = node.attributes['responseidentifier'].value
      raise 'Response identifier is missing or not unique.' if response_id.nil? || response_id.empty?

      # Find child of the node that contains the responseDeclaration.
      # If the responseDeclaration is not found, raise an error.
      response_node = node.xpath(".//div[@class='responseDeclaration']")
      raise "Response node is missing for response identifier: #{response_id}" if response_node.empty?

      response_node = response_node.first
      response_div_identifier = response_node.attributes['identifier'].value
      if response_div_identifier != response_id
        raise "Response id mismatch: expected '#{response_id}' found '#{response_div_identifier}'"
      end

      unique_id = "#{response_id}_#{unit_reference.tr('.', '_')}"
      # Update both the container div and the responseDeclaration with the unique identifier.
      response_node.attributes['identifier'].value = unique_id
      node.attributes['responseidentifier'].value = unique_id
      node.children.before(<<~HTML
        <div class="additional-info">
          #{add_unit_to_header}
        </div>
      HTML
                          )
    end

    add_assessment_to_file(self_checks.to_html)
  end

  def extract_ap_exam_blocks(doc)
    on_exam_boxes = doc.xpath("//div[contains(@class, 'examFullWidth')]")
    return if on_exam_boxes.empty?

    on_exam_boxes.each do |node|
      node['class'] = 'exam summaryBox'
      node.children.before(add_unit_to_header)
    end

    add_exam_to_file(on_exam_boxes.to_s)
  end

  def summary_page_preamble(type)
    title = "#{I18n.t('unit', num: @currUnitNum)} #{I18n.t(type.downcase.tr('-', '_'))}"
    BJCHelpers.summary_page_prefix(@language, title)
  end

  # Returns { destination_path => contents } for this unit's self-check and
  # exam reference pages, then resets the buffers for the next unit.
  # Nothing is written to disk here.
  def finalize_unit(unit_dir)
    pending = {}
    { 'Self-Check' => self_check_file_name, 'Exam' => exam_file_name }.each do |type, file_name|
      next if @page_content[type].empty?

      pending[File.join(unit_dir, file_name)] = @page_content[type] + BJCHelpers.summary_page_suffix
      @page_content[type] = +''
      @priorPageHeading[type] = nil
    end
    pending
  end

  def add_content_to_file(data, type)
    content = @page_content[type]
    content << summary_page_preamble(type) if content.empty?

    data = data.gsub('&amp;', '&')
    if @priorPageHeading[type] != currLab
      content << "<h2>#{currLab}</h2>\n"
      @priorPageHeading[type] = currLab
    end
    content << data
  end

  def add_unit_to_header
    page_number = BJCHelpers.lab_page_number(@currUnit)
    box_num(@box_num + 1)
    link = "#{url_for(@currFile)}#{topic_url_suffix}#box#{@box_num}"
    " #{I18n.t('from')} <a href=\"#{link}\"><strong>#{page_number}</strong></a>"
  end

  def add_assessment_to_file(result)
    add_content_to_file(result, 'Self-Check')
  end

  def add_exam_to_file(exam)
    add_content_to_file(exam, 'Exam')
  end
end
