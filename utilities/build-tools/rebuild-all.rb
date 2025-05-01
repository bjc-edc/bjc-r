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
en_runner = Main.new(root: path, content: csp_dir, course: 'bjc4nyc', language: 'en')
en_runner.Main

puts
puts 'Rebuilding Espanol CSP'
es_runner = Main.new(root: path, content: csp_dir, course: 'bjc4nyc', language: 'es')
es_runner.Main

# puts
puts 'Rebuilding Sparks'
sparks_runner = Main.new(root: path, content: 'sparks/student-pages', course: 'sparks', language: 'en')
sparks_runner.Main

puts '*' * 80
puts 'WARNING: DO NOT COMMIT THESE UPDATES UNTIL THIS IS REMOVED'
puts '*' * 80
