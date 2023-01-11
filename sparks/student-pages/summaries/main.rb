require 'fileutils'
require 'rio'
require_relative 'vocab'


class Main
	def initialize(dir, topicFolder)
		@parentDir = dir
		@topicFolder = topicFolder
		@currFile = nil
		@currIndex = 0
		@currUnit = nil
		@topicLinks = []
		@currentLine = nil
		@currDir = dir
		@listUnitsDir = []
		@listLabsDir = []
		@vocab = Vocab.new(@parentDir)
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

	def isCorrectFileType(fileType, fileName)
		File.exists?("#{fileName}#{fileType}") & File.file?(fileName)
	end

	def Main()
		parse_allTopicPages(@topicFolder)
		parse_topicsFile("#{@parentDir}/summaries/topics.txt")
	end


	#make sure im in topic folder and then enter correct sub folder depending on class
	def parse_allTopicPages(folder)
		Dir.chdir(@topicFolder)
		filesList = list_files('.topic')
		filesList.each do |file|
			if isTopicPageFile(file)
				parse_rawTopicPage(file)
			end
		end
	end
	
	def isTopicPageFile(file)
		unwantedFilesPattern = /teaching-guide/
		filename = File.basename(file)
		if (filename.match(unwantedFilesPattern))
			false
		else
			true
		end
	end

	#ignore 'raw-html: '
	#ignore Summary/Summaries: 
	def parse_rawTopicPage(file)
		allLines = File.readlines(file)
		topicURLPattern = /\/bjc-r.+\.\w+/
		headerPattern = /((heading:.+)|(title:.+))/
		labNum = 1
		allLines.each do |line|
			if isComment(line)
				line = removeComment(line)
			end
			if isTopic(line)
				if (line.match(headerPattern))
					header = removeHTML(line.match(headerPattern).to_s)
					add_content_to_file("#{@parentDir}/summaries/topics.txt", "#{header}\n")
					labNum = 1
				else
					wholeLine = removeHTML(line.to_s.split(/.+:/).join)
					labName = wholeLine.match(/(\w+\s?((\!|\?|\.|-)\s?)?)+/).to_s
					topicURL = line.match(topicURLPattern).to_s
					add_content_to_file("#{@parentDir}/summaries/topics.txt", "#{labNum} #{labName} ----- #{topicURL}\n")
					labNum += 1
				end
			end
		end
		add_content_to_file("#{@parentDir}/summaries/topics.txt", "\n")
	end

	def isComment(arg)
		str = arg.force_encoding("BINARY")
		if str.match(/\/\//)
			true
		else
			false
		end
	end

	def removeComment(arg)
		str = arg.force_encoding("BINARY")
		strList = arg.split(/\/\/.+/)
		strList.join
	end

	def isTopic(arg)
		str = arg.force_encoding("BINARY")
		kludges = ['raw-html',
			'Summaries',
			'Summary',
			]
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
			if (listLabs[i].match(labNum))
				return listLabs[i]
				break
			end
			i += 1
		end
	end

	def parse_topicsFile(topicsFile)
		#make sure i am in summaries directory first
		Dir.chdir(@parentDir)
		f = File.open(topicsFile, 'r')
		labNamePattern = /-----/
		unitNamePattern = /title: /
		labTopicPattern = /heading: /
		unitNum = ''
		unitFolder = ''
		labFolder = ''
		labName = ''
		labNum = ''
		f.each do |line|
			if line.match(labNamePattern)
				#labNameMatch = line.match(/(\w+\s?((\!|\?|\.|-)\s?)?)+/).to_s
				#labNameList = labNameMatch.split(/[\!\?\.\-\s]+/)
				#labName = labNameList.join("-")
				labNum = line.match(/\d+\s+/).to_s
				labFile = findLabFile(labNum, Dir.getwd())
				
				@vocab.read_file(labFile)
				#pass to function that will open correct file
			elsif line.match(labTopicPattern)
				labNum = line.match(/\d+/).to_s
				labFolder = getFolder(labNum, unitFolder)
				Dir.chdir(labFolder)
					
				#change lab folder
			elsif line.match(unitNamePattern)
				unitNum = line.match(/\d+/).to_s
				unitFolder = getFolder(unitNum, @parentDir)
				Dir.chdir(unitFolder)
				
				#change unit folder
			
			end
		end
		@vocab.add_HTML_end()
	end

	def getFolder(strPattern, parentFolder)
		Dir.chdir(parentFolder)
		foldersList = list_folders(parentFolder)
		foldersList.each do |folder|
			if File.basename(folder).match(strPattern)
				return "#{parentFolder}/#{folder}"
			end
		end
	end

	def fileLanguage(file)
		file_name = File.basename(file)
		if /\w+\.html/.match?(file)
			lang = /\w+\.html/.match(file).to_s
			return lang.split[0]
		else
			return "en"
		end
	end

	def parse_topic_links(file)
		if @currLine.match(/<div class="topic_link">/)
		end
		pattern = /"\/bjc-r[^\s]+"/
		str.match(pattern)
	end

	def iter_start_at(file)
		'hello'
	end

	#Setters and Getters

	def currDir(cwd)
		@currDir = cwd
	end

	def currFile(file)
		@currFile = file
	end

	def main(cwd)
		list_labs(@listUnitsDir)
	end

end