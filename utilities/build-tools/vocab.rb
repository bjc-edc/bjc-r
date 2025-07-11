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
  VOCAB_CLASSES = %w[vocabFullWidth vocabBig vocab]

  def initialize(path, language = 'en', content, course)
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
    @vocabDict = {}
    @labPath = ''
    @currUnitName = nil
    @index = Index.new(@parentDir, @language)
    # TODO: See if we can remove this.
    @current_box_num = 0
    @language_ext = language_ext(language)
    # (For now) also store the current file content as a string, so we can write the file only once.
    @current_file_content = ''
    # This is actually a hash of units: labs: pages: [{word:, html:}]
    @vocab_by_page = {}
  end

  def review_folder
    @review_folder ||= "#{@parentDir}/#{TEMP_FOLDER}"
  end

  def doIndex
    @index.vocabDict(@vocabDict)
    @index.vocabList(@vocabList)
    @index.main
  end

  def currUnitName(str)
    @currUnitName = str
  end

  def labPath(arg)
    @labPath = arg
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

  def currFile(file)
    @currFile = file
  end

  def currUnitNum(num)
    @currUnitNum = num
  end

  def currLab
    nil if @currUnit.nil?
  end

  def vocab_file_name
    "unit-#{@currUnitNum}-vocab#{@language_ext}.html"
  end

  def currLab
    return if @currUnit.nil?

    labMatch = @currUnit.match(/Lab.+,/)
    labList = labMatch.to_s.split(/,/)
    @currLab = labList.join
  end

  def process_curriculum_page(page)
    # Extract vocab from each page, then add to the @vocab_by_page hash
  end

  # Then:
  # def write_unit_summary_file(unit)
  #   # This method is not currently implemented.
  #   # Write the summary file for the unit.
  # end

  # Then write all vocab to the curriculum index file.
  # def write_curriculum_index_file; end

  def handle_new_unit(unit)
    @current_file_content = ''
    @current_box_num = 0 # Should this be per-unit?
    @currUnit = unit
    @currUnitNum = @currUnit.match(/\d+/).to_s
    write_new_vocab_summary(vocab_file_name)
  end

  # Write unit summary file.
  def end_of_unit(_unit)
    add_HTML_end
  end

  # TODO: Delete this after process_curriculum_page is fully implemented.
  def read_file(file)
    return unless File.exist?(file)

    currFile(file)
    parse_unit(file)
    parse_vocab(file)
    puts "Vocab Completed: #{@currUnit}"
  end

  def topic_files_in_course
    @topic_files_in_course ||= @course.list_topics_no_path.filter { |file| file.match(/\d+-\w+/) }
  end

  def parse_unit(file)
    doc = File.open(file) { |f| Nokogiri::HTML(f) }
    title = doc.xpath('//title')
    str = title.to_s
    pattern = %r{</?\w+>}
    if str.nil?
      nil
    else
      newStr = str.split(pattern)
      if newStr.join == @currUnit # same unit
      else
        currUnit(newStr.join)
        currUnitNum(@currUnit.match(/\d+/).to_s)
      end
    end
  end

  def write_new_vocab_summary(_file_name)
    title = "#{unit} #{@currUnitNum} #{I18n.t('vocab')}"
    @current_file_content << BJCHelpers.summary_page_prefix(@language, title)
    # "<h2>#{@currUnitName}</h2>\n<h3>#{currLab}</h3>\n"
    @current_file_content << "\n\t<h2>#{currLab}</h2>\n"

    # if File.exist?(file_name)
    #   puts "Appending to existing vocab file: #{file_name}"
    #   f = File.open(file_name, mode: 'a')
    #   f.write(@current_file_content)
    #   f.close
    # else
    #   Dir.mkdir(review_folder) unless Dir.exist?(review_folder)
    #   Dir.chdir(review_folder)
    #   puts "Creating new vocab file: #{file_name}"
    #   File.write(file_name, @current_file_content)
    # end
  end

  def add_HTML_end
    Dir.chdir(review_folder)
    # return unless File.exist?(vocab_file_name)
    @current_file_content << BJCHelpers.summary_page_suffix
    # binding.irb
    File.write(vocab_file_name, @current_file_content)
  end

  def add_content_to_file(filename, data)
    lab = @currLab
    data = data.gsub(/&amp;/, '&')
    if @current_file_content != ''
      @current_file_content << "\n\t<h2>#{currLab}</h2>\n" if lab != currLab
    else
      write_new_vocab_summary(filename)
    end
    @current_file_content << data
  end

  # might need to save index of line when i find the /div/ attribute
  # might be better to have other function to handle that bigger parsing of the whole file #with io.foreach
  def parse_vocab(file)
    doc = File.open(file) { |f| Nokogiri::HTML(f) }

    xpath_selector = VOCAB_CLASSES.map { |class_name| "//div[contains(@class, '#{class_name}')]" }.join(' | ')
    doc.xpath(xpath_selector).each do |node|
      node['class'] = 'vocab summaryBox'
      child = node.children
      child.before(add_vocab_unit_to_header)
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
    (list.include?(word) or list.include?(word.upcase) or list.include?(word.downcase) or list.include?(word.capitalize))
  end

  def findVocab(word)
    list = @vocabList
    cases = %w[downcase upcase capitalize]
    return word if list.include?(word)

    vocab = (cases.map { |item| word.method(item).call }).map { |vocab| list.include?(vocab) ? vocab : nil }
    vocab.find { |item| !item.nil? }
  end

  def separateVocab(str)
    unless str.scan(/\(\w+\)/).empty? # looking for strings in parathesis such as: (API), (AI)
      saveVocabWord(str.scan(/\(\w+\)/)[0][1..-2])
    end
    if !str.scan(/ or /).empty? # looking for strings with "or" in them: antivirus or antimalware
      iterateVocab(str.split(' or '))
    elsif !str.scan(/ o /).empty? # looking for string with "or" in them in spanish
      iterateVocab(str.split(' o '))
    end
    return unless str.split(' ').length > 1 # looking for strings with multiple words: articial intelligence

    list = str.split(' ')
    saveVocabWord("#{list[-1]}, #{list[0..-2].join(' ')}")
  end

  def iterateVocab(list)
    str = list.join(' ')
    vList = list
    if str.match(/^((?!(\(.*\))).)*/) # str has parethesis with multiple words
      vList = str.match(/^((?!(\(.*\))).)*/).to_s.split(' ')
    end
    vList.each do |vocab|
      saveVocabWord(vocab) if !vocab.match?(/^(\s+)/) && (vocab != '') && !vocab.match?(/\(/)
    end
  end

  def removeArticles(vocab)
    vList = vocab.split(' ')
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
      # Skip removing 'the' from these words.
      # TODO: Does this need to handle spanish?
      kludges = ['the cloud', 'cloud, the']
      node = removeArticles(node.text.gsub(/(\s+)$/, '').to_s) unless kludges.include?(node.to_s.downcase)
      saveVocabWord(node)
      separateVocab(node)
    end
  end

  def saveVocabWord(vocab)
    kludges = %w[T BI PI T]
    return if kludges.include?(vocab.upcase)

    if !vocabExists?(@vocabList, vocab)
      @vocabList.push(vocab)
      @vocabDict[vocab] = [add_vocab_unit_to_index]
    elsif @vocabDict[findVocab(vocab)].last != add_vocab_unit_to_index
      @vocabDict[findVocab(vocab)].append(add_vocab_unit_to_index)
    end
  end

  def parse_vocab_header(str)
    newStr1 = str
    if str.match(/vocabFullWidth/)
      newStr1 = str.gsub(/<!--.+-->/, '') if str.match(/<!--.+-->/)
      newStr2 = newStr1.to_s
      if newStr2.match(/<div class="vocabFullWidth">.+/)
        headerList = newStr2.split(/:/)
      else
        headerList = []
        headerList.push(str)
      end
      headerList
    else
      []
    end
  end

  def get_topic_file
    unit_reference = return_vocab_unit(@currUnit)
    unit_num = unit_reference.match(/\d+/).to_s
    topic_files_in_course.filter { |f| f.match(unit_num) }[0]
  end

  def add_vocab_unit_to_index(vocabTerm = '')
    unit = return_vocab_unit(@currUnit)
    suffix = generate_url_suffix(TOPIC_COURSE[0], get_topic_file, TOPIC_COURSE[-1])
    path = get_prev_folder(Dir.pwd, true)
    "<a href=\"#{get_url(vocab_file_name, path)}#{suffix}#box#{@current_box_num}\">#{unit}</a>"
  end

  # NOTE: There should be no whitespace after the <a> tag so the `:` is right next to the link.
  def add_vocab_unit_to_header
    page_text = BJCHelpers.lab_page_number(@currUnit)
    # Capitalize the first letter of the page text
    # This really only makes a difference for the Spanish translation, since English is already capitalized.
    page_text = page_text.capitalize if @language == 'es'
    suffix = generate_url_suffix(TOPIC_COURSE[0], get_topic_file, TOPIC_COURSE[-1])
    "<a name=\"box#{@current_box_num}\"</a>
    <a href=\"#{get_url(@currFile, Dir.pwd)}#{suffix}\"><b>#{page_text}</b></a>"
  end

  # need something to call this function and parse_unit
  def return_vocab_unit(str)
    list = str.scan(/(\d+)/)
    list.join('.')
  end

  # TODO: Use this to replace current_box_number in the HTML.
  def vocab_term_html_id(unit_str, vocab_term)
    unit_reference = return_vocab_unit(unit_str).gsub(/\./, '-')
    # TODO: is there anything we need to do to sanitize the vocab_term?
    "#{unit_reference}-#{vocab_term.gsub(/\s+/, '-').downcase}"
  end

  def add_vocab_to_file(vocab)
    return unless vocab != ''

    file = "#{review_folder}/#{vocab_file_name}"
    add_content_to_file(file, vocab)
  end

  def get_url(file, localPath)
    linkPath = localPath.match(/bjc-r.+/).to_s
    "/#{linkPath}/#{file}"
  end
end
