require 'fileutils'
require 'nokogiri'
require 'i18n'

require_relative 'course'
require_relative 'index'
require_relative 'selfcheck'

I18n.load_path = Dir['**/*.yml']
I18n.backend.load_translations
TEMP_FOLDER = 'review'

# TODO: It's unclear where the HTML for new files comes from.
# We should probably have a 'template' file which gets used.
# I think we can just replace content in the file, but we could use a library.
class Vocab
  include BJCHelpers
  
  def initialize(path, language = 'en', content, course)
    @parentDir = path
    @language = language
    @content = content
    @course = course
    I18n.locale = @language.to_sym
    @currUnit = nil
    @currFile = nil
    @isNewUnit = true
    @currUnitNum = 0
    @currLab = ''
    @vocabList = []
    @vocabDict = {}
    @labPath = ''
    @currUnitName = nil
    @index = Index.new(@parentDir, @language)
    @boxNum = 0
    @language_ext = language_ext(language)
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

  def isNewUnit(boolean)
    @isNewUnit = boolean
  end

  def currUnitNum(num)
    @currUnitNum = num
  end

  def boxNum(num)
    @boxNum = num
  end

  def currLab
    return if @currUnit.nil?
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

  def read_file(file)
    return unless File.exist?(file)
    currFile(file)
    parse_unit(file)
    parse_vocab(file)
    puts "Completed: #{@currUnit}"
  end

  def topic_files_in_course
    @topic_files_in_course ||= @course.list_topics_no_path.filter { |file| file.match(/\d+-\w+/)}
  end

  def parse_unit(file)
    doc = File.open(file) { |f| Nokogiri::HTML(f) }
    title = doc.xpath('//title')
    str = title.to_s
    pattern = %r{</?\w+>}
    if str.nil?
      isNewUnit(false)
      nil
    else
      newStr = str.split(pattern)
      if newStr.join == @currUnit
        isNewUnit(false)
      else
        currUnit(newStr.join)
        currUnitNum(@currUnit.match(/\d+/).to_s)
        isNewUnit(true)
      end
    end
  end

  def createNewVocabFile(fileName)
    i = 0
    file_path = Dir.getwd
    unless File.exist?(fileName)
      Dir.chdir(review_folder)
      File.new(fileName, 'w')
    end
    f = File.open(fileName, mode: 'a')
    linesList = File.readlines("#{file_path}/#{@currFile}")[0..30]
    while !linesList[i].match(/<body>/) && (i < 30)
      if linesList[i].match(/<title>/)
        f.write("<title>#{unit} #{@currUnitNum} #{I18n.t('vocab')}</title>\n")
      else
        f.write("#{linesList[i]}\n")
      end
      i += 1
    end
    f.write("<h2>#{@currUnitName}</h2>\n<h3>#{currLab}</h3>\n")
    f.close
    Dir.chdir(file_path)
  end

  def add_HTML_end
    Dir.chdir(review_folder)
    ending = "</body>\n</html>"
    return unless File.exist?(vocab_file_name)

    File.write(vocab_file_name, ending, mode: 'a')
  end

  def add_content_to_file(filename, data)
    lab = @currLab
    data = data.gsub(/&amp;/, '&')
    data.delete!("\n\n\\")
    if File.exist?(filename)
      f = File.open(filename, mode: 'a') 
      f.write("<h3>#{currLab}</h3>") if lab != currLab
      f.close
    else
      createNewVocabFile(filename)
    end
    f = File.open(filename, mode: 'a') 
    f.write(data)
    f.close
  end

  #re-formatting the margins of the vocab boxes some there is less whitespace on vocab pages
  def reformat(file)
  end

  # might need to save index of line when i find the /div/ attribute
  # might be better to have other function to handle that bigger parsing of the whole file #with io.foreach
  def parse_vocab(file)
    doc = File.open(file) { |f| Nokogiri::HTML(f) }
    vocab_full_size = ["'vocabFullWidth'", "'vocabFullWidth AP-only'"]
    vocab_partial_size = ["'vocabBig'", "'vocab'"]

    vocab_full_size.each do |class_tag|
      path = "//div[@class = #{class_tag}]"
      vocab_set = doc.xpath("//div[@class = #{class_tag}]")
      if vocab_set.to_s != ""
        vocab_set.each do |node|
          child = node.children
          node.kwattr_add("style", "width: 95%")
          child.before(add_vocab_unit_to_header) #if !child.to_a.include?(add_vocab_unit_to_header)
          get_vocab_word(node)
          boxNum(1 + @boxNum)
        end
      add_vocab_to_file(vocab_set.to_s)
      end
    end

    vocab_partial_size.each do |class_tag|
      vocab_set2 = doc.xpath("//div[@class = #{class_tag}]")
      if vocab_set2.to_s != ""
        vocab_set2.each do |node|
          child = node.children
          change_to_vocabFullWidth(vocab_set2, node['class'])
          node.kwattr_add("style", "width: 95%")
          child.before(add_vocab_unit_to_header) #if !child.to_a.include?(add_vocab_unit_to_header)
          get_vocab_word(node)
          boxNum(1 + @boxNum)
        end
        add_vocab_to_file(vocab_set2.to_s)
      end
    end
  end

  def change_to_vocabFullWidth(vocab_set, clas)
    return unless %w[vocabBig vocab].include?(clas)

    vocab_set.remove_class(clas)
    vocab_set.add_class('vocabFullWidth')
  end

  def get_vocab_word(nodeSet)
    extract_vocab_word(nodeSet.xpath('.//div//strong'))
    extract_vocab_word(nodeSet.xpath('.//li//strong'))
    extract_vocab_word(nodeSet.xpath('.//p//strong'))
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

  def extract_vocab_word(nodeSet)
    nodeSet.each do |n|
      kludges = ['the cloud', 'cloud, the']
      kludges.include?(n.to_s.downcase) ? node = n : node = removeArticles(n.text.gsub(/(\s+)$/, '').to_s)
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
    topic_files = topic_files_in_course.filter {|f| f.match(unit_num)}[0]
  end

  def add_vocab_unit_to_index
    unit = return_vocab_unit(@currUnit)
    suffix = generate_url_suffix(TOPIC_COURSE[0], get_topic_file, TOPIC_COURSE[-1])
    path = get_prev_folder(Dir.pwd, true)
    " <a href=\"#{get_url(vocab_file_name, path)}#{suffix}#box#{@boxNum}\">#{unit}</a>"
  end

  def add_vocab_unit_to_header
    unit = return_vocab_unit(@currUnit)
    suffix = generate_url_suffix(TOPIC_COURSE[0], get_topic_file, TOPIC_COURSE[-1])
    "<a name=\"box#{@boxNum}\"</a>
    <a href=\"#{get_url(@currFile, Dir.pwd)}#{suffix}\"><b> #{unit}</b></a>"
  end

  # need something to call this function and parse_unit
  def return_vocab_unit(str)
    list = str.scan(/(\d+)/)
    list.join('.')
  end

  def add_vocab_to_file(vocab)
    return unless vocab != ''

    file = "#{review_folder}/#{vocab_file_name}"
    add_content_to_file(file, vocab)
  end

  def get_url(file, localPath)
    linkPath = localPath.match(/bjc-r.+/).to_s
    result = "/#{linkPath}/#{file}"
  end
end