# frozen_string_literal: true

require 'nokogiri'

require_relative 'bjc_helpers'

class BJCCourse
  include BJCHelpers

  # Keep in sync with llab.DEVELOPER_CLASSES and the hidden classes in css/bjc.css.
  DEVELOPER_CLASSES = %w[todo comment commentBig ap-standard csta-standard].freeze

  attr_accessor :course_file

  def initialize(root: '', course: '', language: 'en')
    raise '`root` must end with "bjc-r" folder' unless %r{bjc-r/?$}.match?(root)
    raise 'course must be present' unless course

    @root = root
    @course_file = "#{root}/course/#{course}#{language_ext(language)}.html"
  end

  def course_contents
    @course_contents ||= Nokogiri::HTML5.parse(File.read(@course_file))
  end

  def topic_url?(url)
    # There may be alternative paths for topic files, but this is what is currently used.
    url.include?('?topic=')
  end

  def list_topics_no_path
    topic_files = list_topics
    topic_files.map { |file| file.split('/')[-1] }
  end

  def list_topics
    # Filtering the URLs is necessary because there are links with the wrong class applied.
    visible_links = course_contents.css('.topic_link a').reject { |node| developer_only?(node) }
    visible_links.filter_map do |node|
      url = node['href']
      url.split('?topic=')[1] if url && has_topic_url?(url)
    end
  end

  private

  def developer_only?(node)
    node.ancestors.any? do |ancestor|
      (ancestor['class'].to_s.split & DEVELOPER_CLASSES).any?
    end
  end
end
