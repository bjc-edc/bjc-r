# frozen_string_literal: true

# Unit tests for the curriculum build tools. These run against small fixtures in
# a temporary directory, so they need no browser and no network:
#
#   bundle exec rspec utilities/specs/build_tools_spec.rb

require 'fileutils'
require 'tmpdir'

require_relative '../build-tools/main'

# Builds a throwaway bjc-r checkout containing one course, one topic file, and a
# handful of curriculum pages, so a whole build can be run end to end.
module BuildToolsFixture
  COURSE_PAGE = <<~HTML
    <div class="topic_link">
      <a href="/bjc-r/topic/topic.html?topic=testing/1-widgets.topic">Unit 1</a>
    </div>
    <div class="todo">
      <div class="topic_link">
        <a href="/bjc-r/topic/topic.html?topic=testing/2-hidden.topic">Unit 2 (in progress)</a>
      </div>
    </div>
  HTML

  # Note the deliberate quirks, all of which appear in the real topic files:
  # "quiz:" with no space after the colon, a page whose title contains the word
  # "Review", a heading with a second colon in it, and a // comment.
  TOPIC_FILE = <<~TOPIC
    title: Unit 1: Widgets

    {

    heading: Lab 1: Widget Basics // a trailing comment
    \traw-html: <p>Some prose, not a page.</p>
    \tresource: Meet the Widget [/bjc-r/cur/testing/1-widgets/1-basics/1-meet.html]
    \tquiz:Widget Quiz [/bjc-r/cur/testing/1-widgets/1-basics/2-quiz.html]

    heading: Lab 2: Widget Practice
    \tresource: Review Your Widget [/bjc-r/cur/testing/1-widgets/2-practice/1-review.html]
    \tresource: A Page That Does Not Exist [/bjc-r/cur/testing/1-widgets/2-practice/9-missing.html]
    }
  TOPIC

  VOCAB_BOX = <<~HTML
    <div class="vocab">
      <p>A <strong>Widget</strong> is a thing.</p>
    </div>
  HTML

  SELF_CHECK_BOX = <<~HTML
    <div class="assessment-data" responseIdentifier="ri1">
      <div class="responseDeclaration" identifier="ri1"></div>
    </div>
  HTML

  EXAM_BOX = '<div class="examFullWidth"><p>On the exam, widgets are called gizmos.</p></div>'
  ATWORK_BOX = '<div class="atwork"><p>Ada Lovelace built widgets.</p></div>'

  PAGES = {
    '1-basics/1-meet.html' => ['Unit 1 Lab 1: Widget Basics, Page 1', VOCAB_BOX + ATWORK_BOX],
    '1-basics/2-quiz.html' => ['Unit 1 Lab 1: Widget Basics, Page 2', SELF_CHECK_BOX + EXAM_BOX],
    '2-practice/1-review.html' => ['Unit 1 Lab 2: Widget Practice, Page 1', VOCAB_BOX]
  }.freeze

  def self.page(title, body)
    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <title>#{title}</title>
      </head>
      <body>
      #{body}
      </body>
      </html>
    HTML
  end

  # Returns the path to the bjc-r folder of a fresh fixture checkout.
  def self.build(parent_directory)
    root = File.join(parent_directory, 'bjc-r')
    write(File.join(root, 'course', 'test.html'), COURSE_PAGE)
    %w[1-widgets.topic 2-hidden.topic 1-teaching-guide.topic].each do |file_name|
      write(File.join(root, 'topic', 'testing', file_name), TOPIC_FILE)
    end
    PAGES.each do |relative_path, (title, body)|
      write(File.join(root, 'cur', 'testing', '1-widgets', relative_path), page(title, body))
    end
    root
  end

  # Adds a second unit to the course whose self-check markup is inconsistent, so
  # building it raises. Used to prove a failed run writes nothing at all.
  def self.add_broken_unit(root)
    course_file = File.join(root, 'course', 'test.html')
    File.write(course_file, <<~HTML, mode: 'a')
      <div class="topic_link">
        <a href="/bjc-r/topic/topic.html?topic=testing/2-gadgets.topic">Unit 2</a>
      </div>
    HTML
    write(File.join(root, 'topic', 'testing', '2-gadgets.topic'), <<~TOPIC)
      title: Unit 2: Gadgets

      {

      heading: Lab 1: Gadget Basics
      \tresource: Meet the Gadget [/bjc-r/cur/testing/2-gadgets/1-basics/1-meet.html]
      }
    TOPIC
    broken_self_check = <<~HTML
      <div class="assessment-data" responseIdentifier="ri1">
        <div class="responseDeclaration" identifier="ri2"></div>
      </div>
    HTML
    write(File.join(root, 'cur', 'testing', '2-gadgets', '1-basics', '1-meet.html'),
          page('Unit 2 Lab 1: Gadget Basics, Page 1', broken_self_check))
  end

  def self.write(path, contents)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, contents)
  end
