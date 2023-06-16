require 'fileutils'
require 'rio'
require 'nokogiri'
require 'twitter_cldr'

require_relative 'vocab'
require_relative 'main'
require_relative 'atwork'

FILE_NAME = 'vocab-index'

class Index
    def initialize(path, language="en")
        @parentDir = path
        @language = language
        @vocabList = []
        @vocabDict = {}
    end

    def language_ext
		@language_ext ||= @language == 'en' ? '' : ".#{@language}"
	end

    def index_filename
        "#{FILE_NAME}#{language_ext}.html"
    end

    def vocabList(list)
        @vocabList = list
    end

    def vocabDict(dict)
        @vocabDict = dict
    end

    def getAlphabet()
        if @language == "es"
            alphabet = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "ñ", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]
        else
            alphabet = ('a'..'z').to_a
        end
    end

    def generateAlphaOrder(usedLetters, output)
        alphabet = getAlphabet()
        File.write(index_filename, "\n<div class=\"index-letter-link\">\n", mode: "a")
        #i = 0
        #while alphabet.length > i
        #    File.write(index_filename, "<a href=\"##{alphabet[i].upcase}\">#{alphabet[i].upcase}</a>&nbsp;\n", mode: "a")
        #    i += 1
        #end
        linksUnusedLetters(usedLetters).each do |letter|
            File.write(index_filename, letter, mode: "a")
        end
        File.write(index_filename, "\n<\/div>\n<div>\n", mode: "a")
        File.write(index_filename, output, mode: "a")
    end

    def isNonEngChar(vocab, usedLetters)
        return !(isCapital?(vocab[0]) or isLowercase?(vocab[0]))
        #return usedLetters.localize(@language).compare(usedLetters[-1], vocab[0]).abs() == 1
    end
    def isCapital?(char)
        return (char.bytes[0] >= 65 and char.bytes[0] <= 90)
    end

    def isLowercase?(char)
        return (char.bytes[0] >= 97 and char.bytes[0] <= 122)
    end

    # alphabet and letter are lowercase and returned vocab word is upper and then lowercase
    def castCharToEng(vocab, usedLetters)
        collator = TwitterCldr::Collation::Collator.new(@language)
        if isNonEngChar(vocab, usedLetters)
            letter = vocab[0].downcase
            alpha = getAlphabet().push(letter).localize(@language).sort.to_a
            newLetter = alpha[alpha.index(letter) + 1]
            if isCapital?(vocab[0])
                newLeter = newLetter.upcase
            end
            return newLetter.upcase + vocab[1..]
        else
            return vocab
        end
    end

    def linksUnusedLetters(usedLetters)
        unused = getAlphabet().map{|letter| usedLetters.include?(letter) }
        links = []
        #link = (fileName, "<a href=\"##{alphabet[i].upcase}\">#{alphabet[i].upcase}</a>&nbsp;\n", mode: "a")
        i = 0
        while i < unused.length
            newBool = unused[i]
            j = i
            letter = getAlphabet()[i]
            while !newBool and j > 0
                j -= 1
                newBool = unused[j]
            end
            newLetter = getAlphabet()[j]
            links.append("<a href=\"##{newLetter.upcase}\">#{letter.upcase}</a>&nbsp;\n")
            i += 1
        end
        return links
    end


    def addIndex()
        alphabet = getAlphabet()
        filtered = @vocabList.filter {|item| item != nil && item != "" && alphabet.include?(item[0].downcase)}
        sorted = filtered.localize(@language).sort.to_a
        i = 0
        usedLetters = []
        output = "<ul style=\"list-style-type:square\">\n"
        while i < sorted.length
            vocab = sorted[i].gsub(": ", "")
            if !keepCapitalized?(vocab)
                vocab = vocab.downcase
            end
            letter = vocab[0]
            if !usedLetters.empty? && isNonEngChar(vocab, usedLetters)
                vocab = castCharToEng(vocab, usedLetters)
                letter = vocab[0]
            end
            if usedLetters.empty? or not(usedLetters.include?(letter.downcase))
                usedLetters.push(letter.downcase)
                output += "\n<div class=\"index-letter-target\"><p>#{letter.upcase}<a class=\"anchor\" name=\"#{letter.upcase}\">&nbsp;</a></p></div>\n"
            end
            list = @vocabDict[sorted[i]]
            outputLinks =  list.map{|elem| (list.index(elem) == list.length - 1 && list.length > 1)  ? ", #{elem}" : " #{elem}" }.join()
            output += "<li>#{vocab}#{outputLinks}</li>\n"
            i += 1
        end
        output += '</ul>'
        generateAlphaOrder(usedLetters, output)
    end

    def moveFile()
        src = "#{@parentDir}/review/#{index_filename}"
        dst = "#{@parentDir}/#{index_filename}"
        if File.exist?(dst)
            File.delete(dst)
        end
        FileUtils.copy_file(src, dst)
    end
    def main()
        filePath = "#{@parentDir}/review"
        Dir.chdir(filePath)
        files = Dir.glob("*html").select {|f| File.file? f}
        createNewIndexFile(files[0], filePath)
        #generateAlphaOrder()
        addIndex()
        add_HTML_end()
        moveFile()
    end

    def createNewIndexFile(copyFile, filePath)
        i = 0
        File.new(index_filename, "a")
        linesList =  rio("#{filePath}/#{copyFile}").lines[0..20]
        while (not(linesList[i].match(/<\/head>/)) and i < 20)
            if linesList[i].match(/<title>/)
                File.write(index_filename, "<title>BJC Curriculum Index</title>", mode: "a")
            else
                File.write(index_filename, "#{linesList[i]}", mode: "a")
            end
            i += 1
        end
        File.write(index_filename, "\n</head>\n<body>\n", mode:"a")
    end

    def add_HTML_end()
        ending = "</div>\n</body>\n</html>"
        if File.exist?(index_filename)
            File.write(index_filename, ending, mode: "a")
        end
    end

    def keepCapitalized?(vocab)
        capitals = ["Moore's", "IP", "DDoS", "SSL", "TLS", "TCP", "IA", "IPA", "PCT", "PI", "AI", "ADT", "API", "Creative Commons", "ISPs"]
        capitals.each do |item|
            if vocab.match?(item) #and (vocab == item or vocab.match?("#{item}\s") or vocab.match?("\s#{item}"))
                return true
            elsif vocab.match?(/\(.+\)/)
                return true
            end
        end
        return false
    end
end
