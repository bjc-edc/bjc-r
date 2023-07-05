require 'pry'
require 'fileutils'
require 'i18n'
require 'nokogiri'

require_relative 'bjc_helpers'
require_relative 'atwork'
require_relative 'course'
require_relative 'vocab'
require_relative 'selfcheck'

# TODO: Include BJCHelpers - figure out which config stuff belongs there.
VALID_LANGUAGES = %w[en es de].freeze
TEMP_FOLDER = 'summaries~'

I18n.load_path = Dir['**/*.yml']
I18n.backend.load_translations

class Main
  attr_reader :course, :parentDir
  attr_accessor :skip_test_prompt, :course_file

  # TODO: Determine whether the content folder path is necessary
  # or can it be inferred from a course/topic?
  def initialize(root: '', content: 'cur/programming', course: 'bjc4nyc', language: 'en')
    raise '`root` must end with "bjc-r" folder' unless root.match(%r{bjc-r/?$})
    raise '`content` should NOT include "bjc-r/" folder' if content.match(%r{bjc-r/$})
    raise '`course` should NOT include ".html" folder' if course.match(/\.html$/)

    @rootDir = root
    @parentDir = "#{@rootDir}/#{content}/"
    @language = language
    I18n.locale = @language.to_sym
    @currUnit = nil
    @unitNum = ''
    @classStr = ''
    @subClassStr = ''
    @labFileName = ''
    @course_file = course
    @course = BJCCourse.new(root: @rootDir, course: @course_file, language:)
    @vocab = Vocab.new(@parentDir, language)
    @self_check = SelfCheck.new(@parentDir, language)
    @atwork = AtWork.new(@parentDir, language)
    @testingFolder = false
  end

  def language_ext
    @language_ext ||= @language == 'en' ? '' : ".#{@language}"
  end

  # Extracts the folder class name and subfolder. For example with Sparks,
  # classStr = 'sparks' and subclassStr = 'student-pages'. For CSP,
  # classStr = 'cur' and subclassStr = 'programming'
  # def parse_class()
  #	path = @parentDir
  #	pattern = /bjc-r\\(\w+.?)+(\\review)$/
  #	pathMatch = path.match(pattern).to_s
  #	pathList = pathMatch.split("\\")
  #	classStr(pathList[1])
  #	subClassStr(pathList[2])
  # end

  # Main/primary function to be called, will call and create all other functions and classes.
  # This function will parse the topic pages, parse all labs and units, and create summary pages
  def Main
    testingFolderPrompt
    createNewReviewFolder
    parse_all_topic_files
    # Call BJCTopic.new().parse
    parse_units("#{review_folder}/topics.txt")
    @vocab.doIndex
    @atwork.moveFile
    puts 'All units complete'
    clear_review_folder
  end

  def topic_files_in_course
    @topic_files_in_course ||= course.list_topics
  end

  def clear_review_folder
    return if @testingFolder

    deleteReviewFolder
  end

  def testingFolderPrompt
    return if @skip_test_prompt

    prompt = '> '
    puts "Would you like to have a consolidated review folder (for testing purposes)? \n Type Y/N"
    print prompt
    while (user_input = gets.chomp) # loop while getting user input
      case user_input
      when 'Y', 'y'
        @testingFolder = true
        break
      when 'N', 'n'
        @testingFolder = false
        break
      else
        puts 'Unsupported input. Please type either Y/N'
        print prompt # print the prompt, so the user knows to re-enter input
      end
    end
  end

  def review_folder
    @review_folder ||= "#{@parentDir}/#{TEMP_FOLDER}"
  end

  def deleteReviewFolder
    Dir.chdir(review_folder)
    File.delete('topics.txt') if File.exist?('topics.txt')
    # TODO: should filter en/es separately.
    files = list_files("#{language_ext}.html")
    files.each do |file|
      File.delete(file)
    end
  end

  def createNewReviewFolder
    if Dir.exist?(review_folder)
      deleteReviewFolder
    else
      Dir.mkdir(review_folder)
    end
  end

  # Returns list of all FOLDERS (directories) in current working directory (cwd)
  def list_folders(_folder)
    Dir.glob('*').select { |f| File.directory?(f) }
  end

  # Returns list of all FILES in current working directory (cwd)
  # Input is the file type or ext you want -- Enter '*' for all file types
  def list_files(fileType)
    Dir.glob("*#{fileType}").select { |f| File.file?(f) }
  end

  # Returns true if input (fileName) is a file and not a folder
  # and is the correct extension type (fileType)
  def isCorrectFileType(fileType, fileName)
    File.exist?("#{fileName}#{fileType}") & File.file?(fileName)
  end

  # Input is the current list of topic files based on the @course html file.
  # Based on all the parsed topic pages, summaries will be generated
  def parse_all_topic_files
    topic_files_in_course.select { |f| is_topic_file(f) }.each { |f| parse_rawTopicPage(f) }
  end

  # Returns true if the file is a valid topic page
  # TODO: figure out if this should test for *.topic ?
  def is_topic_file(file)
    unwantedFilesPattern = /teaching-guide/
    filename = File.basename(file)
    return false if filename.match(unwantedFilesPattern)

    filename.match(/\d+/) && (fileLanguage(file) == @language)
  end

  # Adds the summary content and links to the topic.topic file
  def addSummariesToTopic(topic_file)
    linkMatch = @parentDir.match(%r{/bjc-r.+}).to_s
    linkMatchWithoutBracket = linkMatch.split(/\]/)
    link = linkMatchWithoutBracket.join.to_s
    topic_content = <<~TOPIC
      heading: (NEW) #{I18n.t('unit_review', num: @unitNum)}
        resource: (NEW) #{I18n.t('vocab')} [#{link}#{@vocab.vocab_file_name}]
        resource: (NEW) #{I18n.t('on_ap_exam')} [#{link}#{@self_check.exam_file_name}]
        resource: (NEW) #{I18n.t('self_check')} [#{link}#{@self_check.self_check_file_name}]
    TOPIC
    add_content_to_topic_file(topic_file, topic_content)
  end

  def isSummary(line)
    !line.nil? && !@currUnit.nil? && line.match(@currUnit)
  end

  # Parses through the data of the topic page and generates and adds content to a topics.txt
  # file that will be parsed later on to generate summaries
  # TODO: Move this to the BJCTopic Class, or maybe a BJCTopicParser class
  # TODO: This shouldn't write to a file, but return some hash/object
  def parse_rawTopicPage(file)
    full_path = "#{@rootDir}/topic/#{file}"
    currUnit(nil)
    allLines = File.readlines(full_path)
    topicURLPattern = %r{/bjc-r.+\.\w+}
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
      summaryExists = true if (index > 1) && isSummary(line)
      line = removeComment(oldline) if isComment(line)
      if line.match(/\}/) && !summaryExists
        allLines[index] = addSummariesToTopic(file)
        summaryExists = true
      elsif isTopic(line)
        if line.match(headerPattern)
          unitNum(line.match(/\d+/).to_s) if line.match(/title:/)
          header = removeHTML(line.match(headerPattern).to_s)
          add_content_to_file("#{review_folder}/topics.txt", "#{header}\n")
          labNum = 1
        else
          wholeLine = removeHTML(line.to_s.split(/.+:/).join)
          labName = wholeLine.match(/(\w+\s?((!|\?|\.|-)\s?)?)+/).to_s
          topicURL = line.match(topicURLPattern).to_s
          add_content_to_file("#{review_folder}/topics.txt", "#{labNum} #{labName} ----- #{topicURL}\n")
          labNum += 1
        end
      end
      index += 1
    end
    add_content_to_file("#{review_folder}/topics.txt", "END OF UNIT\n")
  end

  # Returns true if there is a comment in the topics.topic page
  def isComment(arg)
    str = arg.force_encoding('BINARY')
    str.match(%r{//})
  end

  # Removes the part of the string that is commented out in topics.topic which will then be added
  # to the new topics.txt file
  def removeComment(arg)
    arg.force_encoding('BINARY')
    strList = arg.split(%r{//.+})
    strList.join
  end

  # Returns true if the string/line is a valid topic. Ignores the lines that start with the kludges.
  # The kludges being the lines we want to avoid and NOT add to our topic.txt page. The topic.txt
  # page should only have what we need to find the correct file, lab, and unit
  def isTopic(arg)
    str = arg.force_encoding('BINARY')
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
      i = item.force_encoding('BINARY')
      bool = false if str.match(i) || !str.match(topicLine)
    end
    bool
  end

  def add_content_to_file(filename, data)
    if File.exist?(filename)
      File.write(filename, data, mode: 'a')
    else
      File.new(filename, 'w')
      File.write(filename, data)
    end
  end

  # TODO: - if we have a BJCTopic class, this probably belongs there.
  def path_to_topic_file(topic_file)
    "#{@rootDir}/topic/#{topic_file}"
  end

  def add_content_to_topic_file(topic_file, contents)
    full_path = path_to_topic_file(topic_file)
    topic_content = File.readlines(full_path)
    contents = contents.split("\n")
    header = contents[0]
    index = 0
    inserted = false
    while index < topic_content.length
      line = topic_content[index]
      if line.match(header) # found the first line of the section
        while !line.match(/}/) || !line.strip == '' || !line.match(/heading/i)
          topic_content.delete_at(index)
          line = topic_content[index]
        end
        contents.delete_at(0)
        topic_content.insert(index, contents.join("\n"))
        topic_content.insert(index + 1, "\n}")
        inserted = true
        break
      end
      index += 1
    end
    # indicates the file is missing a section ending...
    unless inserted
      topic_content.pop # Last line _should always be a }
      topic_content.append(contents.join("\n"))
      topic_content.append("\n}\n")
    end
    File.write(full_path, topic_content.join)
  end

  def removeHTML(str)
    htmlTagPattern = %r{</?\w+>}
    if str.match(htmlTagPattern)
      newStr = str.split(htmlTagPattern)
      newStr.join
    else
      str
    end
  end

  def isFileALab(file, labName)
    file.include?(labName)
  end

  # not using
  def parse_labNameFromFile(labFile)
    fileName = File.basename(labFile)
    nameMatch = fileName.match(/([a-zA-Z]-?)+/)
    nameMatch.to_s.join(' ')
  end

  def findLabFile(lab, _folder)
    listLabs = list_files('.html')
    i = 0
    labNum = lab.match(/\d+/).to_s
    while i < listLabs.size
      if listLabs[i].match(labNum) && (fileLanguage(listLabs[i]) == @language)
        labFileName(listLabs[i])
        return listLabs[i]
        break
      end
      i += 1
    end
  end

  def localPath
    parentDir = @parentDir.match(/.+bjc-r/).to_s
    local = parentDir.split(%r{/bjc-r})
    local.join.to_s
  end

  def extractTopicLink(line)
    labNamePattern = /----- /
    linkMatch = line.split(labNamePattern)
    link = linkMatch[1]
    # lab = link.match(/(\w+-?)+\.html/)
    lab = if @language != 'en'
            link.match(/(\w+-?)+\.\w+\.html/)
          else
            link.match(/(\w+-?)+\.html/)
          end
    # folder = "#{localPath()}#{link[0]}"
    # link =
    # Dir.chdir(folder)
    lab.to_s
    # lab = link.match(/(\w+-?)+\.\w+\.html/).to_s
  end

  def extractTopicLinkFolder(line)
    labNamePattern = /----- /
    linkMatch = line.split(labNamePattern)
    link = if @language != 'en'
             linkMatch[1].split(/(\w+-?)+\.\w+\.html/)
           else
             linkMatch[1].split(/(\w+-?)+\.html/)
           end
    folder = "#{localPath}#{link[0]}"
    # if link.size > 1
    Dir.chdir(folder)
    # end
  end

  def copyFiles
    list = [@vocab.vocab_file_name, @self_check.self_check_file_name, @self_check.exam_file_name]
    FileUtils.cd('..')
    # src = "#{review_folder}/#{@vocab}"
    # dst = "#{Dir.getwd}/#{@vocab.vocab_file_name}"
    list.each do |file|
      src = "#{review_folder}/#{file}"
      dst = "#{Dir.getwd}/#{file}"
      File.delete(dst) if File.exist?(dst)
      # TODO: use nokogiri to refomat the file.
      FileUtils.copy_file(src, dst) if File.exist?(src)
    end
  end

  # Inputs is the topics.txt file that is created earlier from the .topic file.
  # Reads each line from the topics.txt file and finds that unit, lab, and html
  # file it corresponds with. Once the html file is found, it calls the vocab
  # function to began to create or add onto the vocab pages
  def parse_units(topicsFile)
    # make sure i am in summaries directory first
    Dir.chdir(@parentDir)
    f = File.open(topicsFile, 'r')
    labNamePattern = /-----/
    unitNamePattern = /title: /
    endUnitPattern = /END OF UNIT/
    i = 0
    f.each do |line|
      if line.match(endUnitPattern)
        currentPath = Dir.getwd
        copyFiles
        FileUtils.cd(currentPath)
      end
      if !line.match(labNamePattern).nil?
        # labNum = line.match(/\d+\s+/).to_s
        # labFile = findLabFile(labNum, Dir.getwd())
        labFile = extractTopicLink(line)
        if labFile != ''
          extractTopicLinkFolder(line)
          @vocab.labPath(Dir.getwd)
          @vocab.read_file(labFile)
          @self_check.read_file(labFile)
          @atwork.read_file(labFile)
        end

      # pass to function that will open correct file
      # elsif line.match(labTopicPattern)
      # if line.match(/^(heading: [a-zA-Z]+)/)
      #	labNum = /optional-project/
      # else
      #	labNum = line.match(/\d+/).to_s
      # end
      # labFolder = getFolder(labNum, unitFolder)
      # Dir.chdir(labFolder)
      # change lab folder
      elsif line.match(unitNamePattern)
        unitNum(line.match(/\d+/).to_s)
        unitName = line.match(/Unit.+/)
        @vocab.currUnitName(unitName.to_s)
        @self_check.currUnitName(unitName.to_s)
        @atwork.currUnitName(unitName.to_s)
      # unitFolder = getFolder(@unitNum, @parentDir)
      # Dir.chdir(unitFolder)
      # change unit folder
      elsif isEndofTopicPage(line)
        @vocab.add_HTML_end
        @self_check.add_HTML_end
        @atwork.add_HTML_end
      end
      i += 1
    end
  end

  def isEndofTopicPage(line)
    line.match(/END OF UNIT/)
  end

  def getFolder(strPattern, parentFolder)
    Dir.chdir(parentFolder)
    foldersList = list_folders(parentFolder)
    foldersList.each do |folder|
      if File.basename(folder).match(/#{strPattern}/)
        # if File.basename(folder).match(/^#{strPattern}/)
        return "#{parentFolder}/#{folder}"
      end
    end
  end

  def fileLanguage(fileName)
    if !fileName.match(/\.\w\w\.\w+/).nil?
      langMatch = fileName.match(/\w+\.\w+/).to_s
      langMatch.match(/\w+$/).to_s
    else
      'en'
    end
  end

  # Setters and Getters
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
