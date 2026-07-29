require 'fileutils'
require 'nokogiri'

class AtWork
  def initialize(path, language = 'en', content)
    @parentDir = path
    @language = language
    @content = content
    @currUnit = nil
    @currFile = nil
    @isNewUnit = true
    @currUnitNum = 0
    @currLab = ''
    @atwork_filename = "atwork#{language_ext}.html"
    @currUnitName = nil
    # The page contents, built up across the whole run.
    # The file is only written out once the run has finished.
    @content = +''
  end

  def language_ext
    @language_ext ||= @language == 'en' ? '' : ".#{@language}"
  end

  def unit
    temp = @currUnit.match(/[A-Za-z]+/)
    temp.to_s
  end

  def currUnit(str)
    @currUnit = str
  end

  def currFile(file)
    @currFile = file
  end

  def currUnitName(str)
    @currUnitName = str
  end

  def isNewUnit(boolean)
    @isNewUnit = boolean
  end

  def currUnitNum(num)
    @currUnitNum = num
  end

  def currLab
    return if @currUnit.nil?

    labMatch = @currUnit.match(/Lab.+,/)
    labList =  labMatch.to_s.split(/,/)
    @currLab = labList.join
  end

  def read_file(file)
    return unless File.exist?(file)

    isNewUnit(true)
    currFile(file)
    parse_unit(file)
    parse_atWork(file)
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
      unit
      isNewUnit(false)
    end
  end

  def language
    if @language == 'en'
      'Computer Scientists @ Work'
    elsif @language == 'es'
      'El Científico de la Computación @ Acción'
    end
  end

  # The page head, copied from the first curriculum page with an atwork box.
  def page_preamble(linesList)
    preamble = +''
    i = 0
    while !linesList[i].match(/<body>/) && (i < 30)
      if linesList[i].match(/<title>/)
        preamble << "<title>#{language}</title>\n"
      else
        preamble << "#{linesList[i]}\n"
      end
      i += 1
    end
    preamble
  end

  # Returns { destination_path => contents } for the atwork page.
  # Nothing is written to disk here.
  def finalize
    return {} if @content.empty?

    { File.join(@parentDir, @atwork_filename) => @content + "</body>\n</html>\n" }
  end

  def add_content_to_file(data)
    @content << page_preamble(File.readlines(@currFile)[0..15]) if @content.empty?
    @content << data.gsub(/&amp;/, '&')
  end

  def parse_atWork(file)
    doc = File.open(file) { |f| Nokogiri::HTML(f) }
    atWorkSet = doc.xpath("//div[@class = 'atwork']")
    atWorkSet.each do |node|
      child = node.children
      child.before(add_unit_to_header)
    end
    return if atWorkSet.empty?

    add_to_file(atWorkSet.to_s)
  end

  def add_unit_to_header
    unitNum = return_unit(@currUnit)
    " <a href=\"#{get_url(@currFile)}\">#{unitNum}</a>"
  end

  def return_unit(str)
    list = str.scan(/(\d+)/)
    list.join('.')
  end

  def add_to_file(input)
    return unless input != ''

    add_content_to_file(input)
  end

  def get_url(file)
    localPath = Dir.getwd
    linkPath = localPath.match(/bjc-r.+/).to_s
    "/#{linkPath}/#{file}"
  end
end
