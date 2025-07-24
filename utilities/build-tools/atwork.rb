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
    @labPath = ''
    @currUnitName = nil
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

  def createNewFile(fileName, linesList)
    i = 0
    File.new(fileName, 'w')
    while !linesList[i].match(/<body>/) && (i < 30)
      if linesList[i].match(/<title>/)
        File.write(fileName, "<title>#{language}</title>\n", mode: 'a')
      else
        File.write(fileName, "#{linesList[i]}\n", mode: 'a')
      end
      i += 1
    end
  end

  def add_HTML_end
    Dir.chdir("#{@parentDir}/review")
    ending = "</body>\n</html>"
    return unless File.exist?(@atwork_filename)

    File.write(@atwork_filename, ending, mode: 'a')
  end

  def add_content_to_file(filename, data)
    currentDir = Dir.getwd
    linesList = File.readlines(@currFile)[0..15]
    Dir.chdir("#{@parentDir}/review")
    data = data.gsub(/&amp;/, '&')
    createNewFile(filename, linesList) unless File.exist?(filename)
    File.write(filename, data, mode: 'a')
    FileUtils.cd(currentDir)
  end

  def parse_atWork(file)
    doc = File.open(file) { |f| Nokogiri::HTML(f) }
    atWorkSet = doc.xpath("//div[@class = 'atwork']")
    atWorkSet.each do |node|
      child = node.children
      child.before(add_unit_to_atwork)
    end
    return if atWorkSet.empty?

    add_to_file(atWorkSet.to_s)
  end

  def add_unit_to_atwork
    unitNum = return_unit(@currUnit)
    currentDir = Dir.getwd
    FileUtils.cd('..')
    link = " <a href=\"#{get_url(@atwork_filename)}\">#{unitNum}</a>"
    FileUtils.cd(currentDir)
    link
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

    add_content_to_file(@atwork_filename, input)
  end

  def get_url(file)
    localPath = Dir.getwd
    linkPath = localPath.match(/bjc-r.+/).to_s
    "/#{linkPath}/#{file}"
  end

  def moveFile
    src = "#{@parentDir}/review/#{@atwork_filename}"
    dst = "#{@parentDir}/#{@atwork_filename}"
    return unless File.exist?(src)

    File.delete(dst) if File.exist?(dst)
    FileUtils.copy_file(src, dst)
  end
end
