require 'fileutils'
require_relative 'vocab'

class Main

	def initialize(dir)
		@parentDir = dir
		@currFile = nil
		@currIndex = 0
		@currUnit = nil
		@topicLinks = []
		@currentLine = nil
		@currDir = dir
		@listUnitsDir = list_subdir(dir)
		@listLabsDir = []
	end

	def currDir(cwd)
		@currDir = cwd
	end

	def currFile(file)
		@currFile = file
	end

	def main(cwd)
		list_labs(@listUnitsDir)
	end

	def list_subdir(cwd)
		Dir.glob('*').select {|f| File.directory? f}
	end

	def parse_files()
		Dir.glob('*').select {|f| File.file? f}
	end

	def list_labs(cwd)
		for unit in cwd
			Dir.chdir(unit)
			@listLabsDir.push(list_subdir(unit))
		end
		Dir.chdir(cwd)
	end

	def parse_labs(currDir)
		for lab in currDir
		end
	end

	def list_file_content(file)
		file = File.open(file)
		file_data = file.read
		file_data.split
	end

	def read_file(file)
		currIndex = 0
		currFile = file
		File.foreach(file) do |line|
			something?
		end
	end

	def fileLanguage(file)
		file_name = File.basename(file)
		if /\w+\.html/.match?(file)
			lang = /\w+\.html/.match(file).to_s
			return lang.split[0]
		else
			return "en"
		end
	end

	def parse_topic_links(file)
		if @currLine.match(/<div class="topic_link">/)
		end
		pattern = /"\/bjc-r[^\s]+"/
		str.match(pattern)
	end

	def iter_start_at(file)
		'hello'
	end
end