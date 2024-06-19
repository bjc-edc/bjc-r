# frozen_string_literal: true

# Summarize the axe rspec failures into aggregate counts

require 'json'
require 'pp'

RESULTS_PATH = File.join(File.dirname(__FILE__), '..', 'tmp/rspec_output.json')
AXE_CASE_TITLE = /\n\s*\n\s*\d+\)\s+([-\w]+):/

results_data = JSON.parse(File.read(RESULTS_PATH))

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

def aggregate_results(results)
  list_of_hashes = failing_specs(results).map do |ex|
    ex['exception']['message'].split(AXE_CASE_TITLE).slice(1..).each_slice(2).to_h
  end
  list_of_hashes.reduce({}) do |acc, h|
    h.each do |k, v|
      acc[k] ||= []
      acc[k] << v
    end
    acc
  end
end

failing_tests_by_type = summarize_results(results_data)
pp(failing_tests_by_type)

puts "Total: #{failing_tests_by_type.values.sum} failures."

# puts "Aggregate results: #{aggregate_results(results_data)}"
