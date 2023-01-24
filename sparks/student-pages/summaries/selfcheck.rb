require 'fileutils'
require 'rio'

class SelfCheck

    def initialize(path)
        @parentPath = path
		@currIndex = 0
        @currFile
		@currPath = path
		@currUnit = nil
		@currLine = ''
		@listLines = []
		@isNewUnit = true
		@currUnitNum = 0
		@currLab = ''
		@vocabFileName = ''
		@pastFileUnit = nil
        @assessmentFileName = nil
        @currUnitName = nil
    end

    def currUnitName(name)
        @currUnitName = name
    end

    def currIndex(i)
        @currIndex = i
    end

    def listLines(file)
		@listLines = File.readlines(file)
	end

    def currLine(str)
        @currLine = str
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

    def currPath(path)
        @currPath = path
    end

    def currUnit(unit)
        @currUnit = unit
    end


    def currUnitNum(num)
        @currUnitNum = num
    end

    def assessmentFileName(name)
        @assessmentFileName = name
    end

    def is_Assessment_Data(line)
		if line.match(/<div class="assessment-data"/)
            assessmentFileName("assess-data#{@currUnitNum}.html")
			return true
        elsif line.match(/<div class="examFullWidth"/)
            assessmentFileName("exam#{@currUnitNum}.html")
            return true
		else
			return false
		end
	end

	def parse_assessmentData(str, i=0)
		if is_Assessment_Data(str)
			#parse through whole div tag and add all lines
			#also need to add the unit.lab.page to assessment data file
			#create assessment data file if not created
            currLine = str
            tempIndex = i
            assessmentList = []
            isEnd = false
            headerList = []
            divStartTagNum = 0
            divEndTagNum = 0
            until (isEnd == true or tempIndex >= @listLines.size)
                if (divEndTagNum > 0 and divEndTagNum >= divStartTagNum)
                    isEnd = true
                else
                    if currLine.match(/<div/) and currLine.match(/<\/div>/)
                        divStartTagNum += 1
                        divEndTagNum += 1
                    elsif currLine.match(/<div/)
                        divStartTagNum += 1
                    elsif currLine.match(/<\/div>/)
                        divEndTagNum += 1
                    end
                    if (parse_header(currLine) != [])
                        headerList = parse_header(currLine)
                    else
                        assessmentList.push(currLine)
                    end
                    tempIndex = tempIndex + 1
                    currLine = @listLines[tempIndex]
                end
            end
            currLine(@listLines[tempIndex])
            currIndex(@currIndex + tempIndex - 1)
            headerUnit = add_unit_to_header(headerList, @currUnit)
            questions = assessmentList.join("\n")
            add_assessment_to_file("#{headerUnit}\n#{questions}")
        end
    end
        

    def createAssessmentDataFile(fileName)
		i = 0
		if not(File.exist?(fileName))
			File.new(fileName, "w")
		end
		linesList =  rio(@currFile).lines[0..15] 
		while (linesList[i].match(/<body>/) == nil)
			if linesList[i].match(/<title>/)
				File.write(fileName, "<title>Unit #{@currUnitNum} Self-Check Questions</title>\n", mode: "a")
			else
				File.write(fileName, "#{linesList[i]}\n", mode: "a")
			end
			i += 1
		end
		File.write(fileName, "<h2>#{@currUnitName}</h2>\n", mode: "a")
		File.write(fileName, "<h3>#{currLab()}</h3>\n", mode: "a")
	end

	def add_HTML_end()
		Dir.chdir("#{@parentPath}/summaries")
		ending = "</body>\n</html>"
		File.write(@assessmentFileName, ending, mode: "a")
        #does examFileName exist?
        #File.write(@examFileName, ending, mode: "a")
	end

    def add_content_to_file(filename, data)
		lab = @currLab
		if File.exist?(filename)
			if lab != currLab()
				File.write(filename, "<h3>#{currLab()}</h3>\n", mode: "a")
			end
			File.write(filename, data, mode: "a")
		else
			createAssessmentDataFile(filename)
			File.write(filename, data, mode: "a")
		end	
	end	

    
	def parse_header(str)
		newStr = str
		if str.match(/class="assessment-data"/)
			newStr
            headerList = []
			if (newStr.match(/<div class="assessment-data".+>/))
				headerList.push(str)
			end
			headerList
		else
			[]
		end
    end

    def add_unit_to_header(lst, unit)
		unitNum = return_unit(unit)
		withlink = " <a href=\"#{get_url(@currFile)}\">#{unitNum}</a>"
        unitSeriesNum = lst
        unitSeriesNum.push(" #{withlink}:")
        unitSeriesNum.join
	end

	#need something to call this function and parse_unit
	def return_unit(str)
		list = str.scan(/(\d+)/)
		list.join('.')
	end

	def add_assessment_to_file(assessment)
		result = "#{assessment} \n\n"
		add_content_to_file("#{@parentPath}/summaries/#{@assessmentFileName}", result)
	end

	def get_url(file)
		localPath = Dir.getwd()
		linkPath = localPath.match(/bjc-r.+/).to_s
		result = "https://bjc.berkeley.edu/#{linkPath}/#{file}"
		result = "#{result}"
		#add_content_to_file('urlLinks.txt', result)
	end

end