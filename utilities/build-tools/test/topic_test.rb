# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../topic'

class BJCTopicTest < Minitest::Test
  def with_topic(contents)
    Dir.mktmpdir do |root|
      topic_dir = File.join(root, 'topic', 'test')
      FileUtils.mkdir_p(topic_dir)
      path = File.join(topic_dir, 'unit.topic')
      File.write(path, contents)
      yield BJCTopic.new(path)
    end
  end

  def test_parses_full_heading_and_spanish_unit_number
    with_topic(<<~TOPIC) do |topic|
      title: Unidad 2: Abstracción
      {
      heading: Laboratorio 1: Dibujar
        resource: Página [/bjc-r/cur/programming/2-unit/1-lab/page.es.html]
      }
    TOPIC
      page = topic.iterate_curriculum_pages.to_a.fetch(0)

      assert_equal 'Unidad 2: Abstracción', topic.title
      assert_equal '2', topic.unit_number
      assert_equal 'Laboratorio 1: Dibujar', page[:lab]
      assert_equal '/bjc-r/cur/programming/2-unit/1-lab/page.es.html', page[:path]
    end
  end

  def test_excludes_generated_summary_pages_from_curriculum_iteration
    with_topic(<<~TOPIC) do |topic|
      title: Unit 1: Introduction
      {
      heading: Lab 1: Build
        resource: Coming soon
        quiz:Page [/bjc-r/cur/programming/1-unit/1-lab/page.html?1]
      heading: Unit 1 Review
        resource: Vocabulary [/bjc-r/cur/programming/1-unit/unit-1-vocab.html]
        resource: Self-Check [/bjc-r/cur/programming/1-unit/unit-1-self-check.html]
      }
    TOPIC
      pages = topic.iterate_curriculum_pages.to_a

      assert_equal ['/bjc-r/cur/programming/1-unit/1-lab/page.html?1'], pages.map { |page| page[:path] }
      assert_equal 'quiz', topic.unit_data[:content].first[:content].last[:type]
      assert_equal 2, topic.summary_pages.length
    end
  end

  def test_removes_only_a_real_summary_heading
    with_topic(<<~TOPIC) do |topic|
      title: Unit 1: Introduction
      {
      // heading: Unit 1 Review
      heading: Lab 1: Build
        resource: Page [/bjc-r/cur/programming/1-unit/1-lab/page.html]
      heading: Unit 1 Review
        resource: Vocabulary [/bjc-r/cur/programming/1-unit/unit-1-vocab.html]
      }
    TOPIC
      contents = topic.contents_without_summaries

      assert_includes contents, 'heading: Lab 1: Build'
      refute_includes contents, 'resource: Vocabulary'
      refute contents.end_with?('}')
    end
  end

  def test_resource_text_containing_heading_is_not_parsed_as_a_heading
    with_topic(<<~TOPIC) do |topic|
      title: Unit 1
      {
      heading: Lab 1
        resource: A heading example [/bjc-r/cur/programming/1-unit/1-lab/page.html]
      }
    TOPIC
      section = topic.unit_data[:content].find { |entry| entry[:title] == 'Lab 1' }

      assert_equal 1, section[:content].length
      assert_equal 'resource', section[:content].first[:type]
    end
  end
end
