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

    def addIndex()
        fileName = 'index.html'
        sorted = @vocabList.sort()
        i = 0
        while i <= sorted.length
            values = @vocabDict[sorted[i]]
            if sorted[i] != ''
                File.write(fileName, "#{sorted[i]}, #{values}\n", mode: "a")
            end
            i += 1
        end
    end
    
    def main()
        filePath = "#{@parentDir}/review"
        Dir.chdir(filePath)
        files = Dir.glob("*html").select {|f| File.file? f}
        createNewIndexFile(files[0], filePath)
        addIndex()
        add_HTML_end()
    end

    def createNewIndexFile(copyFile, filePath)
    	i = 0
        fileName = 'index.html'
		if not(File.exist?(fileName))
			#Dir.chdir("#{@parentDir}/review")
			File.new(fileName, "a")
		end
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
		ending = "</body>\n</html>"
		if File.exist?('index.html')
			File.write('index.html', ending, mode: "a")
		end
	end

end