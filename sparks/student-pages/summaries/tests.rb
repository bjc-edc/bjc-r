require_relative 'vocab'
require_relative 'main'
require 'rio'
require 'open-uri'
require 'nokogiri'

class Tests
	@type = 'testing'
	def initialize()
	end

	def nokogiriTest()
		doc = File.open("testpage.html") { |f| Nokogiri::HTML(f) }
		div = doc.xpath("//div[@class = 'vocabFullWidth']")
		vocab = div
		#Nokogiri::XML::DocumentFragment.parse(div.to_s)
		title = doc.xpath("//title")
		classname = vocab.at_css "div"
		children = classname.children()
		output = children.before('<id="ZZZZZZZZZZZZZZZZZZZ">')
		#attr(key, value = nil) { |node| ... }
		vocab.each do |node|
			children = node.children()
			children.before('<a href="ZZZZZZZZZZZZZZZZZZZ">')
			save_vocab_word(children)
		end
		#puts vocab
		#puts classname
	end

	def save_vocab_word(nodeSet)
		vocab = []
		#puts "nodeset = #{nodeSet}"
		#puts "nodeSet.inner_text() = #{nodeSet.inner_text()}"
		#puts "nodeSet.inner_html('//strong') = #{nodeSet.inner_html('//strong')}"
		#puts "nodeSet.slice(0) = #{nodeSet.slice(0)}"
		#puts "nodeSet.slice(1) = #{nodeSet.slice(1)}"
		#puts "nodeSet.slice(2) = #{nodeSet.slice(2)}"
		#puts "nodeSet.last() = #{nodeSet.last()}"
		#puts "nodeSet.text() = #{nodeSet.text()}"
		#puts "nodeSet.to_a() = #{nodeSet.to_a()}"
		#puts nodeSet.xpath("//div[@class = 'vocabFullWidth']//strong")
		nodeSet.xpath("//li//strong").each do |word|
			if not(vocab.include?(word.text))
				vocab.push(word.text())
			end
		end
		nodeSet.xpath("//p//strong").each do |word|
			if not(vocab.include?(word.text))
				vocab.push(word.text())
			end
		end
		puts vocab.length
		#n = nodeSet.children()
		#nodeSet.each do |node|
			#node.elements().each do |n|
			#	puts n.xpath("//strong")
			#end
			#puts node.xpath("//strong")
			#puts "node.child() = #{node.child()}"
			#puts node.content()
			#puts node.description()
			#puts node.elem?()
			#puts node.elements()
			#puts node.element_children()
			#puts node.inner_text()
			#puts node.text()
		#end
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

	def assessDataTest()
		sc = SelfCheck.new("C:/Users/I560638/bjc-r/TESTING/2-gossip-and-greet/2-customizing.html")
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