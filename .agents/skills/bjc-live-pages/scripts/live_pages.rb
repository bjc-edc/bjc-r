#!/usr/bin/env ruby
# frozen_string_literal: true

# Lists the pages that are actually part of the live site: everything reachable
# from the five course pages, plus the handful of standalone "general" pages.
# This is the same list the accessibility specs test, built by the same parser.
#
#   bundle exec ruby .agents/skills/bjc-live-pages/scripts/live_pages.rb [options]
#
#   --course NAME   Only this group. Repeatable. One of: bjc4nyc, bjc4nyc.es,
#                   sparks, bjc4nyc_teacher, sparks-teacher, general
#   --urls          Print site URLs (with ?topic=...&course=...) instead of files
#   --count         Print only a count per group
#
# The default output is one repo-relative file path per line, de-duplicated,
# ready for `xargs grep` or `xargs sed`.

require 'optparse'
require_relative '../../../../utilities/specs/bjc_helper'

options = { courses: [], urls: false, count: false }
OptionParser.new do |opts|
  opts.on('--course NAME') { |name| options[:courses] << name }
  opts.on('--urls') { options[:urls] = true }
  opts.on('--count') { options[:count] = true }
end.parse!

ROOT = File.expand_path('../../../..', __dir__)

# '/bjc-r/cur/page.html?topic=x' => 'cur/page.html'; the site root => 'index.html'
def file_for(url)
  path = url.split(/[?#]/).first.delete_prefix('/bjc-r').delete_prefix('/')
  path.empty? ? 'index.html' : path
end

# Building the list logs progress to stdout; keep our output clean for pipes.
real_stdout = $stdout
$stdout = $stderr
groups = BJCSpecs.complete_bjc_grouped_file_list(BJCSpecs::COURSES)
$stdout = real_stdout

unknown = options[:courses] - groups.keys
abort "Unknown course: #{unknown.join(', ')}. Choose from: #{groups.keys.join(', ')}" if unknown.any?
groups = groups.slice(*options[:courses]) if options[:courses].any?

if options[:count]
  groups.each { |name, urls| puts "#{name}\t#{urls.map { |u| file_for(u) }.uniq.size}" }
elsif options[:urls]
  puts groups.values.flatten.uniq
else
  files = groups.values.flatten.map { |url| file_for(url) }.uniq.sort
  missing = files.reject { |file| File.exist?(File.join(ROOT, file)) }
  warn "#{missing.size} listed pages do not exist on disk:\n  #{missing.join("\n  ")}" if missing.any?
  puts files - missing
end
