# frozen_string_literal: true

require 'fileutils'
require 'rio'
require 'nokogiri'
require 'twitter_cldr'
require_relative 'vocab'
require_relative 'main'

class Index
  def initialize(path, language = 'en')
    @parentDir = path
    @language = language
    @vocabList = []
    @vocabDict = {}
  end

  def vocabList(list)
    @vocabList = list
  end

  def vocabDict(dict)
    @vocabDict = dict
  end

  def getAlphabet
    if @language == 'es'
      %w[a b c d e f g h i j k l m n ñ o p q r
         s t u v w x y z]
    else
      ('a'..'z').to_a
    end
  end

  def generateAlphaOrder(usedLetters, output)
    fileName = "index.#{@language}.html"
    getAlphabet
    File.write(fileName, "\n<div class=\"index-letter-link\">\n", mode: 'a')
    # i = 0
    # while alphabet.length > i
    #    File.write(fileName, "<a href=\"##{alphabet[i].upcase}\">#{alphabet[i].upcase}</a>&nbsp;\n", mode: "a")
    #    i += 1
    # end
    linksUnusedLetters(usedLetters).each do |letter|
      File.write(fileName, letter, mode: 'a')
    end
    File.write(fileName, "\n<\/div>\n<div>\n", mode: 'a')
    File.write(fileName, output, mode: 'a')
  end

  def isNonEngChar(vocab, _usedLetters)
    !(isCapital?(vocab[0]) or isLowercase?(vocab[0]))
    # return usedLetters.localize(@language).compare(usedLetters[-1], vocab[0]).abs() == 1
  end

  def isCapital?(char)
    (char.bytes[0] >= 65 and char.bytes[0] <= 90)
  end

  def isLowercase?(char)
    (char.bytes[0] >= 97 and char.bytes[0] <= 122)
  end

  # alphabet and letter are lowercase and returned vocab word is upper and then lowercase
  def castCharToEng(vocab, usedLetters)
    TwitterCldr::Collation::Collator.new(@language)
    return vocab unless isNonEngChar(vocab, usedLetters)

    letter = vocab[0].downcase
    alpha = getAlphabet.push(letter).localize(@language).sort.to_a
    newLetter = alpha[alpha.index(letter) + 1]
    newLetter.upcase if isCapital?(vocab[0])
    newLetter.upcase + vocab[1..]
  end

  def linksUnusedLetters(usedLetters)
    unused = getAlphabet.map { |letter| usedLetters.include?(letter) }
    links = []
    # link = (fileName, "<a href=\"##{alphabet[i].upcase}\">#{alphabet[i].upcase}</a>&nbsp;\n", mode: "a")
    i = 0
    while i < unused.length
      newBool = unused[i]
      j = i
      letter = getAlphabet[i]
      while !newBool && j.positive?
        j -= 1
        newBool = unused[j]
      end
      newLetter = getAlphabet[j]
      links.append("<a href=\"##{newLetter.upcase}\">#{letter.upcase}</a>&nbsp;\n")
      i += 1
    end
    links
  end

  def addIndex
    alphabet = getAlphabet
    filtered = @vocabList.filter { |item| !item.nil? && item != '' && alphabet.include?(item[0].downcase) }
    sorted = filtered.localize(@language).sort.to_a
    i = 0
    usedLetters = []
    output = "<ul style=\"list-style-type:square\">\n"
    while i < sorted.length
      vocab = sorted[i].gsub(': ', '')
      vocab = vocab.downcase unless keepCapitalized?(vocab)
      letter = vocab[0]
      if !usedLetters.empty? && isNonEngChar(vocab, usedLetters)
        vocab = castCharToEng(vocab, usedLetters)
        letter = vocab[0]
      end
      if usedLetters.empty? || !usedLetters.include?(letter.downcase)
        usedLetters.push(letter.downcase)
        output += "\n<div class=\"index-letter-target\"><p>#{letter.upcase}<a class=\"anchor\" name=\"#{letter.upcase}\">&nbsp;</a></p></div>\n"
      end
      list = @vocabDict[sorted[i]]
      outputLinks = list.map do |elem|
        list.index(elem) == list.length - 1 && list.length > 1 ? ", #{elem}" : " #{elem}"
      end.join
      output += "<li>#{vocab}#{outputLinks}</li>\n"
      i += 1
    end
    output += '</ul>'
    generateAlphaOrder(usedLetters, output)
  end

  def moveFile
    src = "#{@parentDir}/review/index.#{@language}.html"
    dst = "#{@parentDir}/index.#{@language}.html"
    File.delete(dst) if File.exist?(dst)
    FileUtils.copy_file(src, dst)
  end

  def main
    filePath = "#{@parentDir}/review"
    Dir.chdir(filePath)
    files = Dir.glob('*html').select { |f| File.file? f }
    createNewIndexFile(files[0], filePath)
    # generateAlphaOrder()
    addIndex
    add_HTML_end
    moveFile
  end

  def createNewIndexFile(copyFile, filePath)
    i = 0
    fileName = "index.#{@language}.html"
    File.new(fileName, 'a')
    linesList = rio("#{filePath}/#{copyFile}").lines[0..20]
    while !linesList[i].match(%r{</head>}) && (i < 20)
      if linesList[i].match(/<title>/)
        File.write(fileName, '<title>BJC Curriculum Index</title>', mode: 'a')
      else
        File.write(fileName, (linesList[i]).to_s, mode: 'a')
      end
      i += 1
    end
    File.write(fileName, "\n</head>\n<body>\n", mode: 'a')
  end

  def add_HTML_end
    ending = "</div>\n</body>\n</html>"
    return unless File.exist?("index.#{@language}.html")

    File.write("index.#{@language}.html", ending, mode: 'a')
  end

  def keepCapitalized?(vocab)
    capitals = ["Moore's", 'IP', 'DDoS', 'SSL', 'TLS', 'TCP', 'IA', 'IPA', 'PCT', 'PI', 'AI', 'ADT', 'API',
                'Creative Commons', 'ISPs']
    capitals.each do |item|
      if vocab.match?(item) # and (vocab == item or vocab.match?("#{item}\s") or vocab.match?("\s#{item}"))
        return true
      elsif vocab.match?(/\(.+\)/)
        return true
      end
    end
    false
  end
end
