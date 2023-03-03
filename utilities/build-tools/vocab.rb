require 'fileutils'
require 'rio'
require_relative 'selfcheck'

class Vocab
	
	def initialize(path, language="en")
		@parentDir = path
		@language = language
		@currUnit = nil
		@currFile = nil
		@isNewUnit = true
		@currUnitNum = 0
		@currLab = ''
		@vocabFileName = ''
		@vocabList = []
		@vocabDict = {}
		@labPath = ''
	end

	def labPath(arg)
		@labPath = arg
	end

	def unit()
		temp = @currUnit.match(/[A-Za-z]+/)
		return temp.to_s
	end


	def selfcheck()
		#@selfcheck
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


	def read_file(file)
		currIndex(0)
		currFile(file)
		isNewUnit(true)
		parse_unit(file)
		parse_vocab(file)
		puts "Completed:  #{@currUnit}"
	end


	def parse_unit(file)
		doc = File.open(file) { |f| Nokogiri::HTML(f) }
		title = doc.xpath("//title")
		str = title.to_s
		pattern = /<\/?\w+>/
		if (str == nil or not(@isNewUnit))
			nil
		else
			newStr = str.split(pattern)
			currUnit(newStr.join)
			currUnitNum(@currUnit.match(/\d+/).to_s)
			unit()
			vocabFileName("vocab#{@currUnitNum}.#{@language}.html")
			isNewUnit(false)
		end
	end

	def vocabLanguage()
		if @language == "en"
			return "Vocabulary"
		elsif @language == "es"
			return "Lexico"
		end
	end

	def createNewVocabFile(fileName)
		i = 0
		filePath = Dir.getwd()
		if not(File.exist?(fileName))
			Dir.chdir("#{@parentDir}/review")
			File.new(@vocabFileName, "w")
		end
		linesList =  rio("#{filePath}/#{@currFile}").lines[0..30] 
		while (not(linesList[i].match(/<body>/)) and i < 30)
			if linesList[i].match(/<title>/)
				File.write(fileName, "<title>#{unit()} #{@currUnitNum} #{vocabLanguage()}</title>\n", mode: "a")
			else
				File.write(fileName, "#{linesList[i]}\n", mode: "a")
			end
			i += 1
		end
		File.write(fileName, "<h2>#{@currUnit}</h2>\n", mode: "a")
		File.write(fileName, "<h3>#{currLab()}</h3>\n", mode: "a")
		Dir.chdir(@labPath)
	end

	def add_HTML_end()
		Dir.chdir("#{@parentDir}/review")
		ending = "</body>\n</html>"
		File.write(@vocabFileName, ending, mode: "a")
	end


	def add_content_to_file(filename, data)
		lab = @currLab
		if File.exist?(filename)
			if lab != currLab()
				File.write(filename, "<h3>#{currLab()}</h3>", mode: "a")
			end
			File.write(filename, data, mode: "a")
		else
			createNewVocabFile(filename)
			File.write(filename, data, mode: "a")
		end	
	end	



	#might need to save index of line when i find the /div/ attribute
	#might be better to have other function to handle that bigger parsing of the whole file #with io.foreach
	def parse_vocab(file)
		doc = File.open(file) { |f| Nokogiri::HTML(f) }
		vocabSet = doc.xpath("//div[@class = 'vocabFullWidth']")
		#header = parse_vocab_header(doc.xpath(""))
		vocabSet.each do |node|
			child = node.children()
			child.before(add_vocab_unit_to_header())
			#save_vocab_word(node)			
		end
		#if not(vocabSet.empty?())
		add_vocab_to_file(vocabSet.to_s)
		#end
	end

	def get_vocab_word(nodeSet)
		save_vocab_word(nodeSet.xpath("//li//strong"))
		save_vocab_word(nodeSet.xpath("//p//strong"))
	end

	def save_vocab_word(nodeSet)
		nodeSet.each do |node|
			#if not(@vocabList.include?(node.text()))
			#	@vocabList.push(node.text())
			#	@vocabDict[node.text()] = [get_url()]
			#elsif @vocabDict[node.text].last() != get_url()
			#	@vocabDict[node.text()].append(get_url)
			#end
		end
	end

	def parse_vocab_header(str)
		newStr1 = str
		if str.match(/vocabFullWidth/)
			if str.match(/<!--.+-->/)
				newStr1 = str.gsub(/<!--.+-->/, "")
			end
			newStr2 = newStr1.to_s
			if (newStr2.match(/<div class="vocabFullWidth">.+/))
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

	def add_vocab_unit_to_header()
		unitNum = return_vocab_unit(@currUnit)
		link = " <a href=\"#{get_url(@currFile)}\">#{unitNum}</a>"
		return link
		#if lst.size > 1
		#	unitSeriesNum = lst.join(" #{withlink}:")
		#else
		#	unitSeriesNum = lst
		#	unitSeriesNum.push(" #{withlink}:")
		#	unitSeriesNum.join
		#end
	end

	#need something to call this function and parse_unit
	def return_vocab_unit(str)
		list = str.scan(/(\d+)/)
		list.join('.')
	end

	def add_vocab_to_file(vocab)
		result = vocab
		file = "#{@parentDir}/review/#{@vocabFileName}"
		add_content_to_file(file, vocab)
		#if File.exists?(file)
		#	doc = File.open(file) { |f| Nokogiri::HTML(f) }
		#	vocabSet = doc.xpath("//div[@class = 'vocabFullWidth']").to_s
		#	if vocab.match(vocabSet) == nil
	#			add_content_to_file(file, vocab)
		#	end
		#else
			#add_content_to_file(file, vocab)
		#end
	end

	def get_url(file)
		localPath = Dir.getwd()
		linkPath = localPath.match(/bjc-r.+/).to_s
		result = "/#{linkPath}/#{file}"
		#https://bjc.berkeley.edu
		result = "#{result}"
		#add_content_to_file('urlLinks.txt', result)
	end

end