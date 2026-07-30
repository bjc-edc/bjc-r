# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

require_relative '../build-tools/bjc_helpers'
require_relative '../build-tools/course'

RSpec.describe BJCCourse do
  subject(:course) { described_class.new(root: root, course: 'test') }

  let(:temporary_directory) { Dir.mktmpdir }
  let(:root) { File.join(temporary_directory, 'bjc-r') }
  let(:course_file) { File.join(root, 'course', 'test.html') }

  before do
    FileUtils.mkdir_p(File.dirname(course_file))
    File.write(course_file, <<~HTML)
      <div class="topic_link">
        <a href="/bjc-r/topic/topic.html?topic=test/1-visible.topic">Visible topic</a>
      </div>
      <div class="todo">
        <div class="topic_link">
          <a href="/bjc-r/topic/topic.html?topic=test/2-todo.topic">Todo topic</a>
        </div>
      </div>
      <div class="comment">
        <div class="topic_link">
          <a href="/bjc-r/topic/topic.html?topic=test/3-comment.topic">Comment topic</a>
        </div>
      </div>
      <div class="commentBig">
        <div class="topic_link">
          <a href="/bjc-r/topic/topic.html?topic=test/4-comment-big.topic">Large comment topic</a>
        </div>
      </div>
      <div class="ap-standard">
        <div class="topic_link">
          <a href="/bjc-r/topic/topic.html?topic=test/5-ap-standard.topic">AP standard topic</a>
        </div>
      </div>
      <div class="csta-standard">
        <div class="topic_link">
          <a href="/bjc-r/topic/topic.html?topic=test/6-csta-standard.topic">CSTA standard topic</a>
        </div>
      </div>
    HTML
  end

  after { FileUtils.remove_entry(temporary_directory) }

  it 'lists only topics visible on the course page' do
    expect(course.list_topics).to eq(['test/1-visible.topic'])
  end
end

RSpec.describe BJCHelpers do
  subject(:helper) do
    Class.new do
      include BJCHelpers

      def initialize(root)
        @rootDir = root
      end
    end.new(root)
  end

  let(:temporary_directory) { Dir.mktmpdir }
  let(:root) { File.join(temporary_directory, 'bjc-r') }

  after { FileUtils.remove_entry(temporary_directory) }

  describe '#generate_url_suffix' do
    it 'adds only the topic and course parameters' do
      suffix = helper.generate_url_suffix('sparks', '1-functions-data.topic', 'sparks')

      expect(suffix).to eq('?topic=sparks/1-functions-data.topic&course=sparks.html')
      expect(suffix).not_to include('novideo', 'noassignment')
    end
  end

  describe '#report_topic_file_change' do
    let(:topic_file) { File.join(root, 'topic', 'test.topic') }

    before do
      FileUtils.mkdir_p(File.dirname(topic_file))
      File.write(topic_file, "updated topic\n")
    end

    it 'clearly identifies a modified topic file' do
      expect do
        helper.report_topic_file_change(topic_file, "original topic\n")
      end.to output(
        %r{NOTICE: Build tools modified topic file: topic/test\.topic.*Review this file before committing}m
      ).to_stdout
    end

    it 'does not report an unchanged topic file' do
      expect do
        helper.report_topic_file_change(topic_file, "updated topic\n")
      end.not_to output.to_stdout
    end
  end
end
