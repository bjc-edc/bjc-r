#! /usr/bin/env ruby

# Compare *.es.* to the English file
# use `diff` to see if they are the same.
# if they are the same, delete the *.es version.

SOURCE = ARGV[0]

all_images = Dir.glob("#{SOURCE}/**/*")
spanish_files = all_images.select { |path| path.match?('.es.') }
spanish_files.each do |es_path|
  en_path = es.path.sub('.es', '')
  if File.exists?(en_path)
    result = `diff -s #{en_path} #{es_path}`
    if result.match?('identical')
      puts "Deleting #{es_path}"
      File.delete(es_path)
    end
  end
end
