require 'fileutils'
require 'rio'
require 'nokogiri'
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
		@currUnitName = nil
		@index = Index.new(@parentDir, @language)
	end

	def doIndex()
		@index.vocabDict(@vocabDict)
		@index.vocabList(@vocabList)
		@index.addIndex()
	end

	def currUnitName(str)
		@currUnitName = str
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
		currFile(file)
		isNewUnit(true)
		parse_unit(file)
		parse_vocab(file)
		puts @vocabList
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
		if File.exist?(@vocabFileName)
			File.write(@vocabFileName, ending, mode: "a")
		end
	end


	def add_content_to_file(filename, data)
		lab = @currLab
		data = data.gsub(/&amp;/, "&")
		data.delete!("\n\n\\")
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
		vocabSet1 = doc.xpath("//div[@class = 'vocabFullWidth']")
		#header = parse_vocab_header(doc.xpath(""))
		vocabSet1.each do |node|
			child = node.children()
			child.before(add_vocab_unit_to_header())
			get_vocab_word(node)			
		end
		add_vocab_to_file(vocabSet1.to_s)
		vocabSet2 = doc.xpath("//div[@class = 'vocabBig']")
		vocabSet2.each do |node|
			child = node.children()
			changeToVocabFullWidth(vocabSet2, node['class'])
			child.before(add_vocab_unit_to_header())
			get_vocab_word(node)			
		end
		add_vocab_to_file(vocabSet2.to_s)
		vocabSet3 = doc.xpath("//div[@class = 'vocab']")
		vocabSet3.each do |node|
			child = node.children()
			changeToVocabFullWidth(vocabSet3, node['class'])
			child.before(add_vocab_unit_to_header())
			get_vocab_word(node)			
		end
		add_vocab_to_file(vocabSet3.to_s)
		#if not(vocabSet.empty?())
		
		#end
	end

	def changeToVocabFullWidth(vocabSet, clas)
		if ['vocabBig', 'vocab'].include?(clas)
			vocabSet.remove_class(clas)
			vocabSet.add_class('vocabFullWidth')
		end
	end

	def get_vocab_word(nodeSet)
		#save_vocab_word(nodeSet.xpath(".//li//strong"))
		save_vocab_word(nodeSet.xpath(".//li//strong"))
		save_vocab_word(nodeSet.xpath(".//p//strong"))
	end

	def save_vocab_word(nodeSet)
		nodeSet.each do |n|
			node = n.text() 
			if not(@vocabList.include?(node.to_s()))
				@vocabList.push(node.to_s())
				@vocabDict[node.to_s()] = [add_vocab_unit_to_header()]
			elsif @vocabDict[node.to_s()].last() != add_vocab_unit_to_header()
				@vocabDict[node.to_s()].append(add_vocab_unit_to_header())
			end
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
		if vocab != ''
			result = vocab
			file = "#{@parentDir}/review/#{@vocabFileName}"
			add_content_to_file(file, vocab)
		end
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