end

RSpec.describe 'build tools', type: :build_tools do
  let(:temporary_directory) { Dir.mktmpdir }
  let(:root) { BuildToolsFixture.build(temporary_directory) }

  # Main chdir's into the content folder as it works, so put it back afterwards.
  around do |example|
    original_directory = Dir.pwd
    example.run
    Dir.chdir(original_directory)
  end

  after { FileUtils.remove_entry(temporary_directory) }

  # Every file in the fixture checkout, so a run can be checked for accidental
  # writes or deletions as well as for content changes.
  def generated_files
    Dir.glob(File.join(root, '**', '*')).select { |path| File.file?(path) }.to_h do |path|
      [path.delete_prefix("#{root}/"), File.read(path)]
    end
  end

  describe BJCCourse do
    subject(:course) { described_class.new(root: root, course: 'test') }

    it 'lists only topics that are visible on the course page' do
      expect(course.list_topics).to eq(['testing/1-widgets.topic'])
    end

    it 'lists topic file names without their folder' do
      expect(course.list_topics_no_path).to eq(['1-widgets.topic'])
    end
  end

  describe BJCTopic do
    subject(:topic) { described_class.new(File.join(root, 'topic', 'testing', '1-widgets.topic')) }

    it 'reads the unit title' do
      expect(topic.title.strip).to eq('Unit 1: Widgets')
    end

    it 'reads the unit number' do
      expect(topic.unit_number).to eq('1')
    end

    it 'keeps everything after the first colon of a heading' do
      expect(topic.parse[:topics].first[:content].map { |section| section[:title] })
        .to eq(['Lab 1: Widget Basics', 'Lab 2: Widget Practice'])
    end

    describe '#iterate_curriculum_pages' do
      subject(:pages) do
        collected = []
        topic.iterate_curriculum_pages { |page| collected << page }
        collected
      end

      it 'yields every curriculum page in topic-file order' do
        expect(pages.map { |page| page[:path] }).to eq(
          ['/bjc-r/cur/testing/1-widgets/1-basics/1-meet.html',
           '/bjc-r/cur/testing/1-widgets/1-basics/2-quiz.html',
           '/bjc-r/cur/testing/1-widgets/2-practice/1-review.html',
           '/bjc-r/cur/testing/1-widgets/2-practice/9-missing.html']
        )
      end

      it 'numbers labs and pages from one, restarting each lab' do
        expect(pages.map { |page| [page[:lab_number], page[:page_number]] })
          .to eq([[1, 1], [1, 2], [2, 1], [2, 2]])
      end

      it 'includes a "quiz:" entry with no space after the colon' do
        expect(pages.map { |page| page[:path] })
          .to include('/bjc-r/cur/testing/1-widgets/1-basics/2-quiz.html')
      end

      it 'includes a page whose title happens to contain the word "Review"' do
        expect(pages.map { |page| page[:path] })
          .to include('/bjc-r/cur/testing/1-widgets/2-practice/1-review.html')
      end

      it 'skips raw-html and other entries without a URL' do
        expect(pages.map { |page| page[:path] }).to all(be_a(String))
      end

      it 'reports the unit and the content folder shared by every page' do
        expect(pages.first).to include(unit: '1', unit_path: '/bjc-r/cur/testing/1-widgets')
      end
    end

    describe '#longest_common_prefix' do
      it 'compares whole folders rather than characters' do
        expect(topic.longest_common_prefix(['/a/b/L1', '/a/b/L2'])).to eq('/a/b')
      end

      it 'is empty for no paths' do
        expect(topic.longest_common_prefix([])).to eq('')
      end
    end

    describe '.summary_heading?' do
      it 'recognizes the generated English and Spanish review headings' do
        expect(described_class).to be_summary_heading('heading: Unit 3 Review')
        expect(described_class).to be_summary_heading('heading: Unidad 3 Revision')
      end

      it 'ignores lab headings that merely mention a review' do
        expect(described_class).not_to be_summary_heading('heading: Lab 2: Review Your Widget')
      end

      it 'ignores nil' do
        expect(described_class).not_to be_summary_heading(nil)
      end
    end
  end

  describe BJCHelpers do
    subject(:helper) do
      Class.new do
        include BJCHelpers

        def initialize(root)
          @rootDir = root
          @currUnit = 'Unit 3 Lab 2: Interactive Pet, Activity 4'
        end
      end.new(root)
    end

    describe '#generate_url_suffix' do
      it 'adds only the topic and course parameters' do
        suffix = helper.generate_url_suffix('sparks', '1-functions-data.topic', 'sparks')

        expect(suffix).to eq('?topic=sparks/1-functions-data.topic&course=sparks.html')
        expect(suffix).not_to include('novideo', 'noassignment')
      end
    end

    describe '#set_current_topic' do
      it 'keeps the topic folder and the course the right way round' do
        helper.set_current_topic('nyc_bjc', 'bjc4nyc')

        expect(described_class.current_topic).to eq(topic_folder: 'nyc_bjc', course: 'bjc4nyc')
      end

      it 'replaces the previous topic instead of accumulating' do
        helper.set_current_topic('nyc_bjc', 'bjc4nyc')
        helper.set_current_topic('sparks', 'sparks')

        expect(described_class.current_topic).to eq(topic_folder: 'sparks', course: 'sparks')
      end
    end

    it 'derives the unit reference from the page title' do
      expect(helper.unit_reference).to eq('3.2.4')
    end

    it 'derives the lab heading from the page title' do
      expect(helper.currLab).to eq('Lab 2: Interactive Pet')
    end

    describe '#report_topic_file_change' do
      let(:topic_file) { File.join(root, 'topic', 'testing', '1-widgets.topic') }

      it 'clearly identifies a topic file that is about to change' do
        expect { helper.report_topic_file_change(topic_file, 'brand new contents') }
          .to output(
            %r{NOTICE: Build tools modified topic file: topic/testing/1-widgets\.topic.*before committing}m
          ).to_stdout
      end

      it 'says nothing when the contents are unchanged' do
        expect { helper.report_topic_file_change(topic_file, File.read(topic_file)) }
          .not_to output.to_stdout
      end
    end
  end

  describe Main do
    subject(:runner) do
      described_class.new(root: root, content: 'cur/testing', course: 'test', language: 'en')
    end

    let(:unit_directory) { File.join(root, 'cur', 'testing', '1-widgets') }
    let(:topic_file) { File.join(root, 'topic', 'testing', '1-widgets.topic') }

    describe '#unit_topic_file?' do
      it 'accepts a unit topic file in the build language' do
        expect(runner).to be_unit_topic_file('testing/1-widgets.topic')
      end

      it 'rejects teacher guides, other languages, and unnumbered topics' do
        expect(runner).not_to be_unit_topic_file('testing/1-teaching-guide.topic')
        expect(runner).not_to be_unit_topic_file('testing/1-widgets.es.topic')
        expect(runner).not_to be_unit_topic_file('testing/glossary.topic')
      end
    end

    describe '#file_language' do
      it 'reads the language suffix, defaulting to English' do
        expect(runner.file_language('1-intro-loops.es.topic')).to eq('es')
        expect(runner.file_language('1-intro-loops.topic')).to eq('en')
      end
    end

    it 'maps llab URLs onto paths in this checkout and back' do
      path = runner.url_to_path('/bjc-r/cur/testing/1-widgets/1-basics/1-meet.html')

      expect(path).to eq(File.join(root, 'cur/testing/1-widgets/1-basics/1-meet.html'))
      expect(runner.path_to_url(path)).to eq('/bjc-r/cur/testing/1-widgets/1-basics/1-meet.html')
    end

    describe '#topic_contents_without_summaries' do
      it 'drops the closing brace so a summary section can be appended' do
        expect(runner.topic_contents_without_summaries(topic_file)).to end_with('9-missing.html]')
      end

      it 'drops a previously generated summary section' do
        File.write(topic_file, <<~TOPIC)
          title: Unit 1: Widgets

          {
          \tresource: A Page [/bjc-r/cur/testing/1-widgets/1-basics/1-meet.html]

          heading: Unit 1 Review
          \tresource: Vocabulary [/bjc-r/cur/testing/1-widgets/unit-1-vocab.html]
          }
        TOPIC

        expect(runner.topic_contents_without_summaries(topic_file)).to end_with('1-meet.html]')
      end
    end

    describe 'a full run' do
      before { runner.Main }

      it 'writes a vocab page with a unit heading and a heading per lab' do
        vocab = File.read(File.join(unit_directory, 'unit-1-vocab.html'))

        expect(vocab).to include('<title>Unit 1 Vocabulary</title>')
        expect(vocab).to include('<h2>Unit 1: Widgets</h2>')
        expect(vocab).to include('<h3>Lab 1: Widget Basics</h3>', '<h3>Lab 2: Widget Practice</h3>')
      end

      it 'closes every generated page' do
        %w[unit-1-vocab.html unit-1-self-check.html unit-1-exam-reference.html].each do |file_name|
          expect(File.read(File.join(unit_directory, file_name))).to end_with("</body>\n</html>\n")
        end
      end

      it 'writes the "@ Work" page once, in the content folder' do
        atwork = File.read(File.join(root, 'cur', 'testing', 'atwork.html'))

        expect(atwork).to include('Ada Lovelace built widgets.')
        expect(atwork.scan('</html>').length).to eq(1)
      end

      it 'links each "@ Work" box back to the page it came from' do
        atwork = File.read(File.join(root, 'cur', 'testing', 'atwork.html'))

        expect(atwork).to include('href="/bjc-r/cur/testing/1-widgets/1-basics/1-meet.html"')
      end

      it 'links vocab index entries through the topic and course they belong to' do
        index = File.read(File.join(root, 'cur', 'testing', 'vocab-index.html'))

        expect(index).to include('?topic=testing/1-widgets.topic&amp;course=test.html')
      end

      it 'adds the generated pages to the unit topic file' do
        expect(File.read(topic_file)).to include(
          'heading: Unit 1 Review',
          "\tresource: Vocabulary [/bjc-r/cur/testing/1-widgets/unit-1-vocab.html]",
          "\tresource: Self-Check Questions [/bjc-r/cur/testing/1-widgets/unit-1-self-check.html]"
        )
      end

      it 'leaves the topic file parsable, with exactly one summary section' do
        titles = BJCTopic.new(topic_file).parse[:topics].first[:content].map { |section| section[:title] }

        expect(titles.count { |title| BJCTopic.summary_heading?(title) }).to eq(1)
      end

      it 'produces the same output when run again' do
        before_rerun = generated_files
        described_class.new(root: root, content: 'cur/testing', course: 'test', language: 'en').Main

        expect(generated_files).to eq(before_rerun)
      end
    end

    # GitHub Actions checks out to /home/runner/work/<repo>/<repo>, so the
    # checkout sits inside a folder of the same name. Anything that finds the
    # site root by matching "bjc-r" in a path finds the wrong one there, and
    # every generated link comes out as /bjc-r/bjc-r/...
    context 'when the checkout is nested inside a folder of the same name' do
      let(:root) { BuildToolsFixture.build(File.join(temporary_directory, 'bjc-r')) }

      before { runner.Main }

      it 'still finds the content to build' do
        expect(File).to exist(File.join(unit_directory, 'unit-1-vocab.html'))
      end

      it 'still writes single-rooted URLs' do
        pages = %w[unit-1-vocab.html unit-1-self-check.html]
                .map { |name| File.read(File.join(unit_directory, name)) }
                .push(File.read(File.join(root, 'cur', 'testing', 'atwork.html')))

        expect(pages).to all(include('href="/bjc-r/cur/testing/1-widgets/'))
        expect(pages.join).not_to include('/bjc-r/bjc-r/')
      end
    end

    it 'writes nothing at all when a later unit fails to build' do
      # Unit 1 builds fine and is staged in memory; unit 2 then raises. Because
      # every write happens at the very end, the checkout is left untouched.
      BuildToolsFixture.add_broken_unit(root)
      before_run = generated_files

      expect { runner.Main }.to raise_error(/Response id mismatch/)
      expect(generated_files).to eq(before_run)
    end
  end
end
