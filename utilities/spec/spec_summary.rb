# frozen_string_literal: true

# Summarize the axe rspec failures into aggregate counts
# TODO: This should be an RSpec formatter

require 'json'
require 'pp'

RESULTS_PATH = File.join(File.dirname(__FILE__), '..', '..', 'tmp/rspec_output.json')
AXE_CASE_TITLE = /\n\s*\n\s*\d+\)\s+([-\w]+):/


def failing_specs(results_data)
  results_data['examples'].filter do |ex|
    ex['status'] == 'failed'
  end
end

def summarize_results(results)
  failing_specs(results).map do |ex|
    ex['exception']['message'].scan(AXE_CASE_TITLE)
  end.flatten.tally
end

def print_summary
  results_data = JSON.parse(File.read(RESULTS_PATH))
  failing_tests_by_type = summarize_results(results_data)
  pp(failing_tests_by_type)
  puts "Total: #{failing_tests_by_type.values.sum} failures."
end

print_summary
