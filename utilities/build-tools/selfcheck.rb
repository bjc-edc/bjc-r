require 'fileutils'
require 'rio'

class SelfCheck

    def initialize(path, language)
        @parentPath = path
        @currFile
		@currUnit = nil
		@isNewUnit = true
		@currUnitNum = 0
		@currLab = ''
		@vocabFileName = ''
        @selfCheckFileName = nil
		@currUnitName = nil
        @examFileName = nil
		@language = language
    end

		def language_ext
			@language_ext ||= @language == 'en' ? '' : ".#{@language}"
		end

    def isNewUnit(boolean)
        @isNewUnit = boolean
    end

    def examFileName(name)
        @examFileName = name
    end

	def getExamFileName()
        return @examFileName
    end

	def getSelfCheckFileName()
        return @selfCheckFileName
    end

	def unit()
		temp = @currUnit.match(/[A-Za-z]+/)
		return temp.to_s
	end

    def currFile(file)
        @currFile = file
    end

    def currLab()
		if @currUnit != nil
			labMatch = @currUnit.match(/Lab.+,/)
			labList =  labMatch.to_s.split(/,/)
			@currLab = labList.join
		end
	end


    def currUnit(unit)
        @currUnit = unit
    end


    def currUnitNum(num)
        @currUnitNum = num
    end

	def currUnitName(str)
        @currUnitName = str
    end

    def selfCheckFileName(name)
        @selfCheckFileName = name
    end

	def read_file(file)
		if File.exist?(file)
			currFile(file)
			isNewUnit(true)
			parse_unit(file)
			parse_assessmentData(file)
			parse_examData(file)
		end
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
			selfCheckFileName("selfcheck#{@currUnitNum}.#{@language}.html")
            examFileName("exam#{@currUnitNum}.#{@language}.html")
			isNewUnit(false)
		end
	end


	def parse_assessmentData(file)
		doc = File.open(file) { |f| Nokogiri::HTML(f) }
		selfcheckSet = doc.xpath("//div[@class = 'assessment-data']")
		#header = parse_vocab_header(doc.xpath(""))
		selfcheckSet.each do |node|
			child = node.children()
			child.before(add_unit_to_header())
		end
		if not(selfcheckSet.empty?())
			add_assessment_to_file(selfcheckSet.to_s)
		end
	end

    def parse_examData(file)
		doc = File.open(file) { |f| Nokogiri::HTML(f) }
		examSet = doc.xpath("//div[@class = 'examFullWidth']")
		#header = parse_vocab_header(doc.xpath(""))
		examSet.each do |node|
			child = node.children()
			child.before(add_unit_to_header())
			#node.content.gsub(/\n\n/, "\n")
		end
		if not(examSet.empty?())
			add_exam_to_file(examSet.to_s)
		end
	end


    def createAssessmentDataFile(fileName, type)
		i = 0
		if not(File.exist?(fileName))
			File.new(fileName, "w")
		end
		linesList =  rio(@currFile).lines[0..15]
		while (linesList[i].match(/<body>/) == nil)
			if linesList[i].match(/<title>/)
				if @language == "en"
					File.write(fileName, "<title>Unit #{@currUnitNum} #{type} Questions</title>\n", mode: "a")
				else
					if type == "Self-Check"
						translatedType = "Preguntas de Autocomprobacion"
					else
						translatedType = "Examen AP"
					end
					File.write(fileName, "<title>Unidad #{@currUnitNum} #{translatedType} </title>\n", mode: "a")
				end
			else
				File.write(fileName, "#{linesList[i]}\n", mode: "a")
			end
			i += 1
		end
		File.write(fileName, "<h2>#{@currUnit}</h2>\n", mode: "a")
		File.write(fileName, "<h3>#{currLab()}</h3>\n", mode: "a")
	end

	def add_HTML_end()
		Dir.chdir("#{@parentPath}/review")
		ending = "</body>\n</html>"
		if File.exist?(@selfCheckFileName)
			File.write(@selfCheckFileName, ending, mode: "a")
		end
        if File.exist?(@examFileName)
			File.write(@examFileName, ending, mode: "a")
		end
        #does examFileName exist?
        #File.write(@examFileName, ending, mode: "a")
	end

    def add_content_to_file(filename, data, type)
		lab = @currLab
		data = data.gsub(/&amp;/, "&")
		data.delete!("\n\n\\")
		#data = data.gsub(/\n(\s+)?\n/, "\n")
		if File.exist?(filename)
			if lab != currLab()
				File.write(filename, "<h3>#{currLab()}</h3>\n", mode: "a")
			end
			File.write(filename, data, mode: "a")
		else
			createAssessmentDataFile(filename, type)
			File.write(filename, data, mode: "a")
		end
	end


    def add_unit_to_header()
		unitNum = return_unit(@currUnit)
		link = " <a href=\"#{get_url(@currFile)}\">#{unitNum}</a>"
        return link
	end

	#need something to call this function and parse_unit
	def return_unit(str)
		list = str.scan(/(\d+)/)
		list.join('.')
	end

	def add_assessment_to_file(assessment)
		result = assessment
		add_content_to_file("#{@parentPath}/review/#{@selfCheckFileName}", result, "Self-Check")
	end

    def add_exam_to_file(exam)
		result = exam
		add_content_to_file("#{@parentPath}/review/#{@examFileName}", result, "Exam")
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
