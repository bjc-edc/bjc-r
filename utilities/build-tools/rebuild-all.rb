#! /usr/bin/env ruby

## This script will rebuild *all* index/summary pages in bjc-r/
## Run from the **root** of bjc-r/
## $ ruby utilties/build-tools/rebuild-all.rb

require_relative 'main'

puts "Rebuilding all index/summaries from: #{ENV['PWD']}"
puts
puts "Rebuilding English CSP"
enRunner = Main.new(root: ENV['PWD'], content: 'cur/programming', topic_dir: 'nyc_bjc', language: 'en')
enRunner.skip_test_prompt = true
enRunner.Main

puts
puts "Rebuilding Espanol CSP"
esRunner = Main.new(root: ENV['PWD'], content: 'cur/programming', topic_dir: 'nyc_bjc', language: 'es')
esRunner.skip_test_prompt = true
esRunner.Main

# puts
# puts "Rebuilding Sparks"
# sparks = Main.new(root: ENV['PWD'], content: 'sparks/student-pages', topic_dir: 'sparks')
# sparks.skip_test_prompt = true
# sparks.Main
