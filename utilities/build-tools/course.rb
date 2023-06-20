
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

  def topic_url
    "/bjc-r/topic/topic.html?topic="
  end

  def list_topics
    # Filtering the URLs is necessary because there are links with the wrong class applied.
    course_contents.css('.topic_link a').map do |node|
      node.attributes['href'].value
    end.select { |url| url.start_with?(topic_url) }.map { |url| url.split(topic_url)[1] }
  end
end
