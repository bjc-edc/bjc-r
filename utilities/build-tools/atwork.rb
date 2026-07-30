# frozen_string_literal: true

require 'nokogiri'

require_relative 'bjc_helpers'

# Collects every "Computer Scientists @ Work" box in a course onto one page.
# Unlike the vocab and self-check pages there is a single @ Work page per
# course, so content accumulates across every unit of a run.
class AtWork
  include BJCHelpers

  def initialize(path, language, content)
    @parentDir = path
    @language = language
    @content = content
    @currUnit = nil
    @currFile = nil
    @currLab = ''
    @currUnitNum = 0
    @currUnitName = nil
    @atwork_filename = "atwork#{language_ext(language)}.html"
    # The page contents, built up across the whole run.
    # The file is only written out once the run has finished.
    @page_content = +''
  end

  def currUnit(str)
    @currUnit = str
  end

  def currFile(file)
    @currFile = file
  end

  def currUnitNum(num)
    @currUnitNum = num
  end

  def currUnitName(str)
    @currUnitName = str
  end

  def read_file(file)
    return unless File.exist?(file)

    currFile(file)
    parse_unit(file)
    parse_atWork(file)
  end

  def parse_unit(file)
    doc = File.open(file) { |f| Nokogiri::HTML(f) }
    currUnit(doc.xpath('//title').to_s.split(%r{</?\w+>}).join)
    currUnitNum(@currUnit.match(/\d+/).to_s)
  end

  def page_title
    if @language == 'en'
      'Computer Scientists @ Work'
    elsif @language == 'es'
      'El Científico de la Computación @ Acción'
    end
  end

  # Returns { destination_path => contents } for the atwork page.
  # Nothing is written to disk here.
  #
  # The head used to be copied line by line out of whichever curriculum page
  # happened to hold the first atwork box, which never emitted the opening
  # <body> tag. Use the same template as every other generated summary page.
  def finalize
    return {} if @page_content.empty?

    { File.join(@parentDir, @atwork_filename) =>
        BJCHelpers.summary_page_template(@language, page_title, @page_content) }
  end

  def add_content_to_file(data)
    @page_content << data.gsub('&amp;', '&')
  end

  def parse_atWork(file)
    doc = File.open(file) { |f| Nokogiri::HTML(f) }
    atwork_boxes = doc.xpath("//div[@class = 'atwork']")
    return if atwork_boxes.empty?

    atwork_boxes.each { |node| node.children.before(add_unit_to_atwork) }
    add_content_to_file(atwork_boxes.to_s)
  end

  # The "1.2.3" reference that links each box back to the curriculum page it
  # came from, the same way the vocab and self-check pages do. This used to
  # link to "<unit folder>/atwork.html", which never exists: the only @ Work
  # page is the one this class generates in the course's content folder.
  def add_unit_to_atwork
    " <a href=\"#{page_url}\">#{unit_reference}</a>"
  end

  def page_url
    link_path = Dir.getwd.match(/bjc-r.+/).to_s
    "/#{link_path}/#{@currFile}"
  end
end
