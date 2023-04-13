require 'fileutils'
require 'rio'
require 'nokogiri'
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

    def generateAlphaOrder()
        fileName = "index.#{@language}.html"
        alphabet = getAlphabet()
        File.write(fileName, "\n<div class=\"index-letter-link\">\n", mode: "a")
        i = 0
        while alphabet.length > i
            File.write(fileName, "<a href=\"##{alphabet[i].upcase}\">#{alphabet[i].upcase}</a>&nbsp;\n", mode: "a")
            i += 1
        end
        File.write(fileName, "\n<\/div>\n<div>\n", mode: "a")
    end

    def addIndex()
        fileName = "index.#{@language}.html"
        sorted = @vocabList.sort
        i = 0
        usedLetters = []
        File.write(fileName, "<ul style=\"list-style-type:square\">\n", mode: "a")
        while i < sorted.length
            if sorted[i] != nil and sorted[i] != ""
                vocab = sorted[i].gsub(": ", "")
                if usedLetters.empty? or not(usedLetters.include?(vocab[0].downcase))
                    usedLetters.push(vocab[0].downcase)
                    File.write(fileName, "\n<div class=\"index-letter-target\"><p>#{vocab[0].upcase}<a class=\"anchor\" name=\"#{vocab[0].upcase}\">&nbsp;</a></p></div>\n", mode: "a")
                end
                values = @vocabDict[sorted[i]]
                outputLinks = ''
                j = 0
                while j < values.length
                    outputLinks += values[j]
                    j += 1
                end
                File.write(fileName, "<li>#{vocab}, #{outputLinks}</li>\n", mode: "a")
                
            end
            i += 1
        end
        File.write(fileName, '</ul>', mode: "a")
    end
    
    def main()
        filePath = "#{@parentDir}/review"
        Dir.chdir(filePath)
        files = Dir.glob("*html").select {|f| File.file? f}
        createNewIndexFile(files[0], filePath)
        generateAlphaOrder()
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