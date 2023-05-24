require 'fileutils'
require 'rio'
require_relative 'vocab'
require_relative 'selfcheck'


class Main
	def initialize(dirPath, topicFolderPath, language='en')
		@parentDir = dirPath
		@topicFolder = topicFolderPath
		@language = language
		@currUnit = nil
		@unitNum = ''
		@classStr = ''
		@subClassStr = ''
		@labFileName = ''
		@vocab = Vocab.new(@parentDir, language)
		@selfcheck = SelfCheck.new(@parentDir, language)
		@testingFolder = true
	end

	def testingFolder(bool)
		@testingFolder = bool
	end

	#Extracts the folder class name and subfolder. For example with Sparks, 
	#classStr = 'sparks' and subclassStr = 'student-pages'. For CSP, 
	#classStr = 'cur' and subclassStr = 'programming'
	#def parse_class()
	#	path = @parentDir
	#	pattern = /bjc-r\\(\w+.?)+(\\review)$/
	#	pathMatch = path.match(pattern).to_s
	#	pathList = pathMatch.split("\\")
	#	classStr(pathList[1])
	#	subClassStr(pathList[2])
	#end

	#Main/primary function to be called, will call and create all other functions and classes. 
	#This function will parse the topic pages, parse all labs and units, and create summary pages
	def Main()
		testingFolderPrompt()
		createNewReviewFolder()
		#parse_class()
		parse_allTopicPages(@topicFolder)
		parse_units("#{@parentDir}/review/topics.txt")
		@vocab.doIndex()
		puts "All units complete"
	end

	def testingFolderPrompt()
		prompt = "> "
		puts "Would you like to have a consolidated review folder (for testing purposes)? \n Type Y/N"
		print prompt
		while user_input = gets.chomp # loop while getting user input
			case user_input
			when ("Y" or "Y".downcase)
				testingFolder(true)
				break
			when ("N" or "N".downcase)
				testingFolder(false)
				break
			else
			  puts "Please type either Y/N"
			  print prompt # print the prompt, so the user knows to re-enter input
			end
		end
	end

	def createNewReviewFolder()
		if Dir.exist?("#{@parentDir}/review")
			Dir.chdir("#{@parentDir}/review")
			File.delete("topics.txt")
			files = list_files("#{@language}.html")
			files.each do |file|
				File.delete(file)
			end
		else 
			Dir.mkdir("#{@parentDir}/review")
		end
	end

	#Returns list of all FOLDERS (directories) in current working directory (cwd)
	def list_folders(folder)
		Dir.glob('*').select {|f| File.directory? f}
	end

	#Returns list of all FILES in current working directory (cwd)
	#Input is the file type or ext you want -- Enter '*' for all file types
	def list_files(fileType)
		Dir.glob("*#{fileType}").select {|f| File.file? f}
	end

	#Returns true if input (fileName) is a file and not a folder 
	#and is the correct extension type (fileType)
	def isCorrectFileType(fileType, fileName)
		File.exists?("#{fileName}#{fileType}") & File.file?(fileName)
	end

	#Input is the folder path of the topic folder you want to parse
	#Based on all the parsed topic pages, summaries will be generated
	def parse_allTopicPages(folder)
		Dir.chdir(@topicFolder)
		filesList = list_files(".topic")	
		filesList.each do |file|
			if isTopicPageFile(file) and fileLanguage(file) == @language
				parse_rawTopicPage(file)
			end
		end
	end
	
	#Returns true if the file is a valid topic page
	def isTopicPageFile(file)
		unwantedFilesPattern = /teaching-guide/
		filename = File.basename(file)
		if (filename.match(unwantedFilesPattern))
			false
		elsif (filename.match(/\d+/) and fileLanguage(file) == @language)
			true
		else
			false
		end
	end

	#Adds the summary content and links to the topic.topic file
	def addSummariesToTopic(topicFile)
		linkMatch = @parentDir.match(/\/bjc-r.+/).to_s
		linkMatchWithoutBracket = linkMatch.split(/\]/)
		link = "#{linkMatchWithoutBracket.join}"
		if @language == "en"
			dataList = ["heading: Unit #{@unitNum} Review",
				"resource: Vocabulary [#{link}/review/vocab#{@unitNum}.#{@language}.html]",
				"resource: On the AP Exam [#{link}/review/exam#{@unitNum}.#{@language}.html]",
				"resource: Self-Check Questions [#{link}/review/selfcheck#{@unitNum}.#{@language}.html]",
				"}"]
		else 
			dataList = ["heading: Unidad #{@unitNum} Revision",
				"resource: Vocabulario [#{link}/review/vocab#{@unitNum}.#{@language}.html]",
				"resource: En el examen AP[#{link}/review/exam#{@unitNum}.#{@language}.html]",
				"resource: Preguntas de Autocomprobacion [#{link}/review/selfcheck#{@unitNum}.#{@language}.html]",
				"}"]
		end
		data = dataList.join("\n")
		#add_content_to_file("#{@topicFolder}/#{topicFile}", data)
	end

	def isSummary(line)
		if line != nil and @currUnit != nil and line.match(@currUnit)
			return true
		else 
			return false
		end
	end

	#Parses through the data of the topic page and generates and adds content to a topics.txt
	#file that will be parsed later on to generate summaries 
	def parse_rawTopicPage(file)
		currUnit(nil)
		allLines = File.readlines(file)
		topicURLPattern = /\/bjc-r.+\.\w+/
		headerPattern = /((heading:.+)|(title:.+))/
		labNum = 1
		index = 0
		if allLines[0].match(/title: [A-Za-z]+/)
			temp = allLines[0].match(/title: [A-Za-z]+\s?\d+/).to_s
			currUnit(temp.split(/title: /)[1])
		end
		summaryExists = false
		allLines.each do |oldline|
			line = oldline
			if index > 1 and isSummary(line)
				summaryExists = true
			end
			if isComment(line)
				line = removeComment(oldline)
			end
			if line.match(/\}/) and (not(summaryExists))
				allLines[index] = addSummariesToTopic(file)
				summaryExists = true
			else
				if isTopic(line) 
					if (line.match(headerPattern))
						if line.match(/title:/)
							unitNum(line.match(/\d+/).to_s)
						end
						header = removeHTML(line.match(headerPattern).to_s)
						add_content_to_file("#{@parentDir}/review/topics.txt", "#{header}\n")
						labNum = 1
					else
						wholeLine = removeHTML(line.to_s.split(/.+:/).join)
						labName = wholeLine.match(/(\w+\s?((\!|\?|\.|-)\s?)?)+/).to_s
						topicURL = line.match(topicURLPattern).to_s
						add_content_to_file("#{@parentDir}/review/topics.txt", "#{labNum} #{labName} ----- #{topicURL}\n")
						labNum += 1
					end
				end
			end
			index += 1
		end
		File.write(file, allLines.join)
		add_content_to_file("#{@parentDir}/review/topics.txt", "END OF UNIT\n")
	end

	#Returns true if there is a comment in the topics.topic page
	def isComment(arg)
		str = arg.force_encoding("BINARY")
		if str.match(/\/\//)
			true
		else
			false
		end
	end

	#Removes the part of the string that is commented out in topics.topic which will then be added
	#to the new topics.txt file
	def removeComment(arg)
		str = arg.force_encoding("BINARY")
		strList = arg.split(/\/\/.+/)
		strList.join
	end

	#Returns true if the string/line is a valid topic. Ignores the lines that start with the kludges.
	#The kludges being the lines we want to avoid and NOT add to our topic.txt page. The topic.txt 
	#page should only have what we need to find the correct file, lab, and unit
	def isTopic(arg)
		str = arg.force_encoding("BINARY")
		kludges = ['raw-html',
			'heading: Unit',
			'Review',
			'resource: Vocabulary',
			'resource: On the AP Exam',
			'resource: Self-Check Questions',
			'heading: Unidad',
			'resource: Vocabulario',
			'resource: En el examen AP',
			'resource: Preguntas de Autocomprobacion']
		topicLine = /(\s+)?(\w+)+(\s+)?/
		bool = true
		kludges.each do |item|
			i = item.force_encoding("BINARY")
			if (str.match(i) or not(str.match(topicLine)))
				bool = false
			end
		end
		bool
	end

	def add_content_to_file(filename, data)
		if File.exist?(filename)
			File.write(filename, data, mode: "a")
		else
			File.new(filename, "w")
			File.write(filename, data)
		end	
	end	

	def removeHTML(str)
		htmlTagPattern = /<\/?\w+>/
		if str.match(htmlTagPattern)
			newStr = str.split(htmlTagPattern)
			newStr.join
		else
			str
		end
	end

	def isFileALab(file, labName)
		fileAsString = rio(file)
		file.include?(labName)
	end

	#not using
	def parse_labNameFromFile(labFile)
		fileName = File.basename(labFile)
		nameMatch = fileName.match(/([a-zA-Z]-?)+/)
		labName = nameMatch.to_s.join(' ')
	end


	def findLabFile(lab, folder)
		listLabs = list_files('.html')
		i = 0
		labNum = lab.match(/\d+/).to_s
		while i < listLabs.size
			if (listLabs[i].match(labNum) and fileLanguage(listLabs[i]) == @language)
				labFileName(listLabs[i])
				return listLabs[i]
				break
			end
			i += 1
		end
	end

	def localPath()
		parentDir = @parentDir.match(/.+bjc-r/).to_s
		local = parentDir.split(/\/bjc-r/)
		output = local.join
		output.to_s
	end

	def extractTopicLink(line)
		labNamePattern = /----- /
		linkMatch = line.split(labNamePattern)
		link = linkMatch[1]
		#lab = link.match(/(\w+-?)+\.html/)
		if @language != "en"
			lab = link.match(/(\w+-?)+\.\w+\.html/)
		else
			lab = link.match(/(\w+-?)+\.html/)
		end
		#folder = "#{localPath()}#{link[0]}"
		#link = 
		#Dir.chdir(folder)
		return lab.to_s
		#lab = link.match(/(\w+-?)+\.\w+\.html/).to_s
	end

	def extractTopicLinkFolder(line)
		labNamePattern = /----- /
		linkMatch = line.split(labNamePattern)
		if @language != "en"
			link = linkMatch[1].split(/(\w+-?)+\.\w+\.html/)
		else
			link = linkMatch[1].split(/(\w+-?)+\.html/)
		end
		folder = "#{localPath()}#{link[0]}"
		#if link.size > 1
		Dir.chdir(folder)
		#end
	end

	#Inputs is the topics.txt file that is created earlier from the .topic file.
	#Reads each line from the topics.txt file and finds that unit, lab, and html
	#file it corresponds with. Once the html file is found, it calls the vocab
	#function to began to create or add onto the vocab pages
	def parse_units(topicsFile)
		#make sure i am in summaries directory first
		Dir.chdir(@parentDir)
		f = File.open(topicsFile, 'r')
		labNamePattern = /-----/
		unitNamePattern = /title: /
		labTopicPattern = /heading: /
		endUnitPattern = /END OF UNIT/
		unitFolder = ''
		labFolder = ''
		labName = ''
		labNum = ''
		f.each do |line|
			if line.match(labNamePattern) != nil

				#labNum = line.match(/\d+\s+/).to_s
				#labFile = findLabFile(labNum, Dir.getwd())

				labFile = extractTopicLink(line)
				if labFile != ""
					extractTopicLinkFolder(line)
					@vocab.labPath(Dir.getwd())
					@vocab.read_file(labFile)
					@selfcheck.read_file(labFile)
				end

				#pass to function that will open correct file
			#elsif line.match(labTopicPattern)
				#if line.match(/^(heading: [a-zA-Z]+)/)
				#	labNum = /optional-project/
				#else
				#	labNum = line.match(/\d+/).to_s
				#end
				#labFolder = getFolder(labNum, unitFolder)
				#Dir.chdir(labFolder)
				#change lab folder

			elsif line.match(unitNamePattern)
				unitNum(line.match(/\d+/).to_s)
				unitName = line.match(/Unit.+/)
				@vocab.currUnitName(unitName.to_s)
				@selfcheck.currUnitName(unitName.to_s)

				#unitFolder = getFolder(@unitNum, @parentDir)
				#Dir.chdir(unitFolder)
				#change unit folder
			elsif(isEndofTopicPage(line))
				@vocab.add_HTML_end()
				@selfcheck.add_HTML_end()
			end
		end
	end

	def isEndofTopicPage(line)
		if line.match(/END OF UNIT/)
			return true
		else
			return false
		end
	end

	def getFolder(strPattern, parentFolder)
		Dir.chdir(parentFolder)
		foldersList = list_folders(parentFolder)
		foldersList.each do |folder|
			if File.basename(folder).match(/#{strPattern}/)

				#if File.basename(folder).match(/^#{strPattern}/)

				return "#{parentFolder}/#{folder}"
			end
		end
	end

	def fileLanguage(fileName)
		if fileName.match(/\.\w\w\.\w+/) != nil
			langMatch = fileName.match(/\w+\.\w+/).to_s
			lang = langMatch.match(/\w+$/).to_s
			return lang
		else
			return "en"
		end
	end

#p array.map { |x| x == 4 ? 'Z' : x }

# => [1, 2, 3, 'Z']

	def parse_topic_links(fileName, line)
		Dir.chdir(@topicFolderPath)
		fileContents = []
		rio(fileName) > fileContents
		lineLink = line.match(/[.+]/).to_s
		contentIndex = fileContents.index(lineLink)
		fileContents.each do |item|
			if item.match(lineMatch)
				addStr = "#{lineLink}?topic=#{@classStr}%2F#{@unitNum}-#{fileName}.topic&course=#{@classStr}.html]"
				newLink = fileContents.gsub("#{lineLink}", addStr)
			#elsif lineMatch and isSummary
			end	
		end
	end


	#Setters and Getters

	def classStr(str)
		@classStr = str
	end

	def subClassStr(str)
		@subClassStr = str
	end

	def unitNum(str)
		@unitNum = str
	end

	def labFileName(str)
		@labFileName = str
	end

	def currUnit(str)
		@currUnit = str
	end

	
end