# frozen_string_literal: true

require 'minitest/autorun'

require_relative '../bjc_helpers'

class BJCHelpersTest < Minitest::Test
  include BJCHelpers

  def test_topic_and_course_context_is_replaced_atomically
    get_topic_course('first-topic', 'first-course')
    get_topic_course('second-topic', 'second-course')

    assert_equal %w[second-topic second-course], BJCHelpers::TOPIC_COURSE
  end
end
