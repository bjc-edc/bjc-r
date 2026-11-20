# frozen_string_literal: true

require 'yaml'

require_relative 'bjc_helpers'

# A compiled course, described by src/<id>/course.yml:
#
#   id: csp                         # served at /bjc-r/csp/, course page csp.html
#   title: 'BJC: AP CS Principles'
#   language: en
#   units:                          # in teaching order; Unit 1 is the first
#     - 1-introduction.topic
#
# The manifest is the only place that says which units a course has and in what
# order. Unit, lab, and page numbers are worked out from it and from the topic
# files it lists, so nothing in a page has to state its own position.
class CourseManifest
  FILE_NAME = 'course.yml'
  SOURCE_FOLDER = 'src'

  attr_reader :source_dir, :id, :title, :language, :units

  # Every compiled course in the checkout at ROOT.
  def self.discover(root)
    Dir.glob(File.join(root, SOURCE_FOLDER, '*', FILE_NAME)).map { |file| new(File.dirname(file)) }
  end

  def initialize(source_dir)
    @source_dir = source_dir
    data = YAML.safe_load_file(File.join(source_dir, FILE_NAME))
    @id = data.fetch('id')
    @title = data.fetch('title')
    @language = data.fetch('language', 'en')
    @units = data.fetch('units')
    validate
  end

  # Where the compiled pages are served, e.g. "/bjc-r/csp".
  def url_root
    "#{BJCHelpers::SITE_ROOT}/#{id}"
  end

  # The course page llab loads, relative to course/, e.g. "csp.html".
  def course_file
    language == 'en' ? "#{id}.html" : "#{id}.#{language}.html"
  end

  # The folder under topic/ that holds this course's compiled topic files.
  def topic_folder
    id
  end

  private

  def validate
    raise "#{source_dir}: `id` must be the name of its folder" unless id == File.basename(source_dir)
    raise "#{source_dir}: unknown language #{language}" unless VALID_LANGUAGES.include?(language)
    raise "#{source_dir}: `units` must list at least one topic file" if units.to_a.empty?
  end
end
