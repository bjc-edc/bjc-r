require 'fileutils'
require 'rio'
require 'nokogiri'

class AtWork

	def initialize(path, language="en")
		@parentDir = path
		@language = language
		@language_ext = language == 'en' ? '' : ".#{language}"
		@currUnit = nil
		@currFile = nil
		@isNewUnit = true
		@currUnitNum = 0
		@currLab = ''
		@atwork_filename = "atwork#{language_ext}.html"
		@labPath = ''
		@currUnitName = nil
	end

	def language_ext
		@language_ext ||= @language == 'en' ? '' : ".#{@language}"
	end

	def unit()
		temp = @currUnit.match(/[A-Za-z]+/)
		return temp.to_s
	end

	def currUnit(str)
		@currUnit = str
	end

	def currFile(file)
		@currFile = file
	end

	def currFile(file)
		@currFile = file
	end

    def currUnitName(str)
        @currUnitName = str
    end


	def isNewUnit(boolean)
		@isNewUnit = boolean
	end

	def currUnitNum(num)
		@currUnitNum = num
	end

	def currLab()
		if @currUnit != nil
			labMatch = @currUnit.match(/Lab.+,/)
			labList =  labMatch.to_s.split(/,/)
			@currLab = labList.join
		end
	end

	def read_file(file)
		if File.exist?(file)
            isNewUnit(true)
			currFile(file)
            parse_unit(file)
			parse_atWork(file)
		end
	end

	def parse_unit(file)
		doc = File.open(file) { |f| Nokogiri::HTML(f) }
		title = doc.xpath("//title")
		str = title.to_s
		pattern = /<\/?\w+>/
		if (str == nil or not(@isNewUnit))
			nil
		else
			newStr = str.split(pattern)
			currUnit(newStr.join)
			currUnitNum(@currUnit.match(/\d+/).to_s)
			unit()
			isNewUnit(false)
		end
	end

	def language()
		if @language == "en"
			return "Computer Scientists @ Work"
		elsif @language == "es"
			return "El Científico de la Computación @ Acción"
		end
	end

	def createNewFile(fileName, linesList)
		i = 0
		File.new(fileName, "w")
		while (not(linesList[i].match(/<body>/)) and i < 30)
			if linesList[i].match(/<title>/)
				File.write(fileName, "<title>#{language()}</title>\n", mode: "a")
			else
				File.write(fileName, "#{linesList[i]}\n", mode: "a")
			end
			i += 1
		end
	end


	def add_HTML_end()
		Dir.chdir("#{@parentDir}/review")
		ending = "</body>\n</html>"
		if File.exist?(@atwork_filename)
			File.write(@atwork_filename, ending, mode: "a")
		end
	end


	def add_content_to_file(filename, data)
        currentDir = Dir.getwd()
        linesList =  rio(@currFile).lines[0..15]
        # puts currentDir
        # puts @parentDir
				Dir.chdir("#{@parentDir}/review")
        puts Dir.getwd()
        puts filename
		data = data.gsub(/&amp;/, "&")
		data.delete!("\n\n\\")
		if File.exist?(filename)
			File.write(filename, data, mode: "a")
		else
			createNewFile(filename, linesList)
			File.write(filename, data, mode: "a")
		end
        FileUtils.cd(currentDir)
	end

	def parse_atWork(file)
		doc = File.open(file) { |f| Nokogiri::HTML(f) }
		atWorkSet = doc.xpath("//div[@class = 'atwork']")
		atWorkSet.each do |node|
			child = node.children()
			child.before(add_unit_to_atwork())
		end
        if not(atWorkSet.empty?())
			add_to_file(atWorkSet.to_s)
		end

	end

	def add_unit_to_atwork()
		unitNum = return_unit(@currUnit)
		currentDir = Dir.getwd()
		FileUtils.cd("..")
		link = " <a href=\"#{get_url(@atwork_filename)}\">#{unitNum}</a>"
		FileUtils.cd(currentDir)
		return link
	end

	def add_unit_to_header()
		unitNum = return_unit(@currUnit)
		link = " <a href=\"#{get_url(@currFile)}\">#{unitNum}</a>"
		return link
	end

	def return_unit(str)
		list = str.scan(/(\d+)/)
		list.join('.')
	end

	def add_to_file(input)
		if input != ''
			result = input
			add_content_to_file(@atwork_filename, input)
		end
	end

	def get_url(file)
		localPath = Dir.getwd()
		linkPath = localPath.match(/bjc-r.+/).to_s
		"/#{linkPath}/#{file}"
		#add_content_to_file('urlLinks.txt', result)
	end

    def moveFile()
        src = "#{@parentDir}/review/#{@atwork_filename}"
        dst = "#{@parentDir}/#{@atwork_filename}"
        if File.exist?(dst)
            File.delete(dst)
        end
        FileUtils.copy_file(src, dst)
    end
end
