#! /usr/bin/env ruby
# frozen_string_literal: true

## Copies one unit of an existing llab course into the source tree of a compiled
## course, taking out everything in it that states a position.
## $ bundle exec ruby utilities/build-tools/import-unit.rb nyc_bjc/1-intro-loops.topic csp
##
## This is a migration aid, to be run once per unit: review what it writes.
## It edits the pages as text rather than re-serializing them, so a diff against
## the original shows only these changes:
##
##   * <title> becomes the page's own name ("Unit 1 Lab 2: Gossip, Page 3"
##     is something the compiler now writes).
##   * Links to pages of the unit lose their ?topic=&course= and point at the
##     page's new home.
##   * A link whose text is a numbered reference ("Unit 1 Lab 2 Page 3: ...")
##     becomes <a href="..." data-page-ref></a>; the compiler writes the text.
##
## The topic file is copied too, without its unit and lab numbers and without
## the generated review section.

require 'fileutils'
require 'nokogiri'

require_relative 'topic'

ROOT = File.expand_path('../..', __dir__)
SITE_ROOT = BJCHelpers::SITE_ROOT
NUMBERED_REFERENCE = /\A(Unit \d+,? )?Lab \d+,? Page \d+: /
ANCHOR = %r{<a\b([^>]*)>(.*?)</a>}m

abort 'Usage: import-unit.rb TOPIC COURSE   (e.g. nyc_bjc/1-intro-loops.topic csp)' unless ARGV.length == 2
topic_reference, course_id = ARGV

def plain(html)
  Nokogiri::HTML5.fragment(html).text.split.join(' ')
end

def file_for(url)
  File.join(ROOT, url.delete_prefix(SITE_ROOT))
end

topic = BJCTopic.new(File.join(ROOT, 'topic', topic_reference))
unit_url = topic.base_content_folder                  # /bjc-r/cur/programming/1-introduction
content_url = File.dirname(unit_url)                  # /bjc-r/cur/programming
course_url = "#{SITE_ROOT}/#{course_id}"
source_dir = File.join(ROOT, 'src', course_id)

# Old URL => the page's name, for the pages the topic file lists.
names = {}
topic.iterate_curriculum_pages { |entry| names[entry[:path]] = entry[:title] }

# Pages the listed ones link to that live in the unit's folder but that the
# topic file leaves out, such as a hints page. They come along, unlisted.
to_import = names.keys
to_import.each do |url|
  File.read(file_for(url)).scan(/href="(#{Regexp.escape(unit_url)}[^"?#]*\.html)/).flatten.each do |linked|
    next if to_import.include?(linked) || linked.include?('/old/') || !File.file?(file_for(linked))

    to_import << linked
  end
end

new_url = to_import.to_h { |url| [url, url.sub(content_url, course_url)] }
new_url["#{content_url}/vocab-index.html"] = "#{course_url}/vocab-index.html"
report = { links: 0, references: [] }

rewrite_link = lambda do |attributes, text|
  href = attributes[/href="([^"]*)"/, 1]
  path, = href.to_s.split(/[?#]/, 2)
  next nil unless new_url.key?(path)

  fragment = href[/#.*\z/].to_s
  attributes = attributes.sub(/href="[^"]*"/, %(href="#{new_url[path]}#{fragment}"))
  report[:links] += 1
  next "<a#{attributes}>#{text}</a>" unless names.key?(path) && plain(text).match?(NUMBERED_REFERENCE)

  short = plain(text).start_with?('Lab')
  report[:references] << "#{plain(text)}  =>  #{plain(names[path])}"
  attributes = attributes.sub(/\s+title="[^"]*"/, '')
  %(<a#{attributes} data-page-ref#{'="short"' if short}></a>)
end

to_import.each do |url|
  html = File.read(file_for(url))
  name = names[url] || html[%r{<h2>(.*?)</h2>}m, 1]
  html = html.sub(%r{<title>.*?</title>}m, "<title>#{plain(name)}</title>") if name
  html = html.gsub(ANCHOR) { |anchor| rewrite_link.call(Regexp.last_match(1), Regexp.last_match(2)) || anchor }

  destination = File.join(source_dir, new_url[url].delete_prefix("#{course_url}/"))
  FileUtils.mkdir_p(File.dirname(destination))
  File.write(destination, html)
end

# The topic file, up to the generated review section.
lines = File.readlines(File.join(ROOT, 'topic', topic_reference), chomp: true)
review = lines.index { |line| BJCTopic.summary_heading?(line) }
lines = lines[0...review] if review
lines = lines.map do |line|
  line.sub(/\A(\s*title:\s*)Unit \d+:\s*/, '\1')
      .sub(/\A(\s*heading:\s*)Lab \d+:\s*/, '\1')
      .sub(%r{\[#{Regexp.escape(content_url)}/}, '[')
end
topic_file = File.join(source_dir, "#{File.basename(unit_url)}.topic")
File.write(topic_file, "#{lines.join("\n").sub(/\}\s*\z/, '').rstrip}\n}\n")

puts "Imported #{names.length} pages and #{to_import.length - names.length} unlisted page(s) into src/#{course_id}/"
puts "Wrote #{topic_file.delete_prefix("#{ROOT}/")}; add it to src/#{course_id}/course.yml"
puts "Rewrote #{report[:links]} links."
puts 'Numbered references now written by the compiler (old text  =>  page it links to):'
report[:references].each { |reference| puts "  #{reference}" }
