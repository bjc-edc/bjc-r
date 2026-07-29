# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../main'

class MainTest < Minitest::Test
  def setup
    @temporary_directory = Dir.mktmpdir
    @root = File.join(@temporary_directory, 'bjc-r')
    FileUtils.mkdir_p(File.join(@root, 'course'))
    FileUtils.mkdir_p(File.join(@root, 'cur', 'programming'))
    File.write(File.join(@root, 'course', 'test.html'), '<html></html>')
    @main = Main.new(root: @root, content: 'cur/programming', course: 'test')
  end

  def teardown
    FileUtils.remove_entry(@temporary_directory)
  end

  def test_maps_bjc_url_to_local_file_and_removes_navigation_query
    expected = File.join(@root, 'cur', 'programming', '1-unit', '1-lab', 'page.html')

    assert_equal expected, @main.local_page_path('/bjc-r/cur/programming/1-unit/1-lab/page.html?2#box1')
    assert_nil @main.local_page_path('https://example.com/page.html')
  end
end
