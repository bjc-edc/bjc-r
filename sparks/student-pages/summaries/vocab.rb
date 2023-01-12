require 'fileutils'
require 'rio'

class Vocab
	
	def initialize(path)
		@parentDir = path
		@currFile = nil
		@currIndex = 0
		@currPath = path
		@currUnit = nil
		@currFile = nil
		@currLine = ''
		@listLines = []
		@isNewUnit = true
		@currUnitNum = 0
		@currLab = ''
		@vocabFileName = ''
		@pastFileUnit = nil
	end

	def currUnit(str)
		@currUnit = str
	end

	def currFile(file)
		@currFile = file
	end

	def currIndex(i)
		@currIndex = i
	end

	def currFile(file)
		@currFile = file
	end

	def currLine(line)
		@currline = line
	end

	def listLines(file)
		@listLines = File.readlines(file)
	end

	def currPath(path)
		@currPath = path
	end

	def isNewUnit(boolean)
		@isNewUnit = boolean
	end

	def currUnitNum(num)
		@currUnitNum = num
	end

	def vocabFileName(name)
		@vocabFileName = name
	end

	def currLab()
		if @currUnit != nil
			labMatch = @currUnit.match(/Lab.+,/)
			labList =  labMatch.to_s.split(/,/)
			@currLab = labList.join
		end
	end

	def pastFileUnit(unit)
		@pastFileUnit = unit
	end

	def read_file(file)
		listLines(file)
		currIndex(0)
		currFile(file)
		isNewUnit(true)
		@listLines.each do |line|
			currLine(line)
			parse_unit(line)
			parse_vocab(file, @currline, @currIndex)
			currIndex(@currIndex + 1)
		end
		#puts "Completed:  #{@currUnit}"
	end


	def parse_unit(str)
		#pattern = /((\s?\w+\s?)+[:,\!](\s?\w+\s?)+)+\d+/
		pattern1 = /<title>.+<\/title>/
		pattern2 = /<\/?\w+>/
		if (str == nil or not(@isNewUnit))
			nil
		elsif str.match(pattern1)
			#add_to_file("Units.txt", str.match(pattern).to_s)
			match = str.match(pattern1).to_s
			newStr = match.split(pattern2)
			currUnit(newStr.join)
			currUnitNum(@currUnit.match(/\d+/).to_s)
			vocabFileName("vocab#{@currUnitNum}.html")
			isNewUnit(false)
		else
			nil
		end
	end

	def createNewVocabFile(fileName)
		i = 0
		if not(File.exist?(fileName))
			File.new(fileName, "w")
		end
		linesList =  rio(@currFile).lines[0..15] 
		while (linesList[i].match(/<body>/) == nil)
			if linesList[i].match(/<title>/)
				File.write(fileName, "<title>Unit #{@currUnitNum} Vocabulary</title>\n", mode: "a")
			else
				File.write(fileName, "#{linesList[i]}\n", mode: "a")
			end
			i += 1
		end
		File.write(fileName, "<h2>#{@currUnit}</h2>\n", mode: "a")
		File.write(fileName, "<h3>#{currLab()}</h3>\n", mode: "a")
	end

	def add_HTML_end()
		Dir.chdir("#{@parentDir}/summaries")
		ending = "</body>\n</html>"
		File.write(@vocabFileName, ending, mode: "a")
	end



	def add_content_to_file(filename, data)
		lab = @currLab
		if File.exist?(filename)
			if lab != currLab()
				File.write(filename, "<h3>#{currLab()}</h3>\n", mode: "a")
			end
			File.write(filename, data, mode: "a")
		else
			createNewVocabFile(filename)
			File.write(filename, data, mode: "a")
		end	
	end	

	#CHange - instead needs to match that class attribute and theeeen
	#iterate through all the new lines and save them to the vocab.rb file 
	def is_vocab_word(file, str, i)
		if /vocabFullWidth/.match(str)
			true
		else
			false
		end
	end

#	def parse_vocab(str)
#		currLine = str
#		vocabList = []
#		until currLine.match?(/((<\/div>)|(<\/ul>))/)
#			str_match = str.match(/<strong>.+<\/strong>/)
#			word = word.to_s.split(/<\/?strong>/)[1]
#			str_match2 = str.split(/<\/?\w+>/)
#			defn = str_match2.join()
#		end
#	end

	#might need to save index of line when i find the /div/ attribute
	#might be better to have other function to handle that bigger parsing of the whole file #with io.foreach
	def parse_vocab(file, str, i=0)
		if is_vocab_word(file, str, i)
			currLine = str
			tempIndex = i
			vocabList = []
			isEnd = false
			headerList = []
			divStartTagNum = 0
			divEndTagNum = 0
			until (isEnd == true or tempIndex >= @listLines.size)
				if (divEndTagNum > 0 and divEndTagNum >= divStartTagNum)
					isEnd = true
				else
					if currLine.match(/<div/)
						divStartTagNum += 1
					elsif (currLine.match(/<\/div>/))
						divEndTagNum += 1
					end
					if (parse_vocab_header(currLine) != [])
						headerList = parse_vocab_header(currLine)
					else
						vocabList.push(currLine)
					end
					tempIndex = tempIndex + 1
					currLine = @listLines[tempIndex]
				end
			end
			currLine(@listLines[tempIndex])
			currIndex(@currIndex + tempIndex - 1)
			headerUnit = add_vocab_unit_to_header(headerList, @currUnit)
			vocab = vocabList.join("\n")
			add_vocab_to_file("#{headerUnit}\n#{vocab}")
		end
	end

	def parse_vocab_header(str)
		newStr1 = str
		if str.match(/vocabFullWidth/)
			if str.match(/<!--.+-->/)
				newStr1 = str.gsub(/<!--.+-->/, "")
			end
			newStr2 = newStr1.to_s
			headerList = newStr2.split(/:/)
			headerList
		else
			[]
		end
		#if str.match(/:(\s\w+)+/) && str.match?(/vocabFullWidth/)
		#	str.match(/:(\s\w+)+/)
		#elsif str.match(/<p>((\w+\s?)+[\.\?\!\?\,:"'\(\)\-]?\s?)+/)
		#	str.match(/((\w+\s?)+[\.\?\!\?\,:"'\(\)\-]?\s?)+/)
		#elsif str.match(/<p>(/w+/s?)+[\.\?\!]/)
		#elsif str.match(/<li>.+<\/li>/)
		#	str_match = str.split(/<\/?\w+>/)
		#	str_match.join()
		#else
		#	nil
	end

	def add_vocab_unit_to_header(lst, unit)
		unitNum = return_vocab_unit(unit)
		withlink = " <a href=\"#{get_url(@currFile)}\">#{unitNum}</a>"
		unitSeriesNum = lst.join(" #{withlink}:")
	end

	#need something to call this function and parse_unit
	def return_vocab_unit(str)
		list = str.scan(/(\d+)/)
		list.join('.')
	end

	def add_vocab_to_file(vocab)
		result = "#{vocab} \n\n"
		add_content_to_file("#{@parentDir}/summaries/#{@vocabFileName}", result)
	end

	def get_url(file)
		current = Dir.getwd()
		result = "https://bjc.berkeley.edu/#{current}/#{file}"
		result = "#{result}"
		#add_content_to_file('urlLinks.txt', result)
	end

end