# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../atwork'

class AtWorkTest < Minitest::Test
  def test_source_header_links_back_to_the_curriculum_page
    Dir.mktmpdir do |temporary_directory|
      page_dir = File.join(temporary_directory, 'bjc-r', 'cur', 'programming', '3-unit', '1-lab')
      FileUtils.mkdir_p(page_dir)
      builder = AtWork.new(File.dirname(page_dir), 'en', 'cur/programming')
      builder.currUnit('Unit 3 Lab 1, Page 2')
      builder.currFile('page.html')

      Dir.chdir(page_dir) do
        assert_equal ' <a href="/bjc-r/cur/programming/3-unit/1-lab/page.html">3.1.2</a>',
                     builder.add_unit_to_header
      end
    end
  end
end
