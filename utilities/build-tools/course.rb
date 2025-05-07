require 'nokogiri'

require_relative 'bjc_helpers'

class BJCCourse
  include BJCHelpers

  attr_accessor :course_file

  def initialize(root: '', course: '', language: 'en')
    raise '`root` must end with "bjc-r" folder' unless root.match(%r{bjc-r/?$})
    raise 'course must be present' unless course

    @root = root
    @course_file = "#{root}/course/#{course}#{language_ext(language)}.html"
  end

  def course_contents
    @course_contents ||= Nokogiri::HTML5.parse(File.read(@course_file))
  end

  def has_topic_url?(url)
    # There may be alternative paths for topic files, but this is what is currently used.
    url.include?("?topic=")
  end

  def list_topics_no_path
    topic_files = list_topics
    topic_files.map {|file| file.split("/")[-1]}
  end

  def list_topics
    # Filtering the URLs is necessary because there are links with the wrong class applied.
    course_contents.css('.topic_link a').map do |node|
      node.attributes['href'].value
    end.select { |url| has_topic_url?(url) }.map { |url| url.split("?topic=")[1] }
  end
end
