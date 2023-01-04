require_relative 'vocab'
require_relative 'main'

class Tests
	@type = 'testing'
	def initialize(n)
		@testName = n
	end

	def get_testName()
		@testName
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