#! /usr/bin/env ruby
# frozen_string_literal: true

## This script will rebuild *all* index/summary pages in bjc-r/
## Run from the **root** of bjc-r/
## $ ruby utilties/build-tools/rebuild-all.rb

require_relative 'main'

ROOT = '/bjc-r'
path = Dir.pwd # #ENV('PWD')
path = path.sub(%r{#{ROOT}/.*$}, ROOT)
puts "Rebuilding all index/summaries from: #{path}"

csp_dir = 'cur/programming'
puts
puts 'Rebuilding English CSP'
# TODO: this should not be necessary. If the files already exist,
# # then we get an error about `topic.txt` not being found.
# Delete the files so that they are rebuilt.
output_files = %w|atwork.html vocab-index.html|
output_files.each do |file|
  full_path = File.join(path, csp_dir, file)
  File.delete(full_path) if File.exist?(full_path)
end

TO_RUN = [
  { course: 'bjc4nyc', language: 'en', content: csp_dir },
  { course: 'bjc4nyc', language: 'es', content: csp_dir },
  { course: 'sparks', language: 'en', content: 'sparks/student-pages' }
]

# TODO:
# Allow passing in --only and --lang to limit the rebuild.
args = ARGV
if args.include?('--only')
  only_course = args[args.index('--only') + 1]
  TO_RUN.select! { |options| options[:course] == only_course }
end
if args.include?('--lang')
  only_language = args[args.index('--lang') + 1]
  TO_RUN.select! { |options| options[:language] == only_language }
end
puts "Rebuilding for courses: #{TO_RUN.map { |options| options[:course] }.uniq.join(', ')}"
puts "Rebuilding for languages: #{TO_RUN.map { |options| options[:language] }.uniq.join(', ')}"
puts

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
