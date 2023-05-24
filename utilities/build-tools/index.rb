require 'fileutils'
require 'rio'
require 'nokogiri'
require 'twitter_cldr'
require_relative 'vocab'
require_relative 'main'


class Index

    def initialize(path, language="en")
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

    def getAlphabet()
        if @language == "es"
            alphabet = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "ñ", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]
        else
            alphabet = ('a'..'z').to_a
        end
    end

    def generateAlphaOrder(usedLetters, output)
        fileName = "index.#{@language}.html"
        alphabet = getAlphabet()
        File.write(fileName, "\n<div class=\"index-letter-link\">\n", mode: "a")
        #i = 0
        #while alphabet.length > i
        #    File.write(fileName, "<a href=\"##{alphabet[i].upcase}\">#{alphabet[i].upcase}</a>&nbsp;\n", mode: "a")
        #    i += 1
        #end
        linksUnusedLetters(usedLetters).each do |letter|
            File.write(fileName, letter, mode: "a")
        end
        File.write(fileName, "\n<\/div>\n<div>\n", mode: "a")
        File.write(fileName, output, mode: "a")
    end

    def isNonEngChar(vocab, usedLetters)
        collator = TwitterCldr::Collation::Collator.new(@language)
        return (collator.compare(vocab[0].upcase, usedLetters[-1].upcase)).abs() == 1
        #return usedLetters.localize(@language).compare(usedLetters[-1], vocab[0]).abs() == 1
    end
    
    #alphabet and letter are lowercase and returned vocab word is upper and then lowercase
    def castCharToEng(vocab, usedLetters)
        collator = TwitterCldr::Collation::Collator.new(@language)
        if isNonEngChar(vocab, usedLetters)
            letter = vocab[0].downcase
            alpha = getAlphabet().push(letter).localize(@language).sort.to_a
            newLetter = alpha[alpha.index(letter) + 1]
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
        fileName = "index.#{@language}.html"
        #FastGettext.locale = @language
        #TwitterCldr.locale 
        sorted = @vocabList.localize(@language).sort.to_a
        alphabet = getAlphabet() 
        i = 0
        usedLetters = []
        output = "<ul style=\"list-style-type:square\">\n"
        #File.write(fileName, "<ul style=\"list-style-type:square\">\n", mode: "a")
        while i < sorted.length
            if sorted[i] != nil and sorted[i] != "" and alphabet.include?(sorted[i][0].downcase)
                vocab = sorted[i].gsub(": ", "")
                letter = vocab[0]
                if !usedLetters.empty? && isNonEngChar(vocab, usedLetters)
                    vocab = castCharToEng(vocab, usedLetters)
                    letter = vocab[0]
                end
                if usedLetters.empty? or not(usedLetters.include?(letter.downcase))
                    usedLetters.push(letter.downcase)
                    output += "\n<div class=\"index-letter-target\"><p>#{letter.upcase}<a class=\"anchor\" name=\"#{vocab[0].upcase}\">&nbsp;</a></p></div>\n"
                    #File.write(fileName, "\n<div class=\"index-letter-target\"><p>#{letter.upcase}<a class=\"anchor\" name=\"#{vocab[0].upcase}\">&nbsp;</a></p></div>\n", mode: "a")
                end
                
                #values = @vocabDict[sorted[i]]
                #@vocabDict[sorted[i]].map{|elem| ", #{elem}"}.join()
                list = @vocabDict[sorted[i]]
                outputLinks =  list.map{|elem| (list.index(elem) == list.length - 1)  ? " #{elem}" : " ,#{elem}" }.join()

                #File.write(fileName, "<li>#{vocab}#{outputLinks}</li>\n", mode: "a")
               # File.write(fileName, "<li>#{vocab}#{outputLinks}</li>\n", mode: "a")
                output += "<li>#{vocab}#{outputLinks}</li>\n"
            end
            i += 1
        end
        #File.write(fileName, '</ul>', mode: "a")
        output += '</ul>'
        #linksUnusedLetters(usedLetters)
        generateAlphaOrder(usedLetters, output)
    end
    
    def main()
        filePath = "#{@parentDir}/review"
        Dir.chdir(filePath)
        files = Dir.glob("*html").select {|f| File.file? f}
        createNewIndexFile(files[0], filePath)
        #generateAlphaOrder()
        addIndex()
        add_HTML_end()
    end

    def createNewIndexFile(copyFile, filePath)
    	i = 0
        fileName = "index.#{@language}.html"
        File.new(fileName, "a")
		linesList =  rio("#{filePath}/#{copyFile}").lines[0..20]
		while (not(linesList[i].match(/<\/head>/)) and i < 20)
			if linesList[i].match(/<title>/)
				File.write(fileName, "<title>BJC Curriculum Index</title>", mode: "a")
			else
				File.write(fileName, "#{linesList[i]}", mode: "a")
			end
			i += 1
		end
        File.write(fileName, "\n</head>\n<body>\n", mode:"a")
    end
    
    def add_HTML_end()
		ending = "</div>\n</body>\n</html>"
		if File.exist?("index.#{@language}.html")
			File.write("index.#{@language}.html", ending, mode: "a")
		end
	end

end