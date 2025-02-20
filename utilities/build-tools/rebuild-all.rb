#! /usr/bin/env ruby
# frozen_string_literal: true

## This script will rebuild *all* index/summary pages in bjc-r/
## Run from the **root** of bjc-r/
## $ ruby utilties/build-tools/rebuild-all.rb

require_relative 'main'

ROOT = '/bjc-r'
path = Dir.pwd # #ENV('PWD')
puts path
path = path.sub(%r{#{ROOT}/.*$}, ROOT)
puts "Rebuilding all index/summaries from: #{path}"

puts
puts 'Rebuilding English CSP'
en_runner = Main.new(root: path, content: 'cur/programming', course: 'bjc4nyc', language: 'en')
en_runner.skip_test_prompt = true
en_runner.Main

# puts
# puts 'Rebuilding Espanol CSP'
# es_runner = Main.new(root: path, content: 'cur/programming', course: 'bjc4nyc', language: 'es')
# es_runner.skip_test_prompt = true
# es_runner.Main

# puts
# puts 'Rebuilding Sparks'
# sparks_runner = Main.new(root: path, content: 'sparks/student-pages', course: 'sparks', language: 'en')
# sparks_runner.skip_test_prompt = true
# sparks_runner.Main

puts '*' * 80
puts 'WARNING: DO NOT COMMIT THESE UPDATES UNTIL THIS IS REMOVED'
puts '*' * 80
