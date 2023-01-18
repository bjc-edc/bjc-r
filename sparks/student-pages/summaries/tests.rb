require_relative 'vocab'
require_relative 'main'
require 'rio'

class Tests
	@type = 'testing'
	def initialize()
	end

	def get_testName()
		@testName
	end

	def allMain()
	end

	def parse_vocab()
		v = Vocab.new(Dir.getwd())
		v.read_file('testpage.html')
	end

	def allVocab()
		v = Vocab.new(Dir.getwd())
		test1()
		test2()
		test3()
		test4()
		test5()
		test6()
		test7()
	end


	def languageTest()
		m = Main.new("C:/Users/I560638/bjc-r/TESTING/1-introduction/1-building-an-app", "C:/Users/I560638/bjc-r/topic/nyc_bjc")
		puts m.fileLanguage("1-creating-a-snap-account.es.html")
		puts m.fileLanguage("1-creating-a-snap-account.html")
	end

	def mainCSP()
		m = Main.new("C:/Users/I560638/bjc-r/TESTING", "C:/Users/I560638/bjc-r/topic/nyc_bjc", "en")
		m.Main()
	end

	def mainCSPSpanish()
		m = Main.new("C:/Users/I560638/bjc-r/TESTING", "C:/Users/I560638/bjc-r/TESTING/nyc_bjc", 'es')
		m.Main()
	end

	def mainTest()
		m = Main.new("C:/Users/I560638/bjc-r/sparks/student-pages", "C:/Users/I560638/bjc-r/topic/sparks")
		m.Main()
	end

	def crawl_allTopicPages()
		m = Main.new("C:/Users/I560638/bjc-r/sparks/student-pages", "C:/Users/I560638/bjc-r/topic/sparks")
		m.parse_allTopicPages("C:/Users/I560638/bjc-r/topic/sparks")
	end
	
	def getFolderTest()
		m = Main.new(Dir.getwd())
		unitNamePattern = /U1/
		m.getFolder(unitNamePattern, "C:/Users/I560638/bjc-r/sparks/student-pages")
	end	

	def parse_topicsFileTest()
		m = Main.new("C:/Users/I560638/bjc-r/sparks/student-pages", "C:/Users/I560638/bjc-r/topic/sparks")
		m.parse_units('topics.txt')
	end

	def isTopicTest()
		v = Vocab.new(Dir.getwd())
		main = Main.new(Dir.getwd())
		#strList = File.readlines('testTopics.topic')
		str = 'title: Unit 1: Functions and Data

			{		
		
			heading:  Lab 1: Introduction to Snap<em>!</em>
			raw-html: <img class="imageRight" src="/bjc-r/sparks/img/U1/lab01/say-hello-fancy-with-inputs-repornéih hóu ᕼย𝕒Ｎ" />
			'
		strList = str.split(/\n/)
		strList.each do |line|
			bool = main.isTopic(line)
			puts "#{bool} --- #{line}\n"
		end
	end

	def parse_topicPageTest()
		main = Main.new(Dir.getwd())
		main.parse_rawTopicPage('testTopics.topic')
	end

	def test1()
		v = Vocab.new(Dir.getwd())
		v.add_content_to_file('test.txt', 'hello world \n')
		v.add_content_to_file('test.txt', 'dogs are  \n')
		v.read_file('testpage.html')
	end

	def test2()
		v = Vocab.new(Dir.getwd())
		v.is_vocab_word('testpage.html', )
	end

	def test3()
		dir = Dir.getwd()
		m = Main.new(dir)
		m.main(dir)
	end

	def test4()
		v = Vocab.new(Dir.getwd())
		str = '<div class="vocabFullWidth"><!--<strong>: Reporters</strong> and <strong>Inputs</strong>-->'
		if v.parse_vocab_header(str)
			true
		else
			false
		end
	end

	def test5()
		v = Vocab.new(Dir.getwd())
		str = '<div class="vocabFullWidth"><!--<strong>: Reporters</strong> and <strong>Inputs</strong>-->'
		if v.parse_vocab_header(str) != []
			v.parse_vocab_header(str)
		else
			'bleh'
		end
	end

	def test6()
		v = Vocab.new(Dir.getwd())
		str = '<div class="vocabFullWidth"><!--<strong>: Reporters</strong> and <strong>Inputs</strong>-->'
		headerList = v.parse_vocab_header(str)
		if headerList != []
			headerList
			v.currUnit('Unit 1 Topic 2, Activity 3')
			v.add_vocab_unit_to_header(headerList)
		else
			puts 'bleh'
		end
	end

	
	def test7()
		v = Vocab.new(Dir.getwd())
		str = '<div class="vocabFullWidth"><!--<strong>: Reporters</strong> and <strong>Inputs</strong>-->'
		headerList = v.parse_vocab_header(str)
		if headerList != []
			puts headerList
			puts v.currUnit('Unit 1 Topic 2, Activity 3')
			v.add_vocab_unit_to_header(headerList)
		else
			headerList
		end
	end

end