#! /usr/bin/env ruby

## This script will rebuild *all* index/summary pages in bjc-r/
## Run from the **root** of bjc-r/
## $ ruby utilties/build-tools/rebuild-all.rb

require_relative 'main'

ROOT = '/bjc-r'
path = ENV['PWD']
path = path.sub(/#{ROOT}\/.*$/, ROOT)
puts "Rebuilding all index/summaries from: #{path}"

en_runner = Main.new(root: path, cur_dir: "cur/programming", topic_dir: "nyc_bjc", language: "en")
en_runner.skip_test_prompt = true
en_runner.Main

es_runner = Main.new(root: path, cur_dir: "cur/programming", topic_dir: "nyc_bjc", language: "es")
es_runner.skip_test_prompt = true
es_runner.Main
