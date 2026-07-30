#! /usr/bin/env ruby
# frozen_string_literal: true

# Compare *.es.* to the English file
# use `diff` to see if they are the same.
# if they are the same, delete the *.es version.

SOURCE = ARGV[0] || 'img/'

all_images = Dir.glob("#{Dir.getwd}/#{SOURCE}/**/*")
spanish_files = all_images.grep(/\w+\.es\.(png|jpeg|gif|jpg|svg)/)
spanish_files.each do |es_path|
  en_path = es_path.sub('.es', '')
  next unless File.exist?(en_path)

  result = `diff -s '#{en_path}' '#{es_path}'`
  if result.match?('identical')
    puts "Deleting #{es_path}"
    File.delete(es_path)
  end
end
