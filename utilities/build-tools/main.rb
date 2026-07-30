# frozen_string_literal: true

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

# Generates the vocabulary, self-check, exam reference, and "@ Work" summary
# pages for one course in one language.
#
# Every generator sees the same sequence of curriculum pages: the topic files
# are parsed once by BJCTopic, and BJCTopic#iterate_curriculum_pages drives the
# whole build. Nothing is written to disk until the run has finished, so a
# failed run leaves the checkout untouched.
class Main
  include BJCHelpers

  attr_reader :course, :parentDir, :unit_num
  attr_accessor :course_file

  # TODO: Determine whether the content folder path is necessary
  # or can it be inferred from a course/topic?
  def initialize(root: '', content: 'cur/programming', course: 'bjc4nyc', language: 'en')
    raise '`root` must end with "bjc-r" folder' unless %r{bjc-r/?$}.match?(root)
    raise '`content` should NOT include "bjc-r/" folder' if %r{bjc-r/$}.match?(content)
    raise '`course` should NOT include ".html" folder' if /\.html$/.match?(course)

    @rootDir = root
    @parentDir = "#{@rootDir}/#{content}/"
    @language = language
    I18n.locale = @language.to_sym
    @unit_num = ''
    @content = content
    @course_file = course
    @course = BJCCourse.new(root: @rootDir, course: @course_file, language: @language)
    # All generated files, path => contents. Nothing is written to disk
    # until the whole run has finished, so a failed run never deletes or
    # replaces any existing content.
    @pending_writes = {}
    @vocab = Vocab.new(@parentDir, language, content, @course)
    @self_check = SelfCheck.new(@parentDir, language, content, @course)
    @atwork = AtWork.new(@parentDir, language, content)
  end

  def language_ext
    @language_ext ||= @language == 'en' ? '' : ".#{@language}"
  end

  # Main/primary function to be called: generates every summary page for the
  # course and writes them all out once the run has finished successfully.
  def Main
    build_unit_summaries
    index_path, index_contents = @vocab.doIndex
    @pending_writes[index_path] = index_contents
    @pending_writes.merge!(@atwork.finalize)
    flush_pending_writes
    puts 'All units complete'
  end

  # Walks every unit's topic file and hands each curriculum page to the vocab,
  # self-check, and "@ Work" generators in the order the topic file lists them.
  def build_unit_summaries
    Dir.chdir(@parentDir)
    unit_topic_files.each do |topic_file|
      topic = parse_topic_page(topic_file)
      set_current_topic(get_prev_folder(topic_file), @course_file)
      start_unit(topic)
      unit_dir = process_curriculum_pages(topic)
      next if unit_dir.nil?

      @pending_writes.merge!(@vocab.finalize_unit(unit_dir))
      @pending_writes.merge!(@self_check.finalize_unit(unit_dir))
      add_summaries_to_topic(topic_file, unit_dir)
    end
  end

  # Perform all the file writes at once, after a fully successful run.
  def flush_pending_writes
    @pending_writes.each do |path, contents|
      report_topic_file_change(path, contents) if path.end_with?('.topic')
      File.write(path, contents)
    end
    puts "Wrote #{@pending_writes.length} files"
    @pending_writes.clear
  end

  # The topic files linked from this course's page that describe a unit of
  # curriculum, in the order the course lists them.
  def unit_topic_files
    @unit_topic_files ||= course.list_topics.select { |file| unit_topic_file?(file) }
  end

  # Returns true if the file is a topic page for a unit of curriculum in this
  # language. Teacher-facing guides have no summary pages of their own.
  # TODO: figure out if this should test for *.topic ?
  def unit_topic_file?(file)
    return false unless /\d+-\w+/.match?(file)

    filename = File.basename(file)
    return false if filename.include?('teaching-guide')

    filename.match(/\d+/) && (file_language(file) == @language)
  end

  def parse_topic_page(file)
    BJCTopic.new(path_to_topic_file(file), course: @course_file, language: @language)
  end

  # TODO: - if we have a BJCTopic class, this probably belongs there.
  def path_to_topic_file(topic_file)
    "#{@rootDir}/topic/#{topic_file}"
  end

  # Records the unit number and name that the generators use for page titles
  # and headings, e.g. "1" and "Unit 1: Introduction to Programming".
  def start_unit(topic)
    @unit_num = topic.unit_number.to_s
    name = topic.title.to_s.match(/#{I18n.t('unit', num: @unit_num)}.+/).to_s
    [@vocab, @self_check, @atwork].each { |generator| generator.currUnitName(name) }
  end

  # Visits every curriculum page of the topic in order, letting each generator
  # collect the content it needs. Pages the topic links to but that don't exist
  # in this checkout are skipped. Returns the unit's output directory, or nil
  # when the unit has no pages to summarize.
  def process_curriculum_pages(topic)
    unit_dir = nil
    topic.iterate_curriculum_pages do |page|
      page_path = url_to_path(page[:path])
      next unless File.exist?(page_path)

      Dir.chdir(File.dirname(page_path))
      unit_dir = File.expand_path('..')
      file_name = File.basename(page_path)
      @vocab.read_file(file_name)
      @self_check.read_file(file_name)
      @atwork.read_file(file_name)
    end
    unit_dir
  end

  # Adds the summary section and links to the unit's .topic file.
  # Only links to summary pages generated this run (staged in
  # @pending_writes under unit_dir) are included. The updated topic file
  # is itself staged in @pending_writes rather than written immediately.
  def add_summaries_to_topic(topic_file, unit_dir)
    topic_file_path = path_to_topic_file(topic_file)
    link = path_to_url(unit_dir)

    file_names = [@vocab.vocab_file_name,
                  @self_check.exam_file_name,
                  @self_check.self_check_file_name].map { |f_name| f_name.gsub(/\d+/, @unit_num) }
    labels = [I18n.t('vocab'), I18n.t('on_ap_exam'), I18n.t('self_check')]
    resources = file_names.zip(labels).filter_map do |f_name, label|
      "\tresource: #{label} [#{link}/#{f_name}]" if @pending_writes.key?(File.join(unit_dir, f_name))
    end
    return if resources.empty?

    body = topic_contents_without_summaries(topic_file_path)
    heading = "heading: #{I18n.t('unit_review', num: @unit_num)}"
    @pending_writes[topic_file_path] = "#{body}\n\n#{heading}\n#{resources.join("\n")}\n}\n"
  end

  # The topic file contents up to (but not including) the summary section,
  # with the closing brace removed so a new summary section can be appended.
  def topic_contents_without_summaries(topic_file_path)
    lines = File.readlines(topic_file_path)
    review_index = lines.index { |line| BJCTopic.summary_heading?(line) }
    if review_index.nil?
      lines.join.sub(/\}\s*\z/, '').rstrip
    else
      lines[0...review_index].join.rstrip
    end
  end

  # 'en' for a file with no language suffix, otherwise the suffix, e.g. the
  # 'es' in "1-intro-loops.es.topic".
  def file_language(file_name)
    return 'en' if file_name.match(/\.\w\w\.\w+/).nil?

    file_name.match(/\w+\.(\w+)\.\w+\z/)[1]
  end

  # The site root is both a URL prefix and a folder in the checkout, so mapping
  # between an llab URL and a path here is just swapping that prefix.
  # "/bjc-r/cur/programming/x.html" => "<checkout>/bjc-r/cur/programming/x.html"
  def url_to_path(url)
    "#{checkout_root}#{url}"
  end

  # "<checkout>/bjc-r/cur/programming" => "/bjc-r/cur/programming"
  def path_to_url(path)
    path.delete_prefix(checkout_root)
  end

  # The folder that contains the bjc-r checkout.
  def checkout_root
    @checkout_root ||= @rootDir.sub(%r{/bjc-r/?\z}, '')
  end
end
