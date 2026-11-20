# frozen_string_literal: true

# Unit tests for the course compiler. Like build_tools_spec, these run against
# a small fixture in a temporary directory and need no browser:
#
#   bundle exec rspec utilities/specs/course_compiler_spec.rb

require 'fileutils'
require 'tmpdir'

require_relative '../build-tools/main'
require_relative '../build-tools/course_compiler'

# A throwaway checkout holding the source of one two-lab course.
module CompiledCourseFixture
  MANIFEST = <<~YAML
    id: demo
    title: Demo Course
    units:
      - 1-widgets.topic
  YAML

  TOPIC_FILE = <<~TOPIC
    title: Widgets

    {

    heading: Widget Basics
    \traw-html: <p>Some prose, not a page.</p>
    \tresource: Meet the <em>Widget</em> [1-widgets/1-basics/meet.html]
    \tquiz: Widget Quiz [1-widgets/1-basics/quiz.html]

    heading: Widget Practice
    \tresource: Using Widgets [1-widgets/2-practice/using.html]
    }
  TOPIC

  PAGES = {
    '1-widgets/1-basics/meet.html' => <<~HTML,
      <p>Next: <a href="/bjc-r/demo/1-widgets/2-practice/using.html" data-page-ref></a>,
      or <a href="quiz.html#q1" data-page-ref="short"></a>.</p>
      <p><a href="/bjc-r/demo/1-widgets/1-basics/hints.html">Hints</a>
      <img src="/bjc-r/img/widget.png" alt="a widget"></p>
    HTML
    '1-widgets/1-basics/quiz.html' => '<p><a href="../2-practice/using.html">Keep going</a></p>',
    '1-widgets/2-practice/using.html' => <<~HTML,
      <p><a href="https://example.com/">Elsewhere</a></p>
      <div class="vocab"><p>A <strong>Widget</strong> is a thing.</p></div>
    HTML
    '1-widgets/1-basics/hints.html' => '<p>A page no topic file lists.</p>'
  }.freeze

  def self.page(name, body)
    "<!DOCTYPE html>\n<html lang=\"en\"><head><title>#{name}</title></head>\n<body>\n#{body}\n</body></html>\n"
  end

  # Returns the root of the checkout, which has to be called "bjc-r".
  def self.build(directory)
    root = File.join(directory, 'bjc-r')
    write(File.join(root, 'src/demo/course.yml'), MANIFEST)
    write(File.join(root, 'src/demo/1-widgets.topic'), TOPIC_FILE)
    PAGES.each { |path, body| write(File.join(root, 'src/demo', path), page(File.basename(path, '.html'), body)) }
    write(File.join(root, 'img/widget.png'), 'not really a picture')
    root
  end

  def self.write(path, contents)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, contents)
  end
end

