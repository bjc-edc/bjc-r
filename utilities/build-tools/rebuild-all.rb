#! /usr/bin/env ruby
# frozen_string_literal: true

## This script will rebuild *all* index/summary pages in bjc-r/
## Run from the **root** of bjc-r/
## $ ruby utilties/build-tools/rebuild-all.rb

require_relative 'main'

ROOT = '/bjc-r'
path = Dir.pwd # #ENV('PWD')
path = path.sub(%r{#{ROOT}/.*$}, ROOT)

csp_dir = 'cur/programming'

TO_RUN = [
  { course: 'bjc4nyc', language: 'en', content: csp_dir },
  { course: 'bjc4nyc', language: 'es', content: csp_dir },
  { course: 'sparks', language: 'en', content: 'sparks/student-pages' }
]

if ARGV.include?('--only')
  only_course = ARGV[ARGV.index('--only') + 1]
  TO_RUN.select! { |options| options[:course] == only_course }
end
if ARGV.include?('--lang')
  only_language = ARGV[ARGV.index('--lang') + 1]
  TO_RUN.select! { |options| options[:language] == only_language }
end

puts '*' * 80
puts <<~TEXT
  Rebuilding all index/summaries
    Directory: #{path}
    Courses: #{TO_RUN.map { |options| options[:course] }.uniq.join(', ')}
    Languages: #{TO_RUN.map { |options| options[:language] }.uniq.join(', ')}
TEXT

TO_RUN.each do |options|
  options => { course:, language:, content: }
  puts "Rebuilding #{course} (#{language})"
  runner = Main.new(root: path, content: content, course: course, language: language)
  runner.Main
  puts '--' * 40
end

puts '*' * 80
puts 'WARNING: DO NOT COMMIT THESE UPDATES UNTIL THIS IS REMOVED'
puts '*' * 80
