# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'

require_relative 'topic'

# Regression tests for the topic representation consumed by all summary
# generators. Keep the fixture small and self-contained: a test should describe
# the topic syntax the generator supports, rather than depend on a particular
# curriculum unit's current content.
class BJCTopicTest < Minitest::Test
  TOPIC = <<~TOPIC
    title: Unit 7: Test-driven Topics

    {
    heading: Lab 1: First Lab
      raw-html: <img src="/bjc-r/img/example.png" />
      resource: First Page [/bjc-r/cur/programming/unit-7/lab-1/first.html]
      quiz: Second Page [/bjc-r/cur/programming/unit-7/lab-1/second.html] // trailing comment

    heading: Lab 2: Second Lab
      assignment: Third Page [/bjc-r/cur/programming/unit-7/lab-2/third.html]

    heading: Unit 7 Review
      resource: Vocabulary [/bjc-r/cur/programming/unit-7/unit-7-vocab.html]
      resource: On the AP Exam [/bjc-r/cur/programming/unit-7/unit-7-exam-reference.html]
      resource: Self-Check Questions [/bjc-r/cur/programming/unit-7/unit-7-self-check.html]
    }
  TOPIC

  def with_topic
    Dir.mktmpdir do |root|
      topic_dir = File.join(root, 'topic', 'test-course')
      Dir.mkdir(File.join(root, 'topic'))
      Dir.mkdir(topic_dir)
      path = File.join(topic_dir, '7-test.topic')
      File.write(path, TOPIC)
      yield BJCTopic.new(path, course: 'test-course')
    end
  end

  def test_parses_title_unit_and_resource_content
    with_topic do |topic|
      assert_equal 'Unit 7: Test-driven Topics', topic.parse[:title]
      assert_equal '7', topic.unit_number
      first_page = topic.unit_data[:content].find { |entry| entry[:content] == 'First Page' }
      assert_equal '/bjc-r/cur/programming/unit-7/lab-1/first.html', first_page[:url]
    end
  end

  def test_all_pages_excludes_generated_summary_pages_by_default
    with_topic do |topic|
      assert_equal %w[first.html second.html third.html],
                   topic.all_pages_without_summaries.map { |page| File.basename(page[:url]) }
      assert_equal 6, topic.all_pages_with_summaries.length
    end
  end

  def test_iterates_only_real_curriculum_pages_with_lab_and_page_numbers
    with_topic do |topic|
      pages = []
      topic.iterate_curriculum_pages { |page| pages << page }

      assert_equal [
        ['Lab 1: First Lab', 1, 1, 'first.html'],
        ['Lab 1: First Lab', 1, 2, 'second.html'],
        ['Lab 2: Second Lab', 2, 1, 'third.html']
      ], pages.map { |page| [page[:lab], page[:lab_number], page[:page_number], File.basename(page[:path])] }
      assert pages.all? { |page| page[:unit] == '7' && page[:course] == 'test-course' }
    end
  end

  def test_base_content_folder_is_shared_curriculum_path
    with_topic do |topic|
      assert_equal '/bjc-r/cur/programming/unit-7/', topic.base_content_folder
    end
  end
end
