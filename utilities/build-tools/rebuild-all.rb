#! /usr/bin/env ruby
# frozen_string_literal: true

## This script will rebuild *all* index/summary pages in bjc-r/
## Run from the **root** of bjc-r/
## $ ruby utilties/build-tools/rebuild-all.rb

require_relative 'main'

ROOT = '/bjc-r'
path = ENV['PWD']
path = path.sub(%r{#{ROOT}/.*$}, ROOT)
puts "Rebuilding all index/summaries from: #{path}"

puts
puts 'Rebuilding English CSP'
en_runner = Main.new(root: path, content: 'cur/programming', topic_dir: 'nyc_bjc', language: 'en')
en_runner.skip_test_prompt = false
en_runner.Main

puts
puts 'Rebuilding Espanol CSP'
es_runner = Main.new(root: path, content: 'cur/programming', topic_dir: 'nyc_bjc', language: 'es')
es_runner.skip_test_prompt = false
es_runner.Main

puts '*' * 80
puts 'WARNING: DO NOT COMMIT THESE UPDATES UNTIL THIS IS REMOVED'
puts '*' * 80
