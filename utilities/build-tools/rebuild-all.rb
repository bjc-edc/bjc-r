#! /usr/bin/env ruby

## This script will rebuild *all* index/summary pages in bjc-r/
## Run from the **root** of bjc-r/
## $ ruby utilties/build-tools/rebuild-all.rb

require_relative 'main'

puts "Rebuilding all index/summaries from: #{ENV['PWD']}"

enRunner = Main.new(root: ENV['PWD'], cur_dir: "programming", topic_dir: "nyc_bjc", language: "en")
enRunner.Main

esRunner = Main.new(root: ENV['PWD'], cur_dir: "programming", topic_dir: "nyc_bjc", language: "es")
esRunner.Main
