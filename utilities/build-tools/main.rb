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
    # Parsed topic files in course order.
    @topics = []
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
  def Main
    parse_all_topic_files
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
    @topics = topic_files_in_course.select { |file| is_topic_file?(file) }
                                    .map { |file| [file, parse_topic_page(file)] }
  end

  # Returns true if the file is a valid topic page
  # TODO: figure out if this should test for *.topic ?
  def is_topic_file?(file)
    unwantedFilesPattern = /teaching-guide/
    filename = File.basename(file)
    return false if filename.match(unwantedFilesPattern)

    filename.match(/\d+/) && (fileLanguage(file) == @language)
  end

  # Adds the summary section and links to the unit's .topic file.
  # Only links to summary pages generated this run (staged in
  # @pending_writes under unit_dir) are included. The updated topic file
  # is itself staged in @pending_writes rather than written immediately.
  def addSummariesToTopic(topic_file, topic, unit_dir)
    topic_folder(topic_file.split('/')[0])
    topic_file_path = "#{@rootDir}/topic/#{topic_file}"
    link = summary_unit_url(topic, unit_dir)

    file_names = [@vocab.vocab_file_name,
                  @self_check.exam_file_name,
                  @self_check.self_check_file_name].map { |f_name| f_name.gsub(/\d+/, @unitNum) }
    labels = [I18n.t('vocab'), I18n.t('on_ap_exam'), I18n.t('self_check')]
    resources = file_names.zip(labels).filter_map do |f_name, label|
      "\tresource: #{label} [#{link}/#{f_name}]" if @pending_writes.key?(File.join(unit_dir, f_name))
    end
    return if resources.empty?

    body = topic.contents_without_summaries
    heading = "heading: #{I18n.t('unit_review', num: @unitNum)}"
    @pending_writes[topic_file_path] = "#{body}\n\n#{heading}\n#{resources.join("\n")}\n}\n"
  end

  def parse_topic_page(file)
    BJCTopic.new(path_to_topic_file(file), course: @course_file, language: @language)
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

  # Iterate through the course's parsed topics and process each real curriculum
  # page. Topic syntax, comments, resources, and summary exclusions are all
  # handled by BJCTopic.
  def parse_units
    @topics.each do |topic_file, topic|
      get_topic_course(File.dirname(topic_file), @course_file)
      unitNum(topic.unit_number.to_s)
      [@vocab, @self_check, @atwork].each { |builder| builder.currUnitName(topic.title.to_s) }
      current_lab_folder = nil

      topic.iterate_curriculum_pages do |page|
        page_path = local_page_path(page[:path])
        next if page_path.nil? || !File.file?(page_path)

        current_lab_folder = File.dirname(page_path)
        previous_directory = Dir.pwd
        begin
          Dir.chdir(current_lab_folder)
          file_name = File.basename(page_path)
          @vocab.read_file(file_name)
          @self_check.read_file(file_name)
          @atwork.read_file(file_name)
        ensure
          Dir.chdir(previous_directory)
        end
      end

      next if current_lab_folder.nil?

      unit_dir = summary_unit_directory(topic, current_lab_folder)
      @pending_writes.merge!(@vocab.finalize_unit(unit_dir))
      @pending_writes.merge!(@self_check.finalize_unit(unit_dir))
      addSummariesToTopic(topic_file, topic, unit_dir)
    end
  end

  def local_page_path(url)
    path = url.to_s.split(/[?#]/, 2).first
    prefix = '/bjc-r/'
    return nil unless path.start_with?(prefix)

    File.join(@rootDir, path.delete_prefix(prefix))
  end

  def summary_unit_directory(topic, current_lab_folder)
    existing_summary = topic.summary_pages.filter_map { |page| local_page_path(page[:url]) }.first
    return File.dirname(existing_summary) unless existing_summary.nil?

    File.expand_path('..', current_lab_folder)
  end

  def summary_unit_url(topic, unit_dir)
    existing_summary = topic.summary_pages.map { |page| page[:url] }.find { |url| url.start_with?('/bjc-r/') }
    return File.dirname(existing_summary) unless existing_summary.nil?

    relative_path = unit_dir.delete_prefix(@rootDir).sub(%r{\A/+}, '')
    "/bjc-r/#{relative_path}"
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

  def currUnit(str)
    @currUnit = str
  end

  def topic_folder(name)
    @topic_folder = name
  end
end
