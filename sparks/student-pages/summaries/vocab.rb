require 'fileutils'
require 'rio'

class Vocab
	
	def initialize(path)
		@currFile = nil
		@currIndex = 0
		@currPath = path
		@currUnit = nil
		@currFile = nil
		@currLine = ''
		@listLines = []
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


	def read_file(file)
		listLines(file)
		currIndex(0)
		currFile(file)
		@listLines.each do |line|
			currLine(line)
			parse_unit(line)
			parse_vocab(file, @currline, @currIndex)
			currIndex(@currIndex + 1)
		end
		puts "Completed:  #{@currUnit}"
	end

	def parse_unit(str)
		#pattern = /((\s?\w+\s?)+[:,\!](\s?\w+\s?)+)+\d+/
		pattern1 = /<title>.+<\/title>/
		pattern2 = /<\/?\w+>/
		if (str == nil or @currUnit != nil)
			nil
		elsif str.match(pattern1)
			#add_to_file("Units.txt", str.match(pattern).to_s)
			match = str.match(pattern1).to_s
			newStr = match.split(pattern2)
			currUnit(newStr.join)
		else
			nil
		end
	end

	def add_content_to_file(filename, data)
		if File.exist?(filename)
			File.write(filename, data, mode: "a")
		else
			File.new(filename, "w")
			File.write(filename, data)
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
	def parse_vocab(file, str, i)
		if is_vocab_word(file, str, i)
			currLine = str
			tempIndex = i
			vocabList = []
			#end_html_tag_pattern = /<(\/)?((p)|(div)|(ul))>/
			isEnd = false
			headerList = []
			until (isEnd == true or tempIndex >= @listLines.size)
				#if return_vocab_str(currLine)
				#	vocabList.push(return_vocab_str(currLine))
				#end
				#vocabList.push(return_vocab_str(@currLine))
				if currLine.match(/<\/div>/)
					isEnd = true
				end
				if (parse_vocab_header(currLine) != [])
					headerList = parse_vocab_header(currLine)
				else
					vocabList.push(currLine)
				end
				tempIndex = tempIndex + 1
				currLine = @listLines[tempIndex]
			end
			currLine(@listLines[tempIndex])
			currIndex(@currIndex + tempIndex - 1)
			headerUnit = add_vocab_unit_to_header(headerList, @currUnit)
			puts headerList
			puts headerUnit
			puts @currUnit
			vocab = vocabList.join("\n")
			add_vocab_to_file("#{headerUnit}\n#{vocab}")
		end
	end

	def parse_vocab_header(str)
		if str.match(/vocabFullWidth/)
			newStr = str.to_s
			headerList = newStr.split(/:/)
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
		lst.join(" #{unitNum}:")
	end

	#need something to call this function and parse_unit
	def return_vocab_unit(str)
		list = str.scan(/(\d+)/)
		list.join('.')
	end

	def add_vocab_to_file(vocab)
		result = "#{vocab} \n\n"
		add_content_to_file('vocab.txt', result)
	end

	def get_url(file)
		current = Dir.getwd().match(/bjc-r.+/)
		result = 'https://bjc.berkeley.edu/' + current
		add_content_to_file('urlLinks.txt', result)
	end

end