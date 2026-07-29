# frozen_string_literal: true

# Run with:
#   bundle exec ruby tests.rb

Dir[File.join(__dir__, 'test', '*_test.rb')].sort.each { |file| require file }
