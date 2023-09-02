require 'fileutils'
require 'i18n'

require_relative 'bjc_helpers'

TEMP_FOLDER = 'review'

I18n.load_path = Dir['**/*.yml']
I18n.backend.load_translations

class SelfCheck
  include BJCHelpers

  def initialize(path, language, content)
    @parentPath = path
    @currUnit = nil
    @content = content
    @isNewUnit = true
    @currUnitNum = 0
    @currLab = ''
    @vocab_file_name = ''
    @currUnitName = nil
    @language = language
    @language_ext = language_ext(language)
    I18n.locale = @language.to_sym
    @box_num = 0
  end

  def review_folder
    @review_folder ||= "#{@parentPath}/#{TEMP_FOLDER}"
  end

  def isNewUnit(boolean)
    @isNewUnit = boolean
  end

  def unit
    temp = @currUnit.match(/[A-Za-z]+/)
    temp.to_s
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
    isNewUnit(true)
    parse_unit(file)
    parse_assessmentData(file)
    parse_examData(file)
  end

  def parse_unit(file)
    doc = File.open(file) { |f| Nokogiri::HTML(f) }
    title = doc.xpath('//title')
    str = title.to_s
    pattern = %r{</?\w+>}
    if str.nil? || !@isNewUnit
      nil
    else
      newStr = str.split(pattern)
      currUnit(newStr.join)
      currUnitNum(@currUnit.match(/\d+/).to_s)
      isNewUnit(false)
    end
  end

  def parse_assessmentData(file)
    doc = File.open(file) { |f| Nokogiri::HTML(f) }
    selfcheckSet = doc.xpath("//div[@class = 'assessment-data']")
    # header = parse_vocab_header(doc.xpath(""))
    selfcheckSet.each do |node|
      child = node.children
      child.before(add_unit_to_header)
    end
    return if selfcheckSet.empty?

    add_assessment_to_file(selfcheckSet.to_s)
  end

  def parse_examData(file)
    doc = File.open(file) { |f| Nokogiri::HTML(f) }
    examSet = doc.xpath("//div[@class = 'examFullWidth']")
    # header = parse_vocab_header(doc.xpath(""))
    examSet.each do |node|
      child = node.children
      node.kwattr_add("style", "width: 95%")
      child.before(add_unit_to_header)
      # node.content.gsub(/\n\n/, "\n")
    end
    return if examSet.empty?

    add_exam_to_file(examSet.to_s)
  end

  def createAssessmentDataFile(fileName, type)
    i = 0
    File.new(fileName, 'w') unless File.exist?(fileName)
    linesList = File.readlines(@currFile)[0..15]
    while linesList[i].match(/<body>/).nil?
      if linesList[i].match(/<title>/)
        # TODO: Use I18n.t() here.
        if @language == 'en'
          File.write(fileName, "<title>Unit #{@currUnitNum} #{type} Questions</title>\n", mode: 'a')
        else
          translatedType = if type == 'Self-Check'
                             'Preguntas de Autocomprobacion'
                           else
                             'Examen AP'
                           end
          File.write(fileName, "<title>Unidad #{@currUnitNum} #{translatedType}</title>\n", mode: 'a')
        end
      else
        File.write(fileName, "#{linesList[i]}\n", mode: 'a')
      end
      i += 1
    end
    File.write(fileName, "<h2>#{@currUnitName}</h2>\n", mode: 'a')
    File.write(fileName, "<h3>#{currLab}</h3>\n", mode: 'a')
  end

  def add_HTML_end
    Dir.chdir(review_folder)
    ending = "\t</body>\n</html>"
    File.write(self_check_file_name, ending, mode: 'a') if File.exist?(self_check_file_name)
    return unless File.exist?(exam_file_name)

    File.write(exam_file_name, ending, mode: 'a')

    # doesexam_file_name exist?
    # File.write(exam_file_name, ending, mode: "a")
  end

  def add_content_to_file(filename, data, type)
    lab = @currLab
    data = data.gsub(/&amp;/, '&')
    data.delete!("\n\n\\")
    # data = data.gsub(/\n(\s+)?\n/, "\n")
    if File.exist?(filename)
      File.write(filename, "<h3>#{currLab}</h3>\n", mode: 'a') if lab != currLab
    else
      createAssessmentDataFile(filename, type)
    end
    File.write(filename, data, mode: 'a')
  end

  def add_unit_to_header
    unitNum = return_unit(@currUnit)
    box_num(@box_num + 1)
    suffix = generate_url_suffix(TOPIC_COURSE[0], get_prev_folder(Dir.pwd), TOPIC_COURSE[1])
    #" <a href=\"#{get_url(@currFile)}#box#{@box_num}#{suffix}\">#{unitNum}</a>"
    " <a href=\"#{get_url(@currFile)}#{suffix}#box#{@box_num}\"><b>#{unitNum}</b></a>"
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
    result = "/#{linkPath}/#{file}"
    # add_content_to_file('urlLinks.txt', result)
  end
end