RSpec.describe CourseCompiler do
  let(:temporary_directory) { Dir.mktmpdir }
  let(:root) { CompiledCourseFixture.build(temporary_directory) }
  let(:out) { File.join(temporary_directory, 'site', 'bjc-r') }
  let(:compiler) { described_class.new(root: root, manifest: CourseManifest.new(source), out: out) }

  after { FileUtils.remove_entry(temporary_directory) }

  def source
    File.join(root, 'src', 'demo')
  end

  # What the compiler adds to a link to a page of the fixture's only unit.
  def context
    '?topic=demo/1-widgets.topic&course=demo.html'
  end

  # The compiled page at PATH, parsed.
  def compiled(path)
    Nokogiri::HTML5.parse(compiler.compile.files.fetch(File.join(out, 'demo', path)))
  end

  def edit(path)
    file = File.join(source, path)
    File.write(file, yield(File.read(file)))
  end

  describe 'numbering' do
    it 'titles each page with its unit, lab, and page number' do
      expect(compiled('1-widgets/1-basics/quiz.html').at_css('title').text)
        .to eq('Unit 1 Lab 1: Widget Basics, Page 2')
    end

    it 'numbers the unit and its labs in the topic file and serves pages from the course folder' do
      topic = compiler.compile.files.fetch(File.join(out, 'topic/demo/1-widgets.topic'))

      expect(topic).to include('title: Unit 1: Widgets', 'heading: Lab 2: Widget Practice',
                               'quiz: Widget Quiz [/bjc-r/demo/1-widgets/1-basics/quiz.html]')
    end

    it 'leaves a page that no topic file lists with its own title' do
      expect(compiled('1-widgets/1-basics/hints.html').at_css('title').text).to eq('hints')
    end

    it 'renumbers every title and reference when a lab moves' do
      edit('1-widgets.topic') do |topic|
        basics, practice = topic.scan(/^heading:.*?(?=^heading:|^\})/m)
        topic.sub(basics + practice, practice + basics)
      end

      expect(compiled('1-widgets/1-basics/meet.html').at_css('title').text)
        .to eq('Unit 1 Lab 2: Widget Basics, Page 1')
      expect(compiled('1-widgets/1-basics/meet.html').css('a').first.text)
        .to eq('Unit 1 Lab 1 Page 1: Using Widgets')
    end
  end

  describe 'links' do
    subject(:links) { compiled('1-widgets/1-basics/meet.html').css('a') }

    it 'gives a link to a listed page the context llab needs' do
      expect(links[0]['href']).to eq("/bjc-r/demo/1-widgets/2-practice/using.html#{context}")
    end

    it 'writes the text of a reference from the page it points at' do
      expect(links[0].text).to eq('Unit 1 Lab 2 Page 1: Using Widgets')
      expect(links[0].key?('data-page-ref')).to be(false)
    end

    it 'resolves a relative link, keeps its fragment, and writes a short reference' do
      expect(links[1]['href']).to eq("/bjc-r/demo/1-widgets/1-basics/quiz.html#{context}#q1")
      expect(links[1].text).to eq('Lab 1 Page 2: Widget Quiz')
    end

    it 'keeps inline markup from the topic file in a reference' do
      reference = '<a href="../1-basics/meet.html" data-page-ref></a>'
      edit('1-widgets/2-practice/using.html') { |page| page.sub('<p>', "<p>#{reference}") }

      expect(compiled('1-widgets/2-practice/using.html').at_css('a').inner_html)
        .to eq('Unit 1 Lab 1 Page 1: Meet the <em>Widget</em>')
    end

    it 'leaves links to unlisted pages and to other sites alone' do
      expect(links[2]['href']).to eq('/bjc-r/demo/1-widgets/1-basics/hints.html')
      expect(compiled('1-widgets/2-practice/using.html').at_css('a')['href']).to eq('https://example.com/')
    end
  end

  describe 'problems' do
    it 'stops the build when a link names a page that is not in the course' do
      edit('1-widgets/1-basics/quiz.html') { |page| page.sub('using.html', 'gone.html') }

      expect { compiler.compile }.to raise_error(described_class::CompileError, %r{links to /bjc-r/demo/.*gone\.html})
    end

    it 'stops the build when a link hard-codes its own context' do
      edit('1-widgets/1-basics/quiz.html') { |page| page.sub('using.html', 'using.html?topic=nyc_bjc/2.topic') }

      expect { compiler.compile }.to raise_error(described_class::CompileError, /hard-codes/)
    end

    it 'stops the build when a topic file lists a page that does not exist' do
      FileUtils.rm(File.join(source, '1-widgets/2-practice/using.html'))

      expect { compiler.compile }.to raise_error(described_class::CompileError, /1-widgets.topic lists/)
    end

    it 'reports every problem at once and writes nothing' do
      edit('1-widgets/1-basics/quiz.html') { |page| page.sub('using.html', 'gone.html') }
      edit('1-widgets/1-basics/meet.html') { |page| page.sub('hints.html', 'lost.html') }

      expect { compiler.compile }.to raise_error(described_class::CompileError) { |error|
        expect(error.problems.length).to eq(2)
      }
      expect(File.exist?(out)).to be(false)
    end

    it 'warns about a missing shared file without stopping the build' do
      FileUtils.rm(File.join(root, 'img/widget.png'))

      expect(compiler.compile.warnings).to contain_exactly(%r{meet\.html: /bjc-r/img/widget\.png does not exist})
    end
  end

  describe 'the compiled site' do
    before do
      compiler.compile.write
    end

    it 'has a course page that the existing tools can read' do
      expect(BJCCourse.new(root: out, course: 'demo').list_topics).to eq(['demo/1-widgets.topic'])
    end

    it 'removes a page that has left the source on the next build' do
      FileUtils.rm(File.join(source, '1-widgets/1-basics/hints.html'))
      edit('1-widgets/1-basics/meet.html') { |page| page.sub(%r{<a href="[^"]*hints.html">Hints</a>}, '') }
      described_class.new(root: root, manifest: CourseManifest.new(source), out: out).compile.write

      expect(File.exist?(File.join(out, 'demo/1-widgets/1-basics/hints.html'))).to be(false)
    end

    it 'can be summarized by the existing generators, unchanged' do
      original_directory = Dir.pwd
      expect { Main.new(root: out, content: 'demo', course: 'demo').Main }.to output(/All units complete/).to_stdout
      Dir.chdir(original_directory)

      expect(File.read(File.join(out, 'topic/demo/1-widgets.topic'))).to include('heading: Unit 1 Review')
    end
  end
end
