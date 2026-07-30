# frozen_string_literal: true

require 'fileutils'
require 'nokogiri'
require 'i18n'

require_relative 'course'
require_relative 'index'
require_relative 'selfcheck'
require_relative 'bjc_helpers'

I18n.load_path = Dir['**/*.yml']
I18n.backend.load_translations

# TODO: It's unclear where the HTML for new files comes from.
# We should probably have a 'template' file which gets used.
# I think we can just replace content in the file, but we could use a library.
class Vocab
  include BJCHelpers

  VOCAB_CLASSES = %w[vocabFullWidth vocabBig vocab].freeze

  def initialize(path, language, content, course)
    @parentDir = path
    @language = language
    @content = content
    @course = course
    I18n.locale = @language.to_sym
    @currUnit = nil
    @currFile = nil
    @currUnitNum = 0
    @currLab = ''
    @vocabList = []
    @vocab_url_map = {}
    @currUnitName = nil
    @index = Index.new(@parentDir, @language)
    # TODO: See if we can remove this.
    @current_box_num = 0
    @language_ext = language_ext(language)
    # (For now) also store the current file content as a string, so we can write the file only once.
    @current_file_content = +''
    # This is actually a hash of units: labs: pages: [{word:, html:}]
    @vocab_by_page = {}
  end

  # Returns [destination_path, contents] for the curriculum vocab index.
  def doIndex
    @index.vocab_url_map = @vocab_url_map
    @index.vocabList(@vocabList)
    @index.main
  end

  def currUnitName(str)
    @currUnitName = str
  end

  def unit
    @currUnit.match(/[A-Za-z]+/).to_s
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

  def vocab_file_name
    "unit-#{@currUnitNum}-vocab#{@language_ext}.html"
  end

  # TODO: Collect the vocab into @vocab_by_page instead of straight into the
  # page buffer, so the unit pages and the index are built from one structure.
  def read_file(file)
    return unless File.exist?(file)

    currFile(file)
    parse_unit(file)
    parse_vocab(file)
    puts "Vocab Completed: #{@currUnit}"
  end

  def parse_unit(file)
    doc = File.open(file) { |f| Nokogiri::HTML(f) }
    title = doc.xpath('//title').to_s.split(%r{</?\w+>}).join
    return if title == @currUnit # still in the same unit

    currUnit(title)
    currUnitNum(@currUnit.match(/\d+/).to_s)
  end

  # The unit heading and the first lab heading of a brand new vocab page.
  def write_new_vocab_summary
    title = "#{unit} #{@currUnitNum} #{I18n.t('vocab')}"
    @current_file_content << BJCHelpers.summary_page_prefix(@language, title)
    @current_file_content << "<h2>#{@currUnitName}</h2>\n#{lab_heading}"
  end

  def lab_heading
    "<h3>#{currLab}</h3>\n"
  end

  # Returns { destination_path => contents } for this unit's vocab page,
  # then resets the buffer so the next unit starts a fresh file.
  # Nothing is written to disk here.
  def finalize_unit(unit_dir)
    return {} if @current_file_content.empty?

    contents = @current_file_content + BJCHelpers.summary_page_suffix
    @current_file_content = +''
    { File.join(unit_dir, vocab_file_name) => contents }
  end

  def add_content_to_file(data)
    previous_lab = @currLab
    if @current_file_content.empty?
      write_new_vocab_summary
    elsif previous_lab != currLab
      @current_file_content << lab_heading
    end
    @current_file_content << "#{data.gsub('&amp;', '&')}\n"
  end

  # might need to save index of line when i find the /div/ attribute
  # might be better to have other function to handle that bigger parsing of the whole file #with io.foreach
  def parse_vocab(file)
    doc = File.open(file) { |f| Nokogiri::HTML(f) }

    xpath_selector = VOCAB_CLASSES.map { |class_name| "//div[contains(@class, '#{class_name}')]" }.join(' | ')
    doc.xpath(xpath_selector).each do |node|
      node['class'] = 'vocab summaryBox'
      child = node.children
      child.before(add_vocab_unit_to_header) # if !child.to_a.include?(add_vocab_unit_to_header)
      get_vocab_word(node) # This saves the extracted term for later.
      # TODO: see if we can remove this tracking of the box number.
      @current_box_num += 1
      add_vocab_to_file(node.to_s)
    end
  end

  def get_vocab_word(node)
    extract_vocab_word(node.xpath('.//div//strong'))
    extract_vocab_word(node.xpath('.//li//strong'))
    extract_vocab_word(node.xpath('.//p//strong'))
  end

  def vocabExists?(list, word)
    [word, word.upcase, word.downcase, word.capitalize].intersect?(list)
  end

  def findVocab(word)
    list = @vocabList
    cases = %w[downcase upcase capitalize]
    return word if list.include?(word)

    vocab = cases.map { |item| word.method(item).call }.map { |vocab| list.include?(vocab) ? vocab : nil }
    vocab.find { |item| !item.nil? }
  end

  # TODO: We need to replace this with dedicated <dt> and <dd> tags in the HTML.
  # We should directly apply all index entries in HTML.
  def separateVocab(str)
    unless str.scan(/\(\w+\)/).empty? # looking for strings in parathesis such as: (API), (AI)
      abbreviation = str.scan(/\(\w+\)/)[0][1..-2]
      saveVocabWord(abbreviation)

      str = str.gsub("(#{abbreviation})", '').strip
    end
    if !str.scan(' or ').empty? # looking for strings with "or" in them: antivirus or antimalware
      iterateVocab(str.split(' or '))
    elsif !str.scan(' o ').empty? # looking for string with "or" in them in spanish
      iterateVocab(str.split(' o '))
    end
    return unless str.split.length > 1 # looking for strings with multiple words: articial intelligence

    list = str.split
    saveVocabWord("#{list[-1]}, #{list[0..-2].join(' ')}")
  end

  def iterateVocab(list)
    str = list.join(' ')
    vList = list
    if /^((?!(\(.*\))).)*/.match?(str) # str has parethesis with multiple words
      vList = str.match(/^((?!(\(.*\))).)*/).to_s.split
    end
    vList.each do |vocab|
      saveVocabWord(vocab) if !vocab.match?(/^(\s+)/) && (vocab != '') && !vocab.include?('(')
    end
  end

  # Skip removing 'the' from these words.
  # TODO: Does this need to handle spanish?
  SPECIAL_ARTICLES = ['the cloud', 'cloud, the'].freeze
  def removeArticles(vocab)
    return vocab if SPECIAL_ARTICLES.include?(vocab.downcase)

    vList = vocab.split
    articles = %w[el la las los the]
    plurals = articles.map(&:capitalize)
    if articles.include?(vList[0]) || plurals.include?(vList[0])
      vList = vList[1..]
      vList.include?(',') ? vList[..vList.index(',')] : vList
      vList.join(' ')
    elsif articles.include?(vList[-1]) || plurals.include?(vList[-1])
      vList = vList[..-1]
      vList.include?(',') ? vList[..vList.index(',')] : vList
      vList.join(' ')
    else
      vocab
    end
  end

  def extract_vocab_word(nodes)
    nodes.each do |node|
      o_node = node.to_s
      node = removeArticles(node.text.gsub(/(\s+)$/, '').to_s)
      if node == ''
        puts "Error: Empty vocab word extracted, original node: #{o_node}"
        next
      end
      saveVocabWord(node)
      separateVocab(node)
    end
  end

  def saveVocabWord(vocab)
    kludges = %w[T BI PI T]
    return if kludges.include?(vocab.upcase)

    if !vocabExists?(@vocabList, vocab)
      @vocabList.push(vocab)
      @vocab_url_map[vocab] = [add_vocab_unit_to_index]
    elsif @vocab_url_map[findVocab(vocab)].last != add_vocab_unit_to_index
      @vocab_url_map[findVocab(vocab)].append(add_vocab_unit_to_index)
    end
  end

  def add_vocab_unit_to_index
    path = get_prev_folder(Dir.pwd, include_path: true)
    "<a href=\"#{get_url(vocab_file_name, path)}#{topic_url_suffix}#box#{@current_box_num}\">#{unit_reference}</a>"
  end

  # NOTE: There should be no whitespace after the <a> tag so the `:` is right next to the link.
  def add_vocab_unit_to_header
    page_text = BJCHelpers.lab_page_number(@currUnit)
    # Capitalize the first letter of the page text
    # This really only makes a difference for the Spanish translation, since English is already capitalized.
    page_text = page_text.capitalize if @language == 'es'
    "<a href=\"#{get_url(@currFile,
                         Dir.pwd)}#{topic_url_suffix}\" id=\"box#{@current_box_num}\"><b>#{page_text}</b></a>"
  end

  def add_vocab_to_file(vocab)
    return unless vocab != ''

    add_content_to_file(vocab)
  end

  def get_url(file, localPath)
    linkPath = localPath.match(/bjc-r.+/).to_s
    "/#{linkPath}/#{file}"
  end
end
