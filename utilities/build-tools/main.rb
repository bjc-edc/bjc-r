require 'fileutils'
require 'i18n'
require 'nokogiri'

require_relative 'bjc_helpers'
require_relative 'atwork'
require_relative 'course'
require_relative 'vocab'
require_relative 'selfcheck'
require_relative 'topic'

I18n.load_path = Dir['**/*.yml']
I18n.backend.load_translations

class Main
  include BJCHelpers
  attr_reader :course, :parentDir
  attr_accessor :course_file

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
    @content = content
    @course_file = course
    @course = BJCCourse.new(root: @rootDir, course: @course_file, language: @language)
    # In-memory intermediate representation of the parsed topic files,
    # in the line-based format previously written to review/topics.txt.
    @topics_data = +''
    # All generated files, path => contents. Nothing is written to disk
    # until the whole run has finished, so a failed run never deletes or
    # replaces any existing content.
    @pending_writes = {}
    @vocab = Vocab.new(@parentDir, language, content, @course)
    @self_check = SelfCheck.new(@parentDir, language, content, @course)
    @atwork = AtWork.new(@parentDir, language, content)
    @topic_folder = ''
  end

  def language_ext
    @language_ext ||= @language == 'en' ? '' : ".#{@language}"
  end

  # Main/primary function to be called, will call and create all other functions and classes.
  # This function will parse the topic pages, parse all labs and units, and create summary pages
  # TODO: this needs to be rewritten to use the BJCTopic class / not require temporary files.
  def Main
    parse_all_topic_files
    # TODO: Move processing vocab/atwork/self-check to iterate over
    # BJCTopic#iterate_curriculum_pages, replacing parse_units below.
    parse_units
    index_path, index_contents = @vocab.doIndex
    @pending_writes[index_path] = index_contents
    @pending_writes.merge!(@atwork.finalize)
    flush_pending_writes
    puts 'All units complete'
  end

  # Perform all the file writes at once, after a fully successful run.
  def flush_pending_writes
    @pending_writes.each do |path, contents|
      File.write(path, contents)
    end
    puts "Wrote #{@pending_writes.length} files"
    @pending_writes.clear
  end

  def topic_files_in_course
    @topic_files_in_course ||= course.list_topics.filter { |file| file.match(/\d+-\w+/) }
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
    topic_files_in_course.select { |f| is_topic_file?(f) }.each { |f| parse_rawTopicPage(f) }
  end

  # Returns true if the file is a valid topic page
  # TODO: figure out if this should test for *.topic ?
  def is_topic_file?(file)
    unwantedFilesPattern = /teaching-guide/
    filename = File.basename(file)
    return false if filename.match(unwantedFilesPattern)

    filename.match(/\d+/) && (fileLanguage(file) == @language)
  end

  # The topic file contents up to (but not including) the summary section,
  # with the closing brace removed so a new summary section can be appended.
  def topic_contents_without_summaries(topic_file_path)
    lines = File.readlines(topic_file_path)
    review_index = lines.index { |line| line.match(/Unit \d+ Review/) || line.match(/Unidad \d+ Revision/) }
    if review_index.nil?
      lines.join.sub(/\}\s*\z/, '').rstrip
    else
      lines[0...review_index].join.rstrip
    end
  end

  # Adds the summary section and links to the unit's .topic file.
  # Only links to summary pages generated this run (staged in
  # @pending_writes under unit_dir) are included. The updated topic file
  # is itself staged in @pending_writes rather than written immediately.
  def addSummariesToTopic(topic_file, unit_dir)
    topic_folder(topic_file.split('/')[0])
    topic_file_path = "#{@rootDir}/topic/#{topic_file}"
    link_match = "/bjc-r/#{@content}"
    unit = File.readlines(topic_file_path).find { |line| line.match?(link_match) }
    link = extract_unit_path(unit, false, true)

    file_names = [@vocab.vocab_file_name,
                  @self_check.exam_file_name,
                  @self_check.self_check_file_name].map { |f_name| f_name.gsub(/\d+/, @unitNum) }
    labels = [I18n.t('vocab'), I18n.t('on_ap_exam'), I18n.t('self_check')]
    resources = file_names.zip(labels).filter_map do |f_name, label|
      "\tresource: #{label} [#{link}/#{f_name}]" if @pending_writes.key?(File.join(unit_dir, f_name))
    end
    return if resources.empty?

    body = topic_contents_without_summaries(topic_file_path)
    heading = "heading: #{I18n.t('unit_review', num: @unitNum)}"
    @pending_writes[topic_file_path] = "#{body}\n\n#{heading}\n#{resources.join("\n")}\n}\n"
  end

  def isSummary(line)
    !line.nil? && !@currUnit.nil? && line.match(@currUnit)
  end

  def parse_topic_page(file)
    BJCTopic.new(path_to_topic_file(file), course: @course_file, language: @language)
  end

  # Parses through the data of the topic page and generates and adds content to a topics.txt
  # file that will be parsed later on to generate summaries
  # TODO: Move this to the BJCTopic Class, or maybe a BJCTopicParser class
  # TODO: This shouldn't write to a file, but return some hash/object
  def parse_rawTopicPage(file)
    full_path = path_to_topic_file(file)
    get_topic_course(get_prev_folder(file), @course_file)
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
        summaryExists = true
      elsif isTopic(line)
        if line.match(headerPattern)
          unitNum(line.match(/\d+/).to_s) if line.match(/title:/)
          header = removeHTML(line.match(headerPattern).to_s)
          append_topics_data("#{header}\n")
          labNum = 1
        else
          wholeLine = removeHTML(line.to_s.split(/.+:/).join)
          labName = wholeLine.match(/(\w+\s?((!|\?|\.|-)\s?)?)+/).to_s
          topicURL = line.match(topicURLPattern).to_s
          append_topics_data("#{labNum} #{labName} ----- #{topicURL}\n")
          labNum += 1
        end
      end
      index += 1
    end
    append_topics_data("END OF UNIT\n")
  end

  def append_topics_data(data)
    @topics_data << "#{data}\n"
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
               'resource: Preguntas de Autocomprobacion',
               "#{I18n.t('self_check')}",
               "#{I18n.t('vocab')}",
               "#{I18n.t('on_ap_exam')}"]
    topicLine = /(\s+)?(\w+)+(\s+)?/
    bool = true
    kludges.each do |item|
      i = item.force_encoding('BINARY')
      bool = false if str.match(i) || !str.match(topicLine)
    end
    bool
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
    lab.to_s
  end

  def extractTopicLinkFolder(line, use_root = true)
    labNamePattern = /----- /
    linkMatch = line.split(labNamePattern)
    link = if @language != 'en'
             linkMatch[1].split(/(\w+-?)+\.\w+\.html/)
           else
             linkMatch[1].split(/(\w+-?)+\.html/)
           end
    use_root ? "#{localPath}#{link[0]}" : link[0]
  end

  def extract_unit_path(line, use_root = true, is_topic = true)
    if is_topic
      # TODO: This may error in raw-html lines which have links.
      bracket_removed = line.split(/.+\[/)
      match = bracket_removed[1].split(/\]/).join.to_s
    else
      match = line
    end
    link_with_lab = if @language != 'en'
                      match.split(/(\w+-?)+\.\w+\.html/)
                    else
                      match.split(/(\w+-?)+\.html/)
                    end
    list = link_with_lab[0].split('/')
    link = list.map { |elem, output = ''| output += "/#{elem}" if list.index(elem) < list.length - 1 }.join
    link = link[1..link.length] if link[1] == '/' # get rid of extra slash, otherwise appears as //bjc-r
    use_root ? "#{localPath}#{link}" : link
  end

  # Input is the topics data built up earlier from the .topic files.
  # Reads each line and finds the unit, lab, and html file it corresponds
  # with. Once the html file is found, it calls the vocab function to
  # began to create or add onto the vocab pages
  def parse_units
    # make sure i am in summaries directory first
    topics_index = 0
    Dir.chdir(@parentDir)
    labNamePattern = /-----/
    unitNamePattern = /title: /
    endUnitPattern = /END OF UNIT/
    current_lab_folder = ''
    @topics_data.each_line do |line|
      if line.match(endUnitPattern)
        unit_dir = File.expand_path('..', current_lab_folder)
        @pending_writes.merge!(@vocab.finalize_unit(unit_dir))
        @pending_writes.merge!(@self_check.finalize_unit(unit_dir))
        addSummariesToTopic(topic_files_in_course[topics_index], unit_dir)
        topics_index += 1
      elsif !line.match(labNamePattern).nil?
        labFile = extractTopicLink(line)
        root = @rootDir.split('/bjc-r')[0]
        lab_path = "#{root}#{line.split(labNamePattern)[-1].split(' ')[-1]}"
        if labFile != ''
          current_lab_folder = extractTopicLinkFolder(line)
          if File.exist?(lab_path)
            Dir.chdir(current_lab_folder)
            @vocab.read_file(labFile)
            @self_check.read_file(labFile)
            @atwork.read_file(labFile)
          end
        end
      elsif line.match(unitNamePattern)
        unitNum(line.match(/\d+/).to_s)
        unitName = line.match(/#{I18n.t('unit', num: @unitNum)}.+/)
        @vocab.currUnitName(unitName.to_s)
        @self_check.currUnitName(unitName.to_s)
        @atwork.currUnitName(unitName.to_s)
      end
    end
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

  def topic_folder(name)
    @topic_folder = name
  end
end
