# frozen_string_literal: true

require 'i18n'
require 'nokogiri'

# One curriculum page of a compiled course: where its source lives, where it is
# served, and -- when a topic file lists it -- its position in the course.
#
# The position comes from the course manifest and the topic file, never from
# the page itself, so moving a page is a one-line change to a topic file.
class BJCPage
  attr_reader :source_path, :url, :name, :unit, :lab, :page, :lab_name, :topic_reference

  # url:      where the compiled page is served, "/bjc-r/csp/1-intro/1-game/1-start.html"
  # name:     the page's own name as the topic file gives it; may contain inline HTML
  # position: { unit:, lab:, page:, lab_name:, topic_reference: } or nil for a
  #           page that exists in the course but that no topic file lists.
  def initialize(source_path:, url:, name: nil, position: nil)
    @source_path = source_path
    @url = url
    @name = name
    return unless position

    @unit, @lab, @page, @lab_name, @topic_reference =
      position.values_at(:unit, :lab, :page, :lab_name, :topic_reference)
  end

  # True when a topic file lists the page, so it has numbers and navigation.
  def listed?
    !unit.nil?
  end

  def document
    @document ||= Nokogiri::HTML5.parse(File.read(source_path))
  end

  # What llab shows in the navigation bar:
  # "Unit 1 Lab 2: Gossip, Page 3"
  def numbered_title
    I18n.t('page_title', unit: unit, lab: lab, page: page, lab_name: plain(lab_name))
  end

  # How another page refers to this one. May contain inline HTML.
  # "Unit 1 Lab 2 Page 3: Customizing and Debugging", or without the unit when
  # SHORT, for references from inside the same unit.
  def reference(short: false)
    I18n.t(short ? 'page_reference_short' : 'page_reference', unit: unit, lab: lab, page: page, name: name)
  end

  # The same reference without markup, for a title="" attribute.
  def plain_reference(short: false)
    plain(reference(short: short))
  end

  private

  def plain(html)
    Nokogiri::HTML5.fragment(html).text.strip
  end
end
