require 'fileutils'
require 'i18n'

require_relative 'course'
require_relative 'bjc_helpers'

I18n.load_path = Dir['**/*.yml']
I18n.backend.load_translations

class SelfCheck
  include BJCHelpers

  def initialize(path, language, content, course)
    @parentPath = path
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
    # Track the previous lab/section heading for the self-check+exam page. If it changes, then we need to insert a newpage heading.
    @priorPageHeading = { 'Self-Check' => nil, 'Exam' => nil }
  end

  def review_folder
    @review_folder ||= "#{@parentPath}/#{TEMP_FOLDER}"
  end

  def unit
    @currUnit.match(/[A-Za-z]+/).to_s
  end

  def currFile(file)
    @currFile = file
  end

  def currLab
    return if @currUnit.nil?

    labMatch = @currUnit.match(/Lab.+,/)
    labList =  labMatch.to_s.split(/,/)
    @currLab = labList.join
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
    title = doc.xpath('//title').to_s
    return if title.nil?

    newtitle = title.split(%r{</?\w+>}) # TODO: cleanup
    currUnit(newtitle.join)
    currUnitNum(@currUnit.match(/\d+/).to_s)
  end

  def extract_self_checks(doc)
    self_checks = doc.xpath("//div[contains(@class, 'assessment-data')]")
    return if self_checks.empty?

    # puts "Found #{self_checks.length} self-check sets in" if !self_checks.empty?
    self_checks.each do |node|
      response_id = node.attributes['responseidentifier'].value
      if response_id.nil? || response_id.empty?
        raise "Response identifier is missing or not unique."
      end
      # Find child of the node that contains the responseDeclaration.
      # If the responseDeclaration is not found, raise an error.
      response_node = node.xpath(".//div[@class='responseDeclaration']")
      if response_node.empty?
        raise "Response node is missing for response identifier: #{response_id}"
      end
      response_node = response_node.first
      response_div_identifier = response_node.attributes['identifier'].value
      if response_div_identifier != response_id
        raise "Response id mismatch: expected '#{response_id}' found '#{response_div_identifier}'"
      end
      suffix = return_unit(@currUnit).gsub('.', '_')
      unique_id = "#{response_id}_#{suffix}"
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

  def create_summary_file(fileName, type)
    return if File.exist?(fileName)

    File.new(fileName, 'w')
    # puts "Creating summary file: #{fileName} for type: #{type}"

    page_preamble = <<~HTML
      <!DOCTYPE html>
      <html lang="#{@language}">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>#{I18n.t('unit', num: @currUnitNum)} #{I18n.t(type.downcase.gsub('-', '_'))}</title>
        <script type="text/javascript" src="/bjc-r/llab/loader.js"></script>
        <script type="text/javascript" src="/bjc-r/utilities/gifffer.min.js"></script>
        <script type="text/javascript">window.onload = function() {Gifffer();}</script>
        <link rel="stylesheet" type="text/css" href="/bjc-r/css/bjc-gifffer.css">
      </head>
      <body>
    HTML
    File.write(fileName, page_preamble, mode: 'w')
  end

  def add_HTML_end
    Dir.chdir(review_folder)
    ending = "\n\t</body>\n</html>\n"
    File.write(self_check_file_name, ending, mode: 'a') if File.exist?(self_check_file_name)
    return unless File.exist?(exam_file_name)

    File.write(exam_file_name, ending, mode: 'a')
  end

  def add_content_to_file(filename, data, type)
    if !File.exist?(filename)
      create_summary_file(filename, type)
    end

    prior_heading = @priorPageHeading[type]
    data = data.gsub(/&amp;/, '&')
    if prior_heading != currLab
      File.write(filename, "<h2>#{currLab}</h2>\n", mode: 'a')
      @priorPageHeading[type] = currLab
    end
    File.write(filename, data, mode: 'a')
  end

  def topic_files_in_course
    @topic_files_in_course ||= @course.list_topics_no_path.filter { |file| file.match(/\d+-\w+/)}
  end

  def get_topic_file
    unit_reference = return_unit(@currUnit)
    unit_num = unit_reference.match(/\d+/).to_s
    topic_files_in_course.filter {|f| f.match(unit_num)}[0]
  end

  def add_unit_to_header
    page_number = BJCHelpers.lab_page_number(@currUnit)
    box_num(@box_num + 1)
    suffix = generate_url_suffix(TOPIC_COURSE[0], get_topic_file, TOPIC_COURSE[-1])
    " #{I18n.t('from')} <a href=\"#{get_url(@currFile)}#{suffix}#box#{@box_num}\"><strong>#{page_number}</strong></a>"
  end

  # need something to call this function and parse_unit
  def return_unit(str)
    list = str.scan(/(\d+)/)
    list.join('.')
  end

  def add_assessment_to_file(result)
    add_content_to_file("#{review_folder}/#{self_check_file_name}", result, 'Self-Check')
  end

  def add_exam_to_file(exam)
    add_content_to_file("#{review_folder}/#{exam_file_name}", exam, 'Exam')
  end

  def get_url(file)
    localPath = Dir.getwd
    linkPath = localPath.match(/bjc-r.+/).to_s
    "/#{linkPath}/#{file}"
  end
end